#!/usr/bin/env python3
"""Backfill git tags + GitHub Releases for every historical steer version.

``release-publish.yml`` handles releases going forward; this one-shot brings the
history up to the same shape. For each ``### X.Y.Z`` heading in ``CHANGELOG.md``
it:

1. anchors the version to a real commit — the one that *introduced* that heading
   (``git log -S`` pickaxe on the exact heading string). That commit is the
   release commit regardless of the message convention of the day
   (``chore(release):``, ``release(steer):``, or an older ``feat(...): … (vX)``),
   so the anchor is uniform across all 90 versions, not just the recent ones;
2. creates an annotated ``vX.Y.Z`` tag on that commit if the tag is missing; and
3. creates a GitHub Release from that tag with the CHANGELOG notes as its body.

**Dry-run is the default** — it prints the plan (anchor commit + tag/release
state) and touches nothing. Pass ``--execute`` to actually create tags and
Releases. Everything is idempotent: existing tags and existing Releases are left
untouched, so a partial run can be resumed and ``--execute`` can follow
``release-publish.yml`` without clobbering what it already published.

Usage::

    python3 scripts/backfill_releases.py               # dry-run: show the plan
    python3 scripts/backfill_releases.py --execute      # create missing tags + Releases
    python3 scripts/backfill_releases.py --only 2.14.0  # limit to one version (repeatable)

Requires ``git`` and (for --execute) an authenticated ``gh`` CLI with push /
release-create rights on the origin remote.
"""

from __future__ import annotations

import argparse
import subprocess
import sys

import changelog_release_notes as crn


def _git(*args: str) -> str:
    return subprocess.run(
        ["git", *args],
        capture_output=True,
        text=True,
        check=True,
        cwd=crn.REPO_ROOT,
    ).stdout.strip()


def anchor_commit(version: str) -> str | None:
    """The commit that first added ``### <version>`` to CHANGELOG.md, or None.

    ``--reverse`` orders oldest-first so the head of the pickaxe list is the
    commit that introduced the heading (later edits to the same section also
    match ``-S`` when the line count changes, but never come first).
    """
    out = _git(
        "log",
        "--reverse",
        "--format=%H",
        "-S",
        f"### {version}",
        "--",
        "CHANGELOG.md",
    )
    lines = [ln for ln in out.splitlines() if ln.strip()]
    return lines[0] if lines else None


def tag_exists(tag: str) -> bool:
    return bool(_git("tag", "--list", tag))


def release_exists(tag: str) -> bool:
    return (
        subprocess.run(
            ["gh", "release", "view", tag],
            capture_output=True,
            text=True,
            cwd=crn.REPO_ROOT,
        ).returncode
        == 0
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--execute",
        action="store_true",
        help="create missing tags + Releases (default: dry-run, print the plan only)",
    )
    parser.add_argument(
        "--only",
        action="append",
        default=[],
        metavar="X.Y.Z",
        help="limit to this version (repeatable); default is every released version",
    )
    args = parser.parse_args(argv)

    versions = crn.released_versions()
    if args.only:
        wanted = set(args.only)
        unknown = wanted - set(versions)
        if unknown:
            print(f"unknown version(s): {', '.join(sorted(unknown))}", file=sys.stderr)
            return 1
        versions = [v for v in versions if v in wanted]

    mode = "EXECUTE" if args.execute else "DRY-RUN"
    print(f"[{mode}] backfilling {len(versions)} version(s)\n")

    created_tags = created_releases = skipped = 0
    problems: list[str] = []

    for version in versions:
        tag = f"v{version}"
        commit = anchor_commit(version)
        if commit is None:
            problems.append(version)
            print(f"  {tag:<12} !! no anchor commit found — skipping")
            continue

        have_tag = tag_exists(tag)
        have_release = release_exists(tag)
        short = commit[:9]

        if have_tag and have_release:
            skipped += 1
            print(f"  {tag:<12} ok  tag + release already exist ({short})")
            continue

        actions = []
        if not have_tag:
            actions.append("tag")
        if not have_release:
            actions.append("release")
        print(f"  {tag:<12} ->  create {' + '.join(actions)} @ {short}")

        if not args.execute:
            continue

        try:
            if not have_tag:
                _git("tag", "-a", tag, commit, "-m", f"steer {version}")
                _git("push", "origin", tag)
                created_tags += 1
            notes = crn.release_notes(version)
            subprocess.run(
                [
                    "gh",
                    "release",
                    "create",
                    tag,
                    "--title",
                    f"steer {version}",
                    "--notes",
                    notes,
                ],
                check=True,
                cwd=crn.REPO_ROOT,
            )
            created_releases += 1
        except subprocess.CalledProcessError as exc:
            problems.append(version)
            print(f"  {tag:<12} !! failed: {exc}", file=sys.stderr)

    print()
    if args.execute:
        print(
            f"created {created_tags} tag(s), {created_releases} release(s); "
            f"{skipped} already present"
        )
    else:
        print(f"dry-run complete; {skipped} already present. Re-run with --execute to apply.")
    if problems:
        print(f"problems with: {', '.join(problems)}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

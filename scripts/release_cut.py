#!/usr/bin/env python3
"""Deterministic release cut for the steer plugin (``/release`` Phase B, steps B3-B5).

``changie`` owns the changelog and the version bump: ``batch`` turns every pending
fragment in ``.changes/unreleased/`` into ``.changes/vX.Y.Z.md``, and ``merge``
reassembles ``CHANGELOG.md`` and rewrites the three version-bearing manifests
through the ``replacements`` block in ``.changie.yaml``. What changie does *not*
know about is the second ledger, and that is why this script still exists:

- ``templates/reference/MIGRATIONS.md``: rename every ``### [Unreleased] — <what>``
  entry **inside ``## Entries``** to ``### vX.Y.Z — <what>``. The authoring stub in
  the trailing ``<!-- Template for a new entry -->`` comment carries the identical
  heading and must never be stamped -- no gate catches it when it is.

It also enforces the preconditions changie has no opinion on (nothing pending,
a version that does not advance, manifests that disagree before the cut) and
re-validates the release invariant afterwards -- including that the Copilot
marketplace's own ``metadata.version`` did not move with the plugin.

``--dry-run`` prints the version file changie would write, the manifest
transitions, and the MIGRATIONS diff, and writes nothing. The skills call this
instead of editing by hand, so the step is reviewable in one place and cannot
drift between ``/release`` and ``/quick-release``.

Usage::

    uv run python scripts/release_cut.py propose                # bump from the pending fragments
    uv run python scripts/release_cut.py cut 6.1.0 --dry-run    # show what would change
    uv run python scripts/release_cut.py cut 6.1.0              # apply + validate
    uv run python scripts/release_cut.py pr-body 6.1.0 --via release [--audit FILE]

Exit status is 0 on success, 1 when a precondition or the post-cut validation
fails. Stdlib only; shells out to ``changie`` for the cut itself.
"""

from __future__ import annotations

import argparse
import difflib
import json
import re
import subprocess
import sys
from pathlib import Path

from reflow_release_notes import release_body

REPO_ROOT = Path(__file__).resolve().parent.parent
CHANGELOG = REPO_ROOT / "CHANGELOG.md"
UNRELEASED_DIR = REPO_ROOT / ".changes/unreleased"
CHANGES_DIR = REPO_ROOT / ".changes"
MIGRATIONS = REPO_ROOT / "plugins/steer/templates/reference/MIGRATIONS.md"
PLUGIN_JSON = REPO_ROOT / "plugins/steer/.claude-plugin/plugin.json"
COPILOT_PLUGIN_JSON = REPO_ROOT / "plugins/steer/.github/plugin/plugin.json"
COPILOT_MARKETPLACE = REPO_ROOT / ".github/plugin/marketplace.json"

UNRELEASED = "### [Unreleased]"
_SEMVER_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")
_MIGRATION_STUB_MARKER = "<!-- Template for a new entry"


class CutError(Exception):
    """A precondition or validation failure that must stop the cut."""


def _semver(text: str) -> tuple[int, int, int]:
    m = _SEMVER_RE.match(text.strip())
    if not m:
        raise CutError(f"not a semver version: {text!r}")
    return int(m[1]), int(m[2]), int(m[3])


# --- MIGRATIONS ---------------------------------------------------------------


def migration_entry_range(text: str) -> tuple[int, int]:
    """Index range ``[start, end)`` of the ``## Entries`` list, excluding the stub.

    ``end`` is the line of the trailing ``<!-- Template for a new entry`` comment
    (or EOF when absent). Headings at or past ``end`` are the authoring stub and
    must never be renamed.
    """
    lines = text.splitlines()
    try:
        start = next(i for i, ln in enumerate(lines) if ln.strip() == "## Entries") + 1
    except StopIteration as exc:
        raise CutError(f"{MIGRATIONS.name}: no '## Entries' section") from exc
    end = next(
        (i for i in range(start, len(lines)) if lines[i].startswith(_MIGRATION_STUB_MARKER)),
        len(lines),
    )
    return start, end


def cut_migrations(text: str, version: str) -> tuple[str, int]:
    """Rename ``### [Unreleased] — <what>`` entries to ``### v<version> — <what>``.

    Returns ``(new_text, renamed_count)``. Zero renames is the normal case.
    """
    lines = text.splitlines()
    start, end = migration_entry_range(text)
    renamed = 0
    for i in range(start, end):
        if lines[i].startswith(UNRELEASED):
            lines[i] = f"### v{version}" + lines[i][len(UNRELEASED) :]
            renamed += 1
    out = "\n".join(lines) + ("\n" if text.endswith("\n") else "")
    return out, renamed


# --- manifests ----------------------------------------------------------------


def _steer_entry_version(marketplace: dict) -> str:
    for entry in marketplace.get("plugins", []):
        if entry.get("name") == "steer":
            return entry.get("version", "")
    raise CutError(f"{COPILOT_MARKETPLACE.name}: no 'steer' plugin entry")


def _manifest_versions() -> dict[Path, str]:
    return {
        PLUGIN_JSON: json.loads(PLUGIN_JSON.read_text(encoding="utf-8")).get("version", ""),
        COPILOT_PLUGIN_JSON: json.loads(COPILOT_PLUGIN_JSON.read_text(encoding="utf-8")).get(
            "version", ""
        ),
        COPILOT_MARKETPLACE: _steer_entry_version(
            json.loads(COPILOT_MARKETPLACE.read_text(encoding="utf-8"))
        ),
    }


# --- commands -----------------------------------------------------------------


def _changie(*args: str) -> str:
    """Run changie from the repo root, via mise when it is not already on PATH."""
    for prefix in (["changie"], ["mise", "x", "--", "changie"]):
        try:
            out = subprocess.run(
                [*prefix, *args], capture_output=True, text=True, check=False, cwd=REPO_ROOT
            )
        except FileNotFoundError:
            continue
        if out.returncode == 0:
            return out.stdout
        detail = out.stderr.strip() or out.stdout.strip()
        raise CutError(f"changie {' '.join(args)} failed: {detail}")
    raise CutError("changie not found -- install it with `mise install`")


def pending_fragments() -> list[tuple[str, str, Path]]:
    """``(kind, slug, path)`` for every pending fragment, sorted by kind then slug."""
    if not UNRELEASED_DIR.is_dir():
        return []
    out = []
    for frag in sorted(UNRELEASED_DIR.glob("*.yaml")):
        kind = slug = ""
        for line in frag.read_text(encoding="utf-8").splitlines():
            if line.startswith("kind:"):
                kind = line.split(":", 1)[1].strip()
            elif line.strip().startswith("Slug:"):
                slug = line.split(":", 1)[1].strip()
        out.append((kind, slug or frag.stem, frag))
    return sorted(out, key=lambda t: (t[0], t[1]))


def propose() -> dict:
    """Bump suggestion from the pending fragments, as changie derives it.

    The level comes from each kind's ``auto:`` in ``.changie.yaml`` -- declared
    data, not a guess at what a bullet's wording implies. The fragments are
    listed so the reviewer can see *which* ones drove it.
    """
    frags = pending_fragments()
    if not frags:
        raise CutError(".changes/unreleased/ is empty -- nothing to release")
    cur = json.loads(PLUGIN_JSON.read_text(encoding="utf-8"))["version"]
    return {
        "current": cur,
        "fragments": frags,
        "suggested": _changie("next", "auto").strip().lstrip("v"),
        "candidates": {
            level: _changie("next", level).strip().lstrip("v")
            for level in ("major", "minor", "patch")
        },
    }


def _precheck(version: str) -> str:
    """Refuse the cut unless it can succeed. Returns the current version."""
    _semver(version)
    if not pending_fragments():
        raise CutError(".changes/unreleased/ is empty -- nothing to release")
    current = _manifest_versions()
    if len(set(current.values())) != 1:
        raise CutError(
            "manifests disagree before the cut: "
            + ", ".join(f"{p.relative_to(REPO_ROOT)}={v}" for p, v in current.items())
        )
    old = next(iter(current.values()))
    if _semver(version) <= _semver(old):
        raise CutError(f"{version} is not above the current plugin version {old}")
    if (CHANGES_DIR / f"v{version}.md").exists():
        raise CutError(f".changes/v{version}.md already exists")
    return old


def preview_cut(version: str) -> str:
    """What ``cut`` would change, without writing anything."""
    old = _precheck(version)
    batched = _changie("batch", f"v{version}", "--dry-run").rstrip()
    parts = [f"# .changes/v{version}.md (new)", "", batched]
    parts += ["", f"# manifests: {old} -> {version}", ""]
    parts += [f"  {p.relative_to(REPO_ROOT)}" for p in _manifest_versions()]
    parts += [
        "",
        "  (.github/plugin/marketplace.json's own metadata.version is left alone)",
        "",
        "# CHANGELOG.md: the block above is inserted at the top; nothing else moves.",
    ]
    if MIGRATIONS.is_file():
        before = MIGRATIONS.read_text(encoding="utf-8")
        after, renamed = cut_migrations(before, version)
        parts += ["", f"# {MIGRATIONS.relative_to(REPO_ROOT)}: {renamed} entry(ies) renamed", ""]
        if after != before:
            parts += list(
                difflib.unified_diff(
                    before.splitlines(keepends=True),
                    after.splitlines(keepends=True),
                    fromfile=f"a/{MIGRATIONS.name}",
                    tofile=f"b/{MIGRATIONS.name}",
                )
            )
    return "".join(x if x.endswith("\n") else x + "\n" for x in parts)


def apply_cut(version: str) -> None:
    """Batch the fragments, reassemble, then stamp the migration ledger."""
    _precheck(version)
    _changie("batch", f"v{version}")
    print(f"batched .changes/v{version}.md")
    # merge rewrites CHANGELOG.md AND the three manifests (.changie.yaml
    # replacements). release-publish.yml fires on the plugin.json version diff,
    # so skipping this step would leave the release unpublished.
    _changie("merge")
    print("merged CHANGELOG.md + manifests")
    if MIGRATIONS.is_file():
        before = MIGRATIONS.read_text(encoding="utf-8")
        after, renamed = cut_migrations(before, version)
        if after != before:
            MIGRATIONS.write_text(after, encoding="utf-8")
            print(f"stamped {renamed} migration entry(ies)")


def validate_cut(version: str) -> list[str]:
    """Post-cut assertions: the release invariant plus the migration-stub guard."""
    errors: list[str] = []
    for path, v in _manifest_versions().items():
        if v != version:
            errors.append(f"{path.relative_to(REPO_ROOT)}: version {v!r} != {version}")
    marketplace = json.loads(COPILOT_MARKETPLACE.read_text(encoding="utf-8"))
    if marketplace.get("metadata", {}).get("version") == version:
        errors.append(f"{COPILOT_MARKETPLACE.name}: metadata.version was bumped -- it must not be")

    if not (CHANGES_DIR / f"v{version}.md").is_file():
        errors.append(f".changes/v{version}.md: missing after the cut")
    if pending_fragments():
        errors.append(".changes/unreleased/: fragments survived the cut")
    if f"## {version}" not in CHANGELOG.read_text(encoding="utf-8"):
        errors.append(f"{CHANGELOG.name}: no '## {version}' heading -- was `changie merge` run?")

    if MIGRATIONS.is_file():
        mtext = MIGRATIONS.read_text(encoding="utf-8")
        mlines = mtext.splitlines()
        start, end = migration_entry_range(mtext)
        if any(mlines[i].startswith(UNRELEASED) for i in range(start, end)):
            errors.append(
                f"{MIGRATIONS.name}: an '[Unreleased]' entry survived inside '## Entries'"
            )
        if any(ln.startswith(f"### v{version}") for ln in mlines[end:]):
            errors.append(f"{MIGRATIONS.name}: the authoring stub was stamped with v{version}")
    return errors


def _run(cmd: list[str]) -> str:
    out = subprocess.run(cmd, capture_output=True, text=True, check=False, cwd=REPO_ROOT)
    return out.stdout


def release_notes(version: str) -> str:
    """The version's entries, reflowed and without their `## X.Y.Z` heading.

    A PR description renders in the same comment mode as a Release body, so it
    needs the same reflow -- shared with the publish workflow rather than copied,
    so the PR and the Release can never disagree about the entries.
    """
    path = CHANGES_DIR / f"v{version}.md"
    if not path.is_file():
        raise CutError(f"{path.relative_to(REPO_ROOT)}: missing")
    return release_body(path.read_text(encoding="utf-8")).strip()


def pr_body(version: str, via: str, audit_file: Path | None) -> str:
    parts = [f"# Release steer {version}", "", "## Changes", "", release_notes(version), ""]
    parts += ["## Pre-release audit", ""]
    if audit_file and audit_file.is_file():
        parts += [audit_file.read_text(encoding="utf-8").rstrip(), ""]
    else:
        parts += ["_TODO: paste the Phase-A verdict (gates, coherence, docs) here._", ""]
    if via == "quick-release":
        parts += [
            "> Cut via `/quick-release`: deterministic gates (CI, strict docs build, "
            "deployed-docs freshness) passed. The judgment-based coherence audit and "
            "documentation-accuracy deep review were **not** run -- reviewers should "
            "apply that scrutiny to the diff.",
            "",
        ]
    parts += ["## Always-on context budget", ""]
    parts += [_run(["uv", "run", "python", "scripts/check_context_budget.py", "--report"]).rstrip()]
    return "\n".join(parts) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("propose", help="suggest a bump from the pending fragments")
    p_cut = sub.add_parser("cut", help="batch + merge + stamp migrations, then validate")
    p_cut.add_argument("version", help="X.Y.Z")
    p_cut.add_argument("--dry-run", action="store_true", help="print the plan, write nothing")
    p_pr = sub.add_parser("pr-body", help="print the release PR body")
    p_pr.add_argument("version")
    p_pr.add_argument("--via", choices=("release", "quick-release"), default="release")
    p_pr.add_argument("--audit", type=Path, default=None, help="file with the audit verdict")
    args = parser.parse_args(argv)

    try:
        if args.cmd == "propose":
            info = propose()
            print(f"current version: {info['current']}")
            print(f"pending fragments: {len(info['fragments'])}")
            for kind, slug, _ in info["fragments"]:
                print(f"  {kind:<9} {slug}")
            print(f"suggested bump: {info['suggested']}")
            print("candidates: " + ", ".join(f"{k}={v}" for k, v in info["candidates"].items()))
            print("(confirm the bump with the user before cutting)")
            return 0
        if args.cmd == "cut":
            if args.dry_run:
                sys.stdout.write(preview_cut(args.version))
                print("\ndry run: nothing written")
                return 0
            apply_cut(args.version)
            errors = validate_cut(args.version)
            if errors:
                for e in errors:
                    print(f"error: {e}", file=sys.stderr)
                return 1
            print(f"cut steer {args.version}: release invariant holds")
            return 0
        if args.cmd == "pr-body":
            sys.stdout.write(pr_body(args.version, args.via, args.audit))
            return 0
    except CutError as exc:
        print(f"release_cut: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

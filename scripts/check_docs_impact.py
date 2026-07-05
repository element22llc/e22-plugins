#!/usr/bin/env python3
"""Docs-impact gate for the e22-plugins documentation site.

A git-diff gate modeled on ``check_changelog.py``'s ``--base`` behaviour gate:
if a PR changes the user-facing surface that the docs site describes (skills,
rules, hooks) but touches no ``docs/`` file, the docs have almost certainly
drifted — fail and point at ``/plugin-docs``.

This is intentionally coarse (any docs change clears the gate); the structural
sync is enforced separately and always by ``validate_docs.py``.

Usage::

    uv run python scripts/check_docs_impact.py --base origin/main

Exit status is 0 when clean (or when not run with --base), 1 when the gate trips.
"""

from __future__ import annotations

import argparse
import subprocess
import sys

# Surfaces the docs site documents. A change here without a docs change is the
# signal we gate on.
DOC_BEARING_PREFIXES = (
    "plugins/steer/skills/",
    "plugins/steer/rules/",
    "plugins/steer/hooks/",
    "plugins/steer/agents/",
)
# Test-only changes don't change documented behaviour. Internal hook *libraries*
# (``hooks/lib/*``) are sourced plumbing — they carry no event/matcher of their
# own and never appear in ``hooks.json``, so the docs site does not describe them
# (``docs/reference/hooks.md`` documents the ``hooks.json`` entries). A change
# confined to a lib helper therefore has no documented surface to drift from.
EXEMPT_SUBSTRINGS = ("/tests/", "/hooks/lib/")
DOCS_PREFIX = "docs/"


def _changed_files(base: str) -> list[str] | None:
    """Changed paths vs ``base``, mirroring ``check_changelog.py``'s semantics:
    three-dot (merge-base) diff, then a two-dot fallback (e.g. shallow clone
    without a merge base), then ``None`` so the caller can fail open with a note
    instead of blocking on git plumbing."""
    try:
        out = subprocess.run(
            ["git", "diff", "--name-only", f"{base}...HEAD"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout
    except (subprocess.CalledProcessError, FileNotFoundError):
        try:
            out = subprocess.run(
                ["git", "diff", "--name-only", base, "HEAD"],
                capture_output=True,
                text=True,
                check=True,
            ).stdout
        except (subprocess.CalledProcessError, FileNotFoundError):
            return None
    return [line.strip() for line in out.splitlines() if line.strip()]


def _is_doc_bearing(path: str) -> bool:
    if any(sub in path for sub in EXEMPT_SUBSTRINGS):
        return False
    return path.startswith(DOC_BEARING_PREFIXES)


def check_impact(base: str, errors: list[str]) -> None:
    changed = _changed_files(base)
    if changed is None:
        print(f"check_docs_impact: could not diff against {base!r}; skipping docs-impact gate.")
        return
    if not changed:
        return
    doc_bearing = [p for p in changed if _is_doc_bearing(p)]
    docs_touched = any(p.startswith(DOCS_PREFIX) for p in changed)
    if doc_bearing and not docs_touched:
        errors.append(
            "documented surface changed but no docs/ file was updated — "
            f"review the docs and run /plugin-docs (changed: {sorted(doc_bearing)})"
        )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", help="git ref to diff HEAD against for the docs-impact gate")
    args = parser.parse_args(argv)

    errors: list[str] = []
    if args.base:
        check_impact(args.base, errors)

    if errors:
        print(f"check_docs_impact: {len(errors)} problem(s) found:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1
    print("check_docs_impact: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())

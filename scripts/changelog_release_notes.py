#!/usr/bin/env python3
"""Extract release metadata from ``CHANGELOG.md`` for tag / GitHub Release cutting.

The steer plugin ships one changelog whose ``## steer`` section carries a
``### X.Y.Z`` heading per release (newest first, ``### [Unreleased]`` on top),
each followed by its bullet notes. This module turns that structure into the
inputs a release needs:

- the release notes body for a given version (used as the GitHub Release body),
- the ordered list of released versions (used by the backfill), and
- the current plugin version (source of truth: ``plugin.json``).

It is **stdlib-only on purpose** — the ``release-publish.yml`` workflow runs it
with the runner's system ``python3`` (no mise/uv provisioning) right after a
release merges to ``main``. The heading parsing mirrors
``check_changelog.py`` (same ``## steer`` scoping and ``### `` heading regex) so
the two never disagree about what a "released heading" is.

Usage::

    python3 scripts/changelog_release_notes.py current-version   # -> 3.11.0
    python3 scripts/changelog_release_notes.py list              # released versions, newest first
    python3 scripts/changelog_release_notes.py notes 3.11.0      # bullet block for one version

Exit status is 0 on success, 1 when a requested version has no heading (or the
changelog / manifest is malformed).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

# Resolve inputs relative to the repo root (two levels up from this file) so the
# script works from any cwd — CI checks out to a runner-specific path.
REPO_ROOT = Path(__file__).resolve().parent.parent
PLUGIN_JSON = REPO_ROOT / "plugins/steer/.claude-plugin/plugin.json"
CHANGELOG = REPO_ROOT / "CHANGELOG.md"

_SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+$")
_HEADING_RE = re.compile(r"^###\s+(.+?)\s*$")


def current_version() -> str:
    """The version in ``plugin.json`` — the release source of truth."""
    data = json.loads(PLUGIN_JSON.read_text(encoding="utf-8"))
    version = data.get("version")
    if not version:
        raise ValueError(f"{PLUGIN_JSON}: missing version")
    return version


def _steer_lines() -> list[str]:
    """Lines of the ``## steer`` section (heading excluded, next ``## `` stops it)."""
    if not CHANGELOG.is_file():
        raise FileNotFoundError(f"{CHANGELOG}: missing")
    out: list[str] = []
    in_section = False
    for line in CHANGELOG.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            in_section = line.strip() == "## steer"
            continue
        if in_section:
            out.append(line)
    return out


def released_versions() -> list[str]:
    """Released (semver) ``### `` headings under ``## steer``, in document order."""
    out: list[str] = []
    for line in _steer_lines():
        m = _HEADING_RE.match(line)
        if m and _SEMVER_RE.match(m.group(1)):
            out.append(m.group(1))
    return out


def release_notes(version: str) -> str:
    """The bullet block under ``### <version>`` up to the next ``### `` heading.

    Trailing/leading blank lines are stripped so the result drops cleanly into a
    GitHub Release body. Raises ``KeyError`` if the version has no heading.
    """
    if not _SEMVER_RE.match(version):
        raise ValueError(f"not a semver version: {version!r}")
    collecting = False
    body: list[str] = []
    for line in _steer_lines():
        m = _HEADING_RE.match(line)
        if m:
            if collecting:  # reached the next release heading — stop.
                break
            if m.group(1) == version:
                collecting = True
            continue
        if collecting:
            body.append(line)
    if not collecting:
        raise KeyError(version)
    return "\n".join(body).strip("\n")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("current-version", help="print plugin.json version")
    sub.add_parser("list", help="print released versions, newest first")
    p_notes = sub.add_parser("notes", help="print the release-notes block for a version")
    p_notes.add_argument("version", help="X.Y.Z")
    args = parser.parse_args(argv)

    try:
        if args.cmd == "current-version":
            print(current_version())
        elif args.cmd == "list":
            for v in released_versions():
                print(v)
        elif args.cmd == "notes":
            notes = release_notes(args.version)
            if not notes.strip():
                print(f"changelog has an empty notes block for {args.version}", file=sys.stderr)
                return 1
            print(notes)
    except KeyError as exc:
        print(f"no '### {exc.args[0]}' heading under '## steer' in {CHANGELOG}", file=sys.stderr)
        return 1
    except (FileNotFoundError, ValueError, json.JSONDecodeError) as exc:
        print(f"changelog_release_notes: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Changelog + release-integrity checks for the steer plugin.

Two checks, so the same script serves local runs and the CI PR gate:

1. **Release validator** (always — no git needed): the version in
   ``plugin.json`` equals the newest *released* heading under ``## steer``
   in ``CHANGELOG.md``, released headings are in strictly descending semver order,
   and a ``### [Unreleased]`` section (optional) is allowed above them. During
   normal development plugin.json is NOT bumped, so it equals the last release;
   the release PR renames ``[Unreleased]`` to the new version and bumps
   plugin.json to match — both keep this invariant.

2. **Behaviour-change gate** (only with ``--base <ref>``): if any plugin behaviour
   file changed versus the base ref, ``CHANGELOG.md`` must have changed too —
   so a stream of PRs accumulates ``[Unreleased]`` entries. Test-only changes
   under ``tests/`` are exempt.

Usage::

    uv run python scripts/check_changelog.py                 # release validator only
    uv run python scripts/check_changelog.py --base origin/main   # + behaviour gate

Exit status is 0 when clean, 1 when any check fails.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

PLUGIN_JSON = Path("plugins/steer/.claude-plugin/plugin.json")
CHANGELOG = Path("CHANGELOG.md")

# Behaviour paths: a change here requires a CHANGELOG.md entry (tests/ exempt).
BEHAVIOUR_PREFIXES = (
    "plugins/steer/skills/",
    "plugins/steer/hooks/",
    "plugins/steer/rules/",
    "plugins/steer/templates/",
    "plugins/steer/scripts/",
    "plugins/steer/policy/",
)
BEHAVIOUR_EXACT = ("plugins/steer/.claude-plugin/plugin.json",)
EXEMPT_SUBSTRINGS = ("/tests/",)

_SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+$")
_HEADING_RE = re.compile(r"^###\s+(.+?)\s*$")


def _semver(s: str) -> tuple[int, int, int]:
    a, b, c = s.split(".")
    return int(a), int(b), int(c)


def heading_sequence() -> list[str]:
    """All '### ' heading texts under '## steer', in document order.

    Matches heading lines only, so an inline ``### [Unreleased]`` mentioned in
    prose (the changelog's own house-rules bullet) is not counted.
    """
    if not CHANGELOG.is_file():
        return []
    out: list[str] = []
    in_section = False
    for line in CHANGELOG.read_text(encoding="utf-8").splitlines():
        if line.startswith("## "):
            in_section = line.strip() == "## steer"
            continue
        if not in_section:
            continue
        m = _HEADING_RE.match(line)
        if m:
            out.append(m.group(1))
    return out


def released_headings() -> list[str]:
    """Released (semver) ### headings under '## steer', in document order."""
    return [h for h in heading_sequence() if _SEMVER_RE.match(h)]


def check_unreleased(errors: list[str]) -> None:
    """Guard the persistent '### [Unreleased]' heading.

    It must appear at most once and before every released heading. A duplicated
    heading is the signature of a ``merge=union`` collision on ``CHANGELOG.md``
    (see ``.gitattributes``): union keeps both sides' added lines, which is what
    stops merge conflicts on concurrent entry additions, but it would silently
    duplicate the heading if two branches ever recreated it. Catch that loudly
    here instead of shipping a malformed changelog.
    """
    seq = heading_sequence()
    count = sum(1 for h in seq if h == "[Unreleased]")
    if count > 1:
        errors.append(
            f"{CHANGELOG}: '### [Unreleased]' appears {count} times under '## steer' — "
            "merge=union likely duplicated it; collapse to a single heading."
        )
    if count == 1 and seq and seq[0] != "[Unreleased]":
        errors.append(
            f"{CHANGELOG}: '### [Unreleased]' must be the first heading under '## steer'."
        )


def check_release(errors: list[str]) -> None:
    if not PLUGIN_JSON.is_file():
        errors.append(f"{PLUGIN_JSON}: missing")
        return
    try:
        version = json.loads(PLUGIN_JSON.read_text(encoding="utf-8")).get("version")
    except json.JSONDecodeError as exc:
        errors.append(f"{PLUGIN_JSON}: invalid JSON ({exc})")
        return
    if not version:
        errors.append(f"{PLUGIN_JSON}: missing version")
        return

    rel = released_headings()
    if not rel:
        errors.append(f"{CHANGELOG}: no released '### X.Y.Z' heading under '## steer'")
        return
    if rel[0] != version:
        errors.append(
            f"{PLUGIN_JSON}: version {version} != newest released CHANGELOG heading {rel[0]}"
        )
    # Strictly descending semver order.
    for newer, older in zip(rel, rel[1:], strict=False):
        try:
            if _semver(newer) <= _semver(older):
                errors.append(f"{CHANGELOG}: releases not in descending order ({newer} <= {older})")
        except ValueError:
            errors.append(f"{CHANGELOG}: non-semver release heading near {newer!r}")


def _changed_files(base: str) -> list[str] | None:
    try:
        out = subprocess.run(
            ["git", "diff", "--name-only", f"{base}...HEAD"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout
    except subprocess.CalledProcessError, FileNotFoundError:
        # Fall back to a two-dot diff (e.g. shallow clone without merge base).
        try:
            out = subprocess.run(
                ["git", "diff", "--name-only", base, "HEAD"],
                capture_output=True,
                text=True,
                check=True,
            ).stdout
        except subprocess.CalledProcessError, FileNotFoundError:
            return None
    return [p for p in out.splitlines() if p.strip()]


def _is_behaviour(path: str) -> bool:
    if any(sub in path for sub in EXEMPT_SUBSTRINGS):
        return False
    return path in BEHAVIOUR_EXACT or path.startswith(BEHAVIOUR_PREFIXES)


def check_behaviour_gate(base: str, errors: list[str]) -> None:
    changed = _changed_files(base)
    if changed is None:
        print(f"check_changelog: could not diff against {base!r}; skipping behaviour gate.")
        return
    behaviour = [p for p in changed if _is_behaviour(p)]
    if behaviour and "CHANGELOG.md" not in changed:
        errors.append(
            "CHANGELOG.md must change when plugin behaviour changes. Add an entry under "
            f"'## steer' → '### [Unreleased]'. Behaviour files changed: {behaviour[:8]}"
        )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="steer changelog/release checks.")
    parser.add_argument("--base", help="Base git ref for the behaviour-change gate.")
    args = parser.parse_args(argv)

    errors: list[str] = []
    check_release(errors)
    check_unreleased(errors)
    if args.base:
        check_behaviour_gate(args.base, errors)

    if errors:
        print(f"check_changelog: {len(errors)} problem(s) found:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1
    print("check_changelog: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Generate the GitHub Copilot custom-instructions artifact from steer's rules.

steer's always-on engineering standards live in ``plugins/steer/rules/*.md`` and
reach Claude Code via the ``inject-standards.sh`` SessionStart hook, whose stdout
becomes the session's ``additionalContext``. GitHub Copilot has no equivalent
context-injecting hook — its ``sessionStart`` hook ignores stdout — so Copilot's
always-on context comes from a static custom-instructions file, primarily
``.github/copilot-instructions.md``. This one file serves **both** Copilot
surfaces: the Copilot CLI and Copilot in VS Code (which reads it natively).

This script concatenates the same ``rules/*.md`` (lexical order, mirroring the
hook) into ``plugins/steer/templates/github/copilot-instructions.md`` — the
committed artifact ``/steer:init`` / ``/steer:adopt`` install into a consumer
repo's ``.github/``. Keeping a single source of truth (the rules) means the two
surfaces never diverge; ``check_copilot_instructions.py`` fails the build if the
committed artifact drifts from the rules.

We target ``.github/copilot-instructions.md`` rather than ``AGENTS.md`` on
purpose: Copilot reads ``AGENTS.md`` *and* ``CLAUDE.md`` as merged peers, so an
``AGENTS.md`` would double-load org standards alongside the consumer repo's
``CLAUDE.md`` (and Claude Code does not read ``AGENTS.md`` at all). The ``.github/``
primary file is read only by Copilot and never competes at the repo root.

Run from the repo root::

    uv run python scripts/gen_copilot_instructions.py            # print to stdout
    uv run python scripts/gen_copilot_instructions.py --write    # write the artifact
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

RULES_DIR = Path("plugins/steer/rules")
ARTIFACT = Path("plugins/steer/templates/github/copilot-instructions.md")

# Brand-free (the payload debrand gate scans templates/github) and skill-ref-safe
# (`/steer:init` resolves to a real skill). The refresh path is the explicit
# re-run of init's Copilot step from Claude Code — Copilot teammates only consume
# the installed file.
HEADER = (
    "<!-- Engineering standards (steer plugin). Generated from the plugin's "
    "rules/ — do not edit by hand. Refresh after a plugin update by re-running "
    "/steer:init's Copilot step. -->"
)


def iter_rule_files(rules_dir: Path) -> list[Path]:
    """The rule files, in the lexical order the SessionStart hook concatenates
    them (the numeric file prefixes encode that order)."""
    return sorted(rules_dir.glob("*.md")) if rules_dir.is_dir() else []


def render(rules_dir: Path = RULES_DIR) -> str:
    """Return the full copilot-instructions text: header then each rule body,
    blank-line separated, with a single trailing newline (mirrors
    ``inject-standards.sh`` minus its Claude-specific banner)."""
    parts: list[str] = [HEADER, "\n\n"]
    for f in iter_rule_files(rules_dir):
        parts.append(f.read_text(encoding="utf-8"))
        parts.append("\n\n")
    return "".join(parts).rstrip("\n") + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Generate the Copilot instructions artifact.")
    parser.add_argument(
        "--write",
        action="store_true",
        help=f"Write the artifact to {ARTIFACT} (default: print to stdout).",
    )
    parser.add_argument(
        "--rules-dir",
        type=Path,
        default=RULES_DIR,
        help=f"Rules directory to concatenate (default: {RULES_DIR}).",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=ARTIFACT,
        help=f"Output path when --write is set (default: {ARTIFACT}).",
    )
    args = parser.parse_args(argv)

    if not args.rules_dir.is_dir():
        print(f"gen_copilot_instructions: rules dir not found: {args.rules_dir}", file=sys.stderr)
        return 1

    text = render(args.rules_dir)
    if args.write:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text, encoding="utf-8")
        print(f"gen_copilot_instructions: wrote {args.out} ({len(text)} bytes)")
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Generate GitHub Copilot prompt-file artifacts from steer's skills.

steer's skills are authored as ``plugins/steer/skills/<name>/SKILL.md``. On the
Copilot **CLI** they load via the Copilot plugin manifest
(``plugins/steer/.github/plugin/plugin.json``). Copilot in **VS Code** does not
use that CLI plugin marketplace, so the skills reach VS Code a different way: as
*prompt files* (``.github/prompts/<name>.prompt.md``), which VS Code surfaces as
``/<name>`` slash-commands in Copilot Chat.

This script renders one prompt file per user-invocable skill into
``plugins/steer/templates/github/prompts/steer-<name>.prompt.md`` — the committed
artifacts ``/steer:init`` / ``/steer:adopt`` install into a consumer repo's
``.github/prompts/``. The single source of truth stays the ``SKILL.md`` files;
``check_copilot_prompts.py`` fails the build if a committed artifact drifts.

The prompt files are deliberately **intent capsules**, not copies of the skill
bodies: skill bodies reference ``${CLAUDE_PLUGIN_ROOT}`` paths and ``/steer:``
invocation, neither of which resolves in a repo-committed VS Code prompt file.
Each capsule carries the skill's purpose, when-to-use, and arguments so Copilot
can drive the same workflow on top of the always-on standards already loaded from
``.github/copilot-instructions.md``.

Run from the repo root::

    uv run python scripts/gen_copilot_prompts.py            # list what would be written
    uv run python scripts/gen_copilot_prompts.py --write    # write the artifacts
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import yaml

SKILLS_DIR = Path("plugins/steer/skills")
PROMPTS_DIR = Path("plugins/steer/templates/github/prompts")
PROMPT_PREFIX = "steer-"


def _parse_frontmatter(text: str) -> dict | None:
    """Return the YAML frontmatter mapping, or None if absent/malformed."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    for idx in range(1, len(lines)):
        if lines[idx].strip() == "---":
            try:
                data = yaml.safe_load("\n".join(lines[1:idx]))
            except yaml.YAMLError:
                return None
            return data if isinstance(data, dict) else None
    return None


def iter_skills(skills_dir: Path) -> list[tuple[str, dict]]:
    """Return (name, frontmatter) for every user-invocable skill, name-sorted.

    Skills with ``user-invocable: false`` (internal one-shot helpers like
    ``spec-scaffold`` and ``tracker-sync``) are excluded — they are not direct
    entry points and should not appear as VS Code slash-commands.
    """
    out: list[tuple[str, dict]] = []
    if not skills_dir.is_dir():
        return out
    for skill_dir in sorted(p for p in skills_dir.glob("*") if p.is_dir()):
        skill_md = skill_dir / "SKILL.md"
        if not skill_md.is_file():
            continue
        fm = _parse_frontmatter(skill_md.read_text(encoding="utf-8"))
        if not fm or not fm.get("name"):
            continue
        if fm.get("user-invocable") is False:
            continue
        out.append((str(fm["name"]), fm))
    return out


def render_prompt(name: str, fm: dict) -> str:
    """Render one VS Code prompt-file artifact for a skill (intent capsule)."""
    description = str(fm.get("description", "")).strip()
    when_to_use = str(fm.get("when_to_use", "")).strip()
    argument_hint = str(fm.get("argument-hint", "")).strip()

    # YAML frontmatter — safe-dumped so descriptions with colons/quotes/em-dashes
    # are escaped correctly; width is unbounded so long descriptions stay on one
    # line (VS Code reads `mode` and `description` from here).
    front = yaml.safe_dump(
        {"mode": "agent", "description": description},
        default_flow_style=False,
        sort_keys=False,
        allow_unicode=True,
        width=10**9,
    ).rstrip("\n")

    header = (
        f"<!-- Generated from the steer plugin's skills/{name}/SKILL.md — do not "
        f"edit by hand. Refresh with: mise run gen:copilot (or re-run "
        f"/steer:init's Copilot step). -->"
    )

    body = [
        header,
        "",
        f"This mirrors steer's `/steer:{name}` workflow for GitHub Copilot in VS Code.",
        "",
        f"**Purpose.** {description}",
        "",
        f"**When to use.** {when_to_use}",
    ]
    if argument_hint:
        body += ["", f"**Arguments.** {argument_hint}"]
    body += [
        "",
        "Apply the org engineering standards already loaded from "
        "`.github/copilot-instructions.md`. The authoritative procedure lives in "
        f"the steer plugin (in Claude Code, `/steer:{name}`); this capsule carries "
        "the intent so Copilot can drive the same workflow here.",
    ]
    return f"---\n{front}\n---\n\n" + "\n".join(body).rstrip("\n") + "\n"


def render_all(skills_dir: Path = SKILLS_DIR) -> dict[str, str]:
    """Return {artifact_filename: rendered_text} for every user-invocable skill."""
    return {
        f"{PROMPT_PREFIX}{name}.prompt.md": render_prompt(name, fm)
        for name, fm in iter_skills(skills_dir)
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Generate the Copilot prompt-file artifacts.")
    parser.add_argument(
        "--write",
        action="store_true",
        help=f"Write the artifacts to {PROMPTS_DIR} (default: list filenames to stdout).",
    )
    parser.add_argument(
        "--skills-dir",
        type=Path,
        default=SKILLS_DIR,
        help=f"Skills directory to render (default: {SKILLS_DIR}).",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=PROMPTS_DIR,
        help=f"Output directory when --write is set (default: {PROMPTS_DIR}).",
    )
    args = parser.parse_args(argv)

    if not args.skills_dir.is_dir():
        print(f"gen_copilot_prompts: skills dir not found: {args.skills_dir}", file=sys.stderr)
        return 1

    artifacts = render_all(args.skills_dir)
    if not artifacts:
        print(
            f"gen_copilot_prompts: no user-invocable skills in {args.skills_dir}", file=sys.stderr
        )
        return 1

    if args.write:
        args.out_dir.mkdir(parents=True, exist_ok=True)
        # Prune stale artifacts (a skill renamed/removed/made internal) so the
        # committed set always matches the current skills exactly.
        keep = set(artifacts)
        for existing in args.out_dir.glob(f"{PROMPT_PREFIX}*.prompt.md"):
            if existing.name not in keep:
                existing.unlink()
        for filename, text in artifacts.items():
            (args.out_dir / filename).write_text(text, encoding="utf-8")
        print(f"gen_copilot_prompts: wrote {len(artifacts)} prompt file(s) to {args.out_dir}")
    else:
        for filename in artifacts:
            print(filename)
    return 0


if __name__ == "__main__":
    sys.exit(main())

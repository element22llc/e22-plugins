#!/usr/bin/env python3
"""Generate GitHub Copilot custom-agent artifacts from steer's subagents.

steer's subagents live at ``plugins/steer/agents/<name>.md`` and reach Claude
Code as plugin-scoped subagents (spawned by ``/steer:audit`` and
``/steer:work --reviewed``). GitHub Copilot in VS Code has a native analog —
**custom agents** (``.github/agents/<name>.agent.md``, formerly "custom chat
modes"/``.chatmode.md``), selectable in the Chat agent picker and invocable as
subagents. This script ports each steer subagent into that format so a Copilot
teammate gets the same specialized, tool-restricted worker (e.g. the read-only
``steer-reviewer``) rather than only the always-on standards.

It renders one artifact per subagent into
``plugins/steer/templates/github/agents/<name>.agent.md`` — the committed files
``/steer:init`` / ``/steer:adopt`` install into a consumer repo's
``.github/agents/``. The single source of truth stays the ``agents/*.md`` files;
``check_copilot_agents.py`` fails the build if a committed artifact drifts.

Claude tool names (``Read``/``Grep``/``Glob``/``Bash``/``Edit``/``Write``) do not
exist in VS Code, so the subagent's ``tools`` frontmatter is mapped to Copilot's
built-in tool *set names* (a read-only agent maps to ``codebase``/``search``/
``usages`` with no edit/run tools). ``model: inherit`` maps to omitting ``model``
(the agent inherits the picker's model).

Run from the repo root::

    uv run python scripts/gen_copilot_agents.py            # list what would be written
    uv run python scripts/gen_copilot_agents.py --write    # write the artifacts
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import yaml

AGENTS_DIR = Path("plugins/steer/agents")
OUT_DIR = Path("plugins/steer/templates/github/agents")

# Map each Claude subagent tool to the equivalent VS Code Copilot built-in tool
# set. Only read-only tools are mapped today (the sole shipped subagent,
# steer-reviewer, is read-only by construction); add edit/run mappings here if a
# future subagent needs them.
_TOOL_MAP: dict[str, list[str]] = {
    "Read": ["codebase"],
    "Grep": ["search"],
    "Glob": ["search"],
    "LS": ["search"],
    "Edit": ["editFiles"],
    "Write": ["editFiles"],
    "MultiEdit": ["editFiles"],
    "Bash": ["runCommands"],
}


def _parse_frontmatter(text: str) -> tuple[dict | None, str]:
    """Return (frontmatter mapping or None, body-after-frontmatter)."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None, text
    for idx in range(1, len(lines)):
        if lines[idx].strip() == "---":
            try:
                data = yaml.safe_load("\n".join(lines[1:idx]))
            except yaml.YAMLError:
                return None, text
            body = "\n".join(lines[idx + 1 :])
            return (data if isinstance(data, dict) else None), body
    return None, text


def _copilot_tools(claude_tools: str) -> list[str]:
    """Translate a Claude ``tools:`` value into Copilot built-in tool set names."""
    out: list[str] = []
    for raw in str(claude_tools).split(","):
        tool = raw.strip()
        for mapped in _TOOL_MAP.get(tool, []):
            if mapped not in out:
                out.append(mapped)
    return out


def iter_agents(agents_dir: Path) -> list[tuple[str, dict, str]]:
    """Return (name, frontmatter, body) for every subagent, name-sorted."""
    out: list[tuple[str, dict, str]] = []
    if not agents_dir.is_dir():
        return out
    for agent_md in sorted(agents_dir.glob("*.md")):
        fm, body = _parse_frontmatter(agent_md.read_text(encoding="utf-8"))
        if not fm or not fm.get("name"):
            continue
        out.append((str(fm["name"]), fm, body))
    return out


def render_agent(name: str, fm: dict, body: str) -> str:
    """Render one VS Code custom-agent artifact from a steer subagent."""
    description = " ".join(str(fm.get("description", "")).split()).strip()

    front: dict[str, object] = {"description": description}
    tools = _copilot_tools(fm.get("tools", "")) if fm.get("tools") else []
    if tools:
        front["tools"] = tools
    model = str(fm.get("model", "")).strip()
    if model and model != "inherit":
        front["model"] = model

    front_yaml = yaml.safe_dump(
        front,
        default_flow_style=False,
        sort_keys=False,
        allow_unicode=True,
        width=10**9,
    ).rstrip("\n")

    header = (
        f"<!-- Generated from the steer plugin's agents/{name}.md — do not edit by "
        f"hand. Refresh with: mise run gen:copilot (or re-run /steer:init's Copilot "
        f"step). -->"
    )

    # The source body is Claude-oriented; rewrite /steer:<skill> references to the
    # /steer-<skill> prompt-file names Copilot surfaces in VS Code so cross-links
    # resolve. The tool-name prose ("Read, Grep, Glob") stays descriptive of the
    # read-only intent; the frontmatter `tools` is what actually constrains Copilot.
    ported = re.sub(r"/steer:([a-z][a-z0-9-]*)", r"/steer-\1", body).strip()

    tools_note = (
        f" In VS Code its tools are {', '.join(f'`{t}`' for t in tools)} (read-only) —"
        " the Claude tool names in the body below (`Read`/`Grep`/`Glob`) map to these."
        if tools
        else ""
    )
    preamble = (
        "This is the GitHub Copilot (VS Code) port of steer's "
        f"`{name}` subagent. Select it from the Chat agent picker, or the "
        "`/steer-audit` prompt will delegate to it. Apply the org engineering "
        f"standards already loaded from `.github/copilot-instructions.md`.{tools_note}"
    )

    return f"{header}\n---\n{front_yaml}\n---\n\n{preamble}\n\n{ported}\n"


def render_all(agents_dir: Path = AGENTS_DIR) -> dict[str, str]:
    """Return {artifact_filename: rendered_text} for every subagent."""
    return {
        f"{name}.agent.md": render_agent(name, fm, body)
        for name, fm, body in iter_agents(agents_dir)
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Generate the Copilot custom-agent artifacts.")
    parser.add_argument(
        "--write",
        action="store_true",
        help=f"Write the artifacts to {OUT_DIR} (default: list filenames to stdout).",
    )
    parser.add_argument(
        "--agents-dir",
        type=Path,
        default=AGENTS_DIR,
        help=f"Subagents directory to render (default: {AGENTS_DIR}).",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=OUT_DIR,
        help=f"Output directory when --write is set (default: {OUT_DIR}).",
    )
    args = parser.parse_args(argv)

    if not args.agents_dir.is_dir():
        print(f"gen_copilot_agents: agents dir not found: {args.agents_dir}", file=sys.stderr)
        return 1

    artifacts = render_all(args.agents_dir)
    if not artifacts:
        print(f"gen_copilot_agents: no subagents in {args.agents_dir}", file=sys.stderr)
        return 1

    if args.write:
        args.out_dir.mkdir(parents=True, exist_ok=True)
        # Prune stale artifacts (a subagent renamed/removed) so the committed set
        # always matches the current subagents exactly.
        keep = set(artifacts)
        for existing in args.out_dir.glob("*.agent.md"):
            if existing.name not in keep:
                existing.unlink()
        for filename, text in artifacts.items():
            (args.out_dir / filename).write_text(text, encoding="utf-8")
        print(f"gen_copilot_agents: wrote {len(artifacts)} agent file(s) to {args.out_dir}")
    else:
        for filename in artifacts:
            print(filename)
    return 0


if __name__ == "__main__":
    sys.exit(main())

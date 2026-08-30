#!/usr/bin/env python3
"""Generate the cross-tool ``.agents/skills/`` tree from steer's skills.

steer's skills are authored as ``plugins/steer/skills/<name>/SKILL.md`` for
Claude Code. Since the `Agent Skills <https://agentskills.io>`_ format became an
open standard, that same ``SKILL.md`` layout is read natively by GitHub Copilot
(CLI, VS Code, JetBrains, the cloud coding agent and code review), Cursor, Gemini
CLI and Codex — all of which discover project skills in ``.agents/skills/``.

So the skills no longer need a per-surface *translation*. This script renders one
**portable copy of the real skill** per skill into
``plugins/steer/templates/agents/skills/steer-<name>/`` — the committed artifacts
``/steer:init`` / ``/steer:adopt`` install into a consumer repo's
``.agents/skills/``, and ``/steer:sync`` refreshes. It replaces
``gen_copilot_prompts.py``, which rendered lossy *intent capsules* (purpose,
when-to-use and arguments, then "the fully authored procedure lives in the steer
plugin" — pointing at a file the reader could not open).

Three things have to be rewritten for a body to work outside Claude Code.

**1. Intra-skill asset references become relative.** ``${CLAUDE_PLUGIN_ROOT}/
skills/<self>/modes/code.md`` becomes ``modes/code.md``: the supporting files are
copied in alongside ``SKILL.md``, which is exactly the spec's ``references/``/
``scripts/`` colocation convention.

**2. Shared-bundle references become URLs into the public plugin repo.** The
deep reference prose (``templates/reference/*``), spec templates
(``templates/spec/*``) and the two helper scripts live outside any one skill and
are shared by many. Vendoring them would put several hundred KB — ``MIGRATIONS.md``
alone is the largest single file — into every consumer repo, so they are rewritten
to ``blob/main`` URLs on the public marketplace repo and fetched on demand.

.. warning::

   Two known defects in this rewrite are open, not fixed — see the pre-release
   audit residue. (a) ``BLOB_BASE`` points at GitHub's HTML ``blob/`` view, so a
   fetch returns a rendered page rather than file content; ``raw.githubusercontent
   .com`` is the form that returns bytes. (b) The rewrite is applied
   unconditionally, including inside runnable command lines, so the generated tree
   contains ``sh "https://…"`` invocations that cannot execute on any surface.
   Fixing (b) is a design question — vendor the few helper scripts, fetch them to a
   temp file first, or drop those command blocks from the portable copy — so it is
   deliberately not patched here.

*Why ``main`` and not the released tag:* pinning would rewrite all 26 skills on
every version bump, adding a regeneration step to each release for prose that is
guidance rather than contract. A consumer whose tree is current (which is exactly
what ``/steer:sync``'s ``agent-surface-current`` capability asserts) is reading
``main``-era skills anyway; one whose tree is stale has stale bodies around the
link regardless.

**3. Invocation is renamed.** ``/steer:<skill>`` is Claude Code's plugin
namespacing. In a ``.agents/skills/steer-<name>/`` tree the slash name is the
directory name, so cross-references become ``/steer-<skill>`` — the same names
the retired VS Code prompt files used, so nothing a teammate types changes.

Frontmatter is narrowed to what travels. ``name`` is prefixed to match the
directory (the spec requires it); ``when_to_use`` is folded into the body as a
"When to use" line rather than kept as a non-spec key; and ``allowed-tools`` /
``disallowed-tools`` are dropped, because their values are Claude tool syntax
(``Bash(git status *)``, ``EnterWorktree``) that means nothing to another agent —
carrying them across risks a wrong grant, and per ``AUTHORING.md`` the read-only
contract those fields express is a **prose invariant** in the body, which does
travel. ``argument-hint`` and ``user-invocable`` are kept: both are purely
declarative and VS Code reads them.

Run from the repo root::

    uv run python scripts/gen_agent_skills.py            # list what would change
    uv run python scripts/gen_agent_skills.py --write    # write the artifacts
"""

from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path

import yaml

SKILLS_DIR = Path("plugins/steer/skills")
OUT_DIR = Path("plugins/steer/templates/agents/skills")

# Where a shared plugin asset is readable on the public marketplace repo. See the
# module docstring for why this tracks `main` rather than the released tag.
BLOB_BASE = "https://github.com/element22llc/e22-plugins/blob/main/plugins/steer"

# Skill directory names are prefixed so the cross-tool slash command is
# `/steer-<name>`, matching what the retired VS Code prompt files exposed.
PREFIX = "steer-"

# Frontmatter keys carried into the portable copy, in emission order. Everything
# else is dropped or folded into the body — see the module docstring.
KEEP_KEYS = ("name", "description", "argument-hint", "user-invocable")

BANNER = (
    "<!-- Generated from the steer plugin's skills/{name}/SKILL.md — do not edit by hand.\n"
    "     Refresh with /steer:sync from Claude Code in a managed repo, or\n"
    "     `mise run gen:copilot` in the plugin repo. Authored for Claude Code and\n"
    "     rendered here in the cross-tool Agent Skills format (agentskills.io) that\n"
    "     Copilot, Cursor, Gemini CLI and Codex read from .agents/skills/. -->"
)

# Claude Code enforces a read-only skill by removing tools from the pool via
# `disallowed-tools`. Nothing enforces that here, and several bodies state the
# restriction as a fact ("the in-place edit tools are unavailable while this skill
# runs"). Leaving that unqualified would be a lie on this surface, so a skill that
# was frontmatter-restricted upstream carries the restriction as a standing
# instruction instead.
RESTRICTION_NOTE = (
    "> **Read-only on this surface — enforced by instruction, not by tooling.**\n"
    "> In Claude Code this skill runs with `{tools}` removed from the tool pool, so\n"
    "> the restriction below is mechanical. No other agent has that mechanism: here\n"
    "> it is a hard instruction. Treat those capabilities as unavailable for the\n"
    '> whole run, and read any claim below that they "are unavailable" as a rule\n'
    "> you must keep rather than a guarantee you can rely on."
)

_PLUGIN_ROOT = re.compile(r"\$\{CLAUDE_PLUGIN_ROOT\}(/[A-Za-z0-9._/-]*)?")
_STEER_REF = re.compile(r"/steer:([a-z][a-z0-9-]*)")


def _split_frontmatter(text: str) -> tuple[dict, str]:
    """Return (frontmatter mapping, body) for a ``SKILL.md``."""
    if not text.startswith("---\n"):
        raise ValueError("SKILL.md does not open with YAML frontmatter")
    end = text.index("\n---\n", 3)
    return yaml.safe_load(text[4:end]) or {}, text[end + 5 :].lstrip("\n")


def rewrite_refs(text: str, skill: str) -> str:
    """Rewrite plugin-root paths and `/steer:` invocations for the portable tree."""

    def plugin_root(match: re.Match[str]) -> str:
        path = (match.group(1) or "").lstrip("/")
        # Intra-skill asset -> relative path; the file is copied in alongside.
        own = f"skills/{skill}/"
        if path.startswith(own):
            return path[len(own) :]
        # Anything else (shared bundle, another skill, or a bare root reference)
        # -> a URL into the public plugin repo.
        return f"{BLOB_BASE}/{path}" if path else BLOB_BASE

    text = _PLUGIN_ROOT.sub(plugin_root, text)
    return _STEER_REF.sub(rf"/{PREFIX}\1", text)


def render(skill_dir: Path) -> str:
    """Return the portable ``SKILL.md`` text for one authored skill."""
    skill = skill_dir.name
    meta, body = _split_frontmatter((skill_dir / "SKILL.md").read_text(encoding="utf-8"))

    out: dict[str, object] = {}
    for key in KEEP_KEYS:
        if key not in meta:
            continue
        value = meta[key]
        if key == "name":
            value = f"{PREFIX}{value}"
        elif isinstance(value, str):
            # `description` is prose like any other and routinely cites sibling
            # skills — it needs the same invocation rewrite the body gets, or the
            # skill listing advertises commands this surface does not offer.
            value = rewrite_refs(value, skill)
        out[key] = value
    out.setdefault("name", f"{PREFIX}{skill}")

    front = yaml.safe_dump(out, sort_keys=False, allow_unicode=True, width=10_000).rstrip("\n")

    parts = [f"---\n{front}\n---", BANNER.format(name=skill)]
    # `when_to_use` is not a spec field; keep the routing signal as prose.
    when = str(meta.get("when_to_use", "")).strip()
    if when:
        parts.append(f"**When to use.** {rewrite_refs(' '.join(when.split()), skill)}")
    blocked = meta.get("disallowed-tools")
    if blocked:
        if isinstance(blocked, str):
            blocked = re.split(r"[,\s]+", blocked.strip())
        parts.append(RESTRICTION_NOTE.format(tools="`, `".join(t for t in blocked if t)))
    parts.append(rewrite_refs(body, skill).strip())
    return "\n\n".join(parts) + "\n"


def supporting_files(skill_dir: Path) -> list[Path]:
    """Every file in a skill directory other than ``SKILL.md``, sorted."""
    return sorted(p for p in skill_dir.rglob("*") if p.is_file() and p.name != "SKILL.md")


def build(skills_dir: Path = SKILLS_DIR) -> dict[Path, str]:
    """Map every output path to its text, for the whole portable tree."""
    tree: dict[Path, str] = {}
    for skill_dir in sorted(p for p in skills_dir.iterdir() if (p / "SKILL.md").is_file()):
        skill = skill_dir.name
        dest = Path(f"{PREFIX}{skill}")
        tree[dest / "SKILL.md"] = render(skill_dir)
        for src in supporting_files(skill_dir):
            rel = src.relative_to(skill_dir)
            tree[dest / rel] = rewrite_refs(src.read_text(encoding="utf-8"), skill)
    return tree


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Generate the cross-tool .agents/skills tree.")
    parser.add_argument("--write", action="store_true", help=f"Write the tree to {OUT_DIR}.")
    parser.add_argument("--skills-dir", type=Path, default=SKILLS_DIR)
    parser.add_argument("--out", type=Path, default=OUT_DIR)
    args = parser.parse_args(argv)

    if not args.skills_dir.is_dir():
        print(f"gen_agent_skills: skills dir not found: {args.skills_dir}", file=sys.stderr)
        return 1

    tree = build(args.skills_dir)
    if not args.write:
        for rel in sorted(tree):
            print(f"{len(tree[rel]):7d}  {args.out / rel}")
        print(
            f"gen_agent_skills: {len(tree)} files across {len({r.parts[0] for r in tree})} skills"
        )
        return 0

    if args.out.exists():
        shutil.rmtree(args.out)  # stale skills must not survive a rename or removal
    for rel, text in tree.items():
        target = args.out / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")
    print(f"gen_agent_skills: wrote {len(tree)} files to {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Documentation-site structural + sync checks for the e22-plugins docs.

Lightweight (stdlib + pyyaml only — no Zensical toolchain), so it runs as part of
``mise run ci`` without pulling in the ``docs`` dependency-group. The strict
link/render build stays a separate, local-only gate (``mise run docs:build``).

Checks:

1. **Skill inventory** — every skill under ``plugins/steer/skills/`` appears in
   ``docs/reference/skills.md`` as ``/steer:<skill>`` (mirrors the README
   inventory check in ``check_standards.py``). This is what keeps the generated
   reference page honest.
2. **Nav integrity** — every file referenced in ``mkdocs.yml`` ``nav:`` exists
   under ``docs/``.
3. **No orphans** — every ``docs/**/*.md`` is reachable from the nav.
4. **Internal links resolve** — relative markdown links in docs point at real
   files.
5. **Namespace hygiene** — every ``/steer:<skill>`` reference resolves to a real
   skill and no stale ``/e22-*`` reference survives.

Usage::

    uv run python scripts/validate_docs.py

Exit status is 0 when clean, 1 when any check fails.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

DOCS_DIR = Path("docs")
MKDOCS_YML = Path("mkdocs.yml")
SKILLS_DIR = Path("plugins/steer/skills")
SKILLS_REF = DOCS_DIR / "reference/skills.md"
AGENTS_DIR = Path("plugins/steer/agents")
AGENTS_REF = DOCS_DIR / "reference/agents.md"

# Reuse the namespace-hygiene patterns from check_standards.py so docs are held
# to the same standard as rules/skills/templates.
_NS_RE = re.compile(r"/steer:([a-z][a-z-]*)")
_STALE_E22_RE = re.compile(r"(?<![A-Za-z0-9])/e22-[a-z][a-z-]*")
# Markdown inline link target: [text](target)
_LINK_RE = re.compile(r"\[[^\]]*\]\(([^)]+)\)")


def agent_names() -> set[str]:
    if not AGENTS_DIR.is_dir():
        return set()
    return {md.stem for md in AGENTS_DIR.glob("*.md")}


def skill_names() -> set[str]:
    if not SKILLS_DIR.is_dir():
        return set()
    return {d.name for d in SKILLS_DIR.iterdir() if (d / "SKILL.md").is_file()}


def _iter_docs():
    """All published docs. Non-page content (the ``docs-templates/`` page
    scaffolds and the repo-root ``AUTHORING.md``) lives outside ``docs/``, so
    every ``*.md`` under ``docs/`` is a real site page."""
    yield from sorted(DOCS_DIR.rglob("*.md"))


def _load_nav_paths(errors: list[str]) -> set[str]:
    """Return nav entries as docs-relative posix paths (e.g. 'reference/skills.md')."""
    if not MKDOCS_YML.is_file():
        errors.append(f"{MKDOCS_YML}: missing")
        return set()
    # mkdocs.yml uses the `!!python/name:...` tag for the mermaid superfence
    # formatter; ignore unknown python tags rather than fail to parse.
    loader = yaml.SafeLoader
    loader.add_multi_constructor("tag:yaml.org,2002:python/name:", lambda _l, _s, _n: None)
    try:
        config = yaml.load(MKDOCS_YML.read_text(encoding="utf-8"), Loader=loader)
    except yaml.YAMLError as exc:
        errors.append(f"{MKDOCS_YML}: invalid YAML ({exc})")
        return set()

    paths: set[str] = set()

    def walk(node) -> None:
        if isinstance(node, str):
            if node.endswith(".md"):
                paths.add(node)
        elif isinstance(node, list):
            for item in node:
                walk(item)
        elif isinstance(node, dict):
            for value in node.values():
                walk(value)

    walk((config or {}).get("nav", []))
    return paths


# --- check 1: skill inventory present in reference/skills.md ----------------


def check_skill_inventory(errors: list[str], skills: set[str]) -> None:
    if not SKILLS_REF.is_file():
        errors.append(f"{SKILLS_REF}: missing — skills reference page is required")
        return
    text = SKILLS_REF.read_text(encoding="utf-8")
    missing = {s for s in skills if not re.search(rf"/steer:{re.escape(s)}(?![a-z-])", text)}
    if missing:
        errors.append(
            f"{SKILLS_REF}: skills reference missing {sorted(missing)} "
            "(run /plugin-docs to reconcile)"
        )


# --- check 1b: agent inventory present in reference/agents.md ---------------


def check_agent_inventory(errors: list[str], agents: set[str]) -> None:
    if not agents:
        return  # no shipped subagents — nothing to document
    if not AGENTS_REF.is_file():
        errors.append(
            f"{AGENTS_REF}: missing — subagents reference page is required when "
            f"{AGENTS_DIR}/ is non-empty"
        )
        return
    text = AGENTS_REF.read_text(encoding="utf-8")
    missing = {a for a in agents if not re.search(rf"`{re.escape(a)}`", text)}
    if missing:
        errors.append(
            f"{AGENTS_REF}: subagents reference missing {sorted(missing)} "
            "(run /plugin-docs to reconcile)"
        )


# --- check 2 + 3: nav integrity and orphans ---------------------------------


def check_nav(errors: list[str], nav_paths: set[str]) -> None:
    for rel in sorted(nav_paths):
        if not (DOCS_DIR / rel).is_file():
            errors.append(f"{MKDOCS_YML}: nav entry '{rel}' has no file under {DOCS_DIR}/")

    on_disk = {md.relative_to(DOCS_DIR).as_posix() for md in _iter_docs()}
    orphans = on_disk - nav_paths
    for rel in sorted(orphans):
        errors.append(f"{DOCS_DIR / rel}: page is not referenced in {MKDOCS_YML} nav")


# --- check 4: internal links resolve ----------------------------------------


def check_links(errors: list[str]) -> None:
    for md in _iter_docs():
        text = md.read_text(encoding="utf-8")
        for m in _LINK_RE.finditer(text):
            target = m.group(1).strip()
            # Skip external, absolute, mailto, and pure-anchor links.
            if target.startswith(("http://", "https://", "mailto:", "#", "/")) or "://" in target:
                continue
            path_part = target.split("#", 1)[0].split("?", 1)[0]
            if not path_part:
                continue
            resolved = (md.parent / path_part).resolve()
            if not resolved.exists():
                errors.append(f"{md}: broken link '{target}'")


# --- check 5: namespace hygiene ---------------------------------------------


def check_namespace(errors: list[str], skills: set[str]) -> None:
    for md in _iter_docs():
        for i, line in enumerate(md.read_text(encoding="utf-8").splitlines(), 1):
            for m in _STALE_E22_RE.finditer(line):
                errors.append(f"{md}:{i}: stale '{m.group(0)}' — use the '/steer:' namespace")
            for m in _NS_RE.finditer(line):
                # `/steer:<skill>` placeholders in templates are excluded already.
                if m.group(1) not in skills:
                    errors.append(f"{md}:{i}: '/steer:{m.group(1)}' does not resolve to a skill")


def run_checks(errors: list[str]) -> None:
    skills = skill_names()
    if not skills:
        errors.append(f"{SKILLS_DIR}: no skills found (run from the repo root)")
    nav_paths = _load_nav_paths(errors)
    check_skill_inventory(errors, skills)
    check_agent_inventory(errors, agent_names())
    check_nav(errors, nav_paths)
    check_links(errors)
    check_namespace(errors, skills)


def main() -> int:
    errors: list[str] = []
    run_checks(errors)
    if errors:
        print(f"validate_docs: {len(errors)} problem(s) found:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        print(
            "  -> Run /plugin-docs to reconcile docs/ with the plugin, "
            "then re-stage docs/ and commit (docs + code land together).",
            file=sys.stderr,
        )
        return 1
    print("validate_docs: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Plugin hygiene checks for the steer Claude Code plugin.

Deterministic, dependency-light structural validation that complements
`claude plugin validate` (the authoritative plugin gate). This script enforces
the conventions that `claude plugin validate` does not know about:

- ``plugin.json`` exists and is well-formed;
- every skill's YAML frontmatter parses and carries the required metadata;
- every command's YAML frontmatter parses and carries a description;
- skill names are unique and match their directory;
- command names are unique and (optionally) wrap a real skill;
- no unresolved placeholders (``TODO``, ``FIXME``, ``[Replace``) leak into
  authored content;
- relative markdown links inside the plugin resolve to real files.

Scope notes (kept deliberately narrow so the checks stay honest):

- The ``templates/`` subtree is *payload* — content materialized into product
  repos — so it is allowed to carry placeholders and product-repo-relative
  links. Placeholder and link checks therefore skip it (link checks still cover
  ``templates/reference/``, whose cross-links must resolve within the plugin).
- ``init`` documents the ``[Replace …]`` placeholder vocabulary, so those
  two files are exempt from the placeholder scan.

Run from the repo root::

    uv run python scripts/check_plugin.py

Exit status is 0 when clean, 1 when any check fails.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

import yaml

PLUGIN_ROOT = Path("plugins/steer")

FORBIDDEN_PLACEHOLDERS = ["[Replace", "TODO", "FIXME"]
REQUIRED_SKILL_FRONTMATTER = ["name", "description", "when_to_use"]
REQUIRED_AGENT_FRONTMATTER = ["name", "description"]

# Claude Code concatenates `description` + `when_to_use` into the skill listing
# used for routing and truncates the combined text at this many characters (the
# documented default `skillListingMaxDescChars`). Past the cap the trailing text
# is silently dropped — so a paragraph-length description crowds out its own
# `when_to_use` trigger phrases. Keep descriptions to purpose + primary trigger.
SKILL_LISTING_CHAR_CAP = 1536
# Frontmatter fields a plugin-scoped subagent silently ignores (Claude Code drops
# them for security). Authoring one is a bug — fail loudly instead.
FORBIDDEN_AGENT_FRONTMATTER = ["hooks", "mcpServers", "permissionMode"]

# Dirs (relative to PLUGIN_ROOT) whose authored markdown must be placeholder-free.
# templates/ is excluded: it is meant to be instantiated and legitimately holds
# placeholders like [Replace …] and [Product Name]. (The legacy commands/ dir was
# removed — skills are namespaced; see check_standards.py.)
PLACEHOLDER_SCAN_DIRS = ["skills", "rules", "agents"]

# Files (relative to PLUGIN_ROOT) exempt from the placeholder scan because they
# document the placeholder vocabulary itself.
PLACEHOLDER_ALLOWLIST = {
    "skills/init/SKILL.md",
}

# Dirs (relative to PLUGIN_ROOT) whose relative markdown links must resolve.
# templates/scaffold and templates/spec describe the *product* repo layout
# (./spec/vision.md, ../apps/README.md, …) and are intentionally not checked.
LINK_SCAN_DIRS = ["skills", "rules", "templates/reference"]

# Optional: client names that must never appear when --client-agnostic is set.
# Populated per engagement; empty by default so the mode is a no-op until used.
CLIENT_SPECIFIC_TERMS: list[str] = []

_LINK_RE = re.compile(r"\[[^\]]*\]\(([^)]+)\)")


def parse_frontmatter(text: str) -> tuple[dict | None, str | None]:
    """Return (frontmatter_dict, error). error is None on success.

    A missing or malformed ``---`` fenced YAML block is an error. A block that
    parses to something other than a mapping is also an error.
    """
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None, "missing YAML frontmatter (no opening '---')"
    for idx in range(1, len(lines)):
        if lines[idx].strip() == "---":
            block = "\n".join(lines[1:idx])
            try:
                data = yaml.safe_load(block)
            except yaml.YAMLError as exc:
                return None, f"malformed YAML frontmatter: {exc}"
            if not isinstance(data, dict):
                return None, "frontmatter is not a mapping"
            return data, None
    return None, "unterminated YAML frontmatter (no closing '---')"


def _iter_markdown(base: Path) -> list[Path]:
    return sorted(base.rglob("*.md")) if base.is_dir() else []


def check_plugin_json(root: Path, errors: list[str]) -> None:
    path = root / ".claude-plugin" / "plugin.json"
    if not path.is_file():
        errors.append(f"{path}: plugin.json is missing")
        return
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        errors.append(f"{path}: invalid JSON ({exc})")
        return
    for key in ("name", "version"):
        if not data.get(key):
            errors.append(f"{path}: missing required key '{key}'")


def check_copilot_version_sync(root: Path, errors: list[str]) -> None:
    """The Copilot manifests must carry the same version as the plugin.

    steer is published to two marketplaces from one source of truth — the Claude
    ``.claude-plugin/plugin.json`` ``version`` (the Claude ``marketplace.json``
    carries no per-plugin version). The Copilot CLI manifests
    (``.github/plugin/plugin.json`` under the plugin root, and the repo-root
    ``.github/plugin/marketplace.json``) each declare their own version and so can
    silently drift from a release. This check anchors both to the plugin version.
    """
    claude_manifest = root / ".claude-plugin" / "plugin.json"
    if not claude_manifest.is_file():
        return  # check_plugin_json already reports the missing source of truth.
    try:
        src_version = json.loads(claude_manifest.read_text(encoding="utf-8")).get("version")
    except json.JSONDecodeError:
        return  # check_plugin_json already reports the malformed source of truth.
    if not src_version:
        return  # check_plugin_json already reports the missing version.

    # Copilot plugin manifest (lives under the plugin root).
    copilot_plugin = root / ".github" / "plugin" / "plugin.json"
    if copilot_plugin.is_file():
        try:
            version = json.loads(copilot_plugin.read_text(encoding="utf-8")).get("version")
            if version != src_version:
                errors.append(
                    f"{copilot_plugin}: version '{version}' != plugin version "
                    f"'{src_version}' (Copilot manifest drifted — keep them in sync at release)"
                )
        except json.JSONDecodeError as exc:
            errors.append(f"{copilot_plugin}: invalid JSON ({exc})")

    # Copilot marketplace manifest (lives at the repo root, two levels above the
    # plugin root — absent in unit tests with a temp root, in which case skip).
    copilot_marketplace = root.parent.parent / ".github" / "plugin" / "marketplace.json"
    if copilot_marketplace.is_file():
        try:
            data = json.loads(copilot_marketplace.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            errors.append(f"{copilot_marketplace}: invalid JSON ({exc})")
            return
        for entry in data.get("plugins", []):
            if entry.get("name") == "steer":
                version = entry.get("version")
                if version != src_version:
                    errors.append(
                        f"{copilot_marketplace}: steer entry version '{version}' != "
                        f"plugin version '{src_version}' (Copilot marketplace drifted)"
                    )


def check_skills(root: Path, errors: list[str], require_when_to_use: bool) -> None:
    required = list(REQUIRED_SKILL_FRONTMATTER)
    if not require_when_to_use and "when_to_use" in required:
        required.remove("when_to_use")

    seen_names: dict[str, Path] = {}
    skills_dir = root / "skills"
    for skill_dir in sorted(p for p in skills_dir.glob("*") if p.is_dir()):
        skill_md = skill_dir / "SKILL.md"
        if not skill_md.is_file():
            errors.append(f"{skill_dir}: missing SKILL.md")
            continue
        fm, err = parse_frontmatter(skill_md.read_text(encoding="utf-8"))
        if err:
            errors.append(f"{skill_md}: {err}")
            continue
        for key in required:
            value = fm.get(key)
            if not (isinstance(value, str) and value.strip()):
                errors.append(f"{skill_md}: missing or empty frontmatter '{key}'")
        desc = fm.get("description")
        wtu = fm.get("when_to_use")
        combined = (len(desc) if isinstance(desc, str) else 0) + (
            len(wtu) if isinstance(wtu, str) else 0
        )
        if combined > SKILL_LISTING_CHAR_CAP:
            errors.append(
                f"{skill_md}: description + when_to_use is {combined} chars, over the "
                f"{SKILL_LISTING_CHAR_CAP}-char skill-listing cap — Claude Code "
                f"truncates the excess and drops trigger text. Trim the description to "
                f"purpose + primary trigger; keep protocol detail in the body."
            )
        name = fm.get("name")
        if isinstance(name, str) and name.strip():
            if name != skill_dir.name:
                errors.append(
                    f"{skill_md}: frontmatter name '{name}' does not match "
                    f"directory '{skill_dir.name}'"
                )
            if name in seen_names:
                errors.append(
                    f"{skill_md}: duplicate skill name '{name}' (also {seen_names[name]})"
                )
            else:
                seen_names[name] = skill_md


def check_agents(root: Path, errors: list[str]) -> None:
    """Validate plugin-scoped subagent definitions under ``agents/``.

    The directory is optional. Each ``*.md`` must carry ``name`` + ``description``,
    have a ``name`` that matches its filename and is unique, and must not declare a
    frontmatter field that plugin subagents ignore (``hooks``/``mcpServers``/
    ``permissionMode``) — those would be silently dropped at load time.
    """
    agents_dir = root / "agents"
    if not agents_dir.is_dir():
        return
    seen_names: dict[str, Path] = {}
    for agent_md in _iter_markdown(agents_dir):
        fm, err = parse_frontmatter(agent_md.read_text(encoding="utf-8"))
        if err:
            errors.append(f"{agent_md}: {err}")
            continue
        for key in REQUIRED_AGENT_FRONTMATTER:
            value = fm.get(key)
            if not (isinstance(value, str) and value.strip()):
                errors.append(f"{agent_md}: missing or empty frontmatter '{key}'")
        for key in FORBIDDEN_AGENT_FRONTMATTER:
            if key in fm:
                errors.append(
                    f"{agent_md}: frontmatter '{key}' is ignored for plugin subagents — remove it"
                )
        name = fm.get("name")
        if isinstance(name, str) and name.strip():
            if name != agent_md.stem:
                errors.append(
                    f"{agent_md}: frontmatter name '{name}' does not match "
                    f"filename '{agent_md.stem}'"
                )
            if name in seen_names:
                errors.append(
                    f"{agent_md}: duplicate agent name '{name}' (also {seen_names[name]})"
                )
            else:
                seen_names[name] = agent_md


def check_placeholders(root: Path, errors: list[str]) -> None:
    for rel in PLACEHOLDER_SCAN_DIRS:
        for md in _iter_markdown(root / rel):
            relpath = md.relative_to(root).as_posix()
            if relpath in PLACEHOLDER_ALLOWLIST:
                continue
            for lineno, line in enumerate(md.read_text(encoding="utf-8").splitlines(), 1):
                for token in FORBIDDEN_PLACEHOLDERS:
                    if token in line:
                        errors.append(f"{md}:{lineno}: unresolved placeholder '{token}'")


def _is_external_link(target: str) -> bool:
    target = target.strip()
    if not target or target.startswith("#"):
        return True  # pure anchor — nothing to resolve on disk
    if "://" in target or target.startswith(("mailto:", "tel:")):
        return True
    # Runtime-resolved variable (e.g. ${CLAUDE_PLUGIN_ROOT}) — nothing to resolve.
    return "${" in target or "{{" in target


def check_links(root: Path, errors: list[str]) -> None:
    for rel in LINK_SCAN_DIRS:
        for md in _iter_markdown(root / rel):
            text = md.read_text(encoding="utf-8")
            for lineno, line in enumerate(text.splitlines(), 1):
                for match in _LINK_RE.finditer(line):
                    target = match.group(1).strip()
                    if _is_external_link(target):
                        continue
                    # Strip any anchor / query fragment before resolving.
                    path_part = re.split(r"[#?]", target, maxsplit=1)[0]
                    if not path_part:
                        continue
                    resolved = (md.parent / path_part).resolve()
                    exists = resolved.exists()
                    if not exists:
                        errors.append(f"{md}:{lineno}: broken relative link '{target}'")


def check_client_terms(root: Path, errors: list[str]) -> None:
    if not CLIENT_SPECIFIC_TERMS:
        return
    lowered = [t.lower() for t in CLIENT_SPECIFIC_TERMS]
    scan_dirs = ["skills", "rules", "templates"]
    for rel in scan_dirs:
        for md in _iter_markdown(root / rel):
            for lineno, line in enumerate(md.read_text(encoding="utf-8").splitlines(), 1):
                low = line.lower()
                for term, term_low in zip(CLIENT_SPECIFIC_TERMS, lowered, strict=True):
                    if term_low in low:
                        errors.append(
                            f"{md}:{lineno}: client-specific term '{term}' (client-agnostic mode)"
                        )


def run_checks(
    root: Path,
    *,
    require_when_to_use: bool = True,
    client_agnostic: bool = False,
) -> list[str]:
    errors: list[str] = []
    if not root.is_dir():
        return [f"{root}: plugin root directory not found"]
    check_plugin_json(root, errors)
    check_copilot_version_sync(root, errors)
    check_skills(root, errors, require_when_to_use)
    check_agents(root, errors)
    check_placeholders(root, errors)
    check_links(root, errors)
    if client_agnostic:
        check_client_terms(root, errors)
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Run steer plugin hygiene checks.")
    parser.add_argument(
        "--plugin-root",
        type=Path,
        default=PLUGIN_ROOT,
        help=f"Path to the plugin root (default: {PLUGIN_ROOT})",
    )
    parser.add_argument(
        "--no-require-when-to-use",
        action="store_true",
        help="Do not require when_to_use in skill frontmatter.",
    )
    parser.add_argument(
        "--client-agnostic",
        action="store_true",
        help="Fail on configured client-specific terms (CLIENT_SPECIFIC_TERMS).",
    )
    args = parser.parse_args(argv)

    errors = run_checks(
        args.plugin_root,
        require_when_to_use=not args.no_require_when_to_use,
        client_agnostic=args.client_agnostic,
    )

    if errors:
        print(f"check_plugin: {len(errors)} problem(s) found:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1
    print("check_plugin: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())

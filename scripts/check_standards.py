#!/usr/bin/env python3
"""Standards-consistency checks for the steer plugin.

Complements ``check_plugin.py`` (frontmatter/links/placeholders hygiene) with the
*semantic* contracts introduced by the audit-mitigation work:

1. when_to_use passes a restricted-grammar formatting check (NOT a YAML parse):
   folded ``>-`` or a double-quoted scalar; bare single-quotes wrapping inner
   quotes are flagged.
2. Bidirectional declared-mode check: each multi-mode skill's
   ``<!-- steer:modes ... -->`` marker agrees with its argument-hint subcommands,
   the modes documented in its body, and every cross-skill mode reference.
3. ``commands/`` is absent/empty (the shims were removed); skill names are unique.
4. Every ``/steer:<skill>`` slash reference resolves to a real skill (no phantom
   skill), and no stale ``/e22-*`` reference survives the rebrand.
5. Every Status:/question-field/marker/next-action token in rules, skills,
   templates, and active fixtures is a member of ``enums.registry``; ENUMS.md
   agrees with the registry; the deprecated "Required before production" category
   appears nowhere.
6. MANIFEST.md install-map sources exist; migration-ledger targets exist; and
   every file under scaffold/ is declared in the map (reverse coverage).
7. README skill inventory matches the skills on disk.
8. Cross-field invariants (registry internal consistency; approval-evidence
   fields present in the intent template).
9. Installed payload (templates/scaffold, templates/spec, templates/reference)
   carries no org-specific brand — the scaffold stays client-agnostic.
10. Hand-maintained rule/skill enumerations (CLAUDE.md skills block, the
    ``standards`` skill's rule list, CROSS-SURFACE.md's rule count + SessionStart
    hook roster) stay in sync with what's actually on disk — so a new rule/skill
    can't silently desync the docs the way it did before this guard existed.
11. A skill that is ``user-invocable: false`` is never presented to a human as a
    bare imperative (``Run /steer:X``) in a user-facing surface (SessionStart hook
    notices, installed scaffold/spec docs) — typing it is rejected by the harness,
    so such surfaces must route to a callable front door or attribute it to Claude.

Usage::

    uv run python scripts/check_standards.py

Exit status is 0 when clean, 1 when any check fails.
"""

from __future__ import annotations

import fnmatch
import json
import re
import sys
from pathlib import Path

from check_plugin import PLUGIN_ROOT, parse_frontmatter

REGISTRY_PATH = PLUGIN_ROOT / "templates/reference/enums.registry"
ENUMS_MD_PATH = PLUGIN_ROOT / "templates/reference/ENUMS.md"
SKILLS_DIR = PLUGIN_ROOT / "skills"
RULES_DIR = PLUGIN_ROOT / "rules"
HOOKS_JSON = PLUGIN_ROOT / "hooks/hooks.json"
STANDARDS_SKILL = SKILLS_DIR / "standards/SKILL.md"
README = Path("README.md")
CLAUDE_MD = Path("CLAUDE.md")
CROSS_SURFACE = Path("CROSS-SURFACE.md")

# Dirs whose markdown is scanned for tokens / command refs.
SCAN_DIRS = ["rules", "skills", "templates"]

# `default` denotes the no-subcommand invocation; it never appears as an
# argument-hint keyword or a documented section, so it is exempt from the
# "declared mode must be documented" direction.
EXEMPT_MODES = {"default"}


def skill_names() -> set[str]:
    return {d.name for d in SKILLS_DIR.iterdir() if (d / "SKILL.md").is_file()}


def load_registry(errors: list[str]) -> dict[str, list[str]]:
    reg: dict[str, list[str]] = {}
    if not REGISTRY_PATH.is_file():
        errors.append(f"{REGISTRY_PATH}: missing enum registry")
        return reg
    for lineno, raw in enumerate(REGISTRY_PATH.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            errors.append(f"{REGISTRY_PATH}:{lineno}: not a key=value line: {raw!r}")
            continue
        key, _, val = line.partition("=")
        reg[key.strip()] = [v.strip() for v in val.split("|") if v.strip()]
    return reg


def _iter_md(dirs: list[str]):
    for d in dirs:
        base = PLUGIN_ROOT / d
        if base.is_dir():
            yield from sorted(base.rglob("*.md"))


# --- check 1: when_to_use formatting (restricted grammar, not a YAML parse) ---


def check_when_to_use_format(errors: list[str]) -> None:
    for skill_md in sorted(SKILLS_DIR.rglob("SKILL.md")):
        lines = skill_md.read_text(encoding="utf-8").splitlines()
        for i, line in enumerate(lines):
            m = re.match(r"^when_to_use:\s*(.*)$", line)
            if not m:
                continue
            val = m.group(1).rstrip()
            # Formatting check, NOT a YAML parse. Flag only genuinely fragile
            # forms: a single-quoted scalar with an inner single-quote, or a
            # double-quoted scalar that is not closed. A plain bare scalar
            # (including internal apostrophes — legal in YAML) and a folded/literal
            # block scalar are fine.
            ok = True
            if val.startswith("'"):
                ok = val.count("'") == 2 and val.endswith("'")  # no inner quote
            elif val.startswith('"'):
                ok = len(val) >= 2 and val.endswith('"')
            if not ok:
                errors.append(
                    f"{skill_md}:{i + 1}: when_to_use is a fragile quoted scalar "
                    f"(single-quoted with inner quote, or unclosed) — use a folded "
                    f"(>-) or double-quoted scalar"
                )
            break


# --- check 2: bidirectional declared-mode markers ---

_MODE_MARKER_RE = re.compile(r"<!--\s*steer:modes\s+([a-z0-9,_-]+)\s*-->")
_HINT_RE = re.compile(r'^argument-hint:\s*"(.*)"\s*$', re.MULTILINE)
# a code-span reference to a namespaced skill, capturing an optional trailing
# bare keyword (the mode) inside the same span.
_REF_RE = re.compile(r"`/steer:([a-z][a-z-]*)((?:\s+[^`]*)?)`")


_SUBCOMMAND_LEADING: set[str] = set()


def _is_subcommand_leading(hint: str) -> bool:
    """True if the hint's first bracket group is entirely bare keyword
    subcommands (no positional placeholder like feature-id, no `<op>`)."""
    m = re.match(r"\s*\[([^\]]*)\]", hint)
    if not m:
        return False
    for tok in m.group(1).split("|"):
        tok = tok.strip()
        if not re.fullmatch(r"[a-z][a-z-]+", tok) or tok.endswith("-id") or tok == "idea":
            return False
    return True


def _hint_subcommands(hint: str) -> set[str]:
    """Bare keyword subcommands from an argument-hint (excluding placeholders)."""
    subs: set[str] = set()
    for tok in re.split(r"[|\[\]]", hint):
        tok = tok.strip()
        if not tok:
            continue
        # placeholders: anything with a space, <…>, #, --flag, ellipsis, or a
        # trailing -id (feature-id) / known arg words.
        if " " in tok:
            # only "verb <arg>" forms are subcommands (e.g. `approve <feature-id>`,
            # `issue <op>`); free-text placeholders like "idea or product
            # description" are not.
            first = tok.split()[0]
            if "<" in tok and re.fullmatch(r"[a-z][a-z-]+", first) and not first.endswith("-id"):
                subs.add(first)
            continue
        if (
            "<" in tok
            or "#" in tok
            or tok.startswith("--")
            or "..." in tok
            or tok.endswith("-id")
            or tok in {"idea", "report"}
        ):
            continue
        if re.fullmatch(r"[a-z][a-z-]+", tok):
            subs.add(tok)
    return subs


def check_mode_markers(errors: list[str], skills: set[str]) -> None:
    declared: dict[str, set[str]] = {}
    for skill_md in sorted(SKILLS_DIR.rglob("SKILL.md")):
        name = skill_md.parent.name
        text = skill_md.read_text(encoding="utf-8")
        marker = _MODE_MARKER_RE.search(text)
        hint_m = _HINT_RE.search(text)
        hint_subs = _hint_subcommands(hint_m.group(1)) if hint_m else set()
        if not marker:
            # No marker: a skill with subcommand keywords in its hint must declare them.
            if hint_subs:
                errors.append(
                    f"{skill_md}: argument-hint has subcommands {sorted(hint_subs)} "
                    f"but no <!-- steer:modes ... --> marker"
                )
            continue
        modes = {m.strip() for m in marker.group(1).split(",") if m.strip()}
        declared[name] = modes
        body = text[marker.end() :]
        # direction A: argument-hint subcommands ⊆ declared
        for sub in sorted(hint_subs - modes):
            errors.append(
                f"{skill_md}: argument-hint subcommand '{sub}' not in declared "
                f"modes {sorted(modes)}"
            )
        # direction B: each declared mode (except default) appears in the body
        for mode in sorted(modes - EXEMPT_MODES):
            if not re.search(rf"\b{re.escape(mode)}\b", body):
                errors.append(
                    f"{skill_md}: declared mode '{mode}' is not documented in the skill body"
                )
        # Only skills whose every argument-hint alternative is a bare keyword
        # (no positional placeholder like feature-id, no `<op>` sublayer) can have
        # their cross-references mode-validated — otherwise a trailing token is
        # indistinguishable from a feature-id argument. work / issues
        # qualify; spec (positional) and tracker-sync (`issue <op>`) don't.
        if hint_m and _is_subcommand_leading(hint_m.group(1)):
            _SUBCOMMAND_LEADING.add(name)
    # direction C: cross-skill mode references against subcommand-leading skills
    for md in _iter_md(SCAN_DIRS):
        text = md.read_text(encoding="utf-8")
        for ref in _REF_RE.finditer(text):
            target, rest = ref.group(1), ref.group(2).strip()
            if target not in declared or target not in _SUBCOMMAND_LEADING or not rest:
                continue
            first = rest.split()[0]
            if not re.fullmatch(r"[a-z][a-z-]+", first):
                continue  # an arg like #N / --all
            if first not in declared[target]:
                errors.append(
                    f"{md}: reference '/steer:{target} {first}' uses a "
                    f"mode not declared by {target} {sorted(declared[target])}"
                )


# --- check 3: commands/ removed; skill names unique ---


def check_commands_gone(errors: list[str]) -> None:
    cmd_dir = PLUGIN_ROOT / "commands"
    if cmd_dir.is_dir() and any(cmd_dir.glob("*.md")):
        errors.append(f"{cmd_dir}: command shims must be removed (skills are namespaced)")


# --- check 4: command refs are namespaced and resolve ---

# Skill names dropped the distinctive ``e22-`` prefix in the rebrand, so a "bare"
# skill reference (e.g. ``/spec``) is now indistinguishable from the ``/spec``
# directory and ordinary path tokens — there is no reliable bare-ref check to make.
# Instead we (a) verify every ``/steer:<skill>`` resolves to a real skill, and
# (b) reject any stale ``/e22-*`` slash reference left over from before the rebrand.
_STALE_E22_RE = re.compile(r"(?<![A-Za-z0-9])/e22-[a-z][a-z-]*")


def check_command_refs(errors: list[str], skills: set[str]) -> None:
    ns_re = re.compile(r"/steer:([a-z][a-z-]*)")
    for md in _iter_md(SCAN_DIRS):
        text = md.read_text(encoding="utf-8")
        for i, line in enumerate(text.splitlines(), 1):
            for m in _STALE_E22_RE.finditer(line):
                errors.append(
                    f"{md}:{i}: stale '{m.group(0)}' — rebrand to the '/steer:' namespace"
                )
            for m in ns_re.finditer(line):
                if m.group(1) not in skills:
                    errors.append(f"{md}:{i}: '/steer:{m.group(1)}' does not resolve to a skill")


# --- check 5: token membership + ENUMS.md agreement ---

_DEPRECATED_NEXT_ACTION = re.compile(r"Required before production(?!\s+(?:release))")


def check_enums_md_agrees(errors: list[str], reg: dict[str, list[str]]) -> None:
    if not ENUMS_MD_PATH.is_file():
        errors.append(f"{ENUMS_MD_PATH}: missing")
        return
    md = ENUMS_MD_PATH.read_text(encoding="utf-8")
    for key, values in reg.items():
        for v in values:
            # each value must appear verbatim somewhere in the human docs
            if v not in md:
                errors.append(f"ENUMS.md: missing documentation for {key} value '{v}'")


def _strip_category(cell: str) -> str:
    cell = cell.split(" (")[0]
    cell = cell.split(" — ")[0]
    return cell.strip()


def check_token_membership(errors: list[str], reg: dict[str, list[str]]) -> None:
    fstat = set(reg.get("feature_status", []))
    adrstat = set(reg.get("adr_status", []))
    qstat = set(reg.get("question_status", []))
    qimp = set(reg.get("question_impact", []))
    rbef = set(reg.get("required_before", []))
    istate = set(reg.get("issue_state", []))
    isrc = set(reg.get("issue_source", []))
    ikind = set(reg.get("issue_kind", []))
    nact = set(reg.get("next_action", []))

    def tokens(value: str) -> list[str]:
        value = value.split("#")[0]  # drop inline comment
        return [t.strip() for t in re.split(r"[|/]", value) if t.strip()]

    for md in _iter_md(SCAN_DIRS):
        rel = md.relative_to(PLUGIN_ROOT)
        # managed-block fixtures are migration test data — they intentionally
        # carry legacy/unknown markers (e.g. a deprecated kind) and are exempt.
        if "fixtures/managed-block" in rel.as_posix():
            continue
        is_adr = md.name == "adr.md" or "decisions/" in rel.as_posix()
        text = md.read_text(encoding="utf-8")
        for i, line in enumerate(text.splitlines(), 1):
            loc = f"{rel}:{i}"
            m = re.match(r"^>\s*Status:\s*(.+)$", line)
            if m:
                if is_adr:
                    for t in tokens(m.group(1)):
                        if t.split()[0] not in adrstat:
                            errors.append(f"{loc}: ADR Status token '{t}' not in registry")
                else:
                    for t in tokens(m.group(1)):
                        if t not in fstat:
                            errors.append(f"{loc}: feature Status token '{t}' not in registry")
            m = re.match(r"^\s*-\s*status:\s*(.+)$", line)
            if m:
                for t in tokens(m.group(1)):
                    if t not in qstat:
                        errors.append(f"{loc}: question status token '{t}' not in registry")
            m = re.match(r"^\s*-\s*impact:\s*(.+)$", line)
            if m:
                for t in tokens(m.group(1)):
                    if t not in qimp:
                        errors.append(f"{loc}: question impact token '{t}' not in registry")
            m = re.match(r"^\s*-\s*required_before:\s*(.+)$", line)
            if m:
                for t in tokens(m.group(1)):
                    if t not in rbef:
                        errors.append(f"{loc}: required_before token '{t}' not in registry")
            # `created:` is optional and a date, not an enum — when present it must
            # be YYYY-MM-DD so the staleness clock can read it (empty = unset).
            m = re.match(r"^\s*-\s*created:\s*(.*)$", line)
            if m:
                val = m.group(1).split("#")[0].strip()
                if val and not re.fullmatch(r"\d{4}-\d{2}-\d{2}", val):
                    errors.append(f"{loc}: question created '{val}' is not a YYYY-MM-DD date")
            for key, vals in (
                ("steer:state", istate),
                ("steer:source", isrc),
                ("steer:kind", ikind),
            ):
                for mm in re.finditer(rf"{key}=([a-z-]+)", line):
                    if mm.group(1) not in vals:
                        errors.append(f"{loc}: {key} value '{mm.group(1)}' not in registry")
            if _DEPRECATED_NEXT_ACTION.search(line):
                errors.append(
                    f"{loc}: deprecated category 'Required before production' — use "
                    f"'Required before initial production' / 'next production release'"
                )
        # next-action category cells inside next-action tables
        for cell in _next_action_cells(text):
            base = _strip_category(cell)
            if base and not any(base == n or base.startswith(n) for n in nact):
                errors.append(f"{rel}: next-action category '{cell}' not in registry")


def _next_action_cells(text: str) -> list[str]:
    cells: list[str] = []
    in_section = False
    for line in text.splitlines():
        if re.match(r"^#+\s", line):
            in_section = bool(re.search(r"(?i)recommend.*next action", line))
        if in_section and line.strip().startswith("|") and line.count("|") >= 3:
            parts = [p.strip() for p in line.strip().strip("|").split("|")]
            if len(parts) >= 2:
                cat = parts[1]
                if cat and cat != "Category" and not set(cat) <= {"-", ":"}:
                    cells.append(cat)
    return cells


# --- check 6: MANIFEST sources / migration targets exist ---


def check_manifest(errors: list[str]) -> None:
    manifest = PLUGIN_ROOT / "templates/scaffold/MANIFEST.md"
    if not manifest.is_file():
        return
    scaffold = PLUGIN_ROOT / "templates/scaffold"
    for i, line in enumerate(manifest.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip().startswith("|"):
            continue
        parts = [p.strip() for p in line.strip().strip("|").split("|")]
        if len(parts) < 2 or set(parts[0]) <= {"-", ":", " "} or parts[0] in {"Source", ""}:
            continue
        # Only the FIRST column lists bundled source paths; descriptions in later
        # columns legitimately mention files (pyproject.toml, config.yml) that are
        # not bundled here.
        for src in re.findall(r"`([^`]+)`", parts[0]):
            for one in re.split(r",\s*", src):
                one = one.strip()
                if not one or "*" in one or one.endswith("…") or one.endswith("/…"):
                    continue  # globs / described dirs
                if not (scaffold / one).exists():
                    errors.append(f"{manifest}:{i}: source '{one}' not found under scaffold/")


def check_manifest_reverse(errors: list[str]) -> None:
    """Reverse of check_manifest: every file physically under scaffold/ must be
    declared in the MANIFEST first column. Without this, a new bundled file
    omitted from the install-map passes CI silently and never gets installed."""
    manifest = PLUGIN_ROOT / "templates/scaffold/MANIFEST.md"
    scaffold = PLUGIN_ROOT / "templates/scaffold"
    if not manifest.is_file() or not scaffold.is_dir():
        return
    # Collect declared sources that resolve under scaffold/. Rows whose source
    # starts with `../` point at sibling template dirs (templates/spec,
    # templates/github), not files here, so they're irrelevant to this walk.
    # Keep globs and `…` dir markers — here they're matched against files, not
    # skipped as in the forward check.
    declared: list[str] = []
    for line in manifest.read_text(encoding="utf-8").splitlines():
        if not line.strip().startswith("|"):
            continue
        parts = [p.strip() for p in line.strip().strip("|").split("|")]
        if len(parts) < 2 or set(parts[0]) <= {"-", ":", " "}:
            continue
        for src in re.findall(r"`([^`]+)`", parts[0]):
            for one in re.split(r",\s*", src):
                one = one.strip()
                if one and not one.startswith("../"):
                    declared.append(one)

    def covered(rel: str) -> bool:
        for pat in declared:
            if rel == pat or fnmatch.fnmatch(rel, pat):
                return True
            if pat.endswith("…"):  # described dir, e.g. `infra/…`
                prefix = pat.rstrip("…").rstrip("/")
                if prefix and rel.startswith(prefix + "/"):
                    return True
        return False

    for path in sorted(scaffold.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(scaffold).as_posix()
        if rel == "MANIFEST.md":  # the map itself is not a payload file
            continue
        if not covered(rel):
            errors.append(
                f"{manifest}: scaffold file '{rel}' is not listed in the MANIFEST "
                "install-map — add a row so it gets installed"
            )


# --- check 7: README skill inventory matches skills on disk ---


def check_readme_inventory(errors: list[str], skills: set[str]) -> None:
    if not README.is_file():
        return
    text = README.read_text(encoding="utf-8")
    # whole-token match so spec is not satisfied by spec-scaffold
    missing = {s for s in skills if not re.search(rf"/steer:{re.escape(s)}(?![a-z-])", text)}
    if missing:
        errors.append(
            f"README.md: skill inventory missing {sorted(missing)} "
            f"(every skill should appear as /steer:<skill>)"
        )


# --- check 10: hand-maintained enumerations stay in sync with disk ---


# Whole-token boundary: the same guard used by check_readme_inventory so that,
# e.g., `spec` is not satisfied by `spec-scaffold`.
def _token_present(name: str, haystack: str) -> bool:
    return re.search(rf"(?<![a-z-]){re.escape(name)}(?![a-z-])", haystack) is not None


def _sessionstart_hook_basenames() -> set[str]:
    """Basenames of every SessionStart hook script registered in hooks.json."""
    data = json.loads(HOOKS_JSON.read_text(encoding="utf-8"))
    names: set[str] = set()
    for entry in data.get("hooks", {}).get("SessionStart", []):
        for hook in entry.get("hooks", []):
            for m in re.finditer(r"hooks/([a-z0-9-]+\.sh)", hook.get("command", "")):
                names.add(m.group(1))
    return names


def check_enumeration_drift(errors: list[str], skills: set[str]) -> None:
    rules = {p.stem for p in RULES_DIR.glob("*.md")}

    # CLAUDE.md: the `skills/` layout comment must name every skill. Scope to the
    # block (skill names are common English words elsewhere in the file).
    if CLAUDE_MD.is_file():
        text = CLAUDE_MD.read_text(encoding="utf-8")
        m = re.search(r"skills/.*?\(no commands/", text, re.DOTALL)
        block = m.group(0) if m else ""
        missing = {s for s in skills if not _token_present(s, block)}
        if missing:
            errors.append(
                f"CLAUDE.md: Layout skills/ block missing {sorted(missing)} "
                f"(list every skill under plugins/steer/skills/)"
            )

    # standards skill: the rule list must name every rules/*.md stem. Scope to
    # the "operating manual" list paragraph.
    if STANDARDS_SKILL.is_file():
        text = STANDARDS_SKILL.read_text(encoding="utf-8")
        m = re.search(r"operating manual:(.*?)\n\n", text, re.DOTALL)
        block = m.group(1) if m else ""
        missing = {r for r in rules if f"`{r}`" not in block}
        if missing:
            errors.append(
                f"skills/standards/SKILL.md: rule enumeration missing "
                f"{sorted(missing)} (list every rules/*.md file)"
            )

    # CROSS-SURFACE.md: rule count + SessionStart hook roster match disk.
    if CROSS_SURFACE.is_file():
        text = CROSS_SURFACE.read_text(encoding="utf-8")
        m = re.search(r"\((\d+) files\)", text)
        if m and int(m.group(1)) != len(rules):
            errors.append(
                f"CROSS-SURFACE.md: rule count says ({m.group(1)} files) "
                f"but rules/ has {len(rules)}"
            )
        missing_hooks = {h for h in _sessionstart_hook_basenames() if h not in text}
        if missing_hooks:
            errors.append(
                f"CROSS-SURFACE.md: SessionStart hook roster missing "
                f"{sorted(missing_hooks)} (registered in hooks.json)"
            )


# --- check 8: cross-field invariants ---


def check_cross_field(errors: list[str], reg: dict[str, list[str]]) -> None:
    # registry internal consistency
    for term in ("done", "cancelled"):
        if term not in reg.get("issue_state", []):
            errors.append(f"enums.registry: issue_state must include '{term}'")
    if "cancelled" not in reg.get("question_status", []):
        errors.append("enums.registry: question_status must include 'cancelled'")
    # intent template carries structural approval evidence
    intent = PLUGIN_ROOT / "templates/spec/feature-intent.md"
    if intent.is_file():
        t = intent.read_text(encoding="utf-8")
        for field in ("> Approved by:", "> Approved at:"):
            if field not in t:
                errors.append(f"{intent}: missing approval-evidence field '{field}'")


# --- check 9: git-authorization + workflow-ownership coherence ---

# The contradictory "do not commit until approval" phrasing that Rule 45 (commit
# autonomy) forbids — init/adopt must not reintroduce it.
_NO_COMMIT_RE = re.compile(
    r"(?i)(nothing\s+(?:is\s+)?committed|commit\s+nothing|do\s+not\s+commit)"
    r"[^.\n]*until[^.\n]*approv"
)


def check_authorization(errors: list[str]) -> None:
    import json

    # 1. Rule 45 states the model: commit autonomous, push/PR gated.
    rule = PLUGIN_ROOT / "rules/45-commit-autonomy.md"
    if not rule.is_file():
        errors.append(f"{rule}: commit-autonomy rule is missing")
    else:
        t = rule.read_text(encoding="utf-8")
        if "Commit without asking" not in t:
            errors.append(f"{rule}: must state 'Commit without asking' (commit autonomy)")
        if "waits for the dev" not in t and "once they confirm" not in t:
            errors.append(f"{rule}: must gate publishing (push/PR) on dev confirmation")

    # 2. init/adopt prose must NOT contradict Rule 45.
    for rel in (
        "skills/init/SKILL.md",
        "skills/adopt/SKILL.md",
        "skills/adopt/PROCEDURE.md",
    ):
        p = PLUGIN_ROOT / rel
        if p.is_file() and _NO_COMMIT_RE.search(p.read_text(encoding="utf-8")):
            errors.append(
                f"{p}: contradicts Rule 45 — drop 'nothing committed until approval'; "
                f"commit is autonomous, only push/PR wait for the dev"
            )

    # 3. Scaffold settings enforce the gate: git push under `ask`, not `allow`;
    #    commit stays autonomous.
    settings = PLUGIN_ROOT / "templates/scaffold/claude/settings.json"
    if settings.is_file():
        try:
            perms = json.loads(settings.read_text(encoding="utf-8")).get("permissions", {})
        except json.JSONDecodeError as exc:
            errors.append(f"{settings}: invalid JSON ({exc})")
            perms = {}
        allow = set(perms.get("allow", []))
        ask = set(perms.get("ask", []))
        push = "Bash(git push)"
        if push in allow:
            errors.append(f"{settings}: '{push}' must be under permissions.ask, not allow")
        if push not in ask:
            errors.append(f"{settings}: '{push}' must be listed under permissions.ask")
        if "Bash(git commit:*)" not in allow:
            errors.append(f"{settings}: 'Bash(git commit:*)' should stay under permissions.allow")
        if "Bash(git rev-parse:*)" not in allow:
            errors.append(
                f"{settings}: 'Bash(git rev-parse:*)' should stay under permissions.allow "
                f"(read-only; steer machinery invokes it constantly — see issue #170)"
            )
        # Issue-first (rule 36) authorizes autonomous tracker-metadata writes on an
        # explicit implement/capture request. Some hosts' auto-mode classifiers block
        # an unprompted `gh issue create` as an external write, making the documented
        # find-or-create path unreachable — so the scaffold pre-authorizes the
        # tracker-metadata write verbs under `allow` (see issue #180). Delivery
        # (push/PR/merge) stays human-gated under `ask`/`deny`; these are metadata only.
        #
        # `tracker-sync` is MCP-first (the plugin ships the github MCP server), so the
        # *preferred* create/manage path is the `mcp__github__*` issue tools, not `gh` —
        # those must be pre-authorized too or the autonomous path prompts on every call
        # regardless of the `gh` allowances. The dedup `search`/`get` reads run before
        # every create; pre-authorizing them keeps find-before-create silent. This is
        # the metadata surface only — `gh api`/`gh api graphql` (a mutation vector for
        # fields/milestones/relationships) and delivery stay prompted by omission.
        autonomous_issue_ops = (
            # gh path — write verbs (#180) + dedup/capability reads
            "Bash(gh issue create:*)",
            "Bash(gh issue edit:*)",
            "Bash(gh issue comment:*)",
            "Bash(gh issue list:*)",
            "Bash(gh issue view:*)",
            "Bash(gh auth status:*)",
            # MCP-first path — the preferred create/manage/dedup tools
            "mcp__github__create_issue",
            "mcp__github__update_issue",
            "mcp__github__add_issue_comment",
            "mcp__github__get_issue",
            "mcp__github__list_issues",
            "mcp__github__search_issues",
        )
        for issue_op in autonomous_issue_ops:
            if issue_op not in allow:
                errors.append(
                    f"{settings}: '{issue_op}' should stay under permissions.allow "
                    f"(issue-first autonomous tracker-metadata path; host classifiers "
                    f"otherwise prompt on every find-or-create — see issue #180 and the "
                    f"MCP-first create path in /steer:tracker-sync)"
                )
        # Read-only inspection the skills run constantly (git status/diff/log/show,
        # gh pr/run/repo/label reads, the named verify tasks). These are non-mutating
        # and the read-heavy skills (/steer:next, /audit, /issues, /sync, /work, …)
        # invoke them on every step — leaving them prompted made the whole experience
        # feel gated even though nothing risky was happening. They stay under `allow`
        # so inspection is silent; the human-gated delivery surface (push/PR/merge/
        # deploy) stays prompted by `ask`/`deny` and the `gh api`/`gh:*` ban below.
        # `mise run` is allowed ONLY for the named verify tasks `check`/`ci` — never
        # the wildcard, which would silently green-light `mise run deploy`.
        read_only_ops = (
            "Bash(git status:*)",
            "Bash(git diff:*)",
            "Bash(git log:*)",
            "Bash(git show:*)",
            "Bash(git branch:*)",
            "Bash(git remote:*)",
            "Bash(gh pr view:*)",
            "Bash(gh pr checks:*)",
            "Bash(gh pr list:*)",
            "Bash(gh pr diff:*)",
            "Bash(gh run view:*)",
            "Bash(gh run list:*)",
            "Bash(gh run watch:*)",
            "Bash(gh repo view:*)",
            "Bash(gh label list:*)",
            "Bash(mise tasks:*)",
            "Bash(mise run check:*)",
            "Bash(mise run ci:*)",
        )
        for ro_op in read_only_ops:
            if ro_op not in allow:
                errors.append(
                    f"{settings}: '{ro_op}' should stay under permissions.allow "
                    f"(read-only inspection the skills run constantly; prompting on it "
                    f"is the friction this allowlist removes — keep it silent)"
                )
        # A broad `mise run:*` would let `mise run deploy` through the human gate.
        for forbidden_mise in ("Bash(mise run:*)", "Bash(mise:*)"):
            if forbidden_mise in allow:
                errors.append(
                    f"{settings}: '{forbidden_mise}' must not be under permissions.allow — "
                    f"it green-lights `mise run deploy`/arbitrary tasks; allow only the "
                    f"named verify tasks (`mise run check`/`ci`)"
                )
        # `gh api`/`gh api graphql` must NOT be blanket-allowed: it is the mutation
        # vector for repo delete, PR merge, branch protection, and arbitrary writes
        # that the human-gated delivery boundary depends on (see the tooling-permission
        # constraints). Field/milestone/relationship writes that go through it stay
        # prompted by design.
        for forbidden in ("Bash(gh api:*)", "Bash(gh api)", "Bash(gh:*)"):
            if forbidden in allow:
                errors.append(
                    f"{settings}: '{forbidden}' must not be under permissions.allow — "
                    f"it grants the human-gated delivery surface (repo delete, PR merge, "
                    f"branch protection); keep `gh api` prompted"
                )

    # 4. build documents both modes and delegates governed implementation to
    #    work (the sole execution owner).
    build = PLUGIN_ROOT / "skills/build/SKILL.md"
    if build.is_file():
        bt = build.read_text(encoding="utf-8")
        if "/steer:work" not in bt:
            errors.append(f"{build}: governed implementation must delegate to /steer:work")
        if "prototype" not in bt.lower():
            errors.append(f"{build}: must document the prototype/local build mode")


# --- check 10: scaffold policy/governance copies stay in sync ---

# Files the scaffold ships verbatim from the plugin so a consumer repo carries
# the same scanner/policy the plugin would apply (consumer CI can run the
# scanner without the plugin checked out; the same policy seeds the repo).
# They MUST stay byte-identical.
_SCAFFOLD_COPIES = [
    ("templates/scaffold/scripts/scan-version-pins.sh", "scripts/scan-version-pins.sh"),
    ("templates/scaffold/scripts/version-policy.sh", "hooks/lib/version-policy.sh"),
    ("templates/scaffold/policy/versions.yml", "policy/versions.yml"),
    ("templates/scaffold/policy/branch-protection.yml", "policy/branch-protection.yml"),
]


def check_scaffold_version_copies(errors: list[str]) -> None:
    for copy_rel, src_rel in _SCAFFOLD_COPIES:
        copy = PLUGIN_ROOT / copy_rel
        src = PLUGIN_ROOT / src_rel
        if not src.is_file():
            errors.append(f"{src}: version-governance source is missing")
            continue
        if not copy.is_file():
            errors.append(f"{copy}: scaffold copy is missing (ship it from {src_rel})")
            continue
        if copy.read_bytes() != src.read_bytes():
            errors.append(
                f"{copy}: scaffold copy drifted from {src_rel} — re-copy so consumer CI "
                f"runs the same scanner/policy"
            )


# --- check 11: installed payload carries no org-specific branding ---

# Files under these dirs are copied verbatim into consumer repos by
# /steer:init / /steer:adopt, so they must stay client-agnostic. The company
# brand is always written with a separator ("element-22" / "Element 22"); the
# marketplace org "element22llc" has none, so this never flags the legitimate
# `element22llc/e22-plugins` repo reference, and the author email retained in
# the manifests lives outside these payload dirs. `templates/github` is the
# single home for GitHub templates: the Issue Forms / workflows / PR template
# under it are installed payload, and the `issue-bodies/` are plugin-internal
# (read at runtime, not installed) — both are kept brand-free regardless.
_PAYLOAD_DIRS = [
    "templates/scaffold",
    "templates/spec",
    "templates/github",
    "templates/reference",
]
_BRAND_RE = re.compile(r"element[\s-]22", re.IGNORECASE)


def check_payload_debranded(errors: list[str]) -> None:
    for d in _PAYLOAD_DIRS:
        base = PLUGIN_ROOT / d
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*")):
            if not path.is_file():
                continue
            try:
                text = path.read_text(encoding="utf-8")
            except UnicodeDecodeError, OSError:
                continue
            for lineno, line in enumerate(text.splitlines(), 1):
                if _BRAND_RE.search(line):
                    rel = path.relative_to(PLUGIN_ROOT)
                    errors.append(
                        f"{rel}:{lineno}: org-specific brand in installed payload "
                        f"({line.strip()!r}) — keep the scaffold client-agnostic"
                    )


# --- check 11: non-callable skills are never surfaced as a user imperative ---

# A skill declared `user-invocable: false` is reachable only when the model
# invokes it (a front door routes to it). A user who *types* `/steer:<that-skill>`
# is rejected by the harness ("This skill can only be invoked by Claude"). So any
# surface a human reads as a to-do — a SessionStart hook notice, or the
# human-readable docs installed into a managed repo — must not present such a skill
# as a bare imperative ("Run /steer:X"). Either route the user to a callable front
# door, or attribute the action to Claude. Guards against the regression in #219;
# generalizes to whatever set is `user-invocable: false` at any given time.

_IMPERATIVE_CUE = re.compile(r"\b(?:run|type|use)\b", re.IGNORECASE)


def _noncallable_skills() -> set[str]:
    out: set[str] = set()
    for skill_dir in sorted(p for p in SKILLS_DIR.iterdir() if p.is_dir()):
        skill_md = skill_dir / "SKILL.md"
        if not skill_md.is_file():
            continue
        fm, _ = parse_frontmatter(skill_md.read_text(encoding="utf-8"))
        if fm and fm.get("user-invocable") is False:
            out.add(skill_dir.name)
    return out


def _user_facing_surfaces() -> list[Path]:
    """Files whose text a human reads as instructions: SessionStart hook notices
    (their stdout is shown to the user) and the docs installed into a repo."""
    surfaces: list[Path] = []
    for name in _sessionstart_hook_basenames():
        surfaces.append(PLUGIN_ROOT / "hooks" / name)
    surfaces.append(PLUGIN_ROOT / "templates/scaffold/README.md")
    surfaces.append(PLUGIN_ROOT / "templates/scaffold/CLAUDE.md")
    surfaces.extend(sorted((PLUGIN_ROOT / "templates/spec").glob("*.md")))
    return [p for p in surfaces if p.is_file()]


def _output_blob(path: Path) -> str:
    """Collapse a file to one whitespace-normalized string for proximity scanning.
    A hook splits a single notice across many `printf` calls, so a line-based scan
    would miss a verb and its `/steer:X` token landing on different lines — join
    first. For shell hooks, drop whole-line comments (`# …`): they are not emitted
    to the user, so a `# /steer:sync runs on its own branch` note is not output."""
    lines = path.read_text(encoding="utf-8").splitlines()
    if path.suffix == ".sh":
        lines = [ln for ln in lines if not ln.lstrip().startswith("#")]
    return re.sub(r"\s+", " ", " ".join(lines))


def check_noncallable_imperatives(errors: list[str]) -> None:
    noncallable = _noncallable_skills()
    if not noncallable:
        return
    alt = "|".join(re.escape(s) for s in sorted(noncallable))
    ref_re = re.compile(rf"/steer:({alt})(?![a-z-])")
    for path in _user_facing_surfaces():
        blob = _output_blob(path)
        for m in ref_re.finditer(blob):
            window = blob[max(0, m.start() - 80) : m.start()]
            # A bare imperative ("Run /steer:X") traps the user; an action
            # attributed to Claude ("ask Claude to run /steer:X") does not.
            if _IMPERATIVE_CUE.search(window) and "laude" not in window:
                snippet = blob[max(0, m.start() - 40) : m.start() + 30].strip()
                errors.append(
                    f"{path}: '/steer:{m.group(1)}' is presented as a user "
                    f"imperative, but that skill is user-invocable: false — route "
                    f"users to a callable front door, or attribute it to Claude. "
                    f"Near: …{snippet}…"
                )


def run_checks(errors: list[str]) -> None:
    reg = load_registry(errors)
    skills = skill_names()
    check_when_to_use_format(errors)
    check_mode_markers(errors, skills)
    check_commands_gone(errors)
    check_command_refs(errors, skills)
    if reg:
        check_enums_md_agrees(errors, reg)
        check_token_membership(errors, reg)
        check_cross_field(errors, reg)
    check_manifest(errors)
    check_manifest_reverse(errors)
    check_readme_inventory(errors, skills)
    check_enumeration_drift(errors, skills)
    check_authorization(errors)
    check_scaffold_version_copies(errors)
    check_payload_debranded(errors)
    check_noncallable_imperatives(errors)


def main() -> int:
    errors: list[str] = []
    run_checks(errors)
    if errors:
        print(f"check_standards: {len(errors)} problem(s) found:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1
    print("check_standards: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())

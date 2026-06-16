#!/usr/bin/env python3
"""Standards-consistency checks for the e22-standards plugin.

Complements ``check_plugin.py`` (frontmatter/links/placeholders hygiene) with the
*semantic* contracts introduced by the audit-mitigation work:

1. when_to_use passes a restricted-grammar formatting check (NOT a YAML parse):
   folded ``>-`` or a double-quoted scalar; bare single-quotes wrapping inner
   quotes are flagged.
2. Bidirectional declared-mode check: each multi-mode skill's
   ``<!-- e22:modes ... -->`` marker agrees with its argument-hint subcommands,
   the modes documented in its body, and every cross-skill mode reference.
3. ``commands/`` is absent/empty (the shims were removed); skill names are unique.
4. Every ``/e22-*`` slash reference is namespaced (``/e22-standards:<skill>``) and
   resolves to a real skill — no bare ``/e22-*``, no phantom skill.
5. Every Status:/question-field/marker/next-action token in rules, skills,
   templates, and active fixtures is a member of ``enums.registry``; ENUMS.md
   agrees with the registry; the deprecated "Required before production" category
   appears nowhere.
6. MANIFEST.md install-map sources exist; migration-ledger targets exist.
7. README skill inventory matches the skills on disk.
8. Cross-field invariants (registry internal consistency; approval-evidence
   fields present in the intent template).

Usage::

    uv run python scripts/check_standards.py

Exit status is 0 when clean, 1 when any check fails.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

from check_plugin import PLUGIN_ROOT

REGISTRY_PATH = PLUGIN_ROOT / "templates/reference/enums.registry"
ENUMS_MD_PATH = PLUGIN_ROOT / "templates/reference/ENUMS.md"
SKILLS_DIR = PLUGIN_ROOT / "skills"
README = Path("README.md")

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

_MODE_MARKER_RE = re.compile(r"<!--\s*e22:modes\s+([a-z0-9,_-]+)\s*-->")
_HINT_RE = re.compile(r'^argument-hint:\s*"(.*)"\s*$', re.MULTILINE)
# a code-span reference to a namespaced skill, capturing an optional trailing
# bare keyword (the mode) inside the same span.
_REF_RE = re.compile(r"`/e22-standards:(e22-[a-z][a-z-]*)((?:\s+[^`]*)?)`")


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
                    f"but no <!-- e22:modes ... --> marker"
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
        # indistinguishable from a feature-id argument. e22-work / e22-issues
        # qualify; e22-spec (positional) and e22-tracker-sync (`issue <op>`) don't.
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
                    f"{md}: reference '/e22-standards:{target} {first}' uses a "
                    f"mode not declared by {target} {sorted(declared[target])}"
                )


# --- check 3: commands/ removed; skill names unique ---


def check_commands_gone(errors: list[str]) -> None:
    cmd_dir = PLUGIN_ROOT / "commands"
    if cmd_dir.is_dir() and any(cmd_dir.glob("*.md")):
        errors.append(f"{cmd_dir}: command shims must be removed (skills are namespaced)")


# --- check 4: command refs are namespaced and resolve ---

_SKILL_ALT_CACHE: list[str] = []


def check_command_refs(errors: list[str], skills: set[str]) -> None:
    alt = "|".join(sorted(skills, key=len, reverse=True))
    bare_re = re.compile(r"(?<![A-Za-z0-9/:_])/(" + alt + r")(?![a-z-])(?!:)")
    ns_re = re.compile(r"/e22-standards:(e22-[a-z][a-z-]*)")
    for md in _iter_md(SCAN_DIRS):
        text = md.read_text(encoding="utf-8")
        for i, line in enumerate(text.splitlines(), 1):
            for m in bare_re.finditer(line):
                errors.append(f"{md}:{i}: bare '/{m.group(1)}' — use '/e22-standards:{m.group(1)}'")
            for m in ns_re.finditer(line):
                if m.group(1) not in skills:
                    errors.append(
                        f"{md}:{i}: '/e22-standards:{m.group(1)}' does not resolve to a skill"
                    )


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
            for key, vals in (("e22:state", istate), ("e22:source", isrc), ("e22:kind", ikind)):
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


# --- check 7: README skill inventory matches skills on disk ---


def check_readme_inventory(errors: list[str], skills: set[str]) -> None:
    if not README.is_file():
        return
    text = README.read_text(encoding="utf-8")
    # whole-token match so e22-spec is not satisfied by e22-spec-scaffold
    missing = {
        s for s in skills if not re.search(rf"/e22-standards:{re.escape(s)}(?![a-z-])", text)
    }
    if missing:
        errors.append(
            f"README.md: skill inventory missing {sorted(missing)} "
            f"(every skill should appear as /e22-standards:<skill>)"
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
        "skills/e22-init/SKILL.md",
        "skills/e22-adopt/SKILL.md",
        "skills/e22-adopt/PROCEDURE.md",
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

    # 4. e22-build documents both modes and delegates governed implementation to
    #    e22-work (the sole execution owner).
    build = PLUGIN_ROOT / "skills/e22-build/SKILL.md"
    if build.is_file():
        bt = build.read_text(encoding="utf-8")
        if "/e22-standards:e22-work" not in bt:
            errors.append(
                f"{build}: governed implementation must delegate to /e22-standards:e22-work"
            )
        if "prototype" not in bt.lower():
            errors.append(f"{build}: must document the prototype/local build mode")


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
    check_readme_inventory(errors, skills)
    check_authorization(errors)


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

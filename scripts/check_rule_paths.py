#!/usr/bin/env python3
"""Bound what a single file open costs in Tier 2 rule injection.

Tier 2 rules escape the SessionStart hook's 10,000-character cap, but they do
**not** escape the context window. Claude Code injects every rule whose ``paths:``
frontmatter matches a file it reads, so the real question is not "how big is the
ruleset" but **"how much of it arrives when one file is opened?"**

That number is much larger than "path-scoped" suggests. 18 of the 30 rules are
action-scoped — commit autonomy, end-of-session, gate prompts, the deletion gate —
and no glob predicts an *action*, so they carry ``paths: "**"`` and fire on the
first file touched. They are honestly **deferred always-on**, not scoped. Opening
one file currently pulls 19-22 rules.

This is still a large improvement on what it replaced (those rules reached no
session at all, and the pre-split design *intended* ~17,500 always-on characters
it never actually delivered). But it is a real context cost that grows silently:
every new ``paths: "**"`` rule lands on every file open in every managed repo, and
nothing in a PR shows that. Hence a gate.

Two budgets, both in **characters** — the same unit as ``check_context_budget.py``
and the runtime cap, deliberately, so no surface here mixes units:

``WORST_CASE_MAX_CHARS``
    The most any single file open can inject, measured across a corpus of
    representative repo paths. This is the number that matters.

``UNIVERSAL_MAX_CHARS``
    The subtotal of rules matching ``**`` — the floor *every* file open pays,
    including a bare ``README.md``. Split out because it is the part that can only
    be reduced by trimming prose or finding a real scope, never by better globs.

Reducing either means trimming a rule's rationale into ``templates/reference/*``
and keeping the imperative — the trade ``87-output-discipline`` already took.
Do **not** narrow a glob to a path that does not really bound the rule: a rule
that fails to load where it applies is the defect this whole split exists to fix.

Run from the repo root::

    uv run python scripts/check_rule_paths.py            # gate
    uv run python scripts/check_rule_paths.py --report   # per-path table
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path, PurePosixPath

import yaml

RULES_DIR = Path("plugins/steer/templates/scaffold/claude/rules")

# Sized at the measured worst case plus ~7%, which buys roughly one more
# average rule (~2,150 chars) before the ceiling is load-bearing. Same basis as
# check_context_budget.py: a margin too thin to absorb an ordinary edit makes the
# ceiling dictate the wording of the next correctness fix.
WORST_CASE_MAX_CHARS = 50_000
UNIVERSAL_MAX_CHARS = 41_500

# Representative of what a session actually opens. Not exhaustive — a corpus, so
# the worst case is measured against realistic paths rather than a contrived one.
# Add a path here when a new glob shape ships.
CORPUS = [
    "README.md",
    "CLAUDE.md",
    "src/app.py",
    "apps/web/src/page.tsx",
    "apps/web/src/components/Button.tsx",
    "apps/api/src/db/query.ts",
    "spec/intent.md",
    "spec/tracker.md",
    "spec/features/f/contract.md",
    "docs/decisions/adr-001.md",
    "infra/main.tf",
    "mise.toml",
    "package.json",
    "pyproject.toml",
    "tests/test_x.py",
    "compose.yaml",
    ".github/workflows/ci.yml",
]


def load_rules(rules_dir: Path = RULES_DIR) -> list[tuple[str, int, list[str]]]:
    """(name, characters, globs) for every Tier 2 rule."""
    out: list[tuple[str, int, list[str]]] = []
    for path in sorted(rules_dir.glob("steer-*.md")):
        text = path.read_text(encoding="utf-8")
        parts = text.split("---")
        globs: list[str] = []
        if len(parts) >= 3:
            fm = yaml.safe_load(parts[1]) or {}
            raw = fm.get("paths", [])
            globs = [raw] if isinstance(raw, str) else list(raw)
        out.append((path.name, len(text), globs))
    return out


def matches(file_path: str, globs: list[str]) -> bool:
    p = PurePosixPath(file_path)
    for g in globs:
        try:
            if p.full_match(g):
                return True
        except (ValueError, TypeError):
            continue
    return False


def injected_for(file_path: str, rules) -> tuple[int, int]:
    """(rule count, characters) injected when ``file_path`` is opened."""
    hit = [r for r in rules if matches(file_path, r[2])]
    return len(hit), sum(r[1] for r in hit)


def universal_chars(rules) -> tuple[int, int]:
    """(count, characters) of rules that fire on ANY file."""
    hit = [r for r in rules if matches("zz_any_file_at_all.txt", r[2])]
    return len(hit), sum(r[1] for r in hit)


def run_checks(rules_dir: Path = RULES_DIR) -> list[str]:
    if not rules_dir.is_dir():
        return [f"{rules_dir}: Tier 2 rules directory not found"]
    rules = load_rules(rules_dir)
    if not rules:
        return [f"{rules_dir}: no steer-*.md rules found"]

    errors: list[str] = []
    worst_path, worst_n, worst_chars = "", 0, 0
    for candidate in CORPUS:
        n, chars = injected_for(candidate, rules)
        if chars > worst_chars:
            worst_path, worst_n, worst_chars = candidate, n, chars

    total = sum(r[1] for r in rules)
    if worst_chars > WORST_CASE_MAX_CHARS:
        errors.append(
            f"{rules_dir}: opening `{worst_path}` injects {worst_n} of {len(rules)} rules, "
            f"{worst_chars:,} characters — over the {WORST_CASE_MAX_CHARS:,}-character "
            f"worst-case budget. Tier 2 has no hook cap, but it still costs context, and "
            f"this lands on the first file a session touches. Trim a rule's rationale into "
            f"templates/reference/* and keep the imperative; do NOT narrow a glob to a path "
            f"that does not really bound the rule."
        )

    uni_n, uni_chars = universal_chars(rules)
    if uni_chars > UNIVERSAL_MAX_CHARS:
        errors.append(
            f"{rules_dir}: {uni_n} rules match `**` and so fire on EVERY file open, "
            f"totalling {uni_chars:,} characters — over the {UNIVERSAL_MAX_CHARS:,}-character "
            f"budget for the universal set. This is the floor every session pays as soon as "
            f'it reads anything, including a bare README. A new `paths: "**"` rule is an '
            f"always-on rule in everything but name — give it a real scope, or trim prose to "
            f"pay for it."
        )
    _ = total
    return errors


def report(rules_dir: Path = RULES_DIR) -> str:
    rules = load_rules(rules_dir)
    uni_n, uni_chars = universal_chars(rules)
    total = sum(r[1] for r in rules)
    lines = [
        f"Tier 2: {len(rules)} rules, {total:,} characters total.",
        f"Universal (`**`, fires on any file): {uni_n} rules, {uni_chars:,} chars "
        f"(budget {UNIVERSAL_MAX_CHARS:,}).",
        "",
        f"{'file opened':40} {'rules':>6} {'chars':>9}",
        f"{'-' * 40} {'-' * 6} {'-' * 9}",
    ]
    rows = sorted(((c, *injected_for(c, rules)) for c in CORPUS), key=lambda r: -r[2])
    for candidate, n, chars in rows:
        lines.append(f"{candidate:40} {n:6} {chars:9,}")
    worst = rows[0]
    lines += [
        "",
        f"Worst case: `{worst[0]}` → {worst[1]}/{len(rules)} rules, {worst[2]:,} chars "
        f"(budget {WORST_CASE_MAX_CHARS:,}).",
    ]
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--report", action="store_true", help="print the per-path table")
    ap.add_argument("--rules-dir", type=Path, default=RULES_DIR)
    args = ap.parse_args(argv)

    if args.report:
        print(report(args.rules_dir))
        return 0
    errors = run_checks(args.rules_dir)
    if errors:
        print(f"check_rule_paths: {len(errors)} problem(s) found:", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1
    print("check_rule_paths: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

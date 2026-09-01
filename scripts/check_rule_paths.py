#!/usr/bin/env python3
"""Bound what a single file open costs in deferred repository rule injection.

deferred repository rules escape the SessionStart hook's 10,000-character cap, but they do
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

Once per process — NOT once per resumed conversation
----------------------------------------------------
Within **one process** a matching rule is injected once, however many matching
files are read. Across **process restarts** (``-p --continue`` / ``-p --resume``)
it is re-attached, and those copies **accumulate in the replayed history**.
Measured on Claude Code 2.1.252 over 12 pinned-session turns, tracking effective
input tokens (``input + cache_creation + cache_read``), with a 4,266-byte rule:

======================================  =====================
arm                                     growth per turn
======================================  =====================
rule present, reads a match every turn  **+4,100 tokens**
no rule, reads a file every turn         +1,666 tokens (baseline history)
rule present, reads nothing                +109 tokens (flat)
======================================  =====================

So a resumed turn that reads a matching file costs roughly **+2,400 tokens**
attributable to the rule — about 2.3x the rule's own character count, consistent
with the attachment carrying both ``content`` and ``rawContent``. Total cost over
N such turns is therefore **O(N^2)**, not O(N). Turns that read nothing add
nothing (+109/turn is ordinary message history), so resumption alone is not the
trigger: **a matching read after a restart is.**

What this means for the budgets below
-------------------------------------
``WORST_CASE_MAX_CHARS`` bounds **one injection**. It does not bound, and cannot
bound, the cumulative context of a conversation resumed across many processes.
Anything driving a scripted per-turn loop should either stay in **one process**
(the SDK's streaming input, or an interactive session), where the cost is paid
once, or use **an independent session per work item**, which is O(N) rather than
O(N^2). A long ``-p --continue`` chain that reads files every turn is the one
shape to avoid. steer's own ``/steer:loop`` runs one process per scheduled run,
so it is not exposed to this.

Two budgets, both in **characters** — the same unit as ``check_context_budget.py``
and the runtime cap, deliberately, so no surface here mixes units:

``WORST_CASE_MAX_CHARS``
    The most any single file open can inject, measured across a corpus of
    representative repo paths. A **first-touch** cost: a session that later reads
    files matching other globs activates further rules and climbs toward the
    single-process maximum, so this is not a session peak.

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

# The number a reader actually wants is not either tier alone but what a session
# is carrying at its worst moment: the always-on core (delivered at session
# start, every session) PLUS the deferred rules a single file open pulls in.
# Quoting only the deferred figure understates the real peak by the whole core.
CORE_PROFILE = "code"

# Sized at the measured worst case plus ~7%, which buys roughly one more
# average rule (~2,150 chars) before the ceiling is load-bearing. Same basis as
# check_context_budget.py: a margin too thin to absorb an ordinary edit makes the
# ceiling dictate the wording of the next correctness fix.
# DELIBERATE BUDGETS, NOT A RATCHET.
#
# These are chosen ceilings on a cost this repo has decided is acceptable — they
# are NOT derived from any harness limit, unlike INJECTED_CAP_CHARS (a real
# 10,000-character runtime cap) or SKILL_BODY_MAX_BYTES (a real re-attach cap).
# That makes them exactly the kind of number this repo has watched drift upward
# seven times before: see the retired-ratchet history in check_context_budget.py,
# which is preserved specifically as evidence of how that happens.
#
# So: **raising either value requires an explicit, recorded decision** — a
# reviewer agreeing in the PR that the new cost is worth it, and a note here
# saying what bought the increase. "The gate went red and I needed it green" is
# the failure mode, not a reason. The default response to a breach is to trim a
# rule's rationale into templates/reference/*, never to move the line.
#
# Sized at the measured worst case plus ~7%, which buys roughly one more average
# rule (~2,150 chars) — enough that an ordinary correctness fix to a rule never
# has its wording dictated by the ceiling, which is the specific failure the
# ratchet history records.
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
    """(name, characters, globs) for every deferred repository rule."""
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


def core_chars() -> int | None:
    """Characters the SessionStart hook delivers, or None if unmeasurable here.

    Imported lazily and failure-tolerantly: this gate must still work on a
    rules directory passed with --rules-dir, where no plugin hook exists to run.
    """
    try:
        import check_context_budget as ccb

        payload, _ = ccb.measure_injected(Path("plugins/steer"), CORE_PROFILE)
        return len(payload)
    except Exception:
        return None


def run_checks(rules_dir: Path = RULES_DIR) -> list[str]:
    if not rules_dir.is_dir():
        return [f"{rules_dir}: deferred repository rules directory not found"]
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
            f"worst-case budget. The deferred tier has no hook cap, but it still costs "
            f"context, and this lands on the first file a session touches. NOTE this "
            f"budget bounds ONE injection, not the cumulative context of a conversation "
            f"resumed across processes, where each matching read re-attaches. It is a "
            f"DELIBERATE budget, not a harness limit: raising it needs a reviewer's "
            f"agreement and a recorded reason. Trim a rule's rationale into "
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
            f"pay for it. This budget is a deliberate choice, not a harness limit: raising it "
            f"needs a reviewer's agreement and a recorded reason here."
        )
    _ = total
    return errors


def report(rules_dir: Path = RULES_DIR) -> str:
    rules = load_rules(rules_dir)
    uni_n, uni_chars = universal_chars(rules)
    total = sum(r[1] for r in rules)
    lines = [
        f"Deferred repository rules: {len(rules)} rules, {total:,} characters total.",
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
        f"Worst case (deferred only): `{worst[0]}` → {worst[1]}/{len(rules)} rules, "
        f"{worst[2]:,} chars (budget {WORST_CASE_MAX_CHARS:,}).",
    ]
    core = core_chars()
    if core is not None:
        peak = core + worst[2]
        lines += [
            f"Always-on core: {core:,} chars.",
            f"WORST SINGLE-FILE LOAD: {peak:,} chars (~{peak // 4:,} tokens) — the core "
            f"plus the most any ONE file open pulls in. This is a first-touch cost, not a "
            f"session peak: a session that goes on to touch other paths activates further "
            f"rules and climbs toward the single-process maximum below.",
            f"Single-process attachment maximum: {core + total:,} chars "
            f"(~{(core + total) // 4:,} tokens) if one process touches files matching every "
            f"rule. This bounds ONE process, NOT a conversation resumed across processes: "
            f"each `-p --continue`/`--resume` turn that reads a matching file re-attaches "
            f"the rules it matches, and those copies accumulate (measured ~2.3x the rule's "
            f"characters per such turn, O(N^2) over N turns). Stay in one process, or use "
            f"one session per work item.",
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

"""Tests for scripts/check_rule_paths.py — the the deferred tier context-cost budgets."""

from __future__ import annotations

from pathlib import Path

import check_rule_paths as crp
from conftest import REPO_ROOT

REAL_RULES = REPO_ROOT / "plugins" / "steer" / "templates" / "scaffold" / "claude" / "rules"


def _rules(tmp_path: Path, specs: list[tuple[str, list[str], int]]) -> Path:
    d = tmp_path / "rules"
    d.mkdir(parents=True)
    for name, globs, size in specs:
        fm = "---\npaths:\n" + "".join(f'  - "{g}"\n' for g in globs) + "---\n"
        (d / name).write_text(fm + "x" * size, encoding="utf-8")
    return d


def test_real_ruleset_is_inside_both_budgets():
    assert crp.run_checks(REAL_RULES) == []


def test_a_single_open_cannot_quietly_grow_past_the_budget(tmp_path: Path):
    """The regression this gate exists for: one more `**` rule on every file open.

    A new action-scoped rule is the easiest thing in the world to add — it needs
    no glob and looks local in a diff — and it lands on every file open in every
    managed repo. Nothing else in the build would notice.
    """
    big = crp.WORST_CASE_MAX_CHARS // 2 + 100
    ok = _rules(tmp_path / "a", [("steer-01-a.md", ["**"], big)])
    assert crp.run_checks(ok) == []

    over = _rules(
        tmp_path / "b",
        [("steer-01-a.md", ["**"], big), ("steer-02-b.md", ["**"], big)],
    )
    errors = crp.run_checks(over)
    assert errors, "two oversized `**` rules must breach a budget"
    joined = " ".join(errors)
    assert "worst-case" in joined or "EVERY file open" in joined


def test_overlapping_narrow_globs_are_counted_together(tmp_path: Path):
    """Overlap is the failure mode, not any single rule's size.

    Three rules that each look narrowly scoped can still all match one path. The
    budget is per-open, so it has to sum what actually co-fires rather than judge
    rules one at a time.
    """
    d = _rules(
        tmp_path,
        [
            ("steer-01-a.md", ["**/*.tsx"], 1_000),
            ("steer-02-b.md", ["apps/**"], 1_000),
            ("steer-03-c.md", ["**/components/**"], 1_000),
            ("steer-04-d.md", ["infra/**"], 1_000),  # must NOT co-fire
        ],
    )
    rules = crp.load_rules(d)
    n, chars = crp.injected_for("apps/web/src/components/Button.tsx", rules)
    assert n == 3, f"expected the three overlapping globs to co-fire, got {n}"
    only_one, one_chars = crp.injected_for("infra/main.tf", rules)
    assert chars > one_chars * 2, (
        "three co-firing rules must cost materially more than one — the budget is "
        "per-open, so overlap is what it has to measure"
    )
    assert only_one == 1


def test_universal_budget_is_separate_from_worst_case(tmp_path: Path):
    """The `**` floor is reported on its own because only prose can reduce it.

    A worst case driven by scoped globs can be fixed by scoping better; one
    driven by `**` cannot, so conflating them would hide which lever applies.
    """
    d = _rules(tmp_path, [("steer-01-a.md", ["**"], crp.UNIVERSAL_MAX_CHARS + 1)])
    errors = crp.run_checks(d)
    assert any("EVERY file open" in e for e in errors), errors


def test_report_names_the_worst_path():
    text = crp.report(REAL_RULES)
    assert "Worst case (deferred only):" in text
    assert "Universal (`**`" in text


def test_a_rule_with_no_paths_never_fires(tmp_path: Path):
    """No `paths:` means Claude Code will not auto-load it — that is a defect the
    other gates catch, but this one must not silently count it as free coverage."""
    d = tmp_path / "rules"
    d.mkdir(parents=True)
    (d / "steer-01-a.md").write_text("---\nfoo: bar\n---\nbody", encoding="utf-8")
    rules = crp.load_rules(d)
    assert crp.injected_for("anything.md", rules) == (0, 0)


def test_report_states_the_combined_peak_not_just_the_deferred_tier():
    """Quoting the deferred figure alone understates the cost by the whole core.

    The peak a session actually carries is the always-on core (delivered every
    session) plus the worst single file open, and that is the number a reader
    needs. Pinned so the report cannot regress to the partial figure.
    """
    text = crp.report(REAL_RULES)
    assert "COMBINED PEAK" in text
    assert "Always-on core:" in text
    assert "Session ceiling:" in text

    core = crp.core_chars()
    assert core is not None, "the core payload must be measurable from the repo root"
    rules = crp.load_rules(REAL_RULES)
    worst = max(crp.injected_for(c, rules)[1] for c in crp.CORPUS)
    assert f"{core + worst:,}" in text


def test_budgets_are_documented_as_deliberate_not_derived():
    """These ceilings are chosen, not harness-imposed — the class of number this
    repo has watched drift upward seven times. The module must say so, so nobody
    raises one to turn a gate green without a recorded reason."""
    doc = (Path(crp.__file__).read_text(encoding="utf-8")).upper()
    assert "DELIBERATE BUDGETS, NOT A RATCHET" in doc
    assert "RECORDED DECISION" in doc or "RECORDED REASON" in doc

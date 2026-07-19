"""Tests for scripts/check_context_budget.py.

The real plugin must fit its ratchet ceilings, and each budget must catch its
violation on a synthetic minimal plugin built in a tmp dir.
"""

from __future__ import annotations

from pathlib import Path

import check_context_budget as ccb
from conftest import REPO_ROOT

REAL_PLUGIN = REPO_ROOT / "plugins" / "steer"


def _make_plugin(tmp_path: Path, *, rules_bytes: int = 100, desc_chars: int = 100) -> Path:
    root = tmp_path / "plugin"
    (root / "rules").mkdir(parents=True)
    (root / "rules" / "00-demo.md").write_text("r" * rules_bytes, encoding="utf-8")
    skill_dir = root / "skills" / "demo-skill"
    skill_dir.mkdir(parents=True)
    (skill_dir / "SKILL.md").write_text(
        "---\n"
        "name: demo-skill\n"
        f"description: {'d' * desc_chars}\n"
        "when_to_use: Use when demonstrating.\n"
        "---\n\n# Demo\n",
        encoding="utf-8",
    )
    return root


def test_real_plugin_fits_budgets():
    assert ccb.run_checks(REAL_PLUGIN) == []


def test_real_plugin_measure_is_nonzero():
    stats = ccb.measure(REAL_PLUGIN)
    assert stats["rules_bytes"] > 0
    assert stats["listing_chars"] > 0
    assert stats["skills"]


def test_minimal_plugin_is_clean(tmp_path: Path):
    assert ccb.run_checks(_make_plugin(tmp_path)) == []


def test_rules_over_budget_fails(tmp_path: Path):
    root = _make_plugin(tmp_path, rules_bytes=ccb.RULES_TOTAL_MAX_BYTES + 1)
    errors = ccb.run_checks(root)
    assert len(errors) == 1
    assert "always-on budget" in errors[0]


def test_rules_budget_sums_across_files(tmp_path: Path):
    root = _make_plugin(tmp_path, rules_bytes=ccb.RULES_TOTAL_MAX_BYTES - 10)
    (root / "rules" / "10-more.md").write_text("r" * 11, encoding="utf-8")
    errors = ccb.run_checks(root)
    assert len(errors) == 1 and "always-on budget" in errors[0]


def test_listing_over_budget_fails(tmp_path: Path):
    root = _make_plugin(tmp_path, desc_chars=ccb.LISTING_TOTAL_MAX_CHARS + 1)
    errors = ccb.run_checks(root)
    assert len(errors) == 1
    assert "routing-surface budget" in errors[0]


def test_malformed_frontmatter_counts_as_zero(tmp_path: Path):
    # Malformed frontmatter is check_plugin.py's finding; this gate must not
    # crash or double-report on it.
    root = _make_plugin(tmp_path)
    (root / "skills" / "demo-skill" / "SKILL.md").write_text("# no frontmatter\n")
    assert ccb.run_checks(root) == []


def test_missing_root_reports(tmp_path: Path):
    errors = ccb.run_checks(tmp_path / "nope")
    assert len(errors) == 1 and "not found" in errors[0]


def test_report_renders_table(tmp_path: Path):
    text = ccb.report(_make_plugin(tmp_path))
    assert "| Always-on surface |" in text
    assert "rules/*.md injection" in text
    assert "demo-skill" in text


def test_main_gate_and_report_exit_codes(tmp_path: Path, capsys):
    root = _make_plugin(tmp_path, rules_bytes=ccb.RULES_TOTAL_MAX_BYTES + 1)
    assert ccb.main(["--plugin-root", str(root)]) == 1
    assert "problem(s) found" in capsys.readouterr().err
    # --report never gates, even over budget (it is the visibility surface).
    assert ccb.main(["--plugin-root", str(root), "--report"]) == 0

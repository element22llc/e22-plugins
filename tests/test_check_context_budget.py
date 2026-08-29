"""Tests for scripts/check_context_budget.py.

The real plugin must fit its ratchet ceilings, and each budget must catch its
violation on a synthetic minimal plugin built in a tmp dir.
"""

from __future__ import annotations

import shutil
from pathlib import Path

import check_context_budget as ccb
from conftest import REPO_ROOT

REAL_PLUGIN = REPO_ROOT / "plugins" / "steer"


# Since the injected-payload re-base the gate measures the payload the SessionStart hook emits, so a
# synthetic plugin needs a hook to measure. This stub concatenates rules/*.md
# unconditionally — it is standing in for delivery, not for scope.sh, so every
# profile sees the same bytes and the profile ceilings can be exercised directly.
# The real hook (and therefore the real scope predicates) is exercised by the
# tests that run against REAL_PLUGIN.
_STUB_HOOK = '#!/usr/bin/env sh\ncat "$(dirname "$0")"/../rules/*.md\n'


def _make_plugin(
    tmp_path: Path,
    *,
    rules_bytes: int = 100,
    desc_chars: int = 100,
    body_bytes: int = 0,
) -> Path:
    root = tmp_path / "plugin"
    (root / "rules").mkdir(parents=True)
    (root / "rules" / "00-demo.md").write_text("r" * rules_bytes, encoding="utf-8")
    (root / "hooks").mkdir(parents=True)
    (root / "hooks" / "inject-standards.sh").write_text(_STUB_HOOK, encoding="utf-8")
    skill_dir = root / "skills" / "demo-skill"
    skill_dir.mkdir(parents=True)
    (skill_dir / "SKILL.md").write_text(
        "---\n"
        "name: demo-skill\n"
        f"description: {'d' * desc_chars}\n"
        "when_to_use: Use when demonstrating.\n"
        "---\n\n# Demo\n" + "b" * body_bytes,
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
    assert stats["injected"]


def test_minimal_plugin_is_clean(tmp_path: Path):
    assert ccb.run_checks(_make_plugin(tmp_path)) == []


# --- injected-payload profiles ----------------------------------------


def test_scoping_is_measured_knowledge_is_materially_leaner():
    """The whole reason for the re-base: inject-when scoping must show up.

    Under the retired on-disk ratchet these two profiles were the same number.
    """
    injected = ccb.measure(REAL_PLUGIN)["injected"]
    assert injected["knowledge"]["tokens"] < injected["code"]["tokens"]
    assert injected["code"]["tokens"] <= injected["code-max"]["tokens"]
    # Not a rounding difference — scoping reclaims a large majority of the payload
    # for a non-code folder. Loose bound so ordinary rule edits don't trip it.
    assert injected["knowledge"]["tokens"] < injected["code-max"]["tokens"] * 0.6


def test_real_plugin_is_inside_every_gated_ceiling():
    for name, got in ccb.measure(REAL_PLUGIN)["injected"].items():
        if got["max_tokens"] is None:
            continue
        assert got["tokens"] <= got["max_tokens"], (
            f"profile {name}: {got['tokens']:,} tok over {got['max_tokens']:,}"
        )


def test_unscoping_a_rule_is_caught_by_the_knowledge_profile(tmp_path: Path):
    """The regression the retired on-disk sum could never see.

    Dropping a rule's inject-when marker pushes that rule onto every
    knowledge-work session while leaving the on-disk total byte-for-byte
    identical. Runs against a copy of the REAL plugin so the real scope.sh
    predicates decide, not a stub.
    """
    root = tmp_path / "steer"
    shutil.copytree(REAL_PLUGIN, root)

    # Pick a real scoped rule and confirm the marker is the only thing changing.
    victim = root / "rules" / "99-end-of-session.md"
    original = victim.read_text(encoding="utf-8")
    marker, _, rest = original.partition("\n")
    assert marker.startswith("<!-- steer:inject-when="), marker

    before = ccb.measure(root)

    # Replace the marker with a same-length comment: identical bytes on disk.
    victim.write_text(f"<!--{'-' * (len(marker) - 7)}-->\n{rest}", encoding="utf-8")
    after = ccb.measure(root)

    assert after["rules_bytes"] == before["rules_bytes"], "on-disk total must be unchanged"
    assert after["injected"]["knowledge"]["tokens"] > before["injected"]["knowledge"]["tokens"], (
        "un-scoping a rule must show up as growth in the knowledge profile"
    )


def test_profile_over_ceiling_fails(tmp_path: Path):
    over = int(ccb.INJECTED_PROFILES["knowledge"]["max_tokens"] * ccb.BYTES_PER_TOKEN) + 100
    errors = ccb.run_checks(_make_plugin(tmp_path, rules_bytes=over))
    assert [e for e in errors if "'knowledge' profile" in e], errors
    assert "inject-when" in " ".join(errors)


def test_gate_fails_closed_when_it_cannot_measure(tmp_path: Path):
    """A budget gate that cannot measure must never pass."""
    root = _make_plugin(tmp_path)
    (root / "hooks" / "inject-standards.sh").unlink()
    errors = ccb.run_checks(root)
    assert len(errors) == 1
    assert "could not measure the injected payload" in errors[0]


def test_token_conversion_is_pessimistic():
    # 3.5 B/tok over-reports against the ~4.0 B/tok these rules actually measure.
    assert ccb.BYTES_PER_TOKEN == 3.5
    assert ccb.tokens(3500) == 1000


def test_listing_over_budget_fails(tmp_path: Path):
    root = _make_plugin(tmp_path, desc_chars=ccb.LISTING_TOTAL_MAX_CHARS + 1)
    errors = ccb.run_checks(root)
    assert len(errors) == 1
    assert "routing-surface budget" in errors[0]


def test_skill_body_over_compaction_cap_fails(tmp_path: Path):
    root = _make_plugin(tmp_path, body_bytes=ccb.SKILL_BODY_MAX_BYTES + 1)
    errors = ccb.run_checks(root)
    assert len(errors) == 1
    assert "compaction cap" in errors[0]
    assert "demo-skill" in errors[0]


def test_skill_body_at_cap_passes(tmp_path: Path):
    # The ceiling is inclusive — exactly at the cap must not fail.
    root = _make_plugin(tmp_path, body_bytes=0)
    body = root / "skills" / "demo-skill" / "SKILL.md"
    body.write_text(
        body.read_text(encoding="utf-8").ljust(ccb.SKILL_BODY_MAX_BYTES, "b"), encoding="utf-8"
    )
    assert body.stat().st_size == ccb.SKILL_BODY_MAX_BYTES
    assert ccb.run_checks(root) == []


def test_sibling_body_files_do_not_count_toward_the_cap(tmp_path: Path):
    # The whole point of factoring procedure out: a modes/*.md read
    # just-in-time is a tool result, not re-attached skill content, so it must
    # not be summed into the SKILL.md body budget.
    root = _make_plugin(tmp_path, body_bytes=100)
    modes = root / "skills" / "demo-skill" / "modes"
    modes.mkdir()
    (modes / "big.md").write_text("x" * (ccb.SKILL_BODY_MAX_BYTES * 2), encoding="utf-8")
    assert ccb.run_checks(root) == []


def test_every_real_skill_body_is_under_the_cap():
    over = [
        (name, size)
        for name, size in ccb.measure(REAL_PLUGIN)["bodies"]
        if size > ccb.SKILL_BODY_MAX_BYTES
    ]
    assert over == [], f"skill bodies over the compaction cap: {over}"


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
    assert "rules/*.md on disk" in text
    assert "injected payload — knowledge" in text
    assert "largest SKILL.md body" in text
    assert "Largest skill bodies (compaction cap):" in text
    assert "demo-skill" in text


def test_main_gate_and_report_exit_codes(tmp_path: Path, capsys):
    over = int(ccb.INJECTED_PROFILES["knowledge"]["max_tokens"] * ccb.BYTES_PER_TOKEN) + 100
    root = _make_plugin(tmp_path, rules_bytes=over)
    assert ccb.main(["--plugin-root", str(root)]) == 1
    assert "problem(s) found" in capsys.readouterr().err
    # --report never gates, even over budget (it is the visibility surface).
    assert ccb.main(["--plugin-root", str(root), "--report"]) == 0

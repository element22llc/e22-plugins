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


# The gate measures what the SessionStart hook emits, so a synthetic plugin needs
# a hook. It gets the REAL one (hooks/ copied wholesale, libs included): the
# behaviour under test is the 10,000-character cap guard and the scope
# predicates, and a stub that reimplemented either would be testing the stub.


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
    shutil.copytree(REAL_PLUGIN / "hooks", root / "hooks")
    (root / ".claude-plugin").mkdir(parents=True)
    (root / ".claude-plugin" / "plugin.json").write_text(
        '{"name":"steer","version":"0.0.0-test"}', encoding="utf-8"
    )
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


def test_scoping_is_measured(tmp_path: Path):
    """inject-when scoping must still show up in the measured payload.

    Driven by a fixture rather than the real plugin: after the 10,000-character
    split, every Tier 1 rule is unconditional (Tier 2 scopes itself with `paths:`
    frontmatter instead), so the real plugin no longer exercises this. The
    predicates in lib/scope.sh are still live code and still gated here.
    """
    root = _make_plugin(tmp_path)
    (root / "rules" / "50-scoped.md").write_text(
        "<!-- steer:inject-when=code-project -->\n# Scoped\n" + "s" * 400, encoding="utf-8"
    )
    injected = ccb.measure(root)["injected"]
    assert injected["knowledge"]["chars"] < injected["code"]["chars"]
    assert injected["code"]["chars"] <= injected["code-max"]["chars"]


def test_real_plugin_delivers_every_core_rule_in_every_profile():
    """The property that actually matters: nothing is silently left undelivered."""
    for name, got in ccb.measure(REAL_PLUGIN)["injected"].items():
        assert got["dropped"] == [], f"profile {name} drops {got['dropped']}"
        assert got["chars"] <= ccb.INJECTED_CAP_CHARS, (
            f"profile {name}: {got['chars']:,} chars over the "
            f"{ccb.INJECTED_CAP_CHARS:,}-character runtime cap"
        )


def test_the_gate_measures_characters_of_the_exact_serialized_payload():
    """Unit discipline: the cap is in CHARACTERS, so the gate must be too.

    Non-ASCII prose (em dashes, arrows) makes bytes and characters differ by ~90
    on this ruleset. Measuring bytes where the runtime measures characters is not
    merely imprecise, it is a silent disagreement between the hook that enforces
    the cap and the gate that verifies it — the exact class of drift that let the
    original defect through. This pins that `chars` is `len()` of the identical
    string the hook emitted, not a byte count and not a re-read of the files.
    """
    payload, _ = ccb.measure_injected(REAL_PLUGIN, "code")
    got = ccb.measure(REAL_PLUGIN)["injected"]["code"]

    assert got["chars"] == len(payload)
    assert got["bytes"] == len(payload.encode("utf-8"))
    # If these were equal the test would prove nothing about the unit.
    assert got["bytes"] > got["chars"], "expected non-ASCII prose in the ruleset"
    # The gated comparison is the character count against the character cap.
    assert got["chars"] <= ccb.INJECTED_CAP_CHARS


def test_hook_and_gate_agree_on_the_measured_size():
    """The hook budgets itself; the gate checks it. They must count the same way.

    The hook counts with `wc -m`, the gate with Python `len()`. Under a UTF-8
    locale those agree exactly; under LC_ALL=C `wc -m` falls back to bytes, which
    is >= characters and therefore still safe. Either way the hook must never
    believe it has MORE room than the gate does.
    """
    import subprocess

    payload, _ = ccb.measure_injected(REAL_PLUGIN, "code")
    wc = subprocess.run(
        ["wc", "-m"], input=payload.encode("utf-8"), capture_output=True, check=True
    )
    hook_unit = int(wc.stdout.split()[0])
    assert hook_unit >= len(payload), (
        f"the hook's unit ({hook_unit}) under-counts against the runtime's "
        f"({len(payload)}) — it would over-fill the payload"
    )


def test_real_plugin_keeps_headroom_under_the_cap():
    """A ceiling with no margin dictates the wording of the next fix.

    This file's sibling gate has a long history of exactly that failure; the cap
    itself cannot move, so the margin is the only defence.
    """
    for name, got in ccb.measure(REAL_PLUGIN)["injected"].items():
        spare = ccb.INJECTED_CAP_CHARS - got["chars"]
        assert spare >= 500, f"profile {name} has only {spare} characters spare"


def test_unscoping_a_rule_is_caught_by_the_knowledge_profile(tmp_path: Path):
    """The regression the retired on-disk sum could never see.

    Dropping a rule's inject-when marker pushes that rule onto every
    knowledge-work session while leaving the on-disk total byte-for-byte
    identical. Runs against a copy of the REAL plugin so the real scope.sh
    predicates decide, not a stub.
    """
    root = _make_plugin(tmp_path)
    victim = root / "rules" / "50-scoped.md"
    victim.write_text(
        "<!-- steer:inject-when=code-project -->\n# Scoped\n" + "s" * 400, encoding="utf-8"
    )
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


def test_profile_over_the_runtime_cap_fails(tmp_path: Path):
    """One rule bigger than the cap: the hook drops it, the gate must fail."""
    root = _make_plugin(tmp_path, rules_bytes=100)
    (root / "rules" / "50-huge.md").write_text("h" * ccb.INJECTED_CAP_CHARS, encoding="utf-8")
    errors = ccb.run_checks(root)
    assert [e for e in errors if "'knowledge' profile" in e], errors
    joined = " ".join(errors)
    assert "50-huge.md" in joined, joined
    assert "cannot be raised" in joined, joined


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
    root = _make_plugin(tmp_path, rules_bytes=ccb.INJECTED_CAP_CHARS + 100)
    assert ccb.main(["--plugin-root", str(root)]) == 1
    assert "problem(s) found" in capsys.readouterr().err
    # --report never gates, even over budget (it is the visibility surface).
    assert ccb.main(["--plugin-root", str(root), "--report"]) == 0

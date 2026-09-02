"""Tests for scripts/check_context_budget.py.

The real plugin must fit its ceilings, and each budget must catch its violation
on a synthetic minimal plugin built in a tmp dir.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

import check_context_budget as ccb
from conftest import REPO_ROOT

REAL_PLUGIN = REPO_ROOT / "plugins" / "steer"


# The gate measures what the SessionStart hook emits, so a synthetic plugin needs
# a hook. It gets the REAL one (hooks/ copied wholesale, libs and hooks.json
# included): the behaviour under test is the per-part cap guard and the scope
# predicates, and a stub that reimplemented either would be testing the stub.


def _make_plugin(
    tmp_path: Path,
    *,
    rules_bytes: int = 100,
    desc_chars: int = 100,
    body_bytes: int = 0,
    parts: int | None = None,
) -> Path:
    root = tmp_path / "plugin"
    (root / "rules").mkdir(parents=True)
    (root / "rules" / "00-demo.md").write_text("r" * rules_bytes, encoding="utf-8")
    shutil.copytree(REAL_PLUGIN / "hooks", root / "hooks")
    if parts is not None:
        _set_parts(root, parts)
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


def _set_parts(root: Path, parts: int) -> None:
    """Re-register inject-standards.sh in the fixture's hooks.json as `parts` parts."""
    manifest = root / "hooks" / "hooks.json"
    data = json.loads(manifest.read_text(encoding="utf-8"))
    for group in data["hooks"]["SessionStart"]:
        if any("inject-standards" in h["command"] for h in group["hooks"]):
            group["hooks"] = [
                {
                    "type": "command",
                    "command": (
                        f'sh "${{CLAUDE_PLUGIN_ROOT}}/hooks/inject-standards.sh" {k} {parts}'
                    ),
                    "timeout": 10,
                }
                for k in range(1, parts + 1)
            ]
    manifest.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


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


# --- the two constants live in two languages; they must be one number ---------


def test_hook_and_gate_share_the_cap_constants():
    """The hook enforces the cap in sh; the gate verifies it in Python.

    Both carry the number. If they ever disagree, one of them is wrong about
    what the runtime does, and the gate could pass a payload the hook drops (or
    the reverse). Pin them equal.
    """
    hook = (REAL_PLUGIN / "hooks" / "inject-standards.sh").read_text(encoding="utf-8")
    cap = re.search(r"^STEER_INJECT_CAP=(\d+)$", hook, re.M)
    budget = re.search(r"^STEER_INJECT_PART_BUDGET=(\d+)$", hook, re.M)
    assert cap and budget, "the hook must declare STEER_INJECT_CAP and STEER_INJECT_PART_BUDGET"
    assert int(cap.group(1)) == ccb.INJECTED_CAP_CHARS
    assert int(budget.group(1)) == ccb.INJECTED_PART_BUDGET_CHARS
    assert ccb.INJECTED_PART_BUDGET_CHARS < ccb.INJECTED_CAP_CHARS


# --- parts are read from hooks.json, never assumed --------------------------


def test_parts_come_from_hooks_json():
    manifest = json.loads((REAL_PLUGIN / "hooks" / "hooks.json").read_text(encoding="utf-8"))
    registered = [
        h["command"]
        for g in manifest["hooks"]["SessionStart"]
        for h in g["hooks"]
        if "inject-standards.sh" in h["command"]
    ]
    assert ccb.hook_parts(REAL_PLUGIN) == len(registered)
    assert len(registered) >= 2, "the ruleset needs more than one part to arrive whole"


def test_non_contiguous_parts_fail_closed(tmp_path: Path):
    root = _make_plugin(tmp_path, parts=3)
    manifest = root / "hooks" / "hooks.json"
    data = json.loads(manifest.read_text(encoding="utf-8"))
    for group in data["hooks"]["SessionStart"]:
        group["hooks"] = [h for h in group["hooks"] if not h["command"].endswith(" 2 3")]
    manifest.write_text(json.dumps(data), encoding="utf-8")
    errors = ccb.run_checks(root)
    assert len(errors) == 1 and "must be registered exactly once each" in errors[0]


def test_legacy_single_registration_is_one_part(tmp_path: Path):
    root = _make_plugin(tmp_path)
    manifest = root / "hooks" / "hooks.json"
    data = json.loads(manifest.read_text(encoding="utf-8"))
    for group in data["hooks"]["SessionStart"]:
        for h in group["hooks"]:
            if "inject-standards.sh" in h["command"]:
                h["command"] = 'sh "${CLAUDE_PLUGIN_ROOT}/hooks/inject-standards.sh"'
        if "inject-standards" in group["hooks"][0]["command"]:
            group["hooks"] = group["hooks"][:1]
    manifest.write_text(json.dumps(data), encoding="utf-8")
    assert ccb.hook_parts(root) == 1


# --- injected-payload profiles ----------------------------------------


def test_scoping_is_measured():
    """inject-when scoping must show up in the measured payload."""
    injected = ccb.measure(REAL_PLUGIN)["injected"]
    assert injected["knowledge"]["chars"] < injected["code"]["chars"]
    assert injected["code"]["chars"] <= injected["code-max"]["chars"]


def test_real_plugin_delivers_every_rule_in_every_profile():
    """The property that actually matters: nothing is silently left undelivered,
    and no single part is over the runtime cap."""
    for name, got in ccb.measure(REAL_PLUGIN)["injected"].items():
        assert got["dropped"] == [], f"profile {name} drops {got['dropped']}"
        assert got["largest_part"] <= ccb.INJECTED_PART_BUDGET_CHARS, (
            f"profile {name}: a part is {got['largest_part']:,} chars, over the "
            f"{ccb.INJECTED_PART_BUDGET_CHARS:,}-character part budget"
        )


def test_the_gate_measures_characters_of_the_exact_serialized_payload():
    """Unit discipline: the cap is in CHARACTERS, so the gate must be too.

    Non-ASCII prose (em dashes, arrows) makes bytes and characters differ on this
    ruleset. Measuring bytes where the runtime measures characters would be a
    silent disagreement between the hook that enforces the cap and the gate that
    verifies it. This pins that `chars` is `len()` of the identical string the
    hook emitted, not a byte count and not a re-read of the files.
    """
    parts = ccb.measure_injected(REAL_PLUGIN, "code")
    payload = "".join(out for out, _ in parts)
    got = ccb.measure(REAL_PLUGIN)["injected"]["code"]

    assert got["chars"] == len(payload)
    assert got["part_chars"] == [len(out) for out, _ in parts]
    assert got["bytes"] == len(payload.encode("utf-8"))
    # If these were equal the test would prove nothing about the unit.
    assert got["bytes"] > got["chars"], "expected non-ASCII prose in the ruleset"


def test_hook_counts_characters_the_way_the_gate_does():
    """The hook budgets itself with `LC_ALL=C tr -d '\\200-\\277' | wc -c`, which
    is the code-point count regardless of the session's locale. It must equal
    Python's len() on the real payload — in a UTF-8 locale AND under LC_ALL=C,
    which is what a GUI-launched session may run with."""
    parts = ccb.measure_injected(REAL_PLUGIN, "code")
    payload = "".join(out for out, _ in parts)
    for locale in ("en_US.UTF-8", "C"):
        counted = subprocess.run(
            ["sh", "-c", "LC_ALL=C tr -d '\\200-\\277' | wc -c"],
            input=payload.encode("utf-8"),
            capture_output=True,
            check=True,
            env={"LC_ALL": locale, "PATH": "/usr/bin:/bin"},
        )
        assert int(counted.stdout.split()[0]) == len(payload), locale


def test_real_plugin_keeps_headroom_in_the_last_part():
    """A ceiling with no margin dictates the wording of the next fix.

    The registered parts must leave room for ordinary rule edits without a
    hooks.json change: at least one mean-sized rule's worth spare in every
    profile.
    """
    for name, got in ccb.measure(REAL_PLUGIN)["injected"].items():
        spare = got["parts"] * ccb.INJECTED_PART_BUDGET_CHARS - got["chars"]
        assert spare >= 2_000, f"profile {name} has only {spare} characters spare"


def test_parts_are_a_deterministic_ordered_partition(tmp_path: Path):
    """Every invocation computes the same partition; parts hold whole rules in
    lexical order; each part stays under the budget; nothing is duplicated."""
    root = _make_plugin(tmp_path, parts=3)
    sizes = {"10-a.md": 4_000, "20-b.md": 4_000, "30-c.md": 4_000, "40-d.md": 4_000}
    for name, n in sizes.items():
        (root / "rules" / name).write_text(f"# {name}\n" + "x" * n + "\n", encoding="utf-8")
    parts = ccb.measure_injected(root, "code")
    outs = [out for out, _ in parts]
    assert len(outs) == 3
    assert all(len(o) <= ccb.INJECTED_PART_BUDGET_CHARS for o in outs)
    # 00-demo + 10-a + 20-b fit part 1; 30-c + 40-d fit part 2; part 3 is silent.
    assert "# 10-a.md" in outs[0] and "# 20-b.md" in outs[0]
    assert "# 30-c.md" in outs[1] and "# 40-d.md" in outs[1]
    assert outs[2] == ""
    joined = "".join(outs)
    for name in sizes:
        assert joined.count(f"# {name}\n") == 1, name
    assert ccb.INCOMPLETE_MARKER not in joined
    assert "part 1/3" in outs[0] and "part 2/3" in outs[1]


def test_profile_over_the_registered_parts_fails(tmp_path: Path):
    """More eligible rules than the parts can hold: the hook drops from the tail
    and says so in-band; the gate must fail, naming the dropped rules."""
    root = _make_plugin(tmp_path, parts=1)
    for name in ("10-a.md", "20-b.md", "30-c.md"):
        (root / "rules" / name).write_text(f"# {name}\n" + "x" * 4_000 + "\n", encoding="utf-8")
    errors = ccb.run_checks(root)
    assert [e for e in errors if "'knowledge' profile" in e], errors
    joined = " ".join(errors)
    dropped_clause = joined.split("DROP", 1)[1].split(". A session")[0]
    assert "30-c.md" in dropped_clause and "10-a.md" not in dropped_clause
    assert "cannot be raised" in joined
    # And the in-band notice never pushes a part over the budget.
    for out, _ in ccb.measure_injected(root, "knowledge"):
        assert len(out) <= ccb.INJECTED_PART_BUDGET_CHARS


def test_notice_is_sized_from_the_data_not_a_fixed_reserve(tmp_path: Path):
    """Fill the only part to within a few characters of the budget, then drop
    many long-named rules: the notice must still fit, by popping rules."""
    root = _make_plugin(tmp_path, parts=1)
    (root / "rules" / "00-demo.md").unlink()
    header = len(ccb.measure_injected(root, "knowledge")[0][0])
    # One rule that fills the part to budget - 10.
    fill = ccb.INJECTED_PART_BUDGET_CHARS - header - 10 - len("# fill\n") - 3
    (root / "rules" / "10-fill.md").write_text("# fill\n" + "x" * fill + "\n", encoding="utf-8")
    for i in range(8):
        name = f"2{i}-a-very-long-rule-name-to-make-the-notice-big-{i}.md"
        (root / "rules" / name).write_text(f"# {name}\ny\n", encoding="utf-8")
    parts = ccb.measure_injected(root, "knowledge")
    out, err = parts[0]
    assert ccb.INCOMPLETE_MARKER in out
    assert len(out) <= ccb.INJECTED_PART_BUDGET_CHARS
    dropped = ccb.dropped_rules(parts)
    assert len(dropped) >= 8
    assert "and " in out and " more." in out, "notice must summarise beyond the name limit"
    assert err.startswith("steer-inject: dropped(")


def test_single_oversized_rule_is_dropped_and_reported(tmp_path: Path):
    root = _make_plugin(tmp_path, rules_bytes=100)
    (root / "rules" / "50-huge.md").write_text("h" * ccb.INJECTED_CAP_CHARS, encoding="utf-8")
    errors = ccb.run_checks(root)
    joined = " ".join(errors)
    assert "50-huge.md" in joined, joined


def test_gate_fails_closed_when_it_cannot_measure(tmp_path: Path):
    """A budget gate that cannot measure must never pass."""
    root = _make_plugin(tmp_path)
    (root / "hooks" / "inject-standards.sh").unlink()
    errors = ccb.run_checks(root)
    assert len(errors) == 1
    assert "could not measure the injected payload" in errors[0]


def test_gate_fails_closed_without_hooks_json(tmp_path: Path):
    root = _make_plugin(tmp_path)
    (root / "hooks" / "hooks.json").unlink()
    errors = ccb.run_checks(root)
    assert len(errors) == 1 and "hooks manifest not found" in errors[0]


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
    assert "parts" in text
    assert "largest SKILL.md body" in text
    assert "Largest skill bodies (compaction cap):" in text
    assert "demo-skill" in text


def test_main_gate_and_report_exit_codes(tmp_path: Path, capsys):
    root = _make_plugin(tmp_path, rules_bytes=ccb.INJECTED_CAP_CHARS + 100, parts=1)
    assert ccb.main(["--plugin-root", str(root)]) == 1
    assert "problem(s) found" in capsys.readouterr().err
    # --report never gates, even over budget (it is the visibility surface).
    assert ccb.main(["--plugin-root", str(root), "--report"]) == 0

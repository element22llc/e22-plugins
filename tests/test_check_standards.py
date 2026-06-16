"""Tests for scripts/check_standards.py."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

import check_standards  # noqa: E402


def test_real_standards_pass():
    """The live plugin satisfies every standards-consistency check."""
    errors: list[str] = []
    check_standards.run_checks(errors)
    assert errors == [], "\n".join(errors)


def test_registry_loads_expected_keys():
    errors: list[str] = []
    reg = check_standards.load_registry(errors)
    assert errors == []
    for key in ("feature_status", "question_status", "issue_state", "next_action", "adr_status"):
        assert reg.get(key), f"registry missing {key}"
    assert "cancelled" in reg["issue_state"]
    assert "draft" in reg["feature_status"]
    assert "proposed" not in reg["feature_status"]


def test_is_subcommand_leading():
    f = check_standards._is_subcommand_leading
    assert f("[start | resume | status | finish] [#issue ...]") is True
    assert f("[capture | triage | brainstorm] [#issue | feature-id]") is True
    # positional default (feature-id) → not subcommand-leading
    assert f("[feature-id | approve <feature-id> | validate [feature-id]]") is False
    # `<op>` sublayer → not subcommand-leading
    assert f("[issue <op> | pull | push] [#issue | feature-id]") is False
    assert f("[idea or product description]") is False


def test_hint_subcommands():
    f = check_standards._hint_subcommands
    assert f("[start | resume | status | finish] [#issue ...]") == {
        "start",
        "resume",
        "status",
        "finish",
    }
    # placeholders (feature-id) excluded; `approve <feature-id>` keeps the verb
    assert f("[feature-id | approve <feature-id> | validate [feature-id | --all]]") == {
        "approve",
        "validate",
    }
    # free-text placeholder yields no subcommands
    assert f("[idea or product description]") == set()


def test_strip_category():
    f = check_standards._strip_category
    assert f("Blocking now (L2)") == "Blocking now"
    assert f("Complete — no action required (L7)") == "Complete"
    assert f("Required before initial production") == "Required before initial production"


def test_deprecated_next_action_regex():
    rx = check_standards._DEPRECATED_NEXT_ACTION
    assert rx.search("Required before production")  # the removed category
    assert not rx.search("Required before production release")  # the new one
    assert not rx.search("Required before initial production")

"""The routing-eval ledger: entries distilled right, and only full sweeps recorded."""

from __future__ import annotations

import importlib.util
import json

import pytest
from conftest import REPO_ROOT

EVALS = REPO_ROOT / "plugins/steer/evals"
_spec = importlib.util.spec_from_file_location("ledger", EVALS / "ledger.py")
assert _spec and _spec.loader
ledger = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ledger)


def _case(name: str, score: float, negative: bool = False) -> dict:
    routed = {"name": "routed", "config": {"tool": "Skill"}}
    if negative:
        routed["config"] |= {"min": 0, "max": 0}
    return {
        "name": name,
        "graders": [{"name": "answer", "config": {}}, routed],
        "arms": {"with": [{}, {}, {}], "without": [{}, {}, {}]},
        "aggregates": {"score": score},
    }


def _agg(cases: list[dict], **extra) -> dict:
    return {
        "startedAt": "2026-10-15T12:10:18.401Z",
        "claudeVersion": "2.1.300",
        "costUsd": 22.9122,
        "durationSeconds": 3676,
        "partial": False,
        "suite": {
            "plugins": [{"version": "7.9.0"}],
            "modelOverride": "claude-sonnet-5-5",
            "judgeModel": "claude-opus-5-5",
        },
        "cases": cases,
        "aggregates": {"meanDelta": 0.75, "overallScore": 0.9},
    } | extra


def test_ceiling_excludes_negative_cases():
    e = ledger.entry(_agg([_case("a", 1), _case("b", 0.73), _case("c", 1), _case("n", 1, True)]))
    assert e["ceiling"] == 0.75
    assert e["runs"] == 3
    assert e["below"] == {"b": 0.73}
    assert (e["costUsd"], e["minutes"]) == (22.91, 61)


@pytest.mark.parametrize(
    ("extra", "force", "reason"),
    [
        ({"partial": True}, True, "partial"),
        ({"aggregates": {"overallScore": 1}}, True, "no baseline"),
        ({}, False, "not a full sweep"),
    ],
)
def test_rejects_what_is_not_a_comparable_sweep(extra, force, reason):
    agg = _agg([_case("a", 1)], **extra)
    assert reason in ledger.rejection(agg, set(), force)


def test_rejects_a_sweep_already_recorded():
    agg = _agg([_case("a", 1)])
    assert ledger.rejection(agg, {agg["startedAt"]}, True) == "already recorded"


def test_committed_ledger_is_well_formed():
    keys = set(ledger.entry(_agg([_case("a", 1)])))
    rows = [json.loads(line) for line in (EVALS / "ledger.jsonl").read_text().splitlines()]
    assert rows
    assert [r["started"] for r in rows] == sorted(r["started"] for r in rows)
    for r in rows:
        assert set(r) == keys
        assert 0 <= r["meanDelta"] <= r["ceiling"] <= 1

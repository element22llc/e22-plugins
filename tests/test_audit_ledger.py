"""Tests for scripts/audit_ledger.py — the persistent findings ledger.

Two properties matter. First, identity is stable under the churn that actually
happens between audit rounds (line drift, reviewer rewording), because an
unstable id makes every round look like a fresh discovery — the rediscovery
cycle this ledger exists to break. Second, a triaged finding never gates again.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

import audit_ledger  # noqa: E402

HOOKS_MD_CLAIM = (
    "scopes lib/json.sh to the PreToolUse/Stop hooks and 'the exact PreToolUse shapes'; "
    "json.sh states a two-tier contract the lifecycle hooks depend on"
)


@pytest.fixture
def ledger(tmp_path: Path) -> Path:
    return tmp_path / "findings.jsonl"


def write_candidates(tmp_path: Path, rows: list[dict]) -> Path:
    p = tmp_path / "candidates.json"
    p.write_text(json.dumps(rows), encoding="utf-8")
    return p


# --- identity ---------------------------------------------------------------


def test_identity_survives_line_drift() -> None:
    """The line number is deliberately not part of the id."""
    a = audit_ledger.finding_id("docs-accuracy", "docs/reference/hooks.md", HOOKS_MD_CLAIM)
    b = audit_ledger.finding_id("docs-accuracy", "docs/reference/hooks.md", HOOKS_MD_CLAIM)
    assert a == b


def test_identity_survives_reviewer_rewording() -> None:
    """Filler words, case and punctuation vary between rounds; content does not."""
    a = audit_ledger.claim_slug("The header contradicts the code at that line")
    b = audit_ledger.claim_slug("header contradicts code, at that line!")
    assert a == b


def test_distinct_claims_on_one_file_do_not_collide() -> None:
    one = audit_ledger.finding_id("docs-accuracy", "docs/x.md", "json contract is stale")
    two = audit_ledger.finding_id("docs-accuracy", "docs/x.md", "nav entry points at a dead page")
    assert one != two


def test_same_claim_different_rule_is_a_different_finding() -> None:
    one = audit_ledger.finding_id("docs-accuracy", "docs/x.md", "stale claim")
    two = audit_ledger.finding_id("cross-reference", "docs/x.md", "stale claim")
    assert one != two


# --- severity capping -------------------------------------------------------


def test_normalise_caps_reviewer_severity() -> None:
    row = audit_ledger.normalise(
        {
            "ruleId": "docs-accuracy",
            "path": "docs/reference/hooks.md",
            "claim": HOOKS_MD_CLAIM,
            "severity": "blocker",
        }
    )
    # The reviewer's opinion is preserved for the audit trail...
    assert row["proposed"] == "blocker"
    # ...but the path decides what it can do.
    assert row["severity"] == "low"
    assert row["ceiling"] == "low"
    assert row["state"] == "open"


def test_normalise_rejects_incomplete_candidates() -> None:
    with pytest.raises(ValueError, match="missing required field"):
        audit_ledger.normalise({"ruleId": "docs-accuracy", "path": "docs/x.md"})


def test_normalise_rejects_unknown_severity() -> None:
    with pytest.raises(ValueError, match="unknown severity"):
        audit_ledger.normalise(
            {"ruleId": "r", "path": "docs/x.md", "claim": "c", "severity": "urgent"}
        )


# --- round-tripping and triage ---------------------------------------------


def test_record_then_new_reports_nothing_twice(tmp_path: Path, ledger: Path, capsys) -> None:
    cands = write_candidates(
        tmp_path,
        [{"ruleId": "docs-accuracy", "path": "docs/reference/hooks.md", "claim": HOOKS_MD_CLAIM}],
    )
    audit_ledger.main(["--ledger", str(ledger), "record", "--candidates", str(cands)])
    capsys.readouterr()

    # A second round re-reports the same finding at a drifted line.
    again = write_candidates(
        tmp_path,
        [
            {
                "ruleId": "docs-accuracy",
                "path": "docs/reference/hooks.md",
                "line": 204,
                "claim": HOOKS_MD_CLAIM,
            }
        ],
    )
    audit_ledger.main(["--ledger", str(ledger), "new", "--candidates", str(again)])
    out = capsys.readouterr().out
    assert "0 new, 1 already in the ledger" in out


def test_accept_requires_a_reason_and_stops_the_finding(
    tmp_path: Path, ledger: Path, capsys
) -> None:
    cands = write_candidates(
        tmp_path,
        [
            {
                "ruleId": "release",
                "path": "CHANGELOG.md",
                "claim": "heading order broken",
                "severity": "blocker",
            }
        ],
    )
    audit_ledger.main(["--ledger", str(ledger), "record", "--candidates", str(cands)])
    capsys.readouterr()

    assert audit_ledger.main(["--ledger", str(ledger), "gate"]) == 1

    fid = next(iter(audit_ledger.load(ledger)))
    audit_ledger.main(
        ["--ledger", str(ledger), "accept", fid, "--reason", "intentional; tracked in #492"]
    )
    capsys.readouterr()

    assert audit_ledger.main(["--ledger", str(ledger), "gate"]) == 0
    assert audit_ledger.load(ledger)[fid]["reason"] == "intentional; tracked in #492"


def test_accept_without_reason_is_rejected(tmp_path: Path, ledger: Path) -> None:
    with pytest.raises(SystemExit):
        audit_ledger.main(["--ledger", str(ledger), "accept", "deadbeef1234"])


def test_gate_ignores_non_shipping_blockers(tmp_path: Path, ledger: Path, capsys) -> None:
    """The 6.0.0 regression, end to end: a docs-site blocker must not gate."""
    cands = write_candidates(
        tmp_path,
        [
            {
                "ruleId": "docs-accuracy",
                "path": "docs/reference/hooks.md",
                "claim": HOOKS_MD_CLAIM,
                "severity": "blocker",
            }
        ],
    )
    audit_ledger.main(["--ledger", str(ledger), "record", "--candidates", str(cands)])
    capsys.readouterr()
    assert audit_ledger.main(["--ledger", str(ledger), "gate"]) == 0


def test_resolve_keeps_a_tombstone(tmp_path: Path, ledger: Path, capsys) -> None:
    cands = write_candidates(
        tmp_path, [{"ruleId": "r", "path": "plugins/steer/rules/24-worktrees.md", "claim": "c"}]
    )
    audit_ledger.main(["--ledger", str(ledger), "record", "--candidates", str(cands)])
    fid = next(iter(audit_ledger.load(ledger)))
    audit_ledger.main(["--ledger", str(ledger), "resolve", fid])
    capsys.readouterr()
    rows = audit_ledger.load(ledger)
    assert rows[fid]["state"] == "fixed"  # tombstone, so a regression reads as recurrence


def test_unknown_id_is_an_error(tmp_path: Path, ledger: Path) -> None:
    ledger.parent.mkdir(parents=True, exist_ok=True)
    ledger.write_text("", encoding="utf-8")
    with pytest.raises(SystemExit, match="no finding with id"):
        audit_ledger.main(["--ledger", str(ledger), "resolve", "000000000000"])


def test_corrupt_ledger_is_reported_with_its_line(tmp_path: Path, ledger: Path) -> None:
    ledger.parent.mkdir(parents=True, exist_ok=True)
    ledger.write_text('{"id": "a"}\nnot json\n', encoding="utf-8")
    with pytest.raises(SystemExit, match=":2:"):
        audit_ledger.load(ledger)


def test_ledger_round_trips_and_stays_sorted(tmp_path: Path, ledger: Path, capsys) -> None:
    cands = write_candidates(
        tmp_path,
        [
            {"ruleId": "r", "path": "docs/a.md", "claim": "zebra claim here"},
            {"ruleId": "r", "path": "docs/b.md", "claim": "alpha claim here"},
        ],
    )
    audit_ledger.main(["--ledger", str(ledger), "record", "--candidates", str(cands)])
    capsys.readouterr()
    ids = [json.loads(line)["id"] for line in ledger.read_text().splitlines()]
    assert ids == sorted(ids)  # order-stable diffs for concurrent PRs


def test_repo_ledger_is_wellformed_and_capped() -> None:
    """The committed ledger must parse and must never carry an over-ranked row."""
    rows = audit_ledger.load(audit_ledger.LEDGER)
    for row in rows.values():
        assert row["state"] in audit_ledger.STATES
        assert row["severity"] == audit_ledger.cap(row["path"], row["proposed"])
        if row["state"] == "accepted":
            assert row["reason"], f"{row['id']}: accepted without a reason"

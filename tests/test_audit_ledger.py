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
    assert "0 new, 0 recurrence, 1 already in the ledger" in out


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


# --- reconciliation ---------------------------------------------------------


def test_reconcile_closes_rows_whose_path_is_gone(
    tmp_path: Path, ledger: Path, capsys, monkeypatch
) -> None:
    """An open row on a deleted file cannot still hold; no verifier is needed."""
    monkeypatch.chdir(tmp_path)
    (tmp_path / "docs").mkdir()
    (tmp_path / "docs" / "kept.md").write_text("x", encoding="utf-8")
    cands = write_candidates(
        tmp_path,
        [
            {"ruleId": "r", "path": "docs/kept.md", "claim": "still here"},
            {"ruleId": "r", "path": "docs/removed.md", "claim": "file was deleted"},
        ],
    )
    audit_ledger.main(["--ledger", str(ledger), "record", "--candidates", str(cands)])
    audit_ledger.main(["--ledger", str(ledger), "reconcile"])
    capsys.readouterr()
    by_path = {r["path"]: r for r in audit_ledger.load(ledger).values()}
    assert by_path["docs/removed.md"]["state"] == "fixed"
    assert "path no longer exists" in by_path["docs/removed.md"]["reason"]
    assert by_path["docs/kept.md"]["state"] == "open"


def test_reconcile_applies_verifier_verdicts(
    tmp_path: Path, ledger: Path, capsys, monkeypatch
) -> None:
    monkeypatch.chdir(tmp_path)
    (tmp_path / "docs").mkdir()
    for name in ("a.md", "b.md"):
        (tmp_path / "docs" / name).write_text("x", encoding="utf-8")
    cands = write_candidates(
        tmp_path,
        [
            {"ruleId": "r", "path": "docs/a.md", "claim": "claim that got fixed"},
            {"ruleId": "r", "path": "docs/b.md", "claim": "claim that still holds"},
        ],
    )
    audit_ledger.main(["--ledger", str(ledger), "record", "--candidates", str(cands)])
    rows = audit_ledger.load(ledger)
    a = next(r["id"] for r in rows.values() if r["path"] == "docs/a.md")
    b = next(r["id"] for r in rows.values() if r["path"] == "docs/b.md")
    verdicts = tmp_path / "verdicts.json"
    verdicts.write_text(
        json.dumps(
            {
                "reconcile": [
                    {"id": a, "holds": False, "reason": "line 12 now lists both hooks"},
                    {"id": b, "holds": True, "reason": "still contradicts"},
                ]
            }
        ),
        encoding="utf-8",
    )
    audit_ledger.main(["--ledger", str(ledger), "reconcile", "--verdicts", str(verdicts)])
    out = capsys.readouterr().out
    assert "1 fixed" in out and "1 still hold" in out
    rows = audit_ledger.load(ledger)
    assert rows[a]["state"] == "fixed"
    assert rows[a]["reason"] == "reconciled: line 12 now lists both hooks"
    assert rows[b]["state"] == "open"
    assert audit_ledger.main(["--ledger", str(ledger), "gate"]) == 0


def test_reconcile_never_overrides_human_triage(
    tmp_path: Path, ledger: Path, capsys, monkeypatch
) -> None:
    """A verifier saying 'fixed' about an accepted row is noise; the human's call stands."""
    monkeypatch.chdir(tmp_path)
    (tmp_path / "docs").mkdir()
    (tmp_path / "docs" / "a.md").write_text("x", encoding="utf-8")
    cands = write_candidates(tmp_path, [{"ruleId": "r", "path": "docs/a.md", "claim": "c"}])
    audit_ledger.main(["--ledger", str(ledger), "record", "--candidates", str(cands)])
    fid = next(iter(audit_ledger.load(ledger)))
    audit_ledger.main(["--ledger", str(ledger), "accept", fid, "--reason", "by design"])
    verdicts = tmp_path / "verdicts.json"
    verdicts.write_text(json.dumps([{"id": fid, "holds": False}]), encoding="utf-8")
    audit_ledger.main(["--ledger", str(ledger), "reconcile", "--verdicts", str(verdicts)])
    capsys.readouterr()
    row = audit_ledger.load(ledger)[fid]
    assert row["state"] == "accepted" and row["reason"] == "by design"


def test_reconcile_rejects_malformed_verdicts(tmp_path: Path, ledger: Path) -> None:
    ledger.parent.mkdir(parents=True, exist_ok=True)
    ledger.write_text("", encoding="utf-8")
    bad = tmp_path / "verdicts.json"
    bad.write_text(json.dumps([{"id": "abc", "holds": "yes"}]), encoding="utf-8")
    with pytest.raises(SystemExit, match="boolean 'holds'"):
        audit_ledger.main(["--ledger", str(ledger), "reconcile", "--verdicts", str(bad)])


def test_open_touched_filters_to_changed_files(
    tmp_path: Path, ledger: Path, capsys, monkeypatch
) -> None:
    cands = write_candidates(
        tmp_path,
        [
            {"ruleId": "r", "path": "docs/changed.md", "claim": "edited since confirmed"},
            {"ruleId": "r", "path": "docs/same.md", "claim": "untouched since confirmed"},
        ],
    )
    audit_ledger.main(["--ledger", str(ledger), "record", "--candidates", str(cands)])
    capsys.readouterr()
    monkeypatch.setattr(audit_ledger, "path_touched", lambda row: row["path"] == "docs/changed.md")
    audit_ledger.main(["--ledger", str(ledger), "open", "--touched", "--json"])
    rows = json.loads(capsys.readouterr().out)["rows"]
    assert [r["path"] for r in rows] == ["docs/changed.md"]
    assert set(rows[0]) >= {"id", "path", "line", "claim", "ruleId"}


# --- recurrence -------------------------------------------------------------


def test_fixed_finding_reported_again_is_a_recurrence_not_carried(
    tmp_path: Path, ledger: Path, capsys
) -> None:
    """The tombstone has to talk: a regression of a fixed row must be reported, then reopened."""
    cands = write_candidates(
        tmp_path, [{"ruleId": "r", "path": "plugins/steer/rules/24-worktrees.md", "claim": "c"}]
    )
    audit_ledger.main(["--ledger", str(ledger), "record", "--candidates", str(cands)])
    fid = next(iter(audit_ledger.load(ledger)))
    audit_ledger.main(["--ledger", str(ledger), "resolve", fid])
    capsys.readouterr()

    audit_ledger.main(["--ledger", str(ledger), "new", "--candidates", str(cands)])
    out = capsys.readouterr().out
    assert "0 new, 1 recurrence, 0 already in the ledger" in out
    assert "regression" in out

    audit_ledger.main(["--ledger", str(ledger), "record", "--candidates", str(cands)])
    out = capsys.readouterr().out
    assert "reopened 1 recurrence" in out
    row = audit_ledger.load(ledger)[fid]
    assert row["state"] == "open"
    assert row["reason"].startswith("recurrence")


def test_accepted_finding_reported_again_stays_carried(
    tmp_path: Path, ledger: Path, capsys
) -> None:
    cands = write_candidates(tmp_path, [{"ruleId": "r", "path": "docs/a.md", "claim": "c"}])
    audit_ledger.main(["--ledger", str(ledger), "record", "--candidates", str(cands)])
    fid = next(iter(audit_ledger.load(ledger)))
    audit_ledger.main(["--ledger", str(ledger), "accept", fid, "--reason", "by design"])
    capsys.readouterr()
    audit_ledger.main(["--ledger", str(ledger), "new", "--candidates", str(cands)])
    assert "0 new, 0 recurrence, 1 already in the ledger" in capsys.readouterr().out
    assert audit_ledger.load(ledger)[fid]["state"] == "accepted"

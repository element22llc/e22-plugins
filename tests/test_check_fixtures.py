"""Tests for scripts/check_fixtures.py.

The real plugin + this repo's own scenario fixtures must pass cleanly, and each
contract validator must catch its regression. check_fixtures reads cwd-relative
module constants, so integration tests pin cwd to the repo root and negative
tests monkeypatch the relevant path constant onto a synthetic tree.
"""

from __future__ import annotations

from pathlib import Path

import check_fixtures
from conftest import REPO_ROOT

# --- pure helpers --------------------------------------------------------


def test_category_value_reads_following_line():
    text = "## Expected category\n\nRecommended\n"
    assert check_fixtures._category_value(text) == "Recommended"


def test_category_value_absent():
    assert check_fixtures._category_value("# no category heading\n") is None


def test_state_marker_regex():
    assert check_fixtures._STATE_MARKER_RE.findall("<!-- e22:state=ready-for-dev -->") == [
        "ready-for-dev"
    ]


# --- lifecycle / marker validation ---------------------------------------


def test_invalid_lifecycle_state_is_caught(tmp_path: Path, monkeypatch):
    block = tmp_path / "reference" / "fixtures" / "managed-block"
    block.mkdir(parents=True)
    (block / "bad.expected.md").write_text(
        "<!-- e22:state=not-a-real-state -->\n", encoding="utf-8"
    )
    monkeypatch.setattr(check_fixtures, "REFERENCE", tmp_path / "reference")
    errors: list[str] = []
    check_fixtures.check_lifecycle_and_markers(errors)
    assert any("invalid issue lifecycle state" in e for e in errors)


def test_malformed_state_marker_is_caught(tmp_path: Path, monkeypatch):
    block = tmp_path / "reference" / "fixtures" / "managed-block"
    block.mkdir(parents=True)
    # Valid state value but not wrapped in the canonical comment form.
    (block / "bad.expected.md").write_text("e22:state=inbox\n", encoding="utf-8")
    monkeypatch.setattr(check_fixtures, "REFERENCE", tmp_path / "reference")
    errors: list[str] = []
    check_fixtures.check_lifecycle_and_markers(errors)
    assert any("canonical" in e for e in errors)


# --- repo scenario fixtures ----------------------------------------------


def test_misleading_production_language_is_caught(tmp_path: Path, monkeypatch):
    prod = tmp_path / "production-app-with-open-issues"
    prod.mkdir(parents=True)
    (prod / "next-actions.md").write_text(
        "## Recommended next actions\n\n### Recommended\n\n"
        "<!-- e22:state=in-progress -->\n"
        "Required before production: tidy the backlog.\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(check_fixtures, "REPO_FIXTURES", tmp_path)
    errors: list[str] = []
    check_fixtures.check_repo_fixtures(errors)
    assert any("must not contain 'Required before production'" in e for e in errors)


def test_accepted_adr_from_adoption_is_caught(tmp_path: Path, monkeypatch):
    adopted = tmp_path / "adopted-existing-app"
    adopted.mkdir(parents=True)
    (adopted / "adr-0001.md").write_text(
        "# Inferred decision\n\n> Status: Accepted\n", encoding="utf-8"
    )
    monkeypatch.setattr(check_fixtures, "REPO_FIXTURES", tmp_path)
    errors: list[str] = []
    check_fixtures.check_repo_fixtures(errors)
    assert any("Status: Accepted" in e for e in errors)


# --- ADR template default ------------------------------------------------


def test_adr_default_proposed_before_accepted(tmp_path: Path, monkeypatch):
    spec = tmp_path / "spec"
    spec.mkdir(parents=True)
    # Accepted listed before Proposed — must be flagged.
    (spec / "adr.md").write_text("> Status: Accepted | Proposed\n", encoding="utf-8")
    monkeypatch.setattr(check_fixtures, "SPEC_TEMPLATES", spec)
    errors: list[str] = []
    check_fixtures.check_adr_default_proposed(errors)
    assert any("before 'Accepted'" in e for e in errors)


# --- integration: real plugin + repo fixtures are clean ------------------


def test_real_fixtures_pass(monkeypatch):
    monkeypatch.chdir(REPO_ROOT)
    assert check_fixtures.run_checks() == []

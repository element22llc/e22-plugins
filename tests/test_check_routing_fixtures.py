"""Tests for scripts/check_routing_fixtures.py.

The real fixtures must validate against the real plugin, and each check must
catch its violation on a synthetic plugin + fixtures pair built in a tmp dir.
"""

from __future__ import annotations

from pathlib import Path

import check_routing_fixtures as crf
from conftest import REPO_ROOT

REAL_PLUGIN = REPO_ROOT / "plugins" / "steer"
REAL_FIXTURES = REPO_ROOT / "tests" / "fixtures" / "routing" / "asks.yml"


def _make_plugin(tmp_path: Path) -> Path:
    root = tmp_path / "plugin"
    (root / "rules").mkdir(parents=True)
    (root / "rules" / "00-router.md").write_text(
        "| set up a repo | `/steer:setup` |\n", encoding="utf-8"
    )
    skill_dir = root / "skills" / "setup"
    skill_dir.mkdir(parents=True)
    (skill_dir / "SKILL.md").write_text(
        "---\n"
        "name: setup\n"
        "description: One front door for onboarding a repo.\n"
        "when_to_use: Use to set up or onboard a repo onto the standards.\n"
        "---\n\n# Setup\n",
        encoding="utf-8",
    )
    return root


def _write_fixtures(tmp_path: Path, body: str) -> Path:
    path = tmp_path / "asks.yml"
    path.write_text(body, encoding="utf-8")
    return path


_OK_FIXTURE = """\
fixtures:
  - ask: "set up this repo"
    skill: setup
    signals: ["onboard", "set up"]
"""


def test_real_fixtures_validate_against_real_plugin():
    assert crf.run_checks(REAL_PLUGIN, REAL_FIXTURES) == []


def test_real_fixtures_meet_the_floor():
    fixtures, errors = crf.load_fixtures(REAL_FIXTURES)
    assert errors == []
    assert len(fixtures) >= crf.MIN_FIXTURES


def _no_floor_errors(errors: list[str]) -> list[str]:
    """The synthetic tree carries one fixture; ignore the floor finding."""
    return [e for e in errors if "fixture floor" not in e]


def test_valid_fixture_passes(tmp_path: Path):
    root = _make_plugin(tmp_path)
    fx = _write_fixtures(tmp_path, _OK_FIXTURE)
    assert _no_floor_errors(crf.run_checks(root, fx)) == []


def test_signal_in_router_only_passes(tmp_path: Path):
    # A signal carried by 00-router.md but absent from the skill's own
    # frontmatter is still routable — the surface is the union.
    root = _make_plugin(tmp_path)
    fx = _write_fixtures(
        tmp_path,
        'fixtures:\n  - ask: "x"\n    skill: setup\n    signals: ["/steer:setup"]\n',
    )
    assert _no_floor_errors(crf.run_checks(root, fx)) == []


def test_missing_signal_fails(tmp_path: Path):
    root = _make_plugin(tmp_path)
    fx = _write_fixtures(
        tmp_path,
        'fixtures:\n  - ask: "x"\n    skill: setup\n    signals: ["hovercraft"]\n',
    )
    errors = _no_floor_errors(crf.run_checks(root, fx))
    assert len(errors) == 1 and "hovercraft" in errors[0]


def test_unknown_skill_fails(tmp_path: Path):
    root = _make_plugin(tmp_path)
    fx = _write_fixtures(
        tmp_path,
        'fixtures:\n  - ask: "x"\n    skill: nope\n    signals: ["set up"]\n',
    )
    errors = _no_floor_errors(crf.run_checks(root, fx))
    assert len(errors) == 1 and "does not exist" in errors[0]


def test_duplicate_ask_fails(tmp_path: Path):
    root = _make_plugin(tmp_path)
    fx = _write_fixtures(tmp_path, _OK_FIXTURE + _OK_FIXTURE.replace("fixtures:\n", ""))
    errors = _no_floor_errors(crf.run_checks(root, fx))
    assert any("duplicate ask" in e for e in errors)


def test_empty_signals_fails(tmp_path: Path):
    root = _make_plugin(tmp_path)
    fx = _write_fixtures(tmp_path, 'fixtures:\n  - ask: "x"\n    skill: setup\n    signals: []\n')
    errors = _no_floor_errors(crf.run_checks(root, fx))
    assert len(errors) == 1 and "non-empty list" in errors[0]


def test_below_floor_reports(tmp_path: Path):
    root = _make_plugin(tmp_path)
    fx = _write_fixtures(tmp_path, _OK_FIXTURE)
    errors = crf.run_checks(root, fx)
    assert any("fixture floor" in e for e in errors)


def test_missing_fixtures_file_reports(tmp_path: Path):
    root = _make_plugin(tmp_path)
    errors = crf.run_checks(root, tmp_path / "absent.yml")
    assert len(errors) == 1 and "missing" in errors[0]


def test_malformed_yaml_reports(tmp_path: Path):
    root = _make_plugin(tmp_path)
    fx = _write_fixtures(tmp_path, "fixtures: [unclosed\n")
    errors = crf.run_checks(root, fx)
    assert len(errors) == 1 and "malformed YAML" in errors[0]


def test_main_exit_codes(tmp_path: Path, capsys):
    root = _make_plugin(tmp_path)
    fx = _write_fixtures(tmp_path, _OK_FIXTURE)
    assert crf.main(["--plugin-root", str(root), "--fixtures", str(fx)]) == 1  # floor
    assert "problem(s) found" in capsys.readouterr().err
    assert crf.main(["--plugin-root", str(REAL_PLUGIN), "--fixtures", str(REAL_FIXTURES)]) == 0

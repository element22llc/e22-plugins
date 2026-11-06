"""plugins/steer/hooks/tests/run.sh must not pass a case whose shell reported an error."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest

TESTS = Path(__file__).resolve().parents[1] / "plugins" / "steer" / "hooks" / "tests"


def _run(tmp_path: Path, body: str) -> subprocess.CompletedProcess[str]:
    tests = tmp_path / "plugins" / "steer" / "hooks" / "tests"
    (tests / "cases").mkdir(parents=True)
    shutil.copy(TESTS / "run.sh", tests)
    shutil.copy(TESTS / "lib.sh", tests)
    shutil.copytree(TESTS.parent / "lib", tests.parent / "lib")
    (tests / "cases" / "probe.sh").write_text(f'. "$(dirname -- "$0")/../lib.sh"\n{body}\nfinish\n')
    return subprocess.run(
        ["sh", str(tests / "run.sh"), "probe"], capture_output=True, text=True, check=False
    )


def test_clean_case_passes(tmp_path: Path):
    result = _run(tmp_path, "assert_eq same a a")
    assert result.returncode == 0, result.stderr
    assert result.stdout.strip().endswith("1 passed, 0 failed")


@pytest.mark.parametrize("shell_error", ["assert_typo name a a", "cat ./no-such-file"])
def test_stray_stderr_fails_the_run(tmp_path: Path, shell_error: str):
    result = _run(tmp_path, f"{shell_error}\nassert_eq same a a")
    assert result.returncode == 1
    assert "FAIL: probe wrote to stderr:" in result.stderr
    assert result.stdout.strip().endswith("1 passed, 1 failed")


def test_skip_line_on_stderr_is_allowed(tmp_path: Path):
    result = _run(tmp_path, "echo 'SKIP: git unavailable' >&2\nassert_eq same a a")
    assert result.returncode == 0, result.stderr
    assert "SKIP: git unavailable" in result.stderr


def test_case_dying_before_its_tally_is_counted_once(tmp_path: Path):
    result = _run(tmp_path, 'echo "$UNSET_VARIABLE"')
    assert result.returncode == 1
    assert "probe exited before its tally" in result.stderr
    assert "wrote to stderr" not in result.stderr
    assert result.stdout.strip().endswith("0 passed, 1 failed")


def test_failed_assertion_is_counted_once(tmp_path: Path):
    result = _run(tmp_path, "assert_eq differs a b")
    assert result.returncode == 1
    assert "wrote to stderr" not in result.stderr
    assert result.stdout.strip().endswith("0 passed, 1 failed")

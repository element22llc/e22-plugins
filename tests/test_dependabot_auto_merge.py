"""Behaviour of the shipped dependabot-auto-merge.yml merge step (#660).

The step's ``run`` script is extracted from the template and executed against a
stub ``gh`` that replays check states, so the test exercises the shipped text.
The contract: approve only after every other check finished, abort on a failed,
cancelled or skipped gating check, and merge pinned to the verified head.
"""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

import pytest
import yaml
from conftest import REPO_ROOT

WORKFLOW = REPO_ROOT / "plugins/steer/templates/github/workflows/dependabot-auto-merge.yml"
SHA = "a" * 40

_GH = """#!/bin/sh
printf '%s\\n' "$*" >>"$STUB/calls"
case "$1 $2" in
"pr checks")
  n=$(cat "$STUB/n" 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" >"$STUB/n"
  f="$STUB/checks.$n"; [ -f "$f" ] || f="$(ls "$STUB"/checks.* | sort -t. -k2 -n | tail -1)"
  cat "$f" ;;
"pr view") echo "$HEAD_NOW" ;;
"pr review") exit "${REVIEW_RC:-0}" ;;
esac
"""


def _step() -> dict:
    jobs = yaml.safe_load(WORKFLOW.read_text(encoding="utf-8"))["jobs"]
    steps = jobs["dependabot-auto-merge"]["steps"]
    return next(s for s in steps if "gh pr merge" in s.get("run", ""))


def _run(tmp_path: Path, polls: list[str], head_now: str = SHA, review_rc: int = 0):
    stub = tmp_path / "stub"
    stub.mkdir()
    for i, body in enumerate(polls, 1):
        (stub / f"checks.{i}").write_text(body, encoding="utf-8")
    for name, body in (("gh", _GH), ("sleep", "#!/bin/sh\n")):
        (stub / name).write_text(body, encoding="utf-8")
        (stub / name).chmod(0o755)
    step = _step()
    env = {k: str(v) for k, v in step["env"].items() if "${{" not in str(v)}
    env |= {
        "PATH": f"{stub}{os.pathsep}{os.environ['PATH']}",
        "STUB": str(stub),
        "PR_URL": "https://github.com/o/r/pull/1",
        "HEAD_SHA": SHA,
        "UPDATE_TYPE": "version-update:semver-patch",
        "HEAD_NOW": head_now,
        "REVIEW_RC": str(review_rc),
    }
    # Actions runs `run:` blocks with `bash -e {0}`.
    proc = subprocess.run(
        ["bash", "-e", "-c", step["run"]], env=env, capture_output=True, text=True, check=False
    )
    calls = (stub / "calls").read_text(encoding="utf-8").splitlines()
    return proc, calls


def _verbs(calls: list[str]) -> list[str]:
    return [" ".join(c.split()[:2]) for c in calls]


def test_waits_for_non_required_checks_then_approves_and_merges_pinned(tmp_path: Path):
    proc, calls = _run(tmp_path, ["pass ci\npending e2e\n", "pass ci\npass e2e\n"])
    assert proc.returncode == 0, proc.stderr
    verbs = _verbs(calls)
    assert verbs.count("pr checks") == 2
    assert verbs.index("pr review") > max(i for i, v in enumerate(verbs) if v == "pr checks")
    merge = next(c for c in calls if c.startswith("pr merge"))
    assert f"--match-head-commit {SHA}" in merge


def test_waits_until_the_gating_check_is_reported(tmp_path: Path):
    proc, calls = _run(tmp_path, ["", "pending ci\n", "pass ci\n"])
    assert proc.returncode == 0, proc.stderr
    assert _verbs(calls).count("pr checks") == 3


@pytest.mark.parametrize(
    ("checks", "why"),
    [
        ("pass ci\nfail e2e\n", "failed"),
        ("pass ci\ncancel e2e\n", "cancelled"),
        ("skipping ci\npass e2e\n", "skipped"),
    ],
)
def test_never_approves_on_a_bad_check(tmp_path: Path, checks: str, why: str):
    proc, calls = _run(tmp_path, [checks])
    assert proc.returncode == 1
    assert why in proc.stdout
    assert "pr review" not in _verbs(calls)
    assert "pr merge" not in _verbs(calls)


def test_moved_head_exits_clean_without_approving(tmp_path: Path):
    proc, calls = _run(tmp_path, ["pass ci\n"], head_now="b" * 40)
    assert proc.returncode == 0, proc.stderr
    assert "pr review" not in _verbs(calls)


def test_refused_approval_names_the_repo_setting(tmp_path: Path):
    proc, calls = _run(tmp_path, ["pass ci\n"], review_rc=1)
    assert proc.returncode == 1
    assert "Allow GitHub Actions to create and approve pull requests" in proc.stdout
    assert "pr merge" not in _verbs(calls)

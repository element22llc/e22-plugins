"""Behaviour of the shipped dependabot-auto-merge.yml merge step (#660, #687).

The step's ``run`` script is extracted from the template and executed against a
stub ``gh`` that replays the PR's required checks, so the test exercises the
shipped text. The contract: arm native auto-merge only when every gating check is
required by branch protection, pinned to the triggering head, without waiting on
the checks themselves.
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
"pr merge") exit "${MERGE_RC:-0}" ;;
esac
"""


def _step() -> dict:
    jobs = yaml.safe_load(WORKFLOW.read_text(encoding="utf-8"))["jobs"]
    steps = jobs["dependabot-auto-merge"]["steps"]
    return next(s for s in steps if "gh pr merge" in s.get("run", ""))


def _run(
    tmp_path: Path,
    polls: list[str],
    head_now: str = SHA,
    review_rc: int = 0,
    merge_rc: int = 0,
    gating: str | None = None,
):
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
        "MERGE_RC": str(merge_rc),
    }
    if gating is not None:
        env["GATING_CHECKS"] = gating
    # Actions runs `run:` blocks with `bash -e {0}`.
    proc = subprocess.run(
        ["bash", "-e", "-c", step["run"]], env=env, capture_output=True, text=True, check=False
    )
    calls = (stub / "calls").read_text(encoding="utf-8").splitlines()
    return proc, calls


def _verbs(calls: list[str]) -> list[str]:
    return [" ".join(c.split()[:2]) for c in calls]


def test_arms_auto_merge_pinned_to_head_without_waiting(tmp_path: Path):
    proc, calls = _run(tmp_path, ["ci\ne2e\n"])
    assert proc.returncode == 0, proc.stderr
    assert _verbs(calls) == ["pr checks", "pr review", "pr merge"]
    merge = calls[-1]
    assert "--auto" in merge
    assert f"--match-head-commit {SHA}" in merge


def test_waits_until_the_gating_check_is_registered(tmp_path: Path):
    proc, calls = _run(tmp_path, ["", "ci\n"])
    assert proc.returncode == 0, proc.stderr
    assert _verbs(calls).count("pr checks") == 2
    assert "pr merge" in _verbs(calls)


@pytest.mark.parametrize(
    ("required", "gating"),
    [("", None), ("e2e\n", None), ("ci\n", "ci e2e")],
)
def test_never_arms_when_a_gating_check_is_not_required(
    tmp_path: Path, required: str, gating: str | None
):
    proc, calls = _run(tmp_path, [required], gating=gating)
    assert proc.returncode == 1
    assert "Not a required check" in proc.stdout
    assert _verbs(calls).count("pr checks") == 6
    assert "pr review" not in _verbs(calls)
    assert "pr merge" not in _verbs(calls)


def test_refused_approval_names_the_repo_setting(tmp_path: Path):
    proc, calls = _run(tmp_path, ["ci\n"], review_rc=1)
    assert proc.returncode == 1
    assert "Allow GitHub Actions to create and approve pull requests" in proc.stdout
    assert "pr merge" not in _verbs(calls)


def test_refused_auto_merge_names_the_repo_setting(tmp_path: Path):
    proc, _ = _run(tmp_path, ["ci\n"], merge_rc=1)
    assert proc.returncode == 1
    assert "Allow auto-merge" in proc.stdout


def test_refused_auto_merge_on_a_moved_head_exits_clean(tmp_path: Path):
    proc, _ = _run(tmp_path, ["ci\n"], merge_rc=1, head_now="b" * 40)
    assert proc.returncode == 0, proc.stderr
    assert "head moved" in proc.stdout

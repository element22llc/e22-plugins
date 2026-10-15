"""Behaviour of the shipped Dependabot auto-merge job in ci.yml (#660, #687, #736).

The merge step's ``run`` script is extracted from the template and executed against a
stub ``gh`` that replays the PR's commits through the step's own ``--jq`` filter, so
the test exercises the shipped text. The contract: merge only the head ``ci`` tested,
only when every commit is Dependabot's, never by approving, and never where branch
protection still wants a human review.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest
import yaml
from conftest import REPO_ROOT

TEMPLATES = REPO_ROOT / "plugins/steer/templates"
CI = TEMPLATES / "github/workflows/ci.yml"
SHA = "a" * 40

_GH = """#!/bin/sh
printf '%s\\n' "$*" | tr '\\n' ' ' >>"$STUB/calls"; echo >>"$STUB/calls"
case "$1 $2" in
api\\ *)
  [ "${API_RC:-0}" = 0 ] || exit "$API_RC"
  while [ "$#" -gt 0 ]; do
    [ "$1" = --jq ] && { shift; jq -r "$1" "$STUB/commits.json"; exit; }
    shift
  done ;;
"pr view")
  case "$*" in
  *reviewDecision*) printf '%s\\n' "$DECISION" ;;
  *) printf '%s\\n' "$HEAD_NOW" ;;
  esac ;;
"pr merge") exit "${MERGE_RC:-0}" ;;
esac
"""


def _commit(sha: str, author="dependabot[bot]", committer="web-flow", verified=True) -> dict:
    return {
        "sha": sha,
        "author": None if author is None else {"login": author},
        "committer": {"login": committer},
        "commit": {"verification": {"verified": verified}},
    }


DEPENDABOT = _commit(SHA)


def _job() -> dict:
    return yaml.safe_load(CI.read_text(encoding="utf-8"))["jobs"]["dependabot-auto-merge"]


def _merge_step() -> dict:
    return next(s for s in _job()["steps"] if "gh pr merge" in s.get("run", ""))


def _run(
    tmp_path: Path,
    commits: list[dict] | None = None,
    decision: str = "",
    head_now: str = SHA,
    merge_rc: int = 0,
    api_rc: int = 0,
):
    stub = tmp_path / "stub"
    stub.mkdir()
    (stub / "commits.json").write_text(json.dumps(commits or [DEPENDABOT]), encoding="utf-8")
    (stub / "gh").write_text(_GH, encoding="utf-8")
    (stub / "gh").chmod(0o755)
    env = {
        "PATH": f"{stub}{os.pathsep}{os.environ['PATH']}",
        "STUB": str(stub),
        "REPO": "o/r",
        "PR_NUMBER": "1",
        "PR_URL": "https://github.com/o/r/pull/1",
        "HEAD_SHA": SHA,
        "DECISION": decision,
        "HEAD_NOW": head_now,
        "MERGE_RC": str(merge_rc),
        "API_RC": str(api_rc),
    }
    # Actions runs an unspecified `shell:` as `bash -e -o pipefail {0}`.
    proc = subprocess.run(
        ["bash", "-e", "-o", "pipefail", "-c", _merge_step()["run"]],
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )
    calls_file = stub / "calls"
    calls = calls_file.read_text(encoding="utf-8").splitlines() if calls_file.exists() else []
    return proc, calls


def _verbs(calls: list[str]) -> list[str]:
    return [" ".join(c.split()[:2]) for c in calls]


needs_jq = pytest.mark.skipif(shutil.which("jq") is None, reason="the stub replays --jq with jq")


@needs_jq
@pytest.mark.parametrize("decision", ["", "APPROVED"])
def test_merges_the_tested_head_without_approving(tmp_path: Path, decision: str):
    proc, calls = _run(tmp_path, decision=decision)
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert _verbs(calls) == ["api --paginate", "pr view", "pr merge"]
    assert "repos/o/r/pulls/1/commits" in calls[0]
    merge = calls[-1]
    assert f"--match-head-commit {SHA}" in merge
    assert "--auto" not in merge
    assert not any(c.startswith("pr review") for c in calls)


@needs_jq
@pytest.mark.parametrize(
    "foreign",
    [
        _commit("b" * 40, author="writer"),
        _commit("b" * 40, author=None),
        _commit("b" * 40, committer="writer"),
        _commit("b" * 40, verified=False),
    ],
    ids=["other-author", "unmapped-author", "other-committer", "unverified"],
)
def test_refuses_a_branch_with_a_commit_that_is_not_dependabots(tmp_path: Path, foreign: dict):
    proc, calls = _run(tmp_path, commits=[DEPENDABOT, foreign])
    assert proc.returncode == 1
    assert "b" * 40 in proc.stdout
    assert "a" * 40 not in proc.stdout
    assert "pr merge" not in _verbs(calls)


@needs_jq
@pytest.mark.parametrize("decision", ["REVIEW_REQUIRED", "CHANGES_REQUESTED"])
def test_leaves_the_merge_to_a_human_when_a_review_is_wanted(tmp_path: Path, decision: str):
    proc, calls = _run(tmp_path, decision=decision)
    assert proc.returncode == 0, proc.stderr
    assert "::notice::" in proc.stdout
    assert "pr merge" not in _verbs(calls)


def test_fails_closed_when_the_commit_list_is_unreadable(tmp_path: Path):
    proc, calls = _run(tmp_path, api_rc=1)
    assert proc.returncode != 0
    assert "pr merge" not in _verbs(calls)


@needs_jq
def test_refused_merge_on_a_moved_head_exits_clean(tmp_path: Path):
    proc, _ = _run(tmp_path, merge_rc=1, head_now="b" * 40)
    assert proc.returncode == 0, proc.stderr
    assert "head moved" in proc.stdout


@needs_jq
def test_refused_merge_on_the_same_head_fails(tmp_path: Path):
    proc, _ = _run(tmp_path, merge_rc=1)
    assert proc.returncode == 1
    assert "needs" in proc.stdout


def test_job_runs_after_ci_scoped_to_dependabot_with_its_own_write_scopes():
    workflow = yaml.safe_load(CI.read_text(encoding="utf-8"))
    job = workflow["jobs"]["dependabot-auto-merge"]
    assert job["needs"] == "ci"
    for guard in (
        "github.event_name == 'pull_request'",
        "github.event.pull_request.user.login == 'dependabot[bot]'",
        "github.actor == 'dependabot[bot]'",
    ):
        assert guard in job["if"]
    assert job["permissions"] == {"contents": "write", "pull-requests": "write"}
    assert workflow["permissions"] == {"contents": "read"}
    assert not any("actions/checkout" in s.get("uses", "") for s in job["steps"])
    assert "pull_request_target" not in workflow[True]


def test_standalone_workflow_and_approval_grant_are_retired():
    assert not (TEMPLATES / "github/workflows/dependabot-auto-merge.yml").exists()
    for policy in (
        TEMPLATES / "scaffold/policy/branch-protection.yml",
        REPO_ROOT / "plugins/steer/policy/branch-protection.yml",
    ):
        data = yaml.safe_load(policy.read_text(encoding="utf-8"))
        assert data["schema"] == 6
        assert "actions_can_approve_pull_requests" not in data
        assert "allow_auto_merge" not in data

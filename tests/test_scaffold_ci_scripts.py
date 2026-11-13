"""Behavior of the scaffold's ``ci-*.sh`` gates, which run in every consumer repo's CI.

Each test runs the real script under ``sh`` in a throwaway git repo, with every
external tool (pnpm, biome, ruff, docker, uvx, mise, ...) replaced by a stub
that records its argv - so a test asserts what the gate *invokes* and whether a
tool failure fails the gate, without the toolchain installed.
"""

from __future__ import annotations

import json
import os
import subprocess
from dataclasses import dataclass
from pathlib import Path

import pytest
from conftest import REPO_ROOT

SCRIPTS = REPO_ROOT / "plugins" / "steer" / "templates" / "scaffold" / "scripts"
STUBBED = (
    "pnpm",
    "biome",
    "ruff",
    "docker",
    "uvx",
    "mise",
    "actionlint",
    "shellcheck",
    "trivy",
    "semgrep",
    "gitleaks",
)
_STUB = """#!/bin/sh
name="$(basename "$0")"
printf '%s\\n' "${name} $*" >>"${STUB_LOG}"
if [ "${name}" = uvx ]; then printf 'diff-cover report\\n' >coverage-diff.md; fi
case " ${STUB_FAIL:-} " in *" ${name} "*) exit 3 ;; esac
"""
_GIT = ("git", "-c", "user.name=t", "-c", "user.email=t@example.com", "-c", "commit.gpgsign=false")


@dataclass
class Run:
    code: int
    out: str
    calls: list[str]


class Repo:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.bin = root.parent / "bin"
        self.log = root.parent / "calls.log"
        self.summary = root.parent / "summary.md"
        self.tmp = root.parent / "tmp"
        (root / "scripts").mkdir(parents=True)
        self.tmp.mkdir()
        self.bin.mkdir()
        for name in STUBBED:
            stub = self.bin / name
            stub.write_text(_STUB, encoding="utf-8")
            stub.chmod(0o755)
        self.git("init", "-q", "-b", "main")

    def git(self, *args: str) -> str:
        return subprocess.run(
            [*_GIT, *args], cwd=self.root, check=True, capture_output=True, text=True
        ).stdout.strip()

    def write(self, rel: str, text: str = "", *, track: bool = True) -> None:
        path = self.root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        if track:
            self.git("add", rel)

    def commit(self, msg: str = "c") -> str:
        self.git("commit", "-q", "--allow-empty", "-m", msg)
        return self.git("rev-parse", "HEAD")

    def run(self, script: str, **env: str) -> Run:
        for name in ("ci-lib.sh", script):
            (self.root / "scripts" / name).write_bytes((SCRIPTS / name).read_bytes())
        self.log.write_text("", encoding="utf-8")
        # A clean env, not os.environ: under GitHub Actions the inherited
        # GITHUB_STEP_SUMMARY and event vars would leak into the gate under test.
        base = {
            "PATH": f"{self.bin}{os.pathsep}{os.environ['PATH']}",
            "HOME": str(self.root.parent),
            "GIT_CONFIG_GLOBAL": os.devnull,
            "STUB_LOG": str(self.log),
            "GITHUB_STEP_SUMMARY": str(self.summary),
            "TMPDIR": str(self.tmp),
        }
        proc = subprocess.run(
            ["sh", f"scripts/{script}"],
            cwd=self.root,
            env={**base, **env},
            capture_output=True,
            text=True,
        )
        calls = self.log.read_text(encoding="utf-8").splitlines()
        return Run(proc.returncode, proc.stdout + proc.stderr, calls)


@pytest.fixture
def repo(tmp_path: Path) -> Repo:
    return Repo(tmp_path / "repo")


def test_deps_skips_without_node(repo: Repo) -> None:
    r = repo.run("ci-deps.sh")
    assert (r.code, r.calls) == (0, [])
    assert "::notice::No Node workspace" in r.out


def test_deps_freezes_an_existing_lockfile(repo: Repo) -> None:
    repo.write("package.json", "{}")
    repo.write("pnpm-lock.yaml")
    assert repo.run("ci-deps.sh").calls == ["pnpm install --frozen-lockfile"]


def test_deps_installs_unfrozen_before_the_first_lockfile(repo: Repo) -> None:
    repo.write("pnpm-workspace.yaml")
    assert repo.run("ci-deps.sh").calls == ["pnpm install --no-frozen-lockfile"]


def test_deps_fails_when_install_fails(repo: Repo) -> None:
    repo.write("package.json", "{}")
    assert repo.run("ci-deps.sh", STUB_FAIL="pnpm").code != 0


def test_typecheck_skips_without_node(repo: Repo) -> None:
    r = repo.run("ci-typecheck.sh")
    assert (r.code, r.calls) == (0, [])


def test_typecheck_runs_the_workspace_script_and_propagates_failure(repo: Repo) -> None:
    repo.write("package.json", "{}")
    assert repo.run("ci-typecheck.sh").calls == ["pnpm run typecheck"]
    assert repo.run("ci-typecheck.sh", STUB_FAIL="pnpm").code != 0


def test_lint_without_a_stack_runs_nothing(repo: Repo) -> None:
    r = repo.run("ci-lint.sh")
    assert (r.code, r.calls) == (0, [])
    assert "::notice::No Node or Python stack" in r.out


def test_lint_runs_every_detected_stack(repo: Repo) -> None:
    repo.write("package.json", "{}")
    repo.write("pyproject.toml")
    assert repo.run("ci-lint.sh").calls == ["biome ci .", "ruff check .", "ruff format --check ."]


def test_lint_detects_a_nested_tracked_pyproject(repo: Repo) -> None:
    repo.write("apps/api/pyproject.toml")
    assert repo.run("ci-lint.sh").calls == ["ruff check .", "ruff format --check ."]


def test_lint_stops_at_the_first_failing_linter(repo: Repo) -> None:
    repo.write("package.json", "{}")
    repo.write("pyproject.toml")
    r = repo.run("ci-lint.sh", STUB_FAIL="biome")
    assert r.code != 0
    assert r.calls == ["biome ci ."]


def test_image_skips_without_a_dockerfile(repo: Repo) -> None:
    repo.write("Dockerfile", track=False)
    r = repo.run("ci-image.sh")
    assert (r.code, r.calls) == (0, [])
    assert "::notice::No Dockerfile found" in r.out


def test_image_builds_each_tracked_dockerfile_from_the_repo_root(repo: Repo) -> None:
    repo.write("Dockerfile")
    repo.write("apps/web/Dockerfile")
    assert sorted(repo.run("ci-image.sh").calls) == [
        "docker build -f Dockerfile .",
        "docker build -f apps/web/Dockerfile --build-arg APP=web .",
    ]


def test_image_fails_when_a_build_fails(repo: Repo) -> None:
    repo.write("apps/web/Dockerfile")
    assert repo.run("ci-image.sh", STUB_FAIL="docker").code != 0


_GITLEAKS = "gitleaks git --no-banner --redact --log-opts=HEAD ."
_TRIVY = "trivy fs --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1"
# The argv ends in the per-run temp file Semgrep writes its findings to.
_SEMGREP = (
    "semgrep scan --config p/default --severity ERROR --error --metrics off --quiet"
    " --json --output "
)


def test_security_scans_secrets_even_without_a_stack(repo: Repo) -> None:
    r = repo.run("ci-security.sh")
    assert (r.code, r.calls) == (0, [_GITLEAKS])
    assert "::notice::No Node or Python stack detected" in r.out


def test_security_scans_secrets_then_dependencies_then_code(repo: Repo) -> None:
    repo.write("package.json", "{}")
    r = repo.run("ci-security.sh")
    assert r.code == 0
    calls = r.calls
    assert calls[:2] == [_GITLEAKS, f"{_TRIVY} ."]
    assert len(calls) == 3
    assert calls[2].startswith(_SEMGREP)


def test_security_fails_on_a_committed_secret(repo: Repo) -> None:
    repo.write("package.json", "{}")
    r = repo.run("ci-security.sh", STUB_FAIL="gitleaks")
    assert r.code != 0
    assert r.calls == [_GITLEAKS]


def test_security_honours_the_expiring_ignore_file(repo: Repo) -> None:
    repo.write("pyproject.toml")
    repo.write(".trivyignore.yaml", "vulnerabilities: []\n")
    calls = repo.run("ci-security.sh").calls
    assert calls[1] == f"{_TRIVY} --ignorefile .trivyignore.yaml ."


def test_security_fails_on_a_dependency_finding(repo: Repo) -> None:
    repo.write("package.json", "{}")
    r = repo.run("ci-security.sh", STUB_FAIL="trivy")
    assert r.code != 0
    assert r.calls == [_GITLEAKS, f"{_TRIVY} ."]


def test_security_propagates_a_semgrep_failure_without_its_output(repo: Repo) -> None:
    repo.write("package.json", "{}")
    r = repo.run("ci-security.sh", STUB_FAIL="semgrep")
    assert r.code == 3
    assert "Semgrep failed (exit 3)" in r.out


_FAKE_TOKEN = "fake_token_DO_NOT_USE_0000000000000000000000000000000000000000"
# Shaped like semgrep 1.184 `--json`: the match reaches extra.message (metavariable
# interpolation), extra.lines (when logged in) and a syntax error's message.
_FINDINGS = {
    "version": "1.184.0",
    "results": [
        {
            "check_id": "generic.secrets.security.detected-npm-token",
            "path": ".npmrc",
            "start": {"line": 3, "col": 1, "offset": 40},
            "end": {"line": 3, "col": 90, "offset": 129},
            "extra": {
                "message": f"npm token {_FAKE_TOKEN} detected",
                "severity": "ERROR",
                "lines": f"//registry.example/:_authToken={_FAKE_TOKEN}",
            },
        },
        {
            "check_id": "javascript.lang.security.audit.eval",
            "path": "src/a.js",
            "start": {"line": 12, "col": 5, "offset": 300},
            "end": {"line": 12, "col": 30, "offset": 325},
            "extra": {
                "message": f"eval of {_FAKE_TOKEN}",
                "severity": "ERROR",
                "lines": _FAKE_TOKEN,
            },
        },
    ],
    "errors": [
        {
            "code": 3,
            "level": "warn",
            "type": "Syntax error",
            "message": f'Syntax error at line bad.js:1:\n `t = "{_FAKE_TOKEN}"` was unexpected',
            "path": "bad.js",
        }
    ],
}
# Prints the token on both streams, as text-mode semgrep does, and writes the JSON
# wherever --output points.
_SEMGREP_FINDINGS_STUB = """#!/bin/sh
printf '%s\\n' "semgrep $*" >>"${STUB_LOG}"
printf '   1| //registry.example/:_authToken=%s\\n' "${FAKE_TOKEN}"
printf '%s\\n' "${FAKE_TOKEN}" >&2
while [ $# -gt 0 ]; do
	if [ "$1" = --output ]; then cp "${FINDINGS_JSON}" "$2"; fi
	shift
done
exit 1
"""


def test_security_reports_code_findings_without_the_matched_source(repo: Repo) -> None:
    repo.write("package.json", "{}")
    findings = repo.root.parent / "findings.json"
    findings.write_text(json.dumps(_FINDINGS, separators=(",", ":")), encoding="utf-8")
    (repo.bin / "semgrep").write_text(_SEMGREP_FINDINGS_STUB, encoding="utf-8")
    r = repo.run("ci-security.sh", FAKE_TOKEN=_FAKE_TOKEN, FINDINGS_JSON=str(findings))
    assert r.code == 1
    assert _FAKE_TOKEN not in r.out
    assert "generic.secrets.security.detected-npm-token .npmrc:3" in r.out
    assert "javascript.lang.security.audit.eval src/a.js:12" in r.out
    assert list(repo.tmp.iterdir()) == []


def test_hygiene_on_an_empty_repo_still_validates_tasks(repo: Repo) -> None:
    r = repo.run("ci-hygiene.sh")
    assert r.code == 0
    assert r.calls == ["mise tasks validate --errors-only"]
    assert "::notice::No application or infra stack detected" in r.out


@pytest.mark.parametrize(
    ("files", "stack"),
    [
        (["package.json"], "node"),
        (["infra/main.tf"], "terraform"),
        (["ansible.cfg"], "ansible"),
        (["roles/web/tasks/main.yml", "playbooks/site.yml"], "ansible"),
        (["Pulumi.yaml"], "pulumi"),
    ],
)
def test_hygiene_reports_the_detected_stack(repo: Repo, files: list[str], stack: str) -> None:
    for f in files:
        repo.write(f)
    assert f"Detected stack: {stack}\n" in repo.run("ci-hygiene.sh").out


def test_hygiene_does_not_take_bare_roles_for_ansible(repo: Repo) -> None:
    repo.write("roles/web/tasks/main.yml")
    assert "Detected stack" not in repo.run("ci-hygiene.sh").out


def test_hygiene_lints_workflows_tracked_shell_and_version_pins(repo: Repo) -> None:
    repo.write(".github/workflows/ci.yml")
    repo.write("bin/tracked.sh")
    repo.write("bin/untracked.sh", track=False)
    repo.write("scripts/scan-version-pins.sh", 'printf "scan %s\\n" "$1" >>"${STUB_LOG}"\n')
    r = repo.run("ci-hygiene.sh")
    assert r.code == 0
    assert "actionlint -color" in r.calls
    assert "scan ." in r.calls
    [lint] = [c for c in r.calls if c.startswith("shellcheck")]
    assert "bin/tracked.sh" in lint
    assert "untracked" not in lint


@pytest.mark.parametrize("tool", ["mise", "shellcheck"])
def test_hygiene_fails_when_a_check_fails(repo: Repo, tool: str) -> None:
    repo.write("a.sh")
    assert repo.run("ci-hygiene.sh", STUB_FAIL=tool).code != 0


def test_coverage_skips_without_a_report(repo: Repo) -> None:
    r = repo.run("ci-coverage.sh")
    assert (r.code, r.calls) == (0, [])
    assert "::notice::No coverage report produced" in r.out


def test_coverage_fails_open_on_an_unresolvable_base(repo: Repo) -> None:
    repo.write("coverage/lcov.info")
    r = repo.run("ci-coverage.sh", STEER_CI_BASE="nope")
    assert (r.code, r.calls) == (0, [])
    assert "fail-open" in r.out


def _repo_with_report(repo: Repo) -> str:
    base = repo.commit("base")
    repo.write("apps/web/coverage/lcov.info")
    repo.commit("change")
    return base


def test_coverage_gates_changed_lines_against_the_base(repo: Repo) -> None:
    base = _repo_with_report(repo)
    r = repo.run("ci-coverage.sh", STEER_CI_BASE=base, COVERAGE_DIFF_MIN="90")
    assert r.code == 0
    # A package report reaches diff-cover as a rebased temp copy (SF: paths prefixed).
    [call] = r.calls
    report, rest = call.removeprefix("uvx diff-cover@10.4.1 ").split(" ", 1)
    assert report.endswith("/apps_web.lcov.info")
    assert rest == f"--compare-branch {base} --fail-under 90 --markdown-report coverage-diff.md"
    assert "diff-cover report" in repo.summary.read_text(encoding="utf-8")


def test_coverage_fails_when_changed_lines_are_under_covered(repo: Repo) -> None:
    base = _repo_with_report(repo)
    r = repo.run("ci-coverage.sh", STEER_CI_BASE=base, STUB_FAIL="uvx")
    assert r.code == 1
    assert "::error::Changed lines are under 80% covered" in r.out


def test_coverage_on_push_skips_in_pr_flow(repo: Repo) -> None:
    base = _repo_with_report(repo)
    r = repo.run("ci-coverage.sh", STEER_CI_EVENT="push", STEER_CI_BEFORE=base)
    assert (r.code, r.calls) == (0, [])
    assert "PR already gated coverage" in r.out


def test_coverage_on_push_gates_solo_trunk(repo: Repo) -> None:
    repo.write("CLAUDE.md", "<!-- steer:delivery-mode=solo-trunk -->\n")
    base = _repo_with_report(repo)
    r = repo.run("ci-coverage.sh", STEER_CI_EVENT="push", STEER_CI_BEFORE=base)
    assert r.code == 0
    assert len(r.calls) == 1
    assert f"--compare-branch {base}" in r.calls[0]


def test_coverage_on_a_first_push_fails_open(repo: Repo) -> None:
    repo.write("CLAUDE.md", "<!-- steer:delivery-mode=solo-trunk -->\n")
    _repo_with_report(repo)
    r = repo.run("ci-coverage.sh", STEER_CI_EVENT="push", STEER_CI_BEFORE="0" * 40)
    assert (r.code, r.calls) == (0, [])
    assert "first push or force-push" in r.out

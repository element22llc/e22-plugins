"""Run shipped MIGRATIONS.md preconditions against fixture repos.

A precondition is the only gate on a migration: one that never fires leaves the
transform unapplied, one that always fires re-applies it every sync. These tests
execute the ledger's own command, so the prose and the test cannot drift.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

import check_migrations  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent
TEMPLATE_SETTINGS = REPO_ROOT / "plugins/steer/templates/scaffold/claude/settings.json"


def _precondition(what_fragment: str) -> str:
    text = (REPO_ROOT / check_migrations.LEDGER).read_text(encoding="utf-8")
    matches = [e for e in check_migrations.parse_entries(text) if what_fragment in e.what]
    assert len(matches) == 1, f"expected one ledger entry matching {what_fragment!r}"
    field = matches[0].field("Precondition") or ""
    block = re.search(r"```sh\n(.*?)```", field, re.S)
    assert block, "precondition carries no ```sh block"
    return block.group(1)


def _fires(cmd: str, repo: Path) -> bool:
    out = subprocess.run(["sh", "-c", cmd], cwd=repo, capture_output=True, text=True)
    return bool(out.stdout.strip())


def _settings(repo: Path, deny: list[str], allow: list[str] | None = None) -> None:
    (repo / ".claude").mkdir()
    perms = {"deny": deny, "allow": allow or []}
    (repo / ".claude/settings.json").write_text(
        json.dumps({"permissions": perms}, indent=2), encoding="utf-8"
    )


WIDE_ENV_DENY = "retires the wide `Bash(git add*.env*)` deny"


@pytest.mark.parametrize(
    ("deny", "expected"),
    [
        (["Bash(git add*.env*)"], True),
        (["Bash(git add*.env)", "Bash(git add*.env*)"], True),
        (["Bash(git add*.env)"], False),
        ([], False),
    ],
)
def test_wide_env_deny_precondition(tmp_path, deny, expected):
    _settings(tmp_path, deny)
    assert _fires(_precondition(WIDE_ENV_DENY), tmp_path) is expected


def test_wide_env_deny_precondition_without_settings(tmp_path):
    assert not _fires(_precondition(WIDE_ENV_DENY), tmp_path)


def test_wide_env_deny_precondition_is_silent_on_the_current_template(tmp_path):
    (tmp_path / ".claude").mkdir()
    (tmp_path / ".claude/settings.json").write_bytes(TEMPLATE_SETTINGS.read_bytes())
    assert not _fires(_precondition(WIDE_ENV_DENY), tmp_path)


WIDE_REMOTE_ALLOW = "retires the over-wide `Bash(git remote:*)` allow"


@pytest.mark.parametrize(
    ("allow", "deny", "expected"),
    [
        (["Bash(git remote:*)"], [], True),
        (["Bash(git remote -v)", "Bash(git remote:*)"], [], True),
        (["Bash(git remote -v)", "Bash(git remote show:*)"], [], False),
        ([], ["Bash(git remote:*)"], False),
    ],
)
def test_wide_remote_allow_precondition(tmp_path, allow, deny, expected):
    _settings(tmp_path, deny, allow)
    assert _fires(_precondition(WIDE_REMOTE_ALLOW), tmp_path) is expected


def test_wide_remote_allow_precondition_without_settings(tmp_path):
    assert not _fires(_precondition(WIDE_REMOTE_ALLOW), tmp_path)


def test_wide_remote_allow_precondition_is_silent_on_the_current_template(tmp_path):
    (tmp_path / ".claude").mkdir()
    (tmp_path / ".claude/settings.json").write_bytes(TEMPLATE_SETTINGS.read_bytes())
    assert not _fires(_precondition(WIDE_REMOTE_ALLOW), tmp_path)


SEMGREP_LOG = "keeps Semgrep's matched source out of the CI log"
TEMPLATE_CI_SECURITY = REPO_ROOT / "plugins/steer/templates/scaffold/scripts/ci-security.sh"


def test_semgrep_log_precondition_fires_on_the_v7_23_script(tmp_path):
    (tmp_path / "scripts").mkdir()
    (tmp_path / "scripts/ci-security.sh").write_text(
        "semgrep scan --config p/default --severity ERROR --error --metrics off --quiet\n",
        encoding="utf-8",
    )
    assert _fires(_precondition(SEMGREP_LOG), tmp_path)


def test_semgrep_log_precondition_without_the_script(tmp_path):
    assert not _fires(_precondition(SEMGREP_LOG), tmp_path)


def test_semgrep_log_precondition_is_silent_on_the_current_template(tmp_path):
    (tmp_path / "scripts").mkdir()
    (tmp_path / "scripts/ci-security.sh").write_bytes(TEMPLATE_CI_SECURITY.read_bytes())
    assert not _fires(_precondition(SEMGREP_LOG), tmp_path)


LOCKFILE = "shipped workflows use exact tags, locked in `actions.lock`"
LOCKFILE_RERUN = "re-run the lockfile migration a 7.23.0 sync skipped"


def _workflows(repo: Path, names: list[str]) -> None:
    wf = repo / ".github/workflows"
    wf.mkdir(parents=True)
    for name in names:
        (wf / name).write_text("on: push\n", encoding="utf-8")


@pytest.mark.parametrize("entry", [LOCKFILE, LOCKFILE_RERUN])
@pytest.mark.parametrize(
    ("files", "expected"),
    [
        (["ci.yml"], True),
        (["ci.yaml"], True),
        (["ci.yml", "release.yaml"], True),
        (["ci.yml", "actions.lock"], False),
        ([], False),
    ],
)
def test_lockfile_precondition(tmp_path, entry, files, expected):
    _workflows(tmp_path, files)
    assert _fires(_precondition(entry), tmp_path) is expected


@pytest.mark.parametrize("entry", [LOCKFILE, LOCKFILE_RERUN])
def test_lockfile_precondition_without_github_dir(tmp_path, entry):
    assert not _fires(_precondition(entry), tmp_path)


# The agent runs a precondition in the user's shell, and zsh's default nomatch
# aborts a command whose glob matches nothing. CI runners have no zsh, so this
# pins the trap locally only.
@pytest.mark.skipif(shutil.which("zsh") is None, reason="zsh not installed")
@pytest.mark.parametrize("entry", [LOCKFILE, LOCKFILE_RERUN])
def test_lockfile_precondition_fires_under_zsh(tmp_path, entry):
    _workflows(tmp_path, ["ci.yml"])
    out = subprocess.run(
        ["zsh", "-f", "-c", _precondition(entry)], cwd=tmp_path, capture_output=True, text=True
    )
    assert out.stdout.strip() == "stale"


RESTORED_SHA = "keep the tags a 7.23.0 lock run wrote over SHA pins"
SHA = "11bd71901bbe5b1630ceea73d27597364c9af683"


def _lock(workflow: str, refs: list[str], deps: list[str] | None = None) -> str:
    lines = ["version: 'v0.0.3'", "workflows:", f"    '.github/workflows/{workflow}':"]
    lines += [f"        - '{r}'" for r in refs]
    lines.append("dependencies:")
    for d in deps or []:
        lines += [f"    '{d}':", f"        ref: '{d.split('@')[1]}'"]
    return "\n".join(lines) + "\n"


TAG_LOCK = _lock("ci.yml", ["actions/checkout@v4.2.2"], ["actions/checkout@v4.2.2"])


def _sha_repo(repo: Path, line: str, lock: str | None, name: str = "ci.yml") -> None:
    wf = repo / ".github/workflows"
    wf.mkdir(parents=True)
    (wf / name).write_text(f"on: push\njobs:\n  a:\n    steps:\n      {line}\n", encoding="utf-8")
    if lock is not None:
        (wf / "actions.lock").write_text(lock, encoding="utf-8")


@pytest.mark.parametrize(
    ("line", "lock", "expected"),
    [
        (f"- uses: actions/checkout@{SHA} # v4.2.2", TAG_LOCK, True),
        (f"- uses: actions/checkout@{SHA}", TAG_LOCK, True),
        (f'- uses: "actions/checkout@{SHA}"', TAG_LOCK, True),
        (f"- uses: 'actions/checkout@{SHA}'", TAG_LOCK, True),
        (f"- uses: octo-org/tools/lint@{SHA}", TAG_LOCK, True),
        # Listed only as another workflow's or a transitive dependency's key.
        (f"- uses: actions/checkout@{SHA}", _lock("other.yml", [f"actions/checkout@{SHA}"]), True),
        (f"- uses: actions/checkout@{SHA}", _lock("ci.yml", [], [f"actions/checkout@{SHA}"]), True),
        (f"- uses: actions/checkout@{SHA}", _lock("ci.yml", [f"actions/checkout@{SHA}"]), False),
        (f'- uses: "actions/checkout@{SHA}"', _lock("ci.yml", [f"actions/checkout@{SHA}"]), False),
        ("- uses: actions/checkout@v4.2.2", TAG_LOCK, False),
        (f"# - uses: actions/checkout@{SHA}", TAG_LOCK, False),
        (f"- uses: octo-org/shared/.github/workflows/build.yml@{SHA}", TAG_LOCK, False),
        (f"- uses: actions/checkout@{SHA}", None, False),
    ],
)
def test_restored_sha_precondition(tmp_path, line, lock, expected):
    _sha_repo(tmp_path, line, lock)
    assert _fires(_precondition(RESTORED_SHA), tmp_path) is expected


def test_restored_sha_precondition_reads_yaml_workflows(tmp_path):
    _sha_repo(tmp_path, f"- uses: actions/checkout@{SHA}", TAG_LOCK, name="ci.yaml")
    assert _fires(_precondition(RESTORED_SHA), tmp_path)


def test_restored_sha_precondition_without_github_dir(tmp_path):
    assert not _fires(_precondition(RESTORED_SHA), tmp_path)


@pytest.mark.skipif(shutil.which("zsh") is None, reason="zsh not installed")
def test_restored_sha_precondition_fires_under_zsh(tmp_path):
    _sha_repo(tmp_path, f"- uses: actions/checkout@{SHA} # v4.2.2", TAG_LOCK)
    out = subprocess.run(
        ["zsh", "-f", "-c", _precondition(RESTORED_SHA)],
        cwd=tmp_path,
        capture_output=True,
        text=True,
    )
    assert out.stdout.strip() == f"ci.yml: actions/checkout@{SHA}"


YAMLLINT_CONFIG = "runs yamllint when any one config exists"
TEMPLATE_CI_IAC = REPO_ROOT / "plugins/steer/templates/scaffold/scripts/ci-iac.sh"


def test_yamllint_config_precondition_fires_on_the_old_check(tmp_path):
    (tmp_path / "scripts").mkdir()
    (tmp_path / "scripts/ci-iac.sh").write_text(
        "\tif ls .yamllint .yamllint.yml .yamllint.yaml >/dev/null 2>&1; then\n", encoding="utf-8"
    )
    assert _fires(_precondition(YAMLLINT_CONFIG), tmp_path)


def test_yamllint_config_precondition_is_silent_on_the_current_template(tmp_path):
    (tmp_path / "scripts").mkdir()
    (tmp_path / "scripts/ci-iac.sh").write_bytes(TEMPLATE_CI_IAC.read_bytes())
    assert not _fires(_precondition(YAMLLINT_CONFIG), tmp_path)


def test_yamllint_config_precondition_without_the_script(tmp_path):
    assert not _fires(_precondition(YAMLLINT_CONFIG), tmp_path)

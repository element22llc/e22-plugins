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


LAST_UPDATED = "`contract.md` drops the template's `Last updated` line"
TEMPLATE_CONTRACT = REPO_ROOT / "plugins/steer/templates/spec/feature-contract.md"


def _contract(repo: Path, feature: str, header: str, body: str = "## Behavior rules\n") -> None:
    d = repo / "spec/features" / feature
    d.mkdir(parents=True)
    text = f"# {feature} - Contract\n\n> Owner: dev team\n{header}> Implements: ./intent.md\n\n"
    (d / "contract.md").write_bytes((text + body).encode())


def _lines(cmd: str, repo: Path) -> list[str]:
    out = subprocess.run(["sh", "-c", cmd], cwd=repo, capture_output=True, text=True)
    return sorted(out.stdout.split())


@pytest.mark.parametrize(
    "header",
    [
        "> Last updated: 2026-03-02\n",
        "> Last updated: YYYY-MM-DD\n",
        "> Last updated: 2026-03-02  \n",
        "> Last updated: 2026-03-02\r\n",
    ],
)
def test_last_updated_precondition_fires_on_the_template_form(tmp_path, header):
    _contract(tmp_path, "refunds", header)
    assert _lines(_precondition(LAST_UPDATED), tmp_path) == ["spec/features/refunds/contract.md:4"]


@pytest.mark.parametrize(
    "header",
    [
        "> Last updated: 2026-03-02 - added partial refunds\n",
        "> Last updated: 2026-03-02 (#123)\n",
        ">  Last updated: 2026-03-02\n",
        "> **Last updated:** 2026-03-02\n",
        "",
    ],
)
def test_last_updated_precondition_leaves_a_customized_line(tmp_path, header):
    _contract(tmp_path, "refunds", header)
    assert _lines(_precondition(LAST_UPDATED), tmp_path) == []


def test_last_updated_precondition_ignores_the_line_below_the_header(tmp_path):
    _contract(tmp_path, "refunds", "", "## Behavior rules\n\n> Last updated: 2026-03-02\n")
    assert _lines(_precondition(LAST_UPDATED), tmp_path) == []


def test_last_updated_precondition_lists_every_stale_contract(tmp_path):
    _contract(tmp_path, "refunds", "> Last updated: 2026-03-02\n")
    _contract(tmp_path, "invoices", "> Last updated: 2026-03-02 - reworked\n")
    _contract(tmp_path, "payouts", "> Last updated: YYYY-MM-DD\n")
    assert _lines(_precondition(LAST_UPDATED), tmp_path) == [
        "spec/features/payouts/contract.md:4",
        "spec/features/refunds/contract.md:4",
    ]


def test_last_updated_precondition_is_silent_on_the_current_template(tmp_path):
    d = tmp_path / "spec/features/refunds"
    d.mkdir(parents=True)
    (d / "contract.md").write_bytes(TEMPLATE_CONTRACT.read_bytes())
    assert _lines(_precondition(LAST_UPDATED), tmp_path) == []


def test_last_updated_precondition_without_features(tmp_path):
    assert _lines(_precondition(LAST_UPDATED), tmp_path) == []


@pytest.mark.skipif(shutil.which("zsh") is None, reason="zsh not installed")
def test_last_updated_precondition_runs_under_zsh(tmp_path):
    _contract(tmp_path, "refunds", "> Last updated: 2026-03-02\n")
    out = subprocess.run(
        ["zsh", "-f", "-c", _precondition(LAST_UPDATED)],
        cwd=tmp_path,
        capture_output=True,
        text=True,
    )
    assert out.stdout.strip() == "spec/features/refunds/contract.md:4"


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
        # gh-actions-lock v0.4.1 keys a kept path action by owner/repo only.
        (f"- uses: octo-org/tools/lint@{SHA}", _lock("ci.yml", [f"octo-org/tools@{SHA}"]), False),
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


SEMGREP_UVX = "runs Semgrep pinned through `uvx`, not a `pipx:` tool"
TEMPLATE_SCAFFOLD = REPO_ROOT / "plugins/steer/templates/scaffold"


def _out(cmd: str, repo: Path) -> list[str]:
    out = subprocess.run(["sh", "-c", cmd], cwd=repo, capture_output=True, text=True)
    return out.stdout.split()


def test_semgrep_uvx_precondition_fires_on_the_v7_24_script_and_tool(tmp_path):
    (tmp_path / "scripts").mkdir()
    (tmp_path / "scripts/ci-security.sh").write_text(
        'semgrep scan --config p/default --json --output "${findings}" >/dev/null 2>&1 || rc=$?\n',
        encoding="utf-8",
    )
    (tmp_path / "mise.toml").write_text('[tools]\n"pipx:semgrep" = "latest"\n', encoding="utf-8")
    assert _out(_precondition(SEMGREP_UVX), tmp_path) == ["script", "tools"]


def test_semgrep_uvx_precondition_fires_on_a_hand_pinned_uvx_line(tmp_path):
    (tmp_path / "scripts").mkdir()
    (tmp_path / "scripts/ci-security.sh").write_text(
        "uvx --from semgrep==1.185.0 semgrep scan --config p/default --json --output x\n",
        encoding="utf-8",
    )
    assert _out(_precondition(SEMGREP_UVX), tmp_path) == ["script"]


def test_semgrep_uvx_precondition_fires_on_a_version_without_its_date(tmp_path):
    (tmp_path / "scripts").mkdir()
    (tmp_path / "scripts/ci-security.sh").write_text(
        "STEER_SEMGREP_VERSION=1.185.0\n"
        'uvx --from "semgrep==${STEER_SEMGREP_VERSION}" semgrep scan --config p/default\n',
        encoding="utf-8",
    )
    assert _out(_precondition(SEMGREP_UVX), tmp_path) == ["script"]


@pytest.mark.parametrize("config", ["mise.toml", "profiles/infra/mise.toml"])
def test_semgrep_uvx_precondition_is_silent_on_the_current_template(tmp_path, config):
    (tmp_path / "scripts").mkdir()
    (tmp_path / "scripts/ci-security.sh").write_bytes(TEMPLATE_CI_SECURITY.read_bytes())
    (tmp_path / "mise.toml").write_bytes((TEMPLATE_SCAFFOLD / config).read_bytes())
    assert _out(_precondition(SEMGREP_UVX), tmp_path) == []


def test_semgrep_uvx_precondition_ignores_a_commented_tool(tmp_path):
    (tmp_path / "mise.toml").write_text('[tools]\n# "pipx:semgrep" = "latest"\n', encoding="utf-8")
    assert _out(_precondition(SEMGREP_UVX), tmp_path) == []


def test_semgrep_uvx_precondition_without_the_files(tmp_path):
    assert _out(_precondition(SEMGREP_UVX), tmp_path) == []


RELOCK = "lock gitleaks and Trivy for every platform `mise.lock` covers"


def _lock(*tables: str) -> str:
    return "lockfile_version = 1\n\n" + "\n".join(f'{t}\nversion = "1.0.0"\n' for t in tables)


def test_relock_precondition_fires_on_a_tool_missing_a_platform(tmp_path):
    (tmp_path / "mise.lock").write_text(
        _lock(
            '[[tools."aqua:aquasecurity/trivy"]]',
            '[tools."aqua:aquasecurity/trivy"."platforms.linux-x64"]',
            '[tools."aqua:aquasecurity/trivy"."platforms.macos-arm64"]',
            '[[tools."aqua:gitleaks/gitleaks"]]',
        ),
        encoding="utf-8",
    )
    assert _out(_precondition(RELOCK), tmp_path) == ["aqua:gitleaks/gitleaks"]


def test_relock_precondition_is_silent_on_a_ci_locked_tool(tmp_path):
    # A windows-x64 table the tool lacks never fires: the entry keys on CI's platform.
    (tmp_path / "mise.lock").write_text(
        _lock(
            '[[tools."aqua:gitleaks/gitleaks"]]',
            '[tools."aqua:gitleaks/gitleaks"."platforms.linux-x64"]',
            '[[tools."pipx:semgrep"]]',
            '[tools.uv."platforms.windows-x64"]',
            "[[tools.uv]]",
            '[tools.uv."platforms.linux-x64"]',
        ),
        encoding="utf-8",
    )
    assert _out(_precondition(RELOCK), tmp_path) == []


def test_relock_precondition_fires_on_trivy_too(tmp_path):
    (tmp_path / "mise.lock").write_text(
        _lock('[[tools."aqua:aquasecurity/trivy"]]', '[tools.uv."platforms.linux-x64"]'),
        encoding="utf-8",
    )
    assert _out(_precondition(RELOCK), tmp_path) == ["aqua:aquasecurity/trivy"]


def test_relock_precondition_is_silent_on_a_host_only_lock(tmp_path):
    (tmp_path / "mise.lock").write_text(
        _lock('[[tools."aqua:gitleaks/gitleaks"]]', '[tools.uv."platforms.macos-arm64"]'),
        encoding="utf-8",
    )
    assert _out(_precondition(RELOCK), tmp_path) == []


def test_relock_precondition_without_a_lock(tmp_path):
    assert _out(_precondition(RELOCK), tmp_path) == []

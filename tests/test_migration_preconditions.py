"""Run shipped MIGRATIONS.md preconditions against fixture repos.

A precondition is the only gate on a migration: one that never fires leaves the
transform unapplied, one that always fires re-applies it every sync. These tests
execute the ledger's own command, so the prose and the test cannot drift.
"""

from __future__ import annotations

import json
import re
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

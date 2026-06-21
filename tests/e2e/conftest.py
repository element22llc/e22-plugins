"""Fixtures for the headless end-to-end skill suite.

These tests drive the real `claude` CLI against a throwaway git repo and assert
on the files a skill produces. They are slow and spend tokens, so they are
marked ``@pytest.mark.e2e`` and excluded from the default run (see
``pyproject.toml`` ``addopts``); run them with ``mise run e2e``.

This dir IS a package (it has ``__init__.py``): without it, pytest's prepend
import mode would register a second top-level ``conftest`` module here, shadowing
``tests/conftest.py`` and breaking the flat tests' ``from conftest import
REPO_ROOT``. As a package, this conftest imports as ``e2e.conftest`` and the
sibling helpers are reached with relative imports (``from .run_steer import``).
"""

from __future__ import annotations

import subprocess
from pathlib import Path

import pytest


def _git(repo: Path, *args: str) -> None:
    subprocess.run(["git", *args], cwd=str(repo), check=True, capture_output=True, text=True)


@pytest.fixture
def seed_repo(tmp_path: Path) -> Path:
    """A genuinely greenfield repo: an empty git working tree, one empty initial
    commit, no remote. Mirrors the temp-repo style of
    ``plugins/steer/hooks/tests/run.sh`` (``git_repo``), translated to Python."""
    repo = tmp_path / "greenfield"
    repo.mkdir()
    _git(repo, "init", "-q")
    _git(repo, "config", "user.email", "e2e@example.com")
    _git(repo, "config", "user.name", "e2e")
    _git(repo, "commit", "-q", "--allow-empty", "-m", "init")
    return repo

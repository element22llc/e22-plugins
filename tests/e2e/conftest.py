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
from dataclasses import dataclass
from pathlib import Path

import pytest


def _git(repo: Path, *args: str) -> None:
    subprocess.run(["git", *args], cwd=str(repo), check=True, capture_output=True, text=True)


def _init_commit(repo: Path) -> None:
    _git(repo, "init", "-q")
    _git(repo, "config", "user.email", "e2e@example.com")
    _git(repo, "config", "user.name", "e2e")
    _git(repo, "add", "-A")
    _git(repo, "commit", "-q", "--allow-empty", "-m", "init")


@pytest.fixture
def seed_repo(tmp_path: Path) -> Path:
    """A genuinely greenfield repo: an empty git working tree, one empty initial
    commit, no remote. Mirrors the temp-repo style of
    ``plugins/steer/hooks/tests/run.sh`` (``git_repo``), translated to Python."""
    repo = tmp_path / "greenfield"
    repo.mkdir()
    _init_commit(repo)
    return repo


# --- existing-app fixture (for /steer:adopt) ------------------------------

# Real working code adopt must NOT rewrite, and a custom .gitignore line the
# additive scaffold merge must preserve. Kept as module constants so the test
# can assert against the exact seeded content.
CORE_SRC = '''"""Widget pricing core — pre-existing working code."""


def price(units: int, unit_cost: float, *, discount: float = 0.0) -> float:
    if units < 0:
        raise ValueError("units must be non-negative")
    gross = units * unit_cost
    return round(gross * (1.0 - discount), 2)
'''

GITIGNORE_MARKER = "# steer-e2e-keepme-custom-ignore"
_GITIGNORE_SRC = f"{GITIGNORE_MARKER}\n__pycache__/\nmy_local_notes/\n"


@dataclass
class ExistingApp:
    repo: Path
    core_rel: str
    core_src: str
    gitignore_marker: str


@pytest.fixture
def existing_app_repo(tmp_path: Path) -> ExistingApp:
    """A 'vibe-coded' app: real source, a README, and a custom .gitignore, but
    NO ``/spec`` — the shape ``/steer:adopt`` reverse-engineers. Committed so a
    later working-tree diff would show anything adopt mutated."""
    repo = tmp_path / "existing-app"
    pkg = repo / "src" / "widgets"
    pkg.mkdir(parents=True)
    (pkg / "__init__.py").write_text("", encoding="utf-8")
    core_rel = "src/widgets/core.py"
    (repo / core_rel).write_text(CORE_SRC, encoding="utf-8")
    (pkg / "api.py").write_text(
        "from .core import price\n\n\ndef quote(n):\n    return price(n, 9.99)\n",
        encoding="utf-8",
    )
    (repo / "pyproject.toml").write_text(
        '[project]\nname = "widgets"\nversion = "0.3.1"\nrequires-python = ">=3.12"\n',
        encoding="utf-8",
    )
    (repo / "README.md").write_text(
        "# widgets\n\nA small widget pricing service. Vibe-coded, no spec yet.\n",
        encoding="utf-8",
    )
    (repo / ".gitignore").write_text(_GITIGNORE_SRC, encoding="utf-8")
    _init_commit(repo)
    return ExistingApp(
        repo=repo,
        core_rel=core_rel,
        core_src=CORE_SRC,
        gitignore_marker=GITIGNORE_MARKER,
    )

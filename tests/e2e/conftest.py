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


# --- drift fixture (for /steer:drift) -------------------------------------
#
# drift compares an as-built /spec spine (with a feature) against a tracker-spec
# export and reports divergences. init never produces a feature (greenfield), and
# running adopt to get one is a ~$4 extra live run — so we hand-seed a believable
# adopted-style spine + a tracker export that DIVERGES from it. The as-built spec
# says the export emits a `phone` column and XLSX; the tracker issue (Done) asks
# only for CSV with name+email — so phone/XLSX are drift the report should surface.

# Tokens the as-built spec has but the tracker intent does not — drift should name
# at least one. Lower-cased substrings, matched leniently against the report text.
DRIFT_SIGNALS = ("phone", "xlsx")

_CONTRACT_MD = """# Contract — customer-export (as-built)

Derived from the code; describes what the export actually does today.

## Behavior

- Emits one row per customer with columns: `name`, `email`, `phone`.
- Supports two output formats: CSV and XLSX.

Evidence: `src/export.py:1`
"""

_INTENT_MD = """# Intent — customer-export

Export customer records for downstream billing.

## Open questions

- (none)
"""

_TRACKER_ISSUE = """# Issue #1 — Customer export

Status: Done

## Acceptance criteria

- Export customers as a CSV file.
- Columns are exactly `name` and `email`.
"""


# A minimal but believable /spec spine, shared by the fixtures that need a
# bootstrapped repo without paying for a live init/adopt.
_SPINE_FILES = (
    ("vision.md", "# Vision\n\nA billing tool.\n"),
    ("users.md", "# Users\n\nBilling ops.\n"),
    ("glossary.md", "# Glossary\n\n- customer: a billed account.\n"),
    ("HISTORY.md", "# History\n\n- 2026-01-01 — seeded.\n"),
    ("tracker.md", "system: github\n"),
)


def _seed_spine(repo: Path, version: str = "2.0.0") -> None:
    (repo / "spec").mkdir(parents=True, exist_ok=True)
    (repo / "spec" / ".version").write_text(f"{version}\n", encoding="utf-8")
    for name, body in _SPINE_FILES:
        (repo / "spec" / name).write_text(body, encoding="utf-8")


@pytest.fixture
def drift_repo(tmp_path: Path) -> Path:
    """A bootstrapped repo whose as-built feature spec diverges from its tracker
    export: the spec emits a `phone` column + XLSX the tracker (Done) never asked
    for. drift should flag that and, being read-only, mutate nothing."""
    repo = tmp_path / "drift-app"
    _seed_spine(repo)
    feat = repo / "spec" / "features" / "customer-export"
    feat.mkdir(parents=True)
    (repo / "src").mkdir()
    (repo / "tracker-export").mkdir()

    (feat / "intent.md").write_text(_INTENT_MD, encoding="utf-8")
    (feat / "contract.md").write_text(_CONTRACT_MD, encoding="utf-8")
    (repo / "src" / "export.py").write_text(
        'def export(customers, fmt="csv"):\n'
        '    """Emit name, email, phone as CSV or XLSX."""\n'
        "    ...\n",
        encoding="utf-8",
    )
    (repo / "tracker-export" / "issue-1.md").write_text(_TRACKER_ISSUE, encoding="utf-8")
    _init_commit(repo)
    return repo


@pytest.fixture
def spec_repo(tmp_path: Path) -> Path:
    """A bootstrapped repo with a spine but no features yet — the state
    ``/steer:spec`` drafts a new feature into."""
    repo = tmp_path / "spec-app"
    _seed_spine(repo)
    (repo / "spec" / "features").mkdir()
    _init_commit(repo)
    return repo

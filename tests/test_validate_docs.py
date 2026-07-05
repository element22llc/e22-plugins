"""Tests for scripts/validate_docs.py — docs-site structural + sync checks.

One live-repo test pins the real docs/ tree green; the rest run against small
hermetic fixtures (monkeypatched module paths), covering each check's failure
mode: inventory drift, nav breakage, orphans, broken links, namespace hygiene.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

import validate_docs  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent


def test_real_docs_pass(monkeypatch):
    monkeypatch.chdir(REPO_ROOT)
    errors: list[str] = []
    validate_docs.run_checks(errors)
    assert errors == [], "\n".join(errors)


# --- hermetic fixture ----------------------------------------------------------


@pytest.fixture
def site(tmp_path: Path, monkeypatch):
    """A minimal docs site: two skills, one agent, two pages, a valid nav."""
    docs = tmp_path / "docs"
    (docs / "reference").mkdir(parents=True)
    (docs / "index.md").write_text("# Home\n[skills](reference/skills.md)\n", encoding="utf-8")
    (docs / "reference/skills.md").write_text(
        "# Skills\n\n- /steer:spec\n- /steer:spec-scaffold\n", encoding="utf-8"
    )
    (docs / "reference/agents.md").write_text("# Agents\n\n- `steer-reviewer`\n", encoding="utf-8")
    mkdocs = tmp_path / "mkdocs.yml"
    mkdocs.write_text(
        "nav:\n"
        "  - Home: index.md\n"
        "  - Reference:\n"
        "      - Skills: reference/skills.md\n"
        "      - Agents: reference/agents.md\n",
        encoding="utf-8",
    )
    skills = tmp_path / "plugins/steer/skills"
    for name in ("spec", "spec-scaffold"):
        (skills / name).mkdir(parents=True)
        (skills / name / "SKILL.md").write_text(f"---\nname: {name}\n---\n", encoding="utf-8")
    agents = tmp_path / "plugins/steer/agents"
    agents.mkdir(parents=True)
    (agents / "steer-reviewer.md").write_text("---\nname: steer-reviewer\n---\n", encoding="utf-8")

    monkeypatch.setattr(validate_docs, "DOCS_DIR", docs)
    monkeypatch.setattr(validate_docs, "MKDOCS_YML", mkdocs)
    monkeypatch.setattr(validate_docs, "SKILLS_DIR", skills)
    monkeypatch.setattr(validate_docs, "SKILLS_REF", docs / "reference/skills.md")
    monkeypatch.setattr(validate_docs, "AGENTS_DIR", agents)
    monkeypatch.setattr(validate_docs, "AGENTS_REF", docs / "reference/agents.md")
    return tmp_path


def _run(errors: list[str]) -> None:
    validate_docs.run_checks(errors)


def test_fixture_site_is_clean(site: Path):
    errors: list[str] = []
    _run(errors)
    assert errors == [], "\n".join(errors)


def test_skill_inventory_missing_skill_flagged(site: Path):
    ref = validate_docs.SKILLS_REF
    ref.write_text("# Skills\n\n- /steer:spec-scaffold\n", encoding="utf-8")
    errors: list[str] = []
    validate_docs.check_skill_inventory(errors, validate_docs.skill_names())
    # `spec` must not be satisfied by the `spec-scaffold` prefix match
    assert errors and "['spec']" in errors[0]


def test_agent_inventory_missing_page_flagged(site: Path):
    validate_docs.AGENTS_REF.unlink()
    errors: list[str] = []
    validate_docs.check_agent_inventory(errors, validate_docs.agent_names())
    assert errors and "subagents reference page is required" in errors[0]


def test_agent_inventory_no_agents_is_clean(site: Path):
    errors: list[str] = []
    validate_docs.check_agent_inventory(errors, set())
    assert errors == []


def test_nav_missing_file_and_orphan_flagged(site: Path):
    (site / "mkdocs.yml").write_text(
        "nav:\n  - Home: index.md\n  - Ghost: reference/ghost.md\n", encoding="utf-8"
    )
    errors: list[str] = []
    nav_paths = validate_docs._load_nav_paths(errors)
    validate_docs.check_nav(errors, nav_paths)
    assert any("nav entry 'reference/ghost.md' has no file" in e for e in errors)
    # skills.md / agents.md are on disk but no longer in the nav -> orphans
    assert any("not referenced" in e and "skills.md" in e for e in errors)


def test_invalid_mkdocs_yaml_reported(site: Path):
    (site / "mkdocs.yml").write_text("nav: [unclosed", encoding="utf-8")
    errors: list[str] = []
    assert validate_docs._load_nav_paths(errors) == set()
    assert errors and "invalid YAML" in errors[0]


def test_broken_relative_link_flagged(site: Path):
    (validate_docs.DOCS_DIR / "index.md").write_text(
        "# Home\n[gone](reference/gone.md)\n[ok](reference/skills.md)\n"
        "[external](https://example.com/x.md)\n[anchor](#section)\n",
        encoding="utf-8",
    )
    errors: list[str] = []
    validate_docs.check_links(errors)
    assert len(errors) == 1
    assert "broken link 'reference/gone.md'" in errors[0]


def test_namespace_hygiene_flags_stale_and_unresolved(site: Path):
    (validate_docs.DOCS_DIR / "index.md").write_text(
        "# Home\nUse /steer:spec normally.\nStale /e22-spec ref.\nBad /steer:bogus ref.\n",
        encoding="utf-8",
    )
    errors: list[str] = []
    validate_docs.check_namespace(errors, validate_docs.skill_names())
    assert any("stale '/e22-spec'" in e for e in errors)
    assert any("'/steer:bogus' does not resolve" in e for e in errors)
    assert len(errors) == 2  # the valid /steer:spec reference is untouched

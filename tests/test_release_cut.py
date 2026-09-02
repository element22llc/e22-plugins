"""Tests for the deterministic release cut (``scripts/release_cut.py``).

The cut used to be four hand edits in a skill body, each with a known trap: the
non-unique ``### [Unreleased]`` text, the migration-ledger authoring stub that
must never be stamped, and the Copilot marketplace's second ``version`` key.
These tests pin each trap so the script can never regress into it.
"""

from __future__ import annotations

import json

import pytest
import release_cut as rc

CHANGELOG = """\
# Changelog

## steer

### [Unreleased]

- **Added:** a new skill.
- **Fixed:** an old bug.

### 6.0.0

- **Changed:** the big one.
- house rule: add bullets under `### [Unreleased]`, never recreate the heading.

## other

### 1.0.0

- nope
"""

MIGRATIONS = """\
# Migrations

## Entries

> Newest first.

### [Unreleased] — `foo` → `bar`

- **What & why:** rename.

### v6.0.0 — earlier thing

- **What & why:** earlier.

<!-- Template for a new entry — copy above the most recent one:

### [Unreleased] — <one-line what>

- **What & why:** ...
-->
"""


@pytest.fixture()
def repo(tmp_path, monkeypatch):
    (tmp_path / "plugins/steer/.claude-plugin").mkdir(parents=True)
    (tmp_path / "plugins/steer/.github/plugin").mkdir(parents=True)
    (tmp_path / "plugins/steer/templates/reference").mkdir(parents=True)
    (tmp_path / ".github/plugin").mkdir(parents=True)

    files = {
        "CHANGELOG": tmp_path / "CHANGELOG.md",
        "MIGRATIONS": tmp_path / "plugins/steer/templates/reference/MIGRATIONS.md",
        "PLUGIN_JSON": tmp_path / "plugins/steer/.claude-plugin/plugin.json",
        "COPILOT_PLUGIN_JSON": tmp_path / "plugins/steer/.github/plugin/plugin.json",
        "COPILOT_MARKETPLACE": tmp_path / ".github/plugin/marketplace.json",
    }
    files["CHANGELOG"].write_text(CHANGELOG, encoding="utf-8")
    files["MIGRATIONS"].write_text(MIGRATIONS, encoding="utf-8")
    files["PLUGIN_JSON"].write_text(
        '{\n  "name": "steer",\n  "displayName": "Steer — x",\n  "version": "6.0.0"\n}\n',
        encoding="utf-8",
    )
    files["COPILOT_PLUGIN_JSON"].write_text(
        '{\n  "name": "steer",\n  "version": "6.0.0",\n  "skills": "skills/"\n}\n',
        encoding="utf-8",
    )
    files["COPILOT_MARKETPLACE"].write_text(
        "{\n"
        '  "name": "e22-plugins",\n'
        '  "metadata": {\n    "version": "1.0.0"\n  },\n'
        '  "plugins": [\n    {\n      "name": "steer",\n      "version": "6.0.0"\n    }\n  ]\n'
        "}\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(rc, "REPO_ROOT", tmp_path)
    for attr, path in files.items():
        monkeypatch.setattr(rc, attr, path)
    return tmp_path


def test_cut_renames_heading_and_reseeds_empty_unreleased(repo):
    assert rc.main(["cut", "6.1.0"]) == 0
    text = rc.CHANGELOG.read_text(encoding="utf-8")
    heads = [ln for ln in text.splitlines() if ln.startswith("### ")]
    assert heads[:3] == ["### [Unreleased]", "### 6.1.0", "### 6.0.0"]
    idx, bullets = rc.unreleased_block(text)
    assert bullets == []
    # The prose mention of the heading in the house-rules bullet is untouched.
    assert "under `### [Unreleased]`, never recreate" in text
    assert rc.released_versions(text) == ["6.1.0", "6.0.0"]


def test_cut_renames_ledger_entries_but_never_the_stub(repo):
    assert rc.main(["cut", "6.1.0"]) == 0
    text = rc.MIGRATIONS.read_text(encoding="utf-8")
    assert "### v6.1.0 — `foo` → `bar`" in text
    assert "### v6.0.0 — earlier thing" in text
    # The authoring stub inside the HTML comment keeps its [Unreleased] heading.
    stub = text.split("<!-- Template for a new entry")[1]
    assert "### [Unreleased] — <one-line what>" in stub
    assert "v6.1.0" not in stub


def test_cut_bumps_all_three_manifests_and_leaves_marketplace_metadata_alone(repo):
    assert rc.main(["cut", "6.1.0"]) == 0
    assert json.loads(rc.PLUGIN_JSON.read_text())["version"] == "6.1.0"
    assert json.loads(rc.COPILOT_PLUGIN_JSON.read_text())["version"] == "6.1.0"
    market = json.loads(rc.COPILOT_MARKETPLACE.read_text())
    assert market["plugins"][0]["version"] == "6.1.0"
    assert market["metadata"]["version"] == "1.0.0"
    # Textual edit: formatting (including the em dash) survives byte-for-byte.
    assert '"displayName": "Steer — x"' in rc.PLUGIN_JSON.read_text(encoding="utf-8")


def test_dry_run_writes_nothing_and_prints_a_diff(repo, capsys):
    before = {p: p.read_text() for p in (rc.CHANGELOG, rc.MIGRATIONS, rc.PLUGIN_JSON)}
    assert rc.main(["cut", "6.1.0", "--dry-run"]) == 0
    out = capsys.readouterr().out
    assert "+### 6.1.0" in out and "+### v6.1.0" in out
    for p, text in before.items():
        assert p.read_text() == text


def test_cut_refuses_without_bullets(repo, capsys):
    rc.CHANGELOG.write_text(
        CHANGELOG.replace("- **Added:** a new skill.\n- **Fixed:** an old bug.\n", ""),
        encoding="utf-8",
    )
    assert rc.main(["cut", "6.1.0"]) == 1
    assert "nothing to release" in capsys.readouterr().err


@pytest.mark.parametrize("version", ["6.0.0", "5.9.9", "6.1"])
def test_cut_refuses_non_ascending_or_malformed_version(repo, version, capsys):
    assert rc.main(["cut", version]) == 1
    assert rc.CHANGELOG.read_text() == CHANGELOG  # untouched


def test_cut_refuses_when_manifests_already_disagree(repo, capsys):
    rc.COPILOT_PLUGIN_JSON.write_text('{\n  "version": "5.9.0"\n}\n', encoding="utf-8")
    assert rc.main(["cut", "6.1.0"]) == 1
    assert "disagree" in capsys.readouterr().err


def test_bump_manifest_refuses_an_ambiguous_version_line(repo):
    text = '{\n  "metadata": {\n    "version": "6.0.0"\n  },\n  "version": "6.0.0"\n}\n'
    with pytest.raises(rc.CutError, match="exactly one"):
        rc.bump_manifest(text, rc.COPILOT_MARKETPLACE, "6.0.0", "6.1.0")


def test_no_ledger_entries_is_a_silent_noop(repo):
    rc.MIGRATIONS.write_text(
        MIGRATIONS.replace("### [Unreleased] — `foo` → `bar`\n\n- **What & why:** rename.\n\n", ""),
        encoding="utf-8",
    )
    before = rc.MIGRATIONS.read_text()
    assert rc.main(["cut", "6.1.0"]) == 0
    assert rc.MIGRATIONS.read_text() == before


def test_propose_reads_bump_from_bullet_vocabulary(repo):
    info = rc.propose(rc.CHANGELOG.read_text())
    assert info["suggested"] == "minor"
    assert info["candidates"] == {"major": "7.0.0", "minor": "6.1.0", "patch": "6.0.1"}
    text = CHANGELOG.replace("- **Added:** a new skill.", "- **Removed:** the old skill.")
    assert rc.propose(text)["suggested"] == "major"
    text = CHANGELOG.replace("- **Added:** a new skill.", "- **Fixed:** wording.")
    assert rc.propose(text)["suggested"] == "patch"


def test_validate_cut_flags_a_stamped_stub(repo):
    assert rc.main(["cut", "6.1.0"]) == 0
    text = rc.MIGRATIONS.read_text().replace(
        "### [Unreleased] — <one-line what>", "### v6.1.0 — <one-line what>"
    )
    rc.MIGRATIONS.write_text(text, encoding="utf-8")
    errors = rc.validate_cut("6.1.0")
    assert any("authoring stub was stamped" in e for e in errors)

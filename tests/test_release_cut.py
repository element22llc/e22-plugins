"""Tests for the deterministic release cut (``scripts/release_cut.py``).

``changie`` owns the changelog and the manifest bump, so these run the real
binary against a hermetic fixture repo: the assertions are about what actually
lands on disk, not about a reimplementation of changie's behaviour. What is
pinned here is every trap the cut has to avoid -- the migration-ledger authoring
stub that must never be stamped, the Copilot marketplace's second ``version``
key, and the preconditions changie itself has no opinion on.
"""

from __future__ import annotations

import json
import shutil

import pytest
import release_cut as rc

pytestmark = pytest.mark.skipif(
    shutil.which("changie") is None, reason="changie not on PATH (run via `mise run test`)"
)

CHANGIE_CONFIG = """\
changesDir: .changes
unreleasedDir: unreleased
headerPath: header.tpl.md
changelogPath: CHANGELOG.md
versionExt: md
versionFormat: "## {{.VersionNoPrefix}}"
kindFormat: ""
changeFormat: "{{.Body}}"
newlines:
  afterVersion: 1
  beforeChangelogVersion: 1
  endOfVersion: 1
kinds:
  - label: Added
    auto: minor
  - label: Fixed
    auto: patch
replacements:
  - path: plugins/steer/.claude-plugin/plugin.json
    find: '^  "version": ".*",$'
    replace: '  "version": "{{.VersionNoPrefix}}",'
  - path: plugins/steer/.github/plugin/plugin.json
    find: '^  "version": ".*",$'
    replace: '  "version": "{{.VersionNoPrefix}}",'
  - path: .github/plugin/marketplace.json
    find: '^      "version": ".*",$'
    replace: '      "version": "{{.VersionNoPrefix}}",'
"""

FRAGMENTS = {
    "added-20260101-0000-a-new-skill.yaml": (
        "kind: Added\ntime: 2026-01-01T00:00:00.000000-05:00\n"
        "custom:\n  Slug: a-new-skill\nbody: '- **Added:** a new skill.'\n"
    ),
    "fixed-20260101-0001-an-old-bug.yaml": (
        "kind: Fixed\ntime: 2026-01-01T00:01:00.000000-05:00\n"
        "custom:\n  Slug: an-old-bug\nbody: '- **Fixed:** an old bug.'\n"
    ),
}

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
    (tmp_path / ".changes/unreleased").mkdir(parents=True)

    (tmp_path / ".changie.yaml").write_text(CHANGIE_CONFIG, encoding="utf-8")
    (tmp_path / ".changes/header.tpl.md").write_text("# Changelog\n", encoding="utf-8")
    (tmp_path / ".changes/v6.0.0.md").write_text(
        "## 6.0.0\n\n- **Changed:** the big one.\n", encoding="utf-8"
    )
    for name, text in FRAGMENTS.items():
        (tmp_path / ".changes/unreleased" / name).write_text(text, encoding="utf-8")

    files = {
        "CHANGELOG": tmp_path / "CHANGELOG.md",
        "MIGRATIONS": tmp_path / "plugins/steer/templates/reference/MIGRATIONS.md",
        "PLUGIN_JSON": tmp_path / "plugins/steer/.claude-plugin/plugin.json",
        "COPILOT_PLUGIN_JSON": tmp_path / "plugins/steer/.github/plugin/plugin.json",
        "COPILOT_MARKETPLACE": tmp_path / ".github/plugin/marketplace.json",
        "CHANGES_DIR": tmp_path / ".changes",
        "UNRELEASED_DIR": tmp_path / ".changes/unreleased",
    }
    files["CHANGELOG"].write_text(
        "# Changelog\n\n## 6.0.0\n\n- **Changed:** the big one.\n", encoding="utf-8"
    )
    files["MIGRATIONS"].write_text(MIGRATIONS, encoding="utf-8")
    files["PLUGIN_JSON"].write_text(
        '{\n  "name": "steer",\n  "version": "6.0.0",\n  "displayName": "Steer"\n}\n',
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
        '  "plugins": [\n    {\n      "name": "steer",\n      "version": "6.0.0",\n'
        '      "source": "./plugins/steer"\n    }\n  ]\n'
        "}\n",
        encoding="utf-8",
    )
    monkeypatch.setattr(rc, "REPO_ROOT", tmp_path)
    for attr, path in files.items():
        monkeypatch.setattr(rc, attr, path)
    return tmp_path


def test_cut_batches_fragments_and_empties_unreleased(repo):
    rc.apply_cut("6.1.0")
    version_file = (repo / ".changes/v6.1.0.md").read_text(encoding="utf-8")
    assert version_file.startswith("## 6.1.0")
    assert "- **Added:** a new skill." in version_file
    assert "- **Fixed:** an old bug." in version_file
    assert list((repo / ".changes/unreleased").glob("*.yaml")) == []
    # ...and the assembled changelog carries the new version above the old one.
    changelog = (repo / "CHANGELOG.md").read_text(encoding="utf-8")
    assert changelog.index("## 6.1.0") < changelog.index("## 6.0.0")


def test_cut_bumps_all_three_manifests_and_leaves_marketplace_metadata_alone(repo):
    """release-publish.yml fires on the plugin.json version diff, so the merge
    step is what makes the release publishable at all."""
    rc.apply_cut("6.1.0")
    assert json.loads(rc.PLUGIN_JSON.read_text())["version"] == "6.1.0"
    assert json.loads(rc.COPILOT_PLUGIN_JSON.read_text())["version"] == "6.1.0"
    marketplace = json.loads(rc.COPILOT_MARKETPLACE.read_text())
    assert marketplace["plugins"][0]["version"] == "6.1.0"
    assert marketplace["metadata"]["version"] == "1.0.0"
    assert rc.validate_cut("6.1.0") == []


def test_cut_renames_ledger_entries_but_never_the_stub(repo):
    rc.apply_cut("6.1.0")
    text = rc.MIGRATIONS.read_text(encoding="utf-8")
    assert "### v6.1.0 — `foo` → `bar`" in text
    # the authoring stub keeps its placeholder heading
    assert text.count("### [Unreleased] — <one-line what>") == 1
    assert "### v6.1.0 — <one-line what>" not in text


def test_dry_run_writes_nothing_and_prints_the_plan(repo, capsys):
    before = {p: p.read_text(encoding="utf-8") for p in repo.rglob("*") if p.is_file()}
    out = rc.preview_cut("6.1.0")
    assert "- **Added:** a new skill." in out
    assert "6.0.0 -> 6.1.0" in out
    assert "metadata.version is left alone" in out
    assert "### v6.1.0 — `foo` → `bar`" in out  # the migrations diff
    after = {p: p.read_text(encoding="utf-8") for p in repo.rglob("*") if p.is_file()}
    assert before == after


def test_cut_refuses_with_no_pending_fragments(repo):
    for frag in (repo / ".changes/unreleased").glob("*.yaml"):
        frag.unlink()
    with pytest.raises(rc.CutError, match="empty"):
        rc.apply_cut("6.1.0")


@pytest.mark.parametrize("version", ["6.0.0", "5.9.0", "not-a-version"])
def test_cut_refuses_non_ascending_or_malformed_version(repo, version):
    with pytest.raises(rc.CutError):
        rc.apply_cut(version)


def test_cut_refuses_when_manifests_already_disagree(repo):
    rc.COPILOT_PLUGIN_JSON.write_text(
        '{\n  "name": "steer",\n  "version": "5.0.0",\n  "skills": "skills/"\n}\n', encoding="utf-8"
    )
    with pytest.raises(rc.CutError, match="disagree"):
        rc.apply_cut("6.1.0")


def test_cut_refuses_to_overwrite_an_existing_version_file(repo):
    (repo / ".changes/v6.1.0.md").write_text("## 6.1.0\n\n- already cut\n", encoding="utf-8")
    with pytest.raises(rc.CutError, match="already exists"):
        rc.apply_cut("6.1.0")


def test_no_ledger_entries_is_a_silent_noop(repo):
    rc.MIGRATIONS.write_text(
        "# Migrations\n\n## Entries\n\n> Newest first.\n\n### v6.0.0 — earlier\n", encoding="utf-8"
    )
    rc.apply_cut("6.1.0")
    assert rc.validate_cut("6.1.0") == []


def test_propose_reads_the_bump_from_fragment_kinds(repo):
    """An `Added` fragment maps to `auto: minor` -- declared data, not a guess
    at what a bullet's wording implied."""
    info = rc.propose()
    assert info["current"] == "6.0.0"
    assert info["suggested"] == "6.1.0"
    assert info["candidates"] == {"major": "7.0.0", "minor": "6.1.0", "patch": "6.0.1"}
    assert [(k, s) for k, s, _ in info["fragments"]] == [
        ("Added", "a-new-skill"),
        ("Fixed", "an-old-bug"),
    ]


def test_propose_refuses_when_nothing_is_pending(repo):
    for frag in (repo / ".changes/unreleased").glob("*.yaml"):
        frag.unlink()
    with pytest.raises(rc.CutError, match="empty"):
        rc.propose()


def test_validate_cut_flags_a_stamped_stub(repo):
    rc.apply_cut("6.1.0")
    text = rc.MIGRATIONS.read_text(encoding="utf-8")
    rc.MIGRATIONS.write_text(
        text.replace("### [Unreleased] — <one-line what>", "### v6.1.0 — <one-line what>"),
        encoding="utf-8",
    )
    assert any("authoring stub" in e for e in rc.validate_cut("6.1.0"))


def test_validate_cut_flags_a_bumped_marketplace_metadata_version(repo):
    rc.apply_cut("6.1.0")
    text = rc.COPILOT_MARKETPLACE.read_text(encoding="utf-8")
    rc.COPILOT_MARKETPLACE.write_text(
        text.replace('"version": "1.0.0"', '"version": "6.1.0"'), encoding="utf-8"
    )
    assert any("metadata.version was bumped" in e for e in rc.validate_cut("6.1.0"))


def test_release_notes_strips_the_version_heading(repo):
    rc.apply_cut("6.1.0")
    notes = rc.release_notes("6.1.0")
    assert not notes.startswith("##")
    assert notes.startswith("- **Added:** a new skill.")


def test_release_notes_reflows_the_entries(repo):
    """The PR body renders in the same comment mode as a Release body.

    Entries are authored wrapped at 80 columns, and every newline there becomes a
    `<br>` -- so `pr-body` has to hand over one line per block, exactly as the
    publish workflow does.
    """
    (repo / ".changes/v6.1.0.md").write_text(
        "## 6.1.0\n\n- **Added:** a skill whose description\n  wrapped onto a second line.\n",
        encoding="utf-8",
    )
    assert rc.release_notes("6.1.0") == (
        "- **Added:** a skill whose description wrapped onto a second line."
    )


def test_pr_body_carries_the_reflowed_entries(repo):
    (repo / ".changes/v6.1.0.md").write_text(
        "## 6.1.0\n\n- **Fixed:** a bug whose explanation\n  needed two lines.\n",
        encoding="utf-8",
    )
    body = rc.pr_body("6.1.0", "release", None)
    assert "- **Fixed:** a bug whose explanation needed two lines." in body

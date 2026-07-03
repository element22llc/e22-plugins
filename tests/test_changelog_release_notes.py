"""Tests for the CHANGELOG release-notes extractor.

The extractor feeds ``release-publish.yml`` (notes body for the just-merged
version). The invariants that matter: it agrees with the real changelog, the
newest released heading tracks ``plugin.json``, and a missing/empty version is a
loud error rather than an empty Release.
"""

from __future__ import annotations

import changelog_release_notes as crn
import pytest
from conftest import REPO_ROOT

SAMPLE = """\
Preamble line that is not part of any section.

## steer

### [Unreleased]

- something not yet released

### 2.1.0

- **Added:** the new thing.
- **Fixed:** the old thing.

### 2.0.0

- **Changed:** the big rename.

## some-other-plugin

### 9.9.9

- should never be seen — different plugin section
"""


@pytest.fixture()
def sample_changelog(tmp_path, monkeypatch):
    path = tmp_path / "CHANGELOG.md"
    path.write_text(SAMPLE, encoding="utf-8")
    monkeypatch.setattr(crn, "CHANGELOG", path)
    return path


def test_released_versions_skips_unreleased_and_other_sections(sample_changelog):
    assert crn.released_versions() == ["2.1.0", "2.0.0"]


def test_notes_are_the_bullets_between_headings(sample_changelog):
    notes = crn.release_notes("2.1.0")
    assert notes == "- **Added:** the new thing.\n- **Fixed:** the old thing."
    # No leading/trailing blank lines, and it stops at the next `### ` heading.
    assert "big rename" not in notes


def test_last_released_notes_stop_at_section_boundary(sample_changelog):
    notes = crn.release_notes("2.0.0")
    assert notes == "- **Changed:** the big rename."
    assert "9.9.9" not in notes  # the other-plugin section must not bleed in


def test_missing_version_raises_keyerror(sample_changelog):
    with pytest.raises(KeyError):
        crn.release_notes("5.5.5")


def test_non_semver_version_rejected(sample_changelog):
    with pytest.raises(ValueError):
        crn.release_notes("[Unreleased]")


# --- Invariants against the real, committed changelog -----------------------


def test_current_version_matches_newest_released_heading():
    """The release invariant: plugin.json version == newest released heading."""
    assert crn.released_versions()[0] == crn.current_version()


def test_every_released_version_has_nonempty_notes():
    for version in crn.released_versions():
        assert crn.release_notes(version).strip(), f"empty notes for {version}"


def test_current_version_notes_exist():
    notes = crn.release_notes(crn.current_version())
    assert notes.strip()


def test_repo_root_points_at_this_repo():
    assert (REPO_ROOT / "plugins/steer/.claude-plugin/plugin.json").is_file()

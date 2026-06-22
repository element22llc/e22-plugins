"""Unit tests for gitutil — pure git, no skill runs (default token-free suite)."""

from __future__ import annotations

import subprocess

import pytest

from . import gitutil


def _repo(tmp_path):
    r = tmp_path / "r"
    r.mkdir()
    for args in (["init", "-q"], ["config", "user.email", "t@e.com"], ["config", "user.name", "t"]):
        subprocess.run(["git", *args], cwd=r, check=True, capture_output=True)
    (r / "seed.txt").write_text("x", encoding="utf-8")
    subprocess.run(["git", "add", "-A"], cwd=r, check=True, capture_output=True)
    subprocess.run(["git", "commit", "-q", "-m", "seed"], cwd=r, check=True, capture_output=True)
    return r


def test_changed_paths_lists_untracked_and_modified(tmp_path):
    r = _repo(tmp_path)
    (r / "spec").mkdir()
    (r / "spec" / "a.md").write_text("y", encoding="utf-8")
    (r / "seed.txt").write_text("changed", encoding="utf-8")
    paths = gitutil.changed_paths(r)
    assert any(p.startswith("spec/") for p in paths)
    assert "seed.txt" in paths


def test_assert_changes_confined_to_passes_when_confined(tmp_path):
    r = _repo(tmp_path)
    (r / "spec").mkdir()
    (r / "spec" / "a.md").write_text("y", encoding="utf-8")
    gitutil.assert_changes_confined_to(r, "spec/")  # must not raise


def test_assert_changes_confined_to_flags_stray(tmp_path):
    r = _repo(tmp_path)
    (r / "spec").mkdir()
    (r / "spec" / "a.md").write_text("y", encoding="utf-8")
    (r / "stray.py").write_text("z", encoding="utf-8")
    with pytest.raises(AssertionError, match="escaped"):
        gitutil.assert_changes_confined_to(r, "spec/")

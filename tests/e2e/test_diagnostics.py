"""Unit tests for the failure-diagnostics helper — pure, no skill runs.

Deliberately unmarked (not @pytest.mark.e2e), so it runs in the default suite
and gives the debuggability tooling real coverage at zero token cost.
"""

from __future__ import annotations

import pytest

from .diagnostics import _tree, explain_on_failure


def test_tree_lists_files_and_skips_git(tmp_path):
    (tmp_path / "a.txt").write_text("x", encoding="utf-8")
    (tmp_path / "sub").mkdir()
    (tmp_path / "sub" / "b.txt").write_text("y", encoding="utf-8")
    (tmp_path / ".git").mkdir()
    (tmp_path / ".git" / "HEAD").write_text("ref", encoding="utf-8")

    out = _tree(tmp_path)
    assert "a.txt" in out
    assert "sub/b.txt" in out
    assert ".git" not in out  # internals excluded


def test_explain_on_failure_reraises_and_dumps(tmp_path, capsys):
    (tmp_path / "produced.txt").write_text("hi", encoding="utf-8")
    with pytest.raises(AssertionError, match="boom"), explain_on_failure(tmp_path):
        raise AssertionError("boom")

    printed = capsys.readouterr().out
    assert str(tmp_path) in printed  # repo path surfaced
    assert "produced.txt" in printed  # produced tree surfaced


def test_explain_on_failure_is_transparent_on_success(tmp_path):
    ran = False
    with explain_on_failure(tmp_path):
        ran = True
    assert ran

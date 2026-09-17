"""Tests for the release-notes reflow (``scripts/reflow_release_notes.py``).

Two invariants carry the weight, and both run over the *real* archived corpus so
a re-published old version is covered as well as the next cut:

- **No corruption.** The whitespace-split token sequence of a version file
  (minus its heading) survives the reflow byte-for-byte. This is what makes the
  transform safe to apply to 113 files nobody is going to re-read.
- **No ``<br>``.** No two non-blank output lines are adjacent unless the second
  one starts a block. Adjacency is precisely what GitHub's comment-mode renderer
  turns into a ``<br>``, so this is the defect itself, pinned.
"""

from __future__ import annotations

from pathlib import Path

import pytest
import reflow_release_notes as rr

REPO_ROOT = Path(__file__).resolve().parents[1]
CHANGES = REPO_ROOT / ".changes"
VERSION_FILES = sorted(CHANGES.glob("v*.md"))


def _adjacent_violations(text: str) -> list[tuple[str, str]]:
    """Pairs of adjacent non-blank lines that would render as a ``<br>`` join."""
    lines = text.splitlines()
    tables = rr._table_lines(lines)
    violations: list[tuple[str, str]] = []
    in_fence = False
    for index, line in enumerate(lines):
        if rr._FENCE.match(line):
            in_fence = not in_fence
            continue
        if in_fence or index in tables or index == 0:
            continue
        previous = lines[index - 1]
        if not line.strip() or not previous.strip():
            continue
        if index - 1 in tables:
            continue
        if not rr._starts_block(line):
            violations.append((previous, line))
    return violations


def test_the_corpus_is_not_empty():
    assert len(VERSION_FILES) > 100, "expected the archived changelog corpus"


@pytest.mark.parametrize("path", VERSION_FILES, ids=lambda p: p.name)
def test_reflow_preserves_every_token(path):
    source = rr.strip_version_heading(path.read_text(encoding="utf-8"))
    assert rr.reflow(source).split() == source.split()


@pytest.mark.parametrize("path", VERSION_FILES, ids=lambda p: p.name)
def test_reflow_leaves_no_soft_wrap_to_render_as_a_break(path):
    body = rr.release_body(path.read_text(encoding="utf-8"))
    assert _adjacent_violations(body) == []


@pytest.mark.parametrize("path", VERSION_FILES, ids=lambda p: p.name)
def test_reflow_is_idempotent(path):
    once = rr.release_body(path.read_text(encoding="utf-8"))
    assert rr.release_body(once) == once


def test_the_corpus_needed_the_fix():
    """Guards the guard: if the source ever stops being wrapped, say so."""
    wrapped = [p for p in VERSION_FILES if _adjacent_violations(p.read_text(encoding="utf-8"))]
    assert wrapped, "no version file is soft-wrapped -- is this script still needed?"


def test_strips_the_version_heading_and_its_blank_line():
    source = "## 6.3.0\n\n- **Added: a thing.**\n"
    assert rr.strip_version_heading(source) == "- **Added: a thing.**"


def test_keeps_a_body_that_has_no_heading():
    assert rr.strip_version_heading("- **Added: a thing.**\n") == "- **Added: a thing.**"


def test_joins_a_bullet_whose_bold_lead_in_spans_lines():
    """The v6.3.0 shape: the ``**...**`` run is split across the 80-column wrap."""
    source = (
        "## 6.3.0\n"
        "\n"
        "- **Fixed: `/steer:init` no longer clobbers a repo's own hook, and a\n"
        "  legacy template fork now gets a commit gate at all.** 6.2.0 wired the\n"
        "  gate from both setup skills.\n"
    )
    assert rr.release_body(source) == (
        "- **Fixed: `/steer:init` no longer clobbers a repo's own hook, and a legacy "
        "template fork now gets a commit gate at all.** 6.2.0 wired the gate from "
        "both setup skills.\n"
    )


def test_keeps_nested_bullets_on_their_own_lines():
    source = (
        "- **Added: a thing.** It does what\n"
        "  it says.\n"
        "  - Covers `PRODUCTION-READINESS.md`, and\n"
        "    every feature file.\n"
        "  - POSIX sh, no jq.\n"
    )
    assert rr.reflow(source) == (
        "- **Added: a thing.** It does what it says.\n"
        "  - Covers `PRODUCTION-READINESS.md`, and every feature file.\n"
        "  - POSIX sh, no jq."
    )


def test_keeps_separate_entries_separate():
    source = "- **Added: one.**\n\n- **Fixed: two.**\n"
    assert rr.reflow(source) == "- **Added: one.**\n\n- **Fixed: two.**"


def test_joins_a_continuation_that_merely_starts_with_a_pipe():
    """v3.6.0: an inline GraphQL union wraps onto a line beginning with ``|``."""
    source = (
        "- The live mutation nests them in a list (`{ fieldId,\n"
        "  singleSelectOptionId | dateValue\n"
        "  | delete }`), with the value passed as an option **id**.\n"
    )
    assert rr.reflow(source) == (
        "- The live mutation nests them in a list (`{ fieldId, singleSelectOptionId "
        "| dateValue | delete }`), with the value passed as an option **id**."
    )


def test_joins_a_continuation_that_opens_with_a_parenthetical_number():
    """v6.1.0: ``(... check`` wraps onto ``11) covered ...``, which is not a list.

    The adjacency sweep cannot see this one -- ``11)`` *looks* like a valid block
    starter -- and the damage is worse than a stray break: indented two spaces
    under a bullet, the renderer makes it a nested ordered list and the sentence
    never closes. CommonMark is the arbiter: only a marker starting at ``1`` may
    interrupt a running paragraph.
    """
    source = (
        "- **Fixed: a thing.** The debranding gate (`check_standards.py` check\n"
        "  11) covered `templates/{scaffold,spec}` but not `templates/agents`.\n"
    )
    assert rr.reflow(source) == (
        "- **Fixed: a thing.** The debranding gate (`check_standards.py` check 11) "
        "covered `templates/{scaffold,spec}` but not `templates/agents`."
    )


def test_advances_a_genuine_ordered_list():
    source = "1. First step, which wraps\n   onto a second line.\n2. Second step.\n"
    assert rr.reflow(source) == "1. First step, which wraps onto a second line.\n2. Second step."


@pytest.mark.parametrize("path", VERSION_FILES, ids=lambda p: p.name)
def test_no_reflowed_line_opens_with_a_stray_ordered_marker(path):
    """No archived entry uses an ordered list, so any such line is a false positive.

    If a future entry ships a real numbered list, this assertion is the thing to
    relax -- deliberately, having checked it renders as intended.
    """
    body = rr.release_body(path.read_text(encoding="utf-8"))
    assert [line for line in body.splitlines() if rr._ORDERED.match(line)] == []


def test_passes_a_real_table_through_verbatim():
    source = "| Gate | When |\n| --- | --- |\n| `ci` | PR |\n| `pre-commit` | commit |\n"
    assert rr.reflow(source) == source.rstrip("\n")


def test_keeps_a_link_reference_definition_on_its_own_line():
    source = (
        "Upstream has not fixed this yet, tracked as\n"
        "[anthropics/claude-code#40495].\n"
        "[anthropics/claude-code#40495]: https://github.com/anthropics/claude-code/issues/40495\n"
    )
    assert rr.reflow(source) == (
        "Upstream has not fixed this yet, tracked as [anthropics/claude-code#40495].\n"
        "[anthropics/claude-code#40495]: https://github.com/anthropics/claude-code/issues/40495"
    )


def test_passes_fenced_code_through_verbatim():
    source = "- **Added: a task.**\n\n```sh\nmise run ci\n  indented\n```\n"
    assert rr.reflow(source) == "- **Added: a task.**\n\n```sh\nmise run ci\n  indented\n```"


def test_joins_a_wrapped_column_zero_paragraph():
    source = "Workflow + authorization coherence - one git-authorization model\nand one owner.\n"
    assert rr.reflow(source) == (
        "Workflow + authorization coherence - one git-authorization model and one owner."
    )


def test_cli_writes_the_reflowed_body(tmp_path, capsys):
    path = tmp_path / "v9.9.9.md"
    path.write_text("## 9.9.9\n\n- **Added: a thing\n  that wrapped.**\n", encoding="utf-8")
    assert rr.main([str(path)]) == 0
    assert capsys.readouterr().out == "- **Added: a thing that wrapped.**\n"


def test_cli_reports_a_missing_file(tmp_path, capsys):
    assert rr.main([str(tmp_path / "nope.md")]) == 1
    assert "::error::" in capsys.readouterr().err

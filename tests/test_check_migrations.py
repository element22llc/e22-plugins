"""Tests for scripts/check_migrations.py — the migration-ledger integrity gate.

Every check gets a **positive control**: a fixture that trips it. A gate that has
only ever been seen green is not known to check anything — the previous
incarnation of this script reported ``deep-checked 0 entries`` on a clean tree for
weeks, because its deep tier selected entries by a rule the authoring convention
had since inverted.

The real ledger is also asserted valid, so a genuine defect landing in
`MIGRATIONS.md` fails here rather than in a consumer's `/steer:sync`.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))

import check_migrations  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parent.parent


# --- fixtures ---------------------------------------------------------------

HEAD = """\
# Spec-spine migration ledger

## How a migration is applied

Prose that mentions `### [Unreleased]` inline must not parse as an entry.

## Entries

"""

GOOD_ENTRY = """\
### [Unreleased] — a real pending change

- **What & why:** the thing moved, and a repo must follow it.
- **Precondition:** `spec/OLD.md` exists.
- **Action:** `git mv spec/OLD.md spec/NEW.md`.

"""

RELEASED_ENTRY = """\
### v3.12.0 — an older shipped change

- **What & why:** history.
- **Precondition:** `spec/ANCIENT.md` exists.
- **Action:** delete it.

"""

TEMPLATE_COMMENT = """\
<!-- Template for a new entry — copy above the most recent one:

### [Unreleased] — <one-line what>

- **What & why:** <the structural change and the reason a repo must follow it>
- **Precondition:** <a check that is true only while the migration is pending>
- **Action:** <the concrete transform>

-->
"""


def _ledger(monkeypatch, tmp_path: Path, body: str):
    """Point the module at a throwaway ledger + changelog."""
    path = tmp_path / "MIGRATIONS.md"
    path.write_text(body, encoding="utf-8")
    monkeypatch.setattr(check_migrations, "LEDGER", path)

    monkeypatch.setattr(check_migrations, "PLUGIN_ROOT", tmp_path)
    return path


def _run() -> int:
    return check_migrations.main([])


# --- the real ledger --------------------------------------------------------


def test_the_shipped_ledger_is_valid(monkeypatch):
    """The ledger in this repo passes every check."""
    monkeypatch.chdir(REPO_ROOT)
    assert _run() == 0


def test_the_shipped_ledger_has_entries(monkeypatch):
    """Guards against a parser that silently matches nothing and reports OK."""
    monkeypatch.chdir(REPO_ROOT)
    text = check_migrations.LEDGER.read_text(encoding="utf-8")
    entries = check_migrations.parse_entries(text)
    assert len(entries) > 10
    assert all(e.is_unreleased or e.version for e in entries)


# --- happy path -------------------------------------------------------------


def test_good_ledger_passes(monkeypatch, tmp_path):
    _ledger(monkeypatch, tmp_path, HEAD + GOOD_ENTRY + RELEASED_ENTRY)
    assert _run() == 0


def test_template_comment_is_not_an_entry(monkeypatch, tmp_path):
    """The authoring template carries `<one-line what>` and must be invisible."""
    path = _ledger(monkeypatch, tmp_path, HEAD + GOOD_ENTRY + RELEASED_ENTRY + TEMPLATE_COMMENT)
    entries = check_migrations.parse_entries(path.read_text(encoding="utf-8"))
    assert [e.key for e in entries] == ["[Unreleased]", "v3.12.0"]
    assert _run() == 0


def test_prose_mention_above_entries_is_ignored(monkeypatch, tmp_path):
    """Only `### ` headings below `## Entries` count."""
    path = _ledger(monkeypatch, tmp_path, HEAD + RELEASED_ENTRY)
    entries = check_migrations.parse_entries(path.read_text(encoding="utf-8"))
    assert [e.key for e in entries] == ["v3.12.0"]


# --- structural positive controls -------------------------------------------


def test_missing_action_field_fails(monkeypatch, tmp_path, capsys):
    entry = "### [Unreleased] — no action\n\n- **What & why:** x.\n- **Precondition:** y.\n\n"
    _ledger(monkeypatch, tmp_path, HEAD + entry)
    assert _run() == 1
    assert "**Action:** field" in capsys.readouterr().err


def test_missing_precondition_field_fails(monkeypatch, tmp_path, capsys):
    entry = "### [Unreleased] — no precondition\n\n- **What & why:** x.\n- **Action:** y.\n\n"
    _ledger(monkeypatch, tmp_path, HEAD + entry)
    assert _run() == 1
    assert "**Precondition:** field" in capsys.readouterr().err


def test_qualified_action_field_is_accepted(monkeypatch, tmp_path):
    """`- **Action — an in-file token rewrite**,` is still the Action field."""
    entry = (
        "### [Unreleased] — qualified action\n\n"
        "- **What & why:** x.\n"
        "- **Precondition:** y.\n"
        "- **Action — an in-file token rewrite**, one pair: `a` -> `b`.\n\n"
    )
    _ledger(monkeypatch, tmp_path, HEAD + entry)
    assert _run() == 0


def test_bad_heading_key_fails(monkeypatch, tmp_path, capsys):
    entry = (
        "### 3.12.0 — bare version, no v prefix\n\n"
        "- **What & why:** x.\n- **Precondition:** y.\n- **Action:** z.\n\n"
    )
    _ledger(monkeypatch, tmp_path, HEAD + entry)
    assert _run() == 1
    assert "neither" in capsys.readouterr().err


def test_heading_without_summary_fails(monkeypatch, tmp_path, capsys):
    entry = "### [Unreleased]\n\n- **What & why:** x.\n- **Precondition:** y.\n- **Action:** z.\n\n"
    _ledger(monkeypatch, tmp_path, HEAD + entry)
    assert _run() == 1
    assert "no `— <what>` summary" in capsys.readouterr().err


# --- ordering ---------------------------------------------------------------


def test_versioned_entries_out_of_order_fail(monkeypatch, tmp_path, capsys):
    older = RELEASED_ENTRY.replace("v3.12.0", "v3.1.0")
    _ledger(monkeypatch, tmp_path, HEAD + older + RELEASED_ENTRY)
    assert _run() == 1
    assert "newest-first" in capsys.readouterr().err


def test_repeated_version_is_allowed(monkeypatch, tmp_path):
    """Several entries may share one release — non-increasing, not strict."""
    _ledger(monkeypatch, tmp_path, HEAD + RELEASED_ENTRY + RELEASED_ENTRY)
    assert _run() == 0


def test_unreleased_below_versioned_fails(monkeypatch, tmp_path, capsys):
    _ledger(monkeypatch, tmp_path, HEAD + RELEASED_ENTRY + GOOD_ENTRY)
    assert _run() == 1
    assert "belong at the top" in capsys.readouterr().err


# --- the guessed-version guard lives elsewhere -------------------------------


def test_version_ahead_of_release_is_not_this_gates_job(monkeypatch, tmp_path):
    """`check_plugin.py::check_migration_versions` owns that invariant.

    Asserting it here too would mean two gates checking one rule against
    different sources of truth (plugin.json vs CHANGELOG.md), which is how they
    drift into disagreeing. This test pins the boundary so nobody re-adds it.
    """
    ahead = RELEASED_ENTRY.replace("v3.12.0", "v9.9.9")
    _ledger(monkeypatch, tmp_path, HEAD + ahead)
    assert _run() == 0


# --- deep tier, [Unreleased] entries only -----------------------------------


def test_placeholder_left_in_unreleased_entry_fails(monkeypatch, tmp_path, capsys):
    entry = (
        "### [Unreleased] — half-written\n\n"
        "- **What & why:** <the structural change and the reason>\n"
        "- **Precondition:** y.\n"
        "- **Action:** z.\n\n"
    )
    _ledger(monkeypatch, tmp_path, HEAD + entry)
    assert _run() == 1
    assert "template placeholder" in capsys.readouterr().err


def test_angle_token_without_a_space_is_not_a_placeholder(monkeypatch, tmp_path):
    """`steer-<skill>.prompt.md` is a path pattern, not an unfilled field."""
    entry = (
        "### [Unreleased] — path patterns are fine\n\n"
        "- **What & why:** `.github/prompts/steer-<skill>.prompt.md` is retired.\n"
        "- **Precondition:** that path exists.\n"
        "- **Action:** delete it.\n\n"
    )
    _ledger(monkeypatch, tmp_path, HEAD + entry)
    assert _run() == 0


def test_missing_cited_template_path_fails(monkeypatch, tmp_path, capsys):
    entry = (
        "### [Unreleased] — cites a ghost\n\n"
        "- **What & why:** x.\n"
        "- **Precondition:** y.\n"
        "- **Action:** reconcile against `templates/spec/nope.md`.\n\n"
    )
    _ledger(monkeypatch, tmp_path, HEAD + entry)
    assert _run() == 1
    assert "does not exist" in capsys.readouterr().err


def test_present_cited_template_path_passes(monkeypatch, tmp_path):
    target = tmp_path / "templates" / "spec"
    target.mkdir(parents=True)
    (target / "real.md").write_text("# Real\n", encoding="utf-8")
    entry = (
        "### [Unreleased] — cites a real file\n\n"
        "- **What & why:** x.\n"
        "- **Precondition:** y.\n"
        "- **Action:** reconcile against `templates/spec/real.md`.\n\n"
    )
    _ledger(monkeypatch, tmp_path, HEAD + entry)
    assert _run() == 0


def test_unlocatable_cited_section_fails(monkeypatch, tmp_path, capsys):
    target = tmp_path / "templates" / "spec"
    target.mkdir(parents=True)
    (target / "real.md").write_text("# Real\n\n## Actual\n", encoding="utf-8")
    entry = (
        "### [Unreleased] — points at a missing heading\n\n"
        "- **What & why:** x.\n"
        "- **Precondition:** y.\n"
        "- **Action:** copy `## Traceability` from `templates/spec/real.md`.\n\n"
    )
    _ledger(monkeypatch, tmp_path, HEAD + entry)
    assert _run() == 1
    err = capsys.readouterr().err
    assert "has no such heading" in err
    assert "'## Actual'" in err  # names what IS there, so the fix is obvious


def test_locatable_cited_section_passes(monkeypatch, tmp_path):
    target = tmp_path / "templates" / "spec"
    target.mkdir(parents=True)
    (target / "real.md").write_text("# Real\n\n## Traceability\n", encoding="utf-8")
    entry = (
        "### [Unreleased] — points at a real heading\n\n"
        "- **What & why:** x.\n"
        "- **Precondition:** y.\n"
        "- **Action:** copy `## Traceability` from `templates/spec/real.md`.\n\n"
    )
    _ledger(monkeypatch, tmp_path, HEAD + entry)
    assert _run() == 0


def test_released_entries_are_not_deep_checked(monkeypatch, tmp_path):
    """A shipped entry citing a since-deleted template must not block a release."""
    entry = RELEASED_ENTRY.replace(
        "- **Action:** delete it.",
        "- **Action:** reconcile against `templates/spec/long-gone.md`.",
    )
    _ledger(monkeypatch, tmp_path, HEAD + entry)
    assert _run() == 0


# --- comment / fence handling (the parser regressions) ----------------------


def test_inline_comment_does_not_hide_the_rest_of_its_line():
    """`a marker (`<!-- steer:profile=app -->`)` must not blank the whole line."""
    line = "- **What & why:** a marker (`<!-- steer:profile=app -->`) is added."
    assert "**What & why:**" in check_migrations.blank_comments(line)


def test_unclosed_comment_inside_a_fence_is_inert(monkeypatch, tmp_path):
    """A grep for the marker contains a bare `<!--` and must not open a comment.

    This is the real v3.1.0 shape: the precondition fences a grep whose pattern
    contains an unclosed `<!--`, and the `- **Action:**` bullet follows it.
    """
    entry = (
        "### [Unreleased] — profile marker back-fill\n\n"
        "- **What & why:** repos carry a profile marker.\n"
        "- **Precondition:**\n\n"
        "  ```sh\n"
        "  grep -qiE '<!--[[:space:]]*steer:profile=' CLAUDE.md\n"
        "  ```\n\n"
        "- **Action:** add `<!-- steer:profile=app -->` to `CLAUDE.md`.\n\n"
    )
    _ledger(monkeypatch, tmp_path, HEAD + entry)
    assert _run() == 0


def test_multiline_comment_is_still_stripped():
    text = "keep\n<!-- one\ntwo\nthree -->\nalso keep"
    out = check_migrations.blank_comments(text)
    assert "two" not in out
    assert out.splitlines()[0] == "keep"
    assert out.splitlines()[-1] == "also keep"
    assert len(out.splitlines()) == len(text.splitlines())  # numbering preserved


# --- failure modes ----------------------------------------------------------


def test_missing_ledger_fails(monkeypatch, tmp_path, capsys):
    monkeypatch.setattr(check_migrations, "LEDGER", tmp_path / "nope.md")
    assert _run() == 1
    assert "not found" in capsys.readouterr().err


def test_ledger_without_entries_section_fails(monkeypatch, tmp_path, capsys):
    _ledger(monkeypatch, tmp_path, "# Ledger\n\nNo entries heading here.\n")
    assert _run() == 1
    assert "no '## Entries' section" in capsys.readouterr().err


@pytest.mark.parametrize(
    "key,expected",
    [("v1.2.3", (1, 2, 3)), ("[Unreleased]", None), ("v10.0.1", (10, 0, 1))],
)
def test_version_parsing(key, expected):
    e = check_migrations.Entry(key=key, what="x", body="", line_no=1)
    assert e.version == expected

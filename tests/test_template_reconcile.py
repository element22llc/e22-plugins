"""Tests for plugins/steer/scripts/template-reconcile.sh.

The helper is the read-only structural diff behind the *Template reconciliation*
convention: it prints the `##`/`###` headings and `- [ ]` checklist items that a
bundled template has and the consumer's existing file lacks.

The contract under test is mostly about what it must NOT report. Its output is a
*splice candidate list* a caller acts on, so a false "missing" is not a cosmetic
wart -- it produces duplicate sections in a file that was already current, in the
step whose whole contract is "additive, never clobber". The normalizations that
suppress false positives (checkbox state, ordering, placeholder seed lines and --
regression-guarding #438 -- line endings) are therefore each pinned here, paired
with a check that a genuine gap is still reported so a normalization can never be
widened into "reports nothing".

#438: a CRLF bundled template gave every anchor an invisible trailing CR, so no
anchor could match the consumer's LF file and the template's ENTIRE anchor set
came back as missing -- while still exiting 0, which is what made it dangerous.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

from conftest import REPO_ROOT

_SCRIPT = REPO_ROOT / "plugins" / "steer" / "scripts" / "template-reconcile.sh"


def _run(existing: Path, bundled: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["sh", str(_SCRIPT), str(existing), str(bundled)],
        capture_output=True,
        text=True,
        check=False,
    )


def _write(path: Path, text: str, *, crlf: bool = False) -> Path:
    """Write with explicit line endings; newline='' keeps Python from translating."""
    path.write_text(text.replace("\n", "\r\n") if crlf else text, encoding="utf-8", newline="")
    return path


# --- line endings (#438) --------------------------------------------------


def test_crlf_bundled_template_reports_no_phantom_gaps(tmp_path: Path):
    """The reported bug: LF consumer vs CRLF bundled template must be 'current'."""
    existing = _write(tmp_path / "existing.md", "## Alpha\n## Beta\n- [ ] one\n")
    bundled = _write(tmp_path / "bundled.md", "## Alpha\n## Beta\n- [ ] one\n", crlf=True)

    result = _run(existing, bundled)

    assert result.returncode == 0
    assert result.stdout == "", f"phantom gaps reported: {result.stdout!r}"


def test_crlf_existing_file_reports_no_phantom_gaps(tmp_path: Path):
    """The consumer's line endings are not ours to control -- normalize both sides."""
    existing = _write(tmp_path / "existing.md", "## Alpha\n## Beta\n", crlf=True)
    bundled = _write(tmp_path / "bundled.md", "## Alpha\n## Beta\n")

    result = _run(existing, bundled)

    assert result.returncode == 0
    assert result.stdout == ""


def test_crlf_on_both_sides_reports_no_phantom_gaps(tmp_path: Path):
    existing = _write(tmp_path / "existing.md", "## Alpha\n- [ ] one\n", crlf=True)
    bundled = _write(tmp_path / "bundled.md", "## Alpha\n- [ ] one\n", crlf=True)

    result = _run(existing, bundled)

    assert result.returncode == 0
    assert result.stdout == ""


def test_crlf_template_still_reports_a_genuine_gap(tmp_path: Path):
    """CR-stripping must not degrade into reporting nothing at all."""
    existing = _write(tmp_path / "existing.md", "## Alpha\n")
    bundled = _write(tmp_path / "bundled.md", "## Alpha\n## Beta\n", crlf=True)

    result = _run(existing, bundled)

    assert result.returncode == 0
    assert [ln for ln in result.stdout.splitlines() if ln] == ["## Beta"]
    assert "\r" not in result.stdout, "CR leaked into the splice candidate"


# --- the pre-existing normalizations, pinned ------------------------------


def test_identical_files_report_no_gaps(tmp_path: Path):
    existing = _write(tmp_path / "existing.md", "## Alpha\n### Nested\n- [ ] one\n")
    bundled = _write(tmp_path / "bundled.md", "## Alpha\n### Nested\n- [ ] one\n")

    assert _run(existing, bundled).stdout == ""


def test_checkbox_state_and_ordering_are_not_a_diff(tmp_path: Path):
    existing = _write(tmp_path / "existing.md", "- [x] one\n## Alpha\n")
    bundled = _write(tmp_path / "bundled.md", "## Alpha\n- [ ] one\n")

    assert _run(existing, bundled).stdout == ""


def test_placeholder_seed_lines_are_never_reported(tmp_path: Path):
    """A filled-in stub legitimately lacks the seed line; it must not read as missing."""
    existing = _write(tmp_path / "existing.md", "## Alpha\n")
    bundled = _write(
        tmp_path / "bundled.md",
        "## Alpha\n### Q-001 -- [...] <!-- steer:placeholder -->\n",
    )

    assert _run(existing, bundled).stdout == ""


def test_missing_anchors_are_reported(tmp_path: Path):
    existing = _write(tmp_path / "existing.md", "## Alpha\n")
    bundled = _write(tmp_path / "bundled.md", "## Alpha\n## Beta\n- [ ] two\n")

    lines = [ln for ln in _run(existing, bundled).stdout.splitlines() if ln]

    assert sorted(lines) == ["## Beta", "- [ ] two"]


# --- error contract -------------------------------------------------------


def test_wrong_argument_count_exits_2(tmp_path: Path):
    result = subprocess.run(
        ["sh", str(_SCRIPT), str(tmp_path / "only-one.md")],
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 2


def test_unreadable_input_exits_3(tmp_path: Path):
    existing = _write(tmp_path / "existing.md", "## Alpha\n")

    result = _run(existing, tmp_path / "does-not-exist.md")

    assert result.returncode == 3

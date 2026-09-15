#!/usr/bin/env python3
"""Publish-ready release notes from a changie version file (``.changes/vX.Y.Z.md``).

A GitHub Release body is rendered in *comment mode* -- the same renderer as an
issue or PR comment, and unlike a ``.md`` file in the tree -- where every newline
becomes a ``<br>``. The changelog is authored hard-wrapped at 80 columns, so
publishing it verbatim put a line break mid-sentence on roughly every line:
v6.3.0's Release page carried 45 of them. Reflowing at publish time keeps the
source wrapped for review and hands GitHub one line per block, which it then
wraps to the reader's width.

The transform is structural, never lexical: it joins *continuation* lines onto
the block they continue and changes nothing else, so the word sequence is
preserved exactly (pinned by a round-trip test over every archived version
file). Any line that starts a block -- a list marker at any depth, a heading, a
link-reference definition, a blockquote, a fence, a thematic break -- begins its
own output line, so nesting and bullet structure survive. Fenced code and GFM
tables pass through verbatim.

Two deliberate non-goals:

- **Indented code blocks are not detected.** Separating a 4-space code block
  from a 4-space continuation of a nested bullet needs full list-context
  tracking; no archived version file has ever held one, and the round-trip test
  gates the corpus. A fence is the supported way to put code in an entry.
- **Tables are anchored on the delimiter row**, not on a leading ``|``. The one
  archived line that begins with ``|`` is prose continuing an inline GraphQL
  union (``| delete }``), and reading it as a table row would split that
  sentence in half.

Usage::

    python3 scripts/reflow_release_notes.py .changes/v6.3.0.md   # -> stdout
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

_FENCE = re.compile(r"^\s{0,3}(?:`{3,}|~{3,})")
_LIST = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s+")
_HEADING = re.compile(r"^\s{0,3}#{1,6}(?:\s|$)")
_LINK_DEF = re.compile(r"^\s*\[[^\]]+\]:\s")
_QUOTE = re.compile(r"^\s*>")
_RULE = re.compile(r"^\s{0,3}(?:(?:-\s*){3,}|(?:\*\s*){3,}|(?:_\s*){3,})$")


def _is_delimiter_row(line: str) -> bool:
    """A GFM table delimiter (``|---|:--:|``) -- what makes the rows above a table.

    Requires a ``|`` so a ``---`` thematic break is never mistaken for one.
    """
    text = line.strip()
    if "|" not in text or "-" not in text:
        return False
    return all(char in "|-: " for char in text)


def _table_lines(lines: list[str]) -> set[int]:
    """Indices belonging to a GFM table: its header, delimiter and body rows."""
    marked: set[int] = set()
    for index, line in enumerate(lines):
        if not _is_delimiter_row(line):
            continue
        # A delimiter row is only a table when a header row sits directly above.
        if index == 0:
            continue
        header = lines[index - 1]
        if not header.strip() or "|" not in header:
            continue
        marked.update({index - 1, index})
        row = index + 1
        while row < len(lines) and lines[row].strip() and "|" in lines[row]:
            marked.add(row)
            row += 1
    return marked


def _starts_block(line: str) -> bool:
    return bool(
        _LIST.match(line)
        or _HEADING.match(line)
        or _LINK_DEF.match(line)
        or _QUOTE.match(line)
        or _RULE.match(line)
    )


def reflow(text: str) -> str:
    """Join soft-wrapped continuation lines so each block is one line."""
    lines = text.splitlines()
    tables = _table_lines(lines)
    out: list[str] = []
    joinable = False
    in_fence = False

    for index, line in enumerate(lines):
        if in_fence:
            out.append(line)
            if _FENCE.match(line):
                in_fence = False
            continue
        if _FENCE.match(line):
            in_fence = True
            out.append(line)
            joinable = False
            continue
        if index in tables:
            out.append(line.rstrip())
            joinable = False
            continue
        if not line.strip():
            out.append("")
            joinable = False
            continue
        if joinable and not _starts_block(line):
            out[-1] = out[-1] + " " + line.strip()
            continue
        out.append(line.rstrip())
        joinable = True

    return "\n".join(out).strip("\n")


def strip_version_heading(text: str) -> str:
    """Drop the leading ``## X.Y.Z`` -- the Release title already carries it."""
    lines = text.splitlines()
    if lines and lines[0].startswith("## "):
        lines = lines[1:]
    while lines and not lines[0].strip():
        lines.pop(0)
    return "\n".join(lines)


def release_body(text: str) -> str:
    """A version file as it should be handed to a comment-mode renderer."""
    return reflow(strip_version_heading(text)) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Reflow a changie version file into a publish-ready release body."
    )
    parser.add_argument("path", type=Path, help="path to .changes/vX.Y.Z.md")
    args = parser.parse_args(argv)
    try:
        text = args.path.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"::error::{exc}", file=sys.stderr)
        return 1
    sys.stdout.write(release_body(text))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Migration-ledger integrity checks for the steer plugin.

`plugins/steer/templates/reference/MIGRATIONS.md` is the single source of truth
for non-additive spine/scaffold transforms. `/steer:sync` and `/steer:adopt` walk
it and apply each entry by its **precondition**, so a malformed entry is not a
cosmetic problem: it either never fires (the migration silently never runs) or
fires forever (a transform re-applied on every sync).

The checks, in two tiers.

**Structural — every entry:**

1. The heading is ``[Unreleased] — <what>`` or ``vX.Y.Z — <what>``, with a
   non-empty ``<what>``.
2. The three fields a consumer needs are present: **What & why**,
   **Precondition**, **Action**.
3. Ordering: every ``[Unreleased]`` entry precedes every versioned one, and
   versioned entries run newest-first (non-increasing — several entries may
   share one release).

**Deep — ``[Unreleased]`` entries only:**

Those are exactly the entries an open PR is introducing, so they are the ones a
gate can still cheaply stop. (The previous incarnation of this script anchored
its deep tier on "entries at or above the last released version", which under the
current ``[Unreleased]`` authoring convention selects *nothing* — it reported
"deep-checked 0 entries" on a clean development tree.)

4. No unfilled template placeholder (``<one-line what>``) survives in a real
   entry.
5. Every ``templates/…`` path the entry cites exists under ``plugins/steer/``.
6. Every ``` `## Heading` ``` the entry says to copy from exists in the file it
   names — a re-take pointing at a heading nobody can locate is unrunnable.

Deliberately **not** here: "no entry names a version ahead of the release".
That invariant is real and load-bearing, but ``check_plugin.py``'s
``check_migration_versions`` already owns it, keyed to ``plugin.json``. Asserting
it again from a different source of truth is how two gates drift into disagreeing
about one rule. ``check_standards.py`` states the complementary gap this script
fills: "migration-ledger targets are **not** machine-checked — MIGRATIONS.md
entries are prose".

The authoring template at the foot of the ledger lives inside an HTML comment and
is deliberately *not* an entry; comment regions are blanked before parsing so it
never counts (it carries the literal ``[Unreleased] — <one-line what>`` heading
and would otherwise fail checks 1 and 5).

Usage::

    uv run python scripts/check_migrations.py

Exit status is 0 when clean, 1 when any check fails.
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path

LEDGER = Path("plugins/steer/templates/reference/MIGRATIONS.md")
PLUGIN_ROOT = Path("plugins/steer")

UNRELEASED = "[Unreleased]"
# Entries separate the key from the summary with an em dash.
_HEADING_RE = re.compile(r"^###\s+(?P<key>\S+)\s*(?:—\s*(?P<what>.*?))?\s*$")
_VERSION_RE = re.compile(r"^v(\d+)\.(\d+)\.(\d+)$")
# A field bullet: `- **Action:**` but also `- **Action — an in-file token
# rewrite**,` — entries qualify the field name inside the bold run, so the name is
# whatever precedes the first `:` or `—`.
_FIELD_RE = re.compile(r"^\s*-\s+\*\*(?P<bold>[^*]+?):?\*\*", re.MULTILINE)
# A backticked token naming a bundled template, e.g. `templates/spec/intent.md`.
_TEMPLATE_PATH_RE = re.compile(r"`(templates/[A-Za-z0-9._/-]+)`")
# "copy … from `## Heading` in `templates/x.md`" — the re-take locatability case.
_CITED_SECTION_RE = re.compile(
    r"`(?P<heading>#{1,6}\s+[^`]+)`[^`]{0,80}?`(?P<path>templates/[A-Za-z0-9._/-]+)`"
)
# An unfilled placeholder from the authoring template reads as descriptive prose
# — `<one-line what>`, `<the concrete transform …>`. A single-token angle form is
# a legitimate path or id pattern (`steer-<skill>.prompt.md`), so require a space.
_PLACEHOLDER_RE = re.compile(r"<[a-z][a-z0-9_/&-]*(?: [a-z0-9_/&-]+)+>")

REQUIRED_FIELDS = ("What & why", "Precondition", "Action")


@dataclass
class Entry:
    """One `### ` block in the ledger's Entries section."""

    key: str
    what: str
    body: str
    line_no: int

    @property
    def version(self) -> tuple[int, int, int] | None:
        """The entry's semver key, or None when it is still `[Unreleased]`."""
        m = _VERSION_RE.match(self.key)
        return (int(m.group(1)), int(m.group(2)), int(m.group(3))) if m else None

    @property
    def is_unreleased(self) -> bool:
        return self.key == UNRELEASED

    def field(self, name: str) -> str | None:
        """The text of a `- **<name>:**` field, to the start of the next field."""
        matches = list(_FIELD_RE.finditer(self.body))
        for i, m in enumerate(matches):
            # `Action — an in-file token rewrite` is still the Action field.
            if m.group("bold").split("—")[0].strip() != name:
                continue
            end = matches[i + 1].start() if i + 1 < len(matches) else len(self.body)
            return self.body[m.end() : end].strip()
        return None


def blank_comments(text: str) -> str:
    """Strip every HTML-comment span, keeping the line count intact.

    The ledger's authoring template lives in a comment and must never parse as a
    real entry; leaving one line per source line means reported line numbers still
    point at the right place.

    Only the commented *span* is removed, never the whole line. Entries embed
    inline markers mid-sentence — ``a **profile** marker (`<!-- steer:profile=app
    -->`)`` — and blanking those lines outright would hide the real field bullets
    that share them.

    Code is opaque: neither a fenced block nor an inline-code span can open or
    close a comment. A precondition's own grep for a marker contains a bare,
    unclosed ``<!--`` (``grep -qiE '<!--[[:space:]]*steer:profile='``), and
    treating that as a comment opener swallows every following bullet until some
    unrelated line happens to contain ``-->``.
    """
    out: list[str] = []
    in_comment = False
    in_fence = False
    for line in text.splitlines():
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            out.append(line)
            continue
        if in_fence:
            out.append(line)
            continue
        rebuilt: list[str] = []
        i = 0
        while i < len(line):
            if in_comment:
                close = line.find("-->", i)
                if close == -1:
                    break
                in_comment = False
                i = close + 3
                continue
            tick = line.find("`", i)
            open_at = line.find("<!--", i)
            if open_at == -1 and tick == -1:
                rebuilt.append(line[i:])
                break
            # An inline-code span before the next `<!--` shields whatever is in it.
            if tick != -1 and (open_at == -1 or tick < open_at):
                close_tick = line.find("`", tick + 1)
                if close_tick == -1:
                    rebuilt.append(line[i:])
                    break
                rebuilt.append(line[i : close_tick + 1])
                i = close_tick + 1
                continue
            rebuilt.append(line[i:open_at])
            in_comment = True
            i = open_at + 4
        out.append("".join(rebuilt))
    return "\n".join(out)


def parse_entries(text: str) -> list[Entry]:
    """Every `### ` block below the `## Entries` heading, in document order."""
    lines = blank_comments(text).splitlines()
    try:
        start = next(i for i, ln in enumerate(lines) if ln.strip() == "## Entries")
    except StopIteration:
        return []

    entries: list[Entry] = []
    current: Entry | None = None
    buf: list[str] = []
    for offset, line in enumerate(lines[start + 1 :], start=start + 2):
        if line.startswith("## "):  # a later top-level section closes Entries
            break
        m = _HEADING_RE.match(line)
        if m:
            if current is not None:
                current.body = "\n".join(buf)
                entries.append(current)
            current = Entry(
                key=m.group("key"),
                what=(m.group("what") or "").strip(),
                body="",
                line_no=offset,
            )
            buf = []
            continue
        if current is not None:
            buf.append(line)
    if current is not None:
        current.body = "\n".join(buf)
        entries.append(current)
    return entries


def _v(t: tuple[int, int, int]) -> str:
    return "v{}.{}.{}".format(*t)


def check_structure(entries: list[Entry], errors: list[str]) -> None:
    """Heading grammar and the three required fields, for every entry."""
    for e in entries:
        where = f"{LEDGER}:{e.line_no}"
        if not (e.is_unreleased or e.version):
            errors.append(
                f"{where}: entry key {e.key!r} is neither `{UNRELEASED}` nor `vX.Y.Z`. "
                "Author a new entry as `### [Unreleased] — <what>`; the release "
                "renames it."
            )
            continue
        if not e.what:
            errors.append(f"{where}: entry `{e.key}` has no `— <what>` summary.")
        for name in REQUIRED_FIELDS:
            if e.field(name) is None:
                errors.append(
                    f"{where}: entry `{e.key} — {e.what}` has no "
                    f"**{name}:** field. A consumer cannot apply it."
                )


def check_ordering(entries: list[Entry], errors: list[str]) -> None:
    """`[Unreleased]` first, then versioned entries newest-first."""
    seen_versioned = False
    previous: tuple[int, int, int] | None = None
    for e in entries:
        if e.is_unreleased:
            if seen_versioned:
                errors.append(
                    f"{LEDGER}:{e.line_no}: `{UNRELEASED}` entry appears below a "
                    "versioned one. Entries are newest-first, so unreleased "
                    "entries belong at the top."
                )
            continue
        version = e.version
        if version is None:
            continue
        seen_versioned = True
        if previous is not None and version > previous:
            errors.append(
                f"{LEDGER}:{e.line_no}: `{_v(version)}` appears below "
                f"`{_v(previous)}`; entries must run newest-first."
            )
        previous = version


def check_unreleased_depth(entries: list[Entry], errors: list[str]) -> None:
    """Deep checks on the entries an open PR is introducing."""
    for e in (x for x in entries if x.is_unreleased):
        where = f"{LEDGER}:{e.line_no}"
        label = f"`{UNRELEASED} — {e.what}`"

        for name in REQUIRED_FIELDS:
            value = e.field(name)
            if value is None:
                continue
            leftover = _PLACEHOLDER_RE.search(value)
            if leftover:
                errors.append(
                    f"{where}: entry {label} still carries the template "
                    f"placeholder {leftover.group(0)!r} in **{name}:**."
                )

        body = e.body
        for cited in sorted(set(_TEMPLATE_PATH_RE.findall(body))):
            if not (PLUGIN_ROOT / cited).exists():
                errors.append(
                    f"{where}: entry {label} cites `{cited}`, which does not exist "
                    f"at {PLUGIN_ROOT / cited}."
                )

        for m in _CITED_SECTION_RE.finditer(body):
            heading, rel = m.group("heading").strip(), m.group("path")
            target = PLUGIN_ROOT / rel
            if not target.is_file():
                continue  # already reported by the path check above
            text = target.read_text(encoding="utf-8")
            present = [line.strip() for line in text.splitlines() if line.lstrip().startswith("#")]
            if heading not in present:
                errors.append(
                    f"{where}: entry {label} says to copy from `{heading}` in "
                    f"`{rel}`, which has no such heading — the action is not "
                    "locatable. Headings present: "
                    + ", ".join(repr(h) for h in present[:8])
                    + ("…" if len(present) > 8 else "")
                )


def main(argv: list[str] | None = None) -> int:
    del argv  # no options yet; kept for symmetry with the other check scripts
    if not LEDGER.is_file():
        print(f"check_migrations: {LEDGER} not found.", file=sys.stderr)
        return 1

    text = LEDGER.read_text(encoding="utf-8")
    entries = parse_entries(text)
    if not entries:
        print(f"check_migrations: no '## Entries' section in {LEDGER}.", file=sys.stderr)
        return 1

    errors: list[str] = []
    check_structure(entries, errors)
    check_ordering(entries, errors)
    check_unreleased_depth(entries, errors)

    unreleased = sum(1 for e in entries if e.is_unreleased)
    if errors:
        print(f"check_migrations: {len(errors)} problem(s) found:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1
    print(
        f"check_migrations: OK ({len(entries)} entries, {unreleased} deep-checked as [Unreleased])"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

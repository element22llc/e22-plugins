#!/usr/bin/env python3
"""Deterministic release cut for the steer plugin (``/release`` Phase B, steps B3-B5).

Cutting a release is four mechanical edits plus one validation, and every one of
them has a documented way to go wrong when done by hand:

- ``CHANGELOG.md``: rename the **heading** ``### [Unreleased]`` to ``### X.Y.Z``
  and re-seed an empty ``### [Unreleased]`` above it. The same text also appears
  as prose in the changelog's own house-rules bullet, so a naive search-and-
  replace hits the wrong line.
- ``templates/reference/MIGRATIONS.md``: rename every ``### [Unreleased] — <what>``
  entry **inside ``## Entries``** to ``### vX.Y.Z — <what>``. The authoring stub in
  the trailing ``<!-- Template for a new entry -->`` comment carries the identical
  heading and must never be stamped -- no gate catches it when it is.
- The three version-bearing manifests must all move to ``X.Y.Z`` -- and the
  Copilot marketplace file carries a *second* ``version`` (``metadata.version``,
  the marketplace's own) that must be left alone.

This script does all of it from one command, refuses the cut when a precondition
does not hold (no bullets, non-ascending version, heading already present), and
re-validates the release invariant afterwards. ``--dry-run`` prints the exact
diff and writes nothing. The skills call it instead of editing by hand, so the
step is reviewable in one place and cannot drift between ``/release`` and
``/quick-release``.

Usage::

    uv run python scripts/release_cut.py propose                # non-binding bump suggestion
    uv run python scripts/release_cut.py cut 6.1.0 --dry-run    # show the edits
    uv run python scripts/release_cut.py cut 6.1.0              # apply + validate
    uv run python scripts/release_cut.py pr-body 6.1.0 --via release [--audit FILE]

Exit status is 0 on success, 1 when a precondition or the post-cut validation
fails. Stdlib only.
"""

from __future__ import annotations

import argparse
import difflib
import json
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CHANGELOG = REPO_ROOT / "CHANGELOG.md"
MIGRATIONS = REPO_ROOT / "plugins/steer/templates/reference/MIGRATIONS.md"
PLUGIN_JSON = REPO_ROOT / "plugins/steer/.claude-plugin/plugin.json"
COPILOT_PLUGIN_JSON = REPO_ROOT / "plugins/steer/.github/plugin/plugin.json"
COPILOT_MARKETPLACE = REPO_ROOT / ".github/plugin/marketplace.json"

UNRELEASED = "### [Unreleased]"
_SEMVER_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")
_HEADING_RE = re.compile(r"^###\s+(.+?)\s*$")
_MIGRATION_STUB_MARKER = "<!-- Template for a new entry"

# Bullet-prefix vocabulary the changelog uses (`- **Added:** ...`). The
# proposal is a *suggestion*: the human confirms the bump.
_MAJOR_HINTS = ("breaking", "removed:", "renamed:", "**removed", "**breaking")
_MINOR_HINTS = ("added:", "**added", "new skill", "new rule", "new hook", "new scaffold")


class CutError(Exception):
    """A precondition or validation failure that must stop the cut."""


def _semver(text: str) -> tuple[int, int, int]:
    m = _SEMVER_RE.match(text.strip())
    if not m:
        raise CutError(f"not a semver version: {text!r}")
    return int(m[1]), int(m[2]), int(m[3])


# --- CHANGELOG ----------------------------------------------------------------


def _steer_bounds(lines: list[str]) -> tuple[int, int]:
    """Index range ``[start, end)`` of the ``## steer`` section body."""
    start = end = None
    for i, line in enumerate(lines):
        if line.startswith("## "):
            if start is not None:
                end = i
                break
            if line.strip() == "## steer":
                start = i + 1
    if start is None:
        raise CutError(f"{CHANGELOG.name}: no '## steer' section")
    return start, end if end is not None else len(lines)


def unreleased_block(text: str) -> tuple[int, list[str]]:
    """Return ``(heading_index, bullet_lines)`` for the ``### [Unreleased]`` heading.

    Heading lines only -- the inline prose mention lower in the file is never a
    match. Raises when the heading is missing, duplicated, or not the first
    heading under ``## steer``.
    """
    lines = text.splitlines()
    start, end = _steer_bounds(lines)
    heads = [(i, _HEADING_RE.match(lines[i])) for i in range(start, end)]
    heads = [(i, m.group(1)) for i, m in heads if m]
    unreleased = [i for i, h in heads if h == "[Unreleased]"]
    if not unreleased:
        raise CutError(f"{CHANGELOG.name}: no '{UNRELEASED}' heading under '## steer'")
    if len(unreleased) > 1:
        raise CutError(f"{CHANGELOG.name}: '{UNRELEASED}' appears {len(unreleased)} times")
    if heads[0][0] != unreleased[0]:
        raise CutError(
            f"{CHANGELOG.name}: '{UNRELEASED}' is not the first heading under '## steer'"
        )
    idx = unreleased[0]
    nxt = next((i for i, _ in heads if i > idx), end)
    body = [ln for ln in lines[idx + 1 : nxt] if ln.strip()]
    return idx, body


def released_versions(text: str) -> list[str]:
    lines = text.splitlines()
    start, end = _steer_bounds(lines)
    out = []
    for i in range(start, end):
        m = _HEADING_RE.match(lines[i])
        if m and _SEMVER_RE.match(m.group(1)):
            out.append(m.group(1))
    return out


def cut_changelog(text: str, version: str) -> str:
    """Rename the heading to ``### version`` and re-seed an empty ``[Unreleased]``."""
    idx, bullets = unreleased_block(text)
    if not bullets:
        raise CutError(f"{CHANGELOG.name}: '{UNRELEASED}' has no bullets -- nothing to release")
    released = released_versions(text)
    if version in released:
        raise CutError(f"{CHANGELOG.name}: '### {version}' already exists")
    if released and _semver(version) <= _semver(released[0]):
        raise CutError(
            f"{CHANGELOG.name}: {version} is not above the newest released heading {released[0]}"
        )
    lines = text.splitlines()
    lines[idx] = f"### {version}"
    lines[idx:idx] = [UNRELEASED, ""]
    return "\n".join(lines) + ("\n" if text.endswith("\n") else "")


# --- MIGRATIONS ---------------------------------------------------------------


def migration_entry_range(text: str) -> tuple[int, int]:
    """Index range ``[start, end)`` of the ``## Entries`` list, excluding the stub.

    ``end`` is the line of the trailing ``<!-- Template for a new entry`` comment
    (or EOF when absent). Headings at or past ``end`` are the authoring stub and
    must never be renamed.
    """
    lines = text.splitlines()
    try:
        start = next(i for i, ln in enumerate(lines) if ln.strip() == "## Entries") + 1
    except StopIteration as exc:
        raise CutError(f"{MIGRATIONS.name}: no '## Entries' section") from exc
    end = next(
        (i for i in range(start, len(lines)) if lines[i].startswith(_MIGRATION_STUB_MARKER)),
        len(lines),
    )
    return start, end


def cut_migrations(text: str, version: str) -> tuple[str, int]:
    """Rename ``### [Unreleased] — <what>`` entries to ``### v<version> — <what>``.

    Returns ``(new_text, renamed_count)``. Zero renames is the normal case.
    """
    lines = text.splitlines()
    start, end = migration_entry_range(text)
    renamed = 0
    for i in range(start, end):
        if lines[i].startswith(UNRELEASED):
            lines[i] = f"### v{version}" + lines[i][len(UNRELEASED) :]
            renamed += 1
    out = "\n".join(lines) + ("\n" if text.endswith("\n") else "")
    return out, renamed


# --- manifests ----------------------------------------------------------------


def _steer_entry_version(marketplace: dict) -> str:
    for entry in marketplace.get("plugins", []):
        if entry.get("name") == "steer":
            return entry.get("version", "")
    raise CutError(f"{COPILOT_MARKETPLACE.name}: no 'steer' plugin entry")


def bump_manifest(text: str, path: Path, old: str, new: str) -> str:
    """Textually replace the one ``"version": "<old>"`` line so formatting survives.

    Re-serialising with ``json.dump`` would reflow the file; a textual edit keeps
    the diff to the single line a reviewer expects. Exactly one line may carry
    the old version: the Copilot marketplace also has ``metadata.version`` (the
    marketplace's own), so if that ever equals the plugin version the edit is
    ambiguous and the cut stops rather than guessing.
    """
    pattern = re.compile(r'^(\s*"version":\s*")' + re.escape(old) + r'(",?)\s*$', re.M)
    hits = pattern.findall(text)
    if len(hits) != 1:
        raise CutError(
            f'{path.relative_to(REPO_ROOT)}: expected exactly one \'"version": "{old}"\' '
            f"line, found {len(hits)} -- refusing to guess"
        )
    return pattern.sub(lambda m: f"{m.group(1)}{new}{m.group(2)}", text)


def _manifest_versions() -> dict[Path, str]:
    return {
        PLUGIN_JSON: json.loads(PLUGIN_JSON.read_text(encoding="utf-8")).get("version", ""),
        COPILOT_PLUGIN_JSON: json.loads(COPILOT_PLUGIN_JSON.read_text(encoding="utf-8")).get(
            "version", ""
        ),
        COPILOT_MARKETPLACE: _steer_entry_version(
            json.loads(COPILOT_MARKETPLACE.read_text(encoding="utf-8"))
        ),
    }


# --- commands -----------------------------------------------------------------


def plan_cut(version: str) -> dict[Path, tuple[str, str]]:
    """Compute every edit as ``{path: (before, after)}`` without writing."""
    _semver(version)
    current = _manifest_versions()
    if len(set(current.values())) != 1:
        raise CutError(
            "manifests disagree before the cut: "
            + ", ".join(f"{p.relative_to(REPO_ROOT)}={v}" for p, v in current.items())
        )
    old = next(iter(current.values()))
    if _semver(version) <= _semver(old):
        raise CutError(f"{version} is not above the current plugin version {old}")

    edits: dict[Path, tuple[str, str]] = {}
    before = CHANGELOG.read_text(encoding="utf-8")
    edits[CHANGELOG] = (before, cut_changelog(before, version))
    if MIGRATIONS.is_file():
        before = MIGRATIONS.read_text(encoding="utf-8")
        after, _ = cut_migrations(before, version)
        if after != before:
            edits[MIGRATIONS] = (before, after)
    for path in (PLUGIN_JSON, COPILOT_PLUGIN_JSON, COPILOT_MARKETPLACE):
        before = path.read_text(encoding="utf-8")
        edits[path] = (before, bump_manifest(before, path, old, version))
    return edits


def validate_cut(version: str) -> list[str]:
    """Post-cut assertions: the release invariant plus the migration-stub guard."""
    errors: list[str] = []
    versions = _manifest_versions()
    for path, v in versions.items():
        if v != version:
            errors.append(f"{path.relative_to(REPO_ROOT)}: version {v!r} != {version}")
    marketplace = json.loads(COPILOT_MARKETPLACE.read_text(encoding="utf-8"))
    if marketplace.get("metadata", {}).get("version") == version:
        errors.append(f"{COPILOT_MARKETPLACE.name}: metadata.version was bumped -- it must not be")

    text = CHANGELOG.read_text(encoding="utf-8")
    idx, bullets = unreleased_block(text)
    if bullets:
        errors.append(f"{CHANGELOG.name}: re-seeded '{UNRELEASED}' is not empty")
    released = released_versions(text)
    if not released or released[0] != version:
        errors.append(f"{CHANGELOG.name}: newest released heading is {released[:1]} not {version}")

    if MIGRATIONS.is_file():
        mtext = MIGRATIONS.read_text(encoding="utf-8")
        mlines = mtext.splitlines()
        start, end = migration_entry_range(mtext)
        if any(mlines[i].startswith(UNRELEASED) for i in range(start, end)):
            errors.append(
                f"{MIGRATIONS.name}: an '[Unreleased]' entry survived inside '## Entries'"
            )
        if any(ln.startswith(f"### v{version}") for ln in mlines[end:]):
            errors.append(f"{MIGRATIONS.name}: the authoring stub was stamped with v{version}")
    return errors


def propose(text: str) -> dict:
    """Heuristic bump suggestion from the ``[Unreleased]`` bullets. Non-binding."""
    _, bullets = unreleased_block(text)
    tops = [b for b in bullets if b.startswith("- ")]
    lowered = [b.lower() for b in tops]
    major = [b for b in lowered if any(h in b for h in _MAJOR_HINTS)]
    minor = [b for b in lowered if any(h in b for h in _MINOR_HINTS)]
    level = "major" if major else "minor" if minor else "patch"
    cur = _semver(json.loads(PLUGIN_JSON.read_text(encoding="utf-8"))["version"])
    candidates = {
        "major": f"{cur[0] + 1}.0.0",
        "minor": f"{cur[0]}.{cur[1] + 1}.0",
        "patch": f"{cur[0]}.{cur[1]}.{cur[2] + 1}",
    }
    return {
        "current": ".".join(map(str, cur)),
        "bullets": len(tops),
        "major_hints": len(major),
        "minor_hints": len(minor),
        "suggested": level,
        "candidates": candidates,
    }


def _run(cmd: list[str]) -> str:
    out = subprocess.run(cmd, capture_output=True, text=True, check=False, cwd=REPO_ROOT)
    return out.stdout


def pr_body(version: str, via: str, audit_file: Path | None) -> str:
    sys.path.insert(0, str(REPO_ROOT / "scripts"))
    import changelog_release_notes as crn  # noqa: PLC0415 (lazy: shares the notes parser)

    notes = crn.release_notes(version)
    parts = [f"# Release steer {version}", "", "## Changes", "", notes, ""]
    parts += ["## Pre-release audit", ""]
    if audit_file and audit_file.is_file():
        parts += [audit_file.read_text(encoding="utf-8").rstrip(), ""]
    else:
        parts += ["_TODO: paste the Phase-A verdict (gates, coherence, docs) here._", ""]
    if via == "quick-release":
        parts += [
            "> Cut via `/quick-release`: deterministic gates (CI, strict docs build, "
            "deployed-docs freshness) passed. The judgment-based coherence audit and "
            "documentation-accuracy deep review were **not** run -- reviewers should "
            "apply that scrutiny to the diff.",
            "",
        ]
    parts += ["## Always-on context budget", ""]
    parts += [_run(["uv", "run", "python", "scripts/check_context_budget.py", "--report"]).rstrip()]
    return "\n".join(parts) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("propose", help="suggest a bump from the [Unreleased] bullets")
    p_cut = sub.add_parser("cut", help="rename headings + bump manifests, then validate")
    p_cut.add_argument("version", help="X.Y.Z")
    p_cut.add_argument("--dry-run", action="store_true", help="print the diff, write nothing")
    p_pr = sub.add_parser("pr-body", help="print the release PR body")
    p_pr.add_argument("version")
    p_pr.add_argument("--via", choices=("release", "quick-release"), default="release")
    p_pr.add_argument("--audit", type=Path, default=None, help="file with the audit verdict")
    args = parser.parse_args(argv)

    try:
        if args.cmd == "propose":
            info = propose(CHANGELOG.read_text(encoding="utf-8"))
            print(f"current version: {info['current']}")
            print(f"[Unreleased] top-level bullets: {info['bullets']}")
            print(f"major hints: {info['major_hints']}, minor hints: {info['minor_hints']}")
            print(f"suggested bump: {info['suggested']} -> {info['candidates'][info['suggested']]}")
            print("candidates: " + ", ".join(f"{k}={v}" for k, v in info["candidates"].items()))
            print("(heuristic only -- confirm the bump with the user before cutting)")
            return 0
        if args.cmd == "cut":
            edits = plan_cut(args.version)
            for path, (before, after) in edits.items():
                rel = str(path.relative_to(REPO_ROOT))
                if args.dry_run:
                    sys.stdout.writelines(
                        difflib.unified_diff(
                            before.splitlines(keepends=True),
                            after.splitlines(keepends=True),
                            fromfile=f"a/{rel}",
                            tofile=f"b/{rel}",
                        )
                    )
                else:
                    path.write_text(after, encoding="utf-8")
                    print(f"edited {rel}")
            if args.dry_run:
                print(f"\ndry run: {len(edits)} file(s) would change; nothing written")
                return 0
            errors = validate_cut(args.version)
            if errors:
                for e in errors:
                    print(f"error: {e}", file=sys.stderr)
                return 1
            print(f"cut steer {args.version}: release invariant holds")
            return 0
        if args.cmd == "pr-body":
            sys.stdout.write(pr_body(args.version, args.via, args.audit))
            return 0
    except CutError as exc:
        print(f"release_cut: {exc}", file=sys.stderr)
        return 1
    except KeyError as exc:
        print(f"release_cut: no '### {exc.args[0]}' heading in CHANGELOG.md", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

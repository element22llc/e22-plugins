#!/usr/bin/env python3
"""Changelog + release-integrity checks for the steer plugin.

Entries live as one curated fragment per change under ``.changes/unreleased/``;
``changie`` assembles them into a version file at release and merges every
version file into ``CHANGELOG.md``. Three checks, so the same script serves
local runs and the CI PR gate:

1. **Release validator** (always - no git, no changie needed): the version in
   ``plugin.json`` equals the newest ``.changes/vX.Y.Z.md``, and the assembled
   ``CHANGELOG.md`` carries exactly those versions in strictly descending
   order. A hand-edited or stale ``CHANGELOG.md`` fails here rather than
   shipping.

2. **Fragment validator** (always): every pending fragment parses, names a kind
   the config declares, and carries a body and a slug.

3. **Behaviour-change gate** (only with ``--base <ref>``): if any plugin
   behaviour file changed versus the base ref, a fragment must have been *added*
   under ``.changes/unreleased/`` - so a stream of PRs accumulates entries.
   Behaviour is deny-by-default: everything under ``plugins/steer/`` counts,
   minus the exemptions enumerated below, each with the reason it ships nothing.
   A **release cut** satisfies the gate with an added ``.changes/vX.Y.Z.md``
   instead: it folds the pending fragments into that file and empties
   ``unreleased/``, so it can never add one.

Usage::

    uv run python scripts/check_changelog.py                 # validators only
    uv run python scripts/check_changelog.py --base origin/main   # + behaviour gate

Exit status is 0 when clean, 1 when any check fails.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

import yaml

PLUGIN_JSON = Path("plugins/steer/.claude-plugin/plugin.json")
CHANGELOG = Path("CHANGELOG.md")
CHANGIE_CONFIG = Path(".changie.yaml")
CHANGES_DIR = Path(".changes")
UNRELEASED_DIR = CHANGES_DIR / "unreleased"

# Everything the plugin ships is behaviour. An allowlist of directory prefixes fails
# open - the plugin format keeps gaining component types, and adopting a new one
# would ship ungated until somebody remembered to widen the gate. So the
# classifier is deny-by-default: anything under `plugins/steer/`
# requires a changelog fragment unless it is exempted below, and each exemption carries
# the reason it ships nothing. The failure mode is a false positive a reviewer sees,
# not a silent miss.
PLUGIN_ROOT = "plugins/steer/"
EXEMPT_SUBSTRINGS = ("/tests/",)  # test suites, wherever they sit under the plugin
EXEMPT_PREFIXES = (
    "plugins/steer/evals/",  # a dev gate like tests/ - inert at runtime
    "plugins/steer/.claude/",  # local dev settings for this checkout
)
EXEMPT_EXACT = (
    "plugins/steer/README.md",  # maintainer notes, deliberately not shipped
)
# Consumer-facing behaviour that lives outside `plugins/steer/`: the Copilot
# marketplace entry carrying steer's released version. The two plugin manifests are
# already covered by the plugin-root rule above.
BEHAVIOUR_EXACT = (".github/plugin/marketplace.json",)

_SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+$")
_VERSION_FILE_RE = re.compile(r"^v(\d+\.\d+\.\d+)\.md$")
_HEADING_RE = re.compile(r"^##\s+(\d+\.\d+\.\d+)\s*$")


def _semver(s: str) -> tuple[int, int, int]:
    a, b, c = s.split(".")
    return int(a), int(b), int(c)


def declared_kinds() -> list[str]:
    """Kind labels from .changie.yaml, so this gate can't drift from the config."""
    if not CHANGIE_CONFIG.is_file():
        return []
    try:
        cfg = yaml.safe_load(CHANGIE_CONFIG.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError:
        return []
    return [k.get("label", "") for k in cfg.get("kinds", []) if isinstance(k, dict)]


def version_files() -> list[str]:
    """Released versions from `.changes/vX.Y.Z.md`, newest first."""
    if not CHANGES_DIR.is_dir():
        return []
    found = [m.group(1) for p in CHANGES_DIR.glob("v*.md") if (m := _VERSION_FILE_RE.match(p.name))]
    return sorted(found, key=_semver, reverse=True)


def changelog_headings() -> list[str]:
    """Version headings in the assembled CHANGELOG.md, in document order."""
    if not CHANGELOG.is_file():
        return []
    return [
        m.group(1)
        for line in CHANGELOG.read_text(encoding="utf-8").splitlines()
        if (m := _HEADING_RE.match(line))
    ]


def check_release(errors: list[str]) -> None:
    if not PLUGIN_JSON.is_file():
        errors.append(f"{PLUGIN_JSON}: missing")
        return
    try:
        version = json.loads(PLUGIN_JSON.read_text(encoding="utf-8")).get("version")
    except json.JSONDecodeError as exc:
        errors.append(f"{PLUGIN_JSON}: invalid JSON ({exc})")
        return
    if not version:
        errors.append(f"{PLUGIN_JSON}: missing version")
        return

    versions = version_files()
    if not versions:
        errors.append(f"{CHANGES_DIR}: no released 'vX.Y.Z.md' version file")
        return
    if versions[0] != version:
        errors.append(
            f"{PLUGIN_JSON}: version {version} != newest version file {versions[0]} "
            "(`changie merge` rewrites plugin.json - run it rather than editing by hand)"
        )

    # The committed CHANGELOG.md is generated. If it disagrees with the version
    # files, someone edited it directly and the next `changie merge` would silently
    # revert them.
    headings = changelog_headings()
    if headings != versions:
        missing = [v for v in versions if v not in headings]
        extra = [h for h in headings if h not in versions]
        detail = []
        if missing:
            detail.append(f"missing from CHANGELOG.md: {missing[:5]}")
        if extra:
            detail.append(f"not backed by a version file: {extra[:5]}")
        if not detail:
            detail.append("same versions, wrong order")
        errors.append(
            f"{CHANGELOG} is out of sync with {CHANGES_DIR} ({'; '.join(detail)}) "
            "- run `mise run changelog:merge`"
        )


def check_fragments(errors: list[str]) -> None:
    """Every pending fragment must be well-formed before it can be batched."""
    if not UNRELEASED_DIR.is_dir():
        return
    kinds = declared_kinds()
    for frag in sorted(UNRELEASED_DIR.glob("*.yaml")):
        try:
            data = yaml.safe_load(frag.read_text(encoding="utf-8"))
        except yaml.YAMLError as exc:
            errors.append(f"{frag}: invalid YAML ({exc})")
            continue
        if not isinstance(data, dict):
            errors.append(f"{frag}: expected a mapping")
            continue
        kind = data.get("kind")
        if kinds and kind not in kinds:
            errors.append(f"{frag}: kind {kind!r} is not one of {kinds}")
        if not str(data.get("body") or "").strip():
            errors.append(f"{frag}: empty body")
        if not str((data.get("custom") or {}).get("Slug") or "").strip():
            errors.append(f"{frag}: missing custom.Slug")


def _changed_files(base: str) -> list[tuple[str, str]] | None:
    """(status, path) pairs versus ``base``; None when the diff is unavailable."""
    for args in (["--name-status", f"{base}...HEAD"], ["--name-status", base, "HEAD"]):
        try:
            out = subprocess.run(
                ["git", "diff", *args], capture_output=True, text=True, check=True
            ).stdout
        except (subprocess.CalledProcessError, FileNotFoundError):
            continue
        pairs = []
        for line in out.splitlines():
            parts = line.split("\t")
            if len(parts) >= 2:
                pairs.append((parts[0], parts[-1]))
        return pairs
    return None


def _is_behaviour(path: str) -> bool:
    if path in BEHAVIOUR_EXACT:
        return True
    if not path.startswith(PLUGIN_ROOT):
        return False
    if any(sub in path for sub in EXEMPT_SUBSTRINGS):
        return False
    return not (path in EXEMPT_EXACT or path.startswith(EXEMPT_PREFIXES))


def check_behaviour_gate(base: str, errors: list[str]) -> None:
    changed = _changed_files(base)
    if changed is None:
        print(f"check_changelog: could not diff against {base!r}; skipping behaviour gate.")
        return
    behaviour = [p for _, p in changed if _is_behaviour(p)]
    # Only an ADDED fragment counts: editing an existing one is amending somebody
    # else's pending entry, not recording this change.
    added = [p for st, p in changed if st.startswith("A") and p.startswith(f"{UNRELEASED_DIR}/")]
    # A release cut is the one behaviour-changing PR that can never add a fragment:
    # `changie batch` folds every pending fragment into `.changes/vX.Y.Z.md` and
    # empties `unreleased/`, so the added version file *is* this PR's record.
    cut = [
        p
        for st, p in changed
        if st.startswith("A")
        and Path(p).parent == CHANGES_DIR
        and _VERSION_FILE_RE.match(Path(p).name)
    ]
    if behaviour and not added and not cut:
        errors.append(
            "A changelog fragment must be added when plugin behaviour changes. Run "
            "`mise run changelog:new` (or write .changes/unreleased/<kind>-<stamp>-<slug>.yaml). "
            f"Behaviour files changed: {behaviour[:8]}"
        )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="steer changelog/release checks.")
    parser.add_argument("--base", help="Base git ref for the behaviour-change gate.")
    args = parser.parse_args(argv)

    errors: list[str] = []
    check_release(errors)
    check_fragments(errors)
    if args.base:
        check_behaviour_gate(args.base, errors)

    if errors:
        print(f"check_changelog: {len(errors)} problem(s) found:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1
    print("check_changelog: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())

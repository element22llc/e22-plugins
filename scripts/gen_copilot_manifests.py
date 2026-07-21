#!/usr/bin/env python3
"""Stamp the Copilot manifests' ``version`` from the plugin's source of truth.

steer is published to two marketplaces from one version: the Claude
``plugins/steer/.claude-plugin/plugin.json`` ``version``. The Copilot manifests
each declare their own version and can silently drift from a release:

* ``plugins/steer/.github/plugin/plugin.json`` — the Copilot CLI plugin manifest;
* ``.github/plugin/marketplace.json`` (repo root) — the Copilot marketplace, in
  its ``steer`` plugin entry.

This generator rewrites **only** the ``version`` field in each (a targeted
string edit — every other field, including the Copilot-specific descriptions and
the marketplace-level ``metadata.version``, is left byte-for-byte untouched), so
the three stay locked without a hand bump per file. ``check_plugin.py``'s
``check_copilot_version_sync`` remains the gate that fails the build on any drift.

It runs inside ``mise run gen:copilot`` (idempotent — re-stamps the current
version when nothing changed) and again from the release skill after the source
bump. Run from the repo root::

    uv run python scripts/gen_copilot_manifests.py            # report intended state
    uv run python scripts/gen_copilot_manifests.py --write    # apply
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

SOURCE = Path("plugins/steer/.claude-plugin/plugin.json")
COPILOT_PLUGIN = Path("plugins/steer/.github/plugin/plugin.json")
COPILOT_MARKETPLACE = Path(".github/plugin/marketplace.json")

# The lone ``version`` field in the Copilot CLI plugin manifest.
_PLUGIN_VERSION = re.compile(r'("version":\s*")[^"]*(")')
# The ``version`` field *of the steer entry* in the marketplace manifest — anchored
# on the entry's name+source so the marketplace-level ``metadata.version`` (a
# different, independently-managed version) is never touched.
_MARKETPLACE_STEER_VERSION = re.compile(
    r'("name":\s*"steer",\s*"source":\s*"[^"]*",\s*"version":\s*")[^"]*(")',
    re.DOTALL,
)


def _source_version() -> str:
    version = json.loads(SOURCE.read_text(encoding="utf-8")).get("version")
    if not version:
        raise ValueError(f"no version in {SOURCE}")
    return str(version)


def _restamp(path: Path, pattern: re.Pattern[str], version: str) -> tuple[str, bool]:
    """Return (new_text, changed). Raises if the pattern doesn't match exactly once."""
    text = path.read_text(encoding="utf-8")
    new_text, count = pattern.subn(lambda m: f"{m.group(1)}{version}{m.group(2)}", text, count=1)
    if count != 1:
        raise ValueError(f"expected exactly one version field in {path}, matched {count}")
    return new_text, new_text != text


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Stamp the Copilot manifests' version.")
    parser.add_argument("--write", action="store_true", help="Apply the edits (default: report).")
    args = parser.parse_args(argv)

    if not SOURCE.is_file():
        print(f"gen_copilot_manifests: source not found: {SOURCE}", file=sys.stderr)
        return 1
    try:
        version = _source_version()
    except ValueError as exc:
        print(f"gen_copilot_manifests: {exc}", file=sys.stderr)
        return 1

    targets = [
        (COPILOT_PLUGIN, _PLUGIN_VERSION),
        (COPILOT_MARKETPLACE, _MARKETPLACE_STEER_VERSION),
    ]

    changed_any = False
    for path, pattern in targets:
        if not path.is_file():
            print(f"gen_copilot_manifests: target not found: {path}", file=sys.stderr)
            return 1
        try:
            new_text, changed = _restamp(path, pattern, version)
        except ValueError as exc:
            print(f"gen_copilot_manifests: {exc}", file=sys.stderr)
            return 1
        if changed:
            changed_any = True
            if args.write:
                path.write_text(new_text, encoding="utf-8")
                print(f"gen_copilot_manifests: stamped {path} -> {version}")
            else:
                print(f"gen_copilot_manifests: {path} would be stamped -> {version}")
        else:
            print(f"gen_copilot_manifests: {path} already at {version}")

    if changed_any and not args.write:
        print("gen_copilot_manifests: run with --write to apply")
    return 0


if __name__ == "__main__":
    sys.exit(main())

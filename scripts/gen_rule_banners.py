#!/usr/bin/env python3
"""Stamp (and verify) the provenance banner on every Tier 2 rule template.

Tier 2 rules ship in the plugin and are *copied into* a managed repo as
``.claude/rules/steer-*.md``. Once copied they are two files that can diverge in
two very different ways, and a repair step has to tell them apart:

* the **plugin** moved on — the repo's copy is stale and should be replaced;
* the repo's copy **changed after installation** — replacing it may destroy work.

Content comparison alone cannot distinguish those: both show up as "differs from
what the plugin ships". So each installed file records what steer wrote::

    <!-- steer:managed 40-testing v6.0.0 body-cksum:2751348805 — … -->

``body-cksum`` is a POSIX ``cksum`` over every byte of the file *except* the
banner line itself (so it covers the ``paths:`` frontmatter too — editing a glob
is as much a local edit as editing prose). At scan time
``scan-rule-drift.sh`` recomputes it:

===========================  ==========================================
recomputed == banner stamp   the body is unchanged since install, so a
                             difference from the plugin is the plugin's →
                             **stale**
recomputed != banner stamp   the body changed after installation →
                             **edited**, never overwritten silently
===========================  ==========================================

What the stamp does and does not tell you
-----------------------------------------
It is **drift metadata, not an authenticity or security boundary.** All it
establishes is that the body differs from what was recorded at install time. It
attributes nothing: it cannot tell you *who* or *what* changed the file — a
person, a formatter, a merge, a script, or a partial write all look identical.
Anything that can edit the file can also edit the stamp, and a CRC is trivial to
forge besides. Never treat a matching stamp as evidence a file is trustworthy;
its only job is to route a repair (replace vs. show a diff).

Why ``cksum`` and not sha256
----------------------------
Purely **availability and portability of the tool**, not of the digest — a
SHA-256 digest is identical on every platform; what differs is that macOS ships
``shasum`` and Linux ``sha256sum``, with different argument and output
conventions, and neither is guaranteed present. ``cksum`` is POSIX-mandated, so
it exists on every host these hooks run on with no dependency to install and no
per-platform command branching, and its CRC is specified exactly (verified
against the POSIX reference value for ``123456789``: 930766865). Since the stamp
is drift metadata and explicitly not a security control, the weaker checksum
costs nothing that matters here.

The stamp is generated, therefore it can go stale in the plugin's own tree the
moment anybody edits a rule. ``--check`` is wired into ``mise run check`` so it
cannot::

    uv run python scripts/gen_rule_banners.py --write   # stamp
    uv run python scripts/gen_rule_banners.py --check   # gate (exit 1 if stale)
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

PLUGIN_ROOT = Path("plugins/steer")
RULES_DIR = PLUGIN_ROOT / "templates/scaffold/claude/rules"
PLUGIN_JSON = PLUGIN_ROOT / ".claude-plugin/plugin.json"

_BANNER_LINE_RE = re.compile(r"^<!-- steer:managed .*$", re.M)

BANNER_TMPL = (
    "<!-- steer:managed {stem} v{version} body-cksum:{cksum} — installed by "
    "/steer:init / /steer:adopt and reconciled by /steer:sync. Edit the rule in the "
    "steer plugin, not here: a local edit is detected and preserved, but it will not "
    "reach any other repo. -->"
)


def posix_cksum(data: str) -> str:
    """POSIX ``cksum`` CRC of ``data``, as the shell scanner computes it.

    Shelled out rather than reimplemented: the value has to agree byte-for-byte
    with what ``scan-rule-drift.sh`` computes at runtime, and the surest way to
    guarantee that is to call the same tool.
    """
    proc = subprocess.run(["cksum"], input=data.encode("utf-8"), capture_output=True, check=True)
    return proc.stdout.decode().split()[0]


def plugin_version() -> str:
    return json.loads(PLUGIN_JSON.read_text(encoding="utf-8"))["version"]


def strip_banner(text: str) -> str:
    """Everything but the banner line — what the stamp is computed over."""
    return _BANNER_LINE_RE.sub("", text, count=1)


def stamp(path: Path, version: str) -> tuple[str, bool]:
    """Return (new_text, changed) for one rule file."""
    text = path.read_text(encoding="utf-8")
    body = strip_banner(text)
    banner = BANNER_TMPL.format(
        stem=path.stem.removeprefix("steer-"), version=version, cksum=posix_cksum(body)
    )
    if _BANNER_LINE_RE.search(text):
        new = _BANNER_LINE_RE.sub(lambda _: banner, text, count=1)
    else:
        # No banner yet: insert directly after the YAML frontmatter.
        parts = text.split("---\n", 2)
        if len(parts) == 3 and parts[0] == "":
            new = f"---\n{parts[1]}---\n{banner}\n{parts[2]}"
        else:
            new = f"{banner}\n{text}"
    return new, new != text


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write", action="store_true", help="stamp every rule template")
    mode.add_argument("--check", action="store_true", help="fail if any stamp is stale")
    args = ap.parse_args(argv)

    if not RULES_DIR.is_dir():
        print(f"gen_rule_banners: {RULES_DIR} not found", file=sys.stderr)
        return 1

    version = plugin_version()
    stale: list[str] = []
    written = 0
    for path in sorted(RULES_DIR.glob("steer-*.md")):
        new, changed = stamp(path, version)
        if not changed:
            continue
        if args.check:
            stale.append(path.name)
        else:
            path.write_text(new, encoding="utf-8")
            written += 1

    if args.check:
        if stale:
            print(
                f"gen_rule_banners: {len(stale)} rule banner(s) out of sync with their "
                f"content — run 'mise run gen:rule-banners'.\n  - " + "\n  - ".join(stale),
                file=sys.stderr,
            )
            return 1
        print("gen_rule_banners: OK")
        return 0

    print(f"gen_rule_banners: stamped {written} rule(s) at v{version}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Keep the SHIPPED workflow templates' action pins current.

``plugins/steer/templates/github/workflows/*.yml`` SHA-pin every ``uses:`` with
the tag in a trailing comment. Dependabot cannot maintain those pins: its
``github-actions`` ecosystem only scans ``/.github/workflows`` and a root
``action.yml``, and the ``directory`` key has no escape hatch for a templates
tree (#548). A consumer repo self-heals - once installed, its own shipped
``dependabot.yml`` covers ``.github/workflows/`` - so what rots is the *initial*
pin a freshly bootstrapped repo receives.

This script closes that window: it resolves each pinned tag's successor upstream,
rewrites the pin **bump-up only**, and reports what moved.
``template-pin-refresh.yml`` runs it weekly and opens one human-reviewed PR, the
same shape as ``version-policy-refresh.yml`` for the EOL floors. Nothing enforces
pins at build time; a stale pin is not a failure, it is a PR waiting to be opened.

Run from the repo root::

    uv run python scripts/refresh_template_pins.py            # report only
    uv run python scripts/refresh_template_pins.py --write    # rewrite the pins

Exit status: 0 pins current, 1 bumps found (and applied under ``--write``),
2 a lookup failed - never a silent no-op, since "no bumps" and "could not ask"
must not look the same.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from collections.abc import Callable
from pathlib import Path

WORKFLOWS = Path("plugins/steer/templates/github/workflows")

# `uses: owner/repo@<40-hex> # ... vX.Y.Z` - the trailing comment may carry a
# zizmor suppression before the version (`# zizmor: ignore[artipacked] - v7.0.1`),
# so the version is matched at the end rather than right after the `#`.
PIN = re.compile(
    r"(?P<head>uses:\s*)(?P<action>[\w.-]+/[\w.-]+)@(?P<sha>[0-9a-f]{40})"
    r"(?P<comment>\s*#[^\n]*?)(?P<ver>v\d+\.\d+\.\d+)(?P<tail>\s*)$"
)

Fetch = Callable[[str], object]


def gh_api(path: str) -> object:
    """Read the GitHub REST API through ``gh``, so the caller inherits its auth."""
    out = subprocess.run(["gh", "api", path], capture_output=True, text=True, check=False)
    if out.returncode != 0:
        raise LookupError(f"gh api {path}: {out.stderr.strip()}")
    return json.loads(out.stdout)


def _semver(tag: str) -> tuple[int, ...] | None:
    m = re.fullmatch(r"v(\d+)\.(\d+)\.(\d+)", tag)
    return tuple(int(g) for g in m.groups()) if m else None


def latest_release(action: str, fetch: Fetch = gh_api) -> str:
    """The newest fully-qualified ``vX.Y.Z`` release tag for ``action``.

    Deliberately NOT ``releases/latest``: several actions publish a moving major
    tag, and ``anthropics/claude-code-action`` returns ``v1`` there - a tag whose
    commit changes under a pin, which is the whole thing SHA-pinning prevents.
    """
    releases = fetch(f"repos/{action}/releases?per_page=100")
    if not isinstance(releases, list):
        raise LookupError(f"{action}: unexpected releases payload")
    tags = [
        t
        for r in releases
        if not r.get("draft") and not r.get("prerelease") and (t := _semver(str(r.get("tag_name"))))
    ]
    if not tags:
        raise LookupError(f"{action}: no vX.Y.Z release found")
    best = max(tags)
    return "v" + ".".join(str(p) for p in best)


def tag_commit(action: str, tag: str, fetch: Fetch = gh_api) -> str:
    """The commit a tag points at, dereferencing an annotated tag object."""
    ref = fetch(f"repos/{action}/git/ref/tags/{tag}")
    if not isinstance(ref, dict):
        raise LookupError(f"{action}@{tag}: unexpected ref payload")
    obj = ref["object"]
    if obj["type"] == "tag":
        annotated = fetch(f"repos/{action}/git/tags/{obj['sha']}")
        if not isinstance(annotated, dict):
            raise LookupError(f"{action}@{tag}: unexpected tag payload")
        return str(annotated["object"]["sha"])
    return str(obj["sha"])


def refresh(
    workflows: Path = WORKFLOWS, *, write: bool = False, fetch: Fetch = gh_api
) -> tuple[list[str], list[str]]:
    """Return (bumps, failures) as report lines, rewriting the files under ``write``."""
    bumps: list[str] = []
    failures: list[str] = []
    resolved: dict[str, tuple[str, str]] = {}
    for path in sorted(workflows.glob("*.yml")):
        text = path.read_text(encoding="utf-8")
        out_lines = []
        changed = False
        for line in text.splitlines(keepends=True):
            m = PIN.search(line.rstrip("\n"))
            if m is None:
                out_lines.append(line)
                continue
            action, cur_ver, cur_sha = m["action"], m["ver"], m["sha"]
            if action not in resolved:
                try:
                    tag = latest_release(action, fetch)
                    resolved[action] = (tag, tag_commit(action, tag, fetch))
                except (LookupError, KeyError, TypeError) as exc:
                    failures.append(f"{path.name}: {action} - {exc}")
                    out_lines.append(line)
                    continue
            tag, sha = resolved[action]
            cur, new = _semver(cur_ver), _semver(tag)
            # Bump-up only: a pin ahead of the newest release is a deliberate
            # pick (a pre-release, an unreleased fix), never something to undo.
            if cur is None or new is None or new <= cur or sha == cur_sha:
                out_lines.append(line)
                continue
            bumps.append(f"- {path.name}: {action} {cur_ver} -> {tag}")
            out_lines.append(
                line.replace(f"{action}@{cur_sha}", f"{action}@{sha}").replace(
                    f"{m['comment']}{cur_ver}", f"{m['comment']}{tag}"
                )
            )
            changed = True
        if changed and write:
            path.write_text("".join(out_lines), encoding="utf-8")
    return bumps, failures


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Refresh the shipped templates' action pins.")
    parser.add_argument("--write", action="store_true", help="Rewrite the pins in place.")
    parser.add_argument("--workflows", type=Path, default=WORKFLOWS)
    args = parser.parse_args(argv)

    if not args.workflows.is_dir():
        print(f"refresh_template_pins: not a directory: {args.workflows}", file=sys.stderr)
        return 2

    bumps, failures = refresh(args.workflows, write=args.write)
    for line in failures:
        print(f"refresh_template_pins: lookup failed: {line}", file=sys.stderr)
    if failures:
        return 2
    if not bumps:
        print("refresh_template_pins: pins current")
        return 0
    print("refresh_template_pins: " + ("applied" if args.write else "available") + ":")
    for line in bumps:
        print(line)
    return 1


if __name__ == "__main__":
    sys.exit(main())

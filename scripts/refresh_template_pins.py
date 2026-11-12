#!/usr/bin/env python3
"""Keep the SHIPPED workflow templates' action tags and gh-actions-lock pin current.

``plugins/steer/templates/github/workflows/*.yml`` reference every action by an
exact ``vX.Y.Z`` tag; each consumer repo locks the commit in its own
``actions.lock``. Dependabot cannot maintain the templates: its
``github-actions`` ecosystem only scans ``/.github/workflows`` and a root
``action.yml`` (#548). A consumer self-heals once installed - its Dependabot
bumps the tag and regenerates the lock entry - so what rots is the *initial*
tag a freshly bootstrapped repo receives. The same holds for the pinned
``gh-actions-lock`` extension version in ``EXTENSION_PINS``.

This script resolves each tag's successor upstream, rewrites it **bump-up
only**, and reports what moved. ``template-pin-refresh.yml`` runs it weekly and
opens one human-reviewed PR, the same shape as ``version-policy-refresh.yml``
for the EOL floors. A stale tag is not a failure, it is a PR waiting to be opened.

Run from the repo root::

    uv run python scripts/refresh_template_pins.py            # report only
    uv run python scripts/refresh_template_pins.py --write    # rewrite the tags

Exit status: 0 current, 1 bumps found (and applied under ``--write``), 2 a
lookup failed - never a silent no-op, since "no bumps" and "could not ask" must
not look the same.
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
LOCK_EXTENSION = "github/gh-actions-lock"
EXTENSION_PINS = (
    Path("plugins/steer/templates/scaffold/scripts/ci-lib.sh"),
    Path("plugins/steer/scripts/lock-workflows.sh"),
)

# `uses: owner/repo@vX.Y.Z`, optionally quoted, with any trailing comment.
PIN = re.compile(r"uses:\s*[\"']?(?P<action>[\w.-]+/[\w.-]+)@(?P<ver>v\d+\.\d+\.\d+)\b")
EXTENSION_PIN = re.compile(r"^STEER_ACTIONS_LOCK_VERSION=(?P<ver>v\d+\.\d+\.\d+)$", re.MULTILINE)

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
    commit moves between installs, which is what an exact tag prevents.
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


def _bump(
    action: str, cur_ver: str, where: str, resolved: dict[str, str], fetch: Fetch
) -> tuple[str | None, str | None]:
    """(new tag or None, failure line or None) for one occurrence."""
    if action not in resolved:
        try:
            resolved[action] = latest_release(action, fetch)
        except (LookupError, KeyError, TypeError) as exc:
            return None, f"{where}: {action} - {exc}"
    tag = resolved[action]
    cur, new = _semver(cur_ver), _semver(tag)
    # Bump-up only: a tag ahead of the newest release is a deliberate pick (a
    # pre-release, an unreleased fix), never something to undo.
    if cur is None or new is None or new <= cur:
        return None, None
    return tag, None


def refresh(
    workflows: Path = WORKFLOWS,
    *,
    write: bool = False,
    fetch: Fetch = gh_api,
    extension_pins: tuple[Path, ...] = EXTENSION_PINS,
) -> tuple[list[str], list[str]]:
    """Return (bumps, failures) as report lines, rewriting the files under ``write``."""
    bumps: list[str] = []
    failures: list[str] = []
    resolved: dict[str, str] = {}
    targets = [(p, PIN, None) for p in sorted(workflows.glob("*.yml"))]
    targets += [(p, EXTENSION_PIN, LOCK_EXTENSION) for p in extension_pins]
    for path, pattern, fixed_action in targets:
        text = path.read_text(encoding="utf-8")

        def sub(m: re.Match[str], path: Path = path, fixed: str | None = fixed_action) -> str:
            action = fixed or m["action"]
            tag, failure = _bump(action, m["ver"], path.name, resolved, fetch)
            if failure:
                failures.append(failure)
            if tag is None:
                return m[0]
            bumps.append(f"- {path.name}: {action} {m['ver']} -> {tag}")
            return m[0].replace(m["ver"], tag)

        new_text = pattern.sub(sub, text)
        if write and new_text != text:
            path.write_text(new_text, encoding="utf-8")
    return bumps, failures


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Refresh the shipped templates' action tags.")
    parser.add_argument("--write", action="store_true", help="Rewrite the tags in place.")
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

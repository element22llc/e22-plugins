#!/usr/bin/env python3
"""Keep the pins this repo ships current: action tags, gh-actions-lock, Semgrep, re-listed plugins.

``plugins/steer/templates/github/workflows/*.yml`` reference every action by an
exact ``vX.Y.Z`` tag; each consumer repo locks the commit in its own
``actions.lock``. Dependabot cannot maintain the templates: its
``github-actions`` ecosystem only scans ``/.github/workflows`` and a root
``action.yml`` (#548). A consumer self-heals once installed - its Dependabot
bumps the tag and regenerates the lock entry - so what rots is the *initial*
tag a freshly bootstrapped repo receives. The same holds for the pinned
``gh-actions-lock`` extension version in ``EXTENSION_PINS``.

The scaffold's ``ci-security.sh`` runs Semgrep through ``uvx`` at
``STEER_SEMGREP_VERSION``, its transitive deps bounded by the
``STEER_SEMGREP_EXCLUDE_NEWER`` date on the next line. No Dependabot sees a
shell variable, so unlike an action tag this pin never self-heals in a
consumer: only a freshly bootstrapped repo gets the refreshed one. The pair
moves together, to the newest PyPI release past the scaffold Dependabot's
7-day cooldown and a date 7 days before the refresh; with no newer release
past it, neither line moves.

``.claude-plugin/marketplace.json`` re-lists upstream plugins through
``git-subdir`` sources pinned to a SHA, which nothing else watches. Each such
pin moves to the newest commit touching its path; a path that is gone upstream,
or a pin that upstream history no longer contains, is a lookup failure. A source
with no ``sha`` pins nothing and is skipped.

This script resolves each pin's successor upstream, rewrites it **bump-up
only**, and reports what moved. ``template-pin-refresh.yml`` runs it weekly and
opens one human-reviewed PR, the same shape as ``version-policy-refresh.yml``
for the EOL floors. A stale pin is not a failure, it is a PR waiting to be opened.

Run from the repo root::

    uv run python scripts/refresh_template_pins.py            # report only
    uv run python scripts/refresh_template_pins.py --write    # rewrite the pins

Exit status: 0 current, 1 bumps found (and applied under ``--write``), 2 a
lookup failed - never a silent no-op, since "no bumps" and "could not ask" must
not look the same.
"""

from __future__ import annotations

import argparse
import http.client
import json
import re
import subprocess
import sys
import urllib.request
from collections.abc import Callable
from datetime import UTC, date, datetime, time, timedelta
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

SECURITY_SCRIPT = Path("plugins/steer/templates/scaffold/scripts/ci-security.sh")
SEMGREP_PIN = re.compile(
    r"^STEER_SEMGREP_VERSION=(?P<ver>\d+\.\d+\.\d+)\n"
    r"STEER_SEMGREP_EXCLUDE_NEWER=(?P<date>\d{4}-\d{2}-\d{2})$",
    re.MULTILINE,
)
# An sdist or wheel of a final release; pre, post and dev releases never match.
SEMGREP_FILE = re.compile(r"semgrep-(?P<ver>\d+\.\d+\.\d+)(?:-|\.tar\.gz$)")
COOLDOWN = timedelta(days=7)
# uv reads a bare --exclude-newer date in the local timezone (end of day on uv
# 0.11, start of day on older releases), so on a UTC+14 machine the date can
# start 14h before its UTC midnight. A pin uploaded after that instant would
# not resolve there.
EARLIEST_OFFSET = timedelta(hours=14)

MARKETPLACE = Path(".claude-plugin/marketplace.json")
# A source object holds no nested braces, so the match is the span one sha
# rewrite stays inside - two entries sharing a sha are rewritten independently.
SUBDIR_SOURCE = re.compile(r'\{[^{}]*"source"\s*:\s*"git-subdir"[^{}]*\}')
FULL_SHA = re.compile(r"[0-9a-f]{40}")
GITHUB_URL = re.compile(r"https://github\.com/(?P<slug>[\w.-]+/[\w.-]+?)(?:\.git)?/?$")

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


def _subdir_bump(src: dict[str, object], fetch: Fetch) -> tuple[str, str | None, str | None]:
    """(owner/repo, new sha or None, failure line or None) for one ``git-subdir`` source."""
    url, path, sha = src.get("url"), src.get("path"), src.get("sha")
    if sha is None:
        return "", None, None
    if not (isinstance(url, str) and isinstance(path, str) and path and isinstance(sha, str)):
        return "", None, f"malformed git-subdir source: {json.dumps(src)}"
    if not FULL_SHA.fullmatch(sha):
        return "", None, f"{url}: pin {sha!r} is not a full commit SHA"
    m = GITHUB_URL.match(url)
    if not m:
        return "", None, f"{url}: not a github.com URL, cannot be watched"
    slug = m["slug"]
    try:
        # The newest commit touching a deleted path is its deletion, so the
        # path must still exist before that commit can be a bump target.
        fetch(f"repos/{slug}/contents/{path}")
        commits = fetch(f"repos/{slug}/commits?path={path}&per_page=1")
        if not (isinstance(commits, list) and commits and isinstance(commits[0], dict)):
            raise LookupError("unexpected commits payload")
        newest = str(commits[0]["sha"])
        if not FULL_SHA.fullmatch(newest):
            raise LookupError("unexpected commits payload")
        if newest == sha:
            return slug, None, None
        compared = fetch(f"repos/{slug}/compare/{sha}...{newest}")
        if not isinstance(compared, dict):
            raise LookupError("unexpected compare payload")
        status = compared["status"]
    except (LookupError, KeyError) as exc:
        return slug, None, f"{slug}/{path} - {exc}"
    if status == "ahead":
        return slug, newest, None
    # Bump-up only: `behind` is a pin on a later commit that left the path alone.
    if status == "behind":
        return slug, None, None
    return slug, None, f"{slug}/{path} - pin {sha[:7]} is {status} from upstream {newest[:7]}"


def refresh_marketplace(
    manifest: Path = MARKETPLACE, *, write: bool = False, fetch: Fetch = gh_api
) -> tuple[list[str], list[str]]:
    """Return (bumps, failures) for the manifest's ``git-subdir`` SHA pins."""
    bumps: list[str] = []
    failures: list[str] = []
    text = manifest.read_text(encoding="utf-8")

    def sub(m: re.Match[str]) -> str:
        src = json.loads(m[0])
        slug, new, failure = _subdir_bump(src, fetch)
        if failure:
            failures.append(f"{manifest.name}: {failure}")
        if new is None:
            return m[0]
        old = src["sha"]
        bumps.append(f"- {manifest.name}: {slug}/{src['path']} {old[:7]} -> {new[:7]}")
        bumps.append(f"  review: https://github.com/{slug}/commits/{new}/{src['path']}")
        return m[0].replace(old, new)

    new_text = SUBDIR_SOURCE.sub(sub, text)
    if write and new_text != text:
        manifest.write_text(new_text, encoding="utf-8")
    return bumps, failures


def pypi_simple(package: str) -> object:
    """Read ``package``'s PyPI Simple JSON index (PEP 691): every file, its upload time, yanked."""
    request = urllib.request.Request(
        f"https://pypi.org/simple/{package}/",
        headers={"Accept": "application/vnd.pypi.simple.v1+json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as resp:
            return json.loads(resp.read())
    except (OSError, ValueError, http.client.HTTPException) as exc:
        raise LookupError(f"pypi.org/simple/{package}: {exc}") from exc


def _numeric(ver: str) -> tuple[int, ...]:
    return tuple(int(p) for p in ver.split("."))


def _newest_cooled(index: object, current: str, cutoff: datetime) -> str | None:
    """The newest release above ``current`` whose every file predates ``cutoff``, if any."""
    if not isinstance(index, dict):
        raise LookupError("unexpected index payload")
    latest: dict[str, datetime] = {}
    yanked: set[str] = set()
    for f in index["files"]:
        m = SEMGREP_FILE.match(f["filename"])
        # Only releases that could be a bump are parsed, so one malformed old
        # entry upstream cannot fail every run.
        if not m or _numeric(m["ver"]) <= _numeric(current):
            continue
        ver = m["ver"]
        if f.get("yanked"):
            yanked.add(ver)
        uploaded = datetime.fromisoformat(f["upload-time"])
        latest[ver] = max(uploaded, latest.get(ver, uploaded))
    cooled = [v for v, at in latest.items() if v not in yanked and at < cutoff]
    return max(cooled, key=_numeric) if cooled else None


def refresh_semgrep(
    script: Path = SECURITY_SCRIPT,
    *,
    write: bool = False,
    now: datetime,
    fetch: Fetch = pypi_simple,
) -> tuple[list[str], list[str]]:
    """Return (bumps, failures) for the Semgrep version + exclude-newer pair."""
    text = script.read_text(encoding="utf-8")
    m = SEMGREP_PIN.search(text)
    if not m:
        return [], [f"{script.name}: no adjacent STEER_SEMGREP_VERSION / _EXCLUDE_NEWER pins"]
    day = (now.astimezone(UTC) - COOLDOWN).date()
    cutoff = datetime.combine(day, time(), UTC) - EARLIEST_OFFSET
    try:
        old_date = date.fromisoformat(m["date"])
        newest = _newest_cooled(fetch("semgrep"), m["ver"], cutoff)
    except (LookupError, KeyError, TypeError, ValueError, AttributeError) as exc:
        return [], [f"{script.name}: semgrep - {exc}"]
    if newest is None:
        return [], []
    # Bump-up only, like every other pin: a later hand-set date stays.
    new_date = max(old_date, day).isoformat()
    pair = f"STEER_SEMGREP_VERSION={newest}\nSTEER_SEMGREP_EXCLUDE_NEWER={new_date}"
    if write:
        script.write_text(text[: m.start()] + pair + text[m.end() :], encoding="utf-8")
    return [
        f"- {script.name}: semgrep {m['ver']} -> {newest}, exclude-newer {m['date']} -> {new_date}"
    ], []


def main(
    argv: list[str] | None = None,
    fetch: Fetch = gh_api,
    pypi: Fetch = pypi_simple,
    now: datetime | None = None,
) -> int:
    parser = argparse.ArgumentParser(description="Refresh the pins this repo ships.")
    parser.add_argument("--write", action="store_true", help="Rewrite the pins in place.")
    parser.add_argument("--workflows", type=Path, default=WORKFLOWS)
    parser.add_argument("--marketplace", type=Path, default=MARKETPLACE)
    parser.add_argument("--security-script", type=Path, default=SECURITY_SCRIPT)
    args = parser.parse_args(argv)

    if not args.workflows.is_dir():
        print(f"refresh_template_pins: not a directory: {args.workflows}", file=sys.stderr)
        return 2
    if not args.marketplace.is_file():
        print(f"refresh_template_pins: not a file: {args.marketplace}", file=sys.stderr)
        return 2
    if not args.security_script.is_file():
        print(f"refresh_template_pins: not a file: {args.security_script}", file=sys.stderr)
        return 2

    bumps, failures = refresh(args.workflows, write=args.write, fetch=fetch)
    plugin_bumps, plugin_failures = refresh_marketplace(
        args.marketplace, write=args.write, fetch=fetch
    )
    semgrep_bumps, semgrep_failures = refresh_semgrep(
        args.security_script, write=args.write, now=now or datetime.now(UTC), fetch=pypi
    )
    bumps += plugin_bumps + semgrep_bumps
    failures += plugin_failures + semgrep_failures
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

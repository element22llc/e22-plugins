#!/usr/bin/env python3
"""Computed pre-release preconditions for the steer release path.

``PRE-RELEASE-AUDIT.md`` Steps 1, 2 (the CI-status half) and 4b are mechanical:
is the tree clean, is the base current, is there anything to release, where is
the last release, does the live docs site match ``main``, did the upstream
validator-compat job pass, is anything untriaged sitting in the ledger. Until
now the release skills *recalled* those checks from prose and read ``gh run
list`` tables by eye -- which is how a piped exit status, a stale anchor, and a
cancelled docs deploy each slipped through once.

This script computes them. It is what the release skills inject at invocation
(``!`uv run python scripts/release_preflight.py --report``` -- dynamic context
injection, so the skill body arrives with the facts inlined), and what
``/audit-loop`` runs at the top of every round. Severity markers follow the
audit's vocabulary: ``[blocker]`` halts a cut, ``[high]`` is reported and never
halts, ``[warn]`` means "not verified here -- close the loop by hand".

Usage::

    uv run python scripts/release_preflight.py                  # gate: exit 1 on blockers
    uv run python scripts/release_preflight.py --report          # always exit 0 (for injection)
    uv run python scripts/release_preflight.py --caller audit-loop --no-fetch --json

The GitHub checks go through ``gh``; when it is missing or unauthenticated they
degrade to ``[warn]`` rather than pretending to pass. Stdlib only.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "scripts"))

CHANGELOG = REPO_ROOT / "CHANGELOG.md"
PLUGIN_JSON = REPO_ROOT / "plugins/steer/.claude-plugin/plugin.json"
COPILOT_PLUGIN_JSON = REPO_ROOT / "plugins/steer/.github/plugin/plugin.json"
COPILOT_MARKETPLACE = REPO_ROOT / ".github/plugin/marketplace.json"
LEDGER = REPO_ROOT / ".claude/audit/findings.jsonl"

SEVERITY_ORDER = ("blocker", "high", "warn", "info", "ok")
CALLERS = ("release", "quick-release", "audit-loop")
GH_TIMEOUT = 30


@dataclass
class Check:
    id: str
    status: str  # one of SEVERITY_ORDER
    detail: str


def _git(*args: str, check: bool = False) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", *args], capture_output=True, text=True, check=check, cwd=REPO_ROOT
    )


def _gh_json(args: list[str]) -> list | dict | None:
    """Run a ``gh`` command that emits JSON; ``None`` when gh is unusable."""
    try:
        out = subprocess.run(
            ["gh", *args],
            capture_output=True,
            text=True,
            check=False,
            cwd=REPO_ROOT,
            timeout=GH_TIMEOUT,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None
    if out.returncode != 0 or not out.stdout.strip():
        return None
    try:
        return json.loads(out.stdout)
    except json.JSONDecodeError:
        return None


# --- pure helpers (unit-tested) ---------------------------------------------


def count_unreleased_bullets(changelog: str) -> int | None:
    """Top-level bullets under the ``### [Unreleased]`` heading of ``## steer``.

    ``None`` when the heading is missing -- a malformed changelog, distinct from
    an empty one.
    """
    in_steer = in_block = False
    found = False
    n = 0
    for line in changelog.splitlines():
        if line.startswith("## "):
            in_steer = line.strip() == "## steer"
            in_block = False
            continue
        if not in_steer:
            continue
        if line.startswith("### "):
            in_block = line.strip() == "### [Unreleased]"
            found = found or in_block
            continue
        if in_block and line.startswith("- "):
            n += 1
    return n if found else None


def docs_freshness(runs: list[dict], docs_head: str | None, is_ancestor) -> Check:
    """Interpret ``gh run list`` rows for ``docs-deploy.yml`` on ``main``.

    ``runs`` is newest-first. The latest completed run must have succeeded, and
    the newest commit touching ``docs/``/``mkdocs.yml`` on ``origin/main`` must
    be reachable from that run's head -- otherwise the live site lags ``main``.
    ``is_ancestor(a, b)`` answers "is commit a an ancestor of (or equal to) b".
    """
    if not runs:
        return Check("docs-deploy", "warn", "no docs-deploy runs found on main")
    latest = runs[0]
    if latest.get("status") != "completed":
        return Check(
            "docs-deploy",
            "warn",
            f"latest docs-deploy run {latest.get('databaseId')} is {latest.get('status')}; "
            "wait for it before releasing",
        )
    if latest.get("conclusion") != "success":
        return Check(
            "docs-deploy",
            "blocker",
            f"deployed docs stale: last docs-deploy on main {latest.get('conclusion')} "
            f"(run {latest.get('databaseId')}) -- re-run it and let it go green",
        )
    if docs_head and latest.get("headSha") and not is_ancestor(docs_head, latest["headSha"]):
        return Check(
            "docs-deploy",
            "blocker",
            f"deployed docs stale: docs commit {docs_head[:10]} on origin/main is newer than "
            f"the last successful deploy ({latest['headSha'][:10]})",
        )
    return Check("docs-deploy", "ok", f"live site reflects main (run {latest.get('databaseId')})")


def validator_compat(jobs: list[dict] | None) -> Check:
    """Interpret the job list of the latest ``plugin-quality.yml`` run on ``main``."""
    if jobs is None:
        return Check("validator-compat", "warn", "validator-compat not verified (gh unavailable)")
    job = next((j for j in jobs if j.get("name") == "validator-compat"), None)
    if job is None:
        return Check("validator-compat", "warn", "no validator-compat job in the latest run")
    if job.get("conclusion") == "success":
        return Check("validator-compat", "ok", "plugin validates against latest Claude Code")
    return Check(
        "validator-compat",
        "high",
        f"validator-compat is {job.get('conclusion')} on main -- the plugin may not validate "
        "against latest Claude Code; ship only deliberately",
    )


def worst(checks: list[Check]) -> str:
    return min((c.status for c in checks), key=SEVERITY_ORDER.index, default="ok")


def render(checks: list[Check], anchor: str | None) -> str:
    width = max(len(c.id) for c in checks)
    lines = [f"[{c.status}] {c.id:<{width}}  {c.detail}" for c in checks]
    counts = {s: sum(1 for c in checks if c.status == s) for s in SEVERITY_ORDER}
    lines.append("")
    lines.append(
        "preflight: "
        + ", ".join(f"{counts[s]} {s}" for s in ("blocker", "high", "warn"))
        + f"; worst = {worst(checks)}"
    )
    if anchor:
        lines.append(f"LAST_RELEASE={anchor}")
    return "\n".join(lines)


# --- checks -------------------------------------------------------------------


def check_tree() -> Check:
    out = _git("status", "--porcelain").stdout.strip()
    if out:
        n = len(out.splitlines())
        return Check("tree-clean", "blocker", f"{n} uncommitted path(s) -- commit or stash first")
    return Check("tree-clean", "ok", "working tree clean")


def check_base(fetch: bool, caller: str) -> Check:
    if fetch:
        f = _git("fetch", "origin", "main", "--quiet")
        if f.returncode != 0:
            return Check("base-current", "warn", "git fetch origin main failed; base not verified")
    if _git("rev-parse", "--verify", "--quiet", "origin/main").returncode != 0:
        return Check("base-current", "warn", "origin/main not available locally")
    behind = int(_git("rev-list", "--count", "HEAD..origin/main").stdout.strip() or 0)
    ahead = int(_git("rev-list", "--count", "origin/main..HEAD").stdout.strip() or 0)
    branch = _git("rev-parse", "--abbrev-ref", "HEAD").stdout.strip()
    if behind:
        return Check(
            "base-current", "blocker", f"{branch} is {behind} commit(s) behind origin/main"
        )
    if ahead and caller != "audit-loop":
        return Check(
            "base-current",
            "blocker",
            f"{branch} is {ahead} commit(s) ahead of origin/main -- a release is cut from main",
        )
    note = f" ({ahead} ahead, expected for a fix branch)" if ahead else ""
    return Check("base-current", "ok", f"{branch} is current with origin/main{note}")


def check_unreleased(caller: str) -> Check:
    n = count_unreleased_bullets(CHANGELOG.read_text(encoding="utf-8"))
    if n is None:
        return Check(
            "unreleased", "blocker", "CHANGELOG.md has no '### [Unreleased]' under '## steer'"
        )
    if n == 0:
        status = "info" if caller == "audit-loop" else "blocker"
        return Check("unreleased", status, "no [Unreleased] bullets -- nothing to release")
    return Check("unreleased", "ok", f"{n} [Unreleased] bullet(s)")


def check_manifests() -> Check:
    try:
        versions = {
            "plugin.json": json.loads(PLUGIN_JSON.read_text(encoding="utf-8")).get("version"),
            "copilot plugin.json": json.loads(COPILOT_PLUGIN_JSON.read_text(encoding="utf-8")).get(
                "version"
            ),
            "copilot marketplace": next(
                (
                    p.get("version")
                    for p in json.loads(COPILOT_MARKETPLACE.read_text(encoding="utf-8")).get(
                        "plugins", []
                    )
                    if p.get("name") == "steer"
                ),
                None,
            ),
        }
    except (OSError, json.JSONDecodeError) as exc:
        return Check("manifests", "blocker", f"manifest unreadable: {exc}")
    if len(set(versions.values())) != 1:
        return Check(
            "manifests",
            "blocker",
            "version drift: " + ", ".join(f"{k}={v}" for k, v in versions.items()),
        )
    return Check("manifests", "ok", f"all three manifests at {versions['plugin.json']}")


def resolve_anchor() -> tuple[str | None, Check]:
    """``$LAST_RELEASE``: the ``vX.Y.Z`` tag for plugin.json's version, else a fallback."""
    version = json.loads(PLUGIN_JSON.read_text(encoding="utf-8")).get("version", "")
    tag = f"v{version}"
    if _git("rev-parse", "--verify", "--quiet", f"refs/tags/{tag}").returncode == 0:
        sha = _git("rev-list", "-n", "1", tag).stdout.strip()
        return tag, Check("last-release", "ok", f"{tag} @ {sha[:10]}")
    # No tag for the current version: release-publish did not fire, or tags
    # were never fetched. Either way the anchor is degraded, and the audit's
    # delta would be wrong if this went unnoticed.
    _git("fetch", "origin", "--tags", "--quiet")
    if _git("rev-parse", "--verify", "--quiet", f"refs/tags/{tag}").returncode == 0:
        sha = _git("rev-list", "-n", "1", tag).stdout.strip()
        return tag, Check("last-release", "ok", f"{tag} @ {sha[:10]} (fetched)")
    described = _git("describe", "--tags", "--match", "v*", "--abbrev=0").stdout.strip()
    fallback = _git("log", "-1", "--format=%H", "--grep=^chore(release):").stdout.strip()
    anchor = described or fallback or None
    if anchor is None:
        return None, Check("last-release", "high", f"no {tag} tag and no release commit found")
    return anchor, Check(
        "last-release",
        "high",
        f"no {tag} tag for the current plugin version -- release-publish.yml may not have "
        f"fired; anchoring on {anchor[:12]} instead (re-run: gh workflow run "
        f"release-publish.yml -f version={version})",
    )


def check_delta(anchor: str | None) -> Check:
    if anchor is None:
        return Check("delta", "warn", "no anchor; delta-scoped dimensions cannot be bounded")
    files = [
        ln
        for ln in _git("diff", "--name-only", f"{anchor}..HEAD").stdout.splitlines()
        if ln.strip()
    ]
    try:
        from audit_severity import RELEASE_CRITICAL, SEVERITIES, ceiling  # noqa: PLC0415

        worst_ceiling = min((ceiling(p) for p in files), key=SEVERITIES.index, default="none")
        critical = sorted(p for p in files if p in RELEASE_CRITICAL)
    except Exception as exc:  # noqa: BLE001 -- the ceiling is advisory here
        worst_ceiling, critical = f"unknown ({exc})", []
    note = f"; release-critical touched: {', '.join(critical)}" if critical else ""
    return Check(
        "delta", "info", f"{len(files)} path(s) since {anchor}; worst ceiling {worst_ceiling}{note}"
    )


def check_ledger() -> Check:
    try:
        from audit_ledger import load  # noqa: PLC0415
    except ImportError:
        return Check("ledger", "warn", "audit_ledger unavailable")
    rows = load(LEDGER)
    open_rows = [r for r in rows.values() if r.get("state") == "open"]
    blockers = [r for r in open_rows if r.get("severity") == "blocker"]
    if blockers:
        return Check("ledger", "blocker", f"{len(blockers)} untriaged blocker(s) in the ledger")
    return Check("ledger", "ok", f"no untriaged blockers ({len(open_rows)} open below the gate)")


def check_docs_deploy() -> Check:
    runs = _gh_json(
        [
            "run",
            "list",
            "--workflow=docs-deploy.yml",
            "--branch",
            "main",
            "--limit",
            "5",
            "--json",
            "conclusion,headSha,status,databaseId",
        ]
    )
    if runs is None:
        return Check(
            "docs-deploy",
            "warn",
            "deployed-docs freshness not verified -- run: gh run list --workflow=docs-deploy.yml "
            "--branch main",
        )
    docs_head = _git("log", "-1", "--format=%H", "origin/main", "--", "docs", "mkdocs.yml")
    head = docs_head.stdout.strip() or None

    def is_ancestor(a: str, b: str) -> bool:
        return _git("merge-base", "--is-ancestor", a, b).returncode == 0

    return docs_freshness(runs if isinstance(runs, list) else [], head, is_ancestor)


def check_validator_compat() -> Check:
    runs = _gh_json(
        [
            "run",
            "list",
            "--workflow=plugin-quality.yml",
            "--branch",
            "main",
            "--limit",
            "1",
            "--json",
            "databaseId",
        ]
    )
    if not runs or not isinstance(runs, list):
        return validator_compat(None)
    run = _gh_json(["run", "view", str(runs[0]["databaseId"]), "--json", "jobs"])
    if not isinstance(run, dict):
        return validator_compat(None)
    return validator_compat(run.get("jobs", []))


def run_all(caller: str, fetch: bool, offline: bool) -> tuple[list[Check], str | None]:
    checks = [check_tree(), check_base(fetch, caller), check_unreleased(caller), check_manifests()]
    anchor, anchor_check = resolve_anchor()
    checks += [anchor_check, check_delta(anchor), check_ledger()]
    if offline:
        checks += [
            Check("docs-deploy", "warn", "skipped (--offline)"),
            Check("validator-compat", "warn", "skipped (--offline)"),
        ]
    else:
        checks += [check_docs_deploy(), check_validator_compat()]
    return checks, anchor


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--caller", choices=CALLERS, default="release")
    parser.add_argument("--report", action="store_true", help="always exit 0 (skill injection)")
    parser.add_argument("--no-fetch", action="store_true", help="do not git fetch origin main")
    parser.add_argument("--offline", action="store_true", help="skip the gh-backed checks")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)

    checks, anchor = run_all(args.caller, fetch=not args.no_fetch, offline=args.offline)
    if args.json:
        print(json.dumps({"checks": [asdict(c) for c in checks], "anchor": anchor}, indent=2))
    else:
        print(render(checks, anchor))
    if args.report:
        return 0
    return 1 if worst(checks) == "blocker" else 0


if __name__ == "__main__":
    sys.exit(main())

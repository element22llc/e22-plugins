#!/usr/bin/env python3
"""Computed pre-release preconditions for the steer release path.

``PRE-RELEASE-AUDIT.md`` Steps 1, 2 (the CI-status half) and 4b are mechanical:
is the tree clean, is the base current, is there anything to release, where is
the last release, does the live docs site match ``main``, did the upstream
validator-compat job pass, is anything untriaged sitting in the ledger, does
the newest routing-eval sweep cover this candidate and did it hold, how much
judgment review does this delta need. Until
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
    uv run python scripts/release_preflight.py --plan [--full]  # pre-release-audit workflow args

The GitHub checks go through ``gh``; when it is missing or unauthenticated they
degrade to ``[warn]`` rather than pretending to pass. Stdlib only, apart from
the generator constants ``generated_mirrors`` borrows.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "scripts"))

CHANGELOG = REPO_ROOT / "CHANGELOG.md"
UNRELEASED_DIR = REPO_ROOT / ".changes/unreleased"
PLUGIN_JSON = REPO_ROOT / "plugins/steer/.claude-plugin/plugin.json"
COPILOT_PLUGIN_JSON = REPO_ROOT / "plugins/steer/.github/plugin/plugin.json"
COPILOT_MARKETPLACE = REPO_ROOT / ".github/plugin/marketplace.json"
LEDGER = REPO_ROOT / ".claude/audit/findings.jsonl"
EVAL_LEDGER = REPO_ROOT / "plugins/steer/evals/ledger.jsonl"
# Between the two scores one bad run in three produces: 0.87 lost the `answer`
# grader and still routed, 0.8 lost `routed`.
EVAL_FLOOR = 0.85
EVAL_RECHECK = "mise run evals -- --case <name> --runs 6"

ROUTER_RULE = "plugins/steer/rules/00-router.md"
SKILL_MD = re.compile(r"^plugins/steer/skills/([^/]+)/SKILL\.md$")
# An estimate of what one reviewer holds in a single context, not a natural
# break. Replayed over the 25 cuts v7.5.0-v7.27.0 it makes eight light (the
# largest 18 paths / 392 lines) and seventeen full (the smallest 21 / 302).
LIGHT_MAX_PATHS = 20
LIGHT_MAX_LINES = 800
# What the judgment dimensions read (the inputs table in the audit-loop skill,
# plus docs/ for the docs dimension). Tooling, tests and fragments are handed to
# the reviewers but no dimension is about them, so they do not size the review.
DIMENSION_INPUTS = (
    "plugins/steer/",
    "docs/",
    "CHANGELOG.md",
    "CLAUDE.md",
    "README.md",
    "CROSS-SURFACE.md",
)

SEVERITY_ORDER = ("blocker", "high", "warn", "info", "ok")
CALLERS = ("release", "quick-release", "audit-loop")
GH_TIMEOUT = 30


@dataclass
class Check:
    id: str
    status: str  # one of SEVERITY_ORDER
    detail: str


@dataclass
class Scope:
    tier: str  # "light" or "full"
    reason: str
    files: list[str]  # the delta a reviewer is handed
    omitted: int  # generated mirrors left out of it


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


def count_pending_fragments(unreleased_dir: Path) -> int | None:
    """Pending changelog fragments under ``.changes/unreleased/``.

    ``None`` when the directory is missing -- a broken checkout, distinct from
    an empty one (nothing pending, so nothing to release).
    """
    if not unreleased_dir.is_dir():
        return None
    return len(list(unreleased_dir.glob("*.yaml")))


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


def frontmatter(text: str | None) -> str | None:
    match = re.match(r"---\n(.*?)\n---\n", text or "", re.S)
    return match.group(1) if match else None


def routing_surface(files: list[str], read_old, read_new) -> list[str]:
    """Delta paths that move what the routing evals read.

    That surface is the router rule plus each skill's frontmatter (its
    ``description``, ``when_to_use`` and tier). ``read_old`` / ``read_new``
    return a path's text at the last release and now, ``None`` when absent, so
    an added or removed skill counts.
    """
    hits = []
    for path in files:
        if path == ROUTER_RULE:
            hits.append("rules/00-router.md")
        elif (skill := SKILL_MD.match(path)) and frontmatter(read_old(path)) != frontmatter(
            read_new(path)
        ):
            hits.append(f"skills/{skill.group(1)}")
    return hits


def eval_sweep(
    rows: list[dict],
    anchor: str | None,
    anchor_time: datetime | None,
    surface: list[str] | None = None,
    floor: float = EVAL_FLOOR,
) -> Check:
    """Interpret the routing-eval ledger: does this cut owe a sweep, did the newest one hold.

    ``surface`` is ``routing_surface`` between the tree the newest sweep ran on
    and now: a sweep is owed again exactly when that moved, however many
    releases ago the sweep ran. Measuring from the sweep rather than from the
    last release is what keeps a skipped sweep owed at the next cut. ``None``
    means it could not be computed, and the rule falls back to the sweep's age
    against ``anchor_time`` (the instant of the last release, ``None`` when
    undated). Never above ``warn``: three runs per case are noisy, so a low
    case is a prompt to recheck, not a verdict.
    """
    if not rows:
        return Check("evals", "warn", "no routing sweep recorded -- run: mise run evals")
    row = max(rows, key=lambda r: datetime.fromisoformat(r["started"]))
    started = datetime.fromisoformat(row["started"])
    low = sorted((score, name) for name, score in row["below"].items() if score < floor)
    notes = []
    aside = ""
    if surface:
        shown = ", ".join(surface[:4]) + (f", +{len(surface) - 4} more" if surface[4:] else "")
        notes.append(
            f"the routing surface changed since it ran ({shown}) -- this cut owes a sweep: "
            "run `mise run evals`, record it and re-run this check"
        )
    elif surface is not None:
        aside = "; the routing surface is unchanged since it ran, so this cut owes no sweep"
    elif anchor_time is None:
        notes.append("its age against the last release is not verified")
    elif started < anchor_time:
        notes.append(
            f"it predates {anchor}, and whether the routing surface changed since it ran is "
            "not verified -- run `mise run evals` if rules/00-router.md or a skill's "
            "frontmatter changed"
        )
    if low:
        notes.append(
            f"under {floor}: "
            + ", ".join(f"{name} {score}" for score, name in low)
            + f" -- recheck each: {EVAL_RECHECK}"
        )
    head = (
        f"sweep {started:%Y-%m-%d} ({row['cases']} cases x {row['runs']} runs) "
        f"scored {row['score']}"
    )
    if notes:
        return Check("evals", "warn", f"{head}; " + "; ".join(notes))
    if aside:
        return Check("evals", "ok", f"{head}{aside}")
    return Check("evals", "ok", f"{head} after {anchor}, no case under {floor}")


def audit_scope(
    numstat: list[tuple[str, int]],
    mirrors: tuple[str, ...] = (),
    critical: frozenset[str] = frozenset(),
    force_full: bool = False,
) -> Scope:
    """Size the judgment review to the delta: which reviewer fan-out it needs.

    ``numstat`` is ``(path, changed lines)`` per delta path. Generated mirrors
    are dropped from what a reviewer reads (their sources are in the same delta
    and a sync gate proves they match); the size is counted over
    ``DIMENSION_INPUTS`` only. Both tiers review every dimension -- ``light``
    hands them to one reviewer, ``full`` to one each -- so the tier moves cost,
    never coverage.
    """
    kept = [(path, n) for path, n in numstat if not path.startswith(mirrors)]
    files = [path for path, _ in kept]
    sized = [(path, n) for path, n in kept if path.startswith(DIMENSION_INPUTS)]
    paths, lines = len(sized), sum(n for _, n in sized)
    size = f"{paths} path(s) / {lines} line(s)"
    limit = f"the light limit ({LIGHT_MAX_PATHS} / {LIGHT_MAX_LINES})"
    touched = sorted(path for path in files if path in critical)
    if force_full:
        tier, reason = "full", f"{size}; full fan-out forced by the caller"
    elif touched:
        tier, reason = "full", f"{size}; release-critical path in the delta: {', '.join(touched)}"
    elif paths > LIGHT_MAX_PATHS or lines > LIGHT_MAX_LINES:
        tier, reason = "full", f"{size} exceeds {limit}"
    else:
        tier, reason = "light", f"{size} within {limit}"
    return Scope(tier, reason, files, len(numstat) - len(kept))


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
    n = count_pending_fragments(UNRELEASED_DIR)
    if n is None:
        return Check("unreleased", "blocker", ".changes/unreleased/ is missing")
    if n == 0:
        status = "info" if caller == "audit-loop" else "blocker"
        return Check("unreleased", status, "no pending fragments -- nothing to release")
    return Check("unreleased", "ok", f"{n} pending fragment(s)")


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


def generated_mirrors() -> tuple[str, ...]:
    """Path prefixes ``mise run gen:copilot`` regenerates from sources elsewhere in the tree."""
    try:
        import gen_agent_skills  # noqa: PLC0415
        import gen_copilot_agents  # noqa: PLC0415
        import gen_copilot_instructions  # noqa: PLC0415
    except ImportError:
        return ()  # nothing omitted: reviewers read more, never less
    return (
        f"{gen_agent_skills.OUT_DIR.as_posix()}/",
        f"{gen_copilot_agents.OUT_DIR.as_posix()}/",
        f"{gen_copilot_instructions.INSTRUCTIONS_DIR.as_posix()}/",
        gen_copilot_instructions.ARTIFACT.as_posix(),
    )


def delta_numstat(anchor: str) -> list[tuple[str, int]] | None:
    diff = _git("diff", "--numstat", "--no-renames", f"{anchor}..HEAD")
    if diff.returncode != 0:
        return None  # an unreadable delta must not read as an empty, light one
    rows = []
    for line in diff.stdout.splitlines():
        added, deleted, path = line.split("\t", 2)
        # Binary files report "-" for both counts.
        rows.append((path, sum(int(n) for n in (added, deleted) if n.isdigit())))
    return rows


def resolve_scope(anchor: str | None, force_full: bool = False) -> Scope | None:
    from audit_severity import RELEASE_CRITICAL  # noqa: PLC0415

    numstat = delta_numstat(anchor) if anchor else None
    if numstat is None:
        return None
    return audit_scope(numstat, generated_mirrors(), RELEASE_CRITICAL, force_full)


def check_scope(anchor: str | None) -> Check:
    scope = resolve_scope(anchor)
    if scope is None:
        return Check(
            "audit-scope", "warn", "delta not readable; run the audit workflow with no args"
        )
    fan_out = "one combined reviewer" if scope.tier == "light" else "one reviewer per dimension"
    omitted = f"; {scope.omitted} generated mirror(s) not reviewed" if scope.omitted else ""
    return Check("audit-scope", "info", f"{scope.tier}: {scope.reason} -> {fan_out}{omitted}")


def pending_fragments() -> str:
    lines = []
    for path in sorted(UNRELEASED_DIR.glob("*.yaml")):
        kind = re.search(r"^kind:\s*(\S+)", path.read_text(encoding="utf-8"), re.M)
        name = path.relative_to(REPO_ROOT).as_posix()
        lines.append(f"- {name} (kind: {kind.group(1) if kind else '?'})")
    return "\n".join(lines) or "(none)"


def touched_ledger_rows() -> list[dict]:
    out = subprocess.run(
        [sys.executable, "scripts/audit_ledger.py", "open", "--touched", "--json"],
        capture_output=True,
        text=True,
        check=False,
        cwd=REPO_ROOT,
    )
    try:
        rows = json.loads(out.stdout)["rows"]
    except (json.JSONDecodeError, KeyError):
        return []
    return [{k: r.get(k) for k in ("id", "ruleId", "path", "line", "claim")} for r in rows]


def build_plan(force_full: bool = False) -> dict | None:
    """The ``args`` of the ``pre-release-audit`` workflow, so it dispatches no scout."""
    anchor, _ = resolve_anchor()
    scope = resolve_scope(anchor, force_full)
    if scope is None:
        return None
    return {
        "tier": scope.tier,
        "tierReason": scope.reason,
        "lastRelease": anchor,
        "pluginVersion": json.loads(PLUGIN_JSON.read_text(encoding="utf-8")).get("version", ""),
        "files": scope.files,
        "omittedMirrors": scope.omitted,
        "unreleased": pending_fragments(),
        "ledgerRows": touched_ledger_rows(),
    }


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


def sweep_commit(started: datetime) -> str | None:
    """The newest commit on this history when a sweep started: the tree it read, near enough."""
    out = _git("rev-list", "-1", f"--before={int(started.timestamp())}", "HEAD")
    return out.stdout.strip() or None


def routing_surface_since(ref: str | None) -> list[str] | None:
    if ref is None:
        return None
    diff = _git("diff", "--name-only", "--no-renames", f"{ref}..HEAD")
    if diff.returncode != 0:
        return None

    def read_old(path: str) -> str | None:
        shown = _git("show", f"{ref}:{path}")
        return shown.stdout if shown.returncode == 0 else None

    def read_new(path: str) -> str | None:
        target = REPO_ROOT / path
        return target.read_text(encoding="utf-8") if target.is_file() else None

    return routing_surface(diff.stdout.splitlines(), read_old, read_new)


def check_evals(anchor: str | None) -> Check:
    try:
        rows = [
            json.loads(line)
            for line in EVAL_LEDGER.read_text(encoding="utf-8").splitlines()
            if line.strip()
        ]
        stamp = _git("log", "-1", "--format=%ct", anchor).stdout.strip() if anchor else ""
        anchor_time = datetime.fromtimestamp(int(stamp), UTC) if stamp else None
        newest = max((datetime.fromisoformat(r["started"]) for r in rows), default=None)
        surface = routing_surface_since(sweep_commit(newest)) if newest else None
        return eval_sweep(rows, anchor, anchor_time, surface)
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as exc:
        return Check("evals", "warn", f"routing-eval ledger unreadable: {exc!r}")


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
    checks += [anchor_check, check_delta(anchor)]
    if caller == "release":
        checks.append(check_scope(anchor))
    checks += [check_ledger(), check_evals(anchor)]
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
    parser.add_argument(
        "--plan", action="store_true", help="print the pre-release-audit workflow args as JSON"
    )
    parser.add_argument(
        "--full", action="store_true", help="with --plan: force one reviewer per dimension"
    )
    args = parser.parse_args(argv)

    if args.plan:
        plan = build_plan(args.full)
        if plan is None:
            print("delta not readable; run the workflow with no args", file=sys.stderr)
            return 1
        print(json.dumps(plan, indent=2))
        return 0

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

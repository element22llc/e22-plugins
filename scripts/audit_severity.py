#!/usr/bin/env python3
"""Blast-radius severity ceiling for pre-release audit findings.

The pre-release audit used to let a reviewer assign severity from the *prose* of
a finding ("a doc claim that contradicts the code" was defined as a blocker).
That made the release gate stochastic: seven LLM reviewers sampling ~250 markdown
files always find something, each round finds a *different* something, and a
wording nit on a page that ships nothing could halt a release. Between v5.3.0 and
v6.0.0 six audit loops ran (five of them the full four rounds) and the release
still blocked -- on ``docs/reference/hooks.md``, a docs-site page that ships
nothing to any consumer.

So severity is computed from the **path**, not judged from the claim. This module
answers one question -- *what is the worst this finding could do to a consumer who
installs the release?* -- and returns the highest severity a finding on that path
may carry. A reviewer may rank a finding **lower** than its ceiling (a typo in a
hook script is not automatically ``high``); it may never rank one higher. There is
no escalation discretion, because escalation discretion is what made the gate
non-deterministic.

The shipping boundary is not re-derived here. It is imported from
``check_changelog._is_behaviour`` -- the same deny-by-default classifier that
decides whether a change needs a CHANGELOG entry -- so "ships to consumers" has
exactly one definition in this repo and the two gates cannot drift apart.

Tiers, worst first:

``release-critical`` -> ``blocker``
    The version-bearing manifests and the changelog whose invariant binds them.
    Drift here mis-publishes the release itself, which no consumer can work
    around.
``shipped-code`` -> ``high``
    Executable content the plugin ships: hooks, plugin scripts, the MCP and hook
    manifests. A defect here misbehaves in a consumer session.
``shipped-prose`` -> ``medium``
    Content the plugin ships that a model or a human reads: rules, skills,
    agents, templates, policy data. A defect misleads; it does not misexecute.
``repo-tooling`` -> ``medium``
    Gates, generators and CI for this repo. Ships nothing, so it cannot reach a
    consumer -- but a broken gate hides the defects that can.
``non-shipping`` -> ``low``
    The docs site, maintainer prose, tests, evals, this audit machinery. Real
    findings worth fixing; never a reason to hold a release.

Usage::

    uv run python scripts/audit_severity.py docs/reference/hooks.md
    uv run python scripts/audit_severity.py --changed-since v5.3.0 --json
    uv run python scripts/audit_severity.py --explain plugins/steer/hooks/lib/json.sh

Exit status is 0 unless a path argument is malformed.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from check_changelog import _is_behaviour  # noqa: E402  (shared shipping boundary)

# Ordered worst-first; index doubles as the comparison key.
SEVERITIES = ("blocker", "high", "medium", "low")

TIER_CEILING = {
    "release-critical": "blocker",
    "shipped-code": "high",
    "shipped-prose": "medium",
    "repo-tooling": "medium",
    "non-shipping": "low",
}

# The manifests whose mutual agreement *is* the release. Kept as an explicit
# tuple rather than a glob: every entry here is a file whose version field a
# release PR edits, and a new one should be a deliberate addition reviewed as
# such. `check_plugin.check_copilot_version_sync` and `claude plugin tag
# --dry-run` are the deterministic gates that prove they agree.
RELEASE_CRITICAL = frozenset(
    {
        "CHANGELOG.md",
        ".claude-plugin/marketplace.json",
        ".github/plugin/marketplace.json",
        "plugins/steer/.claude-plugin/plugin.json",
        "plugins/steer/.github/plugin/plugin.json",
    }
)

# Extensions that execute rather than inform. `.json` is here because the shipped
# JSON under plugins/steer/ is configuration the harness acts on (hooks.json,
# .mcp.json), not prose.
EXECUTABLE_SUFFIXES = frozenset({".sh", ".py", ".json", ".bash", ".zsh"})

# Repo tooling: ships nothing, but a defect here blinds a gate.
REPO_TOOLING_PREFIXES = ("scripts/", ".github/workflows/", ".github/actions/")
REPO_TOOLING_EXACT = frozenset({"mise.toml", ".pre-commit-config.yaml"})


def classify(path: str) -> str:
    """Return the tier for ``path``. Pure function of the path string."""
    path = path.strip()
    # Strip a `./` prefix only. `lstrip("./")` would treat the argument as a
    # character set and eat the leading dot of every dotfile path, silently
    # demoting `.github/plugin/marketplace.json` out of release-critical.
    while path.startswith("./"):
        path = path[2:]
    if not path:
        raise ValueError("empty path")

    if path in RELEASE_CRITICAL:
        return "release-critical"

    # Repo tooling is checked before the shipping test: `.github/plugin/` is
    # consumer-facing and already caught above, while everything else under
    # `.github/` and all of `scripts/` is this repo's own machinery.
    if path in REPO_TOOLING_EXACT or path.startswith(REPO_TOOLING_PREFIXES):
        return "repo-tooling"

    if not _is_behaviour(path):
        return "non-shipping"

    return "shipped-code" if Path(path).suffix in EXECUTABLE_SUFFIXES else "shipped-prose"


def ceiling(path: str) -> str:
    """Return the highest severity a finding on ``path`` may carry."""
    return TIER_CEILING[classify(path)]


def cap(path: str, proposed: str) -> str:
    """Clamp ``proposed`` severity to the ceiling for ``path``.

    Findings only ever move *down*. A reviewer who ranks a docs-site nit a
    blocker gets a low, which is the whole point of this module.
    """
    if proposed not in SEVERITIES:
        raise ValueError(f"unknown severity {proposed!r}; expected one of {SEVERITIES}")
    limit = ceiling(path)
    return proposed if SEVERITIES.index(proposed) >= SEVERITIES.index(limit) else limit


def blocks_release(path: str, proposed: str) -> bool:
    """True when a finding of ``proposed`` severity on ``path`` halts the cut."""
    return cap(path, proposed) == "blocker"


def _changed_since(ref: str) -> list[str]:
    out = subprocess.run(
        ["git", "diff", "--name-only", f"{ref}...HEAD"],
        capture_output=True,
        text=True,
        check=False,
    )
    if out.returncode != 0:
        # Fall back to the two-dot range: `ref` may be a tag with no merge base
        # recorded (shallow clone), and a wider diff over-reports rather than
        # under-reports, which is the safe direction for a severity ceiling.
        out = subprocess.run(
            ["git", "diff", "--name-only", f"{ref}..HEAD"],
            capture_output=True,
            text=True,
            check=False,
        )
    return [line for line in out.stdout.splitlines() if line.strip()]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("paths", nargs="*", help="paths to classify")
    parser.add_argument(
        "--changed-since",
        metavar="REF",
        help="classify every path changed since REF instead of the positional list",
    )
    parser.add_argument("--json", action="store_true", help="emit JSON")
    parser.add_argument("--explain", action="store_true", help="print the tier rationale per path")
    args = parser.parse_args(argv)

    if args.changed_since:
        paths = _changed_since(args.changed_since)
        if not paths:
            # An empty delta is a legitimate answer ("nothing changed since the
            # release"), not a usage error.
            print(f"no tracked paths changed since {args.changed_since}")
            return 0
    else:
        paths = args.paths
        if not paths:
            parser.error("no paths given (pass paths or --changed-since REF)")

    rows = [{"path": p, "tier": classify(p), "ceiling": ceiling(p)} for p in paths]

    if args.json:
        print(json.dumps(rows, indent=2))
        return 0

    width = max(len(r["path"]) for r in rows)
    for row in rows:
        line = f"{row['path']:<{width}}  {row['ceiling']:<7}"
        if args.explain:
            line += f"  ({row['tier']})"
        print(line)

    if args.changed_since:
        worst = min(rows, key=lambda r: SEVERITIES.index(r["ceiling"]))["ceiling"]
        print(f"\nworst possible severity in this delta: {worst}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

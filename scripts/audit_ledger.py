#!/usr/bin/env python3
"""Persistent findings ledger for the pre-release audit.

The audit's reviewers are stochastic samplers over a large surface. Without a
memory, every release re-discovers the backlog the previous release deliberately
left behind: between v5.3.0 and v6.0.0 ``docs/concepts/copilot-support.md`` was
edited in fourteen separate audit-round commits and ``docs/reference/hooks.md``
in eight -- and ``hooks.md`` still produced the finding that blocked the cut. The
audit-loop keeps a ledger, but only in memory, so it dies with the loop and loop
N+1 re-litigates what loop N settled.

This is that ledger, on disk and in git. The audit reports only findings the
ledger has never seen; anything already triaged is carried forward silently. A
finding is triaged exactly once, by a human, and stays triaged.

The state vocabulary follows SARIF 2.1.0's ``baselineState`` (OASIS, §3.27.19)
rather than inventing one, so the file can be converted to SARIF for any tool
that consumes it:

``open``
    Seen, not yet triaged. Counts against the gate at or above its ceiling.
``accepted``
    Triaged and deliberately not fixed. Requires a ``reason``. Never resurfaces
    and never gates -- this is the state that stops the rediscovery cycle.
``fixed``
    Repaired in the tree. Kept as a tombstone so a regression is recognised as a
    *recurrence* rather than reported as novel.

Identity is a hash of ``ruleId`` + ``path`` + a normalised claim slug -- never the
line number, which drifts on every edit above it and would make the same finding
look new each round.

Usage::

    uv run python scripts/audit_ledger.py status
    uv run python scripts/audit_ledger.py new --candidates round1.json
    uv run python scripts/audit_ledger.py record --candidates round1.json
    uv run python scripts/audit_ledger.py accept <id> --reason "ships nothing; tracked in #492"
    uv run python scripts/audit_ledger.py resolve <id>
    uv run python scripts/audit_ledger.py gate

``gate`` exits 1 when any untriaged finding carries a ``blocker`` ceiling.
"""

from __future__ import annotations

import argparse
import datetime as _dt
import hashlib
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from audit_severity import SEVERITIES, cap, ceiling  # noqa: E402

LEDGER = Path(".claude/audit/findings.jsonl")

STATES = ("open", "accepted", "fixed")

_SLUG_STOPWORDS = frozenset(
    {"the", "a", "an", "is", "are", "was", "were", "of", "to", "in", "on", "at", "and", "that"}
)


def claim_slug(claim: str, words: int = 12) -> str:
    """Normalise a finding's one-line claim into a drift-tolerant identity key.

    Line numbers, punctuation, case and filler words all vary between reviewers
    describing the same defect, so they are stripped. What survives is the
    content words in order, which is stable enough that two reviewers in
    different rounds land on the same id, and specific enough that two genuinely
    different findings on one file do not collide.
    """
    tokens = re.findall(r"[a-z0-9]+", claim.lower())
    kept = [t for t in tokens if t not in _SLUG_STOPWORDS and not t.isdigit()]
    return "-".join(kept[:words])


def finding_id(rule_id: str, path: str, claim: str) -> str:
    digest = hashlib.sha256(f"{rule_id}|{path}|{claim_slug(claim)}".encode()).hexdigest()
    return digest[:12]


def load(ledger: Path = LEDGER) -> dict[str, dict]:
    if not ledger.is_file():
        return {}
    rows: dict[str, dict] = {}
    for lineno, line in enumerate(ledger.read_text(encoding="utf-8").splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError as exc:
            raise SystemExit(f"{ledger}:{lineno}: invalid JSON ({exc})") from exc
        rows[row["id"]] = row
    return rows


def save(rows: dict[str, dict], ledger: Path = LEDGER) -> None:
    ledger.parent.mkdir(parents=True, exist_ok=True)
    # Sorted by id so concurrent PRs produce reviewable, order-stable diffs.
    body = "\n".join(json.dumps(rows[k], sort_keys=True) for k in sorted(rows))
    ledger.write_text(body + "\n" if body else "", encoding="utf-8")


def normalise(candidate: dict) -> dict:
    """Turn a reviewer-supplied candidate into a ledger row.

    Severity is *capped* here rather than trusted: candidates come from LLM
    reviewers, and the whole point of `audit_severity` is that a reviewer does
    not get to set the ceiling on its own finding.
    """
    required = ("ruleId", "path", "claim")
    missing = [k for k in required if not candidate.get(k)]
    if missing:
        raise ValueError(f"candidate missing required field(s): {', '.join(missing)}")

    path = candidate["path"]
    proposed = candidate.get("severity", "medium")
    if proposed not in SEVERITIES:
        raise ValueError(f"unknown severity {proposed!r} on {path}")

    return {
        "id": finding_id(candidate["ruleId"], path, candidate["claim"]),
        "ruleId": candidate["ruleId"],
        "path": path,
        "line": candidate.get("line"),
        "claim": candidate["claim"].strip(),
        "proposed": proposed,
        "severity": cap(path, proposed),
        "ceiling": ceiling(path),
        "state": "open",
        "reason": None,
        "firstSeen": candidate.get("release") or "unreleased",
        "lastSeen": candidate.get("release") or "unreleased",
        "updated": _dt.date.today().isoformat(),
    }


def read_candidates(path: Path) -> list[dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(data, dict):
        data = data.get("findings", [])
    if not isinstance(data, list):
        raise SystemExit(f"{path}: expected a JSON list of findings (or {{'findings': [...]}})")
    return data


# --- commands ---------------------------------------------------------------


def cmd_new(args) -> int:
    """Print only the candidates the ledger has never seen."""
    known = load(args.ledger)
    fresh, carried = [], []
    for cand in read_candidates(args.candidates):
        row = normalise(cand)
        (carried if row["id"] in known else fresh).append(row)

    if args.json:
        print(json.dumps({"new": fresh, "carried": carried}, indent=2, sort_keys=True))
        return 0

    print(f"{len(fresh)} new, {len(carried)} already in the ledger\n")
    for row in sorted(fresh, key=lambda r: SEVERITIES.index(r["severity"])):
        loc = f"{row['path']}:{row['line']}" if row["line"] else row["path"]
        print(f"  [{row['severity']:<7}] {row['id']}  {loc}\n      {row['claim']}")
    if carried:
        print("\n  carried (not reported):")
        for row in carried:
            print(f"    {row['id']}  {known[row['id']]['state']:<8}  {row['path']}")
    return 0


def cmd_record(args) -> int:
    """Add unseen candidates to the ledger as `open`; refresh lastSeen on the rest."""
    rows = load(args.ledger)
    added = 0
    for cand in read_candidates(args.candidates):
        row = normalise(cand)
        if row["id"] in rows:
            rows[row["id"]]["lastSeen"] = row["lastSeen"]
            rows[row["id"]]["updated"] = row["updated"]
        else:
            rows[row["id"]] = row
            added += 1
    save(rows, args.ledger)
    print(f"recorded {added} new finding(s); ledger now holds {len(rows)}")
    return 0


def _transition(args, state: str, reason: str | None) -> int:
    rows = load(args.ledger)
    if args.id not in rows:
        raise SystemExit(f"no finding with id {args.id!r} in {args.ledger}")
    rows[args.id]["state"] = state
    rows[args.id]["reason"] = reason
    rows[args.id]["updated"] = _dt.date.today().isoformat()
    save(rows, args.ledger)
    print(f"{args.id} -> {state}")
    return 0


def cmd_accept(args) -> int:
    return _transition(args, "accepted", args.reason)


def cmd_resolve(args) -> int:
    return _transition(args, "fixed", args.reason)


def cmd_status(args) -> int:
    rows = load(args.ledger)
    if not rows:
        print("ledger is empty")
        return 0
    by_state: dict[str, int] = {}
    for row in rows.values():
        by_state[row["state"]] = by_state.get(row["state"], 0) + 1
    print(f"{len(rows)} finding(s): " + ", ".join(f"{v} {k}" for k, v in sorted(by_state.items())))

    open_rows = [r for r in rows.values() if r["state"] == "open"]
    if open_rows:
        print("\nopen:")
        for row in sorted(open_rows, key=lambda r: SEVERITIES.index(r["severity"])):
            loc = f"{row['path']}:{row['line']}" if row["line"] else row["path"]
            print(f"  [{row['severity']:<7}] {row['id']}  {loc}")
            print(f"      {row['claim']}")
    return 0


def cmd_gate(args) -> int:
    """Exit 1 when an untriaged finding can actually stop a release."""
    rows = load(args.ledger)
    blocking = [r for r in rows.values() if r["state"] == "open" and r["severity"] == "blocker"]
    if not blocking:
        open_n = sum(1 for r in rows.values() if r["state"] == "open")
        print(f"audit ledger: OK (no untriaged blockers; {open_n} open below the gate)")
        return 0
    print(f"audit ledger: {len(blocking)} untriaged blocker(s)", file=sys.stderr)
    for row in blocking:
        loc = f"{row['path']}:{row['line']}" if row["line"] else row["path"]
        print(f"  {row['id']}  {loc}\n      {row['claim']}", file=sys.stderr)
    return 1


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--ledger", type=Path, default=LEDGER, help="ledger path")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_new = sub.add_parser("new", help="report only candidates not already in the ledger")
    p_new.add_argument("--candidates", type=Path, required=True)
    p_new.add_argument("--json", action="store_true")
    p_new.set_defaults(func=cmd_new)

    p_rec = sub.add_parser("record", help="add unseen candidates to the ledger as open")
    p_rec.add_argument("--candidates", type=Path, required=True)
    p_rec.set_defaults(func=cmd_record)

    p_acc = sub.add_parser("accept", help="triage a finding as deliberately not fixed")
    p_acc.add_argument("id")
    p_acc.add_argument("--reason", required=True)
    p_acc.set_defaults(func=cmd_accept)

    p_res = sub.add_parser("resolve", help="mark a finding fixed in the tree")
    p_res.add_argument("id")
    p_res.add_argument("--reason", default=None)
    p_res.set_defaults(func=cmd_resolve)

    sub.add_parser("status", help="summarise the ledger").set_defaults(func=cmd_status)
    sub.add_parser("gate", help="exit 1 on untriaged blockers").set_defaults(func=cmd_gate)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())

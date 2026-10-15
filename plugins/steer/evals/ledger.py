#!/usr/bin/env python3
"""The routing suite's score history: one JSON line per full sweep in `ledger.jsonl`.

`results/` stays gitignored - a full sweep is ~1.4 MB, carries local paths, and
`evals/` ships with every plugin install - so the trend is distilled here from
each sweep's `aggregate-result.json`. Run from the repo root::

    uv run python plugins/steer/evals/ledger.py                # print the trend
    uv run python plugins/steer/evals/ledger.py add --latest   # record the newest run
    uv run python plugins/steer/evals/ledger.py add results/<ts> ...

Read `meanDelta` against `ceiling`, not against 1.0: a negative case (one whose
`routed` grader pins `max: 0`) scores level in both arms by construction, so the
best possible meanDelta is the share of positive cases.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

EVALS = Path(__file__).resolve().parent
RESULTS = EVALS / "results"
LEDGER = EVALS / "ledger.jsonl"


def suite_size() -> int:
    return sum(1 for p in EVALS.iterdir() if (p / "case.yaml").is_file())


def entry(agg: dict) -> dict:
    cases = agg["cases"]
    negatives = sum(
        1 for c in cases if any(g.get("config", {}).get("max") == 0 for g in c["graders"])
    )
    suite = agg["suite"]
    return {
        "started": agg["startedAt"],
        "claude": agg["claudeVersion"],
        "steer": suite["plugins"][0]["version"],
        "executor": suite.get("modelOverride"),
        "judge": suite.get("judgeModel"),
        "cases": len(cases),
        "runs": len(cases[0]["arms"]["with"]),
        "ceiling": round((len(cases) - negatives) / len(cases), 3),
        "meanDelta": round(agg["aggregates"]["meanDelta"], 3),
        "score": round(agg["aggregates"]["overallScore"], 3),
        "costUsd": round(agg["costUsd"], 2),
        "minutes": round(agg["durationSeconds"] / 60),
        "below": {
            c["name"]: round(c["aggregates"]["score"], 2)
            for c in cases
            if c["aggregates"]["score"] < 1
        },
    }


def load() -> list[dict]:
    if not LEDGER.is_file():
        return []
    return [json.loads(line) for line in LEDGER.read_text().splitlines() if line.strip()]


def rejection(agg: dict, recorded: set[str], force: bool) -> str | None:
    if agg.get("partial"):
        return "partial run"
    if "meanDelta" not in agg["aggregates"]:
        return "no baseline arm (run without --ablation with-without)"
    if agg["startedAt"] in recorded:
        return "already recorded"
    if not force and len(agg["cases"]) < suite_size():
        return f"{len(agg['cases'])} of {suite_size()} cases - not a full sweep (--force)"
    return None


def add(dirs: list[Path], force: bool) -> int:
    rows = load()
    recorded = {r["started"] for r in rows}
    added = 0
    for d in dirs:
        agg = json.loads((d / "aggregate-result.json").read_text())
        why = rejection(agg, recorded, force)
        if why:
            print(f"skip {d.name}: {why}", file=sys.stderr)
            continue
        rows.append(entry(agg))
        recorded.add(agg["startedAt"])
        added += 1
    rows.sort(key=lambda r: r["started"])
    LEDGER.write_text("".join(json.dumps(r) + "\n" for r in rows))
    print(f"recorded {added} sweep(s) in {LEDGER.relative_to(EVALS.parents[2])}")
    return 0


def show() -> int:
    print(
        f"{'started':16}  {'steer':7} {'cases':>5} {'runs':>4} {'delta':>5} {'of max':>6} "
        f"{'score':>5} {'cost':>5} {'min':>4}  below 1.0"
    )
    for r in load():
        print(
            f"{r['started'][:16]}  {r['steer']:7} {r['cases']:5} {r['runs']:4} "
            f"{r['meanDelta']:5.2f} {r['meanDelta'] / r['ceiling']:6.0%} {r['score']:5.2f} "
            f"{r['costUsd']:5.0f} {r['minutes']:4}  "
            + " ".join(f"{k.removeprefix('routes-')}:{v}" for k, v in r["below"].items())
        )
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="cmd")
    add_p = sub.add_parser("add", help="record finished sweeps")
    add_p.add_argument("dirs", nargs="*", type=Path)
    add_p.add_argument("--latest", action="store_true", help="the newest results/<ts>/")
    add_p.add_argument("--force", action="store_true", help="accept a subset of the suite")
    args = parser.parse_args(argv)
    if args.cmd != "add":
        return show()
    dirs = list(args.dirs)
    if args.latest:
        dirs.append(max(p for p in RESULTS.iterdir() if p.is_dir()))
    if not dirs:
        parser.error("add needs a results dir or --latest")
    return add(dirs, args.force)


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Replay the `answer` grader's judge over a finished run, with its reasons.

`claude plugin eval` records the judge's *votes* and the text it judged, never
why it voted that way - the standing constraint `README.md` names, and what
blocked issue #630. Everything the judge saw is in `aggregate-result.json`
(`config.criteria` plus each run's `graders[].evidence`), so the verdict can be
reproduced offline for cents instead of re-running a $12 sweep.

Two modes, and the first is the one that makes the second trustworthy:

``--mode votes`` (default)
    Replays the CLI's judge prompt byte for byte - same system prompt, same
    ``Respond with exactly one word`` instruction, same 3-vote majority - and
    diffs the replayed verdict against the recorded one. Agreement is the
    fidelity check: a replay that disagrees is judging something else, and its
    rationales explain nothing.

``--mode rationale``
    Same prompt with the one-word instruction replaced by "verdict first, then
    the clause that decided it". Verdict-first keeps the distribution close to
    the one-word judge; the sentence after it is the diagnosis.

``--live`` re-grades the *stored* evidence against the criteria currently on
disk, which is how a criteria rewrite is validated without spending a run: the
with-plugin arm must pass, and the no-plugin arm must still fail.

Run from the repo root::

    uv run python plugins/steer/evals/replay_judge.py --mode rationale --arm with
    uv run python plugins/steer/evals/replay_judge.py --live --arm both

Judge calls go through the local `claude` CLI on your own credential, from a
scratch cwd with settings, plugins and slash commands off, so the session that
grades carries none of this repo's context.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from fnmatch import fnmatch
from pathlib import Path

EVALS = Path(__file__).resolve().parent
RESULTS = EVALS / "results"

JUDGE_SYSTEM = "You are a strict, terse evaluation judge for coding-agent traces."
# Last measured agreement between this replay and the harness's own verdicts, and
# the run it was measured against. It is not 36/36 and may never be: the harness
# judges through a direct API call, this replays through `claude -p`. Re-measure
# with `--mode votes` after any change here, and move these two lines.
FIDELITY = "28/36 on the with arm, 2026-09-22T13-34-28-092Z"
ONE_WORD = "Respond with exactly one word: PASS or FAIL."
WITH_REASON = (
    "Respond with PASS or FAIL on the first line. On the second line, in one "
    "sentence, name the exact clause of the criterion that decided it."
)


@dataclass
class Item:
    case: str
    arm: str
    run: int
    criteria: str
    evidence: str
    recorded: bool | None


def latest_results() -> Path:
    runs = sorted(p for p in RESULTS.glob("*/aggregate-result.json"))
    if not runs:
        sys.exit(f"no results under {RESULTS} - run `mise run evals` first")
    return runs[-1]


def live_criteria(case: str) -> str:
    text = (EVALS / case / "graders" / "answer.md").read_text(encoding="utf-8")
    body = text.split("---", 2)[2] if text.startswith("---") else text
    return body.strip()


def collect(payload: dict, case_glob: str, arms: list[str], live: bool) -> list[Item]:
    items = []
    for case in payload["cases"]:
        name = case["name"]
        if not fnmatch(name, case_glob):
            continue
        stored = next(
            (g["config"]["criteria"] for g in case["graders"] if g["name"] == "answer"), None
        )
        if stored is None:
            continue
        criteria = live_criteria(name) if live else stored
        for arm in arms:
            for i, run in enumerate(case["arms"].get(arm, [])):
                grader = next((g for g in run["graders"] if g["name"] == "answer"), None)
                if grader is None or not grader.get("evidence"):
                    continue
                items.append(Item(name, arm, i, criteria, grader["evidence"], grader.get("passed")))
    return items


def judge(prompt: str, model: str, cwd: str) -> str:
    result = subprocess.run(
        [
            "claude",
            "-p",
            "--model",
            model,
            "--system-prompt",
            JUDGE_SYSTEM,
            "--setting-sources",
            "",
            "--strict-mcp-config",
            "--disable-slash-commands",
            # The harness judges through a plain API call with no tools. A `claude
            # -p` session attaches the whole tool surface, and that conditioning is
            # the likeliest cause of the one-directional leniency measured on
            # 2026-09-22: all nine with-arm disagreements flipped toward PASS,
            # which sampling noise does not do.
            "--tools",
            "",
            "--max-turns",
            "1",
            prompt,
        ],
        cwd=cwd,
        capture_output=True,
        text=True,
        timeout=300,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"claude exited {result.returncode}")
    return result.stdout.strip()


def verdict(reply: str) -> bool:
    # The CLI's own rule: PASS only when the word appears and FAIL does not.
    return bool(re.search(r"\bPASS\b", reply, re.I)) and not re.search(r"\bFAIL\b", reply, re.I)


def grade(item: Item, mode: str, votes: int, model: str, cwd: str) -> dict:
    tail = ONE_WORD if mode == "votes" else WITH_REASON
    # Byte-identical to the template the CLI builds for a text focus (read out of
    # the 2.1.278 binary). It carries no `Criterion:` label - an earlier replay
    # added one, and a judge prompt that differs at all is judging something else.
    prompt = (
        "You are grading the output of a coding agent against a criterion.\n"
        f"{item.criteria}\n"
        f"Agent output (last_message):\n{item.evidence}\n"
        f"{tail}"
    )
    replies = [judge(prompt, model, cwd) for _ in range(votes)]
    marks = [verdict(r) for r in replies]
    return {
        "case": item.case,
        "arm": item.arm,
        "run": item.run,
        "recorded": item.recorded,
        "votes": marks,
        "passed": sum(marks) > len(marks) / 2,
        "replies": replies,
    }


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--results", type=Path, help="aggregate-result.json (default: newest)")
    ap.add_argument("--case", default="*", help="case name glob")
    ap.add_argument("--arm", default="with", choices=["with", "without", "both"])
    ap.add_argument("--mode", default="votes", choices=["votes", "rationale"])
    ap.add_argument("--votes", type=int, help="judge calls per item (default: 3, 1 rationale)")
    ap.add_argument("--live", action="store_true", help="grade with graders/answer.md on disk")
    ap.add_argument("--model", default="sonnet", help="judge model (match the run's)")
    ap.add_argument("--concurrency", type=int, default=6)
    ap.add_argument("--json", type=Path, help="write the full result here")
    args = ap.parse_args(argv)

    path = args.results or latest_results()
    payload = json.loads(path.read_text(encoding="utf-8"))
    arms = ["with", "without"] if args.arm == "both" else [args.arm]
    items = collect(payload, args.case, arms, args.live)
    if not items:
        sys.exit(f"no `answer` evidence matched in {path}")
    votes = args.votes or (3 if args.mode == "votes" else 1)

    print(f"replaying {len(items)} item(s) from {path} ({args.mode}, {votes} vote(s))")
    with tempfile.TemporaryDirectory() as cwd, ThreadPoolExecutor(args.concurrency) as pool:
        results = list(pool.map(lambda i: grade(i, args.mode, votes, args.model, cwd), items))

    agreed = 0
    for r in results:
        marks = " ".join("PASS" if m else "FAIL" for m in r["votes"])
        same = r["recorded"] is None or r["recorded"] == r["passed"]
        agreed += same
        flag = "" if same else f"  (recorded {'PASS' if r['recorded'] else 'FAIL'})"
        print(f"\n{r['case']} [{r['arm']}] -> {'PASS' if r['passed'] else 'FAIL'}{flag}  {marks}")
        if args.mode == "rationale":
            for reply in r["replies"]:
                print("  " + reply.replace("\n", "\n  "))

    if args.live:
        # `--live` grades stored evidence against criteria the run never saw, so
        # there is nothing to agree with. Say what the instrument is worth: at the
        # fidelity below it can show a criteria change flipping a verdict, and it
        # cannot show a routing change at all.
        print(f"\nadvisory - last measured fidelity {FIDELITY}; a live run is the proof")
    else:
        print(f"\nagreement with the recorded verdicts: {agreed}/{len(results)}")
    passed = sum(r["passed"] for r in results)
    print(f"replayed verdicts: {passed}/{len(results)} PASS")
    if args.json:
        args.json.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
        print(f"wrote {args.json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

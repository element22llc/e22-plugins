#!/usr/bin/env python3
"""Replay the `answer` grader's judge over a finished run, with its reasons.

`claude plugin eval` records the judge's *votes* and the text it judged, never
why it voted that way - the standing constraint `README.md` names, and what
blocked issue #630. Everything the judge saw is in `aggregate-result.json`
(`config.criteria` plus each run's `graders[].evidence`), so the verdict can be
reproduced offline for cents instead of re-running a $12 sweep.

**Know what this is worth before you read a verdict from it.** The prompt and
the call are byte-identical to the harness's, verified by capture rather than
inferred: point ``ANTHROPIC_BASE_URL`` at a local stub that logs the request
body, run one real ``claude plugin eval``, and diff its judge request against
this one (recipe in ``README.md``). Measured agreement is ``FIDELITY`` below,
against a ceiling of 35/36 - what this replay scores against *itself* on the
same items, since a 3-vote majority of a stochastic judge is not a fixed
verdict. Re-measure after any change here, and after a CLI upgrade: the prompt
is version-bound.

Two modes:

``--mode votes`` (default)
    Replays the judge prompt - same system prompt, same ``Respond with exactly
    one word`` instruction, same 3-vote majority - and diffs the replayed
    verdict against the recorded one. That diff is the fidelity measure itself;
    re-measure it after any change to the prompt or the invocation here.

``--mode rationale``
    Same prompt with the one-word instruction replaced by "verdict first, then
    the clause that decided it". Verdict-first keeps the distribution close to
    the one-word judge; the sentence after it is the diagnosis. It commits the
    verdict before the reasoning, so a reply can open ``PASS`` and then argue
    the opposite - read the sentence, not the first word.

``--live`` re-grades the *stored* evidence against the criteria currently on
disk - a criteria rewrite, both arms: the no-plugin arm must still fail and the
with arm should hold. It cannot see a routing change, and a rewrite that moves
a verdict here is still proved by a live ``--case`` run.

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
import os
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
# the run it was measured against. Two consecutive passes scored 34/36 and 33/36
# against a 35/36 replay-vs-replay ceiling, reproducing 7 and 6 of the 9 recorded
# FAILs where the old prompt reproduced none. Re-measure with `--mode votes`
# after any change here, and move these lines.
FIDELITY = "34/36 on the with arm (ceiling 35/36), 2026-09-22T13-34-28-092Z"
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


def judge_env() -> dict[str, str]:
    """The environment a plain terminal would give `claude`, plus thinking off.

    A replay launched from inside a Claude Code session inherits that session's
    `CLAUDE_*` - `CLAUDE_EFFORT` among them - so the same command graded
    differently depending on where it was run. The two kept are where the
    credential lives. `MAX_THINKING_TOKENS=0` is what makes the child send
    `thinking: disabled`, which is how the harness calls the judge.
    """
    keep = {"CLAUDE_CONFIG_DIR", "CLAUDE_CODE_OAUTH_TOKEN"}
    env = {k: v for k, v in os.environ.items() if not k.startswith("CLAUDE_") or k in keep}
    env.pop("CLAUDECODE", None)
    env.pop("AI_AGENT", None)
    env["MAX_THINKING_TOKENS"] = "0"
    return env


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
            # The captured harness call sends tools: [], thinking disabled and
            # three system blocks - the billing header, the Agent SDK line and
            # the judge line. `--tools ""` plus `--system-prompt` reproduce all
            # of that; the one difference left is the environment
            # system-reminder `claude -p` appends as a second message.
            "--tools",
            "",
            "--max-turns",
            "1",
            prompt,
        ],
        cwd=cwd,
        env=judge_env(),
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


def judge_prompt(criteria: str, evidence: str, tail: str = ONE_WORD) -> str:
    """The prompt the CLI sends its judge for a `last_message` focus.

    Byte-identical to a captured `claude plugin eval` judge call, blank lines
    included - `capture_judge.py` is what proves that and re-proves it after a
    CLI upgrade. Reading the template out of the binary is not enough:
    `strings` drops empty lines, so the separators there read as single
    newlines and an earlier reconstruction lost every one of them.
    """
    return (
        "You are grading the output of a coding agent against a criterion.\n\n"
        f"Criterion:\n{criteria}\n\n\n"
        f"Agent output (last_message):\n{evidence}\n\n\n"
        f"{tail}"
    )


def grade(item: Item, mode: str, votes: int, model: str, cwd: str) -> dict:
    tail = ONE_WORD if mode == "votes" else WITH_REASON
    prompt = judge_prompt(item.criteria, item.evidence, tail)
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
        # there is nothing to agree with - print what the instrument is worth
        # instead. It can show a criteria change flipping a verdict; it cannot
        # show a routing change at all.
        print(f"\nlast measured fidelity {FIDELITY}; a live run is the proof")
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

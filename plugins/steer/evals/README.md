# Routing evals

A model-graded regression net for steer's **routing surface**: does a plain-language
ask actually arrive at the skill that owns it?

## Why this exists

`scripts/check_routing_fixtures.py` guards the same surface, and says of itself:

> This is a deterministic lexical proxy, not a model eval: it cannot prove an ask
> routes correctly, but it proves the vocabulary that routing depends on is [present].

That gate proves the *signal keywords* for an ask still appear in the union of
`rules/00-router.md` and the owning skill's `description` + `when_to_use`. It cannot
prove the ask lands. These cases close that gap, and the two are deliberately
coupled: every case here is an ask lifted verbatim from
`tests/fixtures/routing/asks.yml`, so the cheap gate and the expensive one are
measuring the same claim at different strengths.

## What a case asserts

Each case runs the ask against a repo built by its own scaffold and scores two
graders:

| Grader | Type | Weight | Asserts |
|---|---|---|---|
| `routed` | `tool_used` on the `Skill` call | 3 | the run **enters** the owning skill (or the front door that hands off to it) |
| `answer` | `llm` on `last_message` | 2 | it **names** the owning skill and spends the body on that skill's work, rather than the named wrong workflow's |

**Routing is asserted on the invocation; the answer is graded on
`last_message`.** Those are two different claims and they need two different
surfaces.

`last_message` leaves two shapes ungradeable, and they were resolved
differently. A skill that **pauses** on its own question ends with no handoff
heading, so nothing in the final message names it - that is now rule
`00-router`'s problem and the rule says to name the skill in that message. A
skill that **auto-continues** into the next one ends with the *second* skill's
output, which is the rule working as written ("auto-continue, bounded"), and
forcing the second skill to re-name the first is ceremony the 7.0 rule diet
exists to remove. That shape is left failing the `answer` grader on purpose:
`routed` still passes on the `Skill` call, and `--threshold 0.6` is exactly that
grader's weight - "entered the right skill even if the prose judge docked it".

`routed` used to be a regex on `last_message`, and that was the wrong surface for
it. `rules/00-router.md` says "announce, then act", so the announcement lands in
the run's **first** message, and a finished skill's report names the skills that
come *next* - not itself. In the v6.1.0 run **15 of 24** with-plugin runs failed
`routed` while the `answer` judge passed them unanimously, and the single run that
scored full marks did so because it was killed immediately after its announce
line. The grader was measuring message shape.

Watching the `Skill` call is **not** the trace-grading mistake. The objection to
`target: trace` stands: the always-on ruleset names every skill, so any skill
matches somewhere in the injected text, and an early draft that graded the trace
passed cases it should have failed. But an invocation is an **action the run
took**, and the no-plugin arm has no steer skills to invoke - which is why
`routed` carries `arm: both` and stays scored in both arms. A bare
`tool_used: Skill` is auto-demoted to a with-only *indicator* and drops out of the
score, so the `arm: both` is load-bearing.

Four cases accept their **front door** as well as the specialized skill
(`steer:(init|setup)`, `steer:(adopt|setup)`, `steer:(sync|setup)`,
`steer:(issues|work)`), because rule `00-router` makes the
front door the correct route: "front doors detect context and hand off ... so you
rarely route to a specialized skill directly." Discriminating init from adopt is
the `answer` grader's job, and its criteria name the wrong workflow explicitly.

**A closing handoff is never a failure, and the criteria must say "do not fail"
outright.** Every readout ends with a handoff naming the *next* skill (`##
Recommended next actions - /steer:<skill>`, `Suggested command: /steer:...`),
and rule `00-router` mandates it. In the 2026-09-04 run the two `audit` and two
`issues` responses the judge failed were exactly the ones ending "Current
recommended action: `/steer:work`" - read as *starting* the wrong workflow -
while the responses that passed skipped the line. The exemption written for that
(*"a finished readout that names another skill as the next action ... has not
started that workflow"*) then caused the inverse failure in the 7.0 pre-cut
sweep, issue #630: six conformant readouts failed 3-0, and every rationale cited
that clause as proof the response had **done** nothing. Describing the handoff
is not enough - the sentence has to forbid the failure, which is how the two
negatives had always phrased it.

**Passing takes two things, and the first one carries the ablation.** The
criteria require the owning skill to be *named* - anywhere, the closing handoff
heading included - and the body to be spent on that skill's work. The naming
half is what tells the arms apart: no baseline run in the suite has ever named a
`/steer:*` skill, so criteria that grade only the body pass the no-plugin answer
too. That is measured, not assumed: the first #630 rewrite dropped the
requirement and passed **9 of 10** baselines (`replay_judge.py --live`).
`routes-po-idea-to-build` is the one positive that cannot require the name -
rule `00-router` keeps a non-technical owner clear of skill names - so it names
the build flow's two gates instead: the owner approves a written plan before any
code, and a developer reviews before real use. A competent baseline interview
has neither.

**A fail clause must not name a string the right answer also carries.** 7.0
folded `issues` behind `/steer:work`, and `routes-triage-backlog-to-issues`
failed every run of two consecutive sweeps while its criteria accepted
`/steer:work issues` in clause 1 and named "`work`" as the wrong workflow three
paragraphs later. The responses were exemplary grooming. The bullet now names
what delivery actually looks like - `/steer:work <number>`, claiming, branching,
writing the fix - and says outright that `/steer:work` alone is not evidence of
the wrong workflow. The case went 0.60 -> 0.73 on the fix.

**Where a skill's own deliverable is another skill's name, say so.**
`/steer:next` arbitrates: its output *ends* on the one action worth taking,
which is always some other workflow. Criteria that only exempt a closing handoff
do not cover that - the handoff is not decoration there, it is the product. The
case carries a paragraph saying so, and went 0.60 -> 0.87.

**Conformant prose is still a coin flip on this judge, and the suite prices
that.** Both cases above still failed runs after their fix - two of three on
triage, one of three on `next` - on responses that read like the ones that
passed. Replayed at 9 votes against a judge call that now matches the harness
byte for byte (below), those failures split three ways:

| Failure | Replay | Reading |
|---|---|---|
| `spec` run 0, 15-49 | 1/9 PASS | correct: it never names `/steer:spec`. Not variance. |
| `triage` run 1, 15-26 | 2/9 PASS | reproducible, and `--mode rationale` names the clause: its closing `Current recommended action: /steer:work start #123` reads as *starting* delivery. That is a criteria collision, tracked as its own change. |
| `triage` run 2, 15-26 · `next` run 1, 15-40 · `client-status` runs 0-1, 13-34 | 7/9, 9/9, 9/9, 8/9 PASS | not reproducible. Each names its owning skill and spends its body on that skill's work; the rationales for the failed ones read like the rationales for the passed ones. |

The last row is the coin flip, and 2/9, 5/9, 6/9 and 7/9 over texts that read
alike is what a fuzzy boundary looks like. Do not write a clause against a
failure that stays in that row - `--threshold 0.6` is exactly the `routed`
weight for this reason, and a case at 0.73 or 0.87 with `routed` 3/3 has routed
correctly. A failure that leaves it, as triage's did, is a criteria bug and gets
fixed.

**Diagnosing a judge failure: `replay_judge.py`.** Neither the JSON nor
`report.html` carries the judge's rationale, only its votes, and the per-run
`tracePath` points into a sandbox temp dir that is gone by the end of the run.
But everything the judge saw is in `aggregate-result.json` - the criteria and
each run's `last_message` - so the verdict replays offline for cents:

```shell
uv run python plugins/steer/evals/replay_judge.py --arm both            # fidelity
uv run python plugins/steer/evals/replay_judge.py --mode rationale      # why
uv run python plugins/steer/evals/replay_judge.py --live --arm both     # validate a rewrite
```

It sends the judge the same prompt the CLI does and the same 3-vote majority,
and against the 2026-09-22T13-34 sweep two consecutive passes agreed on **34 of
36** and **33 of 36** with-arm items. Read that against the **ceiling: 35/36**,
what the replay scores against *itself* on the same items - a 3-vote majority of
a stochastic judge is not a fixed verdict, so 36/36 is not the target and never
was. It reproduced 7 of the 9 recorded FAILs on the first pass and 6 on the second;
the residual is the last row of the table under "coin flip" above.

**Verify the judge call by capturing it, not by reading the binary.** The
earlier 27/36 came from a prompt reconstructed out of `strings` on the CLI, and
it was wrong twice over: `strings` drops empty lines, so every blank line in the
template read as a single newline, and the `Criterion:` label that was removed
on that reading is one the CLI does build. `capture_judge.py` settles it against
the CLI on your machine - a toy plugin, one eval case, and `ANTHROPIC_BASE_URL`
pointed at a local stub that logs the request body and answers every call, so
nothing leaves the machine and nothing is billed:

```shell
uv run python plugins/steer/evals/capture_judge.py   # after a CLI upgrade
```

It diffs the captured judge request against `replay_judge.judge_prompt()` and
fails loudly when they part. What it shows today, and what the replay matches:
the prompt is

```text
You are grading the output of a coding agent against a criterion.

Criterion:
<criteria>


Agent output (last_message):
<evidence>


Respond with exactly one word: PASS or FAIL.
```

sent with `tools: []`, `thinking: disabled`, three system blocks (billing
header, the Agent SDK line, the judge line) and one user message. `claude -p
--tools "" --system-prompt ...` reproduces all of it except the environment
`system-reminder` it appends as a second message; `MAX_THINKING_TOKENS=0` is
what turns thinking off, and the replay scrubs the parent session's `CLAUDE_*`
so a run from inside Claude Code grades like a run from a terminal. **The prompt
is version-bound** - re-capture after a CLI upgrade, and re-measure.

So read it for what it can carry:

- **A discriminant check is worth acting on.** Rewrite a case's criteria, run
  `--live --arm without`, and a baseline that still fails 0/3 is evidence the
  rewrite did not open a hole.
- **A with-arm verdict is now worth reading too**, at the fidelity above - but
  it grades *stored* text, so it cannot see a routing change, and **a live
  `--case` run at `--runs 3` is still the only proof a criteria fix worked.**
- **`--mode rationale` is a lead, not a verdict.** Verdict-first keeps the
  distribution near the one-word judge, but it also lets a reply open `PASS` and
  then argue the opposite. Read the sentence.

`--live` prints the last measured fidelity for exactly this reason. It is an
authoring aid, not a gate - it cannot see a routing change, only a grading one.

**Every run is read-only, and each case says so** via an identical
`append_system_prompt`. Without it the answer is dominated by permission
narration - every run of the v6.1.0 suite opened by explaining what it could not
write - and the judge grades how well a run describes being blocked. The framing
is byte-identical across cases and applied to both arms, so it cannot bias the
comparison; `tests/test_eval_suite.py` enforces that. It carves the tracker tools
out **by name**: the first framing said "the network is unavailable" and granted
`mcp__github__*` in the same case, and the runs resolved the contradiction by
treating the tracker as dead - 0 tracker calls in 9 of 12 managed with-plugin
runs, `/steer:next` reporting it "unreadable here (no network)", and one
`fix issue #123` run guessing the bug from the code rather than reading the
issue. The framing does **not** tell the run to enter a skill: that would coach
the arm the suite exists to measure. A write-capable skill that is named in prose
and then done by hand in a read-only session is the routing defect the
2026-09-04 run surfaced (13 of 24 with-plugin runs, 12 of them naming the right
skill first), and the fix for it belongs in rule `00-router`, not here.

## Coverage: every public skill, and the asks that own none

Each of the seven public skills has at least one positive case - `setup` has
three, because the front door has to absorb a greenfield, a brownfield and a
behind-the-times repo. The four cases still named after an internal skill
(`init`, `adopt`, `sync`, `issues`) are the front-door cases above: each accepts
either that skill or the public door it now lives behind.

| Skill | Case |
|---|---|
| `setup` | `routes-greenfield-bootstrap-to-init` · `routes-vibe-coded-app-to-adopt` · `routes-openspec-behind-to-sync` |
| `spec` | `routes-think-feature-through-to-spec` |
| `work` | `routes-fix-issue-to-work` · `routes-triage-backlog-to-issues` |
| `audit` | `routes-repo-health-to-audit` |
| `status` | `routes-client-status-to-status` |
| `next` | `routes-lost-user-to-next` |
| `build` | `routes-po-idea-to-build` |
| (none) | `routes-explain-code-to-none` · `routes-general-knowledge-to-none` |

The last row is the point of the negatives. Rule `00-router` tells the model to
map a plain-language goal to the owning skill and **invoke it without being
asked** - the instruction that makes routing feel effortless is also the one
that overfires, and every positive case rewards entering a skill. A negative
case asserts the inverse on the same surface: `tool_used` with `min: 0`,
`max: 0` and `arm: both`, so a run that pulls "what does this function do?" into
an audit fails. `min` defaults to 1, so both bounds are pinned; `tests/test_eval_suite.py`
enforces that.

Read a negative's Δ as **bounded above by zero**: the baseline has no steer
skills to invoke, so it passes `routed` by construction and a healthy negative
scores level. A *negative* delta there is the plugin claiming an ask it does not
own.

The asks are in `tests/fixtures/routing/asks.yml` like every other case's, as
`skill: none` with a `why` and no signals - a lexical gate cannot prove an
absence, which is exactly why the claim lives here.

## Ablation is the point

The suite runs `--ablation with-without` by default: each case also runs a **no-plugin
baseline arm**, and the reported number is the delta. A case that scores well in both
arms proves nothing about steer - the model would have got there anyway. What counts
is Δ.

## The scaffolds

Each case builds its own repo from its own `scaffold.sh`. There are **four
variants**, because one fixture cannot serve every ask:

| Variant | Cases | Repo state | Why |
|---|---|---|---|
| `managed` | work, next, audit, spec, issues, status, both negatives | complete, version-stamped spine + toolchain + code + tests | These asks presume a bootstrapped repo. Every session-start check is **silent** against it - and a negative case needs that silence most: a bootstrap nudge would hand it a workflow to enter. |
| `greenfield` | init, build | `git init` + a README, nothing else | Their asks say "brand-new empty repo" / "build an app from my idea". |
| `legacy` | adopt | a Flask app, no spec, no toolchain, no tests | Its ask says "no spec, no toolchain". Unspecified code volume is what separates adopt from init. |
| `openspec` | sync | an OpenSpec spine, no `spec/.version` | OpenSpec owns the spine, so a stamped spine would contradict the state under test and an unspecified tree would route to adopt. |

**Silence is the contract for `managed`.** A `foreign` spine (a `spec/` with no
`spec/.version`) makes `check-unmanaged-repo.sh` inject an adopt offer into every
run, and template gaps make `check-template-drift.sh` inject a reconciliation
notice - both then compete with the ask for the answer, and the case measures the
fixture instead of the routing. That was a real bug: before the variants existed,
all eight cases shared one `foreign` scaffold and every run of "fix issue #123"
spent its answer on `/steer:adopt`. Check any change to the managed scaffold with

```shell
printf '{"cwd":"<scaffolded repo>"}' | sh plugins/steer/hooks/session-checks.sh
```

and expect **no output**. The two bootstrap variants are the opposite: the nudge
*should* fire there, because it names the very routes those cases assert.

The copies within a variant are byte-identical by contract
(`tests/test_eval_suite.py` enforces it, per variant); the tool requires
`scaffold_script` to name a file **inside** the case directory, so a single shared
copy is not possible. Edit one, run the test, propagate to that variant.

The managed scaffold stamps `spec/.version` with the plugin's **current** version -
a mismatch reads as version drift to `/steer:next` and injects a sync nudge.
`test_managed_scaffold_stamps_the_current_plugin_version` pins the two together,
so the release bump has to re-stamp the fixture.

## The tracker stand-in

`spec/tracker.md` declares GitHub, so the managed cases need a read path to it.
`mocks/github/` provides stand-ins for the three read-only tools the skills call -
`issue_read`, `list_issues`, `search_issues` - named after the server segment of
the tool name (`mcp__github__issue_read` -> `mocks/github/issue_read.md`), with
`_tools.json` as the saved `tools/list` response. `--mocks` defaults to `record`,
which serves a stand-in wherever one exists.

**`list_issues` and `search_issues` are fixed responders** - the file body *is*
the canned result, which is cheap and perfectly deterministic for a call that
takes no discriminating argument.

**`issue_read` is an `type: agent` responder**, because it takes an
`issue_number` **and** a `method` and a fixed body ignores both. As a fixed
responder it returned issue #123 for every call, and the v6.1.0 runs noticed:
they spent turns probing `#117` / `#118` / `#101` / `sub_issues` / `comments`,
concluded "a defect in steer's bundled MCP server", and offered to file it with
`/steer:report` - a fixture bug that rule `00-router` § When steer itself misbehaves faithfully converted
into a false upstream report. The responder body now describes the whole backlog
plus the `comments` / `sub_issues` / `labels` projections, so a wrong number gets
a real not-found and the empty sub-issue lists stay the reason the triage case
recommends decomposition. It costs one model call per `issue_read`, which is the
price of a mock that answers its arguments.

Without them the plugin's bundled `github` server fails to connect (no
`github_pat` in the sandbox) and **every** run narrates
`400: Authorization header is badly formatted` instead of routing - the second
half of the same bug. `mise run evals` passes `--allow-tools` for the three read
tools; writes are deliberately never granted, since a routing case has no reason
to land a change.

One thing this deliberately does not fix, worth knowing when you read a number:

- **The baseline arm has no tracker at all.** The `github` server is the plugin's,
  so the no-plugin arm cannot read an issue however well it routes. `routed` is
  immune (there is no steer skill for it to invoke either way), but the `answer`
  grader's Δ partly reflects capability, not just routing.

The other known scoring bug here - the bootstrap nudge naming `/steer:setup`
while the case grepped for `steer:init`, so a run that answered `/steer:setup`
and stopped was routing correctly and scoring zero - is fixed: `routed` now
accepts the front door on both bootstrap cases.

**The fixture must not out-shout the ask.** Every scaffold pins `HEAD` to
`refs/heads/main` before its first commit (the sandbox has no
`init.defaultBranch`, so `git init` landed on `master` and every 2026-09-04 run
flagged the mismatch with the standards' `main`), and the managed variant carries
a `pyproject.toml`, a CI workflow and a `.gitignore` alongside `mise.toml` - in
that run every managed case, `next`, `spec` and `issues` included, led with "no
manifest / no CI / no .gitignore" before reaching the ask. The one finding the
managed fixture is *meant* to offer is the code defect (`total()` ignores
`quantity`), which is also what issue #123 describes. Silence from
`session-checks.sh` is still the contract; re-check it after any scaffold edit.

## Running

```shell
mise run evals                                           # whole suite, health settings
mise run evals -- --case 'routes-fix-issue-to-work'      # one case, still 3 runs
mise run evals -- --runs 1 --judge-model haiku           # cheap authoring loop
```

Two things that cost real runs while these cases were authored:

- **`--case` takes one glob, not a list.** A second `--case` silently *replaces*
  the first (the CLI keeps the last occurrence of an option), so three of them
  ran one case and reported "1 case(s)". Widen the glob -
  `--case 'routes-*-to-none'` - or run the tool once per case. `--tag` is the
  repeatable one.
- **Don't switch branches while a run is in flight.** The scaffold is read from
  the working tree per arm, so a checkout mid-run fails the second arm with
  `path "scaffold.sh" does not exist` and scores it 0 - which reads exactly like
  a baseline that could not answer.

**Run it through `mise`, not bare.** `claude plugin eval` on its own does not
exercise this suite: the task carries the flags that make a run mean something,
each commented in `mise.toml`.

| Flag | Why the suite needs it |
|---|---|
| `--scaffold` | runs each case's `scaffold.sh` (author-supplied bash, so opt-in). Without it a case measures an empty sandbox |
| `--ablation with-without` | adds the no-plugin baseline arm - the Δ is the whole point |
| `--allow-tools` (3 read tools) | the tracker stand-ins above; without the grant every managed run narrates a credential fault instead of routing |
| `--runs 3` | the per-case default is `runs: 1` so an ad-hoc run stays cheap, and at one run the result is noise: the same case has scored 0.6 / 0 / 0.6 / 0 / 0.6 across five identical runs, and the judge's majority-of-three vote flips on borderline prose |
| `--judge-model sonnet` | the `answer` grader reads exactly that borderline prose; the default `haiku` judge is too coarse for it - authoring the negatives measured that directly: `routes-explain-code-to-none` scored 0.60 under haiku (`answer`: FAIL FAIL FAIL) and 1.00 under sonnet, on a run whose `routed` grader passed both times |
| `--threshold 0.6` | gives the exit code meaning: exit 1 if any case scores below it. Default is `1.0`, which fails any imperfect case; `0.6` is exactly the `routed` grader's weight - "entered the right skill even if the prose judge docked it" |
| `--max-cost-usd 45` | runaway guard, sitting clear of the $25-30 a healthy sweep costs, so it aborts a runaway (exit 2, partial results) rather than a good run |
| `--no-publish` | keeps the HTML report local instead of publishing it to claude.ai (the CLI default where the account supports it). Forward `-- --publish-report` for the link |

Forwarded args override the task's defaults - the CLI takes the last occurrence of
an option - which is what the `--` forms above rely on.

**Read `aggregates.meanDelta`, not a single case's `passed`.** Every run writes
`report.html` + `aggregate-result.json` to `results/<ts>/` (gitignored); that JSON
is the same payload `--json <path>` writes, so there is no need to pass `--json`.
`--threshold` is a floor on the worst case, not the health number.

Deliberately **not** in `mise run ci` - the suite spends real tokens, the same
reason the `e2e` suite sits off the PR path. Budget roughly **$1.00-1.30 per case
per run** across both arms (measured at `max_turns: 12`; the with-plugin arm costs
~3× the baseline, which has no rules to read), so ~$12-15 for the suite at
`runs: 1` and ~$33-40 at the task's `runs: 3`. The task's `--max-cost-usd 60` is
sized against that: a ceiling near the expected spend aborts a healthy sweep, so
re-measure it whenever case count or a `max_turns` changes. Those two figures are
projected from the 9-case run: the three cases added since were piloted at
`--runs 1` and came in **under** the per-case estimate - `$0.94` for the status
case across both arms, `$0.37` and `$0.49` for the negatives, which answer in
1 and 6 turns.

## When it runs

Not on the PR path, so the cadence is declared rather than triggered:

- **Every minor or major release cut** - `/release` Phase A names it, and the
  release PR records the score. A patch release does not need it: the routing
  surface it reads (`rules/00-router.md` plus each skill's `description` +
  `when_to_use`) is what a minor bump moves.
- **Before merging a PR that edits that surface** - the router rule, a public
  skill's `description`/`when_to_use`, or a skill's public/internal tier.
  `check_routing_fixtures.py` runs on every such PR and is the cheap half; this
  is the half that can tell you the ask no longer lands.

`--case` narrows a run to what a change actually touched, which is the honest
way to make either of those affordable:

```shell
mise run evals -- --case 'routes-*-to-none' --runs 1
```

**`max_turns` is sized from real runs, per case, and the comment says why.** A
run killed with `Reached maximum number of turns` is scored on a truncated
message, which says nothing about routing - that is a zero the report cannot
distinguish from a misroute. 6 was far too tight; at 12, `adopt` still exhausted
its budget 3 runs out of 3 and `issues` once, so those two are higher (20 and
16). Raise a case's budget when its runs error, and record what you observed -
but check first whether the *skill* is the thing spending the turns: the adopt
overrun was a real plugin defect (template reads before the survey), not a
too-small budget.

## Availability

`claude plugin eval` is in **early access, enabled per organization**. Where the
rollout has not reached a machine it prints `plugin eval is currently in early
access` and exits. `mise.toml`'s `evals` task sets the enablement flag
(`CLAUDE_CODE_WALNUT_SPIRE=1`) itself, so the task works unchanged on machines
outside the rollout too (CI runners, gateways, telemetry-disabled clients).
Invoking the CLI directly needs that variable in your own environment. It only
lifts the preview gate - not a credential, and it grants nothing - and comes out
once the feature ships generally.

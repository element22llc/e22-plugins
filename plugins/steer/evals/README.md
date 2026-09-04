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
| `answer` | `llm` on `last_message` | 2 | it routes the way the standards route it, and does **not** start the named wrong workflow |

**Routing is asserted on the invocation; the answer is graded on
`last_message`.** Those are two different claims and they need two different
surfaces.

`routed` used to be a regex on `last_message`, and that was the wrong surface for
it. `rules/00-router.md` says "announce, then act", so the announcement lands in
the run's **first** message, and a finished skill's report names the skills that
come *next* — not itself. In the v6.1.0 run **15 of 24** with-plugin runs failed
`routed` while the `answer` judge passed them unanimously, and the single run that
scored full marks did so because it was killed immediately after its announce
line. The grader was measuring message shape.

Watching the `Skill` call is **not** the trace-grading mistake. The objection to
`target: trace` stands: the always-on ruleset names every skill, so any skill
matches somewhere in the injected text, and an early draft that graded the trace
passed cases it should have failed. But an invocation is an **action the run
took**, and the no-plugin arm has no steer skills to invoke — which is why
`routed` carries `arm: both` and stays scored in both arms. A bare
`tool_used: Skill` is auto-demoted to a with-only *indicator* and drops out of the
score, so the `arm: both` is load-bearing.

Two cases accept their **front door** as well as the specialized skill
(`steer:(init|setup)`, `steer:(adopt|setup)`), because rule `00-router` makes the
front door the correct route: "front doors detect context and hand off … so you
rarely route to a specialized skill directly." Discriminating init from adopt is
the `answer` grader's job, and its criteria name the wrong workflow explicitly.

**The `answer` grader judges what the run did, not what it recommends.** Every
readout ends with a handoff naming the *next* skill (`## Recommended next actions
— /steer:<skill>`, `Suggested command: /steer:…`), and rule `00-router` mandates
it. In the 2026-09-04 run the two `audit` and two `issues` responses the judge
failed were exactly the ones ending "Current recommended action: `/steer:work`" —
read as *starting* the wrong workflow — while the responses that passed skipped
the line. The criteria now say so in as many words. The same run had two
greenfield and one build **baseline** response pass with a homegrown spec-first
plan that never mentioned steer, so the "generic assistant" failure is now
concrete: a response that names no `/steer:*` skill fails, however good it reads.
Neither the JSON nor `report.html` carries the judge's rationale — only its
votes — so a judge failure is diagnosed by comparing the passing and failing
`last_message`s, which is how both of these were found.

**Every run is read-only, and each case says so** via an identical
`append_system_prompt`. Without it the answer is dominated by permission
narration — every run of the v6.1.0 suite opened by explaining what it could not
write — and the judge grades how well a run describes being blocked. The framing
is byte-identical across cases and applied to both arms, so it cannot bias the
comparison; `tests/test_eval_suite.py` enforces that. It carves the tracker tools
out **by name**: the first framing said "the network is unavailable" and granted
`mcp__github__*` in the same case, and the runs resolved the contradiction by
treating the tracker as dead — 0 tracker calls in 9 of 12 managed with-plugin
runs, `/steer:next` reporting it "unreadable here (no network)", and one
`fix issue #123` run guessing the bug from the code rather than reading the
issue. The framing does **not** tell the run to enter a skill: that would coach
the arm the suite exists to measure. A write-capable skill that is named in prose
and then done by hand in a read-only session is the routing defect the
2026-09-04 run surfaced (15 of 24 with-plugin runs, 12 of them naming the right
skill first), and the fix for it belongs in rule `00-router`, not here.

## Ablation is the point

The suite runs `--ablation with-without` by default: each case also runs a **no-plugin
baseline arm**, and the reported number is the delta. A case that scores well in both
arms proves nothing about steer — the model would have got there anyway. What counts
is Δ.

## The scaffolds

Each case builds its own repo from its own `scaffold.sh`. There are **three
variants**, because one fixture cannot serve every ask:

| Variant | Cases | Repo state | Why |
|---|---|---|---|
| `managed` | work, next, audit, spec, issues | complete, version-stamped spine + toolchain + code + tests | These asks presume a bootstrapped repo. Every session-start check is **silent** against it. |
| `greenfield` | init, build | `git init` + a README, nothing else | Their asks say "brand-new empty repo" / "build an app from my idea". |
| `legacy` | adopt | a Flask app, no spec, no toolchain, no tests | Its ask says "no spec, no toolchain". Unspecified code volume is what separates adopt from init. |

**Silence is the contract for `managed`.** A `foreign` spine (a `spec/` with no
`spec/.version`) makes `check-unmanaged-repo.sh` inject an adopt offer into every
run, and template gaps make `check-template-drift.sh` inject a reconciliation
notice — both then compete with the ask for the answer, and the case measures the
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

The managed scaffold stamps `spec/.version` with the plugin's **current** version
— a mismatch reads as version drift to `/steer:next` and injects a sync nudge.
`test_managed_scaffold_stamps_the_current_plugin_version` pins the two together,
so the release bump has to re-stamp the fixture.

## The tracker stand-in

`spec/tracker.md` declares GitHub, so the managed cases need a read path to it.
`mocks/github/` provides stand-ins for the three read-only tools the skills call —
`issue_read`, `list_issues`, `search_issues` — named after the server segment of
the tool name (`mcp__github__issue_read` → `mocks/github/issue_read.md`), with
`_tools.json` as the saved `tools/list` response. `--mocks` defaults to `record`,
which serves a stand-in wherever one exists.

**`list_issues` and `search_issues` are fixed responders** — the file body *is*
the canned result, which is cheap and perfectly deterministic for a call that
takes no discriminating argument.

**`issue_read` is an `type: agent` responder**, because it takes an
`issue_number` **and** a `method` and a fixed body ignores both. As a fixed
responder it returned issue #123 for every call, and the v6.1.0 runs noticed:
they spent turns probing `#117` / `#118` / `#101` / `sub_issues` / `comments`,
concluded "a defect in steer's bundled MCP server", and offered to file it with
`/steer:report` — a fixture bug that rule `97-self-report` faithfully converted
into a false upstream report. The responder body now describes the whole backlog
plus the `comments` / `sub_issues` / `labels` projections, so a wrong number gets
a real not-found and the empty sub-issue lists stay the reason the triage case
recommends decomposition. It costs one model call per `issue_read`, which is the
price of a mock that answers its arguments.

Without them the plugin's bundled `github` server fails to connect (no
`github_pat` in the sandbox) and **every** run narrates
`400: Authorization header is badly formatted` instead of routing — the second
half of the same bug. `mise run evals` passes `--allow-tools` for the three read
tools; writes are deliberately never granted, since a routing case has no reason
to land a change.

One thing this deliberately does not fix, worth knowing when you read a number:

- **The baseline arm has no tracker at all.** The `github` server is the plugin's,
  so the no-plugin arm cannot read an issue however well it routes. `routed` is
  immune (there is no steer skill for it to invoke either way), but the `answer`
  grader's Δ partly reflects capability, not just routing.

The other known scoring bug here — the bootstrap nudge naming `/steer:setup`
while the case grepped for `steer:init`, so a run that answered `/steer:setup`
and stopped was routing correctly and scoring zero — is fixed: `routed` now
accepts the front door on both bootstrap cases.

**The fixture must not out-shout the ask.** Every scaffold pins `HEAD` to
`refs/heads/main` before its first commit (the sandbox has no
`init.defaultBranch`, so `git init` landed on `master` and every 2026-09-04 run
flagged the mismatch with the standards' `main`), and the managed variant carries
a `pyproject.toml`, a CI workflow and a `.gitignore` alongside `mise.toml` — in
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

**Run it through `mise`, not bare.** `claude plugin eval` on its own does not
exercise this suite: the task carries the flags that make a run mean something,
each commented in `mise.toml`.

| Flag | Why the suite needs it |
|---|---|
| `--scaffold` | runs each case's `scaffold.sh` (author-supplied bash, so opt-in). Without it a case measures an empty sandbox |
| `--ablation with-without` | adds the no-plugin baseline arm — the Δ is the whole point |
| `--allow-tools` (3 read tools) | the tracker stand-ins above; without the grant every managed run narrates a credential fault instead of routing |
| `--runs 3` | the per-case default is `runs: 1` so an ad-hoc run stays cheap, and at one run the result is noise: the same case has scored 0.6 / 0 / 0.6 / 0 / 0.6 across five identical runs, and the judge's majority-of-three vote flips on borderline prose |
| `--judge-model sonnet` | the `answer` grader reads exactly that borderline prose; the default `haiku` judge is too coarse for it |
| `--threshold 0.6` | gives the exit code meaning: exit 1 if any case scores below it. Default is `1.0`, which fails any imperfect case; `0.6` is exactly the `routed` grader's weight — "entered the right skill even if the prose judge docked it" |
| `--max-cost-usd 45` | runaway guard, sitting clear of the $25–30 a healthy sweep costs, so it aborts a runaway (exit 2, partial results) rather than a good run |
| `--no-publish` | keeps the HTML report local instead of publishing it to claude.ai (the CLI default where the account supports it). Forward `-- --publish-report` for the link |

Forwarded args override the task's defaults — the CLI takes the last occurrence of
an option — which is what the `--` forms above rely on.

**Read `aggregates.meanDelta`, not a single case's `passed`.** Every run writes
`report.html` + `aggregate-result.json` to `results/<ts>/` (gitignored); that JSON
is the same payload `--json <path>` writes, so there is no need to pass `--json`.
`--threshold` is a floor on the worst case, not the health number.

Deliberately **not** in `mise run ci` — the suite spends real tokens, the same
reason the `e2e` suite sits off the PR path. Budget roughly **$1.00–1.30 per case
per run** across both arms (measured at `max_turns: 12`; the with-plugin arm costs
~3× the baseline, which has no rules to read), so ~$8–10 for the suite at
`runs: 1` and ~$25–30 at the task's `runs: 3`. The task's `--max-cost-usd 45` is
sized against that: a ceiling near the expected spend aborts a healthy sweep, so
re-measure it whenever case count or a `max_turns` changes.

**`max_turns` is sized from real runs, per case, and the comment says why.** A
run killed with `Reached maximum number of turns` is scored on a truncated
message, which says nothing about routing — that is a zero the report cannot
distinguish from a misroute. 6 was far too tight; at 12, `adopt` still exhausted
its budget 3 runs out of 3 and `issues` once, so those two are higher (20 and
16). Raise a case's budget when its runs error, and record what you observed —
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
lifts the preview gate — not a credential, and it grants nothing — and comes out
once the feature ships generally.

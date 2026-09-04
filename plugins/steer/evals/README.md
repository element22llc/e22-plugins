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

Each case runs the ask against a scaffolded steer-managed repo and scores two graders:

| Grader | Type | Weight | Asserts |
|---|---|---|---|
| `routed` | `regex` on `last_message` | 3 | the response reaches the owning skill — invoking it, or naming it as the owner when a decision is needed from the user first |
| `answer` | `llm` on `last_message` | 2 | it routes the way the standards route it, and does **not** start the named wrong workflow |

**Both grade `last_message`, never `trace`.** `rules/00-router.md` is injected into
every session and names every skill, so *any* skill matches somewhere in a trace —
grading the trace would measure whether the rules loaded, not where the ask went.
An early draft made exactly that mistake and passed cases it should have failed.

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
`mocks/github/` provides canned stand-ins for the three read-only tools the skills
call — `issue_read`, `list_issues`, `search_issues` — named after the server
segment of the tool name (`mcp__github__issue_read` → `mocks/github/issue_read.md`),
with `_tools.json` as the saved `tools/list` response and each `<tool>.md` body as
the canned result. `--mocks` defaults to `record`, which serves a stand-in wherever
one exists.

Without them the plugin's bundled `github` server fails to connect (no
`github_pat` in the sandbox) and **every** run narrates
`400: Authorization header is badly formatted` instead of routing — the second
half of the same bug. `mise run evals` passes `--allow-tools` for the three read
tools; writes are deliberately never granted, since a routing case has no reason
to land a change.

Two things this deliberately does not fix, both worth knowing when you read a
number:

- **The baseline arm has no tracker at all.** The `github` server is the plugin's,
  so the no-plugin arm cannot read an issue however well it routes. `routed` is
  immune (its pattern can only match plugin output), but the `answer` grader's Δ
  partly reflects capability, not just routing.
- **The bootstrap nudge names `/steer:setup` as the front door** for "set this
  repo up properly", while `routes-greenfield-bootstrap-to-init` greps for
  `steer:init`. Both are named in the notice, so the case can pass — but a run
  that answers `/steer:setup` and stops is routing correctly and scoring zero.

## Running

```shell
mise run evals                                   # whole suite, both arms
mise run evals -- --case 'routes-fix-issue-to-work'
mise run evals -- --runs 3                       # plugin health: see below
```

`--scaffold` and `--allow-tools` are required and the task passes both.

**For a health number, always pass `--runs 3` or more.** The per-case default is
`runs: 1` so an ad-hoc single-case run stays cheap, and at one run the result is
noise: the same case has scored 0.6 / 0 / 0.6 / 0 / 0.6 across five identical
runs, and the LLM grader's majority-of-three judge vote flips on borderline
prose. Read `aggregates.meanDelta` in `results/<ts>/aggregate-result.json`, not a
single case's `passed`.

Deliberately **not** in `mise run ci` — the suite spends real tokens, the same
reason the `e2e` suite sits off the PR path. Budget roughly **$1.00–1.30 per case
per run** across both arms (measured at `max_turns: 12`; the with-plugin arm costs
~3× the baseline, which has no rules to read), so ~$8–10 for the suite at
`runs: 1` and ~$25–30 at `runs: 3`. Cap a run you are unsure about with
`--max-cost-usd`; it aborts and reports partial results rather than overrunning.

## Availability

`claude plugin eval` is in **early access, enabled per organization**. Where the
rollout has not reached a machine it prints `plugin eval is currently in early
access` and exits. `mise.toml`'s `evals` task documents the enablement variable for
machines outside the rollout (CI runners, gateways, telemetry-disabled clients);
obtain it from your Anthropic contact rather than guessing.

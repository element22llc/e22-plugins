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

## The scaffold

Each case carries an **identical** `scaffold.sh` that builds a minimal managed repo
(git history, `CLAUDE.md`, a `/spec` spine with an approved feature and a GitHub
tracker). Without it the cases run in an empty temp dir rooted at `$HOME`, where the
correct answer to most asks is "there is nothing here" — measuring the sandbox, not
the routing.

The copies are byte-identical by contract (`tests/test_eval_suite.py` enforces it);
the tool requires `scaffold_script` to name a file **inside** the case directory, so
a single shared copy is not possible. Edit one, run the test, propagate.

## Running

```shell
mise run evals              # whole suite, with the no-plugin baseline arm
mise run evals -- --case 'routes-fix-issue-to-work'
```

`--scaffold` is required and the task passes it: it runs author-supplied bash as you,
so the flag is opt-in by design. Deliberately **not** in `mise run ci` — the suite
spends real tokens (~$0.55 per case at `runs: 1`, both arms), the same reason the
`e2e` suite sits off the PR path.

## Availability

`claude plugin eval` is in **early access, enabled per organization**. Where the
rollout has not reached a machine it prints `plugin eval is currently in early
access` and exits. `mise.toml`'s `evals` task documents the enablement variable for
machines outside the rollout (CI runners, gateways, telemetry-disabled clients);
obtain it from your Anthropic contact rather than guessing.

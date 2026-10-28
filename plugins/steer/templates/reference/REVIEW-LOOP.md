# The review-gated execution loop

The protocol behind `/steer:work --reviewed`, and behind the code gate `finish`
runs on its own. The loop takes a task and produces
a **vetted** result instead of a first draft, by inserting two *independent*
review gates - one on the plan, one on the diff - and a bounded fix loop around
the implementation step that `/steer:work` already owns.

This file owns the **shared logic**: the three disciplines, the per-gate rubric,
the stopping rules, and how the loop relates to the other execution skills. The
`/steer:work` skill owns the step-by-step: `finish` for the code gate, the
`--reviewed` mode for the plan gate.

---

## 1. Why a loop at all

A single straight pass - read prompt, plan in your head, implement, ship -
carries every misread of the requirement and every blind spot of the implementing
context straight into the output. The loop's value is that an **independent**
context, scoring against an **explicit** rubric, catches what the implementer
cannot see in its own work. Caught at the plan stage a flaw is cheap; caught in
the diff it is dearer; caught after merge, dearest. The loop front-loads that
catch.

The **plan gate is opt-in** (`--reviewed`): reach for it on work where a wrong
approach is costly to unwind. The **code gate runs by default** - `finish` runs
it on every Behavioral or High-risk change, Trivial work skips it. It is one
reviewer, not a loop of them, and its findings cost less before the push than
from the human reviewer after it.

## 2. The three disciplines (non-negotiable)

The loop degrades into theater without all three.

1. **Independence.** Each gate is a *fresh subagent* that never saw the rationale
   for the choices it reviews. A context that produced an artifact is anchored to
   its own reasoning and will confirm it. This is why each gate is a *separate*
   fresh general reviewer subagent - not "re-read your own work." §3 says what
   else the code gate may add, and why `steer-reviewer` cannot do the plan gate.
2. **Explicit rubric.** The reviewer scores against the **restated requirements**
   (what success means, spelled out) plus the **relevant steer rules** - not a
   vague "is this good?". A reviewer with no rubric emits generic feedback that
   never converges.
3. **Bounded exit.** Review loops have sharp diminishing returns: round 1 catches
   most, round 2 the tail, round 3+ is churn and sometimes introduces regressions.
   Cap the fix loop at **2 rounds**; exit as soon as a round surfaces no
   high-severity findings.

## 3. The two gates are different jobs

- **Plan gate** reviews the *approach*: does it satisfy the requirement, is it the
  right shape, what is missing, does it respect the repo's invariants. Highest
  return - a flawed plan is cheap to fix before code exists. The reviewer here is
  a **fresh independent subagent**, *not* `steer-reviewer`: that agent requires
  `path:line` evidence in existing code, which a prospective plan can't supply, so
  it would return nothing.
- **Code gate** reviews the *diff in its repo*: correctness, regressions,
  fidelity to the requirement, and what the diff alone hides - the sibling code
  the change should also have touched, the peers it should match, the risk it
  introduces. A fresh read-only subagent runs it against the §4 rubric; where the
  client has `/code-review`, run it alongside for a deeper correctness sweep.
  `steer-reviewer` is `Read`/`Grep`/`Glob`-only and has no git access, so it can
  check the **on-disk result against standards** but never "the diff" - keep
  that split. The gate runs after the local gates are green and before the first
  push, in both delivery modes.

## 4. Rubric shape per gate

Give the reviewer three things, every time:

- **Plan gate** - the plan text; the restated requirement; the steer rules the
  change touches (e.g. conventions, change classification, the relevant lifecycle rules).
  Ask for severity-ranked findings and an explicit "what is missing" pass (the
  plan is prospective, so the reviewer reasons about the approach rather than
  citing `path:line`s).
- **Code gate** - the restated requirement (the issue's acceptance criteria, the
  intent), the change class, the branch diff against its merge base, and read
  access to the whole repo. The rubric is rules `50-done`, `40-testing`,
  `80-change-class` and `85-practices`, plus `60-high-risk` for a High-risk
  change. Ask for five passes, skipping style the linters own:
  1. **Correctness and fidelity** - bugs, regressions, and whether the diff does
     what the requirement asks.
  2. **Other instances** - for every bug fixed or pattern changed, search the
     repo for the same shape. An unfixed sibling is a finding unless the PR
     names it out of scope.
  3. **Peer consistency** - compare each new file, module or unit with its
     nearest existing siblings: version pins, lockfiles, shared vs duplicated
     config, naming, layout. A deviation with no stated reason is a finding.
  4. **Introduced risk** - what can fail now that could not before: rollout
     order, a partial apply, a default that goes live, an import or migration
     path, a window between two steps.
  5. **Docs the diff touched** - complete and consistent with each other.

  It returns severity-ranked findings with `path:line`, and **design questions**
  apart: choices a reasonable reviewer would challenge, which the author answers
  in the PR rather than necessarily changing. `/steer:work review` hands its
  reviewers this same rubric, so the author's gate runs the review the human's
  agent will run. For standards-sensitive repos, `steer-reviewer` may also check
  the changed files against the standards.

Severity ranking is what makes the loop converge: **high** is what a reviewer
would block the merge on - fix every one; weigh **medium**, treat **low** as
optional. Only high-severity findings keep the fix loop open.

## 5. Where the loop sits among the skills

- **`/steer:work`** owns governed implementation - branch, commits, tests, PR,
  tracker - in GitHub-adopted repos. Its `--reviewed` mode *is* this loop: its
  **Implement** phase runs the same governed `start`->`finish` path, with the gates
  added around it. In
  prototype/local mode (no tracker) there is no `/steer:work`; apply this protocol
  directly around implementation, exactly as `/steer:build` does in that mode.
  In prototype mode neither gate is default; run them when asked.
- **`/steer:build`** is the PO-facing greenfield flow. In its governed mode it
  routes implementation through `/steer:work`; in its default prototype/local mode
  it implements directly.
- **`/code-review`** is the built-in diff reviewer the code gate adds where the
  client has it, for correctness depth; the rubric reviewer covers what it
  cannot see outside the diff.
- **`steer-reviewer`** is the shipped read-only subagent the code gate's optional
  standards check invokes explicitly (it cites `path:line` evidence in existing
  code, so it is *not* used for the plan gate) - the same explicit-invocation
  pattern `/steer:audit` and `/steer:audit spec` use. The plan gate uses a fresh
  general reviewer subagent instead.

## 6. Cost

Each gate spends tokens on top of the implementation. That is the price of a
vetted result, and the reason for the triage step (Trivial changes skip both gates)
and the 2-round cap. If a run stops at the cap with findings still open, say so
and name what was left - silent truncation reads as "all clear" when it was not.

## 7. Related: the Advisor tool (per-developer, optional)

Claude Code's [Advisor tool](https://code.claude.com/docs/en/advisor) is a
lighter-weight cousin of this loop. It pairs your main model with a stronger
**advisor model** that Claude consults *in-session* at decision points - before
committing to an approach, when stuck, or before declaring a task done: the same
escalate-hard-decisions instinct this loop encodes, minus the
independent-subagent gates and the diff review. They are not substitutes - reach
for the advisor for a fast in-context second opinion, and for `--reviewed` when a
wrong approach is costly to unwind and you want an adversarial, rubric-scored
check.

**steer does not configure it for you, by design.** `advisorModel` is a
per-developer, cost- and account-dependent preference, documented as
experimental (as of 2026-10), and it needs the Anthropic API - it is unavailable
on Amazon Bedrock, Google Cloud, Microsoft Foundry and Claude Platform on AWS,
and behind an LLM gateway only if the gateway forwards it intact - so it stays
out of the scaffold's checked-in `settings.json`, which would silently override
each teammate's choice. Enable it yourself with `/advisor <model>` (e.g.
`/advisor opus`, saved to your user settings) or `claude --advisor opus` for one
session.

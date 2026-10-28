# Context hygiene

The context-hygiene standard in full. The goal: long, multi-phase work
should not bloat or exhaust the main session, and task-specific constraints should
never be lost when the context compacts - **without** the user having to notice and
intervene.

## The honest boundary - what a plugin and the model cannot do

A Claude Code plugin (hooks, rules, skills) and the model itself operate under hard
limits here. Designing around them keeps the guidance truthful:

- **No running context-window visibility.** No hook event fires as the window
  fills. The fill percentage reaches only the user's status line
  (`context_window.used_percentage`) and `/context`, and a plugin cannot ship the
  main status line; token counts reach hook input only at a resume, a fork or a
  model switch (Claude Code docs, as of 2026-10). steer therefore cannot
  *detect* that the window is getting heavy.
- **No trigger.** Hooks communicate only through stdout/stderr/exit codes - they
  cannot invoke `/` commands. Neither a hook **nor the model** can start a
  `/compact` or open a new session. Both are strictly user-initiated.
- **`PreCompact` cannot preserve content.** It can block compaction or react to it,
  but it cannot inject "keep this" into the summary.

So "steer notices the window is full and switches sessions for you" is impossible.
The mechanisms below make that switch *unnecessary* instead.

## 1. Delegate a bounded run to a subagent

The default is **one loop**: this context plans the work, runs it, and keeps every
result where the next step can use it. Skills and `/steer:reference` already load
procedure on demand, so a long task rarely needs a second context to stay lean.
Every fork has a price: the caller gets a summary back, not what the subagent saw,
and waits on a nested loop.

A subagent runs with its **own fresh context window by construction** and returns
only its result to the caller. Fork only when one of these holds:

- **The transcript is bloat** - a search or read sweep whose only useful output is
  its conclusion (locate code, grep-and-summarize, a broad audit, a regeneration
  pass), and which would otherwise fill this context. You cannot measure the
  window (above), so judge by the output: little that comes back, much read to
  get it.
- **The units are independent** - N pieces (per-dimension, per-feature, per-PR)
  that each need little from the rest, can run in parallel, and whose context is
  discarded once their result is in.
- **The review must be independent** - a gate that must not see the reasoning
  behind what it reviews (`REVIEW-LOOP.md` section 2).

**Keep connected work in one context.** A multi-phase run whose later steps build
on earlier results - investigate, then design, then implement - stays here,
however long: split it and each handoff drops the detail the next phase needed.
Split by context, never by problem type.

The default, the lossy-handoff cost and the split-by-context rule follow
Anthropic's [When to fold subagents into your main agent
loop](https://claude.com/resources/articles/building-agents-when-to-fold-subagents-into-your-main-agent-loop)
(2026-10-22). It keeps subagents for context bloat, parallel discardable tasks,
and an agent confused by too many tools or conflicting instructions; steer meets
the last case with on-demand skills instead. The review case is its black-box
verification advice.

**What to bring back.** Return only the **structured result** (findings with
evidence fingerprints, a verdict, a path to a written artifact) - never the full
transcript of the sweep. The point of forking is that the heavy intermediate context
stays in the subagent and dies with it.

**Which model.** The delegated subagent's model is a cost lever, and the fork
reasons above want different tiers:

- **Read/search/summarize fan-out** (a bloat sweep, or independent units that
  only read - locate code, grep-and-summarize, gather per-file facts, then return a
  conclusion) -> run on a **cheaper model at lower effort** where the
  delegation lets you pick one. Its failure mode - occasionally missing a file - is cheap for the vetting
  caller to catch, and the read volume is the same either way, so this cuts
  *cost*, not token count.
- **Reviewer / verify / judge delegations** (the examples below) -> keep on the
  **session model** (`inherit`). A missed or mis-ranked finding here
  is expensive and hard to catch downstream, so don't trade capability for cost at the
  step whose whole job is to be trustworthy.

One caveat: a cheaper model inside a **budget-capped agentic loop** can take more
iterations and burn both the wall-clock and the saving - keep those on the session
model, or cap turns tightly. A pure read-and-return fan-out has no such loop.

**The canonical steer examples to follow (all reviewer delegations - session-model):**

- `/steer:audit` fans out one read-only `steer-reviewer` subagent per dimension on
  large repos, then vets the gathered summaries.
- `/steer:audit spec` fans out one reviewer per feature for large drift comparisons.
- `/steer:work --reviewed` spawns a **fresh reviewer subagent** for its plan gate -
  a separate context given the plan, the restated requirements, and the steer rules
  as the rubric.
- `/steer:work finish` spawns one for its code gate on every non-Trivial change,
  given the branch diff and the `REVIEW-LOOP.md` section 4 rubric.
- the `/steer:loop` scaffolded workflow spawns one **unconditionally** - rule
  `53-autonomous-loops` splits ideation from verification, so the reviewer that
  checks the loop's work is never the context that produced it.

## 2. Keep durable state in files, not the chat

What survives compaction (and a brand-new session) is what lives on disk:
`CLAUDE.md`, the `rules/*` (re-injected by the SessionStart hook, whose matcher
includes `compact`), auto-memory, and the `/spec/**` artifacts. Conversation prose
does **not** survive.

Surviving is not the same as belonging. Auto memory
(`~/.claude/projects/<project>/memory/`) persists across sessions and worktrees,
but it is local to one developer's machine - invisible to the repo, the PR, and
every teammate - so it is working notes, **never the team's record**. Don't offer
to save a finding to auto memory as a substitute for capturing it on disk. Route
each durable project fact to its canonical home **by type** instead: a **bug fix**
-> a regression test (Testing / Definition of done); an **operational or behavioral
fact** -> the app guide or a `/spec/history/` entry (Living docs); an **unresolved
bug or follow-up** -> a linked tracker issue (Issue-first); a **durable design
decision** -> the spine (Decision capture); a **team convention** ("always use
pnpm", "the API tests need Redis") -> the product `CLAUDE.md`, which holds
team-learned patterns. Each fact lands in exactly one home, and that capture is
surfaced rather than offered as an optional "want me to remember this?".

Auto memory keeps what is **personal**: one developer's role, expertise and
working preferences ("terse answers", "explain the SQL"). Those have no repo home
and steer leaves them where Claude Code puts them. When a user says "remember X"
and X is about the project, it is one of the routes above, not a memory write -
say where it landed. A recalled memory is a hint, not truth: where it contradicts
the spec, `CLAUDE.md` or the code, the repo wins, and the stale memory is fixed or
deleted.

So **run-state and task-specific constraints belong in a file the work re-reads**,
never only in the chat:

- **Run-state / flow position** -> a status artifact. `/steer:build` keeps flow state
  in `/spec/BUILD-STATUS.md`; `/steer:work` keeps the issue, branch, and session
  breadcrumbs in its `spec/.work/<branch>.md` marker. Resuming reads the file first.
- **Decisions and constraints** -> the durable spine (`/spec/features/*/intent.md`,
  `/spec/decisions/` ADRs, `/spec/history/`) or a purpose-built sidecar the run
  reads on entry.

A sidecar is just a small structured file that travels with the data instead of the
conversation. Example shape for a regeneration run:

```json
{
  "regeneration_policy": {
    "holes": "flag_or_skip",
    "contours_with_holes": "do_not_synthesize",
    "expect_validate": ["simple_plates"]
  }
}
```

Now any session - fresh or compacted - picks the constraint up; nothing depends on
the assistant "remembering" it.

## 3. Fallback nudge - only when genuinely overloaded

When the thread is loaded with unrelated context and delegation won't help (e.g. the
heavy work *is* the current conversation), the only remaining lever is to
**recommend** the user act - because you cannot:

1. Say plainly that `/compact` or a fresh session is the user's call, not something
   you can perform.
2. **Pre-compose the hand-off** so acting is one step: the artifact path to reopen
   and the exact constraints to carry across. A fresh session starts blind - the
   hand-off is what stops the constraints from being lost.

Keep this rare. The default is silent: fork a sweep that qualifies (section 1) and write
state to a file, so the nudge is seldom needed.

**Concrete heuristics to include in the recommendation** - community-validated
rules of thumb the user acts on (you cannot):

- **A focused context answers better.** `/clear` between unrelated tasks; to
  compact earlier than the default, `/autocompact <tokens>` sets the threshold,
  and `/context` shows the current fill.
- **Rewind beats correcting.** Rolling back (double-Esc / `/rewind`) to just
  before a failed attempt and re-prompting outperforms leaving the failed
  attempt plus its correction in the window.
- **A guided `/compact` beats an automatic one.** Suggest the focus hint
  verbatim - e.g. `/compact keep the auth-refactor decisions, drop the test
  debugging` - so the summary keeps exactly what the next step needs.
- **A genuinely new task deserves a fresh session**, seeded with the
  pre-composed hand-off; a follow-up on the same task can stay in this one.

## Worked example - the part-regeneration scenario

A run analyzes an `extraction.json`, produces a verdict ("positioned holes are
unreliable -> flag/skip; simple plates will validate"), then regenerates parts.

- **Without context hygiene:** the verdict and its constraints live only in the chat;
  the heavy regeneration run inflates the same context; if it compacts or the user
  opens a fresh session, the "holes unreliable" constraint is lost and the run may
  fabricate geometry.
- **With context hygiene:** the verdict step writes `regeneration_policy` into the
  artifact (section 2). The regeneration is delegated to a subagent (section 1) seeded from that
  policy, returning only the validated/flagged/skipped report. It qualifies because
  the policy file carries everything the regeneration needs, so the handoff loses
  nothing. The main context stays
  lean, the constraint travels with the data, and the user just approves - no fresh
  session, no re-typing. Only if the whole thread were already overloaded would you
  fall back to recommending `/compact` with the policy path as the hand-off (section 3).

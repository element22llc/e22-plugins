# Context hygiene

Full reference for rule `26-context-hygiene`. The goal: long, multi-phase work
should not bloat or exhaust the main session, and task-specific constraints should
never be lost when the context compacts — **without** the user having to notice and
intervene.

## The honest boundary — what a plugin and the model cannot do

A Claude Code plugin (hooks, rules, skills) and the model itself operate under hard
limits here. Designing around them keeps the guidance truthful:

- **No context-window visibility.** No hook event and no environment variable
  exposes token count or percentage of the budget consumed. Only the user can see
  it, by running `/context`. steer therefore cannot *detect* that the window is
  getting heavy.
- **No trigger.** Hooks communicate only through stdout/stderr/exit codes — they
  cannot invoke `/` commands. Neither a hook **nor the model** can start a
  `/compact` or open a new session. Both are strictly user-initiated.
- **`PreCompact` cannot preserve content.** It can block compaction or react to it,
  but it cannot inject "keep this" into the summary.

So "steer notices the window is full and switches sessions for you" is impossible.
The mechanisms below make that switch *unnecessary* instead.

## 1. Delegate heavy runs to a subagent (the primary lever)

A subagent runs with its **own fresh context window by construction** and returns
only its result to the caller. That is the "fresh session" — automatic, invisible,
and requiring no decision from the user.

**When to fork.** Delegate when a run is:

- **long or multi-phase** — many steps, each producing intermediate output the final
  answer doesn't need (a broad audit, a migration sweep, a regeneration pass); or
- **search-heavy** — would otherwise fill this context with grep/read transcript; or
- **fan-out-shaped** — N independent units (per-dimension, per-feature, per-file)
  that can each be reviewed in isolation.

Below that bar, run inline — the coordination overhead of a subagent isn't worth it
for a short, interactive task.

**What to bring back.** Return only the **structured result** (findings with
evidence fingerprints, a verdict, a path to a written artifact) — never the full
transcript of the sweep. The point of forking is that the heavy intermediate context
stays in the subagent and dies with it.

**Which model.** The delegated subagent's model is a cost lever, and the two
delegation shapes above want different tiers:

- **Read/search/summarize fan-out** (the *search-heavy* and *fan-out-shaped* runs —
  locate code, grep-and-summarize, gather per-file facts, then return a conclusion) →
  run on a **Sonnet-tier model at low effort**. This is the profile where Sonnet lands
  closest to Opus, and its failure mode — occasionally missing a file — is cheap for
  the vetting caller to catch. Sonnet is cheaper per token and the read volume is the
  same either way, so this cuts *cost*, not token count.
- **Reviewer / verify / judge delegations** (the examples below) → keep on the
  **session model** (`inherit`, i.e. Opus-tier). A missed or mis-ranked finding here
  is expensive and hard to catch downstream, so don't trade capability for cost at the
  step whose whole job is to be trustworthy.

One caveat: a cheaper model inside a **budget-capped agentic loop** can take more
iterations and burn both the wall-clock and the saving — keep those on the session
model, or cap turns tightly. A pure read-and-return fan-out has no such loop.

**The canonical steer examples to follow (all reviewer delegations — session-model):**

- `/steer:audit` fans out one read-only `steer-reviewer` subagent per dimension on
  large repos, then vets the gathered summaries.
- `/steer:audit spec` fans out one reviewer per feature for large drift comparisons.
- `/steer:work --reviewed` spawns a **fresh reviewer subagent** for its plan gate —
  a separate context given the plan, the restated requirements, and the steer rules
  as the rubric.

## 2. Keep durable state in files, not the chat

What survives compaction (and a brand-new session) is what lives on disk:
`CLAUDE.md`, the `rules/*` (re-injected by the SessionStart hook, whose matcher
includes `compact`), auto-memory, and the `/spec/**` artifacts. Conversation prose
does **not** survive.

Surviving is not the same as belonging. Private auto-memory persists, but it is
local to one developer's machine — invisible to the repo, the PR, and every
teammate — so it is working notes, **never the team's record**. Don't offer to save
a finding to session memory as a substitute for capturing it on disk. Route each
durable fact to its canonical home **by type** instead: a **bug fix** → a regression
test (Testing / Definition of done); an **operational or behavioral fact** → the app
guide or `/spec/HISTORY.md` (Living docs); an **unresolved bug or follow-up** → a
linked tracker issue (Issue-first); a **durable design decision** → the spine
(Decision capture). Each fact lands in exactly one home, and that capture is
surfaced rather than offered as an optional "want me to remember this?".

So **run-state and task-specific constraints belong in a file the work re-reads**,
never only in the chat:

- **Run-state / flow position** → a status artifact. `/steer:build` keeps flow state
  in `/spec/BUILD-STATUS.md`; `/steer:work` keeps the issue, branch, and session
  breadcrumbs in its `spec/.work/<branch>.md` marker. Resuming reads the file first.
- **Decisions and constraints** → the durable spine (`/spec/features/*/intent.md`,
  `/spec/decisions/` ADRs, `/spec/HISTORY.md`) or a purpose-built sidecar the run
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

Now any session — fresh or compacted — picks the constraint up; nothing depends on
the assistant "remembering" it.

## 3. Fallback nudge — only when genuinely overloaded

When the thread is loaded with unrelated context and delegation won't help (e.g. the
heavy work *is* the current conversation), the only remaining lever is to
**recommend** the user act — because you cannot:

1. Say plainly that `/compact` or a fresh session is the user's call, not something
   you can perform.
2. **Pre-compose the hand-off** so acting is one step: the artifact path to reopen
   and the exact constraints to carry across. A fresh session starts blind — the
   hand-off is what stops the constraints from being lost.

Keep this rare. The default is silent: fork the heavy run and write state to a file,
so the nudge is seldom needed.

**Concrete heuristics to include in the recommendation** — community-validated
rules of thumb the user acts on (you cannot):

- **Quality drops well before the window is full.** Practitioners treat ~40%
  context fill as the onset of degradation and act at or below it; `/context`
  is where the user reads the number.
- **Rewind beats correcting.** Rolling back (double-Esc / `/rewind`) to just
  before a failed attempt and re-prompting outperforms leaving the failed
  attempt plus its correction in the window.
- **A guided `/compact` beats an automatic one.** Suggest the focus hint
  verbatim — e.g. `/compact keep the auth-refactor decisions, drop the test
  debugging` — so the summary keeps exactly what the next step needs.
- **A genuinely new task deserves a fresh session**, seeded with the
  pre-composed hand-off; a follow-up on the same task can stay in this one.

## Worked example — the part-regeneration scenario

A run analyzes an `extraction.json`, produces a verdict ("positioned holes are
unreliable → flag/skip; simple plates will validate"), then regenerates parts.

- **Without context hygiene:** the verdict and its constraints live only in the chat;
  the heavy regeneration run inflates the same context; if it compacts or the user
  opens a fresh session, the "holes unreliable" constraint is lost and the run may
  fabricate geometry.
- **With context hygiene:** the verdict step writes `regeneration_policy` into the
  artifact (§2). The regeneration is delegated to a subagent (§1) seeded from that
  policy, returning only the validated/flagged/skipped report. The main context stays
  lean, the constraint travels with the data, and the user just approves — no fresh
  session, no re-typing. Only if the whole thread were already overloaded would you
  fall back to recommending `/compact` with the policy path as the hand-off (§3).

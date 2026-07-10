<!-- steer:inject-when=code-project -->
## Autonomous loops — automate the navigation, never the authority

An **autonomous loop** is a scheduled automation (a cron workflow, a Routine)
that wakes on its own, discovers work — CI failures, open issues, drift — and
drives it through steer's skills without a human in each turn. A loop removes the
prompting, **not** the responsibility: your job is still to ship code you
*confirmed* works (Definition of done, Verify loop).

- **A loop closes only up to a human gate — never through one.** It may discover,
  triage, draft in an isolated worktree, run the verify loop, and open a **draft**
  PR. It **stops** at every authority gate this manual already sets: creating
  issues beyond an explicit ask (Issue-first), ratifying an ADR (High-risk), and
  push-to-shared / merge / deploy / real secrets (Commit autonomy, High-risk).
  Automating navigation never relaxes what a step is allowed to do.
- **Split ideation from verification.** The agent that drafts a change must not be
  the one that clears it — route the check through an independent reviewer
  (`steer-reviewer`, `/steer:audit`, the test harness), never the drafting agent's
  own say-so.
- **Keep durable state outside the model.** A loop forgets between runs; its memory
  is the tracker + `/spec/**` (issues, `HISTORY.md`), not chat context. Record what
  it did and what's left there, so the next run resumes instead of repeating.
- **Only loop on checkable work.** Same bound as the Verify loop — judgment calls,
  design decisions, and long-compute runs have no fast pass/fail and are never a
  loop's to close: it surfaces them for a human, it does not decide them.
- **Scaffold loops with `/steer:loop`**, which emits the scheduled workflow wired to
  these limits. Don't hand-roll an automation that can cross a gate.

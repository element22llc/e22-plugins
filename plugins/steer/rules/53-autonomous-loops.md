<!-- steer:inject-when=code-project -->
## Autonomous loops — automate the navigation, never the authority

An **autonomous loop** is a scheduled automation (a cron workflow, a Routine)
that wakes on its own, discovers work — CI failures, open issues, drift — and
drives it through steer's skills unattended. It removes the prompting, **not**
the responsibility: still ship code you *confirmed* works (Definition of done).

- **A loop closes only up to a human gate — never through one.** It may
  discover, triage, draft in an isolated worktree, verify, push its **own work
  branch**, and open a PR — the merge review is the human gate (Commit
  autonomy). It **stops** at every authority gate: issue creation beyond an
  explicit ask (Issue-first), ADR ratification (High-risk), and merge / deploy
  / push to `main` or any protected branch / real secrets. Loop-opened PRs are
  **drafts by convention** — the deliberate signal that nobody attended the
  run; a reviewer flips one to ready.
- **A loop presupposes PR flow.** Protect `main` first (`/steer:protect`);
  never point a loop at a solo-trunk repo — unattended direct-to-`main`
  delivery has no gate at all.
- **Split ideation from verification.** The drafting agent never clears its own
  change — route the check through an independent reviewer (`steer-reviewer`,
  `/steer:audit`, the test harness).
- **Keep durable state outside the model.** A loop's memory is the tracker +
  `/spec/**` (issues, `HISTORY.md`), not chat context — record what it did and
  what's left so the next run resumes instead of repeating.
- **Only loop on checkable work.** Judgment calls, design decisions, and
  long-compute runs have no fast pass/fail — the loop surfaces them for a
  human, it never decides them.
- **Scaffold loops with `/steer:loop`** — never hand-roll an automation that
  can cross a gate.

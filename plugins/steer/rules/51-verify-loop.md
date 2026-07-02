<!-- steer:inject-when=code-project -->
## Verify loop — iterate against the harness, don't flail

Before writing code, turn the task into a **verifiable end state** — name the
check that will prove it done (a failing test, a build that passes, a command
whose output you can read). "Add validation" becomes "tests for the bad inputs,
then make them pass." A vague goal you can't check is a goal you can't finish.

- **State the assumption, don't bury it.** When a request has two readings,
  surface the one you're taking (or ask) **before** writing against it — never
  silently pick an interpretation and build 200 lines on it.
- **Loop until green, then stop.** Run the harness (test, lint, typecheck,
  build), fix what it reports, re-run — until it passes. The harness is the
  judge, not your reading of the diff.
- **Cap the loop.** Bound the fix→re-run cycles; if repeated attempts don't
  converge, **stop and report what blocked you** with the failing output — don't
  thrash or paper over the check (see Testing: never delete/skip a failing test).
- **Never loop on uncheckable work.** Judgment calls, design decisions, and
  long-compute runs (training, large sweeps, deploys) have no fast pass/fail —
  those are a human's call or a one-shot script, never an open-ended loop.

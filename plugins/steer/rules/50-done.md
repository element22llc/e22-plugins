<!-- steer:inject-when=code-project -->
## Definition of Done

A change is done when **all five** of these hold:

- [ ] **Intent understood** - you can state what the change is for, and it is the change that was asked for.
- [ ] **Appropriately tested** - Testing rules; a bug fix carries a regression test that fails before and passes after.
- [ ] **CI green** - watched to conclusion after push, not assumed.
- [ ] **The contracts and docs this change actually affected are updated** - the ones this diff made wrong, not a survey of every artifact.
- [ ] **Merge and deploy went through the required human gates.**

That is the whole list. Everything else you owe a change is canonical in its own
rule and named, not restated here. Ceremony scales with the change (Change
classification). CI enforces only a thin floor, and in **solo-trunk** that floor
is the *only* automated backstop. Under a declared production hotfix these are
**deferred** to the mandatory follow-up, never waived.

### Verify loop - iterate against the harness, don't flail

Before writing code, name the check that will prove the task done - a failing
test, a passing build, a command whose output you can read. A goal you can't
check is a goal you can't finish.

- **State the assumption, don't bury it.** Two readings of a request -> surface
  the one you're taking, or ask, **before** writing 200 lines against it.
- **Loop until green, then stop**, and **cap the loop**: run the harness, fix
  what it reports, re-run; if attempts stop converging, **report what blocked
  you** with the failing output. Never thrash, never paper over the check, and
  never loop on uncheckable work - a judgment call or a long-compute run has no
  fast pass/fail.

### Drift gates - surface before merge

Drift - any mismatch along intent <-> spec <-> contract <-> tracker <-> app docs
<-> tests <-> delivered behavior - is resolved by **explicit human review, never
silently**: you surface it before merge, the reviewer resolves it. Flag these
classes in the PR the moment you notice one (its template carries the
checklist): **intent drift · contract drift · undocumented
behavior change · security-sensitive · compliance-impacting · operational
(deploy/CI/infra) · local setup or deployment changed · app docs invalidated ·
architecture/stack drift (`ARCHITECTURE.md`)**. A flagged class blocks merge
until the reviewer resolves it - you may not waive your own flag. The advisory
`spec-drift` CI job warns when behavior changes without its `contract.md`; a
warning is a prompt, not a substitute for the flag. Sweeps: `/steer:audit`.

The workflow is **aligned with** SOC 2 / ISO 27001 delivery expectations - say
"aligned", never "compliant": certification scope and production-readiness
approval stay with humans. The artifacts are the evidence, so keep the chain
intact.

### End-of-session checklist

Before wrapping up, run this and report **only the open items**, one line each -
a clean checklist is one sentence, never the list echoed back with ticks. If an
item can't be satisfied, say so rather than implying the work is complete.

- [ ] The five Definition of Done items hold for every change this session?
- [ ] Unfinished work and known gaps surfaced explicitly?
- [ ] Dev servers and watchers you started stopped, and `mise run docker:clean` run if a worktree is closing?
- [ ] GitHub-adopted repo: the active issue reflects progress, blockers and validation; unrelated findings filed as linked issues; the PR references it with the right closing relation?
- [ ] Scaffold placeholders flagged or resolved?
- [ ] Everything finished committed, and a complete change pushed with its PR open - or the trunk commit pushed in solo-trunk - with CI watched to green?
- [ ] Solo trunk, no waiver, and the MVP works, you deployed, or a second contributor joined -> `/steer:protect`?

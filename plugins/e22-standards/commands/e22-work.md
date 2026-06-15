---
description: "Execute a GitHub issue end-to-end from local Claude Code — validate, claim, branch, load specs, implement, test, update the issue, open the PR, and transition lifecycle state. The execution counterpart to /e22-issues; routes tracker I/O through /e22-tracker-sync. One issue per branch/PR by default."
argument-hint: "[start | resume | status | finish] [#issue ...]"
---

Execute work from a GitHub issue by following the `e22-work` skill.

First read `/spec/tracker.md`: this skill requires `system: github` — if the
tracker is something else, say so and stop. If a code/config/behavior change was
requested with **no issue named**, find-or-create one first (Issue-first), then
start. Route all issue reads/writes through `/e22-tracker-sync`; git and PR
delivery follow the repo's commit/PR-autonomy rules (merge/deploy never implied).

Then run the requested mode:

- **start #N** — validate + claim the issue, create/reuse the branch, load linked
  specs, begin implementation. Detect and refuse to override a conflicting claim
  or branch.
- **resume #N** — reconstruct issue/branch/PR/validation context, reconcile stale
  markers, continue from the actual state.
- **status #N** — read-only: state, claimant, branch, PR, blockers, spec
  readiness, outstanding validation.
- **finish #N** — run validation, update progress, commit/push/open-or-update the
  PR when authorized, transition to `validate`. Never `done` just because a PR
  opened (`done` ⇔ a closed issue).

Defaults: one branch + PR per issue; branch `issue/<number>-<slug>` when the repo
has no convention; discovered out-of-scope work becomes a separate linked issue.
References: `ISSUE-WORKFLOW.md`, `ISSUE-SCHEMA.md`.

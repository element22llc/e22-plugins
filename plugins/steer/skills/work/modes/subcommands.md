# `/steer:work` — the four subcommands in full

Read this file before executing a subcommand. The guardrails, preconditions,
authorization scope, delivery mode, closing-ref rule, completion semantics,
branch naming, concurrency rules, and the recommended-next-actions block stay in
`SKILL.md` and govern all four.

## Subcommands (distinct, idempotent)

- **`start #N`** — resolve + validate the issue (actionable? readiness met for
  its kind per `ISSUE-WORKFLOW.md`?); detect a conflicting claim or branch;
  **claim** it (`assign` the invoking GitHub user — self-assign — + set
  `steer:claimed-by`, `transition` → `in-progress`);
  **(pr-flow)** create or reuse the branch and **write the local work marker**
  `spec/.work/<branch>.md` (slashes → underscores) in the marker format below, so
  the end-of-turn Stop-hook reconciliation recognizes the branch as
  issue-governed — **in solo-trunk, skip both: stay on `main`, no marker**;
  load linked specs (`steer:spec-path`, acceptance criteria);
  begin implementation.
- **`resume #N`** — reconstruct context from the issue + recorded `steer:branch` /
  `steer:pull-request` + working tree; reconcile stale markers (e.g. a recorded
  branch that no longer exists, a PR that merged/closed while away). **If the
  marker's session list (below) has a head session different from the current
  one, surface it as a context source** — offer `claude --resume <id>` to re-enter
  that conversation, and (if present) the transcript located by globbing
  `"$CLAUDE_CONFIG_DIR"/projects/*/<id>.jsonl`. Treat it as a best-effort
  breadcrumb, never authority: the session may be gone or on another machine, so
  fall back cleanly to reconstruction from the issue + tree. Then record the
  current session at the head of the list. Continue from the actual lifecycle
  state.
- **`status #N`** — **read-only**: report state, claimant, branch, PR, blockers,
  spec readiness, and outstanding validation. Mutates nothing.
- **`finish #N`** — run the required validation; update progress (managed block +
  comment); commit, push, and open-or-update the PR (autonomous — Commit
  autonomy; merge is not yours); **then watch CI
  to conclusion** (`gh pr checks --watch`) before transitioning. The first push of
  the new `issue/<n>` branch sets the upstream — `git push -u origin <branch>` —
  or it fails with `no upstream branch`; later pushes are a plain `git push`. **In solo-trunk,
  there is no PR: commit straight to `main` with a `Closes #N` trailer (see
  Closing ref if the tracker lives elsewhere) and watch
  CI on the trunk push** (`gh run watch`) the same way — the closed issue, not a
  merged PR, is the terminal evidence. On a red build,
  diagnose and fix it as part of the same unit of work — re-push and re-watch —
  until checks are green or a remaining failure is
  legitimately non-blocking (and said so). Only transition to `validate` once CI is
  green; hand the reviewer a green PR, not a running or red one. A PR-scoped failure
  is fixed or commented on the PR, **not** filed as a tracker issue — defer to the
  CI-failure triage in `ISSUE-WORKFLOW.md` (only a reproducible default-branch
  failure becomes a `source:ci` bug). **Never mark `done` merely because a PR was
  opened.** If you have stepped away, the in-turn watch blocks the turn; re-enter
  monitoring via the harness `/loop` over `gh pr checks` or a background watch —
  steer ships no background poller.

Natural language (`Fix the export bug`, `work #123`) may orchestrate `start`
through `finish`, but the phases stay distinct and idempotent — re-running a
phase reconciles rather than duplicates.

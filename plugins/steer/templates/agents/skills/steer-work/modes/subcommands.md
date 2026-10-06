# `/steer-work` - the four subcommands in full

Read this file before executing a subcommand. The guardrails, preconditions,
authorization scope, delivery mode, closing-ref rule, completion semantics,
branch naming, concurrency rules, and the recommended-next-actions block stay in
`SKILL.md` and govern all four.

## Subcommands (distinct, idempotent)

- **`start #N`** - resolve + validate the issue (actionable? readiness met for
  its kind per `ISSUE-WORKFLOW.md`?); detect a conflicting claim or branch;
  **claim** it (`claim` - self-assign the invoking GitHub user + set
  `steer:claimed-by` - then `update-state` -> `in-progress`);
  **(pr-flow)** create or reuse the branch and **write the local work marker**
  `spec/.work/<branch>.md` (slashes -> underscores) in the format `WORK-MARKER.md`
  defines (§ Marker format), so
  the end-of-turn Stop-hook reconciliation recognizes the branch as
  issue-governed - **in solo-trunk, skip both: stay on `main`, no marker**;
  load linked specs (`steer:spec-path`, acceptance criteria); **check prior
  learnings** - grep `spec/learnings/*.md` frontmatter (`area:`, `symptoms:`,
  `applies_when:`) for terms from the issue and the paths you expect to touch,
  and read only the files that match (no directory, nothing to do);
  begin implementation.
- **`resume #N`** - reconstruct context from the issue + recorded `steer:branch` /
  `steer:pull-request` + working tree; reconcile stale markers (e.g. a recorded
  branch that no longer exists, a PR that merged/closed while away). **If the
  marker's session list (`WORK-MARKER.md` § Claude Code sessions) has a head
  session different from the current
  one, surface it as a context source** - offer `claude --resume <id>` to re-enter
  that conversation, and (if present) the transcript located by globbing
  `"$CLAUDE_CONFIG_DIR"/projects/*/<id>.jsonl`. Treat it as a best-effort
  breadcrumb, never authority: the session may be gone or on another machine, so
  fall back cleanly to reconstruction from the issue + tree. Then record the
  current session at the head of the list. Continue from the actual lifecycle
  state.
- **`status #N`** - **read-only**: report state, claimant, branch, PR, blockers,
  spec readiness, and outstanding validation. Mutates nothing.
- **`finish #N`** - run the required validation **locally, before any push**:
  the fullest gate `mise tasks` lists (`mise run ci`, else `mise run check`,
  else the repo's lint, typecheck and test tasks), fixed until green. **CI is
  the confirming run, not the iteration loop** - every push to a ready PR re-runs
  the whole pipeline on billed runner minutes, so a fix you could have found
  locally costs a full CI run. A push made before local gates are green (a WIP
  checkpoint, a backup) goes to a **draft** PR (`gh pr create --draft`), which
  the shipped `ci.yml` does not run. **Capture what was learned** -
  if the work turned on reasoning that is non-obvious and absent from the final
  code, tests and docs, put it on the first rung of the enforcement ladder that
  can carry it: regression test -> lint rule or hook -> `contract.md` rule ->
  product `CLAUDE.md` pattern -> `/steer-report` for a steer defect -> only then
  `spec/learnings/<slug>.md` from
  `https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/templates/spec/learning.md`, updating a matching
  learning over adding one (`/steer-reference traceability` section 3). Writing
  nothing is the normal outcome; whatever is written ships in this delivery.
  Then update progress (`update-state` on the managed block + `comment`);
  commit, push, and open-or-update the PR (autonomous - Commit
  autonomy; merge is not yours), writing its **Spec delta** when the branch
  changes a `contract.md` (below), and record it with `link-delivery` - in
  solo-trunk the closing trunk commit is that ref; **mark the PR ready for review** (`gh pr ready`) if it
  is still a draft, **then watch CI
  to conclusion** (`gh pr checks --watch`) before transitioning. The order matters and is
  not cosmetic: the shipped `ci.yml` skips every job on a draft PR, and a **skipped** check
  reads as green to `gh pr checks`. Watching first would let `finish` reach `validate` with
  no test having run - the exact false `done` this mode forbids. So: ready, *then* watch. If
  a check reports `skipped` after that, treat it as a red flag and find out why, never as a
  pass. The first push of
  the new `issue/<n>` branch sets the upstream - `git push -u origin <branch>` -
  or it fails with `no upstream branch`; later pushes are a plain `git push`. **In solo-trunk,
  there is no PR: commit straight to `main` with a `Closes #N` trailer (see
  Closing ref if the tracker lives elsewhere) and watch
  CI on the trunk push** (`gh run watch`) the same way - the closed issue, not a
  merged PR, is the terminal evidence. On a red build,
  diagnose and fix it as part of the same unit of work: reproduce the failure
  locally with the task CI ran, fix everything that run reported, re-run the
  local gates green, then push **once** and re-watch - batch the fixes, never a
  push per attempt. A failure that only reproduces in CI (runner environment,
  secrets, services) is the exception that earns an exploratory push. Repeat
  until checks are green or a remaining failure is
  legitimately non-blocking (and said so). Only transition to `validate` once CI is
  green; hand the reviewer a green PR, not a running or red one. A PR-scoped failure
  is fixed or commented on the PR, **not** filed as a tracker issue - defer to the
  CI-failure triage in `ISSUE-WORKFLOW.md` (only a reproducible default-branch
  failure becomes a `source:ci` bug). **Never mark `done` merely because a PR was
  opened.** If you have stepped away, the in-turn watch blocks the turn; re-enter
  monitoring via the harness `/loop` over `gh pr checks` or a background watch -
  steer ships no background poller.

Natural language (`Fix the export bug`, `work #123`) may orchestrate `start`
through `finish`, but the phases stay distinct and idempotent - re-running a
phase reconciles rather than duplicates.

## Spec delta - derived, never staged

When the branch changes any `spec/features/<id>/contract.md`, fill the PR
template's `## Spec delta` section from the diff itself - there is no staged
delta file. Per changed contract, compare the `### R-NNN` headings and blocks on
the base (`git show <base>:<path>`) against the branch:

- **Added** - an ID only the branch has.
- **Modified** - an ID on both sides whose heading or block changed (a dropped
  `(derived ...)` marker counts: confirming as-built behavior is a change).
- **Removed** - an ID only the base has. Each one needs a `Reason:` line (why the
  behavior goes) and a `Migration:` line (what callers or users do instead, or
  `none` and why) - ask the dev rather than invent either.

Write one line per ID, `R-003 - <short name>`. An edit to plain unnumbered
bullets is listed as `Unnumbered rules changed` - never mint IDs to describe
it. In solo-trunk there is no PR body; put the same block in the trunk commit
body. When updating an open PR, recompute the block from the current diff
rather than appending to it.

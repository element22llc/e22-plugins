## Commit autonomy

Commits are cheap and local — the PR review is the gate (see "You are not the
gate"), not each commit. Do **not** pause work to ask "should I commit?".

- Work on a branch off `main` — never commit to `main` directly. Use the
  repository's configured branch convention if it has one; otherwise `feat/*` /
  `fix/*` (issue-first work via `/steer:work` defaults to `issue/<number>-<slug>`).
  If you find yourself on `main` with changes, create the branch first, then commit.
- In a GitHub-adopted repo, the **first mutation** of a unit of work presupposes
  an active GitHub issue (see Issue-first) — commit autonomy is unchanged once
  that issue exists.
- **Commit without asking** whenever a coherent unit of work is done — tests
  pass, lint is clean, the code builds. Keep commits small with conventional
  messages (`feat:`, `fix:`, `chore:`, ...).
- When you judge the work **complete** (Definition of Done holds, end-of-session
  checklist is clean), don't just stop: tell the dev the branch is ready and
  **propose opening the PR** — push and create it once they confirm.
- Opening the PR is the one step that waits for the dev; everything before it
  (branching, committing) does not.
- **After pushing, watch CI to conclusion and fix a red build before treating the
  work as complete** — that is finishing the work, not crossing the merge gate.
  Don't hand the dev a running or red PR and stop. (Merge and deploy stay gated.)

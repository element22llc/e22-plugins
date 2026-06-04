## Commit autonomy

Commits are cheap and local — the PR review is the gate (see "You are not the
gate"), not each commit. Do **not** pause work to ask "should I commit?".

- Work on a `feat/*` / `fix/*` branch off `main` — never commit to `main`
  directly. If you find yourself on `main` with changes, create the branch
  first, then commit.
- **Commit without asking** whenever a coherent unit of work is done — tests
  pass, lint is clean, the code builds. Keep commits small with conventional
  messages (`feat:`, `fix:`, `chore:`, ...).
- When you judge the work **complete** (Definition of Done holds, end-of-session
  checklist is clean), don't just stop: tell the dev the branch is ready and
  **propose opening the PR** — push and create it once they confirm.
- Opening the PR is the one step that waits for the dev; everything before it
  (branching, committing) does not.

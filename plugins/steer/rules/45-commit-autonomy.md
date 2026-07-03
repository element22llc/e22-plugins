<!-- steer:inject-when=code-project -->
## Commit autonomy

Commits are cheap and local — the PR review is the gate (see "You are not the
gate"), not each commit. Do **not** pause work to ask "should I commit?".

- Work on a branch off `main` — never commit to `main` directly. Use the
  repository's configured branch convention if it has one; otherwise `feat/*` /
  `fix/*` (issue-first work via `/steer:work` defaults to `issue/<number>-<slug>`).
  If you find yourself on `main` with changes, create the branch first, then commit.
- **Exception — solo trunk mode (pre-MVP greenfield).** If the product `CLAUDE.md`
  declares `Delivery mode: solo trunk (pre-MVP)`, commit **directly to `main`** until
  graduation — no `feat/*` branch, no per-feature PR. There is no second reviewer yet,
  so the PR gate has nothing behind it (see "You are not the gate"); CI still runs on
  every push, and the spine, tests, and Definition of Done are **unchanged** — only the
  branch/PR ceremony relaxes. On a GitHub-adopted repo the issue is still required and
  closed from the trunk commit (`Closes #N`), not via a PR (see Issue-first).
  **Graduate** the moment the MVP works, you first deploy, or
  a second contributor joins — whichever comes first — by running **`/steer:protect`**,
  which raises the server-side PR wall and ends the mode.
- In a GitHub-adopted repo, the **first mutation** of a unit of work presupposes
  an active GitHub issue (see Issue-first) — commit autonomy is unchanged once
  that issue exists.
- **Commit without asking** whenever a coherent unit of work is done — tests
  pass, lint is clean, the code builds. Keep commits small, with a
  **[Conventional Commits](https://www.conventionalcommits.org/)** subject:
  `type(scope): summary` in the imperative mood. Types: `feat`, `fix`, `docs`,
  `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `style`, `revert`. Mark a
  breaking change with `!` before the colon (`feat!:`) or a `BREAKING CHANGE:`
  footer. Commit messages are **not** the release changelog — that stays the
  curated `CHANGELOG.md`. Full detail: `/steer:reference conventions`.
- When you judge the work **complete** (Definition of Done holds, end-of-session
  checklist is clean), don't just stop: tell the dev the branch is ready and
  **propose opening the PR** — push and create it once they confirm. The first
  push of a freshly created branch has no upstream, so set it then:
  `git push -u origin <branch>` (subsequent pushes are a plain `git push`).
- Opening the PR is the one step that waits for the dev; everything before it
  (branching, committing) does not.
- **After pushing, watch CI to conclusion and fix a red build before treating the
  work as complete** — that is finishing the work, not crossing the merge gate.
  Don't hand the dev a running or red PR and stop. (Merge and deploy stay gated.)

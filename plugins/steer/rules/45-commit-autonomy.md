<!-- steer:inject-when=code-project -->
## Commit autonomy

Commits are cheap and local — the reviewed **PR merge** is the gate (see "You
are not the gate"), not each commit and not the push. Do **not** pause work to
ask "should I commit?", "should I push?", or "should I open the PR?".

Delivery runs in exactly **two modes**, keyed to GitHub branch protection —
protected repos deliver through PRs, unprotected repos deliver on trunk. The
product `CLAUDE.md` `## Delivery mode` marker caches which one applies
(`<!-- steer:delivery-mode=pr-flow -->` vs `=solo-trunk`; absent → pr-flow);
`/steer:protect` is what moves a repo between them, and there is no third mode.

- **PR flow (protected `main` — the default).** Work on a branch off `main` —
  never commit or push to `main` directly. Use the repository's configured
  branch convention if it has one; otherwise `feat/*` / `fix/*` (issue-first
  work via `/steer:work` defaults to `issue/<number>-<slug>`). If you find
  yourself on `main` with changes, create the branch first, then commit. When
  the work is **complete** (Definition of Done holds, end-of-session checklist
  is clean), **push the branch and open the PR without asking** — announce it,
  don't request permission (the heads-up lets the dev redirect). The first push
  of a fresh branch sets the upstream: `git push -u origin <branch>`
  (subsequent pushes are a plain `git push`). Branch protection — required
  review, green `ci`, no direct push — is what makes this safe: an open PR is
  inert until a human merges it. **Merging the PR is the one step that waits
  for the dev; everything before it (branching, committing, pushing, opening
  the PR) does not.**
- **Solo trunk mode (unprotected `main` — pre-MVP greenfield).** If the product
  `CLAUDE.md` declares solo-trunk, commit **directly to `main` and push without
  asking** — no `feat/*` branch, no per-feature PR. There is no second reviewer
  yet, so the PR gate has nothing behind it (see "You are not the gate"); CI
  still runs on every push, and the spine, tests, and Definition of Done are
  **unchanged** — only the branch/PR ceremony relaxes. On a GitHub-adopted repo
  the issue is still required and closed from the trunk commit (`Closes #N`),
  not via a PR (see Issue-first). **Graduate** the moment the MVP works, you
  first deploy, or a second contributor joins — whichever comes first — by
  running **`/steer:protect`**, which raises the server-side PR wall and flips
  the mode. While any graduation signal stands unaddressed (a deploy target, a
  `prod` branch, a second contributor), trunk pushes stop being autonomous —
  the trunk-push hook surfaces each one for a human yes until the repo
  graduates.
- **Declared-but-unprotected PR flow is a gap, not a mode.** If the repo runs
  pr-flow but `main` has no protection (nobody ran `/steer:protect apply`, or
  the plan/permissions don't allow it — e.g. a private repo on GitHub Free),
  the flow above still applies unchanged — you still never merge — but say the
  wall is missing and recommend `/steer:protect`. Where protection is genuinely
  unavailable, record the exception in an ADR; `/steer:protect verify` and
  `/steer:audit` keep flagging it so the gap stays visible.
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
- **After pushing, watch CI to conclusion and fix a red build before treating the
  work as complete** — that is finishing the work, not crossing the merge gate.
  Don't hand the dev a running or red PR and stop. (**Merge and deploy stay
  human-gated in every mode** — never `gh pr merge`, never deploy, and never
  push to a protected `prod` branch.)

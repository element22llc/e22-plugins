<!-- steer:inject-when=code-project -->
## Commit autonomy

Commits are cheap and local — the reviewed **PR merge** is the gate (see "You
are not the gate"), not each commit and not the push. Never pause work to ask
"should I commit / push / open the PR?".

Delivery runs in exactly **two modes**, keyed to GitHub branch protection. The
product `CLAUDE.md` `## Delivery mode` marker caches which one applies
(`<!-- steer:delivery-mode=pr-flow -->` vs `=solo-trunk`; absent → pr-flow);
`/steer:protect` moves a repo between them, and there is no third mode.

- **PR flow (protected `main` — the default).** Work on a branch off `main` —
  never commit or push to `main` directly. Use the repo's branch convention,
  else `feat/*` / `fix/*` (`/steer:work` defaults to `issue/<number>-<slug>`).
  On `main` with changes? Create the branch first, then commit. When the work
  is **complete** (Definition of Done holds, end-of-session checklist clean),
  **push the branch and open the PR without asking** — announce it, don't
  request permission. First push of a fresh branch:
  `git push -u origin <branch>`. **Merging the PR is the one step that waits
  for the dev; everything before it (branch, commit, push, open PR) does not.**
- **Solo trunk mode (unprotected `main` — pre-MVP greenfield).** If the product
  `CLAUDE.md` declares solo-trunk, commit **directly to `main` and push without
  asking** — no `feat/*` branch, no per-feature PR. CI still runs on every
  push; the spine, tests, and Definition of Done are **unchanged** — only the
  branch/PR ceremony relaxes. On a GitHub-adopted repo the issue is still
  required and closed from the trunk commit (`Closes #N`), not via a PR (see
  Issue-first). **Graduate** — run **`/steer:protect`** — the moment the MVP
  works, you first deploy, or a second contributor joins, whichever comes
  first. While a **local** graduation signal (a deploy target or a `prod`
  branch) stands unaddressed, trunk pushes stop being autonomous — each one
  waits for a human yes until the repo graduates; a second contributor is
  caught on demand by `/steer:protect` and `/steer:audit`, not at push time.
- **Declared-but-unprotected PR flow is a gap, not a mode.** If the repo runs
  pr-flow but `main` has no protection, the flow above applies unchanged — you
  still never merge — but say the wall is missing and recommend
  `/steer:protect`. Where protection is genuinely unavailable, record the
  exception in an ADR; `/steer:protect verify` and `/steer:audit` keep
  flagging it.
- In a GitHub-adopted repo, the **first mutation** of a unit of work
  presupposes an active GitHub issue (see Issue-first) — autonomy is unchanged
  once that issue exists.
- **Commit without asking** whenever a coherent unit of work is done — tests
  pass, lint clean, builds. Keep commits small, with a
  **[Conventional Commits](https://www.conventionalcommits.org/)** subject:
  `type(scope): summary`, imperative mood; mark breaking changes with `!` or a
  `BREAKING CHANGE:` footer. Commit messages are **not** the release
  changelog — that stays the curated `CHANGELOG.md`. Full detail:
  `/steer:reference conventions`.
- **After pushing, watch CI to conclusion and fix a red build before treating
  the work as complete** — don't hand the dev a running or red PR and stop.
  (**Merge and deploy stay human-gated in every mode** — never `gh pr merge`,
  never deploy, never push to a protected `prod` branch.)

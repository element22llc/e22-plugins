---
name: loop
description: "Scaffold an autonomous loop for a managed repo — a scheduled GitHub Actions workflow that wakes on its own, triages work (CI failures, open issues, drift) via /steer:audit + /steer:next, drafts fixes in isolated worktrees reviewed by steer-reviewer, and opens draft PRs. Wired to stop at every human gate (rule 53): it delivers up to the PR, it never merges/deploys. Instantiates templates/github/workflows/steer-loop.yml and lands it via the normal autonomous branch-push + PR (Commit autonomy — the merge review is the gate)."
when_to_use: >-
  Use when someone wants to automate steer's triage/fix loop instead of prompting
  it each turn — "set up a nightly loop", "automate CI-failure triage", "have
  Claude sweep the backlog on a schedule", "loop engineering for this repo". Also
  the follow-up when /steer:audit or /steer:next keeps surfacing the same
  recurring sweep. Verify or remove an existing loop with the verify/remove modes.
argument-hint: "[scaffold | verify | remove]"
allowed-tools:
  - Bash(git status *)
  - Bash(git rev-parse *)
  - Bash(git remote *)
  - Bash(git add *)
  - Bash(git commit *)
  - Bash(git switch *)
  - Bash(git checkout -b *)
  - Bash(git push)
  - Bash(git push -u origin *)
  - Bash(git push origin *)
  - Bash(gh pr create *)
  - Bash(gh auth status *)
  - Bash(gh repo view *)
  - Bash(gh secret list *)
---
<!-- steer:modes scaffold,verify,remove -->

# Scaffold an autonomous loop

`/steer:loop` sets up an **autonomous loop** (rule `53-autonomous-loops`): a
scheduled automation that wakes on its own, discovers work, and drives it through
steer's skills without a human in each turn — the "loop engineering" pattern.
What it installs is a GitHub Actions workflow on a `cron` schedule that runs the
same `steer` plugin an interactive session runs, so the loop obeys the identical
ruleset.

**The one invariant, always: the loop closes only up to a human gate — never
through one** (rule 53). It discovers, triages, drafts in an isolated worktree,
runs the verify loop, pushes its **own work branch**, and opens a **draft** PR —
autonomous delivery up to the merge, exactly like an interactive session (Commit
autonomy). It does **not** merge, deploy,
push to `main` or any protected branch, ratify an ADR, or handle real secrets.
The draft flag is a *convention*, not the gate — it marks the PR as unattended
output; the **merge review is the gate**. Be honest in
every report: this scaffolds a *drafting* automation, not an auto-merging one.

Default mode is `scaffold`. `verify` is read-only.

## Preconditions

Run these as **separate** invocations (chained `&&` defeats the allow-list).

1. **GitHub-hosted repo.** Resolve `owner/repo` from `git remote get-url origin`
   (or `gh repo view`). No GitHub remote yet → say so and stop; a scheduled
   Actions workflow needs the repo on GitHub.
2. **Read `/spec/tracker.md`.** The loop triages the tracker; this skill assumes
   `system: github`. If the tracker is something else, say the loop's
   issue-triage half won't apply and confirm before scaffolding a CI-only loop.
3. **PR flow only (rule 53).** A loop routes unattended work through the merge
   review, so the repo must run pr-flow with a protected `main`. In a
   **solo-trunk** repo (`CLAUDE.md` delivery-mode marker), do not scaffold —
   recommend graduating via `/steer:protect` first. If `main` declares pr-flow
   but is unprotected, scaffold, but name the missing wall as a required
   follow-up (`/steer:protect apply`) — an unattended loop must not be the thing
   that discovers the gate was honor-system.
4. **`ANTHROPIC_API_KEY` must be available to Actions.** Check
   `gh secret list` for it. If absent, scaffold anyway but report it as a
   **required human follow-up** — the workflow no-ops without it (never set the
   secret yourself).
5. **`.github/workflows/claude.yml` present** is a good signal the repo already
   loads steer in CI (same action, same marketplace inputs). Not required, but
   note it if missing so the dev knows this is their first in-CI steer wiring.

## Scaffold (default mode)

1. **Instantiate the workflow.** Copy
   `${CLAUDE_PLUGIN_ROOT}/templates/github/workflows/steer-loop.yml` to
   `.github/workflows/steer-loop.yml`. This template is **on-demand** — it is not
   part of the bootstrap scaffold, so a repo only gets a loop when someone asks
   for one here.
2. **Resolve the two choices with the dev — don't guess:**
   - **Schedule (`cron`).** The template defaults to weekday mornings
     (`0 13 * * 1-5`, 13:00 UTC). Confirm or adjust the cadence. Keep it modest —
     an hourly loop burns API budget and opens draft-PR noise; daily or a few
     times a week is the norm.
   - **Scope.** What the loop is allowed to pick up — the default prompt triages
     CI failures and open issues via `/steer:audit` + `/steer:next`. Narrow it if
     the dev wants (e.g. "only CI failures", "only issues labelled `loop-ok`").
3. **Leave the gate wiring intact.** Do not add `merge`, `gh pr merge`, deploy
   steps, or any push targeting `main`/a protected branch to the workflow. The
   prompt and
   permissions are deliberately scoped to *deliver-up-to-the-PR* — widening them
   to cross the merge violates rule
   53. If the dev wants the loop to merge, that's a human decision made per-PR,
   not something this skill bakes in.
4. **Deliver the workflow like any change.** Commit
   `.github/workflows/steer-loop.yml` on a `feat/*` branch, push, and open the
   PR without asking, announcing it (Commit autonomy — the merge review is the
   dev's gate). The scheduled loop only arms once that PR merges, so the human
   decision to run a loop at all is the merge itself.
5. **Report the follow-ups honestly:** the `ANTHROPIC_API_KEY` secret if missing,
   branch protection if missing (`/steer:protect apply`),
   the chosen schedule, the scope, and that the loop delivers up to the PR and
   never merges. Point at rule
   53 for the boundary and note the workflow can be triggered on demand from the
   Actions tab (`workflow_dispatch`) to test it before the first scheduled run.

## Verify (read-only)

Report whether `.github/workflows/steer-loop.yml` exists and is wired:

- the `on.schedule` cron is present and valid;
- it loads steer via the action's `plugins` / `plugin_marketplaces` inputs (not a
  `settings.json` `enabledPlugins` block, which no-ops in headless CI);
- `permissions` grant no more than `contents: write`, `pull-requests: write`,
  `issues: write`, `id-token: write`, `actions: read` — flag any broader grant;
- the prompt contains no merge/deploy/push-to-`main` instruction (rule 53 — the
  loop pushes only its own work branches);
- `ANTHROPIC_API_KEY` is present in `gh secret list`.

If everything holds, say the loop is wired and name its schedule. If nothing is
installed, say so and offer `scaffold`.

## Remove

`remove` deletes `.github/workflows/steer-loop.yml` and delivers the removal the
same way as scaffold (branch, commit, push, PR — the merge review is the gate).
Confirm first — a scheduled loop someone relies on shouldn't vanish
silently. The `ANTHROPIC_API_KEY` secret is left alone (other workflows may use
it).

## What this skill is not

- **Not an auto-merger.** It never merges, deploys, or pushes to `main` or any
  protected branch — it pushes only its own work branches to open PRs.
  The loop drafts; a human still reviews and merges (rule 53).
- **Not a runtime.** It scaffolds the workflow; the scheduled Actions run *is* the
  loop. This skill doesn't itself run the sweep — invoke `/steer:audit` /
  `/steer:next` directly for a one-off.
- **Not branch protection.** Requiring review on the draft PRs the loop opens is
  `/steer:protect`'s job — name it as the companion follow-up so an autonomous
  loop can't land unreviewed.

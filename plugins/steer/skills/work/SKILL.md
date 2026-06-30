---
name: work
description: "Execute a GitHub issue end-to-end from local Claude Code — read and validate the issue, claim it, create or reuse a branch, load linked specs, implement, test, update progress on the issue, open the PR, and transition lifecycle state. The execution counterpart to /steer:issues (which owns backlog management and never edits code). Routes all tracker-metadata I/O through /steer:tracker-sync; git and PR delivery follow the repo's commit/PR-autonomy rules and delivery mode — in solo-trunk mode it commits straight to main and closes the issue from the trunk commit instead of branching and opening a PR. One issue per branch/PR (or trunk commit) by default. Pass --reviewed to wrap execution in independent plan- and code-review gates plus a bounded fix loop (the review-gated path formerly the deliver skill) — vetted, not first-draft. Pass --hotfix for a genuine production incident (deployed system, active outage/regression): the fast-path relaxes ceremony and ordering (issue filed after-the-fact on a hotfix/ branch, single-reviewer) but keeps every human authority gate, and requires a mandatory post-incident follow-up to restore traceability (rule 62)."
when_to_use: Use when asked to work, start, resume, or finish a specific issue ("work on #123", "fix #123", "implement #123 and #124"), or when a code/config/behavior change in a GitHub-adopted repo needs an issue found-or-created and then implemented. Add --reviewed ("deliver X carefully", "do this with review", any change costly to unwind) to gate the work through independent plan and code review. Add --hotfix only for a real production incident on a deployed system ("prod is down", "emergency fix", "hotfix the outage") — not for ordinary urgent work.
argument-hint: "[start | resume | status | finish] [--reviewed | --hotfix] [#issue ...]"
allowed-tools:
  - Bash(git status *)
  - Bash(git switch *)
  - Bash(git checkout -b *)
  - Bash(git diff *)
  - Bash(git log *)
  - Bash(git show *)
  - Bash(git rev-parse *)
  - Bash(git add *)
  - Bash(git commit *)
  - Bash(gh pr checks *)
  - Bash(gh run view *)
  - Bash(gh run watch *)
---
<!-- steer:modes start,resume,status,finish -->

Implement work from a GitHub issue by following the `work` skill. This is the
**execution** layer of the issue-first workflow: `/steer:issues` manages the
backlog and never edits code; `/steer:work` reads an issue and delivers it.

## Preconditions

1. **Read `/spec/tracker.md`.** This skill requires `system: github`. If the
   tracker is something else, say so and stop (manual flow only).
2. **Route all tracker reads/writes through `/steer:tracker-sync`** (the gateway —
   `search`/`get`/`find-or-create`/`update`/`comment`/`set-type`/`label`/
   `transition`/`assign`/`link-pr`/`close`). Never hit `gh`/MCP for issues
   directly. **Git and PR delivery are not gateway operations** — they are this
   skill's execution concern, under the repo's commit/PR-autonomy rules.
3. **No issue named but a mutation was requested?** Find-or-create one first
   (Issue-first), then `start`.

## Authorization (what an implement request grants)

A CLI "fix/implement #N" request authorizes, without extra confirmation:
read/search the issue, create-or-reuse the issue, claim it, update its managed
state, create/switch the local branch, modify the local repository, and run
tests. **Commit, push, and open/update PR follow the existing commit- and
PR-autonomy rules; merge and deploy are never implied.**

> **Pre-approved shell scope (frontmatter `allowed-tools`).** To cut repetitive
> prompts, this skill pre-approves only read-only git inspection (`status`, `diff`,
> `log`, `show`, `rev-parse`), branch create/switch (`checkout -b`, `switch`), the
> Rule-45-autonomous local mutations `git add` / `git commit`, and **read-only CI
> status** (`gh pr checks`, `gh run view`, `gh run watch`) so the post-push CI watch
> (see `finish`) runs without a prompt per poll. It deliberately does
> **not** pre-approve `git push`, `gh pr create/edit/merge`, `gh api`, `gh workflow run`,
> or destructive git (`reset --hard`, `clean -fdx`, `branch -D`) — those keep the human
> gate. Only those read-only CI reads are pre-approved; every `gh` *write* stays gated,
> and tracker I/O still routes through `/steer:tracker-sync`.

## Delivery mode

How the work reaches `main` is governed by the repo's **delivery mode**, declared
on the product `CLAUDE.md`'s `## Delivery mode` section — the same
machine-readable marker the steer hooks read (`<!-- steer:delivery-mode=solo-trunk -->`
vs `<!-- steer:delivery-mode=pr-flow -->`; absent or unreadable → **pr-flow**).
Determine it once at `start` / `finish`. **Issue-first holds in both modes** —
every implementation-affecting change is tied to a GitHub issue; the modes differ
only in the branch/PR ceremony around that issue.

- **pr-flow** (default) — the full flow this skill describes throughout: claim →
  `issue/<n>` branch + `spec/.work` marker → implement → push → open PR → CI green
  → transition. The PR is the human gate.
- **solo-trunk** (pre-MVP greenfield, before `/steer:protect` graduates the repo)
  — commit **straight to `main`**: **no `issue/<n>` branch, no `spec/.work`
  marker, no PR**. Still claim the issue and implement, but close it **from the
  trunk commit** (`Closes #N`) under Commit autonomy (rule 45) rather than via a
  PR. Committing to `main` is itself authorized in this mode; **deploy is still
  never implied**, and the spine, tests, and Definition of Done are unchanged.
  Wherever a step below says *branch*, *marker*, or *PR*, skip it and substitute
  the trunk commit — everything else (validation, managed-block progress, reading
  the closure reason for the terminal state) is identical.

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
  comment); when authorized, commit/push and open-or-update the PR; **then watch CI
  to conclusion** (`gh pr checks --watch`) before transitioning. The first push of
  the new `issue/<n>` branch sets the upstream — `git push -u origin <branch>` —
  or it fails with `no upstream branch`; later pushes are a plain `git push`. **In solo-trunk,
  there is no PR: commit straight to `main` with a `Closes #N` trailer and watch
  CI on the trunk push** (`gh run watch`) the same way — the closed issue, not a
  merged PR, is the terminal evidence. On a red build,
  diagnose and fix it as part of the same unit of work — re-push (still
  human-gated) and re-watch — until checks are green or a remaining failure is
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

## Reviewed mode (`--reviewed`)

`--reviewed` wraps the `start`→`finish` flow above in two **independent** review
gates plus a bounded fix loop, so the delivery is **vetted, not first-draft**.
This is the review-gated path formerly carried by the standalone `deliver` skill; the execution
itself is unchanged — the same claim, branch, implement, test, PR, and transition
steps run, with gates added around them. Full protocol, rubric structure, and
stopping rules: [`REVIEW-LOOP.md`](../../templates/reference/REVIEW-LOOP.md).

- **Triage first.** If the task is trivial (typo, one-liner, rename), run it
  without the gates and say they were skipped — honesty over ceremony. The gates
  earn their cost only on non-trivial work.
- **Plan gate — independent.** Before implementing, draft the approach (what
  changes, where, why), then spawn a **fresh reviewer subagent** — a separate
  context, **not** `steer-reviewer` (that agent reviews existing on-disk code and
  needs `path:line` evidence a prospective plan can't supply). Give it the plan,
  the **restated requirements** (what success means, in your words), and the
  relevant **steer rules** as the rubric. Ask for severity-ranked findings plus a
  "what's missing" pass. **Revise on every high-severity finding**; never review
  your own plan.
- **Human plan sign-off.** Present the vetted plan for sign-off before a
  significant change (Rules `45-commit-autonomy`, `95-not-the-gate`). This covers
  the **plan**; the push/PR autonomy gates in `finish` still apply at delivery.
- **Implement** via the normal `start`→`finish` flow — do not stand up a second
  path.
- **Code gate — independent.** After implementing, run `/code-review` on the diff
  for correctness bugs and fidelity to the approved plan; in
  spec/standards-sensitive repos additionally invoke `steer-reviewer` to check the
  on-disk result against the standards (read-only, no git access — it reviews
  state, not the diff). In **pr-flow** this gate runs **before** merge; in
  **solo-trunk** it reviews the trunk commit after the fact and its findings
  become immediate follow-up fixes — say so rather than implying it blocked a
  merge.
- **Bounded fix loop.** Apply fixes for confirmed findings, then re-review.
  **Cap at 2 rounds**; exit as soon as a round surfaces no high-severity findings.
  If you stop at the cap with findings still open, say what was left and why.
- **Report.** Summarize what each gate checked, which findings were resolved, and
  any residual risk, folded into the `## Recommended next actions` block below.

In **prototype/local mode** there is no tracker and therefore no `/steer:work` to
run — apply the same `REVIEW-LOOP.md` protocol directly around `/steer:build`'s
implementation, which is the path that population uses.

## Hotfix mode (`--hotfix`)

`--hotfix` is the **production-incident fast-path** (rule `62-hotfix`). It relaxes
*ceremony and ordering*, never the human authority gates. Use it **only** when the
objective entry condition holds: the change targets an already-**deployed
production** system with real users or data **and** there is an active incident,
outage, or regression. "Urgent" feature work and pre-MVP repos are **not** hotfixes —
drop the flag and use the normal flow. A hotfix presupposes a deployed product, so it
implies **pr-flow** (a solo-trunk pre-MVP repo has nothing to hot-fix).

What changes versus the normal flow:

- **Branch.** Work on a `hotfix/<n>-slug` branch (not `issue/<n>`) so the
  issue-first Stop hook recognises the sanctioned after-the-fact lane. `<n>` is the
  issue number once it exists; until then use a short slug and record it when the
  issue is filed.
- **Issue after-the-fact.** Don't block the fix on find-or-create. File or backfill
  the issue as soon as practical and reference it from the PR/commit — the hook
  won't nag a `hotfix/` branch, but the issue is still required by the follow-up.
- **Single-reviewer, expedited.** One reviewer approval is sufficient (it relaxes
  the change-size / high-risk scoping ceremony of rules 60 and 80) — it does **not**
  remove the PR/merge human gate. No self-merge.
- **Deploy on the fix.** Deploying the fix is *policy-permitted* under rule 62 +
  Deployment (validate in non-prod where feasible) — but, exactly as everywhere
  else, deploy is **never auto-executed**: `git push`, `gh pr merge`, and any deploy
  stay human-gated (this skill does not pre-approve them).
- **Mandatory follow-up (not optional).** Once the fire is out, restore traceability:
  backfill/finish the issue, write the spec/ADR if a durable decision was made, and
  append a `/spec/HISTORY.md` entry. Definition of Done is **deferred, not waived**
  (rule 50) — track the follow-up to closure rather than declaring the hotfix done.

## Completion semantics

**Closure reason — not the mere fact of closure — decides the terminal state.**
Inspect it before transitioning a closed issue; keep delivery state as independent
evidence (a merged PR — or, in solo-trunk, the `Closes #N` trunk commit — is
necessary for `done`, not sufficient on its own).

- Opening a PR → `validate` (never `done`). **(Solo-trunk has no PR — the
  trunk commit that closes the issue is the delivery; go straight to the closure
  reasons below.)**
- Closed as **`completed`** (delivered — PR merged or trunk commit landed — **and**
  acceptance criteria accepted) → `done`.
- Closed as **`rejected` / `duplicate` / `obsolete` / `not-planned` /
  `superseded`** → **`cancelled`**, never `done` — record a replacement pointer
  where one applies. Cancelled work was not delivered.
- PR closed **without** merge → back to `in-progress` or `blocked`.
- `status` / `resume` / `finish` reconcile stale markers on the next interaction,
  reading the closure reason rather than assuming "closed == done." When a feature
  issue's state and its spec `Status:` disagree, derive the expected `Status:` from
  the issue state via the Status↔state crosswalk (`ISSUE-WORKFLOW.md`) and surface
  the mismatch — never silently rewrite the spec.

## Branch naming

Use the repository's configured branch convention if one exists. Otherwise fall
back to `issue/<number>-<slug>` — **not** `fix/…`, which would mislabel feature,
docs, or infra work. Record the branch in `steer:branch` (tracker metadata) **and**
in the local marker `spec/.work/<branch>.md` (slashes → underscores; local-only —
`spec/.work/` is git-ignored). The marker is what the Stop-hook reconciliation
checks to confirm a branch is issue-governed, ahead of any branch-name guess; an
unconventional but claimed branch is still recognized. Optional housekeeping:
remove the marker when the issue is closed.

In **`--hotfix` mode**, use `hotfix/<n>-slug` instead — the reconciliation hook
recognises the `hotfix/` prefix directly as the after-the-fact lane (rule 62), so a
marker is not required up front; record it when the issue is filed in the follow-up.

### Marker format

The marker is a small Markdown file. The `issue:` / `branch:` lines are written
once and never rewritten; the session list under the heading is the single source
of truth for "which Claude Code session(s) worked this branch" — the head is the
most recent. The Stop hook keeps that head current each turn, and `resume` reads
it (see above). Session ids are local breadcrumbs and **never** go into tracker
metadata.

```markdown
# Work marker — issue 123

- issue: 123
- branch: issue/123-export-fix

## Claude Code sessions (newest first)

- 64ae4a08-7069-4810-8cd0-d443c8511365
```

Seed the first session id from `$CLAUDE_CODE_SESSION_ID` (fail-open: if it is
empty, write the marker without a session bullet — its existence still governs).
The session heading + list must be the **last** block in the file. If a legacy
extensionless `spec/.work/<branch>` marker exists, upgrade it: carry over any
`issue`/`branch` it records, write the new `.md` file, then remove the old one.

## Concurrency & claims

Before claiming or mutating, check for conflicts: the issue is already assigned
to someone else, `steer:claimed-by` names another context, a different `steer:branch`
is recorded, the recorded branch is gone, the worktree is dirty, or two local
sessions exist for the same user. **A conflicting active branch or claimant
prevents automatic takeover** — report it and ask. GitHub *assignment* represents
the accountable human; the *branch* marker represents the active execution
context.

## Multiple issues

`Implement #123 and #124` → **one branch + PR per issue** by default (in
solo-trunk, **one trunk commit per issue**, each closing its own `#N`). Combine only
when one issue explicitly depends on the other, separating them would produce an
invalid intermediate state, or the user explicitly asks for combined delivery —
otherwise issue-first traceability degrades into many-issues-to-one-PR.

## Discovered work — bounded scope

While implementing, if you find an unrelated bug, tech debt, a missing test, a
security concern, or a new feature request: keep the current issue's scope
bounded and **file a separate linked issue** (related/blocking) via
`/steer:tracker-sync find-or-create`. Create the separate issue when the work has
independent acceptance criteria, needs a new product decision, materially changes
risk, or is separately deliverable; necessary **localized supporting changes**
stay in the current issue and are documented in its managed block. Continue with
the separate work only when the current issue requires it.

## Recommend the next action

End every invocation with a `## Recommended next actions` block per
`${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md`. Per the **locality
rule**, consider only this issue, its branch, PR, criteria, validation, and any
blocker directly hit — not the wider workspace. Map execution state to actions
without redefining the subcommands above:

| State | Category | Action / suggested command |
|---|---|---|
| Acceptance criteria not yet met | Blocking now (next transition) | Continue — `/steer:work resume #N` |
| Required validation failing | Blocking now | Fix failures, then `/steer:work finish #N` |
| Implemented, PR not opened | Blocking now (next transition) | `/steer:work finish #N` |
| PR open, CI running | Blocking now (next transition) | Watch to conclusion — `gh pr checks --watch` (detached: `/loop` over `gh pr checks`) |
| PR open, CI red | Blocking now | Fix the failure, re-push, re-watch |
| PR open, CI green, in `validate`, awaiting review | Human decision required | A reviewer reviews the PR (no command) |
| PR merged but issue still `validate` (stale) | Blocking now | Reconcile to `done` — `/steer:work resume #N` |
| Issue `done` | Complete | Optional: start another ready issue — `/steer:work start #N`, else `No action is currently required.` |

Choose one `Current recommended action` by precedence. The block recommends only
— it never merges, deploys, or auto-advances state.

In **solo-trunk**, read the PR rows as the trunk commit: "PR not opened" → "change
not yet committed to `main`"; "PR open, CI running/red" → the same, watched via
`gh run watch` on the trunk push; there is **no awaiting-review row** — a green
trunk commit that closes the issue with acceptance accepted is `done` (deploy
still excluded).

## Guardrails

- **Managed block only.** Progress updates rewrite only the `steer:managed` block,
  following the concurrency-safe protocol in `ISSUE-SCHEMA.md` (re-fetch before
  write; stop and report on a concurrent edit; fail closed on duplicate/malformed
  blocks). Human content is never overwritten.
- **Never auto-resolve product decisions or drift** — those wait for the named
  human (see `ISSUE-WORKFLOW.md`).
- **The PR is the human gate.** Propose the PR; don't merge or deploy. Watching CI
  to conclusion and fixing a red build is **finishing the work**, not crossing that
  gate — it is expected, not a gate breach. Merge and deploy stay human-gated.
  **In solo-trunk there is no PR gate** — committing to `main` is authorized (rule
  45), so the trunk commit *is* delivery; but **deploy stays human-gated** all the
  same, and graduating the repo to the PR flow is `/steer:protect`'s job, never
  this skill's.
- References: `ISSUE-WORKFLOW.md`, `ISSUE-SCHEMA.md`, the Issue-first, Commit
  autonomy, and Definition of Done rules.

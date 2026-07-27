---
name: work
description: "Execute a GitHub issue end-to-end from local Claude Code — claim, branch, load linked specs, implement, test, open the PR, and transition lifecycle state; the execution counterpart to /steer:issues, routing all tracker-metadata I/O through /steer:tracker-sync. Pass --reviewed to wrap execution in independent plan- and code-review gates, --hotfix for the production-incident fast path."
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
  - Bash(git push)
  - Bash(git push -u origin *)
  - Bash(git push origin *)
  - Bash(gh pr create *)
  - Bash(gh pr edit *)
  - Bash(gh pr checks *)
  - Bash(gh run view *)
  - Bash(gh run watch *)
---
<!-- steer:modes start,resume,status,finish -->

Implement work from a GitHub issue by following the `work` skill. This is the
**execution** layer of the issue-first workflow: `/steer:issues` manages the
backlog and never edits code; `/steer:work` reads an issue and delivers it.

## Guardrails

These hold for the whole run, in every mode.

- **Managed block only.** Progress updates rewrite only the `steer:managed` block,
  following the concurrency-safe protocol in `ISSUE-SCHEMA.md` (re-fetch before
  write; stop and report on a concurrent edit; fail closed on duplicate/malformed
  blocks). Human content is never overwritten.
- **Never auto-resolve product decisions or drift** — those wait for the named
  human (see `ISSUE-WORKFLOW.md`). **Asking** that human in-session is how you
  obtain their answer (rule `61-gate-prompts`), never a licence to supply one.
  The PR **merge** is not promptable in any mode.
- **The merge is the human gate** (rule 45) — push and open the PR yourself;
  never merge or deploy. Watching CI to conclusion and fixing a red build is
  **finishing the work**, not crossing that gate. In solo-trunk the trunk commit
  *is* delivery (Delivery mode below); deploy stays human-gated all the same,
  and graduating the repo is `/steer:protect`'s job, never this skill's.
- References: `ISSUE-WORKFLOW.md`, `ISSUE-SCHEMA.md`, the Issue-first, Commit
  autonomy, and Definition of Done rules.

## Preconditions

0. **Polyrepo member? Resolve the spine first.** If this repo has
   `spec/PRODUCT.md` (a polyrepo member), its spine is **partial by design**: the
   tracker and every feature's `intent.md` / `contract.md` live in the workspace
   repo, not here. Resolve the workspace before step 1 — `workspace.path` if the
   checkout exists, else the GitHub gateway — and read the tracker and the linked
   specs from **there**. A missing local `intent.md` means the workspace has not
   been read yet, never that the feature is unspecified, so **never** author
   product-level spec files here to fill the gap. If neither route reaches the
   workspace, say the spine is unreachable and stop. Procedure:
   `/steer:reference polyrepo`.
1. **Read `/spec/tracker.md`.** This skill requires `system: github`. If the
   tracker is something else, say so and stop (manual flow only). In a member,
   this is the **workspace's** `spec/tracker.md` resolved in step 0 — a member
   never carries its own.
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
state, create/switch the local branch, modify the local repository, run tests,
commit, push, and open/update the PR — the full delivery loop up to the merge
(Commit autonomy). **Merge and deploy are never implied.**

> **Pre-approved shell scope (frontmatter `allowed-tools`).** To cut repetitive
> prompts, this skill pre-approves read-only git inspection (`status`, `diff`,
> `log`, `show`, `rev-parse`), branch create/switch (`checkout -b`, `switch`), the
> Rule-45-autonomous local mutations `git add` / `git commit`, the delivery moves
> `git push` / `gh pr create` / `gh pr edit` (autonomous under Commit autonomy —
> the merge review is the gate, not the push or the PR), and **read-only CI
> status** (`gh pr checks`, `gh run view`, `gh run watch`) so the post-push CI watch
> (see `finish`) runs without a prompt per poll. It deliberately does **not**
> pre-approve `gh pr merge`, `gh api`, `gh workflow run`, or destructive git
> (`push --force`, `reset --hard`, `clean -fdx`, `branch -D`) — merge stays with
> the human, and tracker I/O still routes through `/steer:tracker-sync`. In an
> ungraduated solo-trunk repo the trunk-push hook additionally surfaces the
> session's first `git push` for confirmation while graduation signals stand
> (rule 45; repeats carry a non-blocking reminder).

## Delivery mode

The two-state delivery model — pr-flow vs solo-trunk, the `CLAUDE.md`
delivery-mode marker (absent → pr-flow), what each mode authorizes, and every
gate — is canonical in **rule 45 (Commit autonomy)**; determine the mode once at
`start` / `finish` and apply it, don't re-derive it. **Issue-first holds in both
modes**; they differ only in the branch/PR ceremony. What that means for THIS
skill's steps:

- **pr-flow** (default) — the full flow this skill describes throughout: claim →
  `issue/<n>` branch + `spec/.work` marker → implement → push → open PR → CI
  green → transition. Declared-but-unprotected `main`: same flow unchanged, note
  the missing wall, recommend `/steer:protect` (rule 45).
- **solo-trunk** — commit **straight to `main`**: no `issue/<n>` branch, no
  `spec/.work` marker, no PR. Still claim the issue and implement, but close it
  **from the trunk commit** (`Closes #N`, or `Refs owner/repo#N` + an explicit
  close when the tracker repo differs — see Closing ref). Wherever a step below says *branch*,
  *marker*, or *PR*, skip it and substitute the trunk commit — everything else
  (validation, managed-block progress, closure-reason semantics) is identical.
  While a local graduation signal stands, the trunk-push hook surfaces the
  session's first push for a human yes (rule 45).

## Subcommands (distinct, idempotent)

| Subcommand | What it does |
|---|---|
| **`start #N`** | Resolve + validate the issue, detect a conflicting claim, **claim** it, create/reuse the branch and write the work marker (pr-flow only), load linked specs, begin implementing. |
| **`resume #N`** | Reconstruct context from the issue + recorded branch/PR + working tree, reconcile stale markers, continue from the actual lifecycle state. |
| **`status #N`** | **Read-only**: state, claimant, branch, PR, blockers, spec readiness, outstanding validation. Mutates nothing. |
| **`finish #N`** | Validate, update progress, commit, push, open-or-update the PR, **watch CI to conclusion**, then transition. Never `done` merely because a PR was opened. |

Natural language (`Fix the export bug`, `work #123`) may orchestrate `start`
through `finish`, but the phases stay distinct and idempotent — re-running a
phase reconciles rather than duplicates.

**Read the full procedure before executing one:**
[`modes/subcommands.md`](${CLAUDE_PLUGIN_ROOT}/skills/work/modes/subcommands.md).

## Optional flags — read the procedure only when the flag is passed

- **`--reviewed`** — wrap `start`→`finish` in two independent review gates (plan
  gate + code gate) plus a bounded fix loop, so the delivery is vetted rather
  than first-draft. Triage trivial work out of the gates.
  → procedure: [`modes/reviewed.md`](${CLAUDE_PLUGIN_ROOT}/skills/work/modes/reviewed.md)
- **`--hotfix`** — the production-incident fast path (rule `62-hotfix`): a
  `hotfix/<n>-slug` branch, issue after-the-fact, one expedited reviewer, and a
  mandatory traceability follow-up. Relaxes ceremony, never the human gates.
  Use it **only** for an active incident on a deployed production system.
  → procedure: [`modes/hotfix.md`](${CLAUDE_PLUGIN_ROOT}/skills/work/modes/hotfix.md)

Neither flag changes the subcommands above; both leave the merge and deploy
gates exactly where they are.

## Closing ref — check the tracker repo first

GitHub honours issue-closing keywords **only within one repository**. If
`/spec/tracker.md` declares a `repository:` different from the repo the code
lives in, `Closes #N` renders as a plain cross-reference and **the issue
silently stays open** — and because this skill treats the merged PR as
lifecycle-transition evidence, the issue never advances state either.

- **No `repository:` declared, or the value is absent / a placeholder /
  unreadable** → write `Closes #N`. Nothing further to do.
- **A `repository:` is declared** → resolve both sides and compare before
  writing any closing ref:
  [`CLOSING-REF.md`](${CLAUDE_PLUGIN_ROOT}/skills/work/CLOSING-REF.md).

Divert **only on positive proof of a mismatch**.

In a **polyrepo member** the mismatch is structural, not incidental: the tracker
is the workspace's, so a member PR can never auto-close its issue. Take the
`Refs owner/repo#N` + explicit-close path every time, and land the spec update
(the owning `contract.md`) as its own change in the **workspace** repo — those two
PRs cannot be atomic (`/steer:reference polyrepo`).

## Completion semantics

**Closure reason — not the mere fact of closure — decides the terminal state.**
Inspect it before transitioning a closed issue; keep delivery state as independent
evidence (a merged PR — or, in solo-trunk, the closing trunk commit — is
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

In **`--hotfix` mode**, use `hotfix/<n>-slug` instead (see `modes/hotfix.md`).

Its exact format — the write-once `issue:`/`branch:` lines, the newest-first
session list the Stop hook keeps current, seeding from `$CLAUDE_CODE_SESSION_ID`,
and the legacy extensionless-marker upgrade — is in
[`WORK-MARKER.md`](${CLAUDE_PLUGIN_ROOT}/skills/work/WORK-MARKER.md).

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

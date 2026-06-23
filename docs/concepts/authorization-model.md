# Authorization model

`steer` draws a deliberate line between actions that are **cheap and reversible**
(done autonomously) and actions that are **outward-facing or hard to reverse**
(gated on a human). This is codified in the always-on rule
`45-commit-autonomy.md` and reinforced by `95-not-the-gate.md`.

```mermaid
flowchart TD
    START[Coherent unit of work done] --> BRANCH{On a feat/fix branch?}
    BRANCH -->|No, on main| MK[Create feat/* or fix/* branch first]
    BRANCH -->|Yes| COMMIT
    MK --> COMMIT[Commit autonomously<br/>small, conventional message]
    COMMIT --> DONE{Definition of Done holds?}
    DONE -->|No| MORE[Keep working]
    MORE --> COMMIT
    DONE -->|Yes| PROPOSE[Tell dev branch is ready<br/>propose opening the PR]
    PROPOSE --> GATE{{Human confirms}}
    GATE -->|approved| PUSH[Push + open PR]

    classDef gated fill:#fde,stroke:#c39
    class GATE,PUSH gated
```

## What is autonomous

- **Branching** off `main` onto `feat/*` / `fix/*` — never committing to `main`
  directly.
- **Committing** whenever a coherent unit of work is done (tests pass, lint is
  clean, it builds). Do not pause to ask "should I commit?".
- **Creating or reusing the tracking issue** on an explicit implement/capture
  request, in a GitHub-adopted repo (issue-first, rule `36-issue-first.md`). The
  issue and the bounded action set behind it do not need a second confirmation.

!!! note "Issue creation is autonomous — but a host can still gate it"
    Some Claude Code permission modes classify an unprompted `gh issue create` as
    an external write and block it, even though steer authorizes it. The bundled
    scaffold therefore pre-authorizes the tracker-metadata write verbs
    (`gh issue create` / `edit` / `comment`) under `.claude/settings.json` →
    `permissions.allow`, so the find-or-create path is reachable in a
    default-permission session. Delivery (`git push`, `gh pr create`/`merge`)
    stays under `ask`/`deny`. Where a host still blocks the create, it is a
    *host-permission gate, not a missing issue* — confirm with the user or run
    `!gh issue create` under their identity, rather than looping.

!!! note "Exception — solo trunk mode (pre-MVP greenfield)"
    When one person is both PO and dev with no MVP yet, `/steer:init` can put the
    repo in **solo trunk mode** (declared in the product `CLAUDE.md` `## Delivery
    mode` section): commits land **directly on `main`**, with no `feat/*` branch and
    no per-feature PR — there is no second reviewer yet, so the PR gate has nothing
    behind it. CI still runs on every push, and the spine, tests, and Definition of
    Done are unchanged. The mode ends at **graduation** — run `/steer:protect`, which
    raises the server-side PR wall — once the MVP works, you first deploy, or a second
    contributor joins.

## What is gated

- **Pushing and opening the PR.** This is the one step that waits for the dev.
  Everything before it does not. The **PR review is the gate** — not each commit.

!!! note "Watching CI is not crossing the gate"
    After a push, `/steer:work finish` watches CI to conclusion and fixes a red
    build before treating the work as done — that is *finishing* the work, not
    merging. To support this without a prompt per poll, the `work` skill
    pre-approves **read-only** CI status only (`gh pr checks`, `gh run view`,
    `gh run watch`). `git push`, `gh pr create/edit/merge`, `gh api`, and merge
    or deploy stay gated exactly as before.

!!! note "The local boundary is advisory — the server enforces it"
    Rule `95-not-the-gate.md` is explicit that this in-session discipline cannot
    *stop* a direct push to `main`; it only governs how the agent behaves. The
    real wall is **GitHub branch protection**, which `/steer:protect` verifies
    against `policy/branch-protection.yml` and (on the dev's explicit
    confirmation) applies via `gh api`. Run it as the final step of init/adopt to
    turn the advisory boundary into an enforced one.

## Why this matters for the plugin's own skills

The skill frontmatter encodes the same boundary:

- **Tier 1 (read-only)** skills set `disallowed-tools: Edit, Write, NotebookEdit,
  EnterWorktree` — e.g. `drift`, `audit`, `next`, `standards`.
- **Tier 2 (side-effecting)** skills may edit and commit but never push to `main`
  without confirmation — e.g. `sync`, `work`, `tidy`.

See the [Skills reference](../reference/skills.md) for each skill's tier, and
[Configuration](../reference/configuration.md) for how tools are constrained.

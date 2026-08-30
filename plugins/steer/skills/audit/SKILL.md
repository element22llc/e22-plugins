---
name: audit
description: "Repeatable, read-only audits of a managed repo — code mode sweeps repo health against the standards and ranks findings; spec mode surfaces as-built vs intended drift; all runs both. Non-mutating: proposes only, never edits an existing file. Optionally renders an Artifact dashboard."
when_to_use: >-
  Use for a periodic standards-conformance pass — code health and the
  highest-leverage improvements (code), whether the build matches what the
  tracker asked for (spec), or both.
argument-hint: "[code | spec | all]"
allowed-tools:
  - Bash(sh *scripts/scan-spine-state.sh*)
  - Bash(git status *)
  - Bash(git diff *)
  - Bash(git log *)
  - Bash(git show *)
  - Bash(git rev-parse *)
  - Bash(gh issue list *)
  - Bash(gh issue view *)
  - Bash(gh search issues *)
  - Write
# Read-only by construction, with one deliberate exception. Edit/NotebookEdit/
# EnterWorktree are disallowed so the skill cannot mutate existing repo files,
# branch, or worktree. Write STAYS GRANTED for the two post-confirmation outputs
# this skill's modes instruct — the temp-dir Artifact dashboard and the optional
# AUDIT-REPORT.md / DRIFT-REPORT.md — bound in prose by the read-only contract
# below, exactly as /steer:status, /steer:explain, /steer:help and
# /steer:questions bundle mode do. Do NOT disallow Write here: disallowed-tools is
# scoped to the invoking turn and clears at the user's next message, so it buys no
# safety. The read-only contract below is the binding limit.
disallowed-tools: Edit, NotebookEdit, EnterWorktree
---

<!-- steer:modes code,spec,all -->

# Audit a repo — code health and spec conformance (read-only)

## Read-only contract — both modes, whole run

> The in-place edit tools (`Edit`/`NotebookEdit`) and worktree creation are removed
> from the tool pool for the turn that invokes this skill, so neither audit can
> modify existing code or spec. Upstream scopes `disallowed-tools` that way and
> clears it at your next message, so across a multi-turn run the read-only limit is
> one this skill keeps in prose, not one the frontmatter enforces end to end. It
> does not make the repo immutable either — shell mutations stay governed by your
> permission settings and hooks. `Write` **is** granted, and is bound here
> rather than by the frontmatter: use it for **nothing except** the two outputs
> this skill's modes instruct, and only **after** the user confirms them in a
> fresh message — the optional reports (`AUDIT-REPORT.md` / `DRIFT-REPORT.md`)
> and the optional **Artifact dashboard**, whose only write is its HTML to a
> system temp dir, never under the repo tree (rule `88-artifacts`). One further
> temp-only write is sanctioned: the triage export that `/steer:tracker-sync pull`
> materializes into a temp directory when `spec` mode offers it instead of pasting
> — same temp-dir limit, never under the repo tree. Never use `Write` to create or
> replace any other file. Findings reach the tracker via
> `/steer:issues publish-audit` / `/steer:issues publish-drift`, each its own step.

Both modes are **non-mutating** — they never change an existing file and never
commit. The only things either mode may create are the two confirmed outputs
named above, plus the temp-dir triage export. **Make no code or spec edits, and don't commit.** Publishing
findings to the tracker is a separate step (`/steer:issues publish-audit` /
`publish-drift`) — this skill writes no issue itself. Fixing anything is a
separate, approved step on its own branch + PR.

## Coupling rules

The canonical spec ↔ code rules — drift resolution (Rule 5), behavior vs.
incidental implementation, PO vs. dev approval, naming — live in
`${CLAUDE_PLUGIN_ROOT}/templates/reference/SPEC-FRAMEWORK.md`; the full
conventions and patterns behind the `code`-mode dimensions are in
`${CLAUDE_PLUGIN_ROOT}/templates/reference/CONVENTIONS.md` (open via
`/steer:reference conventions`). This skill *detects, ranks, and routes*; those references
govern how each finding gets *resolved*.

## Pick the mode for the question you're asking

- **`code`** *(default — bare `/steer:audit`)* — whole-repo **code-vs-standards**
  health sweep: review the codebase across the standards dimensions, **vet**
  every candidate finding against the code it cites, rank survivors by
  **leverage**, **propose** routing into `/spec`, and hand the survivors to
  `/steer:issues publish-audit` — the separate filing step.
  → procedure: [`modes/code.md`](${CLAUDE_PLUGIN_ROOT}/skills/audit/modes/code.md)
- **`spec`** — **spec-vs-spec** conformance: diff the **as-built `/spec`** (what
  the code actually does, reverse-engineered by `/steer:adopt`) against the
  **tracker spec** (what was asked for) and surface every divergence. The former
  `drift` skill.
  → procedure: [`modes/spec.md`](${CLAUDE_PLUGIN_ROOT}/skills/audit/modes/spec.md)
- **`all`** — run `code` then `spec` in sequence and report both, each with its
  own ranked report and routing. Use it for a full periodic pass (health **and**
  conformance) before a release. If there is no `/spec` spine, `spec` can't run —
  say so and run `code` only. Read each mode's procedure file as you reach it.

**Read only the procedure file for the mode you are running.** They answer
different questions ("is what we built healthy and standards-aligned?" vs. "did
we build what was asked?"), so run `code` for tech-debt/health and `spec` for
conformance. This is the steady-state counterpart to one-time adoption:
`/steer:adopt` builds the spec for a repo that has none; `/steer:audit` runs
again and again on a repo that already has one.

## Polyrepo scope — both modes

Both modes sweep **one tree**. When
`sh "${CLAUDE_PLUGIN_ROOT}/scripts/scan-spine-state.sh"` reports a
`- polyrepo role:` other than `none`, say up front which repos the audit covered and
name any member you could read neither locally nor over the gateway as
**uncovered** — an audit silently scoped to one member reads as a clean bill of
health for the product. Two limits to state rather than paper over: drift that
crosses the repo edge (a member's contract change invalidating a sibling's
assumption) is **not** detected by `spec` mode, and the `55-drift-gates` CI
backstop cannot see sibling repos at all. In a member, resolve the intended spec
from the workspace via `spec/PRODUCT.md` before reporting any feature as
undocumented — the intent is probably there, not missing. Detail:
`/steer:reference polyrepo`.

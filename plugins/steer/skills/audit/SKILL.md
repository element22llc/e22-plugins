---
name: audit
description: "Repeatable, read-only audits of a managed repo — code mode sweeps repo health against the standards and files ranked findings in the tracker; spec mode surfaces as-built vs intended drift; all runs both. Proposes and files, never edits code or spec."
when_to_use: >-
  Use for a periodic standards-conformance pass — audit overall code health and
  the highest-leverage improvements (code), confirm the build matches what the
  tracker asked for (spec), or both (all).
argument-hint: "[code | spec | all]"
allowed-tools:
  - Bash(git status *)
  - Bash(git diff *)
  - Bash(git log *)
  - Bash(git show *)
  - Bash(git rev-parse *)
  - Bash(gh issue list *)
  - Bash(gh issue view *)
  - Bash(gh search issues *)
disallowed-tools: Edit, Write, NotebookEdit, EnterWorktree
---

<!-- steer:modes code,spec,all -->

# Audit a repo — code health and spec conformance (read-only)

## Read-only contract — both modes, whole run

> Native file-edit tools (`Edit`/`Write`/`NotebookEdit`) and worktree creation are
> unavailable while this skill runs, so neither audit can edit code or spec. This
> does not make the repo immutable — shell mutations stay governed by your
> permission settings and hooks. The optional report writes (`AUDIT-REPORT.md`
> / `DRIFT-REPORT.md`) and the optional **Artifact dashboard** happen only after you
> confirm them (a fresh message), by which point the restriction has cleared — and
> the Artifact's only write is its HTML to a system temp dir, never under the repo
> tree (rule `88-artifacts`). Findings reach the tracker via
> `/steer:issues publish-audit` / `/steer:issues publish-drift`, each its own step.

Both modes are **repository-read-only** — never an edit or a commit; their only
writes are tracker issues. **Make no code or spec edits, and don't commit.**
Fixing anything is a separate, approved step on its own branch + PR.

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
  **leverage**, **propose** routing into `/spec`, **file** findings in the
  tracker.
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

Both modes sweep **one tree**. When `steer_polyrepo_role`
(`lib/scope.sh`) reports a role, say up front which repos the audit covered and
name any member you could read neither locally nor over the gateway as
**uncovered** — an audit silently scoped to one member reads as a clean bill of
health for the product. Two limits to state rather than paper over: drift that
crosses the repo edge (a member's contract change invalidating a sibling's
assumption) is **not** detected by `spec` mode, and the `55-drift-gates` CI
backstop cannot see sibling repos at all. In a member, resolve the intended spec
from the workspace via `spec/PRODUCT.md` before reporting any feature as
undocumented — the intent is probably there, not missing. Detail:
`/steer:reference polyrepo`.

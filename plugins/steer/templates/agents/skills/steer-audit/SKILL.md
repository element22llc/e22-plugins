---
name: steer-audit
description: 'Repeatable, read-only audits of a managed repo - code mode sweeps repo health against the standards and ranks findings; spec mode surfaces as-built vs intended drift; all runs both. Non-mutating: proposes only, never edits an existing file. Optionally renders an Artifact dashboard.'
argument-hint: '[code | spec | all] [--since <ref>]'
---

<!-- Generated from the steer plugin's skills/audit/SKILL.md - do not edit by hand.
     Refresh with /steer:sync from Claude Code in a managed repo, or
     `mise run gen:copilot` in the plugin repo. Authored for Claude Code and
     rendered here in the cross-tool Agent Skills format (agentskills.io) that
     Copilot, Cursor, Gemini CLI and Codex read from .agents/skills/. -->

**When to use.** Use for a periodic standards-conformance pass - code health and the highest-leverage improvements (code), whether the build matches what the tracker asked for (spec), or both.

> **Read-only on this surface - enforced by instruction, not by tooling.**
> In Claude Code this skill runs with `Edit`, `NotebookEdit`, `EnterWorktree` removed from the tool pool, but
> only for the turn that invokes it - upstream clears the restriction at the
> user's next message - so even there it is a rule the skill keeps across a
> multi-turn run rather than a guarantee the runtime holds. No other agent has
> even that much: here it is a hard instruction. Treat those capabilities as
> unavailable for the whole run, and read any claim below that they "are
> unavailable" as a rule you must keep rather than a guarantee you can rely on.

<!-- steer:modes code,spec,all -->

# Audit a repo - code health and spec conformance (read-only)

## Read-only contract - both modes, whole run

> The in-place edit tools (`Edit`/`NotebookEdit`) and worktree creation are removed
> from the tool pool for the turn that invokes this skill, so neither audit can
> modify existing code or spec. Upstream scopes `disallowed-tools` that way and
> clears it at your next message, so across a multi-turn run the read-only limit is
> one this skill keeps in prose, not one the frontmatter enforces end to end. It
> does not make the repo immutable either - shell mutations stay governed by your
> permission settings and hooks. `Write` **is** granted, and is bound here
> rather than by the frontmatter: use it for **nothing except** the two outputs
> this skill's modes instruct, and only **after** the user confirms them in a
> fresh message - the optional reports (`AUDIT-REPORT.md` / `DRIFT-REPORT.md`)
> and the optional **Artifact dashboard**, whose only write is its HTML to a
> system temp dir, never under the repo tree (rule `88-artifacts`). One further
> temp-only write is sanctioned: the triage export that `/steer-tracker-sync pull`
> materializes into a temp directory when `spec` mode offers it instead of pasting
> - same temp-dir limit, never under the repo tree. Never use `Write` to create or
> replace any other file. Findings reach the tracker via
> `/steer-issues publish-audit` / `/steer-issues publish-drift`, each its own step.

Both modes are **non-mutating** - they never change an existing file and never
commit. The only things either mode may create are the two confirmed outputs
named above, plus the temp-dir triage export. **Make no code or spec edits, and don't commit.** Publishing
findings to the tracker is a separate step (`/steer-issues publish-audit` /
`publish-drift`) - this skill writes no issue itself. Fixing anything is a
separate, approved step on its own branch + PR.

## Coupling rules

The canonical spec <-> code rules - drift resolution (Rule 5), behavior vs.
incidental implementation, PO vs. dev approval, naming - live in
`https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/templates/reference/SPEC-FRAMEWORK.md`; the full
conventions and patterns behind the `code`-mode dimensions are in
`https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/templates/reference/CONVENTIONS.md` (open via
`/steer-reference conventions`). This skill *detects, ranks, and routes*; those references
govern how each finding gets *resolved*.

## Pick the mode for the question you're asking

- **`code`** *(default - bare `/steer-audit`)* - **code-vs-standards** health
  sweep, whole-repo unless `--since <ref>` bounds it: review the codebase across the standards dimensions, **vet**
  every candidate finding against the code it cites, rank survivors by
  **leverage**, **propose** routing into `/spec`, and hand the survivors to
  `/steer-issues publish-audit` - the separate filing step.
  -> procedure: [`modes/code.md`](modes/code.md)
- **`spec`** - **spec-vs-spec** conformance: diff the **as-built `/spec`** (what
  the code actually does, reverse-engineered by `/steer-adopt`) against the
  **tracker spec** (what was asked for) and surface every divergence. The former
  `drift` skill.
  -> procedure: [`modes/spec.md`](modes/spec.md)
- **`all`** - run `code` then `spec` in sequence and report both, each with its
  own ranked report and routing. Use it for a full periodic pass (health **and**
  conformance) before a release. If there is no `/spec` spine, `spec` can't run -
  say so and run `code` only. Read each mode's procedure file as you reach it.

## Optional diff scope - `--since <ref>`

`code` mode (and the `code` half of `all`) accepts **`--since <ref>`**: review
only what `git diff <ref>...HEAD` changed, plus each changed file's counterparty
surfaces (a changed skill's rule, a changed rule's skills, a changed module's
tests). **Whole-repo stays the default** - a periodic standards pass is supposed
to see the whole tree.

Use it when the question is "did *this work* introduce anything", not "how
healthy is this repo": before a release, on a long-lived branch, or when an
unscoped sweep keeps returning the same unrelated backlog. That is the failure
the flag exists for - an unscoped reviewer samples a corpus that mostly has not
changed in years, so it always finds *something*, each run finds a *different*
something, and the count never trends down however much you fix.

Under a scope, a finding must implicate a changed file. Anything else is
**pre-existing**: count it in one line ("N findings outside the scope, not
listed - run without `--since` to see them"), never rank it, and never let it
head the report. Do not widen the scope because a neighbouring file looks
suspect. `spec` mode takes no scope: as-built-vs-intended is a question about the
whole spine, and a diff cannot answer it.

**Read only the procedure file for the mode you are running.** They answer
different questions ("is what we built healthy and standards-aligned?" vs. "did
we build what was asked?"), so run `code` for tech-debt/health and `spec` for
conformance. This is the steady-state counterpart to one-time adoption:
`/steer-adopt` builds the spec for a repo that has none; `/steer-audit` runs
again and again on a repo that already has one.

## Polyrepo scope - both modes

Both modes sweep **one tree**. When
`sh "https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/scripts/scan-spine-state.sh"` reports a
`- polyrepo role:` other than `none`, scope the report per
`/steer-reference polyrepo` § "Reporting across members" - an audit silently
scoped to one member reads as a clean bill of health for the product. Two limits
to state rather than paper over: drift that crosses the repo edge (a member's
contract change invalidating a sibling's assumption) is **not** detected by
`spec` mode, and the `55-drift-gates` CI backstop cannot see sibling repos at
all. In a member, resolve the intended spec from the workspace before reporting
any feature as undocumented - the intent is probably there, not missing.

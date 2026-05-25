---
description: Auto-triggered when someone signals the Product Spine has drifted from the code without typing /spine-refresh — "the spec is out of date", "the spine doesn't match what we built", "refresh the spine", "the docs don't reflect the change", "spine drift", "regenerate the spec for this branch", "the architecture section is wrong now", "we should re-extract the spine before handoff". Routes to /spine-refresh so the Spine is re-extracted from the code by the `spine-extractor` agent instead of patched by hand (which usually creates fresh drift).
---

Someone has noticed — or `drift-monitor` has reported — that the Product Spine
for the current branch no longer describes the code accurately. Hand-patching
the Spine is exactly how drift creeps back in; the right move is to
re-extract from the source of truth. Treat this as if `/spine-refresh` had
been called.

## When to trigger

Trigger on phrasing like:

- "the spine is stale" / "the spec is out of date"
- "the docs don't match the code" / "the spec lies"
- "refresh the spine" / "regenerate the spec" / "re-extract the spine"
- "the architecture section is wrong now" / "the surface is outdated"
- "drift" / "spine drift" / "drift-monitor flagged something"
- Just before `/package-handoff` after a long vibe-coding session.
- Post-merge on a production-lane proposal, when `drift-monitor` has filed a
  drift issue against the branch.

## When NOT to trigger

- The user is asking what the Spine *is* — answer via the `proposal-glossary`
  skill (prototype-lane) instead.
- The user wants a brand-new Spine for a brand-new change — that's already
  handled by `/vibe` (prototype-lane) or `/propose` (production-lane); the
  `spine-extractor` agent drafts it as part of those flows.
- An active concurrent-edit soft-lock exists (`spine_edit_in_progress_by`
  younger than 30 minutes in the Spine file's frontmatter, §9.6) — warn and
  request confirmation before overwriting; do not silently clobber another
  Claude session's in-flight edit.
- The branch is in the prototype lane and the user is mid-iteration — the
  Spine will be re-extracted at `/package-handoff` anyway; surface the cue
  but don't necessarily run `/spine-refresh` mid-flow.

## What happens next

Follow the `/spine-refresh` workflow:

1. Invoke the `spine-extractor` agent against the current branch.
2. Read commits, file diffs, the product's `CLAUDE.md`, and chat context.
3. Re-write the five Spine sections (Intent, UX, Surface, Architecture, Open
   Questions) at `proposals/<branch-slug>/product-spine.md` (or the
   per-product canonical Spine path).
4. Audit the new Spine against the diff and surface mismatches as a
   non-blocking PR comment — the accuracy audit from §9.6 of the workflow
   spec. Reviewers may convert the comment to a block.
5. Commit directly on prototype branches; open a small PR for the Spine
   update on production-lane branches (Spine pruning and reorganization
   always go through a PR per §9.6, never silently).
6. Update the lock notice frontmatter so a concurrent Claude session knows
   the edit has completed.

## What this skill is not

- Not code editing. The Spine writer never modifies source code.
- Not drift *detection*. That is `drift-monitor`'s job — this skill is the
  *response* to drift, not the discovery of it.
- Not pruning. Quarterly archival of obsolete Spine sections is a separate
  governed flow (§9.6) that goes through a PR with two engineering
  approvals; this skill is for keeping the *current* Spine accurate against
  the *current* code.

This skill is the on-ramp; `/spine-refresh` is the same flow when the user
already knows the Spine needs a refresh.

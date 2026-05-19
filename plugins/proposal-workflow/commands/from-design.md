---
description: Start a Proposal from a Claude Design handoff bundle.
argument-hint: <handoff bundle URL or path>
---

# /from-design

Same flow as `/propose`, but the source of truth for visual/UX intent is a
Claude Design handoff bundle. The bundle defines what the UI should look like;
this command implements that vision against existing code.

## Workflow

1. **Locate and unpack the bundle.**
   $ARGUMENTS is either a Claude Design share URL or a local path to a handoff
   bundle (tar archive). Download/extract it into the proposal branch under
   `design-handoff/`. Commit it as the first commit on the branch — it becomes
   part of the PR artifact and the audit trail.

2. **Read the bundle's README first.**
   Claude Design bundles include instructions for coding agents. Honor those
   before applying Element 22 conventions. The bundle's design tokens may differ
   from `design-system/` if the design intentionally explores new ground —
   surface this to the champion if so.

3. **Identify the affected product and verify the design system match.**
   - Determine target product (same as `/propose`).
   - Compare bundle's tokens against `design-system/`. If they match, proceed.
     If they diverge, ask the champion: "This design uses tokens not in our
     design system. Do you want me to (a) adapt to existing tokens, (b) add
     new tokens, or (c) keep the design's tokens as a one-off?"

4. **Run the rest of `/propose` workflow** from step 3 (preview tier selection)
   onward, with these additions:
   - The PR description must include a "Design source" section linking to the
     original Claude Design project.
   - The `design-handoff/` directory stays in the PR — do not delete it.
   - Frontend implementation must use `frontend-design` plugin conventions if
     installed.
   - Acceptance criteria must include "Preview visually matches the design at
     desktop and mobile breakpoints".

5. **Surface any design-implementation tradeoffs in the PR.**
   If implementation required deviating from the design (accessibility, performance,
   existing component reuse), document each deviation with the reasoning. Designers
   reviewing the PR should not be surprised.

## When you're done

Same chat message as `/propose`, plus:

- Side-by-side comparison: bundle's rendered design vs. preview screenshot
- List of any design-implementation deviations with rationale

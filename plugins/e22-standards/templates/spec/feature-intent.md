# [Feature Name]

> Owner: [PO github handle]
> Status: draft | approved | implemented | validated | live
> Created: YYYY-MM-DD
> Tracker: [ref in this product's format — see /spec/tracker.md — or "none yet"]
> Approved by: [PO github handle — written by `/e22-standards:e22-spec approve`, else "not yet"]
> Approved at: [YYYY-MM-DD — written by `/e22-standards:e22-spec approve`, else "not yet"]

## PO acceptance

- [ ] PO reviewed this intent
- [ ] Open questions resolved or explicitly deferred
- [ ] Approved for implementation
- [ ] PO validated the working demo (after implementation — check only on the
      PO's explicit confirmation after using the running app)

Approval comment/link: [GitHub PR or issue comment]

## What this feature does

[1–2 sentences. Plain language. What can the user do that they could not do before?]

## Why we are building it

[1 paragraph. What problem does this solve? Link the originating issue if there is one.]

Related issue: [tracker ref(s) per `/spec/tracker.md` — e.g. `PROJ-123`, `#123`, `ENG-123` — or "none yet". When work starts from a tracker item, copy its acceptance criteria into this intent; the ref is the pointer back, the spec is the in-repo source of truth.]

## Design source

If this feature was explored in Claude Design or another design tool, link the source here so future readers can trace back, and point to the locally-readable artifact Claude actually extracts from. Optional — omit the section if there is no design artifact.

- **Traceability link:** [Claude Design URL | Figma URL | other] — human-only; Claude cannot fetch authenticated URLs.
- **Extraction source (path):** [e.g., `spec/features/[id]/design-export/` or `spec/design/claude-design/`] — the ZIP/HTML export or screenshots committed in the repo.
- **Type:** [Claude Design ZIP/HTML export | screenshots | screen recording | walkthrough doc | none]
- **Captured by:** [@po-handle]
- **Date:** YYYY-MM-DD

## User experience

[Describe the experience step-by-step from the user's perspective.]

1. User does X
2. System shows Y
3. User confirms, sees Z

## Key concepts & data

[Plain language — what things does this feature deal with, what must the
system remember about each, and how do they relate? No tables or types; the
dev derives the schema in `contract.md` from this.]

- [Thing] — [what it is; what it must remember; what it belongs to]

## Lifecycle expectations

[What happens to those things over time — especially deletion. Omit if
nothing is ever deleted or archived.]

- What does "delete" mean here: gone forever, recoverable, or just hidden?
- If recoverable — for how long, and by whom?
- What happens to related things when this is deleted?

## What is in scope

-
-

## What is out of scope

-
-

## Open questions

Structured so a tool can tell what blocks a gate and who owns it — see the
open-question format in the spec-framework reference (`/e22-standards:e22-spec-scaffold`). Use
stable IDs (`Q-001`, `Q-002`, …). A promoted question keeps its ID and gains a
`tracker:` ref. The seed block below is marked `<!-- e22:placeholder -->` so the
SessionStart open-questions hook ignores it on a fresh scaffold — **delete the
marker** (and the bracketed title) when you fill in a real question.

### Q-001 — [Anything ambiguous the PO needs to decide] <!-- e22:placeholder -->

- status: open            # open | investigating | resolved | deferred | cancelled
- impact: blocking        # blocking | non-blocking
- owner: product          # product | development | design | security | shared
- required_before: intent-approval   # intent-approval | contract-approval | implementation | non-prod-validation | production-release
- tracker:                # issue ref once promoted (e.g. #142), else empty

_Resolution:_ recorded here when answered, then folded into the relevant
normative section above.

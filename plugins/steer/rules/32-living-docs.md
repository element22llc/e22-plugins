## Living documentation — document in parallel, not after

The PO/dev speaks plainly; **you** translate it into durable artifacts *as the
work happens*, never in a wrap-up pass. Specs are living: when conversation or
implementation reveals a requirement, constraint, assumption, risk, trade-off,
or decision, update (or propose) the owning artifact **in the same change as
the code**:

- Intent, goals, acceptance criteria → the feature's `intent.md` (scope
  changes need PO approval); behavior/data/API decisions → `contract.md`;
  hard-to-reverse choices → ADR.
- Ambiguity → `## Open questions` — **never guess an answer into the spec**.
- Usage, workflows, roles, configuration, limitations, troubleshooting,
  release notes → the app guide (`/spec/app/`).
- Tech stack, the apps/packages map, how the pieces fit together → root
  `ARCHITECTURE.md`. Any PR that changes the stack, adds/removes/renames an app
  or package, or reshapes cross-component data flow updates it — and the linked
  architecture diagram (`/spec/design/architecture.md`) — in the same PR.
- Visual identity, reusable design tokens → root `DESIGN.md`, seeded from the
  chosen identity when the first UI lands and grown on the 3+ rule (`Design
  sources`). The same PR that establishes the stack or first app also retires
  the scaffold's now-false placeholder prose (e.g. the `apps/README.md` "starts
  empty" line, `[e.g., …]` cells) — a stub left after the thing it describes
  exists is drift.
- What changed, why, who asked, refs → append to `/spec/HISTORY.md` (action
  history), one short entry per merged change or ratified decision.

PO-facing artifacts (intent, vision, app guide) stay plain-language;
dev-facing ones (contract, ADR) stay precise enough to implement and review
against. A declined proposal becomes an open question, not silence. Full
conventions + worked examples: run **`/steer:reference traceability`**.

**Applying a decision already made is not a new decision.** Propagating a
settled choice into the artifacts that should reflect it — a one-liner into
`CLAUDE.md`, a consistency edit, a superseding ADR, a fact grounded from the
code — is living-docs upkeep: make the edit in the same change and let the
**PR be the gate** (you are not it — see rule `95-not-the-gate`).
Pause for a yes only when the *decision itself* is unmade — a genuine
product / policy / architecture call, or anything under **High-risk areas** —
or when an edit would clobber filled-in content. Don't stop to ask "shall I
apply this?" once the decision exists.

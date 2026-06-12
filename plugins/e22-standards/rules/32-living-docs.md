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
- What changed, why, who asked, refs → append to `/spec/HISTORY.md` (action
  history), one short entry per merged change or ratified decision.

PO-facing artifacts (intent, vision, app guide) stay plain-language;
dev-facing ones (contract, ADR) stay precise enough to implement and review
against. A declined proposal becomes an open question, not silence. Full
conventions + worked examples: run **`/e22-traceability`**.

---
description: Sweep every open question across the /spec spine (each feature's intent.md and vision.md) and walk the PO/dev through answering each, folding decisions back into the spec. Read-then-propose — never guesses an answer or edits without a yes.
---

Resolve this product's open questions by following the `e22-questions` skill.

Gather every open question across the spine: each `spec/features/*/intent.md`
and `spec/vision.md` (`## Open questions` sections), plus `PRODUCTIONIZATION.md`
if present. Present a consolidated worklist (product-level first, then per
feature). Walk the PO/dev through each — product/behavior questions to the PO in
plain language, technical/architectural ones to the dev — asking, never
inventing. For each answer, propose the spec edit (update the owning
`intent.md`/`contract.md` or `vision.md`, strike the question), applying it on a
yes; note PO vs dev approval. Explicit deferral with a reason is a valid
outcome; an unanswerable question stays open rather than guessed.

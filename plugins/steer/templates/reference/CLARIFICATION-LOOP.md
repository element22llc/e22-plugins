# The PO clarification loop

How steer gets open questions answered by a Product Owner who has no repo and
no Claude Code. This file is the **single source of truth** for the contract
the two ends of the loop share — the machine-keyed return-document format, the
segmentation rule for the inbound document, and the three-bucket routing with
its durability rules. `/steer:questions bundle` (outbound) and
`/steer:intake clarify` (inbound) each own their operational steps and defer
here; when the contract changes, it changes in this one place.

## The loop

1. **Outbound — `/steer:questions bundle`** gathers the PO-answerable open
   questions across the spine and renders them as a shareable, **fillable
   questionnaire** — a Claude Artifact, or the same fillable Markdown printed
   inline where the Artifact tool is unavailable (rendering discipline:
   [`ARTIFACTS.md`](ARTIFACTS.md), rule `88-artifacts`). Bundle changes nothing
   in the spec.
2. **Offline — the PO answers in a browser.** They fill each answer, copy out
   the return document below (a hosted page stores nothing, so the export is
   the only data channel back), and send it on by whatever route they like —
   email, chat, pasted into Word and returned as a `.docx`.
3. **Inbound — `/steer:intake clarify <filled-doc>`** absorbs the export like
   any PO source document (version-stamped and committed under
   `spec/sources/`), segments it into units, maps each unit — by its machine
   key where present — and sorts them into the three-bucket worklist below.
4. **Fold — `/steer:questions`** (the default resolve flow) applies each routed
   answer to the spec under its step-6 tier gate and strikes the question.

## The return-document contract

The questionnaire's copy-box, its "Download .md" export, and the Markdown
fallback all emit the **same** document — each answer under a heading carrying
its **feature-scoped key**, `[<feature-id>] Q-NNN`:

````markdown
# steer clarification questionnaire
<!-- steer:clarification-bundle -->
Fill in each **Answer** block below, then send this file back.
Do not change the "[feature] Q-NNN" heading lines — they map your answers to the spec.

## [accounts] Q-017 — Should deleted accounts be purged or retained? [BLOCKING]
<!-- steer:q feature=accounts id=Q-017 source=spec/features/accounts/intent.md -->
> Context: the intent leaves the retention window for deleted accounts open.

**Answer:**
_(type your answer here)_

---
````

- **The machine key is the `[<feature-id>] Q-NNN` pair**, both parts visible in
  the heading. This matters because **`Q-NNN` ids restart per feature** — they
  are unique only *within* a feature, so a whole-spine bundle can contain two
  different `Q-017`s; the bracketed feature id disambiguates them and makes the
  key spine-unique.
- **Product-level questions** — from `vision.md`, `PRODUCTIONIZATION.md`, or a
  legacy `SPEC-QUESTIONS.md` (see the v1.25.0 entry in
  [`MIGRATIONS.md`](MIGRATIONS.md)) — have no feature home: scope them
  **`[product]`**.
- **Both parts are plain heading text**, so the key survives any document
  round-trip (a PO pasting the Markdown into Word and sending back a `.docx`),
  unlike an HTML comment. The `<!-- steer:q feature= id= source= -->` comment
  restates the key plus the source path as machine-readable provenance — a
  best-effort aid, not the authority; the visible heading is.
- **Nothing volatile is embedded** (no git SHA), so two downloads of the same
  answers stay byte-identical for intake's binary-hash idempotency guard.

### Key matching — valid, stale, and unknown keys

- A **valid key** is a pair that matches a currently-**open** question: locate
  `Q-NNN` *in the named feature* (`[product]` → `vision.md` /
  `PRODUCTIONIZATION.md` / a legacy `SPEC-QUESTIONS.md`). Always match the
  **pair**, never the bare `Q-NNN` — ids restart per feature, so a bare `Q-017`
  is ambiguous across a whole-spine bundle.
- A pair match maps **directly** — an exact key match, not a semantic guess —
  so it is high-confidence and bypasses fuzzy semantic matching entirely.
- A **stale or unknown key** — one that matches no currently-open question
  (answered, renumbered, or a mistyped feature since the bundle was generated)
  — is **never force-applied, and never silently filed or dropped**: it is
  surfaced in bucket 3 for the human to place.

## Segmenting an inbound clarification document

**Segment only a valid extraction.** If the converter was unavailable, the
format is non-convertible, or the extraction is empty/garbled (a scanned PDF
with no text layer — `extraction: none`), stop before segmenting: commit the
binary, record `extraction: none`, and raise an Open question asking the PO for
a text-bearing copy. Never segment absent or garbled text into spurious
"clarification units."

**Default — segment semantically.** An arbitrary client document arrives in
whatever shape the client wrote it (prose, a table, an inline email reply, no
tidy `Q1/Q2` numbering), so segment it into discrete **clarification units**
*semantically*, not structurally — do not rely on numbering or headings the
client may not have used. Each unit carries its **exact quoted source span**
from `extracted.md`. When a paragraph fuses several answers, or an answer is
split across a table cell, err toward a **larger** unit **flagged for the human
to split** — never confidently over-split. Drop preamble, pleasantries, and
anything that answers nothing; do **not** force-map a non-answer.

**Exception — a recognized bundle return segments structurally.** When the
extraction is a questionnaire this org emitted (`## [<feature-id>] Q-NNN — …`
headings, typically under a `<!-- steer:clarification-bundle -->` marker or a
`# steer clarification questionnaire` title), it is *not* an arbitrary client
document: each such heading is a deliberate unit boundary. Segment **one unit
per heading** — carrying the heading's feature-scoped key (both parts) and its
`**Answer:**` body as the quoted span — rather than re-fusing them
semantically. Treat an `**Answer:**` block left at its `_(type …)_` placeholder
— or otherwise empty — as unanswered: drop it, don't map it. Free-text the PO
added outside the question headings is segmented semantically as usual.

## The three-bucket worklist

The mapping is printed as a worklist the human confirms in a **single pass** —
they correct the wrong rows; they never dictate question IDs. Every unit lands
in one of three buckets:

| Bucket | Unit | Routes to |
|---|---|---|
| **1 — answers an open question** | confident match to an open `Q-NNN` (a key match, or a confident semantic match) | intake's step-5 reconcile row for answers, which hands the fold to `/steer:questions` (its step 6). Still tier-gated there: a genuine unmade product decision stays human-gated; a decides-nothing-new answer auto-applies with the PR as the gate |
| **2 — new info** | maps to a feature, answers no open question | intake's existing step-5 reconcile rows (`/steer:spec` / `/steer:spec-scaffold` / `/steer:roadmap` / `/steer:audit`) — new scope routes exactly as a spec-doc change does |
| **3 — unmatched / low-confidence** | can't be placed confidently, or carries a stale/unknown key | **surfaced for the human** — "where does this go?" — **never guessed**; may become a new `Q-NNN` |

### Durability — nothing lives only in the worklist

The worklist is only the in-session presentation; each bucket writes a durable
output as it is worked:

- **Bucket 1** — intake annotates the matched `Q-NNN` with the **proposed
  answer**, its **source-ref** (`spec/sources/<id>/versions/<v>/`) and **exact
  quoted span**, marked **`pending /steer:questions fold`**. This is the same
  durable Open-questions write intake already makes when it *raises* a `Q-NNN`
  in default mode — it is **not** a resolution: intake does not strike the
  question, fold the answer into `intent.md` / `vision.md`, or decide anything.
  The annotation is written **update-in-place per `Q-NNN`** (find the existing
  pending line and replace, not append): if the question already carries a
  pending answer from an earlier absorb, overwrite it with the newer
  answer/source-ref rather than stacking a second — so re-absorbing the same
  bundle (e.g. when a browser re-download changed the bytes enough to slip past
  intake's hash guard) reconciles to one pending answer, never duplicates.
- **Bucket 2** — routed through intake's step-5 gateways, which write durably
  under their own gates.
- **Bucket 3** — raised as a new `Q-NNN`, or left explicitly for the human to
  place; never guessed.

### Ownership — intake routes, questions folds, the halves never cross

**Intake owns ingestion + routing:** the `spec/sources/` commit, the pending
proposed-answer annotations / raised `Q-NNN`s, the step-5 gateway routing, and
— at its step 6 — the `spec/HISTORY.md` row and advancing `source.md`'s
`Latest absorbed version`. **"Absorbed" means the doc was ingested and every
unit durably routed — not that every answer has been folded.**
**`/steer:questions` owns the fold:** it applies its step-6 tier gate to the
pending answer, writes it into the owning `intent.md` / `vision.md` with the
source-ref + quoted span as provenance, and strikes the question. Questions
never touches the source pointer; intake never folds. Advancing the pointer is
therefore correct and strands nothing — the pending answers are already durable
on the `Q-NNN`s.

**Re-running is a plain no-op, not the recovery path.** Because routing outputs
are durable, re-running `clarify` on the same binary hits intake's binary-hash
guard and reports `already absorbed` — the doc is already ingested and routed.
An interrupted run loses nothing already written; finish any un-folded answers
with **`/steer:questions`**, whose sweep finds the
`pending /steer:questions fold` annotations on the `Q-NNN`s. Do **not** re-run
`clarify` to resume — it cannot, and does not need to.

**Honesty limit.** Perfect auto-mapping on an arbitrary messy document is not
achievable, and the loop does not pretend otherwise. Its value is collapsing
the common case to a glance-and-confirm and containing the ambiguous case to
explicit human placement, with a hard floor of **no silent wrong write**: an
unconfident unit lands in bucket 3, never force-bound to the nearest question.

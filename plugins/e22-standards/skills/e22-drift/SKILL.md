---
name: e22-drift
description: Audit implemented code against the full spec — and a batch of source tickets (pasted or exported) — to expose drift. Use when asked to compare a built app to its specs, check for spec drift, or verify code matches a set of Jira/issue tickets. Read-only: reports findings and proposes Rule-5 resolutions, never edits.
---

# Audit code against the spec (drift report)

A **manual, read-only conformance audit.** It compares what the product is
*supposed* to do — the `/spec` spine plus a batch of source tickets the dev
brings — against what the code *actually* does, and surfaces every divergence.

**It never edits code or spec.** Its outputs are a drift report, a proposed
Rule-5 resolution per finding, and `spec-drift` issues for anything needing a
human decision. Resolving drift is a separate, approved step (see the
spec-framework reference, Rule 5).

This is the inverse of `/e22-adopt` (which goes code → spec when no spec
exists). Here a spec exists and you verify the code conforms to it.

## When to run

- After landing a batch of work that spanned several tickets, to confirm the
  build matches the combined intent.
- Periodically, to catch drift that accumulated across many small PRs.
- Before a release or handoff, as a conformance check.

## Inputs

1. **Source tickets** — the "intended behavior" set the dev is checking against.
   The dev either **pastes them into the chat** or **points to an export**
   (e.g. a Jira CSV/JSON/Markdown dump or a directory). Ask which, if not given.
2. **The `/spec` spine** — `features/*/intent.md` + `contract.md`, `decisions/*`,
   `vision.md`, `glossary.md`.
3. **The code** — `/apps` and `/packages`.

## Phase 1 — Reconcile tickets ↔ spec (flag gaps; do NOT write)

The `/spec` spine is the durable source of truth; tickets are intake. This phase
checks whether the spec has absorbed everything the tickets asked for.

1. **Gather the ticket set.** If pasted, use the chat text. If pointed to an
   export, read the files at that path. Normalize each ticket to a one-line
   *intended behavior* + its acceptance criteria. Don't invent detail the ticket
   doesn't state — flag vagueness instead.
2. **Map each ticket to a `/spec` feature** (the `contract.md`/`intent.md` whose
   behavior it belongs to). Classify:
   - **In spec** — the ticket's behavior is captured in a contract.
   - **Spec gap** — the ticket's behavior is in **no** spec (spec lags tickets).
   - **Spec-only** — spec behavior with no backing ticket (usually fine; note it).
3. **Emit a coverage table** (ticket → feature → In spec / Spec gap). Per the
   *report + propose only* autonomy: for each spec gap, **propose** the spec
   addition (which `contract.md`/`intent.md`, what to add) — **do not write it.**
   Treat the spec, after these proposed additions are mentally folded in, as the
   "now-current spec" that Phase 2 audits against.

## Phase 2 — Audit code against the spec (+ ticket expectations)

For every expected behavior in the reconciled set (spec contracts, augmented by
the ticket behaviors from Phase 1), locate the owning code — via the
`contract.md` pointer if present, else search the repo — and classify it with
**file:line evidence**:

| Verdict | Meaning |
|---|---|
| ✅ **Conforms** | Code matches the spec'd behavior. |
| ⚠️ **Drifted** | Code does something different from the spec. |
| 🔴 **Missing** | Spec'd (or ticketed) but not implemented. |
| 🟡 **Extra** | Implemented behavior in no spec or ticket — often where un-spec'd tickets landed. |
| ❓ **Ambiguous** | Spec too vague to judge; needs clarification. |

Read the real code as the evidence — never assert conformance from the spec
alone. Cite `path:line`. For many features this fans out cleanly (one reviewer
per feature); do that if the audit is large.

## Output — report + propose only

1. **Drift report.** Print it: the Phase-1 coverage table, then a per-feature
   findings table (verdict + evidence + one-line note). Offer to also write it to
   `/spec/DRIFT-REPORT.md` on a `feat/e22-drift` branch **only if the dev wants it
   tracked** — it's a point-in-time artifact, not part of the durable spine.
2. **Proposed resolution per finding**, following Rule 5 (spec-framework
   reference): fix the code to match the spec, **or** update the spec to match the
   code. Note which path needs **PO** approval (user-facing behavior changed) vs.
   **dev** approval (internal/architectural).
3. **Open `spec-drift`-labelled issues** for findings that need a human decision,
   so drift becomes a tracked item rather than a quiet failure.
4. **Make no code or spec edits, and don't commit.** This skill stops at the
   report and proposals. Ambiguities go to a proposed `/spec/SPEC-QUESTIONS.md`
   entry, not a guess.

## Coupling rules

The canonical spec ↔ code rules — drift resolution (Rule 5), behavior vs.
incidental implementation, PO acceptance, naming — live in
`${CLAUDE_PLUGIN_ROOT}/templates/reference/spec-framework.md`. Read it for the
full rules. This skill *detects and reports* drift; that reference governs how
it gets *resolved*.

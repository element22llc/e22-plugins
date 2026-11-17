# `/steer-spec questions` - folding an answer back (step 6)

Read this file before the first fold of a sweep. The tier gate in `SKILL.md`
step 6 - auto-apply, ask first, doc-sourced answers on the same gate - and step
8's "never guess a decision" still bind every edit here: this file is only how
an answer the gate already let through is written into the spine.

## For each answered question

- Update the owning `intent.md` / `contract.md` (or `vision.md`) so the
  decision lives in the durable spec, not just the chat.
- **Close the question in its `## Open questions` block** - set
  `status: resolved` and record the decision in its `_Resolution:_` line
  (the block stays, so its `Q-NNN` id keeps resolving from anything that
  cites it - a promoted issue, an ADR, a `pending fold` annotation). A
  legacy checkbox item is converted to a resolved `Q-NNN` block (step 2)
  rather than merely ticked.
- **An accepted recommendation says so** - its `_Resolution:_` reads
  `recommended, accepted by <who>`, not `decided by`, so the reviewer can
  see which answers nobody actively chose.
- **Code-fact answers** carry the grounding (`file:line`), marked
  **dev-sign-off** - confirmed at PR review, not decided now. User-facing
  answers reflect **PO** decisions, other technical answers **dev**
  decisions (spec-framework Rule 5); that sign-off is the PR.
- **Doc-sourced answers** (from `/steer-intake clarify`) are folded with
  their **source-ref** and **exact quoted span** - as code-fact answers
  carry `file:line` - so a mis-mapped clarification is auditable and
  reversible at PR review, and closed like any other answered question.
- A hard-to-reverse or cross-cutting answer -> **`/steer-spec adr`**; propagating
  a decision *already made* into a superseding ADR is itself auto-apply.
- A question that needs a **named owner, blocks multiple features, needs
  stakeholder/research input, or could outlive the session** -> promote it to
  a tracker item (keep-vs-promote test: `ISSUE-WORKFLOW.md`). **A blocking
  question the hook flagged as stale (past its threshold) has, by that fact,
  outlived the session - promote it now.** Keep the structured `Q-NNN` in
  the spec and set its `tracker:` field to the ref - don't delete it; the
  issue carries the same id via `<!-- steer:question-id=Q-NNN -->`. On a
  GitHub tracker, **`/steer-issues`** (via `/steer-tracker-sync`) opens the
  `spec-question` issue; on other trackers, file per `/spec/tracker.md` and
  write the ref back. **Assign the owner** via the `owners:` map in
  `/spec/tracker.md` - the role->login rules (`shared` -> both, blank ->
  unassigned + `needs:triage`, never fabricate a login) are in
  `ISSUE-WORKFLOW.md`. **Reconciliation floor:** the promoted question
  carries its ref, and once its issue is answered/closed the decision is
  folded into the spec's normative prose - a closed issue with a
  still-`open` question is a validation failure (`/steer-spec validate`).
  The inverse holds too: **resolving a promoted question closes its issue**
  `completed` with the change that folds the answer - its closing ref in the
  PR (or the solo-trunk commit), per `/steer-work` -> Closing ref. An answer
  routed to an ADR puts that issue in the ADR's `> Tracker:` instead, and
  `adr accept` closes it.

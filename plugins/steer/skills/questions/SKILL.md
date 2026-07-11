---
name: questions
description: Sweep every open question across the /spec spine — each feature's intent.md and vision.md — and walk the PO/dev through answering each one, folding the decision back into the spec. In bundle mode, render the PO-answerable open questions across the whole spine as a shareable, fillable Claude Code Artifact (with a Markdown fallback) so a Product Owner with no repo or Claude Code access can answer them in a browser and send the result back through /steer:intake clarify.
when_to_use: Use to work down accumulated open questions, before a release or PO→dev handoff, or when asked to resolve or review open questions — including when a client clarification document ingested via /steer:intake clarify supplies answers to fold in. Use bundle mode when you need to hand a Product Owner the open questions to answer offline — it produces a fillable questionnaire (Artifact or Markdown) covering every feature at once.
argument-hint: "[bundle [<feature-id>]]"
---

<!-- steer:modes default,bundle -->

# Resolve open questions (`/steer:questions`)

Open questions are the spine's quiet failure mode: they get written down once,
gated at PO acceptance, then left to rot. This skill is the **workflow that
answers them** — it gathers every open question across the `/spec` spine,
walks the PO/dev through each, and folds the decision back into the spec so the
question stops being open.

It gathers every open question, then resolves each **by tier**. Answers that
**make no new decision** — code-facts grounded from the code (step 4), and
decisions already made — are folded straight back into the spec in the same
change, with the **PR as the gate**; the skill does not stop to ask "shall I
apply this?" for those (rule `32-living-docs`: *applying a decision already made
is not a new decision*). A **genuine decision the human hasn't made** — a
product/policy/architecture call — is routed to them (step 5) and applied only
on a yes. It never *invents* a decision; an unanswerable one stays open rather
than being guessed.

## Modes

`default` (no argument): the **resolve** workflow — gather every open question and
walk it to an answer, folding decisions back into the spec (the steps below,
starting with the `SPEC-QUESTIONS.md` heal in step 1). This is a **write** path.

`bundle` (`bundle [<feature-id>]`): the **outbound** path — render the
PO-answerable open questions as a shareable, fillable questionnaire (a Claude Code
Artifact, or Markdown where that's unavailable) for a Product Owner to answer in a
browser and send back via `/steer:intake clarify`. See
[Bundle mode](#bundle-mode-bundle).

> **Dispatch `bundle` first — before step 1.** A `bundle` invocation renders and
> **stops**; it must **not** fall through into the default resolve flow (steps
> 1–8 below). Route on the argument at the very top, before anything below
> executes — otherwise step 1's unconditional `SPEC-QUESTIONS.md` delete would
> violate the read-only guarantee. The single authoritative list of what bundle
> must not write is the **Read-only** invariant in the Bundle mode section below.

## Where open questions live

There is **no `SPEC-QUESTIONS.md`** — questions live next to their context:

- **Per feature** → each `spec/features/*/intent.md` → `## Open questions`
  (the `- [ ]` items).
- **Product-level** (greenfield vision ambiguities, whole-repo adoption
  questions — anything not yet tied to one feature) → `spec/vision.md` →
  `## Open questions`.
- If present, `spec/PRODUCTIONIZATION.md` → `## Open questions` (dev-facing
  hardening ambiguities). **Honor its `> Lifecycle:` field:** when it is
  `published-snapshot`, the adoption-progress / gap-analysis **checkboxes are now
  tracked as issues** — treat them as historical evidence, not open work; only
  its `## Open questions` are still live here.

A fork from an older template revision (pre-1.25.0) may still carry the retired
standalone `spec/SPEC-QUESTIONS.md`. If it does, step 1 migrates its questions
into the locations above and removes it — so this skill also self-heals the
drift, not just consumes it.

## When to run

- Periodically, to work the backlog down before it accumulates.
- Before a **release** or a **PO→dev handoff**, as a "nothing unanswered left
  to rot" gate.
- Whenever a feature's `## Open questions` list has grown and nobody has
  circled back.

A SessionStart hook (`check-open-questions.sh`) counts outstanding open
questions and surfaces the backlog every session, so it can't quietly
accumulate — this skill is how you act on that nudge and clear it. The hook also
**escalates a blocking question still open after 14 days** (measured from its
`created:` date, or the heading's `git blame` date when absent) with its own
loud line — that is the cue to promote it to a named owner (step 6) or defer it
with a reason (step 7).

## Steps

1. **Heal a legacy `SPEC-QUESTIONS.md` first — migrate *and delete* before you
   answer anything.** Before gathering, check for the retired standalone file a
   pre-1.25.0 fork may still carry:

   ```sh
   test -f spec/SPEC-QUESTIONS.md && echo "legacy SPEC-QUESTIONS.md present — migrate it before gathering"
   ```

   If it exists, this migration is a **hard gate**: the file's questions move
   into the spine and `spec/SPEC-QUESTIONS.md` is **deleted as part of this
   step**, before the sweep touches them. Do not skip it because the spine's
   `## Open questions` sections look empty — empty/placeholder sections are
   exactly the pre-state this step fills. Migrate:
   - Read its `## Open` items. Route each to its context — a question tied to a
     specific feature → that feature's `spec/features/*/intent.md` →
     `## Open questions`; anything product-level → `spec/vision.md` →
     `## Open questions`. Preserve each item's Context / Options / Owner notes;
     create the `## Open questions` section in the destination if it's absent.
   - Read its `## Resolved` items. If the decision is already reflected in the
     owning `intent.md` / `contract.md`, drop it; otherwise fold the decision
     there first so it isn't lost.
   - This is a **move, not an answer** — never invent or resolve anything while
     migrating. Propose the migration (which items land where) **and the
     deletion together**, and on a yes apply it and **delete
     `spec/SPEC-QUESTIONS.md`**. Only the migrated copies in the spine survive;
     they flow into the normal sweep below, where you answer them.
   - **Never keep the file alive as a working store.** Do not "update
     `SPEC-QUESTIONS.md` in place," move its resolved items into a `## Resolved`
     section, leave its deferred items under `## Open`, or defer its retirement
     to "a later step." Once its content is preserved in the spine the file is
     deleted in this same step — its continued existence after this skill runs is
     a failure, not a deferral. The deletion is unconditional and does **not**
     wait on the questions being answered.

2. **Gather.** Collect every open question across the spine. A grep over the
   `## Open questions` sections finds them — for example:

   ```sh
   grep -rn -A20 '^## Open questions' spec/vision.md spec/features/*/intent.md \
     spec/PRODUCTIONIZATION.md 2>/dev/null | grep -E '^\S+:[0-9]+[:-]- \[ \]'
   ```

   The grep's `-A20` window is usually enough context — **don't read each owning
   file wholesale.** Open a file only for a specific bullet whose meaning the
   grep output didn't capture, and read just that `## Open questions` section.
   Skip items already resolved (`- [x]`) or annotated as a deliberate deferral.

3. **Present a worklist.** Print a consolidated table — **product-level
   (`vision.md`) first**, then per feature — with the source file and the
   question. Flag any the SessionStart hook escalated as **stale** (blocking,
   open >14 days) — those jump the queue: promote (step 6) or defer (step 7).
   If there are none, say so and stop. Don't bury the list; this is
   the artifact the PO/dev acts on.

   **Stamp `created:` as you go.** Any question you newly raise gets
   `created: <today>` so its age is tracked. A pre-existing question missing
   `created:` is left blank, *not* back-stamped to today — back-stamping would
   reset its clock and hide the rot; the hook ages it from `git blame` instead.

4. **Triage: code-fact vs human-decision (do this before any investigation).**
   In a reverse-engineered spec (`/steer:adopt`), most open questions are *factual
   questions about what the code already does* — "is `X` dead code?", "does the
   client or server enforce this rule?", "what roles exist?" — **not** decisions.
   These are not for the human: asking the PO/dev what their own code does wastes
   a turn. Split the worklist into two buckets:
   - **Code-fact** — answerable by reading the code the question names. Ground it
     and propose a dev-sign-off answer (step 6).
   - **Human-decision** — genuine product / policy / roadmap / architecture calls
     (retention windows, pricing, consent, lifecycle intent). Route to a human
     (step 5).

   **Cost guardrail — this is where the skill gets expensive if you let it.**
   Ground code-facts the *cheap* way: targeted, inline reads of the specific
   file/symbol each question names, batched into one pass. Each question usually
   needs one or two `grep`/`Read` calls, not a search of the repo.
   - Do **not** spawn an investigation agent per question or per subsystem — a
     fan-out of Explore agents over a 20-feature spec can burn hundreds of
     thousands of tokens to answer questions a handful of greps would settle.
   - Escalate to **at most one** bounded subagent for the *entire* batch, and
     only if several questions genuinely need a broad cross-file search you can't
     do inline. Give it the explicit question list and tell it to return answers,
     not a codebase tour.
   - If grounding a particular question would cost more than the answer is worth,
     leave it open and say so — an honest "unverified, needs a look" beats an
     expensive sweep.

5. **Route each human-decision to its owner.** Reuse the standard PO-vs-dev split:
   - **Product / behavior** ambiguities ("what should delete mean?", "which
     users see this?") → ask the **PO** in plain language.
   - **Technical / architectural** ambiguities (data model shape, integration
     boundary, library choice) → ask the **dev**.

   Ask, don't invent. Work through them oldest/most-blocking first.

6. **Fold each answer back into the spec — by tier** (rule `32-living-docs`:
   *applying a decision already made is not a new decision*).
   - **Auto-apply, no per-edit yes** — answers that decide nothing new: a
     **code-fact** grounded from the code (step 4), or a human-decision the
     PO/dev *just made* in this session. Write the spec edit (and any docs that
     must stay consistent with it — a `CLAUDE.md` one-liner, a superseding ADR)
     in the same change and let the **PR be the gate** (rule `95-not-the-gate`).
     This is the friction this skill exists to remove — don't stop to ask
     "shall I apply this?".
   - **Ask first** — a genuine product/policy/architecture decision *not yet
     made*, or anything under **High-risk areas** (rule `60-high-risk`): never
     blind-write it. Route it (step 5) and apply only once the human answers.
     Never invent a decision (step 8).
   - **Answer sourced from an ingested clarification doc** — a `Q-NNN` may carry a
     **`pending /steer:questions fold`** annotation recorded by `/steer:intake
     clarify` (a client clarification whose unit was mapped to this question,
     carrying its source-ref + quoted span) rather than an answer given in-session.
     The sweep (step 2) surfaces it like any other open question. Treat the pending
     answer as **the human's answer** and apply the **same tier gate above**:
     auto-apply if it decides nothing new; **ask first** for a genuine unmade
     product/policy/architecture decision or a **High-risk area**. It does not get
     a lighter gate for arriving as a document. Fold it via this skill — intake
     records the pending annotation but never writes the resolution itself.

   For each answered question:
   - Update the owning `intent.md` / `contract.md` (or `vision.md`) so the
     decision lives in the durable spec, not just the chat.
   - **Strike the question from its `## Open questions` list** — mark it `- [x]`
     with the decision, or remove it once the decision is captured elsewhere in
     the spec.
   - **Code-fact answers** carry the grounding (`file:line`) and are marked
     **dev-sign-off** — the dev confirms the as-built reading at PR review
     rather than deciding now. User-facing answers reflect **PO** decisions,
     other internal/technical answers reflect **dev** decisions (spec-framework
     Rule 5); that sign-off is the PR, not a per-edit yes.
   - **Doc-sourced answers** (from `/steer:intake clarify`) carry the
     **source-ref** (`spec/sources/<id>/versions/<v>/`) and the **exact quoted
     span** they came from — the same way code-fact answers carry `file:line` — so
     a mis-mapped clarification is auditable and reversible at PR review. They are
     struck with the decision like any other answered question.
   - A hard-to-reverse or cross-cutting answer → record it via **`/steer:adr`**;
     propagating a decision *already made* into a new or superseding ADR is
     itself auto-apply, not a fresh ask.
   - A question that needs a **named owner, blocks multiple features, needs
     stakeholder/research input, or could outlive the session** → promote it to a
     tracker item (the keep-vs-promote test is in `ISSUE-WORKFLOW.md`). **A
     blocking question the SessionStart hook flagged as stale (open >14 days)
     has, by that fact, outlived the session — promote it now** rather than
     letting it rot another cycle. Keep the
     structured `Q-NNN` in the spec and set its `tracker:` field to the ref —
     don't delete the question; the issue carries the same id via
     `<!-- steer:question-id=Q-NNN -->`. On a GitHub tracker, **`/steer:issues`**
     (routing through `/steer:tracker-sync`) opens the `spec-question` issue; on
     other trackers, file it per `/spec/tracker.md` and write the ref back.
     **Assign the owner:** resolve the question's `owner:` role to a GitHub login
     via the `owners:` map in `/spec/tracker.md` and assign the issue to it
     (`owner: shared` → product **and** development; a blank/missing row → leave
     unassigned with `needs:triage`; never fabricate a login). The
     role→login table is in `ISSUE-WORKFLOW.md`.
     **Reconciliation floor:** a promoted question must carry its ref, and once
     its issue is answered/closed the decision must be folded into the spec's
     normative prose — a closed issue with a still-`open` question is a
     validation failure (`/steer:spec validate`).

7. **Explicit deferral is a valid outcome.** If a question genuinely can't be
   answered yet, keep the item but annotate it with **why** it's deferred (and a
   revisit trigger if there is one) so it reads as a deliberate decision, not
   neglect. A deferred question is tracked, not rotting.

8. **Never guess a decision.** A human-decision the human can't answer stays
   open, unchanged — don't invent it. (Grounding a *code-fact* in the actual code
   is not guessing; that's the cheap, correct move from step 4.)

## Done when

- `spec/SPEC-QUESTIONS.md` does **not** exist if it did at the start — its
  questions were migrated into the spine (step 1) and the file deleted in that
  same step. A run that leaves the legacy file behind — answered, partially
  migrated, or "to retire later" — is **not** done.
- Every swept question is either struck with its decision or left open with an
  explicit deferral reason. None were silently dropped or guessed.

## Recommend the next action

End with a `## Recommended next actions` block per
`${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md`, scoped to the
questions just swept (locality rule).

| Observed state | Category | Action / suggested command |
|---|---|---|
| Blocking question stale (open >14d), not promoted | Blocking now | Promote it — `/steer:issues` opens a `spec-question` issue assigned to its `owner` via the tracker.md map |
| Open question still `impact: blocking` | Blocking now | Route to its `owner` (product/dev/design/security) for a decision (no command) |
| Genuine unmade product/architecture decision left open | Human decision required | The owning human decides (no command) |
| All blocking questions resolved | Recommended | Re-check the spec gate — `/steer:spec validate` |
| Only non-blocking deferrals remain | Complete | `No action is currently required.` |

Pick one `Current recommended action` by precedence; an unanswerable question
stays open rather than being guessed.

## Bundle mode (`bundle`)

`/steer:questions bundle [<feature-id>]` renders the open questions **a Product
Owner can answer** as a **shareable, fillable questionnaire** — a Claude Code
Artifact (a private, hosted page they open in a browser, no repo or Claude Code
needed) with a **Markdown fallback**. The PO answers in the page, copies out a
structured Markdown document, and sends it back; `/steer:intake clarify` then
maps each answer to its question **deterministically** and hands it to this
skill's resolve flow to fold in. This is the **outbound** half of the loop
`/steer:intake clarify` completes inbound — steer's way to get answers from a PO
who never touches the repo.

**By default it bundles the whole spine — every feature at once.** Run it with no
argument and you get one questionnaire covering all features plus product-level
questions; you never run it per feature. `bundle <feature-id>` narrows to a single
feature only when you want that.

### Read-only — a hard invariant (not tool-enforced here, so honor it in prose)

Unlike `/steer:explain` (which is frontmatter read-only), this mode lives in a
skill whose default path *writes and deletes* spec files, so its tools can't be
locked down. The read-only guarantee is therefore **behavioral, and you must
uphold it**:

- Bundle **writes nothing under the repo tree** — no `SPEC-QUESTIONS.md`
  heal/delete (step 1), no `created:` stamping (step 3), no `git add`/commit, no
  edit to any `intent.md`/`vision.md`/spec file.
- Its **one** write is the Artifact's HTML source, to a **system temp directory**,
  **never** a path under the working tree (`/spec`, `/apps`, `/packages`, or any
  tracked file) — the same invariant `/steer:explain` uses.
- It runs **no shell** and touches the tracker not at all. Gathering uses the
  read-only `Glob` / `Read` / `Grep` tools only.

### Flow

1. **Locate the spine.** No `/spec` → redirect to `/steer:setup` (or
   `/steer:init` / `/steer:adopt`) and **stop** — there are no questions to bundle
   yet. No argument = the **whole spine, every feature**. A `<feature-id>` narrows
   to that feature; an unknown or ambiguous id → list the features under
   `spec/features/*/` and ask which, never guess.

2. **Gather.** Collect the **same open questions the default flow's
   [step-2 sweep](#steps) identifies** — the `## Open questions` items across
   `spec/vision.md`, `spec/features/*/intent.md`, and `spec/PRODUCTIONIZATION.md`
   (step 2 is the single source for *where* open questions live) — using the
   read-only `Grep`/`Read` tools. (Step 2 *prints* a `grep | grep` shell pipeline
   as an illustration; bundle reproduces the same result read-only, it does not
   run that shell.) Read each item's **structured fields** — `status`, `impact`,
   `owner` — not just the `- [ ]` line.
   - **Detect a legacy `spec/SPEC-QUESTIONS.md`** (a pre-1.25.0 fork may still
     carry it) with `Glob`. Because bundle must **not** run step 1's
     migrate-and-delete heal, do **not** silently omit it: `Read` its `## Open`
     items and **include** them in the gather (read-only — never migrate or
     delete), and add a one-line notice that the file should be healed by running
     the default `/steer:questions` first. Its questions have no feature home, so
     scope them `[product]` like `vision.md`'s.

3. **Filter to what the PO can answer.** A bundle is for a **Product Owner**, so
   it carries the questions a PO can decide — not pure dev/technical work:
   - **Audience — include the human-decision questions the PO owns or co-owns.**
     The `owner:` enum is `product | development | design | security | shared`
     (see the `vision.md` template). Include **`product`** and **`shared`**
     (shared = product *and* development, so the PO owns a half), plus **`design`**
     and **`security`** questions that are product / policy / scope / UX calls a PO
     weighs in on. **Exclude** *code-fact* questions (answerable only by reading
     the code — the [step-4 triage](#steps); asking a PO what their own code does
     is a wasted turn) and questions owned solely by **`development`**
     (data-model / integration / library / architecture calls). Report the
     excluded count, split code-fact vs dev, so nothing looks silently dropped and
     a `shared`/`design`/`security` question is never miscounted as "dev-only".
   - **Status — solicit only `open` / `investigating`.** **Exclude `deferred`**: a
     deferral is a deliberate parking (step 7), and re-soliciting it re-opens a
     closed decision. Show deferred items read-only "for context" at most; never
     as a fillable field.
   - **Blocking first.** Order `impact: blocking` questions first and flag them;
     surface any the SessionStart hook escalated as **stale** (blocking, open
     >14 days) — those are exactly what you want pushed to the PO.
   - **Nothing to ask** (no PO-answerable open questions) → say so, name the
     excluded / deferred counts, and **stop**. Don't render an empty form.

4. **Render — Artifact when available.** Render by the **shared Artifact
   discipline** — rule `88-artifacts`, mechanics in `/steer:reference artifacts`,
   the same standard `/steer:explain` uses; do not restate them here. The temp path
   is `<tempdir>/steer-questions-bundle[-<feature-id>].html`. This is a
   **fillable** page, so it upholds the reference's **copy-out floor** — the one
   capability beyond `explain`'s read-only pages:
   - One labelled **`<textarea>` per question**, grouped **product-level first,
     then per feature**, blocking questions visibly flagged. Each carries its
     **feature-scoped key `[<feature-id>] Q-NNN`** (see the [return
     contract](#return-contract)) and the question's context, verbatim from the spec.
   - **A permission-free copy floor (required — this is the primary export
     path).** The page **always** renders the complete [return
     contract](#return-contract) into a **read-only `<textarea>`/`<pre>` the PO can
     select-all and copy** by hand. This needs neither the Clipboard API nor a
     download — both require iframe-sandbox grants (`clipboard-write`,
     `allow-downloads`) the Artifact frame may not have, so a "Copy" button or a
     `data:`-URI "Download .md" would silently do nothing. Inline JS mirrors each
     `<textarea>`'s value into this copy-box on input, so it always reflects the
     PO's current answers.
   - **A "Copy to clipboard" button and a "Download .md" link are progressive
     enhancement** layered *over* the copy-box — offer them, but the page must be
     fully usable (fill → copy → send) with neither working.
   - The page must make complete sense with everything visible (a screenshot or
     print loses nothing), and every control is keyboard-reachable and labelled.

5. **Markdown fallback.** Where the Artifact tool is unavailable
   (Bedrock/Vertex/Foundry, a zero-data-retention org, or no claude.ai login),
   print the **same fillable [return-contract](#return-contract) Markdown inline**
   in the session so the user can copy it and send it on. Say plainly the hosted
   artifact isn't available and why, so the fallback isn't mistaken for a failure.
   **Do not write it to a file** under the repo — a rendered copy in the tree is
   exactly the drift this stays clear of (same rule as `explain`).

### Return contract

The copy-box, the "Download .md" export, and the Markdown fallback all emit the
**same** document — each answer under a heading carrying its **feature-scoped
key**, `[<feature-id>] Q-NNN`:

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

The **machine key is the `[<feature-id>] Q-NNN` pair**, both visible in the
heading. This matters because **`Q-NNN` ids restart per feature** — they are
unique only *within* a feature, so a whole-spine bundle can contain two different
`Q-017`s; the bracketed **feature id disambiguates them and makes the key
spine-unique**. Product-level questions (from `vision.md`, `PRODUCTIONIZATION.md`,
or a legacy `SPEC-QUESTIONS.md`) have no feature home — scope them **`[product]`**.
Both parts are plain heading text, so the key survives any document round-trip (a
PO pasting the Markdown into Word and sending back a `.docx`), unlike an HTML
comment. The `<!-- steer:q feature= id= source= -->` comment restates the key
plus the source path as machine-readable provenance (a best-effort aid, not the
authority — the visible heading is). Nothing volatile is embedded (no git SHA),
so two downloads of the same answers stay byte-identical for intake's hash guard.

### Recommended next action

Close with a `## Recommended next actions` block: the one best step is to **send
the questionnaire to the PO**, and — when they return the filled document — to
**absorb it with `/steer:intake clarify <filled-doc>`**, which maps each answer
back to its `Q-NNN` and routes it here to fold in. Bundle itself changes nothing
in the spec.

## Coupling rules

The spec ↔ code coupling rules — drift resolution (Rule 5), behavior vs.
incidental implementation, PO acceptance — are canonical in
`${CLAUDE_PLUGIN_ROOT}/templates/reference/SPEC-FRAMEWORK.md`. This skill
*drives questions to answers*; that reference governs how an answer is folded
into the spec.

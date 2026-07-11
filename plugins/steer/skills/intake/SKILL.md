---
name: intake
description: "Absorb a PO-supplied spec/roadmap document (docx/pptx/xlsx/pdf) into the /spec spine — version-stamp and commit the binary plus a normalized Markdown extraction under spec/sources/ — relocating the dropped file into that canonical home so it does not linger where it was uploaded — git-diff it against the prior version, and surface a structured what-changed report. Then route the real changes into intent/contract/vision/roadmap and the tracker via the relevant skills, never clobbering human-authored prose (conflicts become Open questions). Idempotent on an unchanged document. In clarify mode, absorbs a client clarification document instead: it segments the extraction, maps each unit against open questions and the feature list, and sorts them into a three-bucket worklist — answers routed to /steer:questions, new scope to the reconcile rows, unmatched surfaced for the human."
when_to_use: >-
  Use when a Product Owner hands over a new or updated office document (a spec, a
  roadmap, a requirements deck, a spreadsheet) and the team needs to detect what
  changed versus the last version and propagate the real changes into /spec and
  the tracker without losing human-authored content. Reach for it whenever a
  re-sent document arrives with no pointer to what was edited. Use clarify mode
  when a client hands over a clarification document that answers open questions
  and/or introduces new scope, and the team needs each point mapped to the spine
  without hand-supplying question IDs.
argument-hint: "[<path-to-doc> | clarify <path-to-doc> | <source-id> | status]"
allowed-tools:
  - Bash(git status *)
  - Bash(git switch *)
  - Bash(git checkout -b *)
  - Bash(git diff *)
  - Bash(git log *)
  - Bash(git show *)
  - Bash(git rev-parse *)
  - Bash(git add *)
  - Bash(git mv *)
  - Bash(git commit *)
  - Bash(git push)
  - Bash(git push -u origin *)
  - Bash(git push origin *)
  - Bash(gh pr create *)
  - Bash(mise run convert:doc *)
  - Bash(shasum *)
  - Bash(sha256sum *)
---

<!-- steer:modes default,status,clarify -->

# Absorb a PO source document into the spine

A PO repeatedly hands over office documents (docx / pptx / xlsx, sometimes PDF)
carrying specs and roadmaps, and each new version arrives with **no pointer to
what changed**. This skill turns each opaque re-send into a reviewed delta: it
commits the document **and** a normalized Markdown extraction under
`spec/sources/<source-id>/`, `git diff`s successive extractions to surface what
the PO actually changed, then routes the real changes into the spine and tracker
through the skills that already own those artifacts.

It **owns the diff and the routing decision; it owns no domain-write logic** — it
delegates every spec/tracker write to the gateway that already governs it, so the
non-clobbering, human-gated guarantees are inherited, not re-implemented.

## What this skill does NOT do

- It does **not** edit feature prose directly. New behaviour is instantiated via
  `/steer:spec-scaffold`, and both new and changed behaviour is folded into the
  owning `intent.md` through `/steer:spec` (additive edit — never overwrite human
  prose; a conflict becomes an Open question).
- It does **not** resolve drift. A change that contradicts the spine is surfaced
  as a `/steer:audit`-style finding for a human, per rule `55-drift-gates`.
- It does **not** invent content. Anything not present in the extraction becomes
  an Open question, never a guessed requirement.
- It does **not** fabricate dates. Roadmap dates come from the human via
  `/steer:roadmap`.

## First, every run

1. **Require a `/spec` spine.** If `spec/` does not exist, stop and route the user
   to `/steer:setup` (it detects repo state and bootstraps). Intake operates on a
   spine; it does not create one.
2. **Detect the converter and report which path you take** (silence is not
   success — name the path so a reader knows how the extraction was produced):
   - **markitdown MCP** — shipped with this plugin (`plugins/steer/.mcp.json`,
     `uvx markitdown-mcp`). Preferred for docx / pptx / xlsx.
   - **`mise run convert:doc <file>`** — the scaffold-declared CLI task
     (`uvx markitdown` under the pinned `uv`), the deterministic committable path.
   - **native `Read`** — for a text-bearing PDF, Claude can read it directly.
   - **manual floor** — if none is available, commit the binary, tell the user how
     to enable conversion (install `uv`; the `convert:doc` task), and **stop before
     diffing**. Never fabricate an extraction.

## Modes

`default` (a document path, or no argument): run the intake pipeline below on the
supplied document — the normal "the PO just sent a new version" path. With no
argument, list the sources under `spec/sources/` and ask which document to absorb.

`status`: read-only. Print the source ledger — every `spec/sources/<id>/source.md`
with its latest absorbed version, the features/issues it maps to, and any version
whose extraction is still `none` (awaiting a text-bearing copy). No writes.

`clarify` (`clarify <path-to-doc>`): absorb a **client clarification document** —
one that answers open questions and/or introduces new scope. It runs intake's
shared front-end unchanged (step 1 identity, step 2 version/convert/commit, step 6
record) but **replaces the git-diff pipeline (steps 3–4)** with segment → map →
three-bucket routing — see [The clarify pipeline](#the-clarify-pipeline-clarify).
A clarification is its own `source-id`; it is not a version of a prior spec.

## The intake pipeline (`default`)

### 1. Establish source identity

Resolve a stable kebab-case **`source-id`** for the *logical document*, decoupled
from the PO's filename (the PO renames files; identity must not follow the name):

- explicit `--source-id` / the `<source-id>` argument wins;
- else match the incoming document against existing `spec/sources/*/source.md` by
  recorded filename **or** title — surface the candidate and **confirm before
  binding**, never silently reuse (the same discipline `/steer:tracker-sync` uses
  for find-or-create);
- else propose a slug from the document title and confirm it.

### 2. Version, convert, commit

1. Compute the version label `vNNNN-YYYY-MM-DD`: the zero-padded sequence
   `(highest existing version under spec/sources/<id>/versions/) + 1` is the
   ordering key; the date (`date +%F`) is informational, so two documents received
   the same day still order deterministically.
2. **Idempotency guard:** hash the incoming binary and compare it to the binary of
   **every** committed version under `spec/sources/<id>/versions/` (not only the
   latest — a re-dropped *older* version is just as already-absorbed, and must not
   be turned into a spurious new version duplicating old content; this is the same
   any-version match `/steer:tidy` uses). If it matches any of them, the PO re-sent
   an identical file (often under a new name) — report `already absorbed as
   <vNNNN>`, record the new filename in `source.md` if it differs, and **stop**: no
   new version, no diff, no edits, no HISTORY entry. If that re-sent file is sitting at an **in-repo drop
   location** (repo root, `spec/reference/`, anywhere but its committed
   `original.<ext>`) and is byte-identical to the version it matched, it is now a
   redundant duplicate of an already-absorbed source: surface it and route it to
   `/steer:tidy` (which removes an absorbed duplicate on a yes) so it does not stay
   stalled where it was dropped — never delete it silently, and never move it to
   `spec/reference/` (that would duplicate the committed source, not clean it up).
3. Lay down the version directory and convert:
   ```
   spec/sources/<source-id>/
     source.md                          # source-manifest (this plugin's template)
     versions/<vNNNN-YYYY-MM-DD>/
       original.<ext>                   # the committed binary — provenance
       extracted.md                     # normalized Markdown — the diff surface
   ```
   Write `extracted.md` into the version directory **first** (the `Write` tool
   creates the `versions/<vNNNN-YYYY-MM-DD>/` parent), so the directory exists
   before you move the binary into it. **Place `original.<ext>` by relocating the
   dropped file into that directory, not copying it** — so no stray copy is left
   stalled where the PO uploaded it and the canonical `original.<ext>` becomes the
   single home for the source. For a drop file **inside the repo** working tree,
   `git mv` it into place (`git add` it first if it is untracked, then `git mv`);
   this is the same confident, history-preserving move `/steer:tidy` performs. **Only copy** when
   the drop path lies **outside** the repo (e.g. `~/Downloads/…`) — that is the
   PO's own file, not repo clutter: copy it in, leave the external original be, and
   note in the report that it was left in place. Never remove a drop file whose
   bytes do **not** match the committed `original.<ext>`; surface it instead.
   Normalize the extraction **deterministically** so successive versions diff on
   real content, not converter noise: stable heading levels, collapsed runs of
   blank lines, and strip volatile metadata (timestamps, author GUIDs, slide
   coordinates) the converter emits. Convert the **same way every run**.
4. **Capture the diff baseline, do not advance it yet.** Note the version the
   `Latest absorbed version` field in `source.md` names *right now* — that is the
   prior version the diff (step 3) compares against. Leave the field unchanged
   until step 6, so advancing the pointer never destroys the baseline the diff
   needs. (It is a manifest field, not a symlink — portable across checkouts.)
5. `git add` the binary (a `git mv`'d in-repo original is already staged; a copied
   external original still needs `git add`) **and** the extraction together so one
   commit is the durable, diffable record. This extends the design-sources principle (commit a
   Claude-readable extraction alongside the traceability source) to recurring
   versioned documents — see `/steer:reference design-sources`.

### 3. Diff

If this is **not** the first version, diff the new extraction against the prior
version — the one the `Latest absorbed version` field named before this run, which
you captured in step 2.4 (it has **not** been advanced yet):

```sh
git diff --no-index <prev>/extracted.md <new>/extracted.md
```

Parse the hunks into **change units keyed by their nearest enclosing heading
anchor** — a change maps to a topic, not a line number (the same anchor discipline
`template-reconcile.sh` and `/steer:audit` use, so a moved section is not a false
change). Classify each unit **Added / Removed / Modified**.

### 4. The what-changed report

Print (do not write a report file unless asked):

- a header: `source-id`, prior version → new version, and the converter path taken;
- a change table — one row per change unit:

  | Anchor (topic) | Kind | What changed (one line) | Proposed target | Proposed action |
  |---|---|---|---|---|

- a **"no extractable diff"** note if the converter produced empty or garbled text
  (a scanned PDF with no text layer — see Edge cases).

### 5. Reconcile — non-clobbering, human-gated

Route each change unit through the skill that owns the artifact. Intake never
writes feature prose itself:

| Change unit (from the diff) | Routes to | Reused mechanism |
|---|---|---|
| A new feature / capability is described | `/steer:spec-scaffold` then `/steer:spec` | instantiate `intent.md` + `contract.md`; an existing feature is reconciled additively via `template-reconcile.sh`, never clobbered |
| A change to an existing feature's acceptance criteria | `/steer:spec` on the owning `intent.md` | additive edit — copy / append / merge, never overwrite human prose; a conflict becomes an Open question |
| A vision / scope / cross-cutting change | `/steer:spec` on `vision.md` | additive edit; conflicts → Open questions |
| A roadmap / milestone / date change | `/steer:roadmap` | human-confirmed milestones and dates — never fabricated |
| A change that contradicts what the spine/code already says | `/steer:audit` (spec conformance) → `/steer:issues publish-drift` | one issue per real divergence, stable `finding-key`, reconciled across re-runs — never auto-resolved |
| An ambiguous / under-specified change | `/steer:questions` | a `Q-NNN` Open question with `status` / `impact` / `owner` / `required_before` |
| A unit that **answers** an existing open question (clarify mode, bucket 1) | `/steer:questions` (fold-answer path) | folds the answer into the owning `Q-NNN` under `/steer:questions`' step-6 tier gate; records the source-ref + quoted span as provenance. Intake never writes the resolution itself — the resolve direction, symmetric to the raise-direction row above |

The non-clobbering guarantee is **inherited** from these gateways. A genuine
conflict — the document now says X, a human already authored not-X — is never
auto-resolved: it becomes a `Q-NNN` Open question in the owning `intent.md` /
`vision.md`, or, when it is genuine spec-vs-build drift, a `spec-drift` finding for
a human. Surface it; the human resolves it (fix the artifact, fix the code, or
record the accepted divergence).

### 6. Record

For every **absorbed** change (one that produced a spec edit, an Open question, or
a filed issue), append **one** entry to `spec/HISTORY.md` in the template's exact
bold-key format (`spec/HISTORY.md` → `## Format`):

```markdown
## YYYY-MM-DD — <what changed>
- **Why:** absorbed <source-id> <version>
- **Requested by:** <PO handle> via intake
- **Refs:** spec/sources/<id>/versions/<v>/ · spec/features/<id>/ · #issue
- **Areas:** spec-only (or the areas touched)
```

Then update `source.md`: **advance the `Latest absorbed version` field** to
`<vNNNN-YYYY-MM-DD>` (the diff baseline is no longer needed), mark the version
absorbed in the version log, and record the mapped features/issues. The intake run
is the auditable event; the PR review is the evidence.

## The clarify pipeline (`clarify`)

A **client clarification document** is not a version of a prior spec — it is a set
of *answers* to open questions, usually mixed with *new scope*, and it arrives in
whatever shape the client wrote it (prose, a table, an inline email reply, no
tidy `Q1/Q2` numbering). So clarify **reuses intake's shared front-end verbatim**
— step 1 (source identity: the clarification is its own `source-id`), step 2
(version, convert, commit the binary + normalized extraction under
`spec/sources/`, including the step-2.2 binary-hash idempotency guard), and step 6
(record) — but **replaces the git-diff (steps 3–4) with segment → map → route**,
because there is no prior version of *this* document to diff against.

### C1. Segment

**First, the same extraction-validity floor the diff pipeline applies before
diffing applies here before segmenting.** If the converter was unavailable, the
format is non-convertible, or the extraction is empty/garbled (a scanned PDF with
no text layer — `extraction: none`), **stop before segmenting**: commit the binary,
record `extraction: none` in `source.md`, and raise an Open question asking the PO
for a text-bearing copy — exactly as the [Edge cases](#edge-cases) rows do. Never
segment absent or garbled text into spurious "clarification units."

Segment the extraction into discrete **clarification units** *semantically*, not
structurally — do not rely on numbering or headings the client may not have used.
Each unit carries its **exact quoted source span** from `extracted.md`. When a
paragraph fuses several answers, or an answer is split across a table cell, err
toward a **larger** unit **flagged for the human to split** — never confidently
over-split. Drop preamble, pleasantries, and anything that answers nothing; do
**not** force-map a non-answer.

**Exception — a recognized `/steer:questions bundle` return is already
structured, so segment structurally.** When the extraction is a questionnaire this
org emitted (`## [<feature-id>] Q-NNN — …` headings, typically under a
`<!-- steer:clarification-bundle -->` marker or a `# steer clarification
questionnaire` title), it is *not* an arbitrary client document: each such heading
is a deliberate unit boundary. Segment **one unit per heading** — carrying the
heading's **feature-scoped key `[<feature-id>] Q-NNN`** (both parts; `[product]`
scopes a question with no feature home) and its `**Answer:**` body as the quoted
span — rather than re-fusing them semantically. Treat an `**Answer:**` block left
at its `_(type …)_` placeholder — or otherwise empty — as unanswered: drop it,
don't map it. Free-text the PO added outside the question headings is segmented
semantically as usual.

### C2. Map — inline, against the spine

Map each unit against two grounding sets, **inline**:

- **(a) every open `Q-NNN` across the spine** — reuse the exact grep
  `/steer:questions` step 2 uses (over `## Open questions` in `spec/vision.md`,
  `spec/features/*/intent.md`, `spec/PRODUCTIONIZATION.md`); do not re-derive it.
- **(b) the feature list** — each `spec/features/*/intent.md` (and `contract.md`)
  summary, so a unit that answers no open question can still name its feature.

**Fast-path — a unit carrying a feature-scoped `[<feature-id>] Q-NNN` maps by that
key, deterministically.** A unit segmented from a `/steer:questions bundle` return
heading carries the pair `[<feature-id>] Q-NNN` (see [C1](#c1-segment)). Match the
**pair**, not the bare `Q-NNN`: locate the open question `Q-NNN` **in that
feature** (`[product]` → `vision.md` / `PRODUCTIONIZATION.md` / a legacy
`SPEC-QUESTIONS.md`). Matching on the pair is essential — `Q-NNN` ids restart per
feature, so a bare `Q-017` is ambiguous across a whole-spine bundle. On a pair
match, map **directly** — an exact key match, not a semantic guess, so it is
high-confidence and bypasses the fuzzy matching below. A pair that matches **no**
currently-open question — answered, renumbered, or a mistyped feature since the
bundle was generated — is **not** force-applied: surface it in bucket 3 for the
human. Only units *without* such a key (free-text new scope) fall through to the
semantic map below.

For each remaining (unanchored) unit propose: the best-match `Q-NNN` (or
**"none — new info"**), the best-match feature, a **confidence**, and the
**matched evidence** (the quoted span and the words that tie it to that
question/feature).

> **Cost guardrail.** Mapping is where clarify gets expensive. Apply
> `/steer:questions` step 4's cost guardrail **verbatim** — it is the single
> source for this policy, do not restate it here: one cheap inline pass, **no**
> per-unit or per-feature agent fan-out, **at most one** bounded subagent for the
> entire batch, and leave a unit in bucket 3 rather than paying to place it. If
> that policy tightens, it tightens in one place.

### C3. Three-bucket worklist — human-confirmed in one pass

Print the mapping as a worklist the human confirms in a **single pass** — they
correct the wrong rows; they never dictate question IDs. Sort every unit into one
of three buckets:

| Bucket | Unit | Routes to |
|---|---|---|
| **1 — answers an open question** | confident match to an open `Q-NNN` | routed via intake's own [step-5 reconcile row](#5-reconcile--non-clobbering-human-gated) for answers, which hands the fold to `/steer:questions` (its step 6). Still tier-gated there: a genuine product decision stays human-gated; a decides-nothing-new answer auto-applies with the PR as the gate |
| **2 — new info** | maps to a feature, answers no open question | the **existing step-5 reconcile rows** (`/steer:spec` / `/steer:spec-scaffold` / `/steer:roadmap` / `/steer:audit`) — new scope is routed exactly as a spec-doc change is |
| **3 — unmatched / low-confidence** | can't be placed confidently | **surfaced for the human** — "where does this go?" — **never guessed**; may become a new `Q-NNN` |

**Routing is durable — the worklist is only its in-session presentation.** As
intake works each bucket it writes a durable output, so nothing lives only in the
transient worklist:
- **Bucket 1** — intake annotates the matched `Q-NNN` with the **proposed answer**,
  its **source-ref** (`spec/sources/<id>/versions/<v>/`) and **exact quoted span**,
  marked **`pending /steer:questions fold`**. This is the *same durable Open-questions
  write* intake already makes when it *raises* a `Q-NNN` in default mode — it is
  **not** a resolution: intake does not strike the question, fold the answer into
  `intent.md` / `vision.md`, or decide anything. The annotation is written
  **update-in-place per `Q-NNN`** (find-the-existing-pending-line-and-replace, not
  append): if that question already carries a `pending /steer:questions fold` from
  an earlier absorb, overwrite it with the newer answer/source-ref rather than
  stacking a second one. So re-absorbing the same bundle — e.g. when a browser
  re-download changed the bytes enough to slip past the step-2.2 hash guard —
  reconciles to one pending answer, never duplicates.
- **Bucket 2** — routed through the existing step-5 gateways (which write durably).
- **Bucket 3** — raised as a new `Q-NNN`, or left for the human to place; never guessed.

**Record ownership is split, and the halves never cross.** Intake owns
**ingestion + routing**: the `spec/sources/` commit, the pending proposed-answer
annotations / raised `Q-NNN`s, the step-5 gateway routing, and — at step 6 — the
`spec/HISTORY.md` row and advancing `source.md`'s `Latest absorbed version`.
**"Absorbed" means the doc was ingested and every unit durably routed — not that
every answer has been folded.** `/steer:questions` owns the **fold**: it applies
its step-6 tier gate to the pending answer, writes it into the owning `intent.md` /
`vision.md`, and strikes the question. Questions never touches the source pointer;
intake never folds. Advancing the pointer at step 6 is therefore correct and
strands nothing — the pending answers are already durable on the `Q-NNN`s.

**Re-running is a plain no-op, not the recovery path.** Because routing outputs are
durable, re-running `clarify` on the same binary hits the step-2.2 hash guard and
reports `already absorbed` — the doc is already ingested and routed. An interrupted
run loses nothing already written; you finish any un-folded answers with
**`/steer:questions`**, whose sweep now finds the `pending /steer:questions fold`
annotations on the `Q-NNN`s. Do **not** re-run `clarify` to resume — it cannot,
and does not need to.

**Honesty limit.** Perfect auto-mapping on an arbitrary messy document is not
achievable, and clarify does not pretend otherwise. Its value is collapsing the
common case to a glance-and-confirm and containing the ambiguous case to explicit
human placement, with a hard floor of **no silent wrong write**: an unconfident
unit lands in bucket 3, never force-bound to the nearest question.

## Idempotency / re-run behaviour

- **Same version → no-op** via the binary-hash guard (step 2.2). Hashing the
  binary, not the extraction, catches an identical file re-sent under a new name.
- **A new version diffs only against the current latest**, so the report is
  strictly the delta since the last absorbed version — never a re-derivation.
- **Stable identity is the `source-id`**, not the filename; `source.md` keeps the
  filename history so a rename still maps to the same source.
- **Downstream re-runs reconcile, never duplicate**, because the gateways key on
  stable identities (`/steer:tracker-sync` find-or-create on feature-id;
  `/steer:audit` / `/steer:issues publish-drift` finding-key; spec-scaffold's
  anchor-matched additive splice). Re-running intake after a human partially
  resolved a prior batch updates or closes — it does not re-file.

## Edge cases

| Case | Handling |
|---|---|
| First-ever version (no baseline) | No diff. Report "initial import"; treat the whole extraction as new content and route via `/steer:spec` / `/steer:spec-scaffold` (PO-gated). HISTORY: "initial absorb of `<source-id> v0001`." |
| Converter unavailable | Commit the binary, state which path was missing and how to enable it, and stop before diffing — never fabricate an extraction. |
| Non-convertible / unknown format | Commit the binary, record `extraction: none` in `source.md`, raise an Open question for manual review. No diff, no auto-edits. |
| Scanned PDF, no text layer | Detect low text yield; commit the binary, record `extraction: none (scanned — no text layer)`, raise an Open question asking the PO for a text-bearing version. No diff. |
| PO renamed the document | Identity is the `source-id`; fuzzy-match the title/content, confirm, and append the new filename to `source.md`. Never silently bind a rename to the wrong source. |
| Multiple documents map to overlapping features | `source.md` carries a many-to-many map. When two sources touch the same `intent.md`, route both through the append/merge import; **conflicting claims between two sources become one `Q-NNN` Open question naming both** — never auto-pick a precedence. |

## Recommended next actions

Close with a `## Recommended next actions` block scoped to the run, naming the one
best step and delegating to its owner (see
`${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md`):

| Observed state | Category | Action / suggested command |
|---|---|---|
| Converter unavailable; binary committed | Blocking now | Enable conversion (install `uv`; `mise run convert:doc`), then re-run `/steer:intake <doc>` |
| Conflicting claims surfaced as Open questions | Human decision required | PO resolves the `Q-NNN`s (no command) |
| New feature described in the document | Recommended | Spec it — `/steer:spec` |
| Change contradicts the build (drift) | Required before next production release | File it — `/steer:issues publish-drift` |
| Roadmap/milestone change absorbed | Recommended | Reconcile the timeline — `/steer:roadmap` |
| Clarification units matched open questions (bucket 1) | Recommended | Fold the answers — `/steer:questions` |
| Clarification units unmatched (bucket 3) | Human decision required | The human places them (may become new `Q-NNN`s) — no command |
| Delta absorbed, nothing open | Complete | `No action is currently required.` |

Pick one `Current recommended action`. Committing the source + extraction —
and, when the work is complete, pushing and opening the PR — is autonomous
(rule `45-commit-autonomy`); the dev's merge review is the gate, and this
skill never merges.

## Coupling rules

Source-document provenance (traceability link + committed Claude-readable
extraction) follows the design-sources model — `/steer:reference design-sources`.
Spec-vs-intended conformance verdicts and `finding-key` reconciliation are
`/steer:audit`'s; the spec framework (behaviour vs. implementation, PO acceptance,
drift resolution) is in `SPEC-FRAMEWORK.md`; the append-only change log format is
`spec/HISTORY.md`. Intake delegates to these — it does not duplicate them.

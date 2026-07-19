---
name: intake
description: "Absorb a PO office document (docx/pptx/xlsx/pdf) into the /spec spine — commit the binary plus a normalized Markdown extraction under spec/sources/, diff it against the prior version, report what changed, and route the real changes into the spine and tracker without clobbering human-authored prose. clarify mode maps a client clarification document to open questions and new scope."
when_to_use: >-
  Use when a Product Owner hands over a new or re-sent spec, roadmap,
  requirements deck, or spreadsheet and the team needs what changed propagated
  into /spec and the tracker; use clarify mode when a client document answers
  open questions or adds scope.
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
`spec/sources/<source-id>/`, `git diff`s successive extractions, then routes
the real changes into the spine and tracker through the skills that own them.

It **owns the diff and the routing decision — no domain-write logic**: every
spec/tracker write is delegated to the gateway that already governs it, so the
non-clobbering, human-gated guarantees are inherited, not re-implemented.

## What this skill does NOT do

- It does **not** edit feature prose directly. New behaviour is instantiated
  via `/steer:spec-scaffold` and folded into the owning `intent.md` through
  `/steer:spec` (additive — never overwrite human prose; a conflict becomes an
  Open question).
- It does **not** resolve drift. A change that contradicts the spine is surfaced
  as a `/steer:audit`-style finding for a human, per rule `55-drift-gates`.
- It does **not** invent content (anything absent from the extraction becomes
  an Open question, never a guessed requirement) and does **not** fabricate
  dates — roadmap dates come from the human via `/steer:roadmap`.

## First, every run

1. **Require a `/spec` spine.** If `spec/` does not exist, stop and route the
   user to `/steer:setup`. Intake operates on a spine; it does not create one.
2. **Detect the converter and report which path you take** — silence is not
   success; name how the extraction was produced:
   - **markitdown MCP** — shipped with this plugin (`plugins/steer/.mcp.json`,
     `uvx markitdown-mcp`). Preferred for docx / pptx / xlsx.
   - **`mise run convert:doc <file>`** — the scaffold-declared CLI task
     (`uvx markitdown` under the pinned `uv`), the deterministic committable path.
   - **native `Read`** — for a text-bearing PDF, Claude can read it directly.
   - **manual floor** — none available: commit the binary, tell the user how to
     enable conversion (install `uv`; the `convert:doc` task), and **stop
     before diffing** — never fabricate an extraction.

## Modes

`default` (a document path, or no argument): run the intake pipeline below on the
supplied document — the normal "the PO just sent a new version" path. With no
argument, list the sources under `spec/sources/` and ask which document to absorb.

`status`: read-only. Print the source ledger — every `spec/sources/<id>/source.md`
with its latest absorbed version, the features/issues it maps to, and any version
whose extraction is still `none` (awaiting a text-bearing copy). No writes.

`clarify` (`clarify <path-to-doc>`): absorb a **client clarification document**
— one that answers open questions and/or introduces new scope — see
[The clarify pipeline](#the-clarify-pipeline-clarify).

## The intake pipeline (`default`)

### 1. Establish source identity

Resolve a stable kebab-case **`source-id`** for the *logical document*, decoupled
from the PO's filename (the PO renames files; identity must not follow the name):

- explicit `--source-id` / the `<source-id>` argument wins;
- else match against existing `spec/sources/*/source.md` by recorded filename
  **or** title — surface the candidate and **confirm before binding**, never
  silently reuse (`/steer:tracker-sync`'s find-or-create discipline);
- else propose a slug from the document title and confirm it.

### 2. Version, convert, commit

1. Compute the version label `vNNNN-YYYY-MM-DD`: the zero-padded sequence
   `(highest existing version) + 1` is the ordering key; the date (`date +%F`)
   is informational, so two same-day documents still order deterministically.
2. **Idempotency guard:** hash the incoming binary and compare it to the binary
   of **every** committed version under `spec/sources/<id>/versions/` (not only
   the latest — a re-dropped *older* version is just as already-absorbed and
   must not become a spurious new version; the same any-version match
   `/steer:tidy` uses). On a match the PO re-sent an identical file (often
   under a new name) — report `already absorbed as <vNNNN>`, record the new
   filename in `source.md` if it differs, and **stop**: no new version, no
   diff, no edits, no HISTORY entry. If that re-sent file sits at an **in-repo
   drop location** (anywhere but its committed `original.<ext>`), it is a
   redundant duplicate of an already-absorbed source: surface it and route it
   to `/steer:tidy` (which removes it on a yes) — never delete it silently,
   never move it to `spec/reference/` (a duplicate, not a cleanup).
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
   before you move the binary into it. **Place `original.<ext>` by relocating
   the dropped file, not copying it** — no stray copy stays stalled where the
   PO uploaded it; the canonical `original.<ext>` is the source's single home.
   For a drop file **inside the repo**, `git mv` it into place (`git add` it
   first if untracked) — the same history-preserving move `/steer:tidy`
   performs. **Only copy** when the drop path lies **outside** the repo (e.g.
   `~/Downloads/…`) — the PO's own file, not repo clutter: copy it in, leave
   the original be, and note that it was left in place. Never remove a drop
   file whose bytes do **not** match the committed `original.<ext>`; surface
   it instead. Normalize the extraction **deterministically** so successive
   versions diff on real content, not converter noise: stable heading levels,
   collapsed blank-line runs, volatile converter metadata (timestamps, author
   GUIDs, slide coordinates) stripped. Convert the **same way every run**.
4. **Capture the diff baseline, do not advance it yet.** Note the version the
   `Latest absorbed version` field in `source.md` names *right now* — the prior
   version the diff (step 3) compares against. Leave the field unchanged until
   step 6, so advancing the pointer never destroys the baseline the diff needs.
5. `git add` the binary (a `git mv`'d in-repo original is already staged; a
   copied external original still needs it) **and** the extraction together so
   one commit is the durable, diffable record — the design-sources principle
   (a Claude-readable extraction committed alongside the traceability source)
   extended to recurring versioned documents (`/steer:reference design-sources`).

### 3. Diff

If this is **not** the first version, diff the new extraction against the prior
version — the baseline captured in step 2.4 (it has **not** been advanced yet):

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

- a **"no extractable diff"** note for empty/garbled converter output (see Edge cases).

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
`vision.md`, or, for genuine spec-vs-build drift, a `spec-drift` finding.
Surface it; the human resolves it (fix the artifact, fix the code, or record
the accepted divergence).

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

Then update `source.md`: **advance the `Latest absorbed version` field** (the
diff baseline is no longer needed), mark the version absorbed, and record the
mapped features/issues. The intake run is the auditable event; the PR review
is the evidence.

## The clarify pipeline (`clarify`)

A **client clarification document** is a set of *answers* to open questions,
usually mixed with *new scope*, in whatever shape the client wrote it — not a
version of a prior spec, so there is nothing to git-diff against. The whole
shared contract with `/steer:questions bundle` — the loop, the machine-keyed
`[<feature-id>] Q-NNN` key and its stale/unknown-key handling, the segmentation
rule, and the three-bucket worklist with each bucket's durability rules and
the intake-routes / questions-folds ownership split — is canonical in
[`CLARIFICATION-LOOP.md`](../../templates/reference/CLARIFICATION-LOOP.md);
this section is only what intake itself does. Clarify reuses intake's shared
front-end **verbatim** — step 1 (a clarification is its own `source-id`),
step 2 (version, convert, commit, with the step-2.2 binary-hash guard), and
step 6 (record) — replacing the git-diff (steps 3–4) with:

1. **Segment** the extraction into clarification units per the reference's
   segmentation rule — semantic by default; structural (one unit per
   `## [<feature-id>] Q-NNN` heading) for a recognized bundle return. An
   empty/garbled/absent extraction stops here — handle it exactly as the
   [Edge cases](#edge-cases) rows direct.
2. **Map** each unit inline against **(a)** every open `Q-NNN` across the
   spine — reuse the exact grep `/steer:questions` step 2 uses; do not
   re-derive it — and **(b)** the feature list (each
   `spec/features/*/intent.md` / `contract.md` summary). A keyed unit maps
   deterministically per the reference's key-matching rules; for each
   unanchored unit propose the best-match `Q-NNN` (or **"none — new info"**),
   feature, **confidence**, and **matched evidence** — under
   `/steer:questions` step 4's **cost guardrail, verbatim** (the single source
   for that policy; leave a unit in bucket 3 rather than paying to place it).
3. **Route** every unit into the reference's three buckets, from a worklist
   the human confirms in a **single pass** — they correct wrong rows, never
   dictate question IDs. Bucket 1 hands the fold to `/steer:questions` via the
   [step-5 answers row](#5-reconcile--non-clobbering-human-gated) — intake
   writes only the durable `pending /steer:questions fold` annotation, never
   the resolution; bucket 2 routes through the other step-5 rows; bucket 3 is
   surfaced for the human, **never guessed**. The hard floor is **no silent
   wrong write**; re-running clarify on the same binary is a no-op — resume
   un-folded answers with `/steer:questions`, not a re-run.

## Idempotency / re-run behaviour

- **Same version → no-op** via the binary-hash guard (step 2.2). Hashing the
  binary, not the extraction, catches an identical file re-sent under a new name.
- **A new version diffs only against the current latest** (step 3) — strictly the delta, never a re-derivation.
- **Stable identity is the `source-id`**, not the filename; `source.md` keeps the
  filename history so a rename still maps to the same source.
- **Downstream re-runs reconcile, never duplicate** — the gateways key on
  stable identities (`/steer:tracker-sync` find-or-create on feature-id;
  `/steer:audit` / `/steer:issues publish-drift` finding-key; spec-scaffold's
  anchor-matched splice). A re-run after partial resolution updates or closes,
  never re-files.

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

Close with a `## Recommended next actions` block scoped to the run, naming the
one best step (see `${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md`):

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

Pick one `Current recommended action`. Committing the source + extraction and
pushing/opening the PR is autonomous (rule `45-commit-autonomy`); the dev's
merge review is the gate — this skill never merges.

## Coupling rules

Source-document provenance (traceability link + committed Claude-readable
extraction) follows the design-sources model — `/steer:reference design-sources`.
Conformance verdicts and `finding-key` reconciliation are `/steer:audit`'s; the
spec framework is `SPEC-FRAMEWORK.md`; the append-only change-log format is
`spec/HISTORY.md`; the PO clarification-loop contract is
`CLARIFICATION-LOOP.md`. Intake delegates to these — it does not duplicate them.

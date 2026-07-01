---
name: intake
description: "Absorb a PO-supplied spec/roadmap document (docx/pptx/xlsx/pdf) into the /spec spine. Version-stamps and commits the binary plus a normalized Markdown extraction under spec/sources/<source-id>/, git-diffs the new version against the prior extraction, and surfaces a structured what-changed report. Then routes the real changes into intent/contract/vision/roadmap and the tracker by delegating to /steer:spec-scaffold, /steer:tracker-sync, /steer:audit and /steer:questions — never clobbering human-authored prose: conflicts become Open questions, every absorbed change appends a HISTORY.md entry, drift is surfaced for a human and never resolved silently. Idempotent: re-running on an unchanged document is a no-op."
when_to_use: >-
  Use when a Product Owner hands over a new or updated office document (a spec, a
  roadmap, a requirements deck, a spreadsheet) and the team needs to detect what
  changed versus the last version and propagate the real changes into /spec and
  the tracker without losing human-authored content. Reach for it whenever a
  re-sent document arrives with no pointer to what was edited.
argument-hint: "[<path-to-doc> | <source-id> | status]"
---

<!-- steer:modes default,status -->

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
   the current latest version. If they match, the PO re-sent an identical file
   (often under a new name) — report `already absorbed as <vNNNN>`, record the new
   filename in `source.md` if it differs, and **stop**: no new version, no diff, no
   edits, no HISTORY entry.
3. Lay down the version directory and convert:
   ```
   spec/sources/<source-id>/
     source.md                          # source-manifest (this plugin's template)
     versions/<vNNNN-YYYY-MM-DD>/
       original.<ext>                   # the committed binary — provenance
       extracted.md                     # normalized Markdown — the diff surface
   ```
   Normalize the extraction **deterministically** so successive versions diff on
   real content, not converter noise: stable heading levels, collapsed runs of
   blank lines, and strip volatile metadata (timestamps, author GUIDs, slide
   coordinates) the converter emits. Convert the **same way every run**.
4. **Capture the diff baseline, do not advance it yet.** Note the version the
   `Latest absorbed version` field in `source.md` names *right now* — that is the
   prior version the diff (step 3) compares against. Leave the field unchanged
   until step 6, so advancing the pointer never destroys the baseline the diff
   needs. (It is a manifest field, not a symlink — portable across checkouts.)
5. `git add` the binary **and** the extraction together so one commit is the
   durable, diffable record. This extends the design-sources principle (commit a
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
| Delta absorbed, nothing open | Complete | `No action is currently required.` |

Pick one `Current recommended action`. This skill does not perform unapproved
pushes or PRs — committing the source + extraction is autonomous (rule
`45-commit-autonomy`); publishing waits for the dev.

## Coupling rules

Source-document provenance (traceability link + committed Claude-readable
extraction) follows the design-sources model — `/steer:reference design-sources`.
Spec-vs-intended conformance verdicts and `finding-key` reconciliation are
`/steer:audit`'s; the spec framework (behaviour vs. implementation, PO acceptance,
drift resolution) is in `SPEC-FRAMEWORK.md`; the append-only change log format is
`spec/HISTORY.md`. Intake delegates to these — it does not duplicate them.

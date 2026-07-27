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
   - **`mise run convert:doc <file>`** — the scaffold-declared CLI task
     (`uvx markitdown` under the pinned `uv`), the deterministic committable
     path and the **preferred converter** for docx / pptx / xlsx. It is a
     one-shot task, not a long-lived server: nothing runs until you convert a
     document.
   - **native `Read`** — for a text-bearing PDF, Claude can read it directly.
   - **manual floor** — neither available: commit the binary, tell the user how
     to enable conversion (install `uv`; the `convert:doc` task), and **stop
     before diffing** — never fabricate an extraction.

   > There is **no markitdown MCP server**. It was removed from the plugin's
   > `.mcp.json` because it spawned a `uvx markitdown-mcp` subprocess in *every*
   > session — including the overwhelming majority that never convert a
   > document — to serve this one skill. `convert:doc` runs the same
   > `markitdown` tool on demand. If a repo predates the removal and still lists
   > a `markitdown` server in its own `.mcp.json` or `.vscode/mcp.json`, that
   > entry is stale but harmless; `/steer:sync` clears it.

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

## Pipelines — read the one for your mode

Both pipelines are procedures of their own; read the file when you reach this
point, not before.

- **`default`** — absorb a new or re-sent PO source document: commit the binary,
  normalize it to Markdown under `spec/sources/`, diff against the prior
  version, and route the real changes into the spine and tracker.
- **`clarify`** — map a client clarification document onto open questions and
  new scope.

→ [`PIPELINES.md`](${CLAUDE_PLUGIN_ROOT}/skills/intake/PIPELINES.md)

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

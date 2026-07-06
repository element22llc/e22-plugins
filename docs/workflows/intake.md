# `/steer:intake`

Absorb a Product Owner's spec or roadmap **document** — and every later version of
it — into the `/spec` spine, surfacing exactly what changed each time.

!!! info "When to use"
    Use when a PO hands over a new or updated office document (a spec in Word, a
    roadmap deck, a requirements spreadsheet, a PDF) and you need to detect what
    changed versus the last version and fold the real changes into `/spec` and the
    tracker — without losing human-authored content. Reach for it whenever a
    re-sent document arrives with no pointer to what was edited.

**Argument hint:** `[<path-to-doc> | clarify <path-to-doc> | <source-id> | status]`

## The problem it solves

Office documents are opaque binaries: `git` can't diff them and Claude can't read
them directly, so a re-sent file is a blob with no indication of what moved.
`/steer:intake` commits, for every version, **both** the original binary **and** a
normalized Markdown extraction — so a plain `git diff` of successive extractions
*is* the "what changed" the PO never spells out.

## What it does

1. **Identity** — resolves a stable kebab-case `source-id` for the logical
   document, decoupled from the filename (a renamed re-send still maps to the same
   source).
2. **Version, convert, commit** — lays down
   `spec/sources/<source-id>/versions/<vNNNN-DATE>/` holding `original.<ext>`
   (provenance) and `extracted.md` (the diff surface), and commits both together.
   Conversion uses the **markitdown** MCP server shipped with the plugin, or the
   `mise run convert:doc` CLI task.
3. **Diff** — `git diff`s the new extraction against the prior version and groups
   the hunks into change units by heading anchor (topic, not line number).
4. **Report** — prints a structured *what-changed* table.
5. **Reconcile** — routes each change through the skill that owns the artifact
   (`/steer:spec-scaffold`, `/steer:tracker-sync`, `/steer:audit`, `/steer:roadmap`,
   `/steer:questions`), **never clobbering human prose**: conflicts become Open
   questions, drift is surfaced for a human, and every absorbed change appends a
   `spec/HISTORY.md` entry.

**Clarify mode** takes a different middle: a *client clarification document* is not
a version of a prior spec, so instead of the diff (steps 3–4) it **segments** the
extraction semantically, **maps** each unit inline against open questions and the
feature list, and sorts them into a three-bucket, human-confirmed worklist —
answers → `/steer:questions`, new scope → the reconcile rows, unmatched → surfaced
for the human (never guessed). The shared front-end (identity, versioned commit,
`HISTORY` record) is unchanged.

## Modes

| Mode | What it does |
| --- | --- |
| `/steer:intake <path-to-doc>` | Absorb the supplied document — the normal "the PO just sent a new version" path. |
| `/steer:intake clarify <path-to-doc>` | Absorb a **client clarification document** that answers open questions and/or adds scope: segment → map to the spine → three-bucket worklist (answers to `/steer:questions`, new scope to the reconcile rows, unmatched surfaced). Every folded answer records the source-ref + quoted span. The document a PO fills in is usually the **outbound** questionnaire `/steer:questions bundle` produces — when it carries `[<feature-id>] Q-NNN` answer headings, `clarify` segments per heading and maps each answer to its question by that feature-scoped key deterministically. |
| `/steer:intake` | List the sources under `spec/sources/` and ask which document to absorb. |
| `/steer:intake status` | Read-only ledger: each source, its latest absorbed version, mapped features/issues, and any version still awaiting a text-bearing copy. |

## Idempotency

Re-running on an unchanged document is a no-op — a binary-hash guard detects an
identical file (even re-sent under a new name). A genuinely new version diffs only
against the current latest, so the report is always the incremental delta.

## Where it fits

`spec/sources/` is the **versioned** home for recurring PO documents, alongside
`spec/design/` (UI exports plus the living architecture diagram) and
`spec/reference/` (one-off prose). A document sent
once can stay loose under `spec/reference/`; the moment it starts arriving in
versions, it belongs under `spec/sources/`. See
[the markitdown server](../reference/mcp-servers.md) for the converter, and
`/steer:reference design-sources` for the shared provenance model.

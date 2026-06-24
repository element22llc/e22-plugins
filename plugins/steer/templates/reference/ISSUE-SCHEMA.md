# Issue schema — the machine-readable issue contract

Every **agent-authored** GitHub issue follows this contract so that updates are
idempotent, reconciliation is deterministic, and another agent (Claude, Codex,
Copilot) — or a plain `gh` script — can read and rewrite the issue without
parsing free prose. The contract is two things: **hidden identity markers** and
**stable section headings**, with agent-owned content fenced inside a **managed
block** so human edits are never clobbered.

This file is the single normative owner of the issue *format*. The lifecycle,
state model, labels, taxonomy, and authority live in
[`ISSUE-WORKFLOW.md`](ISSUE-WORKFLOW.md); the open-question format lives in
[`SPEC-FRAMEWORK.md`](SPEC-FRAMEWORK.md).

## Identity markers

HTML comments at the top of the issue body. They are invisible in rendered
GitHub but are the deterministic handles every skill keys off — **search by
marker before creating, to dedupe**. The marker is **canonical**; any `source:*`
or other label that mirrors a marker is *derived* and searchable, never the
source of truth.

| Marker | Meaning | On |
|---|---|---|
| `<!-- steer:schema=2 -->` | **Schema-version marker** — the contract version this body was written against. Required on every agent issue. | all |
| `<!-- steer:kind=… -->` | Closed enum (work shape): `feature` · `bug` · `task` · `finding` · `spec-question` · `spec-drift` · `audit-run`. | all |
| `<!-- steer:state=… -->` | Lifecycle state (base source of truth): `inbox` · `exploring` · `ready-for-spec` · `ready-for-dev` · `in-progress` · `validate` · `blocked` · `done` · `cancelled`. `done` = closed as completed; `cancelled` = closed for a non-completion reason (see `ISSUE-WORKFLOW.md` Completion rules). A Project **Status** field may *mirror* this (derived, one-directional); the marker stays canonical — see *GitHub Projects v2 — compatibility boundary* below. | all |
| `<!-- steer:source=… -->` | Origin (canonical): `human` · `adoption` · `audit` · `security-review` · `code-review` · `ci` · `dependency` · `implementation` · `spec`. The `source:*` label is derived from this. | all |
| `<!-- steer:feature-id=… -->` | Owning feature slug (kebab-case), when one exists. | feature, task, spec-question, spec-drift |
| `<!-- steer:spec-path=… -->` | Path to the owning spec artifact (e.g. `spec/features/<id>/intent.md`). | feature, task, spec-question, spec-drift |
| `<!-- steer:question-id=Q-NNN -->` | The stable question ID this issue tracks (see `SPEC-FRAMEWORK.md`). | spec-question |
| `<!-- steer:finding-key=… -->` | Stable conceptual identity of a finding — `<dimension-or-source>:<rule>:<file-or-component>:<symbol>`. **Never line-based.** | finding |
| `<!-- steer:evidence=… -->` | Fingerprint of the *currently observed* evidence (e.g. a short hash of the offending lines/region). Changes as the code moves; the `finding-key` does not. | finding |
| `<!-- steer:dedupe-key=… -->` | Generic conceptual identity for issues with no stronger identity (no `finding-key`/`feature-id`/`question-id`). Stable and conceptual — e.g. `export:csv:duplicate-header`. **Never** line numbers, timestamps, or generated wording. | any without a stronger identity |
| `<!-- steer:audit-id=… -->` | One audit run, `<iso-timestamp>-<short-sha>`. Immutable per run. | audit-run, finding (source:audit) |
| `<!-- steer:audit-commit=… -->` | The commit SHA the audit observed. | audit-run, finding (source:audit) |
| `<!-- steer:parent-issue=N -->` | Parent issue, when native sub-issue links are unavailable (fallback). | task, finding |
| `<!-- steer:claimed-by=… -->` | Active execution context that claimed the issue (e.g. `claude-code`). Optional; the *branch* marker represents the active execution context, GitHub *assignment* the accountable human. | optional |
| `<!-- steer:branch=… -->` | The working branch for this issue. Optional — may be discovered dynamically. | optional |
| `<!-- steer:pull-request=N -->` | The delivering PR. Optional — may be discovered dynamically. | optional |

### Marker requirement matrix

"Before first touch" = a human-created issue an agent has not yet processed;
"after first touch" = the same issue once an agent has normalized it (see
*Human-created issues*).

| Marker | Agent-created | Human issue (before first touch) | Human issue (after first touch) |
|---|---|---|---|
| `steer:schema` (version) | Required | Optional | Required |
| `steer:state` | Required | Optional | Required |
| `steer:kind` | Required | Optional | Required |
| `steer:source` | Required | Optional | Required |
| stable identity (`finding-key`/`feature-id`/`question-id`) | Required when applicable | Optional | Required when derivable |
| `steer:dedupe-key` | Required when no stronger identity exists | Optional | Added when derivable |
| `claimed-by` / `branch` / `pull-request` | Optional (may be discovered) | — | Optional (may be discovered) |

## Managed block

Agent-owned sections live between markers; everything outside is human-owned and
**preserved verbatim** on every update:

```md
<!-- steer:managed:start -->
## Outcome
…agent-maintained sections…
<!-- steer:managed:end -->

## Team notes
Human discussion — never touched by an agent.
```

An idempotent update **replaces only the managed block**, leaving the markers,
human sections, and any unknown content intact.

### Update protocol (concurrency-safe)

Another human or agent may edit the issue between an agent's read and its write.
The update is therefore a guarded read-modify-write, never a blind overwrite:

1. **Read** the current issue body.
2. **Preserve** that exact body as the merge input (bytes outside the block are
   carried forward verbatim).
3. **Produce** the candidate body (managed block rewritten; everything else kept).
4. **Re-read** the issue immediately before writing.
5. If the body **changed** since step 1, recompute the candidate from the new
   version.
6. If it **changes again** on the second attempt, **stop and report a
   concurrent-edit conflict** — do not write.
7. **Never** overwrite an unseen human or agent change.

### Malformed or duplicate blocks fail closed

If the body has **no** managed block, a malformed block, or **more than one**
`steer:managed:start`/`end` pair: do not guess which block is authoritative, do
not auto-delete either, **leave the body unchanged**, and report the schema
conflict with a *proposed* repaired body for a human to accept. Unknown but
structurally **valid** markers always survive; structurally **invalid** managed
blocks fail closed.

## Stable section headings

Inside the managed block, use these headings exactly (skip ones that don't
apply; never rename them). Per kind:

- **feature / task** — `Outcome` · `User value` · `Scope` · `Out of scope` ·
  `Acceptance criteria` · `Open questions` · `Spec references` · `Related issues` ·
  `Validation`.
- **bug** — `Problem` · `Observed behavior` · `Expected behavior` ·
  `Reproduction` · `Evidence` · `Acceptance criteria` · `Technical findings` ·
  `Spec references` · `Related issues` · `Validation`.
- **finding** — `Finding` · `Evidence` · `Standard missed` · `Impact` ·
  `Suggested remediation` · `Origin`.
- **spec-question** — `Question` · `Why this matters` · `Affected specifications`
  · `Decision needed from` · `Resolution`.
- **audit-run** — `Scope` · `Run metadata` · `Summary` · `Report`.
- **spec-drift** — `Spec says` · `Implementation does` · `Evidence` ·
  `Human decision required`.

The body templates in [`../github/issue-bodies/`](../github/issue-bodies/) are
the canonical starting shapes for the agent-generated kinds.

### `Related issues` — cross-references to other issues

`Related issues` holds connections this issue has to **other issues** that are
not parent/sub-issue links. Each line is `#N — <relationship> (<one-line why>)`,
where `<relationship>` is an `issue_relationship` value (`ENUMS.md`). Because each
line mentions `#N`, GitHub auto-creates the backlink on the other issue — the
relationship word is workflow-owned metadata layered on top of an ordinary
cross-reference, since GitHub has no native typed relationship beyond
parent/sub-issue. Example:

```text
## Related issues

- #42 — conflicts-with (a `better-auth` migration would supersede the Cognito
  hosting decision proposed here; a human must reconcile)
- #18 — depends-on (auth provider must be chosen before hosting is finalized)
```

The section lives **inside the managed block**, so it is rewritten idempotently
like any other managed heading. It is **omitted entirely when there are no related
issues** — never emit an empty `Related issues` stub. Parent/sub-issue
relationships do **not** go here (they use native links / `Spec references` ·
`Parent: #N`); a `conflicts-with` line is **surfaced for a human**, never treated
as resolved.

## Taxonomy — Type × kind × source

Three orthogonal axes; do not collapse them into one another:

- **GitHub Issue Type** (`Feature` · `Bug` · `Task`) — the org-level
  classification, set when the repo supports Issue Types (see capability
  degradation in `ISSUE-WORKFLOW.md`).
- **`steer:kind`** — the *work shape* the contract reconciles against (closed enum
  above). Canonical even when Issue Types are unavailable.
- **`source:*`** — the *origin*, derived from the `steer:source` marker.

| Origin | `steer:kind` | `steer:source` / label | GitHub Type |
|---|---|---|---|
| PO feature request | `feature` | `human` | Feature |
| PO/observed defect | `bug` | `human` (or `ci`, `implementation`) | Bug |
| Internal/refactor task | `task` | `human` (or `dependency`) | Task |
| Audit finding | `finding` | `audit` | Task |
| Adoption gap | `finding` | `adoption` | Task |
| Security-review finding | `finding` | `security-review` | Task |
| Code-review finding | `finding` | `code-review` | Task |
| CI failure (durable) | `bug` | `ci` | Bug |
| Dependency upgrade | `task` | `dependency` | Task |
| Discovered during impl. | `bug`/`task` | `implementation` | Bug/Task |
| Spec question | `spec-question` | `spec` | Task |
| Spec drift | `spec-drift` | `spec` | Task |
| Audit run (history) | `audit-run` | `audit` | Task |

`audit-run` is a parent/history record, **not** implementable work. A generic
`finding` (keyed by `finding-key` + `source`) replaces the former
`audit-finding` kind, which parsers still accept as a prior alias.

## Native issue fields & the Projects v2 boundary

GitHub now ships **native issue fields** — typed metadata (single-select, text,
number, date) defined org-wide and stored **on the issue itself**, distinct from
Project-item fields. The org's default set pins **Priority, Effort, Start date,
and Target date** to issue types. These are *not* labels and *not* in the issue
body — they are first-class issue attributes, board-visible by construction, set
via GraphQL (`/steer:tracker-sync field-set`). **`steer` uses them:**

- **Priority** (`issue_priority`, `ENUMS.md`) — read for ranking; **escalate-only**
  auto-set (raise to a mechanical floor, never lower a human value).
- **Effort** — read for ranking/tie-break; **human-set only** (never auto-derived
  — deriving effort would be deciding product).
- **Start / Target date** — written by `/steer:roadmap` under human confirmation,
  never fabricated; read for milestone-proximity ranking.

Their option sets are **org-defined**: read them from the field definition rather
than assuming names. `Urgent/High/Medium/Low` is GitHub's Priority default; where
an org renamed them, `/steer:tracker-sync bootstrap-fields` reports the mismatch
rather than fabricating options.

**Provenance — the field value is the single source of truth.** A field lives
*outside* the body, so it cannot carry an HTML marker. The agent therefore records
its own last escalation as one **ledger** line inside the `steer:managed` block —
`<!-- steer:priority-floor=High applied=YYYY-MM-DD reason=blocking-question:Q-NNN -->`
— a *record of what the agent did*, **never** the authoritative value. If the
field and the ledger disagree, the **field wins** and the ledger is the evidence
the agent reconciles against (one-directional, like `steer:state` ↔ Project
Status). To avoid fighting a human, the agent escalates only when the floor
exceeds the current value **and** the last field-change actor (GitHub timeline)
was not human; a human downgrade below the floor is recorded as suppressed and
left alone. `field-set` is a separate mutation with **no managed-block
concurrency guard** — the timeline-actor check is the concurrency story for
fields. Where the org has not enabled issue fields, they are omitted and ranking
treats Priority as unset (capability degradation in `ISSUE-WORKFLOW.md`).

A **Project** still builds boards/roadmaps from **Project-*item* fields** —
Status, Iteration, and any custom single-select that is *not* a native issue
field. The plugin **never writes those into an issue body**; a Project-side tool
owns them.

What the issue *does* expose to Projects, and what steer already sets, are its
**native attributes**: the GitHub **Issue Type**, **labels** (`source:*` ·
`needs:*` · `risk:*`), **assignees**, the **milestone**, **native
parent/sub-issue links**, and the **native issue fields** above (Priority, Effort,
dates). A board or roadmap groups, filters, and lays out items from exactly these
— so steer issues are **Projects-v2-compatible by construction**, with no
field-mirroring machinery to maintain. Three of these are **capability-degrading**:
where the org disables Issue Types, native sub-issues, or native issue fields,
they fall back to the `steer:kind` / `steer:parent-issue` markers (or, for fields,
are simply omitted) — and markers are **not** board-visible (see below). **Labels,
assignees, milestone, and any enabled issue fields are always board-visible.**

Because **markers are invisible to Projects** (it cannot read HTML comments):

- **`steer:kind` reaches the board only through the Issue Type** it maps to (the
  Taxonomy table above). The marker stays canonical.
- **`steer:state` is the base source of truth and stays in the body.** A Project
  **Status** field may *mirror* it, but the mirror is a **derived,
  one-directional** reflection — never a gate, never re-read as truth. A board
  with no mirror still gets a coarse Status from GitHub's built-in Project
  workflows (item-added / issue-closed / PR-merged).

Direction of truth is fixed: the **issue and `/spec` are canonical; a Project is
a derived view/overlay.** Planning fields that are **native issue fields**
(priority, effort, start/target date) now live **on the issue** (the section
above) — they are neither markers nor labels. The planning fields with **no home
on the issue** — iteration, size, and any other custom Project-*item* single-select
— live **only** on the Project item and are never mirrored back into the issue.

## Idempotency & deduplication

**Find before create.** Resolve identity in this order; only an **exact**
identifier match auto-reuses an issue:

1. Explicit `#N` supplied by the user — use it after verifying the repository and state.
2. Exact `finding-key`.
3. Exact `feature-id` + `kind`.
4. Exact `question-id`.
5. Exact `dedupe-key`.
6. **Semantic title search → candidates only.** Never silently reuse a semantic match.

Rules:

- Search **all** states (open *and* closed), scoped to the **current repository**.
- **Multiple exact matches** → stop and report a contract violation; do not pick.
- A **closed** exact match → reopen only when it is genuinely the same unfinished
  work; otherwise create a follow-up issue linked to it.
- A **semantic** candidate → present for explicit selection; uncertain or
  multiple candidates mean a new issue, not a silent reuse.
- **Update only the managed block** (see the update protocol). Preserve markers,
  human sections, and unknown markers. Never delete content you didn't write.
- **Writers emit the current schema; parsers accept current + one prior.** When
  the schema version bumps, a writer rewrites the managed block to the new shape
  and updates `steer:schema`; unknown/human markers are carried forward. The prior
  `audit-finding` kind is accepted and migrated to `finding` + `source:audit`.
- **Schema migration is explicit.** It happens only through `/steer:sync` or
  `/steer:issues reconcile` and is reported — never silently during an unrelated
  command.

## Human-created issues — original content is immutable

A human issue opened through a YAML Issue Form has no markers, no managed block,
and no lifecycle state. When an agent **first processes** it:

1. **Preserve the complete original body verbatim** — form responses are never
   rewritten or reordered.
2. Add the identity markers (`schema`, `kind`, `state`, `source`, identity).
3. **Append** the managed block *below* the human body (or maintain agent
   synthesis in one deterministic comment) — the original stays on top, untouched:

```md
[Original human Issue Form body — untouched]

<!-- steer:managed:start -->
## AI synthesis
…agent-maintained sections…
<!-- steer:managed:end -->
```

The plugin must never rewrite the original form responses.

## Issue Forms are human UI, not an agent API

The YAML Issue Forms in
[`../github/ISSUE_TEMPLATE/`](../github/ISSUE_TEMPLATE/) are
**repository UI** for humans opening issues — GitHub exposes no API to submit a
form programmatically. The form and the agent `capture` path share *equivalent
semantic fields*; an agent **renders those fields into this contract** (markers
+ headings + managed block). Never try to "submit a form" via MCP or `gh`.

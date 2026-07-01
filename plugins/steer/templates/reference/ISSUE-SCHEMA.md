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
| `<!-- steer:kind=… -->` | Closed enum (work shape): `epic` · `feature` · `bug` · `task` · `finding` · `spec-question` · `spec-drift` · `audit-run`. | all |
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
| `<!-- steer:parent-issue=N -->` | Parent issue, when native sub-issue links are unavailable (fallback). The marker is **single-valued** — an issue's one direct parent. An Epic→Feature→Task chain is two separate single-parent edges (the *feature* carries `parent-issue=<epic#>`; each *task* carries `parent-issue=<feature#>`), so a feature is simultaneously a child (of its epic) and a parent (of its tasks) via different markers on different issues — nothing is multi-valued. | task, finding, feature (under an epic) |
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

- **epic** — `Outcome` · `Goal / theme` · `Child features` · `Out of scope` ·
  `Spec references` · `Related issues` · `Validation`. `Child features` is a
  checklist of `- [ ] #N — <feature title>`, maintained as features are linked;
  an epic has **no `Acceptance criteria` of its own** — acceptance rolls up from its
  child features, and `Validation` describes the epic-level product acceptance.
- **feature / task** — `Outcome` · `User value` · `Scope` · `Out of scope` ·
  `Acceptance criteria` · `Open questions` · `Spec references` · `Related issues` ·
  `Delivery` · `Validation`.
- **bug** — `Problem` · `Observed behavior` · `Expected behavior` ·
  `Reproduction` · `Evidence` · `Acceptance criteria` · `Technical findings` ·
  `Spec references` · `Related issues` · `Delivery` · `Validation`.
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

### Clickable references — spec/file links and the `Delivery` line

Two conventions keep an issue useful to a PO reading it in the GitHub UI, where a
bare path renders as grey inline code (not a link) and the delivering PR otherwise
lives only in an invisible marker:

- **Repo-file references are Markdown links.** Every spec- or code-file path the
  body cites — under `Spec references`, `Affected specifications`, `Evidence`, or
  inline — is rendered as a link to the file on the repo's default branch:
  `[`<path>`](https://github.com/<owner>/<repo>/blob/<default-branch>/<path>)`.
  The shorthand for that prefix is **`REPO_BLOB_BASE` =
  `https://github.com/<owner>/<repo>/blob/<default-branch>`** — `<owner>/<repo>`
  and `<default-branch>` (usually `main`) come from the repo `/steer:tracker-sync`
  operates on. When a specific line or range is cited, append the GitHub line
  anchor: `…/file.ts#L42` or `…/file.ts#L42-L186`. The **`steer:spec-path` marker
  stays the bare path** (machine-readable identity); only the visible body text is
  linked, so marker-based dedup/reconcile are unaffected. On a non-GitHub tracker,
  or when the blob base can't be resolved, fall back to the bare code-fenced path.
- **The delivering PR/branch is visible, not just a marker.** The
  `steer:pull-request` / `steer:branch` markers are invisible HTML comments, so an
  implementable issue (feature · task · bug) also carries a **`Delivery`** heading
  inside the managed block that mirrors them as a human-visible, clickable line —
  `PR: #NN` (GitHub auto-links `#NN`) and `Branch: \`<branch>\``. It is **omitted
  until a branch/PR exists** and is maintained from the markers by
  `/steer:tracker-sync link-pr` and `/steer:work`. The markers stay **canonical**;
  the line is a derived, one-directional view (like `steer:state` ↔ a Project
  Status mirror) — never re-read as the source of truth.

## Taxonomy — Type × kind × source

Three orthogonal axes; do not collapse them into one another:

- **GitHub Issue Type** (`Feature` · `Bug` · `Task`, plus `Epic` where the org
  defines it) — the org-level classification, set when the repo supports Issue
  Types (see capability degradation in `ISSUE-WORKFLOW.md`). `Epic` is org-defined
  and may be absent even when the standard three exist; when absent the epic keeps
  `steer:kind=epic` with its Type left unset.
- **`steer:kind`** — the *work shape* the contract reconciles against (closed enum
  above). Canonical even when Issue Types are unavailable.
- **`source:*`** — the *origin*, derived from the `steer:source` marker.

| Origin | `steer:kind` | `steer:source` / label | GitHub Type |
|---|---|---|---|
| Product epic / initiative | `epic` | `human` (or `spec`) | Epic *(unset if absent)* |
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

> **The native issue field is the only writable home — a same-named Projects
> board column is a read-only projection. This is a trap; name it.** When a repo's
> Project v2 board surfaces Priority / Effort / dates, they appear as single-select
> **columns that look identical to genuine Project custom fields (e.g. `Size`,
> `Iteration`) but are API-locked**. Every Projects write path fails on them —
> `updateProjectV2Field` and `gh project item-edit` return
> `Only custom fields can be updated. Fields derived from issues or pull requests
> must be updated through their respective APIs` — and every Projects *read* path
> (`field-list`, the `fields` connection, `node()`) reports `options: []`, so there
> is **no option id** to set a value through the Project at all, even though the UI
> shows Urgent/High/Medium/Low. The destination is the **native issue field**: set
> it via **`/steer:tracker-sync field-set`** (which uses the issue-field API), never
> the Projects API. The reverse also holds — a genuine Project custom single-select
> (`Size`, `Iteration`, `Status`) is **not** a native issue field and *is* edited
> through `gh project item-edit`; `field-set` will not find it. When you need to set
> both on the same issue (e.g. seed `Priority` *and* `Size`), they go through two
> different APIs.

**Provenance — the field value is the single source of truth.** A field lives
*outside* the body, so it cannot carry an HTML marker. The agent therefore records
its own last escalation as one **ledger** line inside the `steer:managed` block —
`<!-- steer:priority-floor=High applied=YYYY-MM-DD reason=blocking-question:Q-NNN -->`
— a *record of what the agent did*, **never** the authoritative value. If the
field and the ledger disagree, the **field wins** and the ledger is the evidence
the agent reconciles against (one-directional, like `steer:state` ↔ Project
Status). To avoid fighting a human, the agent escalates only when `floor > value`
**and** the current value is one the agent itself last set — **(value unset and no
prior ledger line) or (a ledger line exists and value equals that ledger value)**;
otherwise the value is human-owned (set but unequal to the agent's recorded
escalation, or set with no ledger at all) and the agent records
`human override of floor X — suppressed` and leaves it. This guard is computable
from the ledger plus a `field-get` read — it needs **no** field-change-actor read
(the gateway exposes none). `field-set` is a separate mutation with **no
managed-block concurrency guard**, so this ledger comparison *is* the concurrency
story for fields: a concurrent human edit shows up as `value ≠ ledger` and
suppresses. Where the org has not enabled issue fields, they are omitted and
ranking treats Priority as unset (capability degradation in `ISSUE-WORKFLOW.md`).

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

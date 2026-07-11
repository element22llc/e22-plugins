---
name: issues
description: "High-level GitHub Issues lifecycle for the /spec spine — capture, triage, brainstorm, materialize, decompose, epic grouping, status, a ranked relationship-aware board view, and bounded reconcile. A thin orchestrator: it delegates product/spec reasoning to /steer:spec, audit findings to /steer:audit, drift to /steer:audit spec, and question promotion to /steer:questions, and routes GitHub reads/writes through /steer:tracker-sync (MCP-first, gh fallback, manual floor) — with one sanctioned exception, the bootstrap-labels mode's inline label creation. Agent-authored issues follow the machine-readable contract (stable headings + hidden markers + managed blocks). /spec stays product truth; the issue is the work/decision layer."
when_to_use: Use to drive a PO idea from capture to a draft spec to decomposed work without losing open questions or overwriting human content.
argument-hint: "[capture | triage | brainstorm | materialize | decompose | epic | status | board | reconcile | publish-audit | publish-drift | publish-adoption | publish-findings | bootstrap-labels] [#issue | feature-id]"
allowed-tools:
  - Bash(git status *)
  - Bash(gh issue list *)
  - Bash(gh issue view *)
  - Bash(gh search issues *)
  - Bash(gh pr list *)
---
<!-- steer:modes capture,triage,brainstorm,materialize,decompose,epic,status,board,reconcile,publish-audit,publish-drift,publish-adoption,publish-findings,bootstrap-labels -->

# Drive the GitHub Issues lifecycle for the /spec spine

`/steer:issues` is the **PO-facing lifecycle workflow** above the low-level
`/steer:tracker-sync` gateway. It **orchestrates; it does not own domain
reasoning** — every step delegates to the skill that owns it and routes GitHub
I/O through `/steer:tracker-sync`. The two invariants from the issue-workflow
reference hold throughout:

- **`/spec` is durable product truth; GitHub Issues is the work/decision layer.**
- **All reads/writes go through `/steer:tracker-sync`** (MCP-first → `gh` → manual
  floor); this skill never calls the GitHub API directly — with one sanctioned
  exception, `bootstrap-labels`, which runs `gh label create --force` inline
  because label-taxonomy setup is a repo-level operation the issue-scoped
  `/steer:tracker-sync` gateway exposes no op for.

Read the references before acting: the lifecycle, state model, and authority
table in `${CLAUDE_PLUGIN_ROOT}/templates/reference/ISSUE-WORKFLOW.md`; the issue
format (markers, headings, **managed blocks**, idempotency) in
`ISSUE-SCHEMA.md`; the open-question contract in `SPEC-FRAMEWORK.md`.

## First, every run

1. **Read `/spec/tracker.md`.** Confirm `system: github`. On a non-GitHub
   tracker, say so and stop — there is no GitHub path; the manual flows in
   `/steer:tracker-sync` apply. Never fabricate tracker state.
2. **Detect capability via `/steer:tracker-sync`** (MCP vs `gh` vs manual) and say
   which path you took, so the user knows whether issues were actually touched.

## Modes

### Delegating modes (the owning skill does the thinking)

- **`brainstorm #N`** — product discovery against an issue, *without* writing a
  spec. Discovery reasoning follows `/steer:spec`'s interview style; the issue
  body stays human-owned. Required steps, in order:
  1. **Read** the issue + related specs.
  2. **Search the existing issue corpus first — this is not optional.** Before
     synthesizing, run **`/steer:tracker-sync search`** across **open *and*
     closed** issues for the topic, the systems/components named, and adjacent
     decisions — don't reason only about the one issue you were handed. Search by
     the obvious keywords *and* their alternatives (e.g. an issue about "Cognito
     hosting" must also search `auth`, `authentication`, `better-auth`,
     `login`, `identity`). The goal is to catch the issue that the current one
     **overlaps, depends on, or — most importantly — silently conflicts with**
     (a hosting choice that a pending auth-migration issue would invalidate).
  3. **Surface every relationship you find** in the AI-synthesis comment: name
     the issue (`#N`), the `issue_relationship` (`ENUMS.md`), and one line of
     why. Call out **conflicts and supersessions explicitly** as a decision a
     human must make — never silently pick a side.
  4. **Propose cross-links.** For each real relationship, propose
     **`/steer:tracker-sync link-related`** to record it under the issues'
     `Related issues` headings (the `#N` mention auto-creates the GitHub
     backlink). With an explicit request or in an active workflow, perform the
     link; for an unsolicited cluster, take **one** confirmation before writing.
  5. **Maintain one** editable "AI synthesis" comment (proposed outcome +
     boundaries + the related-issue cluster) rather than reposting summaries.
  When the corpus search can't run (no MCP/`gh`/manual path), say so — don't
  silently skip it and present a relationship-blind synthesis as complete.
- **`materialize #N`** — turn approved product intent into a spec. Hand to
  `/steer:spec` to write/update `spec/features/<id>/intent.md`, **set `Status:
  draft`** (never `approved` — that's a later explicit `/steer:spec approve`),
  link the issue in `> Tracker:`, run `/steer:spec validate` on the feature, and
  present the diff / open a PR. Comment back on the issue with the exact spec
  path (as a clickable link — `ISSUE-SCHEMA.md` → Clickable references) + commit/PR. **Features only** — an epic has no `intent.md` and is **not
  materializable**; group features under an epic with the `epic` mode instead.
- **`publish-audit [report|triage-doc]`** — take an `/steer:audit` finding set and
  create/update the audit-run parent + selected finding children (see
  `/steer:audit`); file via `/steer:tracker-sync`. Selection comes from the
  session, **or from the audit dashboard's filled triage export** (the
  `<!-- steer:audit-triage -->` document — rule `88-artifacts` return leg): file
  exactly the findings whose `finding-key` is checked, carry each note into the
  issue body, and **flag any key that doesn't match the current finding set**
  (stale or unknown — e.g. the code moved since the audited SHA) instead of
  silently filing or dropping it. Same single confirmation either way.
- **`publish-drift [report]`** — take an `/steer:audit spec` finding set and file
  decision-checklist `spec-drift` issues (see `/steer:audit spec`); never auto-resolve.
- **`publish-adoption`** — reconcile selected `spec/PRODUCTIONIZATION.md` gaps
  into `kind=finding` + `source:adoption` issues (stable `finding-key` per gap;
  **reconcile, don't duplicate**). Findings are **deduplicated by remediation
  work-shape, not 1:1** with sections/rows/bullets; the canonical
  **section → destination** map is the brief's "What publishes, and where" note
  (architectural-choice *decisions* → `/steer:adr` / `/steer:questions`, never
  findings; committed secrets → rotate; the dependency table → **one** upgrade
  finding, not per package). **Partial-publication safe:** flip the brief's
  `> Lifecycle:` to `published-snapshot` **only after all intended findings are
  created or reconciled**; on partial failure, **leave it `active-adoption`** and
  record the successfully-published refs under `> Published findings:`. A rerun
  reconciles by `finding-key` (never duplicates) and completes the flip once the
  set is whole. After a clean flip, **`PRODUCTIONIZATION.md` is an adoption
  assessment snapshot + evidence source — the GitHub issue is canonical** for
  ownership, lifecycle, progress, and closure; the report records the resulting
  issue ref but does not independently track implementation status, and its
  checkboxes are a historical snapshot, not active work.
- **`publish-findings --source code-review|security-review`** — file
  `kind=finding` issues with the matching `source:*` from a `/code-review` or
  `/security-review` pass (stable `finding-key`; reconcile). **Security findings
  support redaction / private handling** — never auto-publish secrets or
  exploit-enabling detail into a broadly visible issue (link to private handling;
  flag `risk:security`; default to human review before public disclosure).

All `publish-*` modes **set the native Priority field to the derived floor on
creation** (the floor table in `ISSUE-SCHEMA.md` → *Native issue fields*) via
`/steer:tracker-sync field-set` — applied once at create time; a reconcile rerun
is escalate-only, so a human who later adjusts Priority is never overridden.

### Net-new modes (logic lives here)

- **`capture`** — open an issue from the current conversation, prototype,
  screenshot, or design source. Gather the same **semantic fields** the matching
  Issue Form asks for (feature / bug / product-question / improvement) and
  **render them into the machine-readable body** (markers + headings + managed
  block) — do **not** try to submit a Form (it's human UI only). Default labels
  per kind (`source:po`, `needs:triage`); enters **Inbox**.
  **Before creating, search the corpus** via `/steer:tracker-sync search` (open +
  closed) — this serves dedup (an exact match means update/skip, not a second
  issue) *and* relationship-discovery. When the new issue **overlaps, depends on,
  or conflicts with** an existing one, populate its `Related issues` heading and
  propose the reciprocal `/steer:tracker-sync link-related`; flag a
  `conflicts-with`/`supersedes` for human reconciliation rather than deciding it.
- **`triage [#N|--all]`** — keep the backlog clean and correctly labelled. For
  each issue:
  - **Deduplicate** — search by marker (`feature-id`+`kind`, `question-id`,
    `finding-key`) and title; flag duplicates and propose close-as-duplicate
    (link to the canonical issue), never silently merging human content.
  - **Label correctness (esp. human-created issues)** — apply the right
    `source:*` (e.g. `source:human` for manually opened issues), `needs:*`, and
    `risk:*` labels from `templates/reference/LABELS.md`. When the kind is
    missing (issue opened without a Form or marker), infer it (feature / bug /
    product-question / improvement) from the content and set the `steer:kind`
    marker + GitHub Issue **Type**. Resolve conflicting labels (e.g. both
    `bug`-ish and `feature`-ish). Kind is never a plain label.
  - **Missing required information** — bug without repro/expected-vs-actual,
    feature without acceptance criteria, etc. Post the request in **one** managed
    comment and apply `needs:triage` rather than guessing the content.
  - **Cleanup signals** — report stale `needs:triage` issues, orphaned
    sub-issues (no parent link), and mislabelled items; propose fixes.
  - **Priority (escalate-only auto-set) & field gaps** — set the native
    **Priority** field to the **mechanical floor** via `/steer:tracker-sync
    field-set`, escalate-only (`max(current, floor)`) under the ledger-based
    never-fight-a-human guard. The floor table, the provenance/suppression
    guard, the PO-directed-seeding distinction (a human value: no ledger, no
    `max()` guard), and the Projects-v2 trap (the native issue field is the
    only writable home) are all canonical in `ISSUE-SCHEMA.md` → *Native issue
    fields & the Projects v2 boundary* — apply them, don't restate them.
    Surface a *missing* Effort or a missing **Priority on a `ready-for-dev`**
    issue as a field gap; propose, never auto-fill (human-set only).
  - **Routing** — suggest the next transition; propose Inbox → Exploring and
    **perform it only where the authority table in `ISSUE-WORKFLOW.md` allows**.
  Scope: `#N` triages one issue; `--all` sweeps open issues, emits a summary
  report, and takes **one** batch confirmation before any writes. All GitHub
  reads/writes (labels, types, comments, closes) go through `/steer:tracker-sync`;
  rewrites touch only the `steer:managed` block. Priority and effort are **native
  issue fields, never labels** (`ISSUE-SCHEMA.md`) — never invent `priority:*` /
  `effort:*` labels for them.
- **`decompose #N`** — create implementation sub-issues from a parent feature.
  **Preconditions:** the feature's `intent.md` exists, `Status: approved`, and
  its **contract readiness is `ready`** — the mechanically-derived signal in
  `SPEC-FRAMEWORK.md` (Contract readiness), which already folds in "a populated
  `contract.md` exists" and "no unresolved blocking question
  `required_before: contract-approval`." Pointing both `decompose` and `status`
  at the **same** derivation is deliberate: they can never disagree. (`--prototype`
  is the only way to decompose before that bar — see below.) Use native GitHub parent/sub-issue
  links when available; else fall back to `Parent: #N` + `<!-- steer:parent-issue=N -->`
  and a generated checklist in the parent. Each child uses the `technical-task`
  body. `--prototype` is the **only** way to decompose before approval, and those
  tasks are clearly marked non-production. **If `#N` is `kind=epic`**, this is the
  wrong tier — redirect to `/steer:issues epic` (an epic groups *features*; it has
  no `contract.md` to gate on).
- **`epic [--new "<title>"] [#E --add #F1,#F2,…] [#F]`** — manage the tier **above**
  features: a parent tracking issue that groups child features (and, transitively,
  their tasks) via native sub-issue links, so a goal spanning several features is
  one visible hierarchy. An epic is a **grouping construct owned by the tracker** —
  it has **no `intent.md`** and is **not materializable**; its "why" is the rollup
  of its child features, optionally pointing at a `vision.md` theme. Verbs:
  - **`epic --new "<title>"`** — create-or-find the epic. **Find before create**
    (search by `dedupe-key` + semantic title via `/steer:tracker-sync search`, open
    + closed — never silently reuse a semantic match). Render the `epic` body
    (`templates/github/issue-bodies/epic.md` — markers + managed block), set
    `steer:state=inbox`, and set **Type=`Epic` only when the org has it**, else keep
    `steer:kind=epic` with the Type unset and emit the capability warning (via
    `/steer:tracker-sync set-type`).
  - **`epic #E --add #F1,#F2,…`** (alias **`epic #F`** to attach a single feature to
    a chosen epic) — link existing feature issues as sub-issues of `#E` via
    `/steer:tracker-sync link-parent` (native sub-issue link, else
    `steer:parent-issue` marker), and maintain the epic's `## Child features`
    checklist in its managed block.
  **Gate:** unlike `decompose`'s contract-readiness gate (a *feature* derivation),
  an epic only needs **its scope agreed + ≥1 child feature identified** — a
  deliberately different, product-level bar, so the two tiers never share a
  derivation. State (`inbox → exploring → in-progress → validate → done`) follows the
  epic path in `ISSUE-WORKFLOW.md`; completion is the **child rollup** (all children
  terminal, ≥1 `done`, PO confirms) — the agent proposes `done`, never auto-closes.
- **`status [#N|feature-id]`** — a unified read-only view: issue state + intent
  status + **contract readiness** (`ready | incomplete | missing`, the derivation
  in `SPEC-FRAMEWORK.md` — never `approved`) + sub-issue progress + blockers. Runs
  `/steer:spec validate` and surfaces any failures. Example shape:
  ```
  Feature customer-export
  Issue: #123 — Validate
  Intent: approved   Contract: ready
  Implementation: 3/4 sub-issues closed
  Preview: available
  Blocking: #134 telemetry
  ```
  **When `#N` is `kind=epic`**, render a **child-feature rollup** instead of
  contract readiness — the linked features, their states, and how many are
  `done`/`validate` — so the epic's progress is the aggregate of its features. Branch
  on `steer:kind`; the feature/task shape above is unchanged. Example shape:
  ```
  Epic billing-revamp
  Issue: #98 — In-progress (Type: Epic)
  Child features: 4 linked — 1 done · 1 validate · 2 in-progress
  Eligible to close: no (2 features not yet terminal)
  ```
- **`board [--all]`** — a **read-only** backlog overview: the open issue set as one
  ranked, relationship-aware, hygiene-flagged view. **Never writes.** Reads through
  `/steer:tracker-sync` (`search`, `field-get`) and says which capability path it
  took. Four sections:
  - **Ranked** — issues ordered by the **composite sort key** in `NEXT-ACTIONS.md`
    (safety level → native **Priority** field → unblock-count → milestone proximity
    → lifecycle depth → created-at/#N). Show each issue's Priority and lifecycle
    state. The board **does not** re-derive the cross-workflow "single most critical
    thing" — that is `/steer:next`'s job (locality: a board ranks *issues*; it does
    not arbitrate ADRs, PR-review gates, or secrets). Where issue fields are
    unavailable, Priority shows as unset and the remaining terms order the list.
  - **Relationships** — dependency clusters from native blocked-by edges (and the
    `Related issues` markers where native is unavailable): what blocks what, and any
    `conflicts-with`/`supersedes` pair surfaced for a human. Never auto-resolve.
    Also show **Epic → Feature → Task** parent/child clusters — these are native
    sub-issue links, so they render as a real hierarchy in a Projects v2 view by
    construction (markers only where native sub-issues are unavailable).
  - **Dedup candidates** — likely duplicates by marker (`feature-id`+kind,
    `question-id`, `finding-key`, `dedupe-key`) and semantic title overlap; propose,
    don't merge (close-as-duplicate is a `triage` action).
  - **Hygiene** — stale `needs:triage`, orphaned sub-issues (no parent), **orphaned
    epics** (an epic that claims `in-progress` or later with zero linked features),
    missing **Priority** on `ready-for-dev`, missing kind/Type, and mislabelled items
    — each with the `triage`/owning action that fixes it. The fix for a Priority/Effort
    gap is a **native issue-field** write via `/steer:tracker-sync field-set` (PO value)
    or the `triage` escalate-only floor (mechanical) — **never** the Projects API,
    whose same-named board column is a read-only projection (`ISSUE-SCHEMA.md`).
    Surfaces work; performs none.
  `#N`/`feature-id` scopes to one item's neighborhood; `--all` (default) sweeps open
  issues. It ends with the `## Recommended next actions` block (below).
- **`bootstrap-labels`** — idempotently create/reconcile the supported label
  taxonomy so Issue Forms and agent labels actually apply (GitHub silently drops a
  form label that doesn't exist). Reconciles the exact `source:*` / `needs:*` /
  `risk:*` set in `templates/reference/LABELS.md` (the canonical list; `source:*`
  mirrors the `steer:source` enum) via `gh label create --force` (create-or-update;
  safe to re-run). `/steer:init` and `/steer:adopt` call this during setup. Kind is
  **not** a label (it's the `steer:kind` marker + Issue Type).
- **`reconcile #N | feature-id | --all`** — verify issue ↔ spec pointers agree
  and the lifecycle is internally consistent; update only the managed block of
  any issue it touches; **never auto-resolve behavioural drift or a product
  decision** — route those to a human. Two scopes:
  - **bounded** (`#N` / `feature-id`) — one issue or feature. Enforce the
    question-reconciliation floor below.
  - **repo-wide** (`--all`) — sweep the spine + tracker and report every
    disagreement: referenced issues that no longer exist; closed features whose
    issues are still open (or vice versa); approved specs missing a tracker ref
    (`require_tracker_ref_for_features`); open `spec-drift` issues that no longer
    reproduce; sub-issues with no parent link; **epic↔feature inconsistency** (a
    closed epic with open child features or vice versa, or a `validate`/`done` epic
    with no linked features); merged PRs that left a stale
    `Status`; promoted questions whose issue is closed but whose `Q-NNN` is still
    `open`; and **contract-less issues — the after-the-fact recovery path for a
    raw create that bypassed `/steer:tracker-sync`** (the point-of-action
    issue-create contract nudge in `check-bash-actions.sh` is best-effort, not a gate). Flag any
    open issue missing the machine-readable contract: **no `steer:` markers AND no
    `steer:managed` block** (so neither `steer:kind` nor `steer:source` is set,
    the issue carries no `source:*` label, and its Type is the unset default).
    Such an issue is invisible to marker-based dedup (`triage`/`board`) and to
    every lifecycle check above, so surface it here with the retrofit action —
    infer kind + labels + Type via `/steer:issues triage` and apply the contract
    through `/steer:tracker-sync` (markers + derived `source:*` label + Issue
    Type). **Never invent intent:** retrofit only the machine-readable contract
    onto the existing human body; do not rewrite or guess the issue's content, and
    leave a genuinely human-authored issue (one a human typed directly) for
    `triage` to label rather than treating it as drift. Output is a reconciliation
    report + proposed actions, confirmed once before any write. `--all` is
    read-heavy — route all fetches through `/steer:tracker-sync` and say so.

## Question-reconciliation floor (safe from the first release)

Even before repo-wide reconcile, the per-feature lifecycle must guarantee — via
`/steer:spec validate` at every gate and `reconcile`:

- an **approved** intent contains **no `open` `blocking` question gated at
  `required_before: intent-approval`** (questions gated at later gates block
  their own gate, not the already-granted approval);
- a `deferred` question has `owner` + `required_before`;
- a **promoted** question carries a `tracker:` ref (and the issue carries its
  `question-id`);
- a question whose issue is **closed** cannot stay silently `open` — it surfaces
  as a failure that blocks the relevant gate;
- **resolving** a question means folding the answer into the spec's normative
  prose, not leaving it only on the issue or in `_Resolution:_`.

This is the trap the whole layer exists to prevent: a question promoted to an
issue, answered, and never returned to the spec, with implementation proceeding
on stale intent.

## Recommend the next action

After any mode, emit a `## Recommended next actions` block per
`${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md`. As an orchestrator,
recommend the **next valid lifecycle transition** for the issue(s) just touched
(locality rule), delegating the action to its owning skill.

| Issue lifecycle state | Category | Action / suggested command |
|---|---|---|
| `inbox`, not yet triaged | Recommended | `/steer:issues triage` |
| `exploring` (feature needs a spec) | Human decision required | Shape intent — `/steer:issues materialize` → `/steer:spec` |
| `ready-for-spec`, intent not approved | Human decision required | PO approves the intent (no command) |
| `ready-for-dev`, decomposed and actionable | Recommended | Start it — `/steer:work start #N` |
| `in-progress` / `validate` | Human decision required | A reviewer reviews the open PR (no command) |
| Unresolved `blocking` question on the item | Blocking now | `/steer:questions` |
| Several `ready-for-dev` items to sequence into releases | Recommended | Lay them on a timeline — `/steer:roadmap` |
| `epic` in `exploring`, child features identified | Recommended | Link them — `/steer:issues epic #E --add …` |
| `epic` whose child features are all terminal (≥1 `done`) | Human decision required | PO confirms the epic outcome (no command) |
| Nothing queued | Complete | `No action is currently required.` |

Pick one `Current recommended action` by precedence. Read-only and idempotent —
it recommends the transition; it does not perform unapproved writes.

## Guardrails

- **Orchestrate, don't duplicate.** Delegate to the owning skill; never restate
  its prose here. All GitHub I/O goes through `/steer:tracker-sync`.
- **Idempotent.** Find before create — search by marker (`feature-id`+`kind`,
  `question-id`, `finding-key`). A match means update, not create.
- **Managed blocks only.** Updating an issue rewrites **only** the
  `steer:managed` block; markers, human sections, and unknown content are
  preserved verbatim.
- **Authorization & confirmation.** Reads never confirm. When to act without
  asking vs confirm first (explicit request → no ask; bulk finding-publish → one
  batch confirmation; unsolicited idea → confirm before external publish;
  managed-block update in an active workflow → no repeat) and when a state
  transition may be *performed* vs only *proposed* are governed by the single
  **Authorization & confirmation** block + authority table in `ISSUE-WORKFLOW.md`.
  This skill does not restate them.
- **No code, no spec rewrites beyond pointers + materialized intent.** The spec
  edits this skill drives are the materialized `intent.md` (via `/steer:spec`) and
  `> Tracker:` / `tracker:` pointer lines. It never edits `/apps`, `/packages`,
  or `contract.md` behavior. **Execution from an issue — claim, branch,
  implement, test, open the PR, transition — belongs to `/steer:work`**, not here.

## Coupling rules

Lifecycle, state model, and authority are canonical in `ISSUE-WORKFLOW.md`; the
issue format in `ISSUE-SCHEMA.md`; the open-question + validate contract in
`SPEC-FRAMEWORK.md`; tracker conventions in rule `35-issue-tracker` and
`/steer:reference traceability`. GitHub I/O is `/steer:tracker-sync`'s job. This skill only
sequences those across the lifecycle.

# Changelog

All notable changes to the `e22-plugins` marketplace. Each plugin is versioned
in its own `.claude-plugin/plugin.json`; this file records what changed and when.

## e22-standards

### [Unreleased]

Audit-mitigation series (rev. 2). Implementation PRs accumulate here; the release
PR assigns the version and converts this to a versioned entry.

- **Lifecycle coherence (audit F2, F3, F7, F8, F19).** Corrects the spec/issue
  state model before it is canonicalized:
  - **F2** — materialized intents are written as `Status: draft` (not
    `proposed`); only `/e22-spec approve` flips to `approved`. Prose aligned in
    `e22-issues`, rule `30-spec-workflow`, and `ISSUE-WORKFLOW.md`.
  - **F3** — new **`/e22-spec approve <feature-id>`** subcommand with an explicit
    transition contract: `draft → approved` only (refuses to downgrade
    `implemented`/`validated`/`live`; idempotent on `approved`); an exact
    blocking-question predicate (blocking impact ∧ unresolved status ∧
    `intent-approval` gate); and structural approval evidence (`> Approved by:` /
    `> Approved at:` added to the intent template) plus one HISTORY entry.
  - **F7** — lifecycle-aware production categories replace the single "Required
    before production": **Required before initial production**, **Required before
    next production release**, and **Urgent live-system remediation**, so an
    already-live system never gets a pre-launch instruction. Updated across
    `NEXT-ACTIONS.md`, `e22-spec`/`e22-build`/`e22-drift`/`e22-adopt`/`e22-next`,
    and the next-action fixtures.
  - **F8** — closure **reason**, not mere closure, decides the terminal state:
    new `cancelled` state added to the issue-state enum; `validate → done` only
    when closed as `completed`; `rejected`/`duplicate`/`obsolete`/`not-planned`/
    `superseded` → `cancelled`. Wired into `ISSUE-WORKFLOW.md`, `ISSUE-SCHEMA.md`,
    `e22-work`, and `e22-next`.
  - **F19** — **contract readiness** is a mechanically-derived signal
    (`ready | incomplete | missing`, never `approved`) defined in
    `spec-framework.md`; `/e22-issues status` and the `decompose` precondition
    share the one derivation so they cannot disagree.

- **Remove command shims; correct invocation syntax (audit F4).** A runtime
  smoke test confirmed plugin skills are invoked **only** as
  `/e22-standards:<skill>` — Claude Code always namespaces plugin skills, so the
  bare `/e22-*` form never worked for a user. The 13 thin `commands/*.md` shims
  (which only restated skill semantics and produced the same namespaced
  invocation) are deleted, and every `/e22-*` reference across rules, skills,
  reference prose, templates, scaffold, hooks, README, and CLAUDE.md is rewritten
  to the namespaced form. CLAUDE.md's "every skill is invokable as `/<skill-name>`"
  claim is corrected. (Branch names like `feat/e22-adopt` and tracker markers like
  `e22:state` are unaffected — they are not slash commands.)

- **Canonical enum registry + standards validation (audit "automated validation",
  F1-secondary, F5).**
  - **`templates/reference/enums.registry`** — a strict line-oriented,
    shell-AND-python-parseable file is now the single source of truth for every
    controlled vocabulary (feature status, question status/impact,
    required_before, issue kind/state/source, ADR status, next-action category).
    **`ENUMS.md`** documents them for humans; CI asserts the two agree.
  - **`scripts/check_standards.py`** (wired into `mise run check`/`ci`) adds eight
    semantic checks: when_to_use formatting (a restricted-grammar check, *not* a
    YAML parse — F1-secondary); bidirectional declared-mode markers
    (`<!-- e22:modes … -->` ↔ argument-hint ↔ body ↔ cross-references);
    `commands/` is gone; every `/e22-*` reference is namespaced and resolves to a
    real skill; every Status/state/source/required_before/next-action token is a
    registry member (the deprecated "Required before production" is forbidden);
    MANIFEST sources exist; README skill inventory is complete; cross-field
    invariants. `check_fixtures.py` now derives its category/state sets from the
    registry too (no drift).
  - **F5** — README skill inventory completed (adds `e22-issues`, `e22-work`,
    `e22-spec`, `e22-next`, `e22-sync`, `e22-tracker-sync`), grouped by area.
  - `check_plugin.py` loses its now-dead `commands/` handling; the live plugin
    passes the full gate (`mise run check`) and the expanded test suite.

- **Productionization lifecycle + single authority rule (audit F6, F16).**
  - **F6** — `productionization.md` gains a parseable `> Lifecycle:` field
    (`active-adoption` → `published-snapshot` → `superseded`, with
    `> Published findings:` / `> Superseded by:` pointers). `/e22-standards:e22-adopt`
    writes `active-adoption`; `/e22-standards:e22-issues publish-adoption` is
    **partial-publication safe** — it flips to `published-snapshot` only after
    *all* intended findings are filed, else stays `active-adoption` and records
    the published refs (rerun reconciles by `finding-key`, never duplicates).
    `/e22-standards:e22-next` and `/e22-standards:e22-questions` honor the field:
    a `published-snapshot` brief's checkboxes are historical evidence, not active
    work.
  - **F16** — one labelled **Authorization & confirmation** block in
    `ISSUE-WORKFLOW.md` is the single source for when an agent acts without asking
    vs confirms (explicit request → no ask; bulk finding-publish → one batch
    confirmation; unsolicited idea → confirm before external publish;
    managed-block update in an active workflow → no repeat). `/e22-standards:e22-issues`
    now references it instead of restating the semantics.

### 1.48.0

- **New `/e22-next` — read-only workspace navigator.** Delivers the cross-workflow
  arbitrator that 1.47.0 deferred. Where each workflow skill's
  `## Recommended next actions` block is locality-bound (it recommends only from
  its own invocation), `/e22-next` is the one tool that reconstructs the **whole
  workspace state cold** and arbitrates the single best action across *unrelated*
  workflows.
  - **Reconstructs** branch/PR + CI/merge state, `/spec` feature `Status`, open
    questions (`impact`/`required_before`), `Proposed` ADRs, tracker issue
    lifecycle states (via `/e22-tracker-sync`, MCP-first/`gh` fallback), work
    claims (`e22:state`/`e22:branch`), and `spec/.version` drift — then emits a
    state-reconstruction summary plus the standard `## Recommended next actions`
    block ending in one `Current recommended action`.
  - **Reuses, never forks, the contract** in `templates/reference/NEXT-ACTIONS.md`
    (same five categories + shared safety precedence). It carries its own
    workspace-level dimension table and defers *how* to resolve each state to the
    owning skill (`/e22-work`, `/e22-spec`, `/e22-questions`, …); it never edits,
    commits, publishes, merges, or advances state. No `/spec` spine → the only
    action is bootstrap (`/e22-init`/`/e22-adopt`).
  - **New `templates/reference/next-fixtures/`** — prose golden scenarios (not
    executable) pinning the cross-workflow arbitration: secret > PR review,
    blocking question > ready work, stale-reconcile > new work, the human-decision
    tie-break, release-gating > optional bookkeeping, all-clean, and the
    no-spine short-circuit.
  - Wired into the router (`00-router.md`) and surfaced as the `/e22-next`
    command; the 1.47.0 "not yet built" forward-reference in `NEXT-ACTIONS.md` now
    points at the shipped navigator.

### 1.47.0

- **Standardized "Recommended next actions" handoff.** Every major workflow now
  ends with a deterministic, read-only `## Recommended next actions` block that
  derives the next step from observed repo/spec/tracker state — so a workflow
  reconnects its artifacts to the next human or agent action instead of just
  stopping.
  - **New shared convention** `templates/reference/NEXT-ACTIONS.md` owns all the
    shared logic: the five categories (`Blocking now`, `Human decision required`,
    `Required before production`, `Recommended`, `Complete`), a two-level
    precedence (universal safety + skill-local lifecycle), the derivation rule
    (reuse existing state enums; never "always run X"), the output format, and the
    **read-only + locality** rules. The canonical field is `Current recommended
    action` (an *action*, not a command); a `Suggested command` is offered only
    when a real command applies, and `No action is currently required.` is allowed.
  - **New `templates/reference/next-actions-fixtures/`** — prose golden scenarios
    (not executable) that pin the intended arbitration and guard against drift.
  - **Wired into ten skills**, each with its own domain state→action table:
    `/e22-adopt`, `/e22-audit`, `/e22-spec`, `/e22-work` (Phase 1) and
    `/e22-build`, `/e22-drift`, `/e22-questions`, `/e22-init`, `/e22-sync`,
    `/e22-issues`, `/e22-adr` (Phase 2). `/e22-audit` keeps its boundary (routes
    *potential* concerns to specialists; only a confirmed secret is a stop), and
    `/e22-work` post-merge reconciliation is owned by `resume` (no redefinition of
    `finish`).
  - A repo-wide `/e22-next` navigator that arbitrates across unrelated workspace
    state is intentionally **deferred** to a later release.

### 1.46.0

- **Backlog producers — findings flow into the backlog.** Closes the loop so the
  backlog is fed from every source, not just PO capture.
  - **`/e22-issues publish-adoption`** — reconciles selected
    `spec/PRODUCTIONIZATION.md` gaps into `kind=finding` + `source:adoption`
    issues (stable `finding-key`; reconcile, don't duplicate). After publication
    the **GitHub issue is canonical** for ownership/lifecycle/closure;
    `PRODUCTIONIZATION.md` stays an assessment snapshot + evidence source that
    records the issue ref but does not track its status. Pointer added to
    `/e22-adopt`.
  - **`/e22-issues publish-findings --source code-review|security-review`** —
    files `kind=finding` issues with the matching `source:*` from a review pass.
    **Security findings redact secrets / exploit detail** and default to human
    review before public disclosure. Pointer added to `/e22-audit`.
  - **CI-failure policy** in `ISSUE-WORKFLOW.md` — transient → none; reproducible
    on the default branch → create/reconcile a `bug` with `source:ci` (stable
    key); recurring flake → one keyed issue; PR-specific → comment on the PR
    unless it outlives the PR.
  - (Implementation-discovered work and the closed `e22:kind`×`source` taxonomy
    were already established in 1.44.0 / 1.43.0.)

### 1.45.0

- **Repository bootstrap for the issue-first backlog.** Makes a GitHub-adopted
  repo actually carry the contract: real Issue Types, an existing label
  taxonomy, a Project owner, and honest Project-bootstrap claims.
  - **Issue Forms set the GitHub Issue Type** — `bug.yml` → `type: Bug`,
    `feature.yml` → `type: Feature`, `product-question.yml` → `type: Task`;
    `improvement.yml` sets no Type (classified at triage into Feature/Task/Bug).
    Dropped the duplicate `bug`/`feature` kind labels; reconciled `source:po` →
    `source:human` to match the canonical `e22:source` vocabulary.
  - **`/e22-issues bootstrap-labels`** (new) — idempotently creates/reconciles the
    canonical `source:*` / `needs:*` / `risk:*` set (`gh label create --force`)
    so form and agent labels actually apply (GitHub silently drops a label that
    doesn't exist). The canonical list lives in `templates/reference/LABELS.md`.
    `/e22-init` and `/e22-adopt` now run it when the tracker is GitHub Issues.
  - **`tracker.md` gains `project.owner`** (Project numbers are owner-scoped) and
    documents the `Status`-mirrors-`e22:state` relationship; the `labels:` map is
    reconciled to the canonical `source:*` vocabulary.
  - **Project bootstrap is honest** — `/e22-issues project bootstrap` creates/
    reconciles fields + options and **outputs manual view-creation instructions**
    (`gh` has no saved-view API) rather than claiming to have created views.
    `sync` is specified deterministically: discover field/option IDs from names
    at runtime, add the issue if absent, mirror `e22:state` → `Status`, report
    missing/renamed fields, and degrade when the `project` scope is missing.

### 1.44.0

- **Local execution workflow — issue-first routing and the `/e22-work` skill.**
  Builds on the issue contract (1.43.0) to make the local, issue-first model
  operational. `/e22-issues` owns the backlog; the new `/e22-work` owns execution.
  - **New always-on rule `36-issue-first`** — in a GitHub-adopted repo
    (`system: github`), every code/config/infra/behavior change has a GitHub
    issue before the first repository mutation; explicit fix/implement/add
    requests create without confirmation, capture-only/ambiguous language does
    not. Scoped to GitHub-adopted repos; non-GitHub and pre-`/spec` repos keep
    today's flow.
  - **Router** now sends bare issue work ("work on #123", "fix #123", "implement
    #123 and #124") to `/e22-work`, and unissued mutations through find-or-create
    then `/e22-work`; capture-only → `/e22-issues capture`, backlog list →
    `/e22-issues status`.
  - **New `/e22-work` skill + command** — `start` / `resume` / `status` /
    `finish` with distinct, idempotent semantics: validate → claim (refusing to
    override a conflicting claim/branch) → branch (repo convention, else
    `issue/<n>-<slug>`) → load specs → implement → test → update the managed
    block → open the PR → transition. Completion is explicit (PR opened →
    `validate`, never `done`); one branch/PR per issue by default; discovered
    out-of-scope work becomes a separate linked issue. A CLI implement request
    authorizes local edits + tests; commit/push/PR follow autonomy rules;
    merge/deploy are never implied.
  - **`/e22-tracker-sync` is now the generic tracker-metadata gateway** — adds
    `search`/`get`/`find-or-create`/`create`/`update`/`comment`/`set-type`/
    `label`/`transition`/`assign`/`link-parent`/`link-pr`/`close`/`add-to-project`
    as the single low-level layer `/e22-issues` and `/e22-work` call. The boundary
    is tracker metadata only — **git and PR delivery are not gateway operations**.
    `set-type` degrades when org Issue Types are unavailable. Fixed the tracker
    detection to read the `system: github` frontmatter key (not the old
    `System: GitHub Issues` prose).
  - **Intent-aware confirmation** replaces the blanket "creating issues is
    outward-facing → confirm" in `/e22-issues` and `/e22-tracker-sync`.
  - **Definition of Done, End of session, and Commit autonomy** updated for the
    issue-first model (issue exists before first mutation; `e22:state` reflects
    reality; PR references the issue; discovered work filed separately).
  - **New safety-net hook `check-issue-before-mutation.sh`** — a non-blocking,
    once-per-session POSIX-`sh` nudge (no `jq`) that fires on the first
    source-code write in a `system: github` repo. Primary enforcement stays in
    routing + skills.

### 1.43.0

- **Issue contract v2 — the schema groundwork for an issue-first, local-first
  backlog.** This is the normative-contract PR; no rule or skill behavior depends
  on it yet (routing, `/e22-work`, and bootstrap land in following changes). The
  machine-readable issue format in `ISSUE-SCHEMA.md` and the lifecycle in
  `ISSUE-WORKFLOW.md` now describe a backlog where every repository mutation has
  a GitHub issue first.
  - **Closed `e22:kind` enum** — `feature · bug · task · finding · spec-question ·
    spec-drift · audit-run`. The former `audit-finding` kind is replaced by a
    generic `finding` keyed by `finding-key` + `e22:source`; parsers still accept
    `audit-finding` as a prior alias and migrate it.
  - **New canonical markers** — `e22:state` (base lifecycle source of truth, with
    a Project field mirroring it when enabled), `e22:source` (canonical origin;
    the `source:*` label is derived), `e22:dedupe-key` (generic conceptual
    identity), plus optional `e22:claimed-by` / `e22:branch` / `e22:pull-request`.
    `e22:schema` is bumped to `2` and documented as the schema-version marker
    (no second marker introduced — one source of truth).
  - **Marker requirement matrix** — which markers are required for agent-created
    vs human issues before/after first agent touch.
  - **Lifecycle is a closed enum with per-kind readiness** — `inbox · exploring ·
    ready-for-spec · ready-for-dev · in-progress · validate · blocked · done`
    (no standalone `ready`). Bugs/tasks/deterministic findings skip the spec
    gates; questions/drift need a human decision first. Completion is explicit:
    opening a PR → `validate`, never `done`; `done` ⇔ a closed issue; a PR closed
    without merge returns to `in-progress`/`blocked`; `blocked` is reachable from
    any non-terminal state and returns to the prior state.
  - **Concurrency-safe managed-block protocol** — re-fetch-before-write, recompute
    once on a detected change, stop and report on a second change, never overwrite
    unseen edits; duplicate/malformed blocks **fail closed** (body unchanged +
    proposed repair). Original human Issue-Form content is immutable — agents
    append a managed block, never rewrite form responses.
  - **Taxonomy table** — GitHub Issue **Type** × `e22:kind` × `source:*` as three
    orthogonal axes, with capability degradation when org-level Issue Types are
    unavailable (continue on `e22:kind`, no duplicate kind-labels).
  - **Exact-only deduplication** — explicit `#N` → `finding-key` → `feature-id`+kind
    → `question-id` → `dedupe-key` auto-reuse; semantic title search yields
    candidates only; searches all states, scoped to the current repo; multiple
    exact matches stop and report.
  - **New/updated body templates** in `templates/github/issue-bodies/` —
    `feature`, `bug`, `spec-question`, `generic-task`, and `finding` (migrated
    from `audit-finding`); existing templates carry `e22:state`/`e22:source` and
    `schema=2`. **Normative conformance fixtures** added under
    `templates/reference/fixtures/managed-block/` (paired input/expected — not a
    test runner). Fixed the stale `../github/issue-forms/` link to the real
    `../scaffold/github/ISSUE_TEMPLATE/` path.

### 1.42.0

- **`/e22-adopt` no longer manufactures ADRs from inference.** Adoption used to
  reverse-engineer an `Accepted` ADR for each hard-to-reverse as-built choice —
  inventing the context, "alternatives considered," and approval status from the
  code alone. The code proves a choice *exists*, not *why* it was made or that
  anyone ratified it, so this could silently launder a standards violation (e.g.
  raw SQL stamped `Accepted` while the same run flagged it as a gap) into an
  approved exception.
  - **Governing rule: no ADR from inference.** Step 6 now *inventories* as-built
    architectural choices as **facts + evidence + conformance + disposition + a
    decision candidate** in `PRODUCTIONIZATION.md`. An ADR is authored only when a
    **human makes an explicit forward decision** during adoption (retain, replace,
    rewrite, reject), and stays `Proposed` until a named decider accepts it —
    generic adoption-PR approval does not ratify it.
  - **New `PRODUCTIONIZATION.md` section** — *Architectural choices requiring
    decision* — preserves choices the gap table doesn't capture (auth model,
    tenancy, deployment platform, db engine, …) without fabricating rationale.
  - Updated `skills/e22-adopt/SKILL.md`, `commands/e22-adopt.md`, and
    `templates/spec/productionization.md` (the adoption-progress checklist + the
    new section). `e22-audit` remains the defense-in-depth net that later flags
    architectural choices still lacking an ADR.

### 1.41.0

- **Skill discovery metadata.** Frontmatter housekeeping across all skills — no
  workflow-body changes.
  - **`when_to_use` split.** Separated each skill's capability `description` from
    its automatic-invocation triggers using the supported `when_to_use`
    frontmatter field, across all 17 skills. Cleaner classification; the combined
    `description` + `when_to_use` stays under Claude Code's 1,536-char listing cap.
  - **Removed nonexistent aliases.** Dropped `/e22-idea` and `/e22-prototype` from
    `e22-build`'s metadata — they were never real commands (skill command names
    are structural, derived from the directory, not from prose).
  - **`argument-hint` autocomplete.** Added `argument-hint` to the arg-taking
    skills (`e22-build`, `e22-spec`, `e22-spec-scaffold`, `e22-issues`,
    `e22-tracker-sync`) using their actual accepted argument values.

### 1.40.0

- **GitHub Issues lifecycle — Phase 3: reconciliation and Projects.** Completes
  the integration on top of Phases 1–2 (v1.38.0, v1.39.0).
  - **Reconciling audit.** `/e22-audit` now defines the full cross-run lifecycle:
    findings are keyed by a stable, never-line-based **`finding-key`** (the
    conceptual defect) with a separate **`evidence`** fingerprint for the observed
    lines, so moving code updates evidence rather than forging a new finding.
    Re-runs reconcile — same key → update; gone → comment + close; changed →
    update evidence; new → create; false positive → stays closed. Auto-close is
    gated by a confidence rule (**`resolution_mode: deterministic`** may
    auto-close; **`reviewer-confirmed`** judgment calls need a human yes).
    **Audit-run records are immutable history** — one per run (`audit-id`), never
    re-edited. Schema + `audit-finding` template gain the `evidence` marker.
  - **Repo-wide reconcile.** `/e22-issues reconcile --all` sweeps the spine +
    tracker and reports every disagreement (dangling refs, closed-feature/open-
    issue mismatches, approved specs missing a tracker ref, drift issues that no
    longer reproduce, parentless sub-issues, stale `Status` after merge, closed
    question issues with a still-`open` `Q-NNN`). Bounded single-issue reconcile
    stays the Phase 2 behavior.
  - **Optional Projects.** New `/e22-issues project [bootstrap|sync]` creates the
    recommended fields/views and sets item field values via `gh project`, gated
    on `project.enabled` in `tracker.md` and **degrading gracefully** when
    Projects / org-level issue fields (public preview) are unavailable — the base
    lifecycle never depends on them.
  - **Sub-issue fallback** is explicit in `decompose`: native GitHub parent/
    sub-issue links when available, else `Parent: #N` + `<!-- e22:parent-issue=N -->`
    and a generated checklist.

### 1.39.0

- **GitHub Issues lifecycle — Phase 2: the `/e22-issues` orchestrator + safe local
  lifecycle.** Builds on the Phase 1 contracts (v1.38.0).
  - **New skill `/e22-issues`** — the PO-facing lifecycle workflow above the
    low-level `/e22-tracker-sync` gateway. A **thin orchestrator**: delegating
    modes (`brainstorm`/`materialize` → `/e22-spec`, `publish-audit` →
    `/e22-audit`, `publish-drift` → `/e22-drift`) and net-new modes (`capture`,
    `triage`, `decompose`, `status`, bounded `reconcile #issue|feature-id`). All
    GitHub reads/writes route through `/e22-tracker-sync`; issue updates touch
    only the `e22:managed` block; creates are idempotent (find-by-marker).
    `materialize` sets `Status: proposed` only — approval stays a separate
    explicit step; `decompose` requires an approved intent unless `--prototype`.
    Ships a `/slash` alias.
  - **`/e22-spec validate [feature-id|--all]`** — a local, GitHub-independent
    structural check over the open-question contract: open blocking question in
    an approved intent, deferred missing `owner`/`required_before`, closed-issue
    but still-`open` question, promoted-without-ref, resolved-without-resolution.
    Runs at `/e22-spec approve` (a blocking question **blocks approval**) and is
    called by `/e22-issues` and `/e22-drift`. Defense in depth: correctness holds
    even when the tracker is unreachable.
  - **Question-reconciliation floor** — enforced from this release so the
    per-feature lifecycle can't silently lose a promoted-then-answered question
    before implementation proceeds on stale intent.
  - **Wiring.** `/e22-audit` now emits the two-level audit-run + finding-key
    children; `/e22-drift` emits decision-checklist `spec-drift` bodies and
    reaffirms it never auto-resolves; `/e22-questions` applies the keep-vs-promote
    test, keeps the structured `Q-NNN` and sets its `tracker:` field on promotion;
    `/e22-spec` gates approval on `validate`. The router lists `/e22-issues`.

### 1.38.0

- **GitHub Issues lifecycle — Phase 1: contracts and scaffold.** Lays the
  machine-readable foundation for an issue-driven product lifecycle, ahead of the
  `/e22-issues` orchestrator skill (Phase 2) and repository-wide reconciliation
  (Phase 3).
  - **Machine-readable issue contract.** New `templates/reference/ISSUE-SCHEMA.md`
    defines hidden identity markers (`e22:schema`, `kind`, `feature-id`,
    `finding-key`, `audit-id`, …), stable section headings, **managed-block
    boundaries** (`<!-- e22:managed:start/end -->` so agent updates never clobber
    human edits), idempotency rules, and a schema-compatibility policy.
  - **Lifecycle reference.** New `templates/reference/ISSUE-WORKFLOW.md` owns the
    capture → brainstorm → validate → materialize → shape → implement lifecycle,
    the `Status` state model + **authority table** (which transitions an AI may
    propose vs perform), the small label taxonomy (`source:*`/`needs:*`/`risk:*`),
    issue types, and optional GitHub Project field/view guidance.
  - **Structured open questions.** `spec-framework.md` now defines a normative
    machine-readable question format — stable `Q-NNN` IDs with
    `status`/`impact`/`owner`/`required_before`/`tracker` — plus the
    `/e22-spec validate` contract (the GitHub-independent floor that blocks an
    approval while a blocking question is open). Adopted in the `feature-intent.md`
    and `vision.md` templates.
  - **Agent issue-body templates** (plugin-internal, not installed):
    `templates/github/issue-bodies/{audit-run,audit-finding,spec-drift,technical-task}.md`,
    each managed-block-wrapped with identity markers — including the stable,
    never-line-based audit `finding-key`.
  - **YAML Issue Forms.** The bundled scaffold's Markdown issue templates are
    replaced by PO-friendly forms (`feature.yml`, `bug.yml`,
    `product-question.yml`, `improvement.yml`); forms are human UI only — agents
    render the same semantic fields into the issue contract, never submit a form.
  - **`tracker.md` frontmatter.** A deterministic config block (system,
    repository, ref format, optional `project`/`workflow`/`labels`/`fields`) with
    **safe unset defaults** — no fabricated repository or project number.
  - **Wiring.** Rules `35-issue-tracker` (keep-vs-promote, names `/e22-issues`)
    and `30-spec-workflow` (capture-first → materialize path) updated; `MANIFEST`
    and a `MIGRATIONS` ledger entry cover the form swap + frontmatter splice for
    existing repos via `/e22-sync`.

### 1.37.1

- **Docs: de-dup open-questions placement between reference files.** The
  `intent.md`-vs-`vision.md` placement rule for `## Open questions` was stated in
  both `spec-framework.md` (canonical, under Structure) and re-derived in
  `TRACEABILITY.md`'s routing table. The routing-table row now points to
  `spec-framework.md` instead of restating the split, keeping a single source of
  truth. No behavior change.

### 1.37.0

- **New skill `/e22-spec` — brainstorm a feature spec without building it.** The
  no-build counterpart to `/e22-build`: it scaffolds the feature spine, drives
  the intent interactively (problem → users → outcome → acceptance criteria),
  sweeps open questions to resolution, and **stops at an approved intent**. Its
  defining guardrail is that it never creates or edits anything under `/apps` or
  `/packages` — if asked to build, it points to `/e22-build` rather than crossing
  the line. Fills the gap where the only way to "just think about the spec" was
  to chain `/e22-spec-scaffold` + `/e22-questions` while dodging `/e22-build`.
- **New skill `/e22-tracker-sync` — GitHub Issues pull/push for the `/spec`
  spine.** Removes the manual copy-paste at the tracker boundary. **pull**
  materializes issues as the one-file-per-issue markdown export `/e22-drift`
  consumes (and can import a ticket's acceptance criteria into an `intent.md`);
  **push** files the `spec-drift` issues `/e22-drift` previously only *described*,
  promotes `## Open questions` to issues (swapping in the ref), and opens
  feature-request issues from an approved intent. Integration is **MCP-first**
  (the GitHub MCP server already shipped in `scaffold/mcp.json`), falling back to
  the **`gh` CLI**, then to **manual export** — and it stays a GitHub-only
  accelerator: a non-GitHub tracker (Jira/Linear/…) keeps the manual export path.
  Pushes are idempotent and confirmed once before creating. It moves *pointers
  and findings*, never the spec itself — `/spec` remains the source of truth.
- **Wiring.** `/e22-drift` now offers `/e22-tracker-sync pull` instead of pasting
  (GitHub trackers) and hands its findings to `push`; `/e22-questions` delegates
  question-promotion to `push`; rule `35-issue-tracker` notes the accelerator;
  the router (`00-router`) lists both new skills. Both ship `/slash` aliases.

### 1.36.0

- **`/e22-questions` resolves settled answers in the same change instead of
  asking per item.** The skill folded *every* answer back into the spec only on
  an explicit yes — including code-facts it had just grounded from the code and
  decisions the human had already made in the session — so a sweep stalled on a
  string of "shall I apply this?" confirmations for edits that decided nothing
  new. Step 6 is now tiered: an answer that **makes no new decision** (a
  code-fact, or a decision already made) is applied in the same change — along
  with the docs that must stay consistent with it, like a `CLAUDE.md` one-liner
  or a superseding ADR — with the **PR as the gate**; only a **genuine unmade
  decision** (product/policy/architecture, or anything high-risk) is routed for
  a yes, and an unanswerable one still stays open rather than being guessed.
- **New org rule: *applying a decision already made is not a new decision*
  (`32-living-docs`).** Propagating a settled choice into the artifacts that
  should reflect it is living-docs upkeep — make the edit in the same change and
  let the PR (rule `95-not-the-gate`) be the gate. Pausing for a yes is reserved
  for an *unmade* decision, a high-risk area, or an edit that would clobber
  filled-in content. The read-only audits (`/e22-drift`, `/e22-audit`) and the
  anti-clobber sweeps (`/e22-sync`, `/e22-tidy`) are unchanged.

### 1.35.1

- **`/e22-questions` now reliably retires a legacy `SPEC-QUESTIONS.md`.** The
  skill already intended to migrate the retired standalone file into the spine
  and delete it before sweeping, but the instruction was weak enough that a run
  could treat `SPEC-QUESTIONS.md` as a live working store — answering questions
  in place and deferring the file's retirement to "a later step," leaving it on
  disk. Step 1 is now a hard gate: migration and deletion happen together,
  unconditionally, before any answering; keeping the file alive (updating it in
  place, parking resolved/deferred items in it, or deferring retirement) is
  explicitly forbidden. Added a "Done when" backstop: a run that leaves the
  legacy file behind is not done.

### 1.35.0

- **New `/e22-sync` skill — carry an already-bootstrapped repo forward to the
  current plugin.** `/plugin update` refreshes the plugin, but the `/spec` spine
  and bundled scaffold a repo *materialized* at bootstrap stay frozen at the
  version that wrote them. `/e22-sync` closes that gap: it applies pending
  structural migrations, runs the additive Template reconciliation across the
  materialized spine + scaffold, and re-stamps the spine version — read-then-
  propose, never clobbers, lands a `feat/*` PR. It is the
  repo-structure-vs-plugin-conventions axis, distinct from `/e22-drift`
  (spec-vs-tracker) and `/e22-audit` (code-vs-standards). Has a `/e22-sync`
  command alias.
- **Spec-spine version stamp (`/spec/.version`).** `/e22-init` and `/e22-adopt`
  now write the plugin version they bootstrapped at; `/e22-sync` reads it,
  applies migrations newer than it, and re-stamps. Resolved from `plugin.json`,
  never memory.
- **Migration ledger (`templates/reference/MIGRATIONS.md`).** Single source of
  truth for **non-additive** structural changes (renames/moves/deletions) the
  purely-additive Template reconciliation can't express. Each entry is keyed by
  introducing version and is idempotent + self-detecting (precondition + action).
  Seeded with the v1.22.0 `PRODUCTION-READINESS.md` → `PRODUCTIONIZATION.md`
  rename, which `/e22-adopt` previously hard-coded inline; adopt and build now
  delegate to the ledger so future renames need no skill edits. The
  spec-framework reconciliation convention documents the additive-vs-structural
  split and the stamp.

### 1.34.0

- **The plugin replaces `repository-template` as the bootstrap source.** The
  full repo scaffold is now **bundled** at `templates/scaffold/` (mise.toml +
  standard tasks, compose.yaml, CI + `@claude` workflows, PR/issue templates,
  configs, `.env.example`, `.claude/settings.json`, editor config, infra
  conventions — dotfiles stored without the leading dot; `MANIFEST.md` carries
  the install map and per-file adapt notes). `/e22-init` Path B and
  `/e22-adopt` step 10 now instantiate from this bundle instead of fetching
  `element22llc/repository-template`; `/e22-init` Path A is reframed as the
  *legacy-fork* path and back-fills the new artifacts. The spec spine templates
  (`vision`, `users`, `glossary`, `design-source`) moved into `templates/spec/`
  alongside the per-feature ones. The starter app is deliberately **not**
  bundled — bootstrap scaffolds the real first app. README gains
  bootstrap-with-the-plugin + migration-from-the-template sections.
- **Living documentation is now an always-on rule (`32-living-docs.md`).**
  Claude's natural-language-to-spec role is explicit: the PO/dev speaks plainly;
  Claude routes each statement to its owning artifact *as the work happens*
  (intent/acceptance → `intent.md`, decisions/trade-offs → `contract.md`/ADR,
  ambiguity → `## Open questions` — never guessed, usage/roles/config →
  the app guide, what/why/who-asked → action history) in the same PR as the
  code, in the right register per audience (PO plain-language, dev precise).
- **New `/spec` artifacts, all template-backed (`templates/spec/`):**
  `/spec/HISTORY.md` (**action history** — append-only what/why/who-asked/refs
  log for auditability, onboarding, review evidence, and drift-over-time;
  `history.md`), `/spec/tracker.md` (**client-agnostic issue-tracker
  declaration** — Jira/GitHub Issues/Linear/Azure DevOps/other; `tracker.md`),
  and `/spec/app/README.md` (**app knowledge docs** — usage, workflows, roles &
  permissions, configuration, limitations, troubleshooting, runbook, release
  notes; `app-docs.md`). `feature-intent.md` gains a `> Tracker:` header line
  and tracker-agnostic issue-ref guidance. Layout rule and spec-framework
  structure updated to match.
- **Issue-tracker integration is an always-on rule (`35-issue-tracker.md`).**
  Only `/spec/tracker.md` knows which tracker is in use; specs/PRs/history
  write refs in its declared format. Tracker-item acceptance criteria are
  copied into the intent (repo stands alone; ref points back); untracked
  questions live in `## Open questions` and are promoted to tracker items when
  they need scheduling.
- **Pre-merge drift gates (`55-drift-gates.md`) + PR-template checklist.**
  Eight review-sensitive classes — intent drift, contract drift, undocumented
  behavior change, security-sensitive, compliance-impacting, operational,
  local-setup/deployment, app-docs invalidation — must be flagged in the PR
  when noticed and block merge until the human reviewer explicitly resolves
  them (Claude may not waive its own flag). The scaffold's PR template carries
  the checklist plus a living-docs sync section; Definition of Done and the
  end-of-session checklist gain matching items.
- **Audit-aligned delivery rule (`75-compliance.md`).** The workflow is SOC 2 /
  ISO 27001-**aligned** — explicitly *not* a compliance claim — mapping the
  artifacts to traceability, review evidence, change history, access-conscious
  defaults, and human accountability (PO approves intent; dev approves the PR;
  humans own production readiness).
- **New `/e22-traceability` skill + `templates/reference/TRACEABILITY.md`.**
  The full prose behind the four new lean rules: the NL→artifact routing
  table, extraction discipline, PO-facing vs dev-facing register split, action
  history format, app-docs conventions, the tracker adapter table, drift-gate
  mechanics, the SOC 2 / ISO 27001 expectation→artifact evidence map, and
  worked PO-day/dev-day examples. Registered in the router; the `e22-standards`
  loader skill's rule list updated (17 → 21 files).
- **`/e22-build` bootstraps and documents like the rest of the flow.** Step 1
  now covers the no-scaffold case (plugin-driven bootstrap, PO-adapted), and
  handoff seeds the app guide from the demo-validated intents and appends the
  build to `/spec/HISTORY.md`. `check-unmanaged-repo.sh`'s nudge names the
  bundled scaffold and the living-docs spine.

### 1.33.0

- **New `/e22-audit` skill — a repeatable, read-only, whole-repo health audit.**
  Until now the standards had a one-time onboarding triage (`/e22-adopt`), a
  spec-vs-spec conformance check (`/e22-drift`), and diff-scoped reviews
  (`/code-review`, `/security-review`, `/simplify`) — but nothing that sweeps an
  already-adopted, steady-state repo across the standards dimensions and returns a
  **leverage-ranked** cleanup backlog. `/e22-audit` fills that gap. It audits nine
  dimensions anchored to the E22 baseline (spec coverage, architecture &
  boundaries, data layer, input validation & config, error handling & escape
  hatches, testing, toolchain & dependency health, design consistency, DX & docs),
  **vets** every candidate finding against the cited `path:line` (subagents
  over-report), ranks survivors by leverage (impact ÷ effort × confidence), and
  routes results into the existing flow: `audit` issues for code-health findings,
  `/e22-adr` for architectural calls, `## Open questions` for spec gaps. It is
  **read-only** — no code/spec edits, no commit — and **defers** correctness to
  `/code-review`, security to `/security-review`, and mechanical cleanup to
  `/simplify` rather than re-implementing them. Invokable as `/e22-audit` (command
  alias) or the `e22-audit` skill.

### 1.32.0

- **UI craft now comes from Anthropic's `frontend-design`, re-listed not
  re-authored.** Until now nothing in the standards guided *aesthetic* UI
  quality when there was no design export — Claude fell back to generic AI
  defaults. Rather than maintain our own design skill, the marketplace now
  re-lists Anthropic's official `frontend-design` plugin via a `git-subdir`
  source pinned to a SHA (`/plugin install frontend-design@e22-plugins`; bump
  the SHA to update). We carry a pointer, not the prose — zero duplicated
  content.
- **Design-source guidance reweighted toward the common case: no / partial
  export.** Rule `90-design-sources.md` and `DESIGN-SOURCES.md` previously led
  with "features originate from a Claude Design export" and framed the export as
  authoritative. Most features have **no export, or only a partial one**, so the
  guidance now leads there: build the UI deliberately with `frontend-design`
  (scoped to a professional/enterprise default, the standard Next + TS + Tailwind
  stack, and accessibility), defer to a committed export only for the screens it
  actually covers, and anchor product-wide uniformity in `DESIGN.md`.
- **`DESIGN.md` gains a third origin — "established while building without an
  export."** Joins "distilled from an export" and "reverse-engineered by
  `/e22-adopt`": when there is nothing to distill, `DESIGN.md` *is* the record of
  the design decisions made while building, seeded from the first feature and
  grown as patterns recur — the thing that stops an export-less product drifting
  into differently-styled screens. The `/e22-design-sources` skill summary and
  the reference's new "Building UI without a (full) export" section spell out the
  workflow.

### 1.31.0

- **`/e22-adopt` now captures the as-built design, not just the spec.** Adoption
  reverse-engineered `/spec`, ADRs, and a productionization brief from a
  vibe-coded app's code — but never the **design**, so an adopted repo had no
  `DESIGN.md` to iterate on (the scaffolding sync didn't even pull in the
  template's stub). A new **step 7, "Capture the as-built design,"** reverse-
  engineers a root `DESIGN.md` from the running UI — the Tailwind theme, CSS
  custom properties, fonts, the palette/spacing/radius scales in use, and
  recurring component styling — written in the `@google/design.md` format and
  linted, under the same "as-built, dev-confirms, never invent" discipline as
  the spec extraction. **Crucially, a Claude Design export is no longer a
  prerequisite** — the code itself is the source. The step is skipped (and noted
  in `PRODUCTIONIZATION.md`) for backend-only repos with no UI surface, and the
  scaffolding-sync step (now step 10) is told never to overwrite a captured
  `DESIGN.md` with the template stub. Old steps 7–11 shift to 8–12.
- **`DESIGN.md` framing decoupled from exports.** `DESIGN-SOURCES.md` now states
  `DESIGN.md` has two legitimate origins — distilled from a design export
  (Greenfield/feature) **or** reverse-engineered from the as-built UI
  (Brownfield `/e22-adopt`) — so the file is no longer presented as something
  that only exists when a design export does.

### 1.30.0

- **`/e22-questions` no longer balloons into a costly codebase sweep.** The skill
  was cheap by design (grep the `## Open questions` sections, ask a human), but it
  had a blind spot: in an `/e22-adopt`-reverse-engineered spec, most open
  questions are *factual* — "is `X` dead code?", "does the client or server
  enforce this?", "what roles exist?" — not decisions. With no guidance on that
  class, a model correctly refuses to ask the PO/dev what their own code does and
  investigates instead — reaching for the most expensive tool available (one
  Explore agent per subsystem). One real run fanned out 4 agents and burned
  ~350k tokens to answer questions a handful of greps would settle. The skill now
  closes the gap with an explicit **triage step (step 4)**: split the worklist
  into **code-fact** (ground by targeted inline reads of the named file/symbol,
  batched, proposed as dev-sign-off) vs **human-decision** (route to PO/dev as
  before). A hard cost guardrail forbids per-question / per-subsystem
  investigation fan-out — at most one bounded subagent for the *entire* batch, and
  only when a broad cross-file search genuinely can't be done inline. Questions
  too costly to ground are left open and flagged rather than swept.
- **Leaner gather.** Step 2 now treats the grep's `-A20` window as sufficient
  context and tells the skill not to read each owning file wholesale — open a file
  only for a bullet the grep didn't capture, and only its `## Open questions`
  section.
- **Aligned the "never guess" contract.** The intro and step 8 now distinguish
  *inventing a decision* (still forbidden) from *grounding a code-fact in the
  actual code* (the cheap, correct move), so the read-then-propose guarantee no
  longer reads as "never look at the code."
- Updated `skills/e22-questions/SKILL.md`.

### 1.29.1

- **Fix: `/e22-drift` skill frontmatter failed to parse, breaking the whole
  plugin.** The `e22-drift` `SKILL.md` description was an unquoted YAML plain
  scalar containing `Read-only: ` — the colon-space made the parser treat it as
  a nested mapping key and silently drop all frontmatter, so `claude plugin
  validate` errored and the loader rejected the plugin (every skill/command,
  e.g. `/e22-questions`, showed as "command not found"). Wrapped the description
  in double quotes. Guard for the future: any skill/command `description:`
  containing `: ` (colon-space), `#`, leading `[`/`{`/`*`/`&`, or a leading
  quote must be quoted.

### 1.29.0

- **`/e22-questions` now auto-heals a retired `SPEC-QUESTIONS.md`.** The
  standalone file was retired in 1.25.0 (questions moved into `## Open questions`
  sections next to their context), but a repo forked from a pre-1.25.0
  `repository-template` still carried `spec/SPEC-QUESTIONS.md` on disk — and a
  fresh greenfield build dutifully *filled the stub it found*, re-introducing the
  retired artifact. The skill no longer just *avoids* the file, it migrates it: a
  new **step 1** detects `spec/SPEC-QUESTIONS.md`, routes each `## Open` item to
  its context (feature-specific → that feature's `intent.md` → `## Open
  questions`; product-level → `vision.md` → `## Open questions`), folds any
  `## Resolved` decision into the owning spec if not already captured, then — on a
  yes — deletes the stray file. It's a **move, not an answer**: nothing is
  invented or resolved during migration, preserving the skill's read-then-propose
  contract.
- **SessionStart nudge surfaces the legacy file.** `check-open-questions.sh`
  counts `## Open questions` items, which never matched the legacy file's `##
  Open` section — so a repo carrying only `SPEC-QUESTIONS.md` got no nudge and the
  heal was never triggered. The hook now also fires when `spec/SPEC-QUESTIONS.md`
  exists (independent of the open-question count), pointing at `/e22-questions` to
  migrate it. Fail-soft, still silent once the file is gone, composes with the
  existing open-question notice. Companion fix in `repository-template` removes
  the stub from the template's spine and adds `## Open questions` to its
  `vision.md`, so new forks no longer ship it.
- Updated `skills/e22-questions/SKILL.md` and `hooks/check-open-questions.sh`.

### 1.28.0

- **`/e22-drift` verdicts are now status-aware, and `🟠 Partial` is a first-class
  verdict.** A drift run against a tracker whose work is mostly open would
  previously flatten every unbuilt unit to `🔴 Missing` with no way to tell a real
  conformance failure from normal backlog — and reviewers smuggled in ad-hoc
  compound verdicts ("Partial / Missing") at epic grain to cope with mixed
  acceptance criteria. Both are now codified:
  - **Tracker status gates Missing.** Phase 1 captures each unit's status
    (Backlog / To Do / In Progress / Done / …). In Phase 2, **Done-but-Missing =
    true drift / defect** (the priority signal of the audit) while
    **Backlog/To-Do-but-Missing = unbuilt roadmap, expected, not drift** — the
    latter no longer generates `spec-drift` issues. The report leads with the
    real-drift findings so expected-Missing volume can't bury them.
  - **New `🟠 Partial` verdict** for a single unit whose acceptance criteria are
    split (some met, some Missing/Diverged), naming which criteria fall on each
    side. Verdicts are assigned **per unit, not per epic** — an epic is a rollup
    reported as a *verdict spread*, never collapsed to one cell or a compound.
  - **Verdict emoji denotes *kind*, not *severity*** — don't reuse `🔴` to mark a
    "critical" Diverged finding (it collides with Missing); carry severity in a
    separate marker.
  - Coverage table gains a **tracker-status column** so Done-but-Missing reads
    differently from Backlog-but-Missing at a glance.
  - Updated `skills/e22-drift/SKILL.md` only (no `commands/` alias change).

### 1.27.0

- **`/e22-drift` is now a spec-vs-spec diff that *consumes* `/e22-adopt`, not its
  inverse.** 1.24.0 framed drift as "the inverse of `/e22-adopt`" — a spec
  already exists, audit the code against it — and had it compare **code** against
  the `/spec` spine **plus a batch of source tickets**. That's the wrong axis for
  the actual workflow: run `/e22-adopt` to reverse-engineer the **as-built spec**
  from the code (a faithful picture of what the product *does*), then compare that
  as-built spec against the **tracker spec** (what it was *supposed* to do,
  exported as markdown from whatever issue tracker the team uses). Adopt and drift
  are **sequential stages of one flow**, not opposites — drift consumes adopt's
  output. Reworked:
  - **New comparison axis: as-built `/spec` ↔ tracker spec** (pure spec-vs-spec).
    The as-built spec stands in for the code (its `contract.md` sections were
    derived from the real code and carry the `path:line` pointers), so drift cites
    that evidence rather than re-auditing code from scratch.
  - **Tracker-agnostic markdown export is a first-class input, decomposed by
    grain.** The intended spec is exported from any issue tracker — **Jira,
    Linear, GitHub Issues, …** — as markdown; the skill never hardcodes one
    vendor. Phase 1 parses the export — **one file per epic/issue or per
    story/task** — fanning a coarse-grained file out into its constituent
    sub-items + acceptance criteria, normalizing each to an intended-behavior unit
    (tracker key/title kept for traceability).
  - **New verdicts** matched to the spec-vs-spec direction (as-built = reality,
    tracker = intent): ✅ Matches / ⚠️ Diverged / 🔴 Missing (tracker asked, not built) /
    🟡 Unspecified (built, never asked) / ❓ Ambiguous — replacing the old
    Conforms/Drifted/Missing/Extra/Ambiguous code-audit verdicts.
  - **Guard: redirect to `/e22-adopt` when there's no `/spec` spine** — there's no
    as-built spec to diff against until the code has been reverse-engineered.
  - Still **report + propose only** — no code/spec edits, Rule-5 resolution per
    finding (PO vs dev approval noted), `spec-drift` issues for decisions,
    ambiguities to `## Open questions` for `/e22-questions`.
  - Updated `skills/e22-drift/SKILL.md`, the `commands/e22-drift.md` alias, and the
    router (`rules/00-router.md`). The 1.24.0 entry below is left intact as a
    record of what shipped then; this entry supersedes its framing.

### 1.26.0

- **Detect greenfield repos that have no spec spine — push the bootstrap.** A
  brand-new repo with the plugin enabled but no `/spec` (code written from
  scratch with the standards active, but never forked from the template) fell
  through every existing path: the always-on rules were injected, but nothing
  *pushed* the spec-first bootstrap, so sessions silently degraded to toolchain
  conventions only — feature code written ahead of any vision/intent/contract.
  New `hooks/check-unmanaged-repo.sh` (SessionStart) fires when there's no
  `/spec` spine, presenting both bootstrap routes (greenfield `/e22-init` vs
  reverse-engineering `/e22-adopt`) rather than guessing from code volume.
  Fail-soft, silent once `/spec` exists (self-clearing), and silent in the
  plugin's own repo (`.claude-plugin/` guard). Registered after
  `check-open-questions.sh` in `hooks/hooks.json`.
- **Point-of-action nudge when source code is written ahead of a spec.** The
  SessionStart flag fires once, at startup — but a repo that's empty at startup
  can grow its first feature code mid-session, after the banner. New
  `hooks/check-code-before-spec.sh` (PreToolUse, `Write|Edit|MultiEdit`)
  re-asserts spec-first at the moment it's about to be broken: the first write
  of real source code (extension allowlist) into a repo with no `/spec` spine.
  **Non-blocking** — emits `hookSpecificOutput.additionalContext` and exits 0,
  so the write proceeds and the model just sees the reminder — and fires **at
  most once per session+repo** (marker in `TMPDIR` keyed by `session_id` + cwd),
  so it nudges without nagging. Exempts docs/config/scaffolding and anything
  under `spec/` or `.claude/` (writing those is bootstrapping), and is silent
  once `/spec` exists or in the plugin's own repo.
- **Generalized `/e22-init` to cover non-template greenfield, not just forks.**
  `e22-init` previously bailed the moment it found no placeholders — leaving a
  from-scratch non-template repo with no working bootstrap path (the route the
  new hook points greenfield repos at). It's now a two-path skill: **Path A**
  (fresh template fork — the existing placeholder-resolution flow) and **Path B**
  (non-template greenfield — bring the spine + scaffolding in from
  `repository-template`, interview to fill `vision`/`users`/`glossary`, record
  the initial stack as the first ADR, pin the toolchain, then proceed
  spec-first). Repos with substantial pre-existing code still redirect to
  `/e22-adopt`. Updated the skill description, the `commands/e22-init.md` alias,
  and the router (`rules/00-router.md`) accordingly.

### 1.25.0

- **New `/e22-questions` skill — stop open questions from rotting.** Open
  questions were written down once, gated at PO acceptance, then forgotten,
  spread across per-feature `intent.md` sections and a free-floating
  `SPEC-QUESTIONS.md`. The new skill sweeps every open question across the
  `/spec` spine and walks the PO/dev through answering each (read-then-propose:
  it never guesses an answer or edits without a yes), folding each decision back
  into the spec or recording an explicit deferral. Added a `commands/e22-questions.md`
  alias and registered the skill in the router (`rules/00-router.md`) and
  spec-workflow (`rules/30-spec-workflow.md`) rules.
- **SessionStart nudge so questions can't rot silently.** A new
  `hooks/check-open-questions.sh` counts outstanding open questions across
  `vision.md`, every feature's `intent.md`, and `PRODUCTIONIZATION.md` (scoped to
  the `## Open questions` section, skipping resolved `- [x]` items and the
  template's placeholder seed) and surfaces the backlog every session, pointing
  at `/e22-questions`. Fail-soft and silent when there are none — the notice
  clears itself once questions are answered or explicitly deferred.
- **Retired `SPEC-QUESTIONS.md`; questions now live next to their context.**
  Per-feature questions live in that feature's `intent.md` → `## Open questions`;
  product-level questions (greenfield vision interview, whole-repo adoption) live
  in a new `vision.md` → `## Open questions` convention. Rerouted all references
  across rules 30/60/90, the spec-framework and design-sources references, the
  `productionization.md` template, and the `e22-spec-scaffold`, `e22-design-sources`,
  `e22-drift`, `e22-build`, and `e22-adopt` skills.

### 1.24.1

- **Fix documentation drift in the `e22-standards` loader skill.** The on-demand
  loader (`skills/e22-standards/SKILL.md`, used on Cowork/desktop where the
  SessionStart hook does not fire) had two stale spots: its enumerated rule list
  omitted `22-housekeeping`, and its version-confirmation example hardcoded an
  old version string. Added `22-housekeeping` to the list (now matches all 17
  `rules/` files) and made the example placeholder-based (`vX.Y.Z`) so it can't
  drift again — the real version is still read from `plugin.json` at runtime. No
  behavior change.

### 1.24.0

- **New `/e22-drift` skill — audit the built app against its specs.** A manual,
  read-only conformance audit for the inverse of `/e22-adopt`: a spec exists and
  you want to confirm the code still matches it. The dev brings a batch of source
  tickets (pasted into the chat or pointed to a Jira export path); Phase 1
  reconciles those tickets against the `/spec` spine and flags spec gaps
  (proposed, not written); Phase 2 audits `/apps` + `/packages` against the spec
  plus the ticket behaviors, classifying each as Conforms / Drifted / Missing /
  Extra / Ambiguous with `path:line` evidence. Output is a drift report, a
  proposed Rule-5 resolution per finding (PO vs dev approval noted), and
  `spec-drift` issues for items needing a decision. **Report + propose only — it
  makes no code or spec edits and does not commit.** Discoverable via the router
  in `rules/00-router.md` and the `/e22-drift` command alias.

### 1.23.1

- **`/e22-adopt` resume migration: close the gap inside the skill, not just the
  command.** 1.23.0 fixed the command's resume *routing* but left the actual
  `git mv` reachable only via a fragile path: the migration line lived solely in
  `SKILL.md` step 2, while every salient resume gate in the skill keyed on the
  **new** `PRODUCTIONIZATION.md` — which is absent in a repo adopted under ≤1.21.0.
  The "## Resuming?" header (`If PRODUCTIONIZATION.md already exists…`) and step
  2's "if PRODUCTIONIZATION.md does not exist, this is a fresh adoption — skip
  ahead" gate both evaluated false/fresh against the old filename, so the agent
  could settle on the fresh-adoption branch and never reach the one buried line
  that migrates the old name. Now: the skill's resume header recognizes **either**
  filename; step 2 runs the `git mv` **before** the fresh-vs-resume decision and
  bases that decision on whether *neither* file existed; and the command inlines
  the literal `git mv spec/PRODUCTION-READINESS.md spec/PRODUCTIONIZATION.md` so
  migration no longer depends on the agent fully entering the skill.

### 1.23.0

- **`/e22-adopt` now actually migrates the old filename on resume.** The
  always-injected `commands/e22-adopt.md` recognized only the new
  `PRODUCTIONIZATION.md` on resume and inlined a "read it first and resume from
  its unchecked items" shortcut. For a repo adopted under ≤1.21.0 — i.e. every
  existing adoption, since the rename landed in 1.22.0 — the file on disk is
  still `PRODUCTION-READINESS.md`, so the resume branch didn't match and the
  agent improvised: it read the old file and summarized status without ever
  loading the skill or running its step-2 reconcile, so the `git mv` migration
  (which lives only in `SKILL.md`) never fired. The command now treats **either**
  filename as a resume, and routes to the skill's step-2 reconcile **first**
  rather than inlining a competing shortcut — closing the gap for every repo
  adopted before 1.22.0.

### 1.22.0

- **One readiness concept, named for what it is.** `PRODUCTION-READINESS.md` is
  renamed to **`PRODUCTIONIZATION.md`** — it's the dev's standing list of
  hardening *work*, not a go/no-go *judgment*, and "readiness" collided with the
  build flow's handoff gate. `/e22-adopt` migrates an existing
  `PRODUCTION-READINESS.md` to the new name on its next run (resume-safe), so
  already-adopted repos pick it up without losing filled-in content.
- **Productionization is now a decision, not just a to-do list.** The gap
  analysis gains a **disposition** per area — **Keep / Refactor / Rewrite /
  Reject** — plus an **Overall recommendation**. `/e22-adopt` proposes
  dispositions (the dev ratifies at PR review); when most areas trend
  Rewrite/Reject it recommends **rebuilding from the now-extracted `/spec`**
  rather than hardening a mess, and escalates a project-level Rewrite/Reject to
  an ADR (`/e22-adr`).
- **`/e22-build` now leaves the same durable brief.** A PO-built v0 writes
  `/spec/PRODUCTIONIZATION.md` at handoff (the same artifact `/e22-adopt`
  produces) instead of letting the gaps evaporate with the PR description. On a
  PO build the dispositions trend Keep/Refactor — there's no legacy to triage,
  only stubs to finish.
- **Renamed the build flow's `Handoff readiness` checklist to `Handoff gate`**
  in `BUILD-STATUS.md`, matching the reference and ending the "two readinesses"
  ambiguity.

### 1.21.0

- **Repo housekeeping: a `housekeeping` rule + the `/e22-tidy` skill.** A PO
  building from the template tends to commit a pile of source material at the
  repo root — vendor metadata spreadsheets, SQL/DDL dumps, architecture and flow
  decks, system inventories, PII/CMDB docs — and nothing in the standards gave
  those a home or told Claude to keep the root clean. The layout rule defined
  where *code* and *design exports* live, but the canonical `/spec` tree had no
  slot for the research inputs the spec is built from. Added:
  - New always-on `rules/22-housekeeping.md`: the root holds scaffolding + config
    only; loose source/research materials belong in `/spec/reference/` (diagrams
    in `/spec/design/`). When Claude notices root clutter it **proposes** moving
    it — never silently moves, never auto-deletes, flags junk and duplicates for
    confirmation first.
  - `/spec/reference` added to the layout rule as the home for source material.
  - New `e22-tidy` skill + `/e22-tidy` command and bundled
    `templates/reference/HOUSEKEEPING.md`: a sweep that lists root strays,
    classifies them against a destination taxonomy, and presents a plan table
    with a `move` / `rename + move` / `delete` action column for approval, then
    `git mv`s on a yes (so history follows). It **renames** cryptic or
    inconsistent filenames to clear ones as it moves them — a bad name is a
    reason to rename, not to bury or delete. A confusing or duplicate-looking
    name (`Copy of …`, `(002)`, case-variant pairs) is **not** treated as junk:
    those may be the important file, so the sweep **asks the PO/dev what the file
    is for and which version is current** before deciding, then moves + renames
    or (only on confirmation) deletes. Only true OS junk (`desktop.ini`,
    `.DS_Store`, `Thumbs.db`) is ever a deletion candidate, and even that waits
    for a yes — and when junk is deleted, its pattern is added to `.gitignore`
    (broad, tree-wide, only if absent) so it can't be re-committed and
    re-introduced later.

### 1.20.0

- **`practices` rule rephrased principle-first so it applies beyond the default
  stack.** The always-on patterns read as Next.js/Drizzle/Zod-only, which made
  them feel inapplicable on other stacks. Each bullet now leads with the general
  principle (parameterized query layer, validate input at the boundary,
  server-first, domain logic in shared modules) and names the default-stack
  instance in parens — keeping the opinion actionable on the default stack while
  stating the rule any stack must satisfy. No change to what is required; only
  how it is framed.

### 1.19.0

- **`/e22-adopt` stops waving raw SQL and missing schemas through as "clean."**
  A run was observed declaring a repo's data layer "verified clean" because its
  raw SQL was *parameterized* — and never flagging that the DB schema wasn't
  defined anywhere. Both are violations of the `practices` rule (data access
  through Drizzle/SQLAlchemy only; schema defined in code and migration-tracked).
  The misfire traced to ambiguous guidance: the anti-pattern list read "raw /
  string-interpolated SQL" (taken to mean only the *non*-parameterized case), and
  nothing prompted a data-layer check at all. Fixes:
  - The adopt skill's step-8 anti-pattern list now spells out that **raw SQL is
    a violation parameterized or not** (parameterization clears injection, not the
    ORM bypass), and that **a missing/untracked schema is a flagged gap, not an
    absence of findings** — with an explicit "don't mark data-layer practices
    clean without confirming ORM access *and* a migration-tracked schema."
  - Step 7's gap-analysis prompts and the `PRODUCTION-READINESS.md` template gain
    a dedicated **Data layer (ORM, schema, migrations)** dimension.
  - `CONVENTIONS.md` anti-patterns reframed: raw SQL is the anti-pattern
    regardless of injection safety, and "no schema defined at all" is called out
    alongside ad-hoc schema edits.

### 1.18.0

- **Cowork fallback: load the standards on demand where hooks don't fire.** Some
  POs work in Claude Cowork (the desktop app) instead of Claude Code. Plugins are
  cross-compatible and the skills/commands/templates work there unchanged, but
  Cowork runs the agent in a sandbox VM that currently ignores plugin hooks
  ([anthropics/claude-code#40495]) — so the `SessionStart` auto-injection of the
  always-on rules and the `PreToolUse` version-pin guard silently no-op, leaving
  a Cowork session with none of the org standards in context. New **`/e22-standards`**
  skill loads the same `rules/*.md` ruleset on demand; run it once at the start of
  a Cowork session. The router (`00-router.md`) and README now point to it, and
  the README documents the Cowork limitation. When #40495 ships, auto-injection
  works in Cowork with no plugin change and the skill becomes a harmless repeat.

[anthropics/claude-code#40495]: https://github.com/anthropics/claude-code/issues/40495

### 1.17.0

- **Host port bindings must be overridable, so concurrent products don't
  collide.** POs and devs routinely run several E22 products at once; any repo
  that hardcoded `"5432:5432"` in `compose.yaml` made the second `docker compose
  up` fail with `port is already allocated`. The stack rule (`10-stack.md`) and
  the Local services reference (`CONVENTIONS.md`) now require every published
  host port to bind through an env var defaulting to the canonical port —
  `"${POSTGRES_PORT:-5432}:5432"` — with the override variable listed in
  `.env.example`. A dev hitting a collision sets `POSTGRES_PORT=5433` in their
  git-ignored `.env` and mirrors it in `DATABASE_URL`; nothing else changes. The
  guidance notes that container/network/volume *names* need no such treatment —
  Compose namespaces those per project directory. The `repository-template`
  `compose.yaml` already follows the pattern for Postgres; a paired template
  change adds the `.env.example` documenting `POSTGRES_PORT` and `DATABASE_URL`.

### 1.16.0

- **Plugin freshness check at session start.** The always-on standards only help
  if the consumer is running a current copy, but nothing nudged anyone to
  `/plugin update`, so a repo could drift versions behind unnoticed. New
  SessionStart hook `hooks/check-plugin-updates.sh` compares the installed
  marketplace clone's `HEAD` against the remote default-branch tip and, when they
  differ, injects a notice naming the installed version and the two required
  steps: `/plugin update e22-standards@<marketplace>` to pull the new version,
  **then** `/clear` (or a fresh session) to reload — because the update only
  writes files to disk and the current session keeps running the already-injected
  (stale) rules until SessionStart re-fires.
  - Works against the **private** marketplace repo: it uses the clone's existing
    git auth via `git ls-remote` (a raw https fetch would 404), not an
    unauthenticated download.
  - Fail-soft and silent by construction — unknown install layout, no clone,
    offline, or any git error exits 0 with no output, and an up-to-date repo emits
    nothing. The network call is bounded (`ssh -o ConnectTimeout=4 -o BatchMode=yes`,
    `GIT_TERMINAL_PROMPT=0`) so it can never hang or prompt at session start.
  - Self-clearing: the notice disappears once `/plugin update` lands, the same
    self-healing shape as the template-drift hook.

### 1.15.0

- **Design exports are a spec to realize, not code to ship.** The design-sources
  standard previously told the model to *read* an export and treat it as
  authoritative for visual behavior/flow, but was silent on the delivery question:
  may you serve the prototype's runtime (UMD React + in-browser Babel + hand-rolled
  CSS) as the actual front-end? That silence let an ADR treat "serve the prototype
  as-is" as a peer to "rebuild in the stack." It is not — the delivery tech is
  disposable scaffolding; the durable artifact is the design itself.
  - `rules/90-design-sources.md` (always-on) now states the export is a **spec to
    realize in the standard stack, not code to ship**, and that serving the
    prototype runtime as a maintained surface is an **ADR-gated, kill-dated
    exception**, never the default.
  - `templates/reference/DESIGN-SOURCES.md` gains a **"Realizing the design vs.
    serving the prototype"** section with the decision rule (default: rebuild in
    Next.js + TS + Tailwind, no ADR needed; deviation: keep the prototype runtime
    only for genuine throwaways, ADR with a lifespan + named port trigger; never:
    untracked "temporary" hosting that becomes permanent). Notes that the
    rewrite-is-too-expensive objection has expired now that the port is a
    mechanical agent task with the prototype as the pixel-diff oracle.
  - The `e22-design-sources` skill summary gains a matching key-point bullet.

### 1.14.0

- **Template reconciliation is now enforced by a hook, not skill prose.** 1.12.0
  shipped the reconcile logic and 1.13.0 added a forcing-command + resume gate, but
  both lived in `SKILL.md` — advisory context the model reliably skipped when a spec
  file looked complete (it resumed "from the checklist" and never diffed). The fix
  moves detection out of the model's discretion: a new **SessionStart hook**
  (`hooks/check-template-drift.sh`) runs the heading diff deterministically at the
  start of every session and, when an instantiated file is behind the current
  bundled template, injects a high-salience notice naming the exact missing sections
  (e.g. `## Outdated dependencies & bad practices`). Same `additionalContext` path as
  the always-on rules, so it's unavoidable — and it stays **silent when there is no
  drift**, clearing itself once the files are reconciled.
  - Covers all instantiated files: `PRODUCTION-READINESS.md`, `BUILD-STATUS.md`, and
    every feature `intent.md` / `contract.md` under `spec/features/*/`.
  - POSIX sh, no jq, no process substitution (per repo conventions); headings are the
    drift signal (checklist-item diffing over-reports and would inject false
    positives). The skills' in-prose reconcile steps (1.13.0) remain as the
    how-to-splice guidance the notice points the model toward.

### 1.13.0

- **Self-healing reconciliation now actually fires on resume.** 1.12.0 shipped the
  reconcile logic but buried it mid-list, so the model resumed "from the checklist"
  and silently skipped it — a repo adopted under an older version still missed newly
  added sections (e.g. the `## Outdated dependencies & bad practices` gate). The fix
  replaces "remember to diff" with a **forcing function**: each template-copying skill
  now runs a concrete `comm -13` diff (bundled template vs. existing file, normalizing
  `[x]`→`[ ]`) as its **first action on resume**, and acts on the printed candidate
  list. The diff over-reports (filled-in placeholders, reworded items) by design — it
  is a candidate list that guarantees the comparison happens; splicing still applies
  the additive rules with judgment (never re-add a placeholder the dev filled).
  - **Shared convention** (`templates/reference/spec-framework.md` → *Template
    reconciliation*) now prescribes the forcing-command pattern and the "reconcile
    first, before status/next-steps" ordering rule.
  - **`/e22-adopt`** — new **Resume gate** before `## Steps`; step 2 embeds the diff
    command with imperative "run first" language; the competing "continue from
    unchecked items" framing in step 7 and the guardrail now defer to reconcile-first.
  - **`/e22-build`** and **`/e22-spec-scaffold`** — their resume/reconcile branches
    now carry the concrete diff command too.

### 1.12.0

- **Template self-healing, standardized plugin-wide.** Skills that copy a bundled
  template into the product repo now reconcile it against the current template on
  re-run instead of silently missing sections added by a later `/plugin update`.
  The convention is defined once in the shared reference
  (`templates/reference/spec-framework.md` → *Template reconciliation*) and
  applied by every instantiating skill: on a re-run they **splice in** the `##`
  sections, checklist items, and table rows the older template lacked — matched on
  stable anchors, left unchecked/empty, with every filled-in value preserved
  (purely additive; never overwrite, reorder, or delete).
  - **`/e22-adopt`** — new step 2 reconciles `/spec/PRODUCTION-READINESS.md`
    (so e.g. the 1.11.0 dependency-freshness section is picked up by repos adopted
    under 1.10.0). Steps 2–10 renumbered to 3–11; new "Resume is additive, never
    destructive" guardrail.
  - **`/e22-build`** — reconciles `/spec/BUILD-STATUS.md` on resume.
  - **`/e22-spec-scaffold`** — reconciles an existing feature's `intent.md` /
    `contract.md` instead of clobbering it (also fixes a latent overwrite-on-rerun
    risk).
  - **Exempt:** reference prose (read in place, always current via `/plugin
    update`) and **ADRs** (immutable point-in-time records — supersede, never
    retrofit a newer template into an accepted ADR).

### 1.11.0

- **`/e22-adopt` now flags outdated deps and bad practices.** Vibe-coded apps
  pin to whatever versions the generating model knew at *its* training cutoff —
  usually a major or two behind. New step 7 has the skill query the registry
  **live** (`npm view`, `uv pip index versions`, current Node LTS) — not from
  memory, which has the same cutoff problem — and record every major-behind /
  superseded dependency plus as-built anti-patterns (raw SQL, swallowed errors,
  `any`/`@ts-ignore`, unvalidated boundaries, `process.env` reads). New
  **Outdated dependencies & bad practices** section + `Dependency freshness`
  gap-analysis row in the `production-readiness.md` template; the dev owns the
  upgrade on a clean branch with tests green (propose, don't force).

### 1.10.0

- **New: adopt an existing non-template repo — `/e22-adopt`.** Until now the
  plugin assumed every repo was forked from `repository-template` (`/e22-init`
  only resolves placeholders in an already-scaffolded fork). The new skill
  covers the "vibe-coded" case — working code, but no `/spec`, no `mise.toml`,
  no plugin install — by reversing the Greenfield flow: survey the code,
  reverse-engineer `vision.md`/`users.md`/`glossary.md` (ask, don't invent),
  extract `intent.md` + `contract.md` per feature via `/e22-spec-scaffold`,
  capture as-built choices as ADRs via `/e22-adr`, then fetch
  `element22llc/repository-template` and sync in the scaffolding it lacks (mise
  tasks, `compose.yaml`, CI, `/configs`, `.env.example`, plugin install) —
  adapting to the existing stack, reconciling rather than replacing, and never
  clobbering working code. Ends in a `feat/e22-adopt` branch and a PR for dev
  review. (`skills/e22-adopt`, `commands/e22-adopt.md`)
- **New `/spec/PRODUCTION-READINESS.md` (bundled template).** The findings
  output of `/e22-adopt`: a gap analysis vs E22 standards (tests, lockfiles &
  pins, secrets, high-risk areas, CI, Zod/error model, layout) with a
  stop-and-rotate callout for any committed secret. Doubles as the resumable
  adoption checklist — a fresh session reads it first and continues from the
  unchecked items. (`templates/spec/production-readiness.md`)
- Router and spec-workflow rules point whole-repo adoption at `/e22-adopt`,
  distinct from a per-feature Brownfield change. (`rules/00-router.md`,
  `rules/30-spec-workflow.md`)

### 1.9.0

- **PO demo-validation gate before handoff.** `/e22-build` no longer proposes
  the handoff PR on its own judgment that the app is done — the Definition of
  Done is a precondition, never the trigger. New step 9: after the PO has
  actually used the running app and demo feedback is incorporated, the gate
  opens only on the PO's explicit "this does what I wanted" (asked plainly, or
  volunteered). Step 8 is now an explicit iterate-loop that may span many
  sessions. (`skills/e22-build`, `commands/e22-build.md`)
- **Build-flow state persists across sessions.** New `/spec/BUILD-STATUS.md`
  (bundled template), created at interview time and updated at every step
  transition: current step, per-feature progress, handoff-readiness checklist.
  A fresh session reads it and resumes from the recorded step instead of
  restarting the flow; the skill description now triggers on resuming too.
  (`templates/spec/build-status.md`, `skills/e22-build`,
  `templates/reference/spec-framework.md`)
- **Per-feature demo validation is traceable.** `feature-intent.md` gains a
  `validated` status (between `implemented` and `live`) and a
  **PO validated the working demo** acceptance checkbox, checked only on the
  PO's explicit confirmation. (`templates/spec/feature-intent.md`)
- Command alias cleanup: `commands/e22-build.md` guardrail wording aligned
  with the 1.8.0 pre-production relaxation (was still "high-risk areas
  stubbed and flagged").

### 1.8.0

- **Pre-production relaxation of the high-risk gates.** The gates exist to
  protect real systems and real data; while a product is **pre-production**
  (nothing deployed, no real users or data) high-risk areas may be built for
  real locally without prior dev scoping — document choices as you go
  (`contract.md`, ADRs, `/spec/SPEC-QUESTIONS.md`) and the dev PR review
  hardens them at productionization. Pre-production is a property of the
  *product, not the laptop* — local work in a deployed product gets no
  relaxation. Never relaxed: real secrets/credentials, `/infra`, deploys,
  real third-party calls. (`rules/60-high-risk.md`)
- **PO mode unblocked for exploration.** PO guardrails narrowed to the truly
  irreversible (deploy, `/infra`, real secrets/third-party accounts); a
  pre-production PO build may implement the data model, soft-delete with
  restore, and library-backed local sign-in for real. New principle: the PO
  owns data **semantics** (what exists, what "delete" means to a user); the
  dev confirms the **mechanics** (schema, cascades, retention) at review.
  (`rules/05-roles.md`, `skills/e22-build`)
- **Intent template captures data semantics.** New PO-facing **Key concepts &
  data** and **Lifecycle expectations** sections in `feature-intent.md` give
  data-model and deletion intent a structured home; `contract.md`'s Data model
  now derives from them and is marked `proposed — dev confirms at review`
  when drafted pre-production. `/e22-build` now interviews for deletion
  semantics explicitly (recoverable? how long? related items?).

### 1.7.0

- **Token slim: the always-on ruleset shrinks ~27%** (~20.4 KB → ~14.9 KB
  injected per session — roughly 1.4k tokens saved in *every* session of
  *every* product repo), following Anthropic's guidance that long always-on
  context both costs tokens and degrades rule adherence. No standard was
  dropped — prose moved behind the existing on-demand skills (progressive
  disclosure), keeping rules imperative and pointer-style per this repo's own
  `rules/` policy:
  - `10-stack.md` rewritten as lean bullets; backend-placement rationale and
    the local-services prose (compose-from-template, same-engine rule) moved to
    `CONVENTIONS.md` (new **Backend placement** and **Local services**
    sections). The `.env` bootstrap detail now lives only in the Secrets rule
    (it was duplicated across `10-stack.md` and `70-secrets.md`).
  - `85-practices.md` condensed to the E22-specific baseline (Drizzle-only,
    Zod boundaries, server-first, `packages/` for domain logic, nothing
    silenced, lockfile discipline); the full patterns/anti-patterns prose moved
    to `CONVENTIONS.md` (new **Baseline patterns & anti-patterns** section).
  - `30-spec-workflow.md` keeps the triggers; the 4-step Greenfield walkthrough
    moved to the spec-framework reference (new **Greenfield flow** section),
    which `/e22-build` now cites directly.
  - `15-commands.md` command block compacted; `00-router.md`, `20-layout.md`,
    `60-high-risk.md`, `70-secrets.md`, and `90-design-sources.md` tightened
    (duplication with Stack/Spec-workflow removed, pointer phrasing).
- **Skill descriptions trimmed ~35%.** All six SKILL.md frontmatter descriptions
  (loaded every session) cut to one-line what-it-does + when-to-use; the
  `/e22-conventions` summary now lists the new reference sections.

### 1.6.0

- **New: PO path — `/e22-build` skill + command.** Non-technical product
  owners can now go idea → auto-drafted spec → intent validation → working
  local app entirely in Claude Code. The skill is a thin driver over the
  existing Greenfield flow: PO-adapted first-run setup (Claude installs and
  runs mise/Docker/pnpm itself, asks the PO only product name + one-liner,
  keeps the default stack), interview → `vision.md`/`users.md`/`glossary.md`,
  intents via `/e22-spec-scaffold`, an explicit PO-acceptance gate before
  broad implementation, feature-by-feature build with `contract.md` + tests,
  local demo via `mise run dev:setup` + `pnpm dev`, and handoff as a PR whose
  description is the dev's productionization brief (PO-built v0, approved
  intents, stubbed high-risk items, open questions).
- **New always-on rule `05-roles.md` (PO vs dev).** Defines the two audiences
  and PO-mode behavior: plain language, spec-first, Claude drives the
  toolchain; guardrails — never deploy, never touch `/infra`, high-risk areas
  (auth, secrets, migrations, billing, deletion) stubbed minimally and flagged
  for a dev. Standards are never softened for a non-technical user, and the
  gate is unchanged: a PO-built app merges to `main` as v0 only after a dev
  approves the PR.
- **Spec framework broadened to both audiences.** Rule 1 and the lifecycle
  table now say specs are written with Claude's help by a dev *or* a PO via
  `/e22-build` (PO approves intent, dev approves the PR). Fixed structure-
  diagram drift: removed `/spec/README.md` and `/spec/_templates/`, which the
  template repo doesn't ship (templates are bundled in this plugin).
- README: dropped the hand-maintained Versions table (already stale at 1.0.0)
  in favor of `plugin.json` + this changelog.
- Pairs with `repository-template`: PO quickstart in the README, `/e22-build`
  in the `CLAUDE.md` fork note, broadened `spec/vision.md` header, and two
  fresh-fork CI fixes — (1) `pnpm install --frozen-lockfile` failed every
  fresh fork's first PR (`ERR_PNPM_NO_LOCKFILE`, the template deliberately
  ships no `pnpm-lock.yaml`); the install step now freezes only once a
  lockfile exists; (2) mise-action v4 auto-runs `mise install --locked` when
  a `mise.lock` exists, so the comment-only placeholder locks failed every
  tool with "not in the lockfile"; CI now drops placeholder locks (no
  `[[tools]]` entries) from the runner workspace before setup and installs
  the exact pins once `/e22-init` commits populated locks. Both fixes are
  self-correcting at lock adoption.

### 1.5.0

- **New: enforced version-pin verification.** The "default to current stable /
  don't trust training-data memory" rule was advisory only, and the failure
  mode is being *confidently* stale (e.g. a fresh app scaffolded with
  `postgres:16` when current stable is 18), so the "if unsure, ask" escape
  hatch never fired. A new `PreToolUse` hook
  (`hooks/check-version-pins.sh`) now denies Write/Edit/Bash calls that pin a
  stale major for common images (`postgres:`, `node:`, `python:`, `redis:`,
  `valkey:`, `nginx:`, `mysql:`, `mariadb:`, `mongo:`), with current stable
  resolved live from the endoflife.date API — the hook hardcodes no versions.
  Fails open offline; Markdown exempt; deliberate older pins pass with an ADR
  plus a same-line `# pin-ok: <reason>` marker. Documented in
  `CONVENTIONS.md` (Versioning policy → Enforcement).
- **Versioning policy reworded:** verification of current stable is now
  unconditional before writing any pin, instead of "if unsure, say so" —
  models are not unsure, they are confidently stale.
- New stack rule: **don't author `compose.yaml` from scratch** — start from
  the `repository-template` one and adapt, so generated services can't
  reintroduce stale image majors.
- **Fix: hooks no longer depend on the executable bit.** `hooks.json` now
  invokes both hook scripts via an explicit `sh` prefix; marketplace install
  does not chmod, so a missing `+x` could previously leave a session with no
  org standards injected at all.

### 1.4.0

- **Fix: toolchain pinning silently produced no lock.** mise only writes
  `mise.lock` when the file already exists, so the documented
  "`mise install` generates the lock" flow pinned nothing on a fresh fork.
  `CONVENTIONS.md` and `/e22-init` step 4 now document the caveat, require
  restoring a missing lock (`touch mise.lock` / `mise lock`) before installing,
  and require verifying the lock contains real `[[tools.*]]` entries before
  committing. Pairs with `repository-template`, which now ships committed
  placeholder `mise.lock` files (root and `infra/`).
- New org standard: **lockfile discipline** (always-on rule in the practices
  baseline + a `CONVENTIONS.md` section). `mise.lock`, `pnpm-lock.yaml`,
  `uv.lock`, `.terraform.lock.hcl` are committed and updated in the same change
  that touches their config/deps; never deleted or git-ignored to dodge an
  error; lockfile-only diffs get real review.
- New org standard: **mise backends must be cross-platform** (macOS + Linux).
  The registry default backend is not always usable everywhere — e.g. plain
  `pnpm` → `aqua:pnpm/pnpm` has no valid macOS asset, so repos pin `"npm:pnpm"`
  explicitly. Verify `mise install` works on both platforms when adding a tool.
- `/e22-init` step 5 now covers workspace lockfile adoption: the template ships
  no `pnpm-lock.yaml` on purpose (the starter's would go stale); generate and
  commit it (or `uv.lock`) once the real workspace exists.

### 1.3.0

- New org standard: **standard mise tasks**. Every repo exposes
  `mise run dev:setup` — the idempotent one-command local environment (Compose
  services up → `db:migrate` → `db:seed`) — plus `docker:up/down` and
  `db:migrate`/`db:seed`. Environment-orchestration tasks live in `mise.toml`
  (polyglot, owns tooling outside the workspace), not `package.json`, whose
  scripts stay app-level.
- Stack rule's Local-services bullet now names `mise run dev:setup` as the
  standard entry point and requires keeping it green as the stack evolves; the
  always-on commands cheat-sheet includes it in first-time setup.
- `CONVENTIONS.md` gains a "Standard mise tasks" section (the task vocabulary,
  the idempotency contract, and the mise-vs-package.json rationale), surfaced
  in the `/e22-conventions` skill summary.
- `/e22-init` gains step 6: adapt the template's baseline tasks to the product
  being built — real services in `compose.yaml`, real migrate/seed scripts,
  `uv run` instead of pnpm for Python products, or delete the docker/db tasks
  when there are no backing services.
- Pairs with `repository-template`, which now ships the baseline `[tasks]`
  block in `mise.toml` and a Postgres `compose.yaml` (host port overridable via
  `POSTGRES_PORT` so parallel products don't collide on 5432).

### 1.2.0

- New always-on rule **Commit autonomy** (`rules/45-commit-autonomy.md`): on a
  `feat/*`/`fix/*` branch, commit coherent units of work without asking the dev
  for permission — the PR review is the gate, not each commit. Never commit to
  `main` directly. When the work is judged complete (Definition of Done holds),
  proactively propose opening the PR and wait for the dev's confirmation before
  pushing/creating it.
- End-of-session checklist gains a matching item: all finished work committed,
  PR proposed if the change is complete.

### 1.1.0

- Local-dev `.env` bootstrap: the Stack and Secrets rules now require that when
  setting up or running an app locally, `.env` is created and populated with
  the base variables the app needs to boot — e.g. `DATABASE_URL` pointing at
  the local Compose PostgreSQL and freshly generated local-only secrets (auth
  secret, API tokens) — instead of leaving the dev to hand-assemble it from the
  README. Deployed/production secret values must never be copied into it.

### 1.0.0

- Initial release. Fresh start: replaces the earlier experimental 7-plugin
  three-zone marketplace (removed — preserved in git history) with a single
  `e22-standards` plugin mirroring the `repository-template` org standards.
- Always-on ruleset (`rules/*.md`) injected via a `SessionStart` hook: stack,
  layout, spec workflow, testing, Definition of Done, high-risk areas, secrets,
  change-size model, baseline patterns/anti-patterns, design-sources, and the
  end-of-session checklist.
- Skills: `e22-init`, `e22-spec-scaffold`, `e22-adr`, `e22-conventions`,
  `e22-design-sources`. Command: `/e22-init`.
- Bundled spec templates (`feature-intent`, `feature-contract`, `adr`) and full
  reference prose (`CONVENTIONS.md`, `DESIGN-SOURCES.md`, `spec-framework.md`).

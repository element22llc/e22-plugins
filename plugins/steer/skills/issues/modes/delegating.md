# `/steer:issues` — delegating modes (the owning skill does the thinking)

Read this file when running `brainstorm`, `materialize`, or any `publish-*` mode.
The guardrails, coupling rules, and the `## Recommended next actions` contract
stay in `SKILL.md` — they apply to every mode and are not repeated here.

## `brainstorm #N`

Product discovery against an issue, *without* writing a spec. Discovery
reasoning follows `/steer:spec`'s interview style; the issue body stays
human-owned. Required steps, in order:

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

## `materialize #N`

Turn approved product intent into a spec. Hand to `/steer:spec` to write/update
`spec/features/<id>/intent.md`, **set `Status: draft`** (never `approved` —
that's a later explicit `/steer:spec approve`), link the issue in `> Tracker:`,
run `/steer:spec validate` on the feature, and present the diff / open a PR.
Comment back on the issue with the exact spec path (as a clickable link —
`ISSUE-SCHEMA.md` → Clickable references) + commit/PR. **Features only** — an
epic has no `intent.md` and is **not materializable**; group features under an
epic with the `epic` mode instead.

## `publish-audit [report|triage-doc]`

Take an `/steer:audit` finding set and create/update the audit-run parent +
selected finding children (see `/steer:audit`); file via
`/steer:tracker-sync`. Selection comes from the session, **or from the audit
dashboard's filled triage export** (the
`<!-- steer:audit-triage sha=<audited-sha> -->` document —
rule `88-artifacts` return leg): file exactly the findings whose `finding-key`
is checked, carry each note into the issue body, and **flag any key that doesn't
match the current finding set** (stale or unknown — e.g. the code moved since
the audited SHA) instead of silently filing or dropping it. Same single
confirmation either way.

## `publish-drift [report]`

Take an `/steer:audit spec` finding set and file decision-checklist
`spec-drift` issues (see `/steer:audit spec`); never auto-resolve.

## `publish-adoption`

Reconcile selected `spec/PRODUCTIONIZATION.md` gaps into `kind=finding` +
`source:adoption` issues (stable `finding-key` per gap; **reconcile, don't
duplicate**). Findings are **deduplicated by remediation work-shape, not 1:1**
with sections/rows/bullets; the canonical **section → destination** map is the
brief's "What publishes, and where" note (architectural-choice *decisions* →
`/steer:adr` / `/steer:questions`, never findings; committed secrets → rotate;
the dependency table → **one** upgrade finding, not per package).

**Partial-publication safe:** flip the brief's `> Lifecycle:` to
`published-snapshot` **only after all intended findings are created or
reconciled**; on partial failure, **leave it `active-adoption`** and record the
successfully-published refs under `> Published findings:`. A rerun reconciles by
`finding-key` (never duplicates) and completes the flip once the set is whole.

After a clean flip, **`PRODUCTIONIZATION.md` is an adoption assessment snapshot
+ evidence source — the GitHub issue is canonical** for ownership, lifecycle,
progress, and closure; the report records the resulting issue ref but does not
independently track implementation status, and its checkboxes are a historical
snapshot, not active work.

## `publish-findings --source code-review|security-review`

File `kind=finding` issues with the matching `source:*` from a `/code-review` or
`/security-review` pass (stable `finding-key`; reconcile). **Security findings
support redaction / private handling** — never auto-publish secrets or
exploit-enabling detail into a broadly visible issue (link to private handling;
flag `risk:security`; default to human review before public disclosure).

## Priority floor — all `publish-*` modes

All `publish-*` modes **set the native Priority field to the derived floor on
creation** (the floor table in `ISSUE-SCHEMA.md` → *Native issue fields & the
Projects v2 compatibility boundary*) via
`/steer:tracker-sync field-set` — applied once at create time; a reconcile rerun
is escalate-only, so a human who later adjusts Priority is never overridden.

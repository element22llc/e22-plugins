---
name: audit
description: "Repeatable, read-only audits of a managed repo: `code` mode (default) sweeps the whole repo against the standards dimensions, ranks findings by leverage, and files them in the tracker; `spec` mode compares the as-built /spec against the intended spec from the tracker and surfaces drift; `all` runs both. Repository-read-only — proposes spec changes and files issues but never edits code/spec or commits; defers correctness to /code-review and security to /security-review."
when_to_use: Use to audit overall code health and find the highest-leverage improvements (code), to confirm the build matches what the tracker asked for (spec), or both (all) — a periodic standards-conformance pass on a steady-state repo.
argument-hint: "[code | spec | all]"
allowed-tools:
  - Bash(git status *)
  - Bash(git diff *)
  - Bash(git log *)
  - Bash(git show *)
  - Bash(git rev-parse *)
  - Bash(gh issue list *)
  - Bash(gh issue view *)
  - Bash(gh search issues *)
disallowed-tools: Edit, Write, NotebookEdit, EnterWorktree
---

<!-- steer:modes code,spec,all -->

# Audit a repo — code health and spec conformance (read-only)

> Native file-edit tools (`Edit`/`Write`/`NotebookEdit`) and worktree creation are
> unavailable while this skill runs, so neither audit can edit code or spec. This
> does not make the repo immutable — shell mutations stay governed by your
> permission settings and hooks. The optional report writes below (`AUDIT-REPORT.md`
> / `DRIFT-REPORT.md`) and the optional **Artifact dashboard** happen only after you
> confirm them (a fresh message), by which point the restriction has cleared — and
> the Artifact's only write is its HTML to a system temp dir, never under the repo
> tree (rule `88-artifacts`). Findings reach the tracker via
> `/steer:issues publish-audit` / `/steer:issues publish-drift`, each its own step.

Two **repeatable, read-only** audits behind one skill — pick the mode for the
question you're asking:

- **`code`** *(default — bare `/steer:audit`)* — whole-repo **code-vs-standards**
  health sweep: review the codebase across the standards dimensions, **vet**
  every candidate finding against the code it cites, rank survivors by
  **leverage**, **propose** routing into `/spec`, **file** findings in the
  tracker.
- **`spec`** — **spec-vs-spec** conformance: diff the **as-built `/spec`** (what
  the code actually does, reverse-engineered by `/steer:adopt`) against the
  **tracker spec** (what was asked for) and surface every divergence. The former
  `drift` skill.
- **`all`** — run `code` then `spec` and report both.

Both modes are **repository-read-only** — never an edit or a commit; their only
writes are tracker issues. They answer different questions ("is what we built
healthy and standards-aligned?" vs. "did we build what was asked?"), so run
`code` for tech-debt/health and `spec` for conformance. This is the steady-state
counterpart to one-time adoption: `/steer:adopt` builds the spec for a repo that
has none; `/steer:audit` runs again and again on a repo that already has one.

## `code` mode — health against the standards (leverage-ranked)

**Boundaries.** `code` mode is whole-repo, multi-dimension, and leverage-ranked
— it never re-runs the focused skills: correctness bugs defer to `/code-review`,
security to `/security-review`, mechanical cleanup to `/simplify` (name the
skill; don't run it here). A cluttered repo root is handed to `/steer:tidy`, not
reported stray-by-stray. **If there is no `/spec` spine yet,** the spec-coverage
dimension can't run — note that, redirect to `/steer:adopt` for the spec, and
run the code-health dimensions (2–9) without it.

### When to run

- Periodically (e.g. before a release, end of a milestone) as a standards pass.
- When a repo has accreted many small PRs and you want the highest-leverage
  cleanup backlog, ranked rather than ad-hoc.
- When a dev asks "where's the tech debt / what should we fix first?"

### Audit dimensions

Nine standards dimensions, anchored to the baseline (`rules/85-practices.md`,
Definition of Done, the high-risk rule) — **not** a generic checklist:
**1** spec conformance & coverage *(needs `/spec`)* · **2** architecture &
boundaries · **3** data layer · **4** input validation & config · **5** error
handling & escape hatches · **6** testing · **7** toolchain & dependency health
(incl. the branch-protection / solo-trunk graduation check) · **8** design
consistency *(UI repos only)* · **9** DX & docs. Skip any dimension that doesn't
apply to the repo and say so. The full catalogue — what each dimension looks for
— is [`AUDIT-DIMENSIONS.md`](../../templates/reference/AUDIT-DIMENSIONS.md);
load it before fanning out reviewers.

### Phase 0 — Recon

Detect the stack from the repo itself (`package.json` / `pyproject.toml`,
frameworks, database, auth) — don't trust training-data memory. Map the apps,
entry points, and user-facing features. Check whether a `/spec` spine exists; if
not, note it and mark dimension 1 as **not run — redirect to `/steer:adopt`**.
Decide which dimensions apply.

### Phase 1 — Audit

Run one reviewer per applicable dimension. Each finding must carry
**`path:line` evidence** — the file and line that demonstrate it — plus a
one-line statement of which standard it misses. No evidence, no finding.

**Fan out on large repos.** When the repo is large — roughly **5+ applicable
dimensions over more than ~200 source files**, or any sweep where reading every
dimension inline would crowd this context — delegate **each applicable dimension
to the `steer-reviewer` subagent** (one per dimension, explicitly, in parallel)
and gather their summaries. `steer-reviewer` is read-only by construction
(`Read`/`Grep`/`Glob` only), so the fan-out cannot edit code or spec. Below that
size, review the dimensions inline here — the coordination overhead isn't worth
it. Either way, the next phase vets everything the reviewers return.

### Phase 2 — Vet

Re-read the cited code for **every** candidate finding and drop:

- false positives (the cited line doesn't actually do what the finding claims),
- anything already conformant (the pattern is intentional and has a why-comment,
  or the standard doesn't apply here),
- duplicates across dimensions (collapse to one).

Subagents over-report — this stage is what makes the report trustworthy. A
finding that survives vetting states the standard missed, the evidence, and why
it's real.

### Phase 3 — Rank by leverage

Score each surviving finding by **leverage = impact ÷ effort × confidence**:

- **impact** — how much it reduces risk or future cost (a raw-SQL injection
  surface outranks a missing `mise` task).
- **effort** — rough size of the fix (one-line vs. a refactor).
- **confidence** — how sure the finding is real after vetting.

Order the report by leverage so the dev sees the highest-return work first.
Convey severity in its own marker (e.g. a `[blocker]`/`[high]` tag), independent
of dimension.

### Output — report + route only

1. **Ranked audit report.** Print it: a summary table (dimension → count →
   top finding), then a leverage-ordered findings list (finding + `path:line`
   evidence + standard missed + impact/effort/confidence + proposed routing).
   Note any dimension that was **skipped** (not applicable) or **not run** (no
   `/spec`) so silence never reads as "clean." Offer to also write it to
   `/spec/AUDIT-REPORT.md` on a `feat/audit` branch **only if the dev wants
   it tracked** — it's a point-in-time artifact, not part of the durable spine.

   **Optionally publish it as a shareable dashboard** — where the `Artifact` tool
   is available, **offer** a dimension-tiled findings dashboard (a Claude
   Artifact): every tile and card encodes a finding this run actually vetted,
   never an inflated count or a severity beyond the audit's evidence. On request
   it renders **fillable** as a triage form (file/leave checkbox + note per
   finding); the export is machine-keyed — each finding under its stable
   **`finding-key`**, beneath one `<!-- steer:audit-triage sha=<audited-sha> -->`
   marker (the audited SHA is fixed for the run) — with exactly one ingest route:
   **`/steer:issues publish-audit <triage-doc>`**. The write is post-confirmation,
   per the read-only note at the top, to the temp path
   `steer-audit-code-<short-sha>.html`; all rendering mechanics live in rule
   `88-artifacts` / `/steer:reference artifacts`.
2. **Route each finding** to where it belongs in the workflow:
   - **Code-health findings** → a **two-level** issue set, filed via
     **`/steer:issues publish-audit`** (which routes through `/steer:tracker-sync`):
     one **audit-run** parent (scope, plugin version, audited SHA, dimensions
     run/skipped, summary, report path) plus selected **finding** children —
     selected in-session or via the dashboard's filled triage export — each
     carrying a **stable `finding-key`** so re-runs *reconcile* (update/close)
     rather than pile up duplicates (see Reconciliation below).
     Bodies: `${CLAUDE_PLUGIN_ROOT}/templates/github/issue-bodies/audit-run.md`
     (parent run issue) and `${CLAUDE_PLUGIN_ROOT}/templates/github/issue-bodies/finding.md` (child findings).
     Scope children to genuine, high-leverage findings — don't file one per nit.
   - **Architectural / cross-cutting calls** → propose an ADR via `/steer:adr`.
   - **Spec coverage & conformance gaps** → a proposed `## Open questions` entry
     in the owning feature's `intent.md` (or `vision.md` if cross-cutting),
     drivable to answers by `/steer:questions`.
   - **Correctness / security / mechanical cleanup** → defer per the Boundaries
     note. To turn an unresolved `/code-review` or
     `/security-review` finding into a tracked issue, route it through
     **`/steer:issues publish-findings --source code-review|security-review`**
     (`kind=finding` + the matching `source:*`; security findings redact secrets
     / exploit detail and default to human review before public disclosure).
3. **Make no code or spec edits, and don't commit.** This mode stops at the
   report, the proposed routing, and (with a yes) opened issues + the optional
   `AUDIT-REPORT.md`. Fixing anything is a separate, approved step on its own
   branch + PR.
4. **Recommend the next action.** End with a `## Recommended next actions` block
   per `${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md` (categories,
   precedence, output format, read-only rule — auditing is repo-wide *by
   purpose*). **Assert no severity beyond the audit's evidence**: route *potential*
   concerns to the specialist that confirms them; only a *confirmed* exposure is a
   stop.

   | Audit observation | Action |
   |---|---|
   | Confirmed exposed secret found during inspection | Stop & rotate the value; then `/security-review` |
   | Potential security concern needing validation | Run `/security-review` |
   | Potential correctness defect needing diff analysis | Run `/code-review` |
   | Vetted code-health findings ready for tracking | `/steer:issues publish-audit` |
   | Architectural / cross-cutting call | Propose an ADR via `/steer:adr` |
   | Spec coverage / conformance gap | `/steer:questions` |
   | Suspected spec-vs-build drift | Run `/steer:audit spec` |
   | `main` unprotected / branch-protection drift (GitHub) — unless `CLAUDE.md` declares solo trunk mode, where it is intentional until graduation | `/steer:protect` |
   | Mechanical cleanup only | `/simplify` |
   | Nothing actionable | Complete |

   Choose one `Current recommended action` by precedence; the block recommends
   and never edits.

### Reconciliation across runs — audits are reconciling, not additive

Re-running the audit **updates the existing issue set**, never piles up
duplicates: each finding carries a stable **`finding-key`** (the conceptual
defect, never line-based) plus a separately-tracked **`evidence`** fingerprint,
so same-key findings refresh in place, vanished findings close (auto-close only
when deterministic; judgment calls need a human yes), false positives stay
closed, and each run's `audit-run` parent is immutable history. The canonical
full lifecycle — both identities, the per-finding transition rules, `audit-id`
immutability — lives in
[`ISSUE-WORKFLOW.md`](../../templates/reference/ISSUE-WORKFLOW.md) §"Audit &
drift"; `/steer:issues publish-audit` implements it (markers: `ISSUE-SCHEMA.md`).

## `spec` mode — as-built vs intended spec conformance

A **manual, read-only conformance audit.** It compares the **as-built spec**
(the `/spec` spine `/steer:adopt` reverse-engineered from the code — a faithful
description of what the product *actually does*) against the **tracker spec**
(what it was *supposed* to do, exported from the issue tracker as markdown) and
surfaces every place the two diverge. Its outputs are a drift report, a proposed
Rule-5 resolution per finding, and `spec-drift` issues (its only writes) for
anything needing a human decision. Resolving drift is a separate, approved step
(see the spec-framework reference, Rule 5).

**Boundaries.** `/steer:adopt` is the one-time bootstrap for an un-specced repo
— it reverse-engineers the as-built `/spec` from the code; the `spec` audit is
steady-state conformance that **consumes** that spine and diffs it against the
tracker intent. **If there is no `/spec` spine yet, stop and run `/steer:adopt`
first** — there is no as-built spec to compare against.

### When to run

- After landing a batch of work that spanned several epics/stories/issues, to
  confirm the build matches the combined intent.
- Periodically, to catch drift that accumulated across many small PRs.
- Before a release or handoff, as a conformance check against the tracker.

### Inputs

1. **The as-built `/spec` spine** — `features/*/intent.md` + `contract.md`,
   `decisions/*`, `vision.md`, `glossary.md`, as produced by a prior
   `/steer:adopt` run. This stands in for the code: its `contract.md` sections were
   *derived from the real code* and carry the `path:line` pointers. If it's
   absent, redirect to `/steer:adopt` and stop.
2. **The tracker spec export** — markdown files from any issue tracker (Jira,
   Linear, GitHub Issues, …), **one file per epic/issue or per story / task**. A
   coarse-grained file (epic, large issue) contains several sub-items with their
   own acceptance criteria; a story/task/sub-issue file is a single unit. The dev
   either **pastes them into the chat** or **points to a directory/path**. Ask
   which, if not given.

   **If the tracker is GitHub Issues, offer `/steer:tracker-sync pull` instead of
   pasting** — it materializes one markdown file per issue in exactly this shape
   (title, `#` key, labels, state, acceptance criteria) and hands the directory
   straight back here. For Jira/Linear/other, the paste/path export above stays
   the path.

### Phase 1 — Parse the tracker spec into intended-behavior units

The tracker export is the *intended* spec. Decompose it into comparable units.

1. **Read the export.** If pasted, use the chat text; if pointed to a path, read
   the markdown files there.
2. **Decompose each file by its grain.** A coarse-grained file (**epic**, large
   **issue**) fans out into its constituent stories/tasks/sub-issues, each with
   its acceptance criteria; a fine-grained file (**story / task / sub-issue**) is
   a single unit. Normalize each unit to a one-line *intended behavior* + its
   acceptance criteria, keeping the tracker key/title (e.g. `PROJ-123`, issue #)
   for traceability.
3. **Capture each unit's tracker status** (Backlog / To Do / In Progress / In
   Review / Done / …) alongside its key. Status is not cosmetic — it decides
   whether a "not built" finding is a *defect* or just *unbuilt roadmap* (see the
   status rule in Phase 2). A unit with no status is treated as unknown, not Done.
4. **Don't invent detail the tracker spec doesn't state** — where a unit is
   vague, flag it as Ambiguous rather than guessing what it meant.

### Phase 2 — Diff the as-built spec against the tracker spec

Map each intended-behavior unit to the as-built `/spec` feature
(`contract.md`/`intent.md`) that owns it, and classify the comparison. The
**as-built spec is reality** (it describes the code); the **tracker spec is
intent**. Cite the as-built evidence — the `contract.md` section and the
`path:line` pointer it already carries — never assert a match from the tracker
spec alone.

| Verdict | Meaning |
|---|---|
| ✅ **Matches** | The as-built spec captures the tracker-specified behavior. |
| ⚠️ **Diverged** | The as-built behavior differs from what the tracker spec asked for. |
| 🟠 **Partial** | The unit's acceptance criteria are split — some met by the as-built spec, others Missing or Diverged. Name which criteria fall on each side; don't let one verdict hide the gap. |
| 🔴 **Missing** | Tracker spec'd it, but the as-built spec (the code) has no such behavior — not built. |
| 🟡 **Unspecified** | As-built behavior with no backing tracker unit — built, but never asked for. |
| ❓ **Ambiguous** | One side too vague to judge; needs clarification. |

**Assign a verdict per unit, not per epic.** An epic is a *rollup* of units with
mixed verdicts — never collapse it to a single verdict (and never invent a
compound like "Partial / Missing" at epic grain). If you summarize at epic grain,
report the **verdict spread** across its child units; the single-verdict cell
belongs to the units. `🟠 Partial` is the one verdict that *is* legitimate for a
single unit — when that one story's acceptance criteria are themselves split.

**Status gates whether Missing is a defect or just roadmap.** A `🔴 Missing`
verdict means different things depending on the unit's tracker status (captured
in Phase 1). Map the issue `steer:state` to the spec `Status:` it should have via
the Status↔state crosswalk in `ISSUE-WORKFLOW.md`, then read the gate below:

- **Done (or no longer open) but Missing → true drift / defect.** The tracker
  says this shipped, yet the as-built spec has no such behavior. This is a real
  conformance failure and the priority signal of the audit.
- **Backlog / To Do / In Progress but Missing → unbuilt roadmap, expected, not
  drift.** The tracker hasn't claimed it exists yet. Report it as planned-not-yet-
  built, not as a failure — and don't file a `spec-drift` issue for it (it's
  normal backlog, belongs in feature speccing once any blocking decisions land).

Lead the report with the Done-but-Missing and Diverged findings; a tracker that
is mostly open work will be mostly expected-Missing, so don't let that volume
bury the few findings that are actual drift.

**The verdict emoji denotes *kind*, not *severity*.** Don't reuse `🔴` to flag a
"critical" Diverged finding — that collides with Missing. Convey severity in a
separate marker (e.g. a `[blocker]` tag or a severity column) so kind and
severity stay independent.

**Fan out on large comparisons.** This diff parallelizes cleanly — one reviewer
per feature. When the comparison is large (roughly **more than ~10 intended-behavior
units**, or any sweep where diffing every feature inline would crowd this context),
delegate **each feature's diff to the `steer-reviewer` subagent** (one per feature,
explicitly), handing it the intended-behavior unit, the as-built `/spec` feature
that owns it, and the verdict scale above; then gather the per-feature verdicts.
`steer-reviewer` is read-only by construction (`Read`/`Grep`/`Glob` only) — the
tracker pull stays here in the lead. Below that size, diff the features inline.

### Output — report + propose only

1. **Drift report.** Print it: a coverage table (tracker unit → **tracker status**
   → as-built feature → verdict), then a per-feature findings table (verdict +
   as-built evidence + one-line note). Include the status column so a reader can
   tell Done-but-Missing (defect) from Backlog-but-Missing (roadmap) at a glance.
   Offer to also write it to `/spec/DRIFT-REPORT.md` on a `feat/drift` branch
   **only if the dev wants it tracked** — it's a point-in-time artifact, not part
   of the durable spine.

   **Optionally publish it as a shareable drift board** — where the `Artifact`
   tool is available, **offer** a board of verdict-chipped cards (Done-but-Missing
   and Diverged first, tracker status preserved so defect-vs-roadmap reads at a
   glance): every chip is the verdict this run assigned, with its as-built
   evidence, and denotes *kind*, not severity. Unlike the code dashboard, the
   drift board is **never fillable**: each drift finding needs a per-finding human
   decision (its decision-checklist issue), not a bulk selection. The write is
   post-confirmation, per the read-only note at the top, to the temp path
   `steer-audit-drift-<short-sha>.html`; all rendering mechanics live in rule
   `88-artifacts` / `/steer:reference artifacts`.
2. **Proposed resolution per finding**, following Rule 5 (spec-framework
   reference): reconcile the divergence by changing the code to match the tracker
   intent, **or** updating the spec/tracker to match the as-built reality (when
   the build is right and the tracker spec is stale). Note which path needs **PO**
   approval (user-facing behavior changed) vs. **dev** approval
   (internal/architectural).
3. **Open `spec-drift`-labelled issues** for findings that need a human decision,
   so drift becomes a tracked item rather than a quiet failure. Scope these to
   *actual* drift — Diverged, Done-but-Missing, and genuine conflicts — **not**
   expected-Missing backlog (those are unbuilt roadmap, not a decision to track).
   Each issue uses the **decision-checklist** body
   (`${CLAUDE_PLUGIN_ROOT}/templates/github/issue-bodies/spec-drift.md`): *Spec
   says* / *Implementation does* / *Evidence* / *Human decision required* (the
   checklist). The agent may propose a direction but **never resolves behavioural
   drift autonomously** — a PO or dev decides by ownership. On a GitHub tracker,
   hand this finding set to **`/steer:issues publish-drift`** (which routes through
   `/steer:tracker-sync`) to file them — idempotent, confirmed once — rather than
   opening them ad hoc; for other trackers, propose the issues for the dev to
   file.
4. **Make no code or spec edits, and don't commit.** This mode stops at the
   report and proposals. Ambiguities go to a proposed `## Open questions` entry
   in the owning feature's `intent.md` (or `vision.md` if cross-cutting), not a
   guess — run `/steer:questions` to drive them to answers.
5. **Recommend the next action.** Close with a `## Recommended next actions` block
   per `${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md`, scoped to this
   drift run's findings (locality rule).

   | Observed state | Category | Action / suggested command |
   |---|---|---|
   | Behavioural drift needing a human call | Human decision required | PO/dev decides by ownership (no command) |
   | Drift findings not yet filed (GitHub) | Recommended | `/steer:issues publish-drift` |
   | Ambiguities surfaced | Required before next production release | Resolve them — `/steer:questions` |
   | No actual drift (only expected-Missing backlog) | Complete | `No action is currently required.` |

   Choose one `Current recommended action` by precedence. Read-only — proposes,
   never edits or commits.

## `all` mode — run both

Run `code` then `spec` in sequence and report both, each with its own ranked
report and routing. Use it for a full periodic pass (health **and** conformance)
before a release. If there is no `/spec` spine, `spec` can't run — say so and run
`code` only.

## Coupling rules

The canonical spec ↔ code rules — drift resolution (Rule 5), behavior vs.
incidental implementation, PO vs. dev approval, naming — live in
`${CLAUDE_PLUGIN_ROOT}/templates/reference/SPEC-FRAMEWORK.md`; the full
conventions and patterns behind the `code`-mode dimensions are in
`${CLAUDE_PLUGIN_ROOT}/templates/reference/CONVENTIONS.md` (open via
`/steer:reference conventions`). This skill *detects, ranks, and routes*; those references
govern how each finding gets *resolved*.

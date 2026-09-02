# `/steer-audit code` — health against the standards (leverage-ranked)

Read this file when running `code` mode (the default, bare `/steer-audit`) or
the `code` half of `all`. The read-only contract, polyrepo scope note, and
coupling rules stay in `SKILL.md` — they apply to both modes and are not
repeated here.

**Boundaries.** `code` mode is whole-repo, multi-dimension, and leverage-ranked
— it never re-runs the focused skills: correctness bugs defer to `/code-review`,
security to `/security-review`, mechanical cleanup to `/simplify` (name the
skill; don't run it here). A cluttered repo root is handed to `/steer-tidy`, not
reported stray-by-stray. **If there is no `/spec` spine yet,** the spec-coverage
dimension can't run — note that, redirect to `/steer-adopt` for the spec, and
run the code-health dimensions (2–10) without it.

## When to run

- Periodically (e.g. before a release, end of a milestone) as a standards pass.
- When a repo has accreted many small PRs and you want the highest-leverage
  cleanup backlog, ranked rather than ad-hoc.
- When a dev asks "where's the tech debt / what should we fix first?"

## Audit dimensions

Ten standards dimensions, anchored to the baseline (`rules/85-practices.md`,
Definition of Done, the high-risk rule) — **not** a generic checklist:
**1** spec conformance & coverage *(needs `/spec`)* · **2** architecture &
boundaries · **3** data layer · **4** input validation & config · **5** error
handling & escape hatches · **6** testing · **7** toolchain & dependency health
(incl. the branch-protection / solo-trunk graduation check) · **8** design
consistency *(UI repos only)* · **9** DX & docs · **10** comment noise (the
Code comments rule). Skip any dimension that doesn't
apply to the repo and say so. The full catalogue — what each dimension looks for
— is [`AUDIT-DIMENSIONS.md`](https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/templates/reference/AUDIT-DIMENSIONS.md);
load it before fanning out reviewers.

## Phase 0 — Recon

Detect the stack from the repo itself (`package.json` / `pyproject.toml`,
frameworks, database, auth) — don't trust training-data memory. Map the apps,
entry points, and user-facing features. Check whether a `/spec` spine exists; if
not, note it and mark dimension 1 as **not run — redirect to `/steer-adopt`**.
Decide which dimensions apply.

## Phase 1 — Audit

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

## Phase 2 — Vet

Re-read the cited code for **every** candidate finding and drop:

- false positives (the cited line doesn't actually do what the finding claims),
- anything already conformant (the pattern is intentional and has a why-comment,
  or the standard doesn't apply here),
- duplicates across dimensions (collapse to one).

Subagents over-report — this stage is what makes the report trustworthy. A
finding that survives vetting states the standard missed, the evidence, and why
it's real.

## Phase 3 — Rank by leverage

Score each surviving finding by **leverage = impact ÷ effort × confidence**:

- **impact** — how much it reduces risk or future cost (a raw-SQL injection
  surface outranks a missing `mise` task).
- **effort** — rough size of the fix (one-line vs. a refactor).
- **confidence** — how sure the finding is real after vetting.

Order the report by leverage so the dev sees the highest-return work first.
Convey severity in its own marker (e.g. a `[blocker]`/`[high]` tag), independent
of dimension.

## Output — report + route only

1. **Ranked audit report.** Print it: a summary table (dimension → count →
   top finding), then a leverage-ordered findings list (finding + `path:line`
   evidence + standard missed + impact/effort/confidence + proposed routing).
   Note any dimension that was **skipped** (not applicable) or **not run** (no
   `/spec`) so silence never reads as "clean." Offer to also write it to
   `/spec/AUDIT-REPORT.md` **only if the dev wants it tracked** — it's a
   point-in-time artifact, not part of the durable spine. Write it to the working
   tree only, and say plainly that committing it is the dev's next step.
   `EnterWorktree` is disallowed so this skill cannot open a worktree, but the git
   verbs are not blocked by the frontmatter — `allowed-tools` grants without
   restricting — so leaving the branch and the commit to the dev is a boundary
   this skill keeps, not one the tooling enforces.

   **Optionally publish it as a shareable dashboard** — where the `Artifact` tool
   is available, **offer** a dimension-tiled findings dashboard (a Claude
   Artifact): every tile and card encodes a finding this run actually vetted,
   never an inflated count or a severity beyond the audit's evidence. On request
   it renders **fillable** as a triage form (file/leave checkbox + note per
   finding); the export is machine-keyed — each finding under its stable
   **`finding-key`**, beneath one `<!-- steer:audit-triage sha=<audited-sha> -->`
   marker (the audited SHA is fixed for the run) — with exactly one ingest route:
   **`/steer-issues publish-audit <triage-doc>`**. The write is post-confirmation,
   per the read-only note in `SKILL.md`, to the temp path
   `steer-audit-code-<short-sha>.html`; all rendering mechanics live in rule
   `88-artifacts` / `/steer-reference artifacts`.
2. **Route each finding** to where it belongs in the workflow:
   - **Code-health findings** → a **two-level** issue set, filed via
     **`/steer-issues publish-audit`** (which routes through `/steer-tracker-sync`):
     one **audit-run** parent (scope, plugin version, audited SHA, dimensions
     run/skipped, summary, report path) plus selected **finding** children —
     selected in-session or via the dashboard's filled triage export — each
     carrying a **stable `finding-key`** so re-runs *reconcile* (update/close)
     rather than pile up duplicates (see Reconciliation below).
     Bodies: `https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/templates/github/issue-bodies/audit-run.md`
     (parent run issue) and `https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/templates/github/issue-bodies/finding.md` (child findings).
     Scope children to genuine, high-leverage findings — don't file one per nit.
   - **Architectural / cross-cutting calls** → propose an ADR via `/steer-adr`.
   - **Spec coverage & conformance gaps** → a proposed `## Open questions` entry
     in the owning feature's `intent.md` (or `vision.md` if cross-cutting),
     drivable to answers by `/steer-questions`.
   - **Correctness / security / mechanical cleanup** → defer per the Boundaries
     note. To turn an unresolved `/code-review` or
     `/security-review` finding into a tracked issue, route it through
     **`/steer-issues publish-findings --source code-review|security-review`**
     (`kind=finding` + the matching `source:*`; security findings redact secrets
     / exploit detail and default to human review before public disclosure).
3. **Make no code or spec edits, and don't commit.** This mode stops at the
   report, the proposed routing, and (with a yes) the optional `AUDIT-REPORT.md`.
   It opens **no issues itself** — filing is `/steer-issues publish-audit`, its own
   step. Fixing anything is a separate, approved step on its own branch + PR.
4. **Recommend the next action.** End with a `## Recommended next actions` block
   per `https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/templates/reference/NEXT-ACTIONS.md` (categories,
   precedence, output format, read-only rule — auditing is repo-wide *by
   purpose*). **Assert no severity beyond the audit's evidence**: route *potential*
   concerns to the specialist that confirms them; only a *confirmed* exposure is a
   stop.

   | Audit observation | Action |
   |---|---|
   | Confirmed exposed secret found during inspection | Stop & rotate the value; then `/security-review` |
   | Potential security concern needing validation | Run `/security-review` |
   | Potential correctness defect needing diff analysis | Run `/code-review` |
   | Vetted code-health findings ready for tracking | `/steer-issues publish-audit` |
   | Architectural / cross-cutting call | Propose an ADR via `/steer-adr` |
   | Spec coverage / conformance gap | `/steer-questions` |
   | Suspected spec-vs-build drift | Run `/steer-audit spec` |
   | `main` unprotected / branch-protection drift (GitHub) — unless `CLAUDE.md` declares solo trunk mode, where it is intentional until graduation | `/steer-protect` |
   | Mechanical cleanup only | `/simplify` |
   | Nothing actionable | Complete |

   Choose one `Current recommended action` by precedence; the block recommends
   and never edits.

## Reconciliation across runs — audits are reconciling, not additive

Re-running the audit **updates the existing issue set**, never piles up
duplicates: each finding carries a stable **`finding-key`** (the conceptual
defect, never line-based) plus a separately-tracked **`evidence`** fingerprint,
so same-key findings refresh in place, vanished findings close (auto-close only
when deterministic; judgment calls need a human yes), false positives stay
closed, and each run's `audit-run` parent is immutable history. The canonical
full lifecycle — both identities, the per-finding transition rules, `audit-id`
immutability — lives in
[`ISSUE-WORKFLOW.md`](https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/templates/reference/ISSUE-WORKFLOW.md) §"Audit &
drift"; `/steer-issues publish-audit` implements it (markers: `ISSUE-SCHEMA.md`).

---
name: audit
description: "Repeatable, read-only, whole-repo health audit of a managed repo — sweeps the code across standards dimensions (architecture, data layer, validation, errors, tests, deps, design, spec coverage), vets each finding against the cited code, ranks by leverage (impact ÷ effort × confidence), proposes routing into /spec, and files findings in the tracker. Repository-read-only: it proposes spec changes and files tracker issues, but never edits code or spec and never commits. Defers correctness to /code-review and security to /security-review."
when_to_use: Use to audit overall code health, find the highest-leverage improvements, or do a periodic standards-conformance pass on a steady-state repo.
disallowed-tools: Edit, Write, NotebookEdit, EnterWorktree
---

# Audit a repo's health against the standards (leverage-ranked)

> Native file-edit tools (`Edit`/`Write`/`NotebookEdit`) and worktree creation are
> unavailable while this skill runs, so the audit cannot edit code or spec. This does
> not make the repo immutable — shell mutations stay governed by your permission
> settings and hooks. Findings reach the tracker via `/steer:issues publish-audit`,
> which runs as its own step.

A **repeatable, read-only health audit** of a steady-state repo. It sweeps the
whole codebase across the standards dimensions, **vets** every candidate
finding against the code it cites (subagents over-report), ranks what survives by
**leverage**, and **proposes** routing into the existing `/spec` spine while
**filing** the findings in the issue tracker. The output is a ranked report and
proposed spec changes — it is **repository-read-only**: it never edits code or
spec and never commits, and its only writes are tracker issues.

This is the steady-state counterpart to one-time adoption: where `/steer:adopt`
builds the spec for a repo that has none, `/steer:audit` is run again and again on
a repo that already has one, to keep it healthy and standards-aligned.

## Relationship to the review skills — complementary, not overlapping

`/steer:audit` is **whole-repo, multi-dimension, and leverage-ranked**. It does
*not* re-implement the focused review skills — it names them and defers:

- **`/code-review`** — diff-scoped correctness bugs + cleanups. Audit does **not**
  hunt correctness bugs; it points findings that read as bugs to `/code-review`.
- **`/security-review`** — security vulnerabilities. Audit does **not** do a
  security pass; it flags "needs a security review" and defers.
- **`/simplify`** — mechanical reuse/simplification cleanups. Audit may *note*
  systemic duplication but hands the edits to `/simplify`.

And against the other spec skills:

- **`/steer:adopt`** — one-time onboarding triage (Keep/Refactor/Rewrite/Reject)
  that **creates** the `/spec` from code. Audit **assumes** the spec exists and
  is repeatable.
- **`/steer:drift`** — read-only **spec-vs-spec** conformance (as-built vs tracker
  intent). Audit is read-only **code-vs-standards** health. Both route genuine
  findings to issues; they answer different questions ("did we build what was
  asked?" vs. "is what we built healthy and standards-aligned?").

**If there is no `/spec` spine yet,** the spec-coverage dimension can't run.
Note that and redirect to `/steer:adopt` for the spec — the code-health dimensions
(2–9 below) still run without it.

## When to run

- Periodically (e.g. before a release, end of a milestone) as a standards pass.
- When a repo has accreted many small PRs and you want the highest-leverage
  cleanup backlog, ranked rather than ad-hoc.
- When a dev asks "where's the tech debt / what should we fix first?"

## Audit dimensions

Anchored to the baseline (`rules/85-practices.md`, Definition of Done, the
high-risk rule) and the productionization brief — **not** a generic checklist.
Skip any dimension that doesn't apply to the repo (e.g. design on a backend-only
service) and say so.

1. **Spec conformance & coverage** *(needs `/spec`)* — user-facing features with
   no `intent.md`/`contract.md`; `contract.md` sections stale vs the real code;
   hard-to-reverse choices baked into the code with no ADR under
   `/spec/decisions/`.
2. **Architecture & boundaries** — fat route handlers; domain logic living in UI
   components or handlers instead of shared testable modules; server-first
   violations (secrets/DB access leaking client-side); broken package boundaries.
3. **Data layer** — raw or string-interpolated SQL instead of a parameterized
   query layer; schema changed outside committed, reviewed migrations.
4. **Input validation & config** — external inputs (requests, external API
   responses, env vars) used without boundary validation; scattered raw env reads
   instead of one validated config module.
5. **Error handling & escape hatches** — swallowed errors / empty `catch`;
   unexpected errors not reported with context (Sentry gaps); escape hatches
   without a why-comment (`any`, `@ts-ignore`/`@ts-expect-error`, wholesale
   lint-rule disabling).
6. **Testing** — untested domain logic; bug-fix commits with no regression test;
   high-risk areas without coverage.
7. **Toolchain & dependency health** — outdated dependencies; missing or drifted
   lockfiles (`mise.lock`, `pnpm-lock.yaml`, `uv.lock`, `.terraform.lock.hcl`);
   unpinned toolchain versions. On a GitHub-tracked repo, also note if `main`
   lacks branch protection (the real PR gate) — route to `/steer:protect` to
   verify/apply against `policy/branch-protection.yml`; do not query or change
   settings here (audit is read-only code-health).
8. **Design consistency** *(UI repos only)* — `DESIGN.md` drift vs the code;
   styling that recurs in **3+ places** but isn't promoted to a token/component
   (the `DESIGN.md` 3+ rule).
9. **DX & docs** — README quickstart that no longer matches reality;
   `ARCHITECTURE.md` stale vs the code — stack table diverged from
   `package.json` / `mise.toml`, or the apps/packages map missing/naming a
   directory that doesn't match `apps/*`+`packages/*`; `mise.toml` missing the
   tasks a contributor needs (`setup`, `dev`, `test`, `lint`).

**Out of scope (delegated, never re-run here):** correctness bugs →
`/code-review`; security vulnerabilities → `/security-review`; mechanical
cleanup → `/simplify`.

## Phase 0 — Recon

Detect the stack from the repo itself (`package.json` / `pyproject.toml`,
frameworks, database, auth) — don't trust training-data memory. Map the apps,
entry points, and user-facing features. Check whether a `/spec` spine exists; if
not, note it and mark dimension 1 as **not run — redirect to `/steer:adopt`**.
Decide which dimensions apply.

## Phase 1 — Audit

Run one reviewer per applicable dimension. For a large repo, **fan out** (one
subagent per dimension) and gather the results. Each finding must carry
**`path:line` evidence** — the file and line that demonstrate it — plus a
one-line statement of which standard it misses. No evidence, no finding.

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
   `/spec/AUDIT-REPORT.md` on a `feat/audit` branch **only if the dev wants
   it tracked** — it's a point-in-time artifact, not part of the durable spine.
2. **Route each finding** to where it belongs in the workflow:
   - **Code-health findings** → a **two-level** issue set, filed via
     **`/steer:issues publish-audit`** (which routes through `/steer:tracker-sync`):
     one **audit-run** parent (scope, plugin version, audited SHA, dimensions
     run/skipped, summary, report path) plus selected **finding** children, each
     carrying a **stable `finding-key`** (`<dimension>:<rule>:<file-or-component>:<symbol>`
     — never line-based) so re-runs *reconcile* (update/close) rather than pile
     up duplicates. Bodies: `${CLAUDE_PLUGIN_ROOT}/templates/github/issue-bodies/audit-{run,finding}.md`.
     Scope children to genuine, high-leverage findings — don't file one per nit.
   - **Architectural / cross-cutting calls** → propose an ADR via `/steer:adr`.
   - **Spec coverage & conformance gaps** → a proposed `## Open questions` entry
     in the owning feature's `intent.md` (or `vision.md` if cross-cutting),
     drivable to answers by `/steer:questions`.
   - **Correctness** → defer to `/code-review`; **security** → defer to
     `/security-review`; **mechanical cleanup** → defer to `/simplify`. Name the
     skill; don't re-run it here. To turn an unresolved `/code-review` or
     `/security-review` finding into a tracked issue, route it through
     **`/steer:issues publish-findings --source code-review|security-review`**
     (`kind=finding` + the matching `source:*`; security findings redact secrets
     / exploit detail and default to human review before public disclosure).
3. **Make no code or spec edits, and don't commit.** This skill stops at the
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
   | `main` unprotected / branch-protection drift (GitHub) | `/steer:protect` |
   | Mechanical cleanup only | `/simplify` |
   | Nothing actionable | Complete |

   Choose one `Current recommended action` by precedence; the block recommends
   and never edits.

## Reconciliation across runs — audits are reconciling, not additive

Re-running the audit must **update the existing issue set**, never pile up
duplicates. Each run is filed via `/steer:issues publish-audit`, which keys off the
markers (see `ISSUE-SCHEMA.md`). Two distinct identities:

- **`finding-key`** = the *conceptual* defect (`<dimension>:<rule>:<file-or-component>:<symbol>`),
  stable across runs and **never line-based** — so moving the offending code
  without changing the defect still maps to the same finding.
- **`evidence`** = a fingerprint of the *currently observed* lines/region. It
  changes as code moves; that alone is an evidence update, not a new finding.

Per finding, on the next run:

- **Same `finding-key` still present** → update the existing issue's managed
  block (refresh evidence/impact). Don't reopen if a human closed it as
  `resolution:false-positive`.
- **`finding-key` gone (no longer reproduces)** → **comment with the evidence and
  close**, but gate the auto-close on confidence: only **`resolution_mode:
  deterministic`** findings (a check that objectively no longer fires) may
  auto-close; **`resolution_mode: reviewer-confirmed`** judgment calls (e.g.
  "unclear module responsibility") are proposed-for-close and need a human yes.
- **Evidence changed substantially, same key** → update evidence only.
- **New `finding-key`** → create.
- **False positive** → close with `resolution:false-positive`; it stays closed.

**Audit-run records are immutable history.** Each run files one `audit-run`
parent stamped with its own `audit-id` (`<iso-timestamp>-<short-sha>`); never
re-edit a prior run's parent to represent a later run. Finding children reconcile
across runs; the run parents accumulate as a timeline.

## Coupling rules

The canonical spec ↔ code rules (drift resolution, behavior vs. incidental
implementation, PO vs. dev approval) live in
`${CLAUDE_PLUGIN_ROOT}/templates/reference/spec-framework.md`; the full
conventions and patterns behind the dimensions are in
`${CLAUDE_PLUGIN_ROOT}/templates/reference/CONVENTIONS.md` (open via
`/steer:conventions`). This skill *detects, ranks, and routes*; those references
govern how each finding gets *resolved*.

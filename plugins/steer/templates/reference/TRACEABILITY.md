# Traceability & living documentation

Full prose behind the always-on `living-docs`, `issue-tracker`, `drift-gates`,
and `compliance` rules. Loaded on demand via **`/steer:reference traceability`**.

The goal: a PO can express intent in plain language, a dev can review precise
contracts, and anyone — including an auditor — can walk the chain
**intent → spec → tracker ref → implementation → review → release** months
later. Claude does the translation and bookkeeping *in parallel with the
work*; humans approve, review, and stay accountable.

---

## 1. Living documentation — the natural-language-to-spec contract

The user is never required to write structured artifacts. They describe goals,
constraints, decisions, questions, and changes in plain human language; Claude
converts that into the durable artifacts below **as the conversation happens**
— and proposes the update rather than silently rewriting anything a human
already approved.

### Routing table

| The human says (in any words)… | Claude updates / proposes |
|---|---|
| "Users should be able to…", a new goal, a scope change | Feature `intent.md` (what/why, user experience, acceptance) — PO approves scope changes |
| "Actually, it should behave like…" (requirement evolved) | The owning `contract.md` (+ `intent.md` if scope moved) — same PR as the code |
| "Let's go with X over Y" (trade-off accepted, hard to reverse) | ADR via `/steer:adr`; one entry in `/spec/history/` |
| "I'm not sure / we'll decide later / ask the client" | A `## Open questions` entry (see `SPEC-FRAMEWORK.md` → Structure for the `intent.md`-vs-`vision.md` placement rule) |
| "How does someone use this?" answered, a workflow settled, a role defined | App guide (`/spec/app/`) — usage, workflows, roles & permissions, configuration |
| "Ship it / that's what I wanted" (validation, release-worthy change) | Release notes in the app guide; the PO-acceptance checkbox in `intent.md` (its `Status:` becomes `live` only at the actual release) |
| A **notable event** — decision ratified, scope changed, repo-level event, PO document absorbed, incident (not an ordinary merged change) | `/spec/history/` entry: what, why, who asked, refs |

**In a polyrepo member** (`spec/PRODUCT.md` present), the product-level
destinations in this table — `/spec/history/`, `/spec/app/`,
`/spec/features/` — are the **workspace's**. Do not create them locally: route
the entry to the workspace checkout (`workspace.path` in `spec/PRODUCT.md`), else
carry it in the PR description. `spec/decisions/` and `spec/design/` are the
member's own, so ADRs are recorded normally.

### Extraction discipline

- **Extract, don't embellish.** Capture what was said; route what was *not*
  said (gaps, ambiguity) to `## Open questions`. Never invent an answer to
  make a spec look complete.
- **Identify ambiguity out loud.** When intent could mean two things, say so
  and ask — a one-line question now beats intent drift at review.
- **Same change, not "later".** Doc updates ride in the PR that changes the
  behavior. A wrap-up documentation pass is already drift.
- **Proposals, not stealth edits.** Updating an *approved* intent or a
  ratified decision is itself a change — propose it and get the owning
  human's yes (PO for intent, dev for contracts/ADRs).
- **Declined ≠ dropped.** If the human declines an update, record the
  divergence as an open question so it stays visible.

### Two audiences, two registers

| | PO-facing | Dev-facing |
|---|---|---|
| Artifacts | `vision.md`, `users.md`, `intent.md`, app guide, release notes, history "why" lines | `contract.md`, ADRs, implementation pointers, `PRODUCTIONIZATION.md`, runbook, tests |
| Register | Plain language, no stack vocabulary, user-visible outcomes | Precise enough to implement and review against: rules, data, APIs, error states |
| Owns | Intent, user workflows, acceptance criteria, product decisions, open product questions | Contracts, architecture, tests, infra, security, operations, release readiness |

Don't make a PO read code (or a contract) to learn what the product does —
that's what the app guide and intents are for. Don't make a dev reverse-
engineer intent from prose — that's what contracts and ADRs are for.

---

## 2. Action history (`/spec/history/`)

An append-only log: **what happened, why, who or what requested it, and which
specs/issues/decisions/code areas were affected.** 3–6 lines each; detail lives
in the linked spec/ADR/PR.

**One entry per notable event** — a ratified decision (ADR `Accepted`, intent
approved), a scope change to an approved intent, a repo-level event (bootstrap,
adoption, plugin sync, solo-trunk graduation), a PO source document absorbed, or
a production incident and its follow-up. **Not** one per merged change and not
one per commit: an ordinary change's record is the commit plus the reviewed PR,
which already carry what/when/who and the tracker ref. The log's value is that
everything in it is worth reading; routine entries dilute that and cost
maintenance for no information.

**One file per entry**, named for the moment it merged:

```text
spec/history/YYYY-MM-DD-HHMM-<slug>.md
```

```markdown
# 2026-06-10 14:32 — CSV export added to vendor list

- **Why:** PO needs to hand vendor data to finance monthly
- **Requested by:** @pat-po
- **Refs:** PROJ-214 · spec/features/export-csv/ · PR #87
- **Areas:** apps/web, packages/core
```

**Why a directory, not one file.** A single shared log put every PR's entry at
the same insertion point — the top of the file — so every pair of concurrent
changes conflicted there, and no date or time granularity helps: the collision is
positional, not content-based. Git's `union` merge driver looks like the fix and
is worse than the conflict: being *line*-based, when two entries share a trailing
line (`- **Areas:** apps/web` is the common case) it splices the blocks together
and **silently drops a field** in a merge that shows no markers and gets no
review. One file per entry means two PRs write different paths, so there is
nothing to resolve. Read the timeline newest-first with `ls -r spec/history/*.md`.

Entries are **immutable**: never rewrite, re-date, or delete one. A correction is
a new entry carrying `- **Corrects:** <filename>`. A repo bootstrapped before the
directory existed keeps its earlier entries in a frozen `spec/HISTORY.md` archive.

The log serves: **auditability** (when/why/who for a notable event — an ordinary
change's audit record is its commit and reviewed PR), **onboarding**
(read the last quarter in five minutes), **review evidence** (the entry rides in
the reviewed PR), **decision archaeology** (why is it like this?), and **drift
detection over time** (`/steer:audit spec` and `/steer:audit` use it as a
timeline).

---

## 3. App knowledge documentation (`/spec/app/`)

Documentation about *using and operating* the product — distinct from specs
(what to build) and contracts (how it must behave internally). Index:
`spec/app/README.md` (bundled template `templates/spec/app-docs.md`), with
sections split into their own files as they grow:

- **How to use the app** + one subsection per major workflow
- **Roles & permissions** (who can do what, plain language)
- **Configuration concepts** (what's adjustable and what it affects)
- **Known limitations** (deliberate non-goals + current gaps)
- **Troubleshooting** (symptom → cause → action)
- **Operational runbook** (dev-facing; only once deployed)
- **Release notes** (user-facing change log, newest first)
- **Glossary** → link `spec/glossary.md`, never copy it

**Update trigger:** any PR that changes user-visible behavior, roles,
configuration, or operations updates the affected page in the same PR — a
stale app guide is a drift-gate flag ("app docs invalidated"). When behavior
is about to change, check `/spec/app/` *before* merge, not after a user trips
on it.

---

## 4. Issue tracker integration (client-agnostic)

Every client brings their own tracker. The model: **the spec spine is the
in-repo source of truth; the tracker is the scheduling/ownership system; refs
connect the two.** Only one file knows which tracker is in use:

- **`/spec/tracker.md`** declares the system, project key, reference format,
  and URL pattern (bundled template `templates/spec/tracker.md`). Everything
  else stays tracker-agnostic by writing refs in that declared format.

| Tracker | Ref format | PR linking |
|---|---|---|
| GitHub Issues | `#123` | `Closes #123` auto-closes |
| Jira | `PROJ-123` | Smart-commit / branch-name integration if configured |
| Linear | `ENG-123` | `Fixes ENG-123` auto-links |
| Azure DevOps | `AB#123` | `AB#123` auto-links |
| Other / none yet | declare in `tracker.md` | plain link in the PR body |

**Where refs live:**

- Feature `intent.md` header: `> Tracker: PROJ-123` (or `none yet`).
- PR description: under "Related issue", using the tracker's own
  closing/linking syntax where it has one.
- `/spec/history/`: in each entry's `Refs:` line.
- ADRs: link the driving tracker item in Context when one exists.

**Preserving issue context:** when work starts from a tracker item, copy its
acceptance criteria and constraints into the feature's `intent.md` (don't
leave them tracker-only — the repo must stand alone for review and audit);
keep the ref as the pointer back. When tracker state and spec diverge, that's
exactly what `/steer:audit spec` audits.

**Questions not yet tracked externally** live in `## Open questions`. Promote
one to a tracker item when it needs scheduling, an external owner, or client
visibility — then set that question's `tracker:` field to the ref. The
`### Q-NNN` block **stays**: it already reads standalone, the issue carries the
same id via `<!-- steer:question-id=Q-NNN -->`, and that spec-`tracker:` ↔
issue-`question-id` pair is the bidirectional link — deleting the block strands
the issue and fails `/steer:spec validate`, which flags a promoted question with
no `tracker:` ref back.

---

## 5. Drift gates — what must be surfaced before merge

Drift is any meaningful mismatch along intent ↔ spec ↔ contract ↔ tracker ↔
app docs ↔ action history ↔ tests ↔ delivered behavior. The standing rule
(spec-framework Rule 5): **resolve drift via explicit human review, never
silently** — fix the code, fix the artifact, or record the accepted
divergence. The always-on `drift-gates` rule lists the nine review-sensitive
classes; the scaffold's PR template carries them as a checklist so the flag is
part of the review record.

Mechanics:

- Flag **when noticed, not at wrap-up** — note it in the PR description draft
  immediately (or tell the dev if no PR exists yet).
- A checked flag **blocks merge** until the reviewer explicitly resolves it.
  "Resolved" is visible: a code change, an artifact update in the same PR, or
  a written accepted-divergence note (open question or `spec-drift` issue).
- Claude **may not waive its own flag** — only the human reviewer resolves it.
- Sweeps for drift that slipped past per-PR gates: `/steer:audit spec` (as-built spec
  vs tracker spec), `/steer:audit` (code vs standards), `/steer:questions` (open
  questions rotting).

---

## 6. SOC 2 / ISO 27001-aligned delivery

The workflow is **aligned with** SOC 2 and ISO 27001 delivery expectations —
say "aligned", never "compliant": no plugin, workflow, or generated artifact
makes a product compliant. Certification scope, control ownership, compliance
accountability, and production-readiness approval are human responsibilities;
Claude assists with the work and keeps the evidence trail intact.

What the workflow contributes, mapped to what auditors typically ask for:

| Expectation | Where it lives here |
|---|---|
| Traceability of changes | intent → contract → tracker ref → reviewed PR (each change's own record) |
| Review evidence | dev-approved PRs as the production gate; drift flags + DoD in the PR record |
| Change history | ADRs (decisions), action history (what/why/who), git history (code) |
| Access-conscious workflow | branch protection, least-scope tokens, no direct-to-`main`, PO/dev role split |
| Secure defaults | secrets rules (never committed; encrypted config at rest — Parameter Store / Secrets Manager), high-risk gates, validated boundaries |
| Documented operations | runbook in `/spec/app/`, `.env.example`, CI/deploy under version control |
| Auditable decisions | ADR status lifecycle (Proposed/Accepted/Superseded), append-only history |
| Human accountability | PO approves intent; dev approves the PR; humans own production readiness |

---

## 7. Worked examples

### A PO's day (plain language in, artifacts out)

> **PO:** "Clients keep asking for a way to download their vendor list —
> finance wants it monthly as a spreadsheet. Oh, and only admins should be
> able to do it."

Claude, in parallel with any prototyping: drafts
`spec/features/export-csv/intent.md` (what/why, acceptance criteria: admin-
only, CSV columns…), adds `> Tracker: none yet`, asks one clarifying question
("every vendor field, or a fixed set?") and records it under `## Open
questions`, updates the app guide's Roles table proposal (admins gain
"Export"), and — once built and merged — writes a release-notes line ("Admins can
now download the vendor list as CSV"). No history entry: shipping an approved
feature is an ordinary merged change, and the commit plus the reviewed PR are its
record. (The *approval* of the intent, earlier, was the notable event.) The PO
read and approved exactly one artifact: the intent. Everything stayed in plain
language.

### A dev's day (precision in, gates out)

> **Dev:** "The export query is N+1 and I'm moving it into
> `packages/core/reports`; while I'm there I'll stream the CSV instead of
> buffering."

Claude: updates `contract.md` (API surface unchanged; behavior rule added for
streaming + max-size error state), notes the move in Implementation pointers,
checks the PR's drift-gate flags — "Contract drift" (contract updated to
match) and nothing else — writes no history entry (a perf refactor is an ordinary
merged change), and reminds that the app guide is unaffected (no user-visible
change). Tests ride in the same PR per the testing rules. The reviewer sees
the flag, the contract diff, and the regression test together.

### Where each runs

Both flows work in Claude Code and Cowork; the PO typically enters through
**`/steer:build`**, the dev through the normal spec workflow
(`/steer:spec`, `/steer:adr`) — the artifacts and gates are identical.

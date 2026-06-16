---
name: e22-spec
description: "Spec-only brainstorm for a feature — author and iterate intent.md (and contract.md where behavior demands it) and drive open questions to resolution, WITHOUT writing any code. The no-build counterpart to /e22-standards:e22-build. Also runs `/e22-standards:e22-spec validate [feature-id|--all]`: a local, GitHub-independent structural check over the open-question contract that blocks approval while a blocking question is open. Never touches /apps or /packages; ends at an approved intent, not a build."
when_to_use: Use to think a feature through before committing to implementation, shape acceptance criteria, validate a spec's question state, or refine a spec you intend to compare against the code later via /e22-standards:e22-drift.
argument-hint: "[feature-id | approve <feature-id> | validate [feature-id | --all]]"
---
<!-- e22:modes default,approve,validate -->

# Brainstorm a feature spec — no build

A **design-studio loop**: author and iterate a feature's spec and drive its open
questions to resolution, and **write no code at all**. This is the no-build
counterpart to `/e22-standards:e22-build` — it ends at an *approved intent*, not a running app.

It orchestrates the existing spec pieces behind one door: scaffold the spine
(`/e22-standards:e22-spec-scaffold` templates), brainstorm the intent, sweep open questions
(`/e22-standards:e22-questions` behavior), and optionally hand the result to
`/e22-standards:e22-tracker-sync` to file a tracker item — but it never crosses into
implementation.

## The defining guardrail — never builds

- **MUST NOT** create, edit, or delete anything under `/apps/**` or
  `/packages/**`, run build/test/dev tooling, or open a code PR. Writes are
  confined to `/spec/**` (the feature spine, `vision.md`, `decisions/`,
  `glossary.md`).
- If the user asks to "just build it" mid-session, **stop and point to
  `/e22-standards:e22-build` (PO-driven) or normal dev flow** — state the boundary out loud;
  don't silently comply. Brainstorming the spec and building it are separate
  sessions on purpose, so the intent can be reviewed before code exists.

## When to run

- Before committing to implementation, to think a feature through and pin its
  acceptance criteria.
- To refine an intent you plan to compare against the code later (`/e22-standards:e22-drift`).
- Whenever a feature needs design discussion but **not** code yet.

## Steps

1. **Identify the feature.** Ask for a short kebab-case `[id]` (e.g.
   `export-csv`, `user-login`). If `spec/features/[id]/` already exists,
   **resume** it — never clobber filled-in content; merge into it.
2. **Scaffold if new.** Copy the bundled templates for a new feature:
   - `${CLAUDE_PLUGIN_ROOT}/templates/spec/feature-intent.md` → `spec/features/[id]/intent.md`
   - `${CLAUDE_PLUGIN_ROOT}/templates/spec/feature-contract.md` → `spec/features/[id]/contract.md` (only when behavior/data/API surface is in play — see step 5).
   For a design-originated feature, populate the `Design source` section per
   `/e22-standards:e22-design-sources`.
3. **Brainstorm the intent interactively.** Walk the PO/dev through, in plain
   user-facing language: the problem, who it's for, the user-visible outcome,
   and concrete **acceptance criteria**. Keep it stack-free — this is the *what
   and why*, not the *how*. Park anything unresolved under `## Open questions`;
   **never invent an answer**.
4. **Resolve open questions.** Run the `/e22-standards:e22-questions` read-then-propose loop on
   this feature: surface each question, propose options, fold the *confirmed*
   decision back into the spec, strike the question. Explicit deferral with a
   reason is a valid outcome. A question needing an external owner or scheduling
   → leave it open, tagged for `/e22-standards:e22-tracker-sync push` (step 6).
5. **Write `contract.md` only where it earns its place.** Add testable behavior
   rules / data / API surface **only** when they matter for behavior,
   integration, security, or future maintenance — not as ceremony. `intent.md`
   is the what/why (PO-facing); `contract.md` is the testable behavior + data/API
   surface (dev-owned).
6. **Approval gate — both exits stay code-free.** First **run `validate` on this
   feature** (below) — an approval **cannot proceed while a blocking question is
   `open`**; resolve or explicitly reclassify it first. Then present the intent
   for PO approval. On PO approval, run **`approve <id>`** (below) to record the
   approval and flip `Status:` to `approved` in one change, then offer:
   - `/e22-standards:e22-tracker-sync push` → file or refresh the tracker item from this
     intent, writing the ref back into the `> Tracker:` line.
   - hand off for implementation **in a separate session** — this skill stops
     here. In a GitHub-adopted repo (`tracker.md` → `system: github`),
     implementation runs through `/e22-standards:e22-work` (decompose via
     `/e22-standards:e22-issues` first); PO-driven builds go through
     `/e22-standards:e22-build` (which itself delegates to `e22-work` once
     governed). Don't hand off to a "just implement it" path that skips the issue.
7. **Recommend the next action.** Close with a `## Recommended next actions` block
   per `${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md`. Per the
   **locality rule**, consider only *this* feature's intent, open questions,
   contract, tracker state, and directly relevant ADRs — not the wider workspace.

   | Observed state | Category | Action / suggested command |
   |---|---|---|
   | Open `impact: blocking` question on this feature | Blocking now | Resolve it — `/e22-standards:e22-questions` |
   | Intent drafted, not yet PO-approved | Human decision required | PO reviews & approves the intent (no command) |
   | Behavior demands a contract that isn't written | Required before initial production | Author `contract.md` |
   | Approved, tracker configured, not yet filed | Recommended | `/e22-standards:e22-tracker-sync push` |
   | Approved | Complete | Optional: implement in a separate session — `/e22-standards:e22-work` (after `/e22-standards:e22-issues decompose`) or `/e22-standards:e22-build` |

   Pick one `Current recommended action` by precedence; the block stays code-free,
   like the rest of this skill.

## Validate mode — `/e22-standards:e22-spec validate [feature-id|--all]`

A **local, GitHub-independent** structural check over the open-question contract
(`spec-framework.md`): the defense-in-depth floor that holds even when the
tracker is unreachable. It is read-only — it reports failures and (with a yes)
proposes fixes; it never invents a decision. Given a `[feature-id]` it checks one
feature; `--all` sweeps every `intent.md` + `vision.md` in the spine.

Flag each of these, citing the `Q-NNN` and file:

- ✗ an **approved** intent (`Status: approved`/`implemented`/`validated`/`live`)
  that still contains an `open` `blocking` question;
- ✗ a `deferred` question missing `owner` or `required_before`;
- ✗ a `resolved` question with no resolution folded into the spec's normative
  prose (only a `_Resolution:_` line, or nothing);
- ⚠ a question with a `tracker:` ref whose issue is **closed** but whose
  `status:` is still `open` — the closed-issue / stale-spec trap;
- ✗ a **promoted** question (an open `spec-question` issue references its
  `question-id`) with no `tracker:` ref back.

The closed-issue check needs the tracker; when GitHub is unavailable, run the
GitHub-independent checks and **say** the tracker-coupled ones were skipped —
silence must never read as "passed." A failing check **blocks the relevant gate**
(approval, `/e22-standards:e22-issues materialize`, a spec-changing PR). `/e22-standards:e22-issues`
(`materialize`, `status`, `reconcile`) and `/e22-standards:e22-drift` call this before acting.

## Approve mode — `/e22-standards:e22-spec approve <feature-id>`

<!-- e22:transition-owner feature-status:draft->approved -->

Records a PO's intent approval as a **structural, mechanically-checkable**
transition — never a free-form "looks good." This mode is the **single owner and
only writer** of the `draft → approved` transition; `/e22-standards:e22-issues
materialize` deliberately stops at `draft`. Other workflows (notably
`/e22-standards:e22-build`) **delegate** here after an explicit PO approval —
they invoke this operation but **must not reproduce its field-editing logic**
(the `## PO acceptance` checkboxes, `> Approved by:` / `> Approved at:`, the
`Status:` flip, or the HISTORY entry). An explicit PO statement authorizes Claude
to run this operation; the PO never has to know or type the slash command.

**Allowed transition — `draft → approved` only.**

- Refuse on `implemented`, `validated`, or `live`: approval never downgrades or
  rewrites a feature past implementation — report the current state and stop,
  appending nothing.
- **Idempotent on `approved`** — if the feature is already `approved`, report the
  existing `> Approved by:` / `> Approved at:` and append **no** duplicate
  HISTORY entry.

**Blocking-question gate (exact predicate).** Refuse the approval **iff** there
exists a question with **all** of:

- `impact: blocking`, **and**
- `required_before: intent-approval`, **and**
- `status` ∈ the unresolved set `{open, investigating, deferred}`.

A blocking-but-`deferred` question **still blocks** intent approval until its
`impact:` is explicitly reclassified `non-blocking` — deferral is not resolution.
Questions gated only at `contract-approval`, `implementation`,
`non-prod-validation`, or `production-release` do **not** block intent approval
(they block their own later gate). Run `validate` first so the closed-issue /
stale-spec checks fire too.

**On a clean approval, in one change:**

1. Fill the intent header block — `> Approved by: @<po-handle>` and
   `> Approved at: <YYYY-MM-DD>` — and tick the `## PO acceptance` checkboxes (the
   human-facing mirror) with the `Approval comment/link:`.
2. Flip `> Status:` to `approved`.
3. Append **one** `/spec/HISTORY.md` entry (what / why / who-asked / refs).
4. Recommend the local next action — decompose into work
   (`/e22-standards:e22-issues decompose`, then execute each via
   `/e22-standards:e22-work`) or, for a PO-driven build,
   `/e22-standards:e22-build` (which delegates to `e22-work` once governed) — per
   the `## Recommended next actions` block.

`approve` writes only under `/spec/**` (the intent header, PO-acceptance block,
and HISTORY); it stays as code-free as the rest of this skill.

## Relationship to neighbors

| Skill | Role |
|---|---|
| `/e22-standards:e22-spec` | author + iterate a feature spec, **no code** (this) |
| `/e22-standards:e22-spec-scaffold` | one-shot template instantiation (reused here) |
| `/e22-standards:e22-questions` | open-question sweep (behavior reused here) |
| `/e22-standards:e22-build` | spec **and** build, PO-driven, ends in a code PR |
| `/e22-standards:e22-tracker-sync` | file the intent as a tracker item (optional exit) |
| `/e22-standards:e22-drift` | *later*: compare this intent against the as-built code |

## Coupling rules

The canonical spec ↔ code rules — feature-organized specs, spec and code
changing together in the same PR, drift resolution (Rule 5), behavior vs.
incidental implementation, PO acceptance — live in
`${CLAUDE_PLUGIN_ROOT}/templates/reference/spec-framework.md`. This skill stays
on the spec side of that boundary by design.

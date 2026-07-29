---
name: spec
description: "Spec-only brainstorm for a feature — author and iterate intent.md (and contract.md where behavior demands it) and drive open questions to resolution WITHOUT writing any code; `clarify` sweeps the draft for gaps (edge cases, error paths, scope), `approve` records approval and flips intent Status, `validate` checks the open-question contract plus intent/contract/tracker consistency. Ends at an approved intent, not a build."
when_to_use: >-
  Use to think a feature through before committing to implementation, shape
  acceptance criteria, or validate a spec's question state. Works spec-only on
  an unmanaged repo (lite mode) — no bootstrap required.
argument-hint: "[feature-id | approve <feature-id> | clarify <feature-id> | validate [feature-id | --all]]"
---
<!-- steer:modes default,approve,clarify,validate -->

# Brainstorm a feature spec — no build

A **design-studio loop**: author and iterate a feature's spec and drive its open
questions to resolution, and **write no code at all**. This is the no-build
counterpart to `/steer:build` — it ends at an *approved intent*, not a running app.

It orchestrates the existing spec pieces behind one door: scaffold the spine
(`/steer:spec-scaffold` templates), brainstorm the intent, sweep open questions
(`/steer:questions` behavior), and optionally hand the result to
`/steer:tracker-sync` to file a tracker item — but it never crosses into
implementation.

## The defining guardrail — never builds

- **MUST NOT** create, edit, or delete anything under `/apps/**` or
  `/packages/**`, run build/test/dev tooling, or open a code PR. Writes are
  confined to `/spec/**` (the feature spine, `vision.md`, `decisions/`,
  `glossary.md`).
- If the user asks to "just build it" mid-session, **stop and point to
  `/steer:build` (PO-driven) or normal dev flow** — state the boundary out loud;
  don't silently comply. Brainstorming the spec and building it are separate
  sessions on purpose, so the intent can be reviewed before code exists.

## When to run

- Before committing to implementation, to think a feature through and pin its
  acceptance criteria.
- To refine an intent you plan to compare against the code later (`/steer:audit spec`).
- Whenever a feature needs design discussion but **not** code yet.

## Lite mode — an unmanaged repo is not a blocker

On a repo with **no `/spec` spine**, do **not** send the user through
`/steer:setup` first — thinking a feature through is the one activity
sanctioned without bootstrap. Proceed **spec-only**: run the steps below as
normal (`/steer:spec-scaffold` creates `spec/features/[id]/` and instantiates
the templates; no toolchain, scaffold, or full spine required), and say in one
line that you're working in lite mode. Two boundaries: product-level prose
that belongs in `vision.md` is parked in the feature's `## Open questions`
rather than scaffolding the spine ad hoc, and the never-builds guardrail is
unchanged. At close, surface **one** follow-up: `/steer:setup` graduates the
repo (spine, scaffold, toolchain) when the team is ready to build — a next
step, never a precondition for the spec work itself.

## Steps

0. **Resolve the spine first.** If this repo carries `spec/PRODUCT.md` (a polyrepo
   member), its spine is **partial by design**: every feature's `intent.md` /
   `contract.md` lives in the **workspace** repo, not here. Resolve the workspace
   before step 1 — `workspace.path` when `spec/workspace.yml` is present there
   (resolved against the **primary checkout**, since `..` from a linked worktree
   lands on an empty `.claude/worktrees`), else the GitHub gateway — and author the
   feature spec **there**. A missing local `intent.md`
   means the workspace has not been read yet, never that the feature is
   unspecified, so **never** author product-level spec files here to fill the gap.
   If neither route reaches the workspace, say the spine is unreachable and stop.
   Procedure: `/steer:reference polyrepo`.
1. **Identify the feature.** Ask for a short kebab-case `[id]` (e.g.
   `export-csv`, `user-login`). If `spec/features/[id]/` already exists,
   **resume** it — never clobber filled-in content; merge into it.
2. **Scaffold the feature.** Run `/steer:spec-scaffold [id]` — it instantiates
   `intent.md` (+ `contract.md`) from the bundled templates, copying them in for a
   new feature and reconciling additively against the current template for an
   existing one (its `template-reconcile.sh` branch), so nothing is hand-copied or
   clobbered. Whether `contract.md` earns its place is decided in step 6. For a
   design-originated feature, populate the `Design source` section per
   `/steer:reference design-sources`.
3. **Brainstorm the intent interactively.** Walk the PO/dev through, in plain
   user-facing language: the problem, who it's for, the user-visible outcome,
   and concrete **acceptance criteria**. Keep it stack-free — this is the *what
   and why*, not the *how*. Park anything unresolved under `## Open questions`;
   **never invent an answer**.
4. **Clarify — sweep the draft for gaps** (clarify mode — procedure in
   `MODES.md`) before
   presenting anything for approval: interrogate the draft against the gap
   classes and convert every real gap into a `Q-NNN` open question. This is
   where ambiguity becomes structured, answerable questions instead of
   surprises at implementation.
5. **Resolve open questions.** Run the `/steer:questions` read-then-propose loop on
   this feature: surface each question, propose options, fold the *confirmed*
   decision back into the spec, close the question (`status: resolved`; the
   `Q-NNN` block stays). Explicit deferral with a
   reason is a valid outcome. A question needing an external owner or scheduling
   → leave it open, to be filed as an issue via `/steer:issues` at step 7.
6. **Write `contract.md` only where it earns its place.** Add testable behavior
   rules / data / API surface **only** when they matter for behavior,
   integration, security, or future maintenance — not as ceremony. `intent.md`
   is the what/why (PO-facing); `contract.md` is the testable behavior + data/API
   surface (dev-owned).
7. **Approval gate — both exits stay code-free.** First **run `validate` on this
   feature** (procedure in `MODES.md`) — an approval **cannot proceed while a
   blocking question gated at `required_before: intent-approval` is unresolved**
   (the exact predicate lives in approve mode, in `MODES.md`); resolve or
   explicitly reclassify it first. Then present the intent
   for PO approval — as an **answerable prompt** (Approve · Reject · Decide later,
   rule `61-gate-prompts`) when the PO is in the session, rather than leaving a
   `draft` for them to come back and flip. On PO approval, run **`approve <id>`**
   (`MODES.md`) to record the approval and flip `Status:` to `approved` in one change,
   then offer:
   - file it via `/steer:issues` (which routes through the tracker gateway) →
     create or refresh the tracker item from this intent, writing the ref back
     into the `> Tracker:` line.
   - hand off for implementation **in a separate session** — this skill stops
     here. In a GitHub-adopted repo (`tracker.md` → `system: github`),
     implementation runs through `/steer:work` (decompose via
     `/steer:issues` first); PO-driven builds go through
     `/steer:build` (which itself delegates to `work` once
     governed). Don't hand off to a "just implement it" path that skips the issue.
8. **Recommend the next action.** Close with a `## Recommended next actions` block
   per `${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md`. Per the
   **locality rule**, consider only *this* feature's intent, open questions,
   contract, tracker state, and directly relevant ADRs — not the wider workspace.

   | Observed state | Category | Action / suggested command |
   |---|---|---|
   | Open `impact: blocking` question on this feature | Blocking now | Resolve it — `/steer:questions` |
   | Intent drafted, PO in the session | Human decision required | Answer the approval prompt — on Approve, `/steer:spec approve` |
   | Intent drafted, PO is someone else | Human decision required | PO reviews & approves the intent (no command) |
   | Behavior demands a contract that isn't written | Required before initial production | Author `contract.md` |
   | Approved, tracker configured, not yet filed | Recommended | file it via `/steer:issues` |
   | Approved | Complete | Optional: implement in a separate session — `/steer:work` (after `/steer:issues decompose`) or `/steer:build` |

   Pick one `Current recommended action` by precedence; the block stays code-free,
   like the rest of this skill.

## Non-default modes — read the procedure when you run one

- **`clarify <feature-id>`** — sweep a draft intent for gaps (edge cases, error
  paths, scope boundaries) before it goes for approval.
- **`validate [feature-id|--all]`** — check the open-question contract plus
  intent/contract/tracker consistency.
- **`approve <feature-id>`** — the explicit approval transition, with its
  evidence requirements.

→ [`MODES.md`](${CLAUDE_PLUGIN_ROOT}/skills/spec/MODES.md)

## Relationship to neighbors

| Skill | Role |
|---|---|
| `/steer:spec` | author + iterate a feature spec, **no code** (this) |
| `/steer:spec-scaffold` | one-shot template instantiation (reused here) |
| `/steer:questions` | open-question sweep (behavior reused here) |
| `/steer:build` | spec **and** build, PO-driven, ends in a code PR |
| `/steer:tracker-sync` | file the intent as a tracker item (optional exit) |
| `/steer:audit spec` | *later*: compare this intent against the as-built code |

## Coupling rules

The canonical spec ↔ code rules — feature-organized specs, spec and code
changing together in the same PR, drift resolution (Rule 5), behavior vs.
incidental implementation, PO acceptance — live in
`${CLAUDE_PLUGIN_ROOT}/templates/reference/SPEC-FRAMEWORK.md`. This skill stays
on the spec side of that boundary by design.

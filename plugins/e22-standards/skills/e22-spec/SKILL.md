---
name: e22-spec
description: "Spec-only brainstorm for a feature — author and iterate intent.md (and contract.md where behavior demands it) and drive open questions to resolution, WITHOUT writing any code. The no-build counterpart to /e22-build. Use to think a feature through before committing to implementation, shape acceptance criteria, or refine a spec you intend to compare against the code later via /e22-drift. Never touches /apps or /packages; ends at an approved intent, not a build."
---

# Brainstorm a feature spec — no build

A **design-studio loop**: author and iterate a feature's spec and drive its open
questions to resolution, and **write no code at all**. This is the no-build
counterpart to `/e22-build` — it ends at an *approved intent*, not a running app.

It orchestrates the existing spec pieces behind one door: scaffold the spine
(`/e22-spec-scaffold` templates), brainstorm the intent, sweep open questions
(`/e22-questions` behavior), and optionally hand the result to
`/e22-tracker-sync` to file a tracker item — but it never crosses into
implementation.

## The defining guardrail — never builds

- **MUST NOT** create, edit, or delete anything under `/apps/**` or
  `/packages/**`, run build/test/dev tooling, or open a code PR. Writes are
  confined to `/spec/**` (the feature spine, `vision.md`, `decisions/`,
  `glossary.md`).
- If the user asks to "just build it" mid-session, **stop and point to
  `/e22-build` (PO-driven) or normal dev flow** — state the boundary out loud;
  don't silently comply. Brainstorming the spec and building it are separate
  sessions on purpose, so the intent can be reviewed before code exists.

## When to run

- Before committing to implementation, to think a feature through and pin its
  acceptance criteria.
- To refine an intent you plan to compare against the code later (`/e22-drift`).
- Whenever a feature needs design discussion but **not** code yet.

## Steps

1. **Identify the feature.** Ask for a short kebab-case `[id]` (e.g.
   `export-csv`, `user-login`). If `spec/features/[id]/` already exists,
   **resume** it — never clobber filled-in content; merge into it.
2. **Scaffold if new.** Copy the bundled templates for a new feature:
   - `${CLAUDE_PLUGIN_ROOT}/templates/spec/feature-intent.md` → `spec/features/[id]/intent.md`
   - `${CLAUDE_PLUGIN_ROOT}/templates/spec/feature-contract.md` → `spec/features/[id]/contract.md` (only when behavior/data/API surface is in play — see step 5).
   For a design-originated feature, populate the `Design source` section per
   `/e22-design-sources`.
3. **Brainstorm the intent interactively.** Walk the PO/dev through, in plain
   user-facing language: the problem, who it's for, the user-visible outcome,
   and concrete **acceptance criteria**. Keep it stack-free — this is the *what
   and why*, not the *how*. Park anything unresolved under `## Open questions`;
   **never invent an answer**.
4. **Resolve open questions.** Run the `/e22-questions` read-then-propose loop on
   this feature: surface each question, propose options, fold the *confirmed*
   decision back into the spec, strike the question. Explicit deferral with a
   reason is a valid outcome. A question needing an external owner or scheduling
   → leave it open, tagged for `/e22-tracker-sync push` (step 6).
5. **Write `contract.md` only where it earns its place.** Add testable behavior
   rules / data / API surface **only** when they matter for behavior,
   integration, security, or future maintenance — not as ceremony. `intent.md`
   is the what/why (PO-facing); `contract.md` is the testable behavior + data/API
   surface (dev-owned).
6. **Approval gate — both exits stay code-free.** Present the intent for PO
   approval. On approval, offer:
   - `/e22-tracker-sync push` → file or refresh the tracker item from this
     intent, writing the ref back into the `> Tracker:` line.
   - hand to a dev (or `/e22-build`) for implementation **in a separate
     session** — this skill stops here.

## Relationship to neighbors

| Skill | Role |
|---|---|
| `/e22-spec` | author + iterate a feature spec, **no code** (this) |
| `/e22-spec-scaffold` | one-shot template instantiation (reused here) |
| `/e22-questions` | open-question sweep (behavior reused here) |
| `/e22-build` | spec **and** build, PO-driven, ends in a code PR |
| `/e22-tracker-sync` | file the intent as a tracker item (optional exit) |
| `/e22-drift` | *later*: compare this intent against the as-built code |

## Coupling rules

The canonical spec ↔ code rules — feature-organized specs, spec and code
changing together in the same PR, drift resolution (Rule 5), behavior vs.
incidental implementation, PO acceptance — live in
`${CLAUDE_PLUGIN_ROOT}/templates/reference/spec-framework.md`. This skill stays
on the spec side of that boundary by design.

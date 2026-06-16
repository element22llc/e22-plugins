# Proposal — `/steer:spec` (spec-only brainstorm, never builds)

> Status: draft for dev review · Target plugin version: 1.37.0
> Companion: [`tracker-sync`](./tracker-sync.md)

## Problem

Today there is **no entry point for "design the spec, build nothing."** The
pieces exist but must be chained, and the obvious-looking door leads to code:

- `/steer:spec-scaffold` instantiates `intent.md` + `contract.md` from templates
  **once**, then stops — it doesn't drive the thinking.
- `/steer:questions` resolves open questions but assumes a spine already exists.
- `/steer:build` *looks* like the brainstorm door but interviews → spec → **then
  builds the app** and ends in a PR with code.

A PO or dev who wants to *only reason about the spec* — shape intent, argue
acceptance criteria, surface and resolve open questions — and then later compare
that intent against what was actually implemented, has no single skill for it.

## What `/steer:spec` is

The **no-build counterpart to `/steer:build`**: a design-studio loop that authors
and iterates a feature spec and **never writes code under `/apps` or
`/packages`**. It ends at an *approved intent*, not a running app.

It orchestrates the existing pieces behind one door:
1. Scaffold the feature spine if missing (reuses `spec-scaffold` templates).
2. Drive an interactive brainstorm to fill `intent.md` (problem → users →
   outcomes → acceptance criteria → open questions).
3. Sweep `## Open questions` to resolution (reuses `questions` behavior).
4. Optionally hand off to `/steer:tracker-sync` to file the intent as a tracker
   item — but creating code is **out of scope, always**.

## SKILL.md (proposed)

```md
---
name: spec
description: >
  Spec-only brainstorm for a feature — author and iterate intent.md (+ contract.md
  where behavior demands it) and drive open questions to resolution, WITHOUT writing
  any code. The no-build counterpart to /steer:build. Use to think through a feature
  before committing to implementation, shape acceptance criteria, or refine a spec
  you intend to compare against the code later via /steer:drift. Never touches
  /apps or /packages; ends at an approved intent, not a build.
---
```

### Hard guardrail (the defining property)

- **MUST NOT** create, edit, or delete anything under `/apps/**` or
  `/packages/**`, run build/test/dev tooling, or open a code PR.
- Writes are confined to `/spec/**` (the feature spine, `vision.md`,
  `decisions/`, `glossary.md`).
- If the user asks to "just build it" mid-session, the skill **stops and points
  to `/steer:build` or normal dev flow** rather than crossing the line. State the
  boundary explicitly; don't silently comply.

### Steps

1. **Identify the feature.** Ask for a kebab-case `[id]` (e.g. `export-csv`). If
   `spec/features/[id]/` exists, *resume* it — never clobber.
2. **Scaffold if new.** Copy `feature-intent.md` (+ `feature-contract.md` when
   behavior/data surface is in play) from `${CLAUDE_PLUGIN_ROOT}/templates/spec/`.
3. **Brainstorm the intent interactively.** Walk the PO/dev through, in plain
   language: the problem, who it's for, the user-visible outcome, and concrete
   **acceptance criteria**. Park anything unresolved under `## Open questions` —
   never invent an answer.
4. **Resolve open questions.** Run the `questions` read-then-propose loop:
   surface each question, propose options, fold the *confirmed* decision back in.
   Promote questions needing an external owner to `## Open questions` tagged for
   `/steer:tracker-sync`.
5. **Write contract.md only where it earns its place.** Add testable behavior
   rules / data / API surface to `contract.md` *only* when they matter for
   behavior, integration, security, or maintenance — not as ceremony.
6. **Approval gate.** Present the intent for PO approval. On approval, offer two
   exits — neither of which writes code:
   - `/steer:tracker-sync push` → file/refresh the tracker item from this intent.
   - hand to a dev / `/steer:build` for implementation in a *separate* session.

### Relationship to neighbors

| Skill | Role |
|---|---|
| `/steer:spec` | **author + iterate spec, no code** (this) |
| `/steer:spec-scaffold` | one-shot template instantiation (called by this) |
| `/steer:questions` | open-question sweep (behavior reused by this) |
| `/steer:build` | spec **and** build, PO-driven, ends in code PR |
| `/steer:drift` | later: compare this intent vs. as-built code |

## Wiring / rollout checklist

- New skill dir `skills/spec/SKILL.md`.
- Optional `commands/spec.md` alias.
- Router (`rules/00-router.md`) + commands list (`rules/15-commands.md`): add a
  one-liner — "Want to design a feature without building it? → `/steer:spec`."
- `plugin.json` version bump + `CHANGELOG.md` entry.
- Update `CLAUDE.md` skills list + layout comment.
```

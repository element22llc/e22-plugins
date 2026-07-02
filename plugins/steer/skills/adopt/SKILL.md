---
name: adopt
description: Adopt an existing repo that never went through bootstrap (a "vibe-coded" app) into the standards — reverse-engineer the /spec from the code, triage productionization (Keep/Refactor/Rewrite/Reject per area), and sync the plugin's bundled scaffolding without clobbering working code.
when_to_use: Use when a repo has working code but no /spec spine and no mise.toml, or when asked to adopt or onboard an existing app onto the standards.
allowed-tools:
  - Bash(git status *)
  - Bash(git switch *)
  - Bash(git checkout -b *)
  - Bash(git diff *)
  - Bash(git log *)
  - Bash(git show *)
  - Bash(git rev-parse *)
  - Bash(git mv *)
  - Bash(git add *)
  - Bash(git commit *)
  - Bash(mise install *)
  - Bash(mise lock *)
  - Bash(npm view *)
  - Bash(sh *scripts/template-reconcile.sh*)
  - Bash(python3 *scripts/scaffold_reconcile.py*)
---

# Adopt an existing repo into the standards

Bring a repo that never went through bootstrap — a "vibe-coded" app with
working code but no `/spec`, no `mise.toml`, no CI, no plugin install — into the
standards. You reverse the Greenfield spec flow: read the code, write the spec
**and the design** it implies, assess what's missing for production, and sync in
the scaffolding the plugin bundles. The result is a `feat/*` branch and a PR for
dev review — that review is the productionization gate.

This is whole-repo Brownfield adoption. For a brand-new repo (or a legacy
template fork), use `/steer:init` instead; for a single feature
change to an already-adopted repo, use the normal spec workflow
(`/steer:spec`).

## Non-negotiable guardrails (read first)

These govern **every** phase and outrank any procedural detail. If a step in the
runbook seems to conflict with one of these, the guardrail wins.

- **Decisions are recorded, never inferred — no fabricated ADRs.** As-built
  architectural choices are captured as **facts + evidence + conformance
  disposition + decision candidate** in `PRODUCTIONIZATION.md`, **not** as
  ratified ADRs. Code proves a choice *exists*, never *why* it was made or that
  anyone authorized it. An ADR is authored **only** when a human makes an explicit
  forward decision, and stays **`Proposed`** until the named decider accepts it —
  adoption never manufactures a rationale or an `Accepted` status from code alone,
  and PR approval does not ratify it.
- **Ask, don't invent — humans decide product intent.** Product intent and
  ambiguous behavior go to the human and to the owning feature's `## Open
  questions` (or `vision.md` for product-level) — never guessed into the spec.
  PO-acceptance boxes stay **unchecked**; the PO has not validated extracted
  intents. Run `/steer:questions` to resolve open questions.
- **Propose big restructures, don't force them.** Layout moves, rewrites, and
  risky changes are *proposed*; the dev's PR review is the hard gate. Never
  restructure silently.
- **Never clobber working code.** The app already runs — diff and ask before
  overwriting any existing file; reconcile scaffolding rather than replacing it. A
  reverse-engineered `DESIGN.md` is never overwritten by the template stub.
- **Never commit secrets; rotate the ones you find.** A committed credential is
  stop-and-rotate (secrets rule), not a quiet deletion.
- **Standards are not softened.** Adoption produces real spec, real tests, real
  Definition of Done — the same bar as any managed repo. Gaps are recorded, not waived.
- **Up-to-date by default; verify against the registry.** Flag outdated majors and
  superseded libraries from **live** registry data, not memory — but the dev owns
  the upgrade, on its own branch with tests green. Never bump majors silently.
- **Resume is additive, never destructive — and reconcile first.** On a re-run the
  first action is to reconcile `PRODUCTIONIZATION.md` against the current template
  (Phase 2) and splice in newly-added sections/rows **before** reading the
  checklist or proposing next steps. Never overwrite filled-in analysis; never
  restart from scratch.

Work on a `feat/adopt` branch — **never commit to `main`** (commit-autonomy
rule). Commit the reverse-engineered spine + scaffold as coherent units without
asking; **push and the PR wait for the dev** (the one publishing step Commit
autonomy gates).

## Resuming? Reconcile before anything else

If `/spec/PRODUCTIONIZATION.md` **or** the older `/spec/PRODUCTION-READINESS.md`
exists, you are resuming a prior adoption — and that file may have been written
under an **older** plugin version whose template lacked sections this version
adds (the file was renamed `PRODUCTION-READINESS.md` → `PRODUCTIONIZATION.md` in
v1.22.0, so the old name on disk *is* a resume signal — Phase 2 `git mv`s it
first). **Before** you read its checklist, summarize status, or pick next steps,
your **first action** is to reconcile it against the current bundled template
(Phase 2). Do not skip this because the file "looks complete" — a newly added gate
is invisible *precisely because* it isn't in the file yet.

## Phase map

Execute these in order. Each phase below is a one-line summary; the **detailed
step-by-step procedure for every phase lives in
[`PROCEDURE.md`](${CLAUDE_PLUGIN_ROOT}/skills/adopt/PROCEDURE.md)** — read the
phase you are on there before executing it.

1. **Confirm it's an adoption case** — no `/spec`, no `mise.toml`, not a template
   fork; detect the stack; branch `feat/adopt`. → PROCEDURE Phase 1
2. **Reconcile the adoption checklist (resume safety)** — apply pending structural
   migrations from the ledger, then run the template-reconcile diff and splice in
   new sections. **Do this FIRST on a resume.** → PROCEDURE Phase 2
3. **Survey the codebase** — map apps, routes, handlers, data models, services,
   auth, env vars; list the user-facing features. → PROCEDURE Phase 3
4. **Reverse-engineer the product spec** — fill `vision.md` / `users.md` /
   `glossary.md` by interviewing the human; unknowns → `## Open questions`.
   → PROCEDURE Phase 4
5. **Extract a spec per feature** — `intent.md` + `contract.md` from the real
   code; PO-acceptance boxes stay unchecked. → PROCEDURE Phase 5
6. **Inventory as-built architectural choices** — record observation + evidence +
   disposition in `PRODUCTIONIZATION.md`; **no ADR from inference** (guardrails).
   → PROCEDURE Phase 6
7. **Capture the as-built design** — reverse-engineer `DESIGN.md` from real tokens
   (skip if no UI surface); never invent visual rules. → PROCEDURE Phase 7
8. **Triage productionization** — gap analysis vs standards; propose
   Keep/Refactor/Rewrite/Reject per area; committed secrets stop-and-rotate.
   → PROCEDURE Phase 8
9. **Check dependency freshness & flag bad practices** — live registry diff; flag
   raw SQL, untracked schema, swallowed errors, unvalidated boundaries.
   → PROCEDURE Phase 9
10. **Sync the bundled scaffolding** — bring in what the repo lacks from the
    scaffold + living-docs templates; reconcile, never clobber. → PROCEDURE Phase 10
11. **Reconcile layout** — relate code to `/apps` + `/packages` only where
    low-risk; propose large restructures. → PROCEDURE Phase 11
12. **Hand off** — stamp `/spec/.version`, commit on `feat/adopt`, propose the
    PR after dev confirmation, optionally `publish-adoption`. → PROCEDURE Phase 12
13. **Recommend the next action** — emit the `## Recommended next actions` block
    from the observed adoption state. → PROCEDURE Phase 13

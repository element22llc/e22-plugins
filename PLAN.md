# Steer improvement plan — easier, faster, more efficient, better results

> **ARCHIVED 2026-07-21 — plan complete.** All four phases closed: Phase 0
> (instrumentation), Phase 1 (always-on weight, close-out below), Phase 2
> (progressive disclosure — tiered `/steer:help`, lite mode; the item-3
> onboarding card was redesigned during Phase 1: orient-session stays a banner
> printer and its orientation notices carry the intent), Phase 3 (Spec Kit
> rigor, shipped in v3.20.0), Phase 4 (routing eval + budget ratchets run
> permanently in `mise run check`/`ci`; the two remaining items — the
> `check_context_budget.py --report` table in release-PR bodies and the
> misrouting-report invite at the end of `next`/`help` — landed with this
> archive change). Kept at this path because
> shipped hooks/scripts/fixtures cite "PLAN.md Phase N" in comments; the file
> is historical context only, not an active work queue.

Derived from a usability comparison of steer against **OpenSpec** (Fission-AI)
and **GitHub Spec Kit**, plus measurements of this repo. The comparison's
verdict: steer wins on breadth (full SDLC, org standards, PO-facing flows,
plain-language routing) but loses to the lean SDD toolkits on time-to-first-value,
always-on weight, and per-spec rigor ceremony. This plan closes those gaps
without giving up steer's breadth.

## Baseline measurements (2026-07-19, steer v3.19.0)

| Metric | Today | Target |
|---|---|---|
| SessionStart rules injection | ~60 KB (~15k tokens) every session | ~62 KB reached; deeper cuts rejected (see Phase 1 close-out) |
| `rules/*.md` total | 69 KB across 24 files | 61,786 B end-state; ratchet 62,500 |
| Skill frontmatter descriptions (always-on for routing) | ~1–3.6 KB each, ~25–30 KB total | ≤ 400 B each, ≤ 10 KB total |
| Largest SKILL.md bodies | issues 26 KB, audit 24 KB, sync 21 KB, work 21 KB, build 21 KB | ≤ 12 KB slim front + on-demand reference |
| SessionStart hook scripts | 7 separate `sh` processes per startup | 1 orchestrator, < 1 s wall time |
| Skills exposed to users | 24 user-invocable | 5–7 "front door", rest reached via router/front doors |
| Time to first approved spec on a fresh repo | requires init/adopt first | ≤ 5 min, no scaffold required (lite mode) |

Every phase lands as normal `feat/*` PRs with `CHANGELOG.md` `[Unreleased]`
entries per repo policy; version bump happens once at release.

---

## Phase 0 — Instrument before optimizing (1 PR) — ✅ DONE

The repo has fixtures + hooktests but no token or latency budget. Landed:

- **Token budget check**: `scripts/check_context_budget.py` gates the
  concatenated `rules/*.md` bytes and the total skill-listing
  (description + when_to_use) chars. Ceilings are a **ratchet** set at the
  measured baseline + small headroom (71,000 B rules / 19,000 ch listing) so
  weight can't grow; Phase 1 lowers them as reductions land. The plan targets
  are reported (`--report` prints the markdown budget table for release PRs)
  but not enforced. Wired into `mise run check` via `plugin-check`.
- **Routing eval fixtures**: 46 plain-language asks → owning skill with signal
  keywords, in `tests/fixtures/routing/asks.yml`, validated by
  `scripts/check_routing_fixtures.py`: every signal must survive in the
  always-on routing surface (00-router.md + the skill's description/
  when_to_use), with a 40-fixture floor so coverage can't be deleted to make a
  trim pass. This is the regression net for Phases 1–2.
- **Hook latency budget**: `tests/test_hook_latency.py` times the full
  SessionStart startup chain (pinned to hooks.json so new hooks can't dodge
  it) against a 2 s tripwire budget (baseline ~200 ms), overridable via
  `STEER_HOOK_LATENCY_BUDGET_MS`. Lives in the pytest tier, not
  `hooks/tests/run.sh` as originally sketched — POSIX sh has no portable
  sub-second clock.

Why first: Phases 1–2 aggressively cut always-on prose; without these gates we
can't tell "leaner" from "broken".

## Phase 1 — Faster & more efficient: cut the always-on weight (3–4 PRs) — ✅ DONE

Pass 1 landed: skill listing 17,950 → 10,867 chars (−39%, item 3 essentially
done — ceiling re-armed at 11,500); top-5 rules trimmed to imperatives
(69,335 → 65,508 B, ceiling re-armed at 66,500). Item 4 landed: the five
startup/resume session checks now run through one `session-checks.sh`
orchestrator (hooks.json: 7 → 3 SessionStart registrations; the checks stay
individually testable, and the orchestrator is sequencing-only —
failure-isolated, registration order, always exit 0). Item 5 landed with a
design correction: orient-session turned out to derive almost nothing (it is a
banner printer), and `/steer:next` is contractually read-only so it cannot
write a `/spec/.state` cache — the real cost was the model re-deriving local
state call-by-call. Shipped instead as a one-shot read-only
`scripts/workspace-snapshot.sh` that gathers all local dimensions in a single
call, with `/steer:next` fetching only live PR/tracker state separately
(batched, minimal output). Pass 2 (items 1–2 continued) trimmed the next tier
of rules (autonomous-loops, context-hygiene, artifacts, layout, worktrees,
housekeeping, practices, living-docs) to 61,786 B total (ceiling re-armed at
62,500).

**The 30 KB rules target is retired — Phase 1 closes at the measured
end-state.** Two trim passes over every compressible rule landed at 61,786 B
(−11% from 69,335, zero behavior change); the surviving prose is
imperative-dense, so further wording cuts would drop constraints, not fat.
Demoting whole rules from always-on to on-demand was then investigated for
the candidates (`88-artifacts`, `24-worktrees`, `26-context-hygiene`,
`90-design-sources`, `15-commands`) and **rejected**: rule 88 is the ambient
authority ten-plus skill bodies defer to by name (ARTIFACTS.md calls it "the
lean always-on version" of itself), and the others fire exactly when no skill
is mediating (parallel-worktree cleanup, long-session hygiene, ad-hoc UI
coding, wrong-toolchain commands) — each earns its ~1.5–2 KB ambient slot.
The rules ratchet holds at 62,500 B; the listing surface finished at 10,867
ch against its 10,000 target. Phase 1 is **done**.

This is the largest single win. OpenSpec's whole footprint is two slash
commands and plain Markdown; steer spends ~20k tokens before the user types
anything.

1. **Trim `rules/` to imperative one-liners** (biggest files first:
   `00-router` 6 KB, `45-commit-autonomy` 4.6 KB, `30-spec-workflow` 4.2 KB,
   `10-stack` 4.2 KB). Push explanatory prose into `templates/reference/*`
   surfaced via `/steer:reference`; rules keep only the imperative + a pointer.
   Dedupe rules text that skill bodies repeat (spec workflow, commit autonomy,
   issue-first all restate their owning skill).
2. **Compress the router table** in `00-router.md`: one line per intent
   cluster, not per skill; `/steer:help` (on-demand) carries the full
   human-readable table so nothing is lost, it just stops being always-on.
3. **Cap skill descriptions at ~400 bytes**: description = what it does + one
   "use when" sentence. Move disambiguation prose ("not for X, that is
   /steer:Y") into the skill body's opening section, which loads only on
   invocation. Enforce via the Phase 0 budget check. Validate against the
   routing eval after each batch.
4. **Consolidate SessionStart hooks**: merge the 6 startup/resume check scripts
   into one `session-checks.sh` orchestrator (single process, shared repo-state
   scan, sequential early-exit) behind the existing `sh` prefix convention.
   Keep `inject-standards.sh` separate (different matcher includes `compact`).
   PreToolUse checks (`check-version-pins.sh`, `check-write-nudges.sh`,
   `check-bash-actions.sh`) get a cheap first-line guard so the common case
   exits before any real work.
5. **Persist workspace state for `/steer:next` and `orient-session.sh`**: both
   reconstruct branch/spec/tracker state cold every time. Cache the derived
   snapshot in `/spec/.state` (gitignored) with mtime-based invalidation so
   repeat navigation is a file read, not a re-derivation, and tracker reads go
   through `/steer:tracker-sync` with `minimal_output` + batched calls.

## Phase 2 — Easier to use: progressive disclosure (2–3 PRs) — ✅ DONE

Steer's 24-skill surface is its biggest learning-curve liability; the router
offsets it but the surface still leaks (help output, docs, frontmatter).

1. **Tier the skill surface.** Front door of 5–7 skills users should ever need
   to know: `setup`, `spec`, `work`, `next`, `help`, `status` (+ `build` for
   POs). Demote the rest to router-reached: keep them invocable but group
   `/steer:help` output by journey (Start → Spec → Build → Track → Report →
   Govern) with the front door first and an "advanced" fold for the rest.
   Candidates for `user-invocable: false` alongside the existing gateways:
   `spec-scaffold` (already), `tracker-sync` (already), and evaluate `adr`,
   `standards`, `report` for front-door demotion (still invocable, just not
   headlined).
2. **Lite mode — compete with OpenSpec's time-to-first-value.** Let
   `/steer:spec` run on an unmanaged repo without demanding init/adopt: create
   only `spec/<feature>/intent.md` (+ `contract.md` when warranted) from the
   bundled templates, skip mise/compose/CI scaffolding, and surface "graduate
   to full setup via /steer:setup" as the follow-up instead of a prerequisite.
   The unmanaged-repo hook nudge changes from "run setup first" to "spec-only
   is fine; setup unlocks the rest".
3. **First-session onboarding card.** `orient-session.sh` on a fresh repo
   prints a 5-line "what steer is, the 3 things you can say" card instead of
   the full standards preamble; detail stays in `/steer:help`.

## Phase 3 — Better results: adopt Spec Kit's per-spec rigor (2 PRs) — ✅ DONE (v3.20.0)

Spec Kit's differentiators are `/clarify` (structured de-ambiguation before
planning) and `/analyze` (cross-artifact consistency check). Steer has partial
analogues; make them first-class.

1. **`/steer:spec clarify` pass**: before intent approval, a structured sweep
   that interrogates the draft for the classic gap classes (edge cases, error
   paths, non-functional constraints, out-of-scope) and converts each gap into
   the existing open-question mechanism rather than free-form prose. This
   strengthens what `/steer:questions` later consumes.
2. **Cross-artifact analyze gate**: extend `/steer:spec validate` (or add
   `/steer:audit spec --pre`) to check intent ↔ contract ↔ tracker-issue
   consistency *before* implementation, not only as post-hoc drift detection:
   acceptance criteria with no contract behavior, contract behaviors with no
   acceptance criterion, tracker scope missing from intent.
3. **Acceptance-criteria quality checklist** baked into
   `templates/spec/intent.md` (testable, observable, bounded — the checklist
   Spec Kit ships in its templates), enforced as warnings by the validate pass.

## Phase 4 — Keep honest: evals and feedback loop (1 PR, then ongoing) — ✅ DONE

- Run the Phase 0 routing eval + budgets in CI permanently (`mise run ci`).
- Add a before/after token report to release PRs (the release skills already
  gate; append the budget numbers to the release notes) so context weight
  can't silently regress across releases.
- `/steer:report` already files plugin defects upstream; add a one-line prompt
  at the end of `next`/`help` runs inviting misrouting reports so routing-eval
  fixtures grow from real failures.

## Explicit non-goals

- **Multi-agent portability parity** (OpenSpec 25+/Spec Kit 35+ integrations):
  steer stays Claude-Code-first with the generated Copilot target. Broadening
  is a separate strategic decision, not a usability fix.
- **Dropping breadth**: no skill removals; the fix for surface size is tiering
  and routing, not amputation.
- **Renumbering rules** or restructuring the marketplace — out of scope.

## Sequencing & effort

| Phase | PRs | Depends on | Effort |
|---|---|---|---|
| 0 Instrument | 1 | — | S |
| 1 Context/speed | 3–4 | 0 | M–L (mostly prose surgery, gated by evals) |
| 2 Progressive disclosure | 2–3 | 1 (router table rewrite) | M |
| 3 Spec rigor | 2 | — (parallel to 1–2) | M |
| 4 Evals in CI | 1 | 0 | S |

Phases 1 and 3 are independent and can run in parallel streams. The release
that cuts Phase 1 should headline the context reduction ("steer now costs
~60% fewer always-on tokens") since every managed repo benefits immediately on
`/plugin update`.

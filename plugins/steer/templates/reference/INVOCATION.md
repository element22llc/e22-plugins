# Skill invocation matrix

How the `steer` skills are meant to be reached — by natural-language
inference vs. explicit user intent vs. internal orchestration only. This is
**guidance**, not an enforced gate: `user-invocable: false` only hides a skill
from the slash menu; it does not stop the model from invoking it, and no skill
sets `disable-model-invocation` — which is a standing rule here, not a state of
play (see "Why `disable-model-invocation` is never set" below).

Natural-language invocation is part of the plugin's mission, so the default is to
let the model route to the right skill from intent. The tiers below say where to
be *careful* about that.

## Tier 1 — safe to infer (read-only / navigation / reference)

Read-only or purely advisory; inferring them from a question is fine. Three carry a
caveat worth knowing before you infer them: `/steer:report` **auto-files** an
upstream issue with no confirmation step; `/steer:audit` will offer to write a
report file into `/spec`; and `/steer:doctor` will offer to **install system
software**. None of the three changes existing repo content, and the latter two
act only on an explicit yes.

| Skill | What it does |
|---|---|
| `/steer:reference [conventions\|traceability\|design-sources\|context-hygiene\|architecture-diagrams\|artifacts\|gates\|polyrepo]` | Reference prose by topic — conventions (versioning, toolchain, lint/test), traceability (living docs, tracker, drift gates), design-sources (design exports), context-hygiene (session/context discipline), architecture-diagrams (Mermaid/LikeC4 tiers), artifacts (rendering a shareable Claude Artifact), gates (the human-authority gate protocol), polyrepo (workspace/member topology). |
| `/steer:standards` | Re-loads the always-on rules on demand. |
| `/steer:next` | Read-only workspace navigator — never edits or publishes. |
| `/steer:audit` | Read-only health audit — reports, never edits. |
| `/steer:audit spec` | Read-only spec-vs-tracker comparison — reports, never edits. |
| `/steer:status` | Read-only delivery snapshot — reports, never edits. |
| `/steer:explain` | Renders **one feature's spec** as a stakeholder-readable Artifact — presentation only, never authoring. |
| `/steer:help` | Read-only orientation on the skills and where to start. |
| `/steer:doctor` | Diagnoses the local toolchain (git/mise/Docker) and, with a yes, installs **mise and the runtimes it manages**; git and Docker Desktop are handed over as commands to run yourself. |
| `/steer:report` | Files a bug about the steer plugin itself upstream in `e22-plugins`. |

## Tier 2 — requires explicit user intent (side-effecting)

These create files, edit the spec, generate code, commit, or move tracker state.
Invoke them when the user clearly asks for that outcome — not as a side effect of
an unrelated question.

| Skill | Side effect |
|---|---|
| `/steer:setup` | Auto-routing bootstrap front door — detects repo state and runs `init`/`adopt`/`sync`. |
| `/steer:init` | Bootstraps the repo (scaffold + spine). |
| `/steer:adopt` | Reverse-engineers spec + scaffolds an existing repo. |
| `/steer:sync` | Updates the plugin + reconciles spine/scaffold, lands a PR. |
| `/steer:tidy` | Moves/renames/deletes loose files. |
| `/steer:build` | PO build: spec → working app → PR. |
| `/steer:work` | Executes an issue end-to-end (branch → PR → transition); add `--reviewed` to run it through a review-gated loop (plan-gate + `/code-review` + bounded fix). |
| `/steer:spec` | Authors/iterates a feature spec. |
| `/steer:intake` | Absorbs a PO-supplied spec/roadmap document into `/spec` + the tracker. |
| `/steer:adr` | Creates a numbered ADR. |
| `/steer:issues` | Captures/triages/materializes GitHub issues. |
| `/steer:questions` | Resolves open questions, folding decisions into the spec. |
| `/steer:roadmap` | Builds/refreshes the release-milestone timeline from the spec. |
| `/steer:protect` | Sets/verifies GitHub branch protection (the PR gate). |
| `/steer:loop` | Scaffolds a scheduled autonomous-loop workflow — commits, pushes, opens a PR. |

## Tier 3 — internal orchestration only

Called by other skills, hidden from the slash menu (`user-invocable: false`).
Not a user's first move.

| Skill | Role |
|---|---|
| `/steer:tracker-sync` | The low-level GitHub tracker gateway. Driven by `issues` and `work`, and also by `spec`, `roadmap`, `questions`, `next`, `audit`, `status`, `build`, `intake`, and `init`/`adopt` (for `bootstrap-fields`). |
| `/steer:spec-scaffold` | The spec-file creator. Called by `spec`, `build`, `init`, `adopt` and `intake`. |

## Drift detection & auto-repair (managed repos)

A managed repo's live prose freezes its slash invocations at the plugin version that
wrote them. When a skill is renamed, folded into a `reference` mode, or turned
`user-invocable: false`, those frozen strings stop resolving — and Claude Code has no
built-in check that a referenced skill exists. `scripts/scan-invocations.sh` (read-only,
plugin-internal) closes that gap for **`/steer:sync`** (its invocation-hygiene step). It
derives the *valid* surface **live from the plugin** — skill directory names, the
`user-invocable: false` set, and the `reference` modes from the `<!-- steer:modes … -->`
marker — so its verdicts never go stale as skills change.

**Scan scope (false-positive guard).** It reads only unambiguously *live* instruction
surfaces: `CLAUDE.md`, `README.md`, `.github/pull_request_template.md`. It deliberately
skips append-only/provenance prose (`spec/history/*`, `spec/HISTORY.md`, `spec/AUDIT-REPORT.md`, `spec/DRIFT-REPORT.md`,
`spec/decisions/*` ADRs, `spec/sources/*`, `spec/reference/*`, feature `intent.md`
provenance) — a past `e22-adopt` mention there records what was run and must not be
rewritten. The marketplace id `e22-plugins` is never flagged.

**Classes** (one TAB line per problem occurrence:
`<file>\t<lineno>\t<found>\t<class>\t<suggested-fix>`; a valid invocation emits nothing):

| Class | Meaning | Repair |
|---|---|---|
| `legacy-e22` | a pre-rebrand prefix whose `<skill>` still resolves — bare `e22-<skill>`, or the plugin's own former name qualifying it, `e22-standards:e22-<skill>` and `e22-standards:<skill>` (the token is the one **after** the colon, never `standards`). Old-token forms are written here **without** the leading `/`, as in `MIGRATIONS.md`, so this file passes the stale-`/e22-*` lint guard; in a managed repo they carry it | **deterministic** — rewrite to `/steer:<skill>` |
| `reference-mode` | `<mode>` is a `reference` topic, not a skill — whether written `/steer:<mode>` or with a legacy prefix | **deterministic** — rewrite to `/steer:reference <mode>` |
| `noncallable-gateway` | `<skill>` is `user-invocable: false` (a user can't type it) — again whichever prefix it arrives with | **human decision** — route to a front door (e.g. `spec-scaffold`→`/steer:spec`, `tracker-sync`→`/steer:issues`); the swap changes meaning, so propose, don't auto-rewrite |
| `unknown` | a token resolving to no skill and no mode (e.g. a removed skill) | **surface only** — the dev decides |

`/steer:sync` auto-applies the two deterministic classes read-then-propose on its PR
branch and surfaces the other two for the dev. The version-keyed one-shot for the
`reference`-mode renames is the v3.8.0 entry in [MIGRATIONS.md](MIGRATIONS.md); this
detector is the standing every-sync backstop. Keep this class vocabulary in lockstep
with `scripts/scan-invocations.sh`.

## Why `disable-model-invocation` is never set

Anthropic recommends manual-only invocation for side-effecting task skills, and
the flag is tempting for a second reason: it drops a skill's description from the
listing, which is a budget that runs close to full. steer sets it on **no skill**,
and that is a rule rather than a not-yet.

The flag makes a skill **user-only** — "Only you can invoke the skill" — so Claude
cannot reach it through the Skill tool at all. Natural-language routing is core to
this plugin: every user-invocable skill is a model-invocation target (rule
`00-router` routes from the skill listing), including the ones that look manual (`setup`, `protect`, `help`).

The **Tier-3 internal helpers are the worst candidates, not the safest ones.**
`tracker-sync` and `spec-scaffold` are already `user-invocable: false`, so they are
hidden from the slash menu and reached only when another skill routes to them.
Adding `disable-model-invocation` would close the one remaining door and strand
them: invisible to the user *and* unreachable by the model.

Trim the listing budget at the source — shorter descriptions — never by hiding a
skill from the model.

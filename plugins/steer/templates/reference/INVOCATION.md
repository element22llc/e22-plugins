# Skill invocation matrix

How the `steer` skills are meant to be reached — by natural-language
inference vs. explicit user intent vs. internal orchestration only. This is
**guidance**, not an enforced gate: `user-invocable: false` only hides a skill
from the slash menu; it does not stop the model from invoking it, and no skill
sets `disable-model-invocation` today (see "Why not disabled yet" below).

Natural-language invocation is part of the plugin's mission, so the default is to
let the model route to the right skill from intent. The tiers below say where to
be *careful* about that.

## Tier 1 — safe to infer (read-only / navigation / reference)

Read-only or purely advisory; inferring them from a question is fine.

| Skill | What it does |
|---|---|
| `/steer:reference [conventions\|traceability\|design-sources]` | Reference prose by topic — conventions (versioning, toolchain, lint/test), traceability (living docs, tracker, drift gates), design-sources (design exports). |
| `/steer:standards` | Re-loads the always-on rules on demand. |
| `/steer:next` | Read-only workspace navigator — never edits or publishes. |
| `/steer:audit` | Read-only health audit — reports, never edits. |
| `/steer:audit spec` | Read-only spec-vs-tracker comparison — reports, never edits. |

## Tier 2 — requires explicit user intent (side-effecting)

These create files, edit the spec, generate code, commit, or move tracker state.
Invoke them when the user clearly asks for that outcome — not as a side effect of
an unrelated question.

| Skill | Side effect |
|---|---|
| `/steer:init` | Bootstraps the repo (scaffold + spine). |
| `/steer:adopt` | Reverse-engineers spec + scaffolds an existing repo. |
| `/steer:sync` | Updates the plugin + reconciles spine/scaffold, lands a PR. |
| `/steer:tidy` | Moves/renames/deletes loose files. |
| `/steer:build` | PO build: spec → working app → PR. |
| `/steer:work` | Executes an issue end-to-end (branch → PR → transition); add `--reviewed` to run it through a review-gated loop (plan-gate + `/code-review` + bounded fix). |
| `/steer:spec` | Authors/iterates a feature spec. |
| `/steer:spec-scaffold` | Creates a feature's spec files. |
| `/steer:adr` | Creates a numbered ADR. |
| `/steer:issues` | Captures/triages/materializes GitHub issues. |
| `/steer:questions` | Resolves open questions, folding decisions into the spec. |

## Tier 3 — internal orchestration only

Called by other skills, hidden from the slash menu (`user-invocable: false`).
Not a user's first move.

| Skill | Role |
|---|---|
| `/steer:tracker-sync` | The low-level GitHub tracker gateway `issues`/`work` call. |
| `/steer:spec-scaffold` | The spec-file creator `spec`/`adopt` call. |

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
skips append-only/provenance prose (`spec/HISTORY.md`, `spec/reports/*`,
`spec/decisions/*` ADRs, `spec/sources/*`, `spec/reference/*`, feature `intent.md`
provenance) — a past `e22-adopt` mention there records what was run and must not be
rewritten. The marketplace id `e22-plugins` is never flagged.

**Classes** (one TAB line per problem occurrence:
`<file>\t<lineno>\t<found>\t<class>\t<suggested-fix>`; a valid invocation emits nothing):

| Class | Meaning | Repair |
|---|---|---|
| `legacy-e22` | a pre-rebrand `e22-<skill>` prefix whose `<skill>` still resolves | **deterministic** — rewrite to `/steer:<skill>` |
| `reference-mode` | a bare `steer:<mode>` where `<mode>` is a `reference` topic, not a skill | **deterministic** — rewrite to `/steer:reference <mode>` |
| `noncallable-gateway` | `/steer:<skill>` where `<skill>` is `user-invocable: false` (a user can't type it) | **human decision** — route to a front door (e.g. `spec-scaffold`→`/steer:spec`, `tracker-sync`→`/steer:issues`); the swap changes meaning, so propose, don't auto-rewrite |
| `unknown` | a token resolving to no skill and no mode (e.g. a removed skill) | **surface only** — the dev decides |

`/steer:sync` auto-applies the two deterministic classes read-then-propose on its PR
branch and surfaces the other two for the dev. The version-keyed one-shot for the
`reference`-mode renames is the v3.8.0 entry in [MIGRATIONS.md](MIGRATIONS.md); this
detector is the standing every-sync backstop. Keep this class vocabulary in lockstep
with `scripts/scan-invocations.sh`.

## Why `disable-model-invocation` is not set yet

Anthropic recommends manual-only invocation for side-effecting task skills. We
deliberately do **not** flip `disable-model-invocation: true` broadly yet:
natural-language routing is core to this plugin, and disabling it on the Tier-2
workflows would make a PO unable to say "build me X" and have `build` engage.
If we adopt it, the safe first candidates are the **Tier-3 internal helpers**
(`tracker-sync`, `spec-scaffold`) — never the top-level workflows — and
only after testing the behavior in Claude Code.

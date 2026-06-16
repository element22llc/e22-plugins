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
| `/steer:conventions` | Reference prose (versioning, toolchain, lint/test). |
| `/steer:traceability` | Reference prose (living docs, tracker, drift gates). |
| `/steer:design-sources` | Reference prose (design exports). |
| `/steer:standards` | Re-loads the always-on rules on demand. |
| `/steer:next` | Read-only workspace navigator — never edits or publishes. |
| `/steer:audit` | Read-only health audit — reports, never edits. |
| `/steer:drift` | Read-only spec-vs-tracker comparison — reports, never edits. |

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
| `/steer:work` | Executes an issue end-to-end (branch → PR → transition). |
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

## Why `disable-model-invocation` is not set yet

Anthropic recommends manual-only invocation for side-effecting task skills. We
deliberately do **not** flip `disable-model-invocation: true` broadly yet:
natural-language routing is core to this plugin, and disabling it on the Tier-2
workflows would make a PO unable to say "build me X" and have `build` engage.
If we adopt it, the safe first candidates are the **Tier-3 internal helpers**
(`tracker-sync`, `spec-scaffold`) — never the top-level workflows — and
only after testing the behavior in Claude Code.

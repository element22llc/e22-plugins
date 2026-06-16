# Skill invocation matrix

How the `e22-standards` skills are meant to be reached — by natural-language
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
| `/e22-standards:e22-conventions` | Reference prose (versioning, toolchain, lint/test). |
| `/e22-standards:e22-traceability` | Reference prose (living docs, tracker, drift gates). |
| `/e22-standards:e22-design-sources` | Reference prose (design exports). |
| `/e22-standards:e22-standards` | Re-loads the always-on rules on demand. |
| `/e22-standards:e22-next` | Read-only workspace navigator — never edits or publishes. |
| `/e22-standards:e22-audit` | Read-only health audit — reports, never edits. |
| `/e22-standards:e22-drift` | Read-only spec-vs-tracker comparison — reports, never edits. |

## Tier 2 — requires explicit user intent (side-effecting)

These create files, edit the spec, generate code, commit, or move tracker state.
Invoke them when the user clearly asks for that outcome — not as a side effect of
an unrelated question.

| Skill | Side effect |
|---|---|
| `/e22-standards:e22-init` | Bootstraps the repo (scaffold + spine). |
| `/e22-standards:e22-adopt` | Reverse-engineers spec + scaffolds an existing repo. |
| `/e22-standards:e22-sync` | Updates the plugin + reconciles spine/scaffold, lands a PR. |
| `/e22-standards:e22-tidy` | Moves/renames/deletes loose files. |
| `/e22-standards:e22-build` | PO build: spec → working app → PR. |
| `/e22-standards:e22-work` | Executes an issue end-to-end (branch → PR → transition). |
| `/e22-standards:e22-spec` | Authors/iterates a feature spec. |
| `/e22-standards:e22-spec-scaffold` | Creates a feature's spec files. |
| `/e22-standards:e22-adr` | Creates a numbered ADR. |
| `/e22-standards:e22-issues` | Captures/triages/materializes GitHub issues. |
| `/e22-standards:e22-questions` | Resolves open questions, folding decisions into the spec. |

## Tier 3 — internal orchestration only

Called by other skills, hidden from the slash menu (`user-invocable: false`).
Not a user's first move.

| Skill | Role |
|---|---|
| `/e22-standards:e22-tracker-sync` | The low-level GitHub tracker gateway `e22-issues`/`e22-work` call. |
| `/e22-standards:e22-spec-scaffold` | The spec-file creator `e22-spec`/`e22-adopt` call. |

## Why `disable-model-invocation` is not set yet

Anthropic recommends manual-only invocation for side-effecting task skills. We
deliberately do **not** flip `disable-model-invocation: true` broadly yet:
natural-language routing is core to this plugin, and disabling it on the Tier-2
workflows would make a PO unable to say "build me X" and have `e22-build` engage.
If we adopt it, the safe first candidates are the **Tier-3 internal helpers**
(`e22-tracker-sync`, `e22-spec-scaffold`) — never the top-level workflows — and
only after testing the behavior in Claude Code.

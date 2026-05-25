# CLAUDE.md — e22-plugins

This repo is the **Element 22 plugin marketplace** for Claude Code and Cowork.
It is not a product; it is the substrate every product Claude session loads.

The always-loaded operating rules live in [`CONSTITUTION.md`](./CONSTITUTION.md).
The full operational spec — branch metadata, the five enforcement layers, the
Handoff Bundle, scaled approvals, runtime guarantees, invariants — lives in
[`docs/collaborative-ai-workflow-spec.md`](./docs/collaborative-ai-workflow-spec.md).
When the constitution and the spec disagree, the spec wins.

---

## Auto-trigger skills — name them, don't make users type slash commands

This marketplace ships **auto-triggered SKILL.md files** that match plain-language
intent and route to the right plugin command. A Product Owner saying *"can we
try a different checkout"* should not have to know that `/vibe` exists. An
engineer saying *"let's review PR #42"* should not have to type `/validate`.

When user phrasing matches one of the triggers below, invoke the skill via the
**Skill tool** before doing anything else. Do not require the user to type the
slash command. The slash command is the same flow for users who already know
the vocabulary — the skill is the on-ramp for users who don't.

| Skill | Plugin | Intent it auto-detects | Routes to |
|---|---|---|---|
| `change-idea-intake` | prototype-lane | "I wish X did Y", "could we make X different", "what if we tried Z" | `/vibe` |
| `proposal-glossary` | prototype-lane | "what's the Spine", "what's vibe-coding", "what's Keep vs Refactor" | (glossary answer, in-place) |
| `proposal-intake` | production-lane | "let's add X", "implement Y", "ship a change to do Z", "fix bug W", "create a PR for V" | `/propose` |
| `validation-decision` | production-lane | "let's review PR #N", "I'll evaluate the handoff", "is this Keep or Refactor" | `/validate` |
| `feature-flag-promotion` | production-lane | "promote X to 50%", "graduate from experimental", "ramp the flag" | `/promote` |
| `spine-staleness-cue` | spine-writer | "the spec is stale", "spine drift", "regenerate the spec for this branch" | `/spine-refresh` |

**Routing rules between skills:**

- *Exploratory* phrasing ("can we try", "what if we", "show me three variants")
  → `change-idea-intake` → prototype lane, even if the speaker is an engineer.
- *Committed* phrasing ("we need to ship", "this has to land in main")
  → `proposal-intake` → production lane, even if the speaker is a PO.
- *Reviewing a packaged handoff* → `validation-decision`, never
  `proposal-intake` — the prototype is the spec; don't re-propose it.
- *Sensitive domains* (auth, payments, PII, permissions, billing, data model):
  every skill refuses to generate code without `branch.yaml#sensitivity:
  sensitive` declared explicitly (spec §9.7, invariant #12).
- *Just venting / asking a question*: do not auto-invoke any skill. Confirm
  intent first; treat the brief acknowledgment described in each SKILL.md as
  mandatory, not optional.

## Hook-based plugins — auto-detection is at the tool layer, not the prompt

Four house-rule plugins auto-fire on **harness events**, not user wording, and
deliberately have no intent skills:

| Plugin | Substrate | Fires on |
|---|---|---|
| `spec-driven-dev` | PreToolUse + UserPromptSubmit | Every Write/Edit/MultiEdit; every prompt (lane announcement) |
| `always-test` | PostToolUse + Stop | Every Write/Edit/MultiEdit; session end (smoke-test reminder) |
| `house-style` | PostToolUse | Every Write/Edit/MultiEdit |
| `security-rails` | PreToolUse | Every Write/Edit/MultiEdit and Bash |

This is intentional. Per spec §8.1, AI Instructions are soft — bypassable. Hooks
are hard — the harness runs them, not Claude. Safety-bearing rules must live in
the hook layer or below. Do not paper over a hook gap with a skill.

---

## The non-negotiables (full list in [spec §10](./docs/collaborative-ai-workflow-spec.md#10-invariants-non-negotiable-rules))

1. No prototype branch ever touches production data, auth, or secrets — enforced
   at the infrastructure layer (spec §9.9), not by Claude refusal alone.
2. No direct pushes to `main`. Production-touching changes go through a PR.
3. The lane is a property of the branch, declared in `/.workflow/branch.yaml`
   — not the person, not the branch's origin.
4. Chat history is not canonical. Only the repo (Spine, ADRs, branch metadata,
   Handoff Bundle) is durable memory. *Chats propose; the repo records.*
5. Every rule in the plugin pack maps to at least one hard enforcement layer
   (Repo Contract, CI Policy, App Guard, or Review Rule). AI Instructions
   alone are never load-bearing for safety.

---

## When working *in this repo* (the marketplace itself)

This repo's own changes go through normal `feat/*` / `fix/*` branches off
`main`, not `prototype/*` — the marketplace itself ships at the speed of
governance. Changes to a plugin's behavior need a version bump in that
plugin's `plugin.json` and a note in the relevant README. New auto-trigger
skills go under `plugins/<plugin>/skills/<skill-name>/SKILL.md`, follow the
existing `change-idea-intake` shape (trigger phrases in `description`, *When
NOT to trigger* section, *What happens next* section), and must be listed in
the routing table above.

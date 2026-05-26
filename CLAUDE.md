# CLAUDE.md — e22-plugins

This repo is the **Element 22 plugin marketplace** for Claude Code, Claude
Chat, and Claude Cowork. It is not a product; it is the substrate every
product Claude session loads.

The always-loaded operating rules live in [`CONSTITUTION.md`](./CONSTITUTION.md).
The full operational spec lives in
[`docs/collaborative-ai-workflow-spec.md`](./docs/collaborative-ai-workflow-spec.md).
When the constitution and the spec disagree, the spec wins.

---

## The workflow in one line

> Let the PO explore locally. Let Claude extract the meaning. Let engineering
> decide what becomes production.

POs install the always-on org plugin and start a brand-new MVP by talking
naturally — no commands, no skills to remember, no GitHub repository, no
branch metadata, no Product Spine maintenance. Engineering keeps full
governance, applied only when the work has been imported into a governed repo.

---

## The three zones

| Zone | Owner | Tooling | Control point |
|---|---|---|---|
| **Local MVP Sandbox** | PO | Claude, local folders, disposable previews | Always-on org plugin guardrails |
| **Handoff / Extraction** | Claude + Dev | `HANDOFF.md` at workspace root, optional assets, optional source export | Dev reviews the handoff packet before code |
| **Governed Production** | Dev | GitHub, PRs, branch protection, CI/CD, review rules | Checks, approvals, rollback |

Zone detection is implemented once in `plugins/e22-org/lib/zone.sh`. A
workspace is **governed** when it's a git repo whose `origin` remote points
at GitHub. Otherwise it's **sandbox**. Hook plugins source this helper and
self-gate; in the sandbox they go silent.

---

## The seven plugins

| Plugin | Profile | What it does |
|---|---|---|
| `e22-org` | always-on (PO + Dev) | Always-loaded `CLAUDE.md` baseline, sandbox guardrails (real PII / prod-DB connection strings), natural-language handoff trigger, shared `lib/zone.sh`. The PO's only required installation. |
| `security-rails` | always-on (PO + Dev) | Universal hard guardrails in both zones — secrets, AWS keys, Stripe live keys, raw-SQL interpolation, force-push, push-to-main. |
| `handoff-packager` | always-on (PO + Dev) | Per-section guidance for filling `HANDOFF.md`. Template lives in `e22-org/templates/`. Triggered by natural language, not a command. |
| `house-style` | always-on (PO + Dev) | Always-loaded tech-stack and latest-stable-version guidance in both zones; lint/format PostToolUse hook gated to governed zone only. |
| `always-test` | production (Dev) | Test-floor enforcement. Zone-gated — silent in sandbox, full enforcement (exit 2 / Stop-continue) in governed repos. |
| `spine-writer` | production (Dev) | Product Spine generation. Zone-gated. `/spine-refresh` refuses in sandbox. |
| `production-lane` | production (Dev) | `/validate` (Harden / Extract / Rewrite / Reject / Continue exploring), `/propose`, `/from-design`, `/promote`. Auto-trigger skills route Dev intent to the right command. |

**Install profiles** (documented; not enforced by the marketplace):

- **PO bundle:** `e22-org`, `security-rails`, `handoff-packager`, `house-style`.
- **Dev bundle:** all seven.

The four "always-on" plugins are safe in both zones; the three "production"
plugins are no-ops in the sandbox so installing the full Dev bundle is also
fine for a PO who wants one install.

---

## Auto-trigger skills

Three skills auto-fire on plain-language intent — all Dev-facing, all in
`production-lane`. POs do not need to know they exist; Devs benefit from
not having to type slash commands when intent is clear.

| Skill | Plugin | Intent it auto-detects | Routes to |
|---|---|---|---|
| `proposal-intake` | production-lane | "let's add X", "implement Y", "ship a change to do Z", "fix bug W", "create a PR for V" | `/propose` |
| `validation-decision` | production-lane | "let's review the handoff for X", "I'll evaluate the MVP", "is this Harden or Extract", "evaluate this prototype" | `/validate` |
| `feature-flag-promotion` | production-lane | "promote X to 50%", "graduate from experimental", "ramp the flag" | `/promote` |
| `spine-staleness-cue` | spine-writer | "the spec is stale", "spine drift", "regenerate the spec for this branch" | `/spine-refresh` |

Routing rules:

- *Exploratory* phrasing in the sandbox ("can we try", "what if we", "show me
  three variants") — Claude responds conversationally; no skill auto-fires.
- *Committed* production phrasing ("we need to ship", "this has to land in
  main") in a governed repo → `proposal-intake` → `/propose`.
- *Reviewing a HANDOFF.md* → `validation-decision`, never `proposal-intake`.
- *Sensitive domains* (auth, payments, PII, permissions, billing, data model):
  every skill refuses to generate production-bound code without explicit
  engineering review.
- *Just venting / asking a question*: do not auto-invoke any skill.

The natural-language handoff trigger ("handoff this", "package this for
dev", "I'm done with the MVP", etc.) is handled by `e22-org`'s
always-loaded `CLAUDE.md` plus its `handoff-cue.sh` UserPromptSubmit hook —
not by an auto-trigger skill. POs never need to know the mechanism.

---

## Hook-based plugins

Four plugins fire on **harness events**, not user wording.

| Plugin | Substrate | Zone gate | Fires on |
|---|---|---|---|
| `e22-org` | PreToolUse (Write/Edit) + UserPromptSubmit | none — both zones | Every edit and prompt |
| `security-rails` | PreToolUse (Write/Edit, Bash) | none — both zones | Every edit and Bash command |
| `always-test` | PostToolUse + Stop | governed only | Every edit and session end |
| `house-style` | PostToolUse | governed only | Every edit |
| `spine-writer` | PostToolUse | governed only | Meaningful edits |

Hooks are hard controls only where the Claude surface supports them — Claude
Code today. On Chat / Cowork / Artifacts the same rules apply as
instructions and reminders in always-loaded `CLAUDE.md` files. That
asymmetry is acceptable because the sandbox cannot deploy to production,
use real customer data, or access production credentials.

Per spec v0.4 §11.2, AI instructions are soft — bypassable. Safety-bearing
rules in the governed zone live in hooks or in the repo contract (branch
protection, CODEOWNERS, CI policies, review rules), never in instructions
alone.

---

## The non-negotiables

Spec v0.4 §12 boundaries that always hold:

1. Local MVP sandboxes do not deploy directly to production.
2. Local MVP sandboxes do not use production credentials or databases.
3. Local MVP sandboxes do not use real customer data or real PII.
4. Live auth, payment, billing, and permission integrations are forbidden
   in sandbox exploration.
5. Prototype code is disposable unless Dev explicitly accepts ownership.
6. `HANDOFF.md` is durable memory for the transition; chat history is not
   canonical.
7. Prototype shortcuts must be labeled in `HANDOFF.md` §9.
8. Production work uses GitHub PR governance.
9. No direct pushes to `main`.
10. Secrets never appear in code, PRs, comments, commit messages,
    `HANDOFF.md`, specs, or chat. Reference them via secret-store variable
    names only.
11. Sensitive production changes require explicit engineering review.
12. Infrastructure and environment-configuration changes require explicit
    human approval before modification.
13. Production safety rules need hard enforcement where possible: CI,
    branch protection, CODEOWNERS, secret scanning, review rules.

---

## When working *in this repo* (the marketplace itself)

This repo's own changes go through normal `feat/*` / `fix/*` branches off
`main`. Changes to a plugin's behavior need a version bump in that
plugin's `plugin.json` and a note in the relevant README or commit
message.

New auto-trigger skills go under `plugins/<plugin>/skills/<skill-name>/SKILL.md`,
follow the existing `validation-decision` shape (trigger phrases in the
`description` frontmatter, *When NOT to trigger* section, *What happens
next* section), and must be listed in the routing table above.

Hook scripts under `plugins/*/hooks/*.sh` must be executable. The
marketplace install does not chmod for you. Hooks parse the hook payload
from stdin with `python3`; if a target environment cannot rely on Python,
swap for `jq` or inline parsing.

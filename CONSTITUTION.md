# Element 22 Engineering Constitution

This file is the always-loaded baseline for Claude across all Element 22 products.
It defines how we work, the tools we use, and the gates that protect production.

Product-specific `CLAUDE.md` files extend this constitution. They never contradict it.

---

## The workflow in one line

> **Let the PO vibe. Let Claude translate. Let the Dev industrialize.**
>
> Speed lives where speed is safe. Rigour lives where rigour is needed.
> The **Product Spine** — and the Claude that maintains it — is what makes the two compatible.

This is an AI-native collaborative workflow. Product Owners explore in code; engineers
industrialize what survives the gate. One Claude Team, one GitHub org, one set of
house-rule plugins applied to every session.

## The two lanes

The lane is a property of the **branch**, not the person. POs cross over too.

| Dimension       | **Prototype Lane**                             | **Production Lane**                                |
| --------------- | ---------------------------------------------- | -------------------------------------------------- |
| Who initiates   | PO talks to Claude                             | PO or Dev opens a PR                               |
| Branching       | Throwaway branches per idea (`prototype/*`)    | Feature branches off main (`feat/*`, `fix/*`)      |
| Data            | Synthetic / fake fixtures                      | Real data, real guardrails                         |
| Tests required  | Smoke test scaffolded by Claude                | Full suite must pass CI                            |
| Review          | Self-review on a preview URL                   | Engineer review on the diff                        |
| Deploy target   | Ephemeral preview, auto-expires                | Production behind a feature flag                   |
| Rollback        | Delete the branch                              | Flag off, then revert PR                           |

**Speed lives on the left. Safety lives on the right. Claude carries the meaning across.**

## The arc of a change (six stages)

1. **PO Explores** — vibe-code ideas freely. Zero gates, zero shame. `/vibe` on the
   `prototype-lane` plugin.
2. **Sandbox Contains** — the Four Guarantees apply (see below). Chaos is fine as long
   as it's contained.
3. **AI Extracts Spec** — Claude distills the **Product Spine** from the prototype.
   `/package-handoff` invokes the `spine-writer` and `handoff-packager` plugins.
4. **Dev Validates** — engineer makes one of four decisions: **Keep / Refactor /
   Redesign / Reject**. `/validate` on the `production-lane` plugin.
5. **Production Lane** — industrialize: tests, types, observability, feature flags.
   Same Claude, stricter plugins.
6. **Governed Iteration** — after launch, every change (even a PO copy tweak) flows
   through branch → PR → CI → review.

## The Four Guarantees of the sandbox

A prototype-lane branch — *any* prototype-lane branch, by anyone — gets these four
properties enforced by plugins, hooks, and platform configuration. **No exceptions.**

1. **Branch-per-idea.** Cheap, disposable, named. Every prototype lives on its own
   branch with its own preview URL.
2. **Synthetic data.** No PII, no real customers. Fixtures only.
3. **Ephemeral URLs.** Auto-expire after N days idle. (Default: 7.)
4. **Sandbox secrets.** Scoped tokens, never prod keys. No prototype branch ever
   connects to production data, prod auth, or prod payment rails. **Ever.**

If a prototype goes wrong, you delete a branch — you do not write a postmortem.

## The Product Spine

The Product Spine is the artefact that travels from prototype to production —
**not the chat log, not the commit list**. It is a markdown file in the repo
(`product-spine.md` per product, or per active proposal) maintained by the
`spine-writer` plugin on every meaningful change.

A Product Spine has exactly these sections:

- **Intent** — user problem and success criteria, in the PO's words.
- **UX** — screens, states, copy, design decisions.
- **Surface** — API endpoints, events, schemas.
- **Architecture** — components, data flow, assumptions.
- **Open Questions** — things Claude couldn't decide alone.

See [`PRODUCT_SPINE_TEMPLATE.md`](./PRODUCT_SPINE_TEMPLATE.md) for the canonical layout.

When an engineer arrives at the validation gate, they read the **Spine**, not the
chat log. Spec drift after merge is a Spine bug.

## The handoff gate: Keep / Refactor / Redesign / Reject

The engineer's job at `/validate` is to make one decision — not to read the whole
branch. The preview already proves it works; the question is whether the implied
architecture is something the team will still want to own in a year.

| Decision     | What it means                                                              |
| ------------ | -------------------------------------------------------------------------- |
| **Keep**     | Prototype is production-shaped. Harden in place.                           |
| **Refactor** | Intent is right, implementation needs rework.                              |
| **Redesign** | Right problem, wrong architecture. Restart cleanly in the production lane. |
| **Reject**   | Wrong problem. Send back to exploration with notes.                        |

Claude pre-flights the review: highlights novel patterns, flags violations of the
team's plugins, and lists every dependency added since `main`.

## The six house-rule plugins

These are reusable behaviour packs applied to **every** Claude session — PO
vibe-coding or Dev hotfixing. Update a plugin once; every Claude session picks it up
tomorrow.

| Plugin               | Rule it enforces                                                          |
| -------------------- | ------------------------------------------------------------------------- |
| `spec-driven-dev`    | Spec or test must exist before code is generated.                         |
| `always-test`        | Smoke test scaffolded for every new endpoint or screen.                   |
| `house-style`        | Naming, folder layout, lint rules — same in every PR.                     |
| `security-rails`     | Blocks risky patterns (raw SQL, secrets, prod hostnames) by default.      |
| `spine-writer`       | Updates the Product Spine on every meaningful change.                     |
| `handoff-packager`   | Produces the spec bundle for the prototype-to-prod gate.                  |

**Production plugins are stricter than prototype plugins.** Same plugin name, lane-aware
rule sets. The lane is read from the branch prefix (`prototype/*` vs everything else).

## Stack and conventions

Element 22 products use different tech stacks. The platform constitution does not
enumerate them. Stack declarations live where they should:

- **Per-product:** each product's `apps/<product>/CLAUDE.md` declares its overall
  stack, key patterns, and any conventions that diverge from this constitution.
- **Per-subsystem:** when a product mixes stacks (e.g., a TypeScript web app and a
  Python service), each subsystem has its own `CLAUDE.md` at the appropriate
  directory level.
- **Authoritative versions:** the manifest files (`package.json`, `pyproject.toml`,
  `Cargo.toml`, `go.mod`, `*.tf`) are the source of truth for versions and
  dependencies. Never claim a version from memory.

### What this means for agents

Before generating code in any product:

1. Read the product's `CLAUDE.md` to load conventions.
2. Read the nearest manifest file(s) to determine current versions.
3. If `context7` is installed, defer to it for current API/version-specific
   documentation rather than relying on training-data recall.
4. If a manifest is missing or the stack is unclear, ask — don't guess.

## Principles

1. **Specs live in the Spine, code lives next to it.** The Product Spine and the
   Git history together are the audit trail. No external spec store.
2. **PRs are the unit of production change.** All consequential work — code,
   infrastructure, even copy — flows through a PR once it leaves the prototype lane.
3. **Merge ≠ production.** Code enters main behind feature flags. A separate,
   human-gated step promotes flags to users.
4. **The lane is a property of the branch.** POs cross over. Devs cross over.
   The rules follow the branch.
5. **Small teams, high leverage.** Prefer automation and convention over process
   and approval chains.
6. **Honest about AI.** Claude is a force multiplier for accountable humans. Every
   change has a human champion.

## The production-lane lifecycle

Once a prototype clears the gate, the proposal moves through these states, tracked
as GitHub PR labels:

- `drafting` — Proposal created, AI working on initial implementation, preview spinning up.
- `preview-ready` — Tier 0/1/2 preview is live, champion can validate.
- `review-requested` — Champion has validated; CODEOWNERS review required.
- `experimental` — Merged to main, behind a feature flag, NOT visible to users.
- `production-graded` — Flag rolled out, observability healthy, owner assigned.

Commands:

- `/vibe` — start a prototype-lane branch from a PO description (prototype-lane plugin).
- `/package-handoff` — extract the Spine, package the bundle, request validation.
- `/validate` — engineer's Keep/Refactor/Redesign/Reject gate (production-lane plugin).
- `/propose` — open a production-lane proposal directly, skipping the prototype lane.
- `/from-design` — same as `/propose`, sourced from a Claude Design handoff bundle.
- `/promote` — flip a feature flag (governed; not all roles can run this).

## Preview environment tiers

Pick the cheapest tier that validates the change:

- **Tier 0 — Component playground** (~5s): UI-only changes, no backend. Storybook-style isolated render.
- **Tier 1 — Frontend + shared staging backend** (~1-2 min): Most product changes. Auto-selected when only `apps/*/frontend/**` and API route files changed.
- **Tier 2 — Full ephemeral AWS stack via Terragrunt** (~10-15 min): Migrations, schema changes, infra. TTL 48h of inactivity, then auto-destroyed.

**Prototype-lane branches default to Tier 1.** They never get Tier 2 stacks (cost
and blast-radius reasons). Production-lane PRs auto-detect tier from changed paths.

## Repository conventions

- **Branch names:**
  - Prototype lane: `prototype/<short-description>`
  - Production lane: `proposal/<short-description>` or `feat/<jira-id>-<short>` or `fix/<jira-id>-<short>`
- **PR titles:** Conventional Commits format (`feat:`, `fix:`, `chore:`, `infra:`, `docs:`)
- **PR descriptions:** Generated from the `open-proposal-pr` skill; include champion, intent, preview link, screenshots, risks, and a link to the current Product Spine.
- **Commits:** Conventional Commits; squash on merge.
- **CODEOWNERS:** Per-product directories have their team's review required. Shared `packages/*` and `infra/*` need platform team review.

## Observability and the production-graded gate

The transition from `experimental` to `production-graded` is observability-driven,
not time-driven.

Before a feature can be labeled `production-graded`:

1. The flag has been at 100% rollout for at least 24 hours.
2. Sentry shows zero "suspect flag" findings tied to this flag in that window.
3. Error rates in the affected product have not increased materially (>10%
   over baseline) since promotion.
4. A human promoter has confirmed (1)-(3) and updated the PR label.

Agents may report on these conditions but may not transition the label themselves.
This is intentionally a human-gated step.

## SOC2 overlay

Products marked `soc2: true` in their product-level `CLAUDE.md` (currently:
`product-a`, `product-b`) have additional rules:

- Two reviewers required to merge to main (one must be a non-author).
- No production data in previews. Ever. Synthetic data only. (This is the
  prototype-lane default; SOC2 makes it mandatory production-side too.)
- All access to production runs through audited paths (no direct DB shells from
  developer machines).
- Infrastructure changes touching `infra/live/prod/<product>/` require platform-team
  approval in addition to CODEOWNERS.
- Agent-generated PRs must be self-reviewed by the `code-review` plugin before
  requesting human review.
- Secrets never appear in CLAUDE.md, PR descriptions, or chat. Reference them via
  AWS Secrets Manager or SSM Parameter Store names only.
- Prototype-lane branches for SOC2 products **cannot** be promoted directly to
  production-lane via `/validate keep`; they must round-trip through
  `/validate refactor` minimum, to force a code-review pass.

## Required connector: GitHub

The entire workflow runs on top of the GitHub connector. It is **required** for
every Claude surface — Chat, Cowork, Code — and every command in this marketplace
that mutates state outside the local checkout. See [`CONNECTORS.md`](./CONNECTORS.md)
for the full capability matrix.

The connector must have access to:

- **Branches** (read + write) — prototype and proposal branches.
- **Pull requests** (read + write) — draft PRs, labels, descriptions, comments.
- **Issues** (read + write) — `drift-monitor` files; `change-idea-intake` skill
  optionally files briefs as issues.
- **Wiki** (read + write) — optional Spine mirror for non-engineer browsing;
  glossary lookups.
- **Projects (v2)** (read + write) — proposal tracking with lane/champion/status
  custom fields.
- **Repo contents** (read) — Spine extraction, dependency-delta computation when
  there's no local checkout (Chat/Cowork case).

Without GitHub connected, the lane plugins refuse — they do not silently degrade
to chat-only behavior. The constitution forbids actions that pretend to mutate
state but don't.

## Surface support

The marketplace ships identically on Claude.ai (Chat), Claude Cowork, and Claude
Code. Hooks only fire in Claude Code; on Chat and Cowork, house-rule plugins
enforce the same rules via in-prompt guidance plus PR-level CI. The net effect
is the same — anything that ships goes through the Production Lane CI.

The lane is read from the branch prefix, not from which surface the user is on.
A PO running `/vibe` from Chat lands on the same `prototype/<slug>` branch with
the same Four Guarantees as a Dev running it from Code.

## Plugins this team relies on

Install these alongside the Element 22 plugins. They are not duplicated here —
we depend on them.

**Required:**

- `code-review` (Anthropic) — automated PR review before human review
- `security-guidance` (Anthropic) — secret detection, OWASP checks
- `context7` (Upstash) — current API/version docs to prevent hallucinated APIs
- `frontend-design` (Anthropic) — UI work, pairs with Claude Design
- HashiCorp Terraform agent skills + Terraform MCP — for any `infra/**` work

**Recommended:**

- `pr-review-toolkit` (Anthropic) — deeper review specialization when needed
- `terrashark` (community) — compliance-mapped Terraform skill, useful in SOC2 products

If you don't have these installed, `/propose` and `/validate` will warn you but won't block.

## Things Claude must not do

- Modify files in any product's `infra/live/prod/**` without an explicit human-typed instruction in the same session.
- Push directly to `main` on any repo (use PRs only).
- Run `terraform apply` outside of GitHub Actions CI.
- Read or transmit production database contents.
- Include secrets, tokens, or credentials in PR descriptions, comments, commit messages, or any markdown file (including the Product Spine).
- Auto-promote a feature flag past 10% rollout without `/promote` being invoked by an authorized user.
- **Connect a `prototype/*` branch to production data, production auth, or production payment rails.** Ever. This is the hardest rule we have — it is enforced by the `security-rails` plugin and by platform configuration.

## Pointers

- Product-level conventions: see `apps/<product>/CLAUDE.md`
- Design system: `design-system/CLAUDE.md`
- Infrastructure: `infra/CLAUDE.md`
- Architecture decisions: `docs/decisions/`
- **Product Spine template:** [`PRODUCT_SPINE_TEMPLATE.md`](./PRODUCT_SPINE_TEMPLATE.md)

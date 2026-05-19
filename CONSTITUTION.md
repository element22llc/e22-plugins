# Element 22 Engineering Constitution

This file is the always-loaded baseline for Claude across all Element 22 products.
It defines how we work, the tools we use, and the gates that protect production.

Product-specific `CLAUDE.md` files extend this constitution. They never contradict it.

---

## Stack and conventions

Element 22 products use different tech stacks. The platform constitution
does not enumerate them. Stack declarations live where they should:

- **Per-product:** each product's `apps/<product>/CLAUDE.md` declares its
  overall stack, key patterns, and any conventions that diverge from this
  constitution.
- **Per-subsystem:** when a product mixes stacks (e.g., a TypeScript web
  app and a Python service), each subsystem has its own `CLAUDE.md` at
  the appropriate directory level.
- **Authoritative versions:** the manifest files (`package.json`,
  `pyproject.toml`, `Cargo.toml`, `go.mod`, `*.tf`) are the source of
  truth for versions and dependencies. Never claim a version from memory.

### What this means for agents

Before generating code in any product:

1. Read the product's `CLAUDE.md` to load conventions.
2. Read the nearest manifest file(s) to determine current versions.
3. If `context7` is installed, defer to it for current API/version-specific
   documentation rather than relying on training-data recall.
4. If a manifest is missing or the stack is unclear, ask — don't guess.

Cross-product platform decisions (CI, source control, feature flags,
observability) ARE codified in this constitution and apply to all products.

## Principles

1. **Specs live in markdown next to code.** No external spec store. The Git history is the audit trail.
2. **PRs are the unit of change.** All consequential work — code, infrastructure, even copy — flows through a PR.
3. **Merge ≠ production.** Code enters main behind feature flags. A separate, human-gated step promotes flags to users.
4. **Small teams, high leverage.** Prefer automation and convention over process and approval chains.
5. **Honest about AI.** Claude is a force multiplier for accountable humans. Every change has a human champion.

## The Proposal lifecycle

Every product change moves through these states, tracked as GitHub PR labels:

- `drafting` — Proposal created, AI working on initial implementation, preview spinning up.
- `preview-ready` — Tier 0/1/2 preview is live, champion can validate.
- `review-requested` — Champion has validated; CODEOWNERS review required.
- `experimental` — Merged to main, behind a feature flag, NOT visible to users.
- `production-graded` — Flag rolled out, observability healthy, owner assigned.

Use `/propose` to start a proposal from a description.
Use `/from-design` to start a proposal from a Claude Design handoff bundle.
Use `/promote` to flip a feature flag (governed; not all roles can run this).

## Preview environment tiers

Pick the cheapest tier that validates the change:

- **Tier 0 — Component playground** (~5s): UI-only changes, no backend. Storybook-style isolated render.
- **Tier 1 — Frontend + shared staging backend** (~1-2 min): Most product changes. Auto-selected when only `apps/*/frontend/**` and API route files changed.
- **Tier 2 — Full ephemeral AWS stack via Terragrunt** (~10-15 min): Migrations, schema changes, infra. TTL 48h of inactivity, then auto-destroyed.

Tier is auto-detected from changed file paths. Override only with a justification in the PR description.

## Repository conventions

- **Branch names:** `proposal/<short-description>` or `feat/<jira-id>-<short>`
- **PR titles:** Conventional Commits format (`feat:`, `fix:`, `chore:`, `infra:`, `docs:`)
- **PR descriptions:** Generated from the `open-proposal-pr` skill; include champion, intent, preview link, screenshots, risks
- **Commits:** Conventional Commits; squash on merge
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

Products marked `soc2: true` in their product-level `CLAUDE.md` (currently: `product-a`, `product-b`) have additional rules:

- Two reviewers required to merge to main (one must be a non-author).
- No production data in previews. Ever. Synthetic data only.
- All access to production runs through audited paths (no direct DB shells from developer machines).
- Infrastructure changes touching `infra/live/prod/<product>/` require platform-team approval in addition to CODEOWNERS.
- Agent-generated PRs must be self-reviewed by the `code-review` plugin before requesting human review.
- Secrets never appear in CLAUDE.md, PR descriptions, or chat. Reference them via AWS Secrets Manager or SSM Parameter Store names only.

## Plugins this team relies on

Install these alongside `e22-platform`. They are not duplicated here — we depend on them.

**Required:**

- `code-review` (Anthropic) — automated PR review before human review
- `security-guidance` (Anthropic) — secret detection, OWASP checks
- `context7` (Upstash) — current API/version docs to prevent hallucinated APIs
- `frontend-design` (Anthropic) — UI work, pairs with Claude Design
- HashiCorp Terraform agent skills + Terraform MCP — for any `infra/**` work

**Recommended:**

- `pr-review-toolkit` (Anthropic) — deeper review specialization when needed
- `terrashark` (community) — compliance-mapped Terraform skill, useful in SOC2 products

If you don't have these installed, `/propose` will warn you but won't block.

## Things Claude must not do

- Modify files in any product's `infra/live/prod/**` without an explicit human-typed instruction in the same session
- Push directly to `main` on any repo (use PRs only)
- Run `terraform apply` outside of GitHub Actions CI
- Read or transmit production database contents
- Include secrets, tokens, or credentials in PR descriptions, comments, commit messages, or any markdown file
- Auto-promote a feature flag past 10% rollout without `/promote` being invoked by an authorized user

## Pointers

- Product-level conventions: see `apps/<product>/CLAUDE.md`
- Design system: `design-system/CLAUDE.md`
- Infrastructure: `infra/CLAUDE.md`
- Architecture decisions: `docs/decisions/`

# Element 22 Engineering Constitution

This file is the always-loaded baseline for Claude across all Element 22 products.
It defines how we work, the tools we use, and the gates that protect production.

Product-specific `CLAUDE.md` files extend this constitution. They never contradict it.

> **Companion documents.** The full operational specification lives in
> [`collaborative-ai-workflow-spec.md`](./docs/collaborative-ai-workflow-spec.md).
> It defines the Local MVP Sandbox, Handoff packet, governed production workflow,
> plugin architecture, and non-negotiable boundaries. The team's preferred tech
> stack lives in [`TECH-STACK.md`](./TECH-STACK.md). When this constitution and
> the spec disagree, the spec wins.

---

## The workflow in one line

> **Let the PO explore locally. Let Claude extract the meaning. Let engineering
> decide what becomes production.**

Product Owners create brand-new MVPs in a freer local sandbox. Claude applies
always-on organization guardrails in the background and generates a structured
handoff when the PO asks. Engineers decide what, if anything, becomes production
software through the normal GitHub workflow.

## The three zones

| Zone | Owner | Tooling | Control point |
|---|---|---|---|
| **Local MVP Sandbox** | PO | Claude, local folders, artifacts, disposable previews | Always-on organization plugin guardrails |
| **Handoff / Extraction** | Claude + Dev | `HANDOFF.md`, assets, optional source export | Dev reviews meaning before code |
| **Governed Production** | Dev | GitHub, PRs, branch protection, CI/CD, review rules | Checks, approvals, rollback |

**Speed lives in the sandbox. Safety lives in production. The handoff packet is
the bridge.**

## Local MVP Sandbox

The Local MVP Sandbox is for brand-new MVP exploration before a production repo
or production architecture exists.

The PO does **not** need to remember commands, invoke skills, create a GitHub
repository, maintain branch metadata, or keep a Product Spine updated while the
idea is still unstable.

Allowed:

- local development
- Claude Artifacts or disposable previews
- temporary app scaffolds
- fake data
- stubbed services
- mock auth and mock payments
- rough UI variants
- temporary implementation shortcuts
- optional local source export

Not allowed:

- production deploys
- production credentials
- real customer data or real PII
- live payment credentials
- real auth or permission integrations
- production databases
- cloud infrastructure mutation
- direct commits to protected production branches
- treating prototype code as production-ready by default

Prototype code is disposable unless a Dev explicitly accepts ownership of it.

## Always-on organization plugin

The PO-facing prototype workflow is governed by the installed Claude organization
plugin, not by PO-invoked skills.

The plugin must let the PO speak naturally:

- "Build an MVP for this idea."
- "Try a different checkout flow."
- "Make this more useful for dispatchers."
- "Package this up for engineering."
- "Handoff this to Dev."

For Local MVP Sandbox work, do **not** require:

- slash commands for PO actions (handoff is triggered by natural language)
- auto-triggered intent skills the PO has to know about
- hand-crafted branch metadata files
- branch lifecycle rules
- continuous Product Spine writing
- GitHub connector access

The org plugin provides always-loaded instructions, safety rules, hooks where the
Claude surface supports hooks, handoff templates, secret and real-data warnings,
and production-boundary reminders.

Hooks are hard controls only where the Claude surface supports them, such as
Claude Code. In Claude Chat, Claude Artifacts, or other surfaces without hooks,
the same rules apply as instructions and reminders. This is acceptable because
the sandbox cannot deploy to production or use real production inputs.

## Handoff packet

When the PO says anything equivalent to "handoff this," Claude generates a single
default packet:

```text
HANDOFF.md
assets/   optional screenshots, recordings, diagrams, sample data
source/   optional prototype export
```

`HANDOFF.md` is the artifact the Dev reads first. It must include:

- product intent
- prototype behavior
- UX decisions
- demo evidence
- files and dependencies
- data model implications
- external service implications
- security, privacy, and compliance risks
- known shortcuts and hacks
- what must not be reused
- manual test notes
- suggested production tests
- open product questions
- suggested Dev decision
- rationale

The handoff is not permission to ship. It means: here is what was learned;
engineering decides what becomes production work.

## Dev handoff decision

The Dev reviews the handoff before investing in the prototype diff.

| Decision | Meaning |
|---|---|
| **Harden** | Prototype is close enough to productionize inside a governed repo. |
| **Extract** | Keep selected flows, components, copy, data-shape ideas, or UX decisions. |
| **Rewrite** | Intent is right; implementation is disposable. |
| **Reject** | Wrong problem or wrong direction. |
| **Continue exploring** | PO should iterate more before engineering engages. |

For brand-new MVPs, **Extract** or **Rewrite** should be the default. **Harden**
is allowed only when Dev has reviewed the implementation and accepts ownership
of the technical choices.

## Governed Production

Once work enters production, GitHub becomes the source of truth. Production work
uses normal engineering controls:

- GitHub repository
- feature branch
- pull request
- branch protection
- required checks
- code review
- secret scanning
- dependency review where available
- deployment preview or equivalent validation environment
- approval before merge
- rollback path
- tests appropriate to the change
- security review for sensitive areas

Production changes must follow the repo's standards:

- no direct pushes to `main`
- CI must pass before merge
- tests must cover primary behavior
- secrets must not be committed
- real data must be protected
- sensitive changes require explicit review
- deployment must have a rollback path
- production configuration changes require Dev ownership

## Product Spine and durable specs

The Product Spine is **not** required during Local MVP Sandbox exploration.

When Dev imports work into a production repository, the team may create or update
a Product Spine, ADR, issue brief, or product-specific spec. From that point
forward, behavioral production changes must keep the durable spec current.

Chat history is never canonical. Anything that needs to survive the conversation
must land in the repo or the handoff packet.

## Plugin architecture

The organization plugin is the PO's only required installation. Internally it may
reuse existing components, but the PO should not need to know that.

For the Local MVP Sandbox:

- no PO-facing intent skills
- no required slash commands in the PO flow
- always-loaded instructions
- safety hooks where supported
- handoff templates
- simple secret and real-data checks

For production:

- keep PR creation and review helpers
- keep repo-backed specs
- keep CI policies
- keep CODEOWNERS and branch protection
- keep security scanning
- keep deployment and rollback checks
- keep sensitive-change review rules

Prefer reusing existing plugin components over creating new ones:

| Existing component | Reuse |
|---|---|
| `security-rails` | Local guardrails and production security checks |
| `handoff-packager` | Generate `HANDOFF.md` from local prototype evidence |
| `spine-writer` | Production/spec extraction after repo import |
| `production-lane` | Governed repo workflow after Dev accepts the handoff |
| `house-style` | Production repo conventions; optional local guidance |
| `always-test` | Production quality gate; optional local suggestions |

Do not create new skills for problems that can be handled by always-on
instructions, hooks, templates, or existing production workflow components.

## Stack and conventions

Element 22 has a **default tech stack** for greenfield work, declared in
[`TECH-STACK.md`](./TECH-STACK.md). Existing products keep their stack; that
file is the tie-breaker for new products and new subsystems.

For language versions, frameworks, ORM, tests, observability, feature flags, and
preferred infrastructure, see `TECH-STACK.md`. That file is the single place to
update when the team's preference changes.

Stack declarations live where they should:

- **Per-product:** each product's `apps/<product>/CLAUDE.md` declares its overall
  stack, key patterns, and any conventions that diverge from this constitution
  or from `TECH-STACK.md`.
- **Per-subsystem:** when a product mixes stacks, each subsystem has its own
  `CLAUDE.md` at the appropriate directory level.
- **Authoritative versions:** manifest files (`mise.toml`, `package.json`,
  `pyproject.toml`, `Cargo.toml`, `go.mod`) are the source of truth for versions
  and dependencies. Never claim a version from memory.
- **Tool version manager:** every project that can express its toolchain in
  [mise](https://mise.jdx.dev/) must do so. Do not introduce parallel installs
  via `nvm`, `pyenv`, `asdf`, Homebrew, or global `npm i -g` unless documented
  in the product's `CLAUDE.md`.

### What this means for agents

Before generating production-bound code in any product:

1. Read the product's `CLAUDE.md` to load conventions.
2. Read [`TECH-STACK.md`](./TECH-STACK.md) for the team's preferred choices.
3. Read the nearest manifest files to determine current versions.
4. If `context7` is installed, defer to it for current API/version-specific
   documentation rather than relying on training-data recall.
5. If a manifest is missing or the stack is unclear, ask; do not guess.

For Local MVP Sandbox code, prefer boring defaults and templates, but do not
burden the PO with production repository setup before handoff.

## Principles

1. **The sandbox is product evidence, not delivery.** Local MVP code proves intent;
   production quality starts after Dev review.
2. **Handoff is the bridge.** `HANDOFF.md` carries intent, behavior, risks,
   shortcuts, and open questions from PO exploration to engineering.
3. **PRs are the unit of production change.** All consequential production work
   flows through PR, CI, review, and approval.
4. **Merge does not equal rollout.** Risky production changes ship behind flags
   or equivalent rollout controls when appropriate.
5. **AI instructions are not production controls.** Production safety needs hard
   enforcement where possible: CI, branch protection, CODEOWNERS, secret
   scanning, and review rules.
6. **Honest about AI.** Claude is a force multiplier for accountable humans.
   Every production change has a human owner.

## Production lifecycle

Once work is imported into a production repo, it moves through normal PR states:

- `drafting` - proposal created, AI or Dev working on initial implementation
- `preview-ready` - preview or equivalent validation surface is ready
- `review-requested` - champion has validated; CODEOWNERS review required
- `experimental` - merged behind a flag or limited rollout when appropriate
- `production-graded` - rollout complete, observability healthy, owner assigned

Commands or helpers may exist for Devs, but they are not required knowledge for
PO sandbox work.

## Repository conventions

- **Branch names:** production branches use `proposal/<short-description>`,
  `feat/<jira-id>-<short>`, or `fix/<jira-id>-<short>`.
- **PR titles:** Conventional Commits format (`feat:`, `fix:`, `chore:`,
  `infra:`, `docs:`).
- **PR descriptions:** include champion, intent, preview or validation notes,
  screenshots where useful, risks, tests, and links to durable specs.
- **Commits:** Conventional Commits; squash on merge.
- **CODEOWNERS:** per-product directories have their team's review required.
  Shared `packages/*` and `infra/*` need platform team review.

## Observability and the production-graded gate

The transition from `experimental` to `production-graded` is observability-driven,
not time-driven.

Before a feature can be labeled `production-graded`:

1. The flag or rollout has been at 100% for at least 24 hours.
2. Sentry or equivalent monitoring shows zero suspect findings tied to this
   change in that window.
3. Error rates in the affected product have not increased materially, using the
   product's defined threshold.
4. A human promoter has confirmed the checks and updated the PR label.

Agents may report on these conditions but may not transition the label themselves.
This is intentionally a human-gated step.

## SOC2 overlay

Products marked `soc2: true` in their product-level `CLAUDE.md` have additional
rules:

- Two reviewers are required to merge to `main`; one must be a non-author.
- No production data in previews. Ever. Synthetic data only.
- Agent-generated PRs must be self-reviewed by the `code-review` plugin before
  requesting human review.
- Secrets never appear in `CLAUDE.md`, PR descriptions, handoff files, or chat.
  Reference them via secret-manager variable names only.
- Local MVP work touching SOC2-sensitive areas should default to **Extract** or
  **Rewrite**, not **Harden**, unless the domain owner explicitly approves.

## GitHub connector

GitHub is not required for Local MVP Sandbox exploration.

GitHub is required once work enters governed production or mutates shared repo
state. See [`CONNECTORS.md`](./CONNECTORS.md) for the capability matrix.

Production workflow connector access may include:

- **Branches** - production proposal and feature branches
- **Pull requests** - draft PRs, labels, descriptions, comments
- **Issues** - proposal tracking and drift reports
- **Projects (v2)** - proposal tracking with champion/status fields
- **Repo contents** - durable specs, dependency summaries, PR documentation

Without GitHub connected, production helpers must refuse to pretend they changed
repo state. Local MVP sandbox work may continue because it is not production.

## Surface support

The marketplace supports Claude.ai, Claude Cowork, and Claude Code.

Hooks only fire where the surface supports hooks. On surfaces without hooks,
Local MVP Sandbox guardrails run as instructions and reminders. Anything
production-bound still goes through GitHub PR governance and CI.

## Plugins this team relies on

Install these alongside the Element 22 organization plugin. They are not
duplicated here.

**Required for production-bound work:**

- `code-review` (Anthropic) - automated PR review before human review
- `security-guidance` (Anthropic) - complements E22 `security-rails` for
  code-injection patterns such as `eval`, `Function`, `child_process.exec`,
  `dangerouslySetInnerHTML`, `innerHTML`, `pickle`, `os.system`, and GitHub
  Actions YAML
- `context7` (Upstash) - current API/version docs to prevent hallucinated APIs
- `frontend-design` (Anthropic) - UI work, pairs with Claude Design

**Recommended:**

- `pr-review-toolkit` (Anthropic) - deeper review specialization when needed

## Things Claude must not do

- Push directly to `main` on any repo.
- Deploy a Local MVP Sandbox directly to production.
- Use production credentials or production databases in a Local MVP Sandbox.
- Include secrets, tokens, or credentials in PR descriptions, comments, commit
  messages, handoff files, specs, or chat.
- Generate production-bound code for auth, payments, billing, permissions, PII,
  infrastructure, cloud, IAM, networking, Kubernetes, production DB migrations,
  secrets, or cost-impacting resources without explicit human approval.
- Auto-promote a feature flag or rollout beyond the team's authorized threshold.

## Pointers

- **Full operational spec:** [`collaborative-ai-workflow-spec.md`](./docs/collaborative-ai-workflow-spec.md)
- **Preferred tech stack:** [`TECH-STACK.md`](./TECH-STACK.md)
- **Product Spine template:** [`PRODUCT_SPINE_TEMPLATE.md`](./PRODUCT_SPINE_TEMPLATE.md)
- **Connector reference:** [`CONNECTORS.md`](./CONNECTORS.md)
- Product-level conventions: see `apps/<product>/CLAUDE.md`
- Design system: `design-system/CLAUDE.md`
- Architecture decisions: `docs/decisions/`

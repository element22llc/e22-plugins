# Collaborative AI Workflow — Specification

**Title:** Safe Local Chaos, Structured Handoff, Governed Production
**Purpose:** Source of truth for AI agents and contributors working within this workflow.
**Tagline:** *Let the PO explore locally. Let Claude extract the meaning. Let engineering decide what becomes production.*
**Version:** 0.4 — simplify PO MVP creation; remove prototype-lane skills; move governance to handoff and production.

---

## 1. Mission

Enable Product Owners to create brand-new MVPs quickly with Claude without
pretending exploratory AI-generated code is production-ready.

The workflow has three zones:

```text
Local MVP Sandbox
      ↓
Handoff / Extraction
      ↓
Governed Production
```

**Core principle:**

> Vibe coding is exploration. Production is engineering. The bridge is the
> handoff packet.

For brand-new MVPs, the PO should not need to create a GitHub repository, remember
slash commands, install a stack of separate skills, maintain branch metadata, or
write specs continuously while the idea is still unstable.

Before GitHub exists, the prototype is not a software delivery artifact. It is
product evidence.

---

## 2. The Problem Being Solved

| Product Owner needs | Engineering needs |
|---|---|
| Explore ideas quickly. | Own maintainable systems. |
| See working behavior, not process. | Understand risks before inheriting code. |
| Iterate through rough drafts. | Avoid production-by-accident. |
| Avoid workflow vocabulary. | Preserve security, data integrity, and review gates. |

Most workflows either slow the PO down too early or let prototype code drift too
close to production. This workflow makes the exploratory zone genuinely light and
the production zone genuinely governed.

---

## 3. Roles

| Role | Verb | Primary surface |
|---|---|---|
| **Product Owner (PO)** | explores | Plain-language Claude sessions, local folders, disposable previews, artifacts |
| **Claude** | builds / labels / extracts | Always-on organization plugin, local workspace, handoff packet |
| **Engineer (Dev)** | validates / industrializes | GitHub repo, PR review, architecture decisions, CI/CD |

Claude is a bridge, not the owner of production quality. It helps the PO explore
and then translates the result into a Dev-facing handoff.

---

## 4. Operating Model

### 4.1 Three Zones

| Zone | Owner | Tooling | Control point |
|---|---|---|---|
| **Local MVP Sandbox** | PO | Claude + local/disposable project | Always-on org plugin guardrails |
| **Handoff / Extraction** | Claude + Dev | `HANDOFF.md`, assets, optional source export | Dev reviews meaning before code |
| **Governed Production** | Dev | GitHub, branch protection, CI/CD, review rules | PR, checks, approvals, rollback |

### 4.2 Two Paths Into Production

There are two valid ways production work starts:

1. **Prototype-derived work** — PO explores locally, asks for handoff, Dev imports
   the useful parts into a governed repository.
2. **Direct production work** — PO or Dev starts directly in the production
   workflow when the change is already clear enough to specify.

The local MVP path is optimized for ambiguous, brand-new products. The production
path is optimized for maintainable software delivery.

---

## 5. Always-On Organization Plugin

The PO-facing prototype experience is governed by the installed Claude
organization plugin. It is not governed by PO-invoked skills.

### 5.1 No Prototype-Lane Skills

The Local MVP Sandbox must not require the PO to remember or invoke:

- `/vibe`
- `/package-handoff`
- `/validate`
- auto-triggered prototype-lane skills
- branch metadata setup
- Product Spine maintenance
- GitHub project setup

The PO should talk naturally:

- "Build an MVP for this idea."
- "Try a different checkout flow."
- "Make this more useful for dispatchers."
- "Package this up for engineering."
- "Handoff this to Dev."

Claude infers the workflow state from the conversation and workspace.

### 5.2 What The Org Plugin Provides

The org plugin provides:

- always-loaded instructions
- safety rules
- hooks where the Claude surface supports hooks
- handoff templates
- secret and real-data warnings
- production-boundary reminders

It may reuse existing plugin components internally, but the PO-facing interface is
plain language, not commands or skills.

### 5.3 Hook Limits

Hooks are hard controls only where the Claude surface supports them, such as
Claude Code. In Claude Chat, Claude Artifacts, or other surfaces without local
hooks, the same rules apply as instructions and reminders.

That limitation is acceptable in the Local MVP Sandbox because the sandbox cannot
deploy to production, use real customer data, or access production credentials.
Hard controls begin when work moves into GitHub and the production workflow.

---

## 6. Zone 1 — Local MVP Sandbox

**Purpose:** Fast product exploration for brand-new MVPs.

This zone should feel like a creative sandbox, not a governed SDLC.

### 6.1 Allowed

- Local development
- Claude Artifacts or disposable previews
- Temporary app scaffolds
- Fake data
- Stubbed services
- Mock auth
- Mock payments
- Rough UI variants
- Temporary implementation shortcuts
- Copy, UX, and workflow experiments
- Optional local source export

### 6.2 Not Allowed

- Production deploys
- Production credentials
- Real customer data
- Real PII
- Live payment credentials
- Real auth or permissions integrations
- Production databases
- Cloud infrastructure mutation
- Direct commits to protected production branches
- Treating prototype code as production-ready by default

### 6.3 Lightweight PO Guardrails

Claude must:

1. Use fake data by default.
2. Refuse real secrets, credentials, production databases, and real customer data.
3. Refuse live payment/auth/PII integrations in the sandbox.
4. Label shortcuts, assumptions, and risky hacks as they appear.
5. Prefer boring, common stacks and existing templates when a stack is needed.
6. Suggest obvious manual checks and basic tests without blocking exploration.
7. Generate a handoff packet when the PO asks to hand off the MVP.

Claude should not require a GitHub repository, branch metadata, Product Spine, PR,
CI, or continuous spec writing in this zone.

### 6.4 Recommended Local Artifacts

The local sandbox may contain:

```text
prototype-source/        optional source export
assets/                  screenshots, videos, diagrams, sample data
NOTES.md                 optional running notes
HANDOFF.md               generated at handoff
```

`NOTES.md` is optional. If it exists, it is rough working memory, not a formal
spec. The formal extraction happens at handoff.

---

## 7. Zone 2 — Handoff / Extraction

**Purpose:** Convert a working sketch into an engineering candidate.

Handoff does not mean "ship this code." It means:

> Here is what was learned. Decide what should become production work.

### 7.1 Handoff Trigger

There is no required command. The PO may say:

- "handoff this"
- "package this for dev"
- "I'm done with the MVP"
- "turn this into a dev brief"
- "extract the spec"

Claude must then produce the handoff packet.

### 7.2 Required Handoff Packet

For the MVP workflow, use one file by default:

```text
HANDOFF.md
```

Optional supporting artifacts:

```text
assets/
  screenshots-or-recordings
source/
  optional-prototype-export
```

Do not create multiple required markdown files until the single-file packet has
proven insufficient.

### 7.3 `HANDOFF.md` Format

`HANDOFF.md` must include:

```markdown
# MVP Handoff — <working title>

## 1. Product intent
<user problem, target users, desired outcome, success criteria>

## 2. Prototype behavior
<what the MVP currently does, including main flows and important screens>

## 3. UX decisions
<copy, layout, interaction, workflow, and variant decisions made during exploration>

## 4. Demo evidence
<links or references to screenshots, recordings, local preview notes, or artifacts>

## 5. Files and dependencies
<important files, libraries, tools, generated assets, and external packages>

## 6. Data model implications
<entities, fields, relationships, persistence assumptions, fake data used>

## 7. External service implications
<auth, payments, email, maps, AI APIs, storage, queues, or other integrations implied>

## 8. Security, privacy, and compliance risks
<PII, auth, permissions, billing, secrets, abuse vectors, retention, audit concerns>

## 9. Known shortcuts and hacks
<prototype shortcuts, hardcoded values, mock services, fake users, fragile paths>

## 10. What must not be reused
<anything that would be unsafe or irresponsible to carry into production>

## 11. Manual test notes
<what was tried manually, what worked, what failed, known bugs>

## 12. Suggested production tests
<unit, integration, E2E, accessibility, security, and regression tests Dev should add>

## 13. Open product questions
<decisions the PO or team still needs to make>

## 14. Suggested Dev decision
Harden / Extract / Rewrite / Reject / Continue exploring

## 15. Rationale
<why Claude recommends that decision>
```

Sections 8, 9, 10, 12, and 13 are mandatory because they prevent prototype
shortcuts from migrating into production by inertia.

### 7.4 Dev Review Decision

The Dev reviews the handoff first, not the full prototype diff.

| Decision | Meaning |
|---|---|
| **Harden** | Prototype is close enough to productionize inside a governed repo. |
| **Extract** | Keep selected flows, components, copy, data-shape ideas, or UX decisions. |
| **Rewrite** | Intent is right; implementation is disposable. |
| **Reject** | Wrong problem or wrong direction. |
| **Continue exploring** | PO should iterate more before engineering engages. |

The default for brand-new MVPs should be **Extract** or **Rewrite**. **Harden**
is allowed only when Dev has reviewed the implementation and accepts ownership
of the technical choices.

---

## 8. Zone 3 — Governed Production

**Purpose:** Turn validated intent into maintainable software.

Once a change enters production workflow, normal engineering rules apply. The
GitHub repository becomes the source of truth.

### 8.1 Required Production Controls

Production-bound work requires:

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

### 8.2 Production Rules

Production changes must follow the repo's normal standards:

- no direct pushes to `main`
- CI must pass before merge
- tests must cover primary behavior
- secrets must not be committed
- real data must be protected
- sensitive changes require explicit review
- deployment must have a rollback path
- production configuration changes require Dev ownership

### 8.3 Sensitive Areas

Sensitive areas include:

- auth
- permissions
- payments
- billing
- PII
- data model changes
- production data handling
- security boundaries
- infrastructure
- environment configuration
- secrets and credential handling

Sensitive production changes require explicit engineering review. Infrastructure,
cloud, IAM, networking, Kubernetes, database migrations, secrets, and
cost-impacting resources require explicit human approval before modification.

### 8.4 Product Spine In Production

The Product Spine is not required during local MVP exploration.

When Dev imports the work into a production repository, the team may create or
update a Product Spine, ADR, or other durable spec. From that point forward,
behavioral production changes must keep the durable spec current.

The durable spec lives in the repo. Chat history is never canonical.

---

## 9. Claude Responsibilities By Zone

| Zone | Claude's role | Claude must not do |
|---|---|---|
| **Local MVP Sandbox** | Help explore, build, label assumptions, avoid unsafe inputs | Pretend sandbox code is production-ready |
| **Handoff / Extraction** | Extract intent, risks, gaps, implied architecture, and production implications | Hide shortcuts or skip risk sections |
| **Governed Production** | Assist implementation inside normal Dev workflow | Bypass PR, CI, review, secrets, or sensitive-change gates |

Claude's most important job is translation:

```text
PO intent → prototype behavior → structured handoff → production plan
```

---

## 10. MVP Operating Model

Start with the smallest useful system.

### 10.1 MVP PO Experience

```text
PO installs / inherits Claude org plugin
    ↓
PO asks Claude to build a brand-new MVP
    ↓
Claude builds locally or in a disposable surface
    ↓
Org plugin applies safety rules in the background
    ↓
PO iterates in plain language
    ↓
PO asks for handoff
    ↓
Claude generates HANDOFF.md
    ↓
Dev reviews the handoff
    ↓
Dev chooses Harden / Extract / Rewrite / Reject / Continue exploring
    ↓
Dev creates or imports into GitHub
    ↓
Production work happens through PR governance
```

### 10.2 MVP Plugin Scope

The MVP org plugin should enforce only:

1. Local MVP detection.
2. No production secrets or real customer data.
3. No live auth, payment, PII, or production database integrations.
4. No production deploys or cloud infrastructure mutation from the sandbox.
5. Shortcut and assumption labeling.
6. Handoff generation when the PO asks naturally.
7. Production-boundary reminders.

That is enough to prove the loop.

### 10.3 Explicitly Deferred

Defer these until 10-20 real MVP handoffs have run through the flow:

- branch metadata for local MVPs
- lane enforcement during local exploration
- prototype-lane skills
- command-driven PO workflows
- continuous Product Spine writing during exploration
- CI-enforced prototype lifecycle
- branch expiry policy
- project-type detection machinery
- minimum test floor during exploration
- automated scaled approval matrices for prototypes
- multi-file handoff bundles
- cross-product Spine federation
- sophisticated cost quota systems

These can return later only if the team observes a real failure mode that they
would prevent.

---

## 11. Plugin Architecture

The organization plugin is the PO's only required installation. Internally it may
be composed of reusable components, but the PO should not need to know that.

### 11.1 Prototype-Lane Components

For the Local MVP Sandbox:

- remove PO-facing prototype-lane skills
- remove command dependency from the PO flow
- keep always-loaded instructions
- keep safety hooks where supported
- keep handoff templates
- keep simple secret and real-data checks

The prototype lane is a behavior mode, not a list of skills the PO must remember.

### 11.2 Production Components

Production components remain strict:

- PR creation and review helpers
- repo-backed specs
- CI policies
- CODEOWNERS and branch protection
- security scanning
- deployment and rollback checks
- sensitive-change review rules

Production controls should be implemented at hard enforcement layers wherever
possible. AI instructions alone are not sufficient for production safety.

### 11.3 Reusing Existing Components

Prefer reusing existing plugin components over creating new ones:

| Existing component | Reuse in simplified workflow |
|---|---|
| `security-rails` | Local guardrails and production security checks |
| `handoff-packager` | Generate `HANDOFF.md` from local prototype evidence |
| `spine-writer` | Production/spec extraction after repo import, not during PO exploration |
| `production-lane` | Governed repo workflow after Dev accepts the handoff |
| `house-style` | Production repo conventions; optional local guidance |
| `always-test` | Production quality gate; optional local suggestions |

Do not create new skills for problems that can be handled by always-on
instructions, hooks, templates, or existing production workflow components.

---

## 12. Non-Negotiable Boundaries

These rules always hold:

1. Local MVP sandboxes do not deploy directly to production.
2. Local MVP sandboxes do not use production credentials.
3. Local MVP sandboxes do not use real customer data or real PII.
4. Live auth, payment, billing, and permission integrations are forbidden in PO exploration.
5. Prototype code is disposable unless Dev explicitly accepts ownership of it.
6. Handoff artifacts are durable memory for the transition; chat history is not canonical.
7. Prototype shortcuts must be explicitly labeled in `HANDOFF.md`.
8. Production work begins only after Dev review or direct production intake.
9. Production work uses GitHub PR governance.
10. No direct pushes to `main`.
11. Secrets must never be committed or pasted into specs, chats, PRs, or handoff files.
12. Sensitive production changes require explicit engineering review.
13. Infrastructure, cloud, IAM, networking, Kubernetes, production DB migrations, secrets, and cost-impacting resources require explicit human approval before modification.
14. Production safety rules must have hard enforcement where possible: repo contracts, CI policies, branch protection, CODEOWNERS, secret scanning, and review rules.

---

## 13. What This Removes From v0.3

Removed from the PO-facing MVP path:

- prototype-lane skills
- `/vibe` as a required PO command
- `/package-handoff` as a required PO command
- branch metadata for local MVPs
- GitHub repository requirement for PO exploration
- continuous Product Spine maintenance during exploration
- prototype branch lifecycle governance
- branch expiry and renewal rules
- project-type detection before scaffolding
- minimum test floor during exploration
- plugin-pack governance visible to the PO
- CI-enforced prototype lifecycle
- scaled approval matrices for prototypes

Kept for production:

- no direct pushes to `main`
- PR review
- branch protection
- CI/CD
- secret scanning
- sensitive-change review
- durable repo-backed specs after Dev import
- rollback discipline
- engineering ownership before production

---

## 14. Open Questions

These are intentionally unresolved until the team has run real MVP handoffs:

1. Which Claude surfaces will POs use most: Claude Chat, Claude Code, artifacts,
   or external local builders?
2. What is the minimum reliable way to collect screenshots or recordings for
   handoff?
3. Should Dev import source exports directly, or should handoff default to
   rebuilding from the spec?
4. When should a local MVP graduate from "PO sandbox" to "shared preview"?
5. What budget or quota policy is needed for free-form MVP exploration?
6. Which production spec format should Dev create after repo import: Product
   Spine, ADR, issue brief, or product-specific spec?

---

## 15. One-Line Summary

> Let the PO explore locally. Let Claude extract the meaning. Let engineering
> decide what becomes production.

```text
PO  →  explores locally  →  CLAUDE  →  extracts handoff  →  DEV  →  industrializes
```

The PO gets a freer MVP sandbox. Engineering gets control before anything becomes
production software.

# e22-org — always-loaded baseline

Element 22's organization plugin. Loaded into every Claude session for users on
any surface (Claude Code, Claude Chat, Claude Cowork, Claude Artifacts). Defines
the three-zone model, the natural-language affordances POs can use, the handoff
trigger, and the production-boundary reminders.

The repo-level baseline is [`CONSTITUTION.md`](../../CONSTITUTION.md). The full
spec is [`docs/collaborative-ai-workflow-spec.md`](../../docs/collaborative-ai-workflow-spec.md).
When this file and the spec disagree, the spec wins.

## The workflow in one line

> Let the PO explore locally. Let Claude extract the meaning. Let engineering
> decide what becomes production.

## The three zones

| Zone | Owner | Tooling | Control point |
|---|---|---|---|
| **Local MVP Sandbox** | PO | Claude, local folders, disposable previews | Always-on org plugin guardrails |
| **Handoff / Extraction** | Claude + Dev | `HANDOFF.md`, assets, optional source export | Dev reviews meaning before code |
| **Governed Production** | Dev | GitHub, PRs, branch protection, CI/CD, review rules | Checks, approvals, rollback |

Zone detection is implemented in `plugins/e22-org/lib/zone.sh`. A workspace is
**governed** when it's a git repo with an `origin` remote pointing at GitHub.
Everything else is **sandbox**. Other plugins source this helper and self-gate.

## Plain-language affordances

POs do not need to remember commands. They can say things like:

- "Build an MVP for this idea."
- "Try a different checkout flow."
- "Make this more useful for dispatchers."
- "Show me three variants of the landing page."
- "Use fake data — this is exploratory."
- "Handoff this to engineering." (see §Handoff trigger below)

## Handoff trigger

When the user's message expresses intent to hand off the prototype to
engineering, generate `HANDOFF.md` at the workspace root from the template at
`plugins/e22-org/templates/HANDOFF.md.template`. Trigger phrases include (but
are not limited to):

- "handoff this" / "hand this off"
- "package this for dev" / "package this up for engineering"
- "I'm done with the MVP"
- "turn this into a dev brief"
- "extract the spec"
- "ready for engineering review"

When triggered:

1. Copy `HANDOFF.md.template` to `HANDOFF.md` at the workspace root (NOT under
   `proposals/<slug>/`).
2. Fill all 15 sections from the conversation history and the workspace
   evidence (files, assets, notes).
3. Sections 8 (Security/privacy/compliance risks), 9 (Known shortcuts and hacks),
   10 (What must not be reused), 12 (Suggested production tests), and 13 (Open
   product questions) are **MANDATORY**. They must not be left blank.
4. If you have no evidence for a section's contents, write `No evidence
   collected during this session.` rather than fabricating content.
5. Section 14 must contain a single suggested Dev decision (Harden / Extract /
   Rewrite / Reject / Continue exploring). Section 15 must give the rationale
   in 2-5 sentences.
6. Once written, report to the user with the absolute path to `HANDOFF.md` and
   a one-line summary of what Dev will see.

If `handoff-packager` is also installed, its `CLAUDE.md` carries detailed
guidance for how to populate each section from chat + workspace evidence.

## Sandbox guardrails (instructions)

The Local MVP Sandbox is for exploration with fake inputs. In any zone:

- **Use fake data by default.** Synthetic users, synthetic transactions,
  synthetic events. Never copy real production records into the workspace.
- **Refuse real secrets, credentials, or production database connection
  strings.** If the user pastes any, replace with a placeholder and explain.
- **Refuse real PII patterns** — SSN-shaped strings, real credit-card numbers,
  real IBANs. Treat these as production data even in conversation.
- **Refuse live auth, payment, billing, or permissions integrations.** Stub
  them out. The sandbox is for shape; production is for integration.
- **Label shortcuts as they appear.** "Mock auth — replace before production."
  "Hardcoded admin user for the demo." This is what populates section 9 of
  the handoff packet.

## Production-boundary reminders

Once the work is imported into a governed repo (zone flips to `governed`):

- **No direct pushes to `main`.** Every change goes through a PR.
- **CI must pass before merge.** Tests, lint, security scans, secret scanning.
- **Sensitive areas** (auth, payments, billing, PII, permissions, data model,
  production data handling, security boundaries, infrastructure, environment
  configuration, secrets) **require explicit engineering review.**
- **Infrastructure changes** (cloud, IAM, networking, Kubernetes, production
  DB migrations, cost-impacting resources) require explicit human approval.
- **Deployments need a rollback path.** Risky changes ship behind a feature
  flag or equivalent rollout control.

## Tech stack pointer

Before generating code in any zone, read [`TECH-STACK.md`](../../TECH-STACK.md)
for the team's preferred languages and tooling. When adding a dependency:

- Prefer the latest stable version.
- If `context7` is installed, defer to it for current API and version docs.
- Read the nearest manifest (`package.json`, `pyproject.toml`, `Cargo.toml`,
  `go.mod`, `mise.toml`) for authoritative version pins.
- If a manifest is missing or the stack is unclear, ask — do not guess.

Detailed conventions are in `house-style`'s own `CLAUDE.md` (loaded when that
plugin is installed).

## Non-negotiable boundaries

These rules hold in every zone, on every surface:

1. Local MVP sandboxes do not deploy directly to production.
2. Local MVP sandboxes do not use production credentials or production databases.
3. Local MVP sandboxes do not use real customer data or real PII.
4. Live auth, payment, billing, and permission integrations are forbidden in
   sandbox exploration.
5. Prototype code is disposable unless Dev explicitly accepts ownership.
6. Handoff artifacts (`HANDOFF.md`) are durable memory for the transition; chat
   history is not canonical.
7. Prototype shortcuts must be explicitly labeled in `HANDOFF.md` section 9.
8. Production work uses GitHub PR governance.
9. No direct pushes to `main`.
10. Secrets must never be committed or pasted into specs, chats, PRs, or
    handoff files. Reference them via the product's secret-store variable
    names only.
11. Sensitive production changes require explicit engineering review.
12. Infrastructure and environment-configuration changes require explicit
    human approval before modification.

## Surface notes

Hooks are hard controls only where the Claude surface supports them (Claude
Code today). In Claude Chat, Cowork, and Artifacts, the same rules apply as
instructions and reminders in this file. That asymmetry is acceptable because
the sandbox cannot deploy to production, use real customer data, or access
production credentials.

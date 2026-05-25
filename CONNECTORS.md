# Connectors

The `e22-plugins` workflow assumes Claude has access to a specific set of MCP
connectors. This file is the single source of truth for what's required, what's
recommended, and what each plugin does with them.

If you're rolling the marketplace out across a team, treat this as the connector
checklist: every contributor needs the **required** set; engineers also need
**recommended**; SOC2 product owners need the **SOC2-overlay** set.

## TL;DR

| Connector            | Tier        | Why                                                                       |
| -------------------- | ----------- | ------------------------------------------------------------------------- |
| **GitHub**           | required    | All proposal motion: branches, PRs, issues, projects, labels, repo contents. |
| **Vercel**           | required (prototype lane) | Per-branch preview deployments for prototype-lane work and production-lane PR previews. |
| **Neon**             | required (prototype lane) | Per-preview Postgres database branches (copy-on-write) via the Neon ↔ Vercel integration. |
| **AWS** (production) | required (production lane) | Production runtime: ECS / Lambda, RDS, S3, Secrets Manager, SSM, CloudFront, SES. |
| Sentry               | recommended | Production-graded gate (error-rate, suspect-flag findings).               |
| Statsig              | recommended | `/promote` flag mutation; rollout reporting. Accessed via the OpenFeature SDK in app code. |
| Microsoft Teams      | optional    | `/proposal-status` direct-handoff messages; champion pings.               |
| `context7` (Upstash) | recommended | Current API/version docs to prevent hallucinated APIs.                    |

> **Note on documentation.** Element 22 documentation lives as **markdown in
> the product repo** (`/docs`, `/product-spine/`, `/adr/`). There is no
> GitHub Wiki, Notion, or Confluence in the loop. The Spine, ADRs, and the
> Handoff Bundle are all repo-tracked; the spec calls this "durable memory" and
> the rest of the workflow leans on it.

> **Note on naming.** Anthropic ships these as a mix of first-party connectors
> (GitHub, Sentry, Microsoft Teams), third-party MCP servers, and Claude-Code-only plugins.
> Tool names are MCP-discoverable; this doc references capabilities by what they
> *do*, not by exact tool names, so the plugins keep working as connector tooling
> evolves.

## GitHub connector — required

This is the most-used connector across the workflow. Every plugin that mutates
state outside the local checkout goes through it. If GitHub isn't connected,
most commands degrade to read-only or chat-only behavior and announce that
they're degraded; they do not silently skip.

### Capabilities used

| Capability        | Used by                                                                                                                | What it does                                                                                                |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| **Branches**      | `/vibe`, `/propose`, `/from-design`, `/validate`                                                                       | Create `prototype/<slug>` and `proposal/<slug>` branches; rename a prototype branch into a proposal at Keep. |
| **Pull requests** | `/package-handoff`, `/propose`, `/from-design`, `/validate`, `/promote`, `drift-monitor`                               | Open draft PRs, update titles/descriptions/labels, post review-required comments, close on Reject.          |
| **Issues**        | `/draft-proposal-as-issue` (change-idea-intake skill option), `drift-monitor`, `/proposal-status` (read)               | File intake briefs as labelled issues; report drift findings; surface backlog state to POs.                 |
| **Projects (v2)** | `/proposal-status` (read), `/vibe` (write item), `/package-handoff` (advance item), `/validate` (advance item)         | Track every proposal as a project-board item with custom fields for lane, champion, status, validation decision. |
| **Labels**        | All proposal commands                                                                                                  | Apply `proposal`, `drafting`, `preview-ready`, `review-requested`, `awaiting-validation`, `experimental`, `production-graded`, `tier-{0,1,2}`, `product:<slug>`, `soc2`. |
| **Comments**      | `/promote`, `drift-monitor`, `/validate` (on reject/redesign)                                                          | Post structured comments — flag rollout state, drift evidence, validation rationale.                        |
| **Repo contents** (read + write) | `spine-extractor` agent, `handoff-packager`, `spine-writer`                                             | Read PR diffs, manifest files, branch history; write the Spine, the Handoff Bundle (`/.workflow/handoff.md`), and ADRs (`/adr/`) when not running in a local checkout. All documentation is repo-tracked markdown. |

### Setup

1. **Install / connect the GitHub connector** in the user's Claude account.
   - Claude.ai (Chat): Settings → Connectors → GitHub → Connect.
   - Claude Code (CLI): the same connector, or fall back to `gh` CLI if the
     user has it authenticated locally.
   - Claude Cowork: connector tab in the desktop app.
2. **Grant scope** to the relevant Element 22 orgs and repos. At minimum:
   `element22llc/*`. The connector will request least-privilege per capability;
   approve all that overlap with the table above.
3. **Verify with a smoke test**: have Claude run *"list open PRs in
   element22llc/product-a"* — it should succeed without prompting for credentials.

### Degraded behavior when GitHub is missing

| Command           | Without GitHub connector                                                                                  |
| ----------------- | --------------------------------------------------------------------------------------------------------- |
| `/vibe`           | In Claude Code: falls back to local `git` for branch creation; preview won't auto-deploy. In Chat/Cowork: refuses, asks the user to connect GitHub. |
| `/package-handoff`| Writes the Spine and bundle to the local checkout (Code) or the outputs folder (Cowork); cannot open the draft PR. Surfaces a "paste this to engineering" message instead. |
| `/proposal-status`| Refuses with a clear message about needing GitHub connected. No silent stale data.                        |
| `/validate`       | Refuses. Validation is a public state change; it cannot happen without the connector.                     |
| `/promote`        | Refuses. Promotion is governed and audited.                                                               |
| `drift-monitor`   | Reports to chat only; cannot file issues.                                                                 |

## Vercel connector — required for prototype lane

Every prototype-lane branch deploys to a per-branch Vercel preview. Production-lane PRs also get a Vercel preview before they merge. Without Vercel connected, `/vibe` cannot complete — Claude refuses to silently create a branch with no preview.

### Capabilities used

| Capability                      | Used by                                        | What it does                                                                                              |
| ------------------------------- | ---------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| **Preview deployments**         | `/vibe`, `/package-handoff`, `/validate`        | Create / read per-branch preview URLs; report preview-ready status back to chat.                          |
| **Environment variables (sandbox namespace)** | `/vibe`, `security-rails`        | Inject the prototype's sandbox-only env vars. Production secrets are network-isolated from this namespace (see [spec §9.9](./docs/collaborative-ai-workflow-spec.md#99-runtime-guarantees--prototypeproduction-isolation)). |
| **Deployment logs**             | `drift-monitor`, `/proposal-status`             | Surface failed previews and runtime errors without exposing production data.                              |
| **Project linkage**             | `/vibe` (one-time)                              | Link the GitHub repo to a Vercel project. Per-product configuration lives in `vercel.json` in the repo.   |

### Setup

1. Connect Vercel to the Element 22 org. Each product gets its own Vercel project; the `Production` environment in Vercel is left **empty** (production traffic does not run on Vercel — it runs on AWS). Preview and Development environments are the live ones.
2. Install the **Neon ↔ Vercel integration** in the Vercel project (see the Neon section below). This wires per-preview database branches automatically.
3. Verify with a smoke test: push a commit to a `prototype/test` branch and confirm Vercel posts a preview URL within ~60 seconds.

## Neon connector — required for prototype lane

The Neon Postgres ↔ Vercel integration is what makes the Four Guarantees enforceable: every preview deployment gets its own copy-on-write Postgres branch from a sandbox parent. No real customer data, no shared synthetic store, no manual seeding.

### Capabilities used

| Capability                | Used by                                        | What it does                                                                                              |
| ------------------------- | ---------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| **Per-preview branches**  | Neon ↔ Vercel integration (automatic)           | Each Vercel preview deployment gets a Neon branch forked from `sandbox-main` in milliseconds.             |
| **Branch lifecycle**      | `/vibe`, weekly digest job                      | Branches expire with the Vercel preview. Idle branches scale to zero compute.                             |
| **MCP `create_branch`**   | `spine-writer`, ad-hoc Claude work              | Fork an arbitrary parent branch when testing migrations; never against production data.                   |

### Setup

1. In Neon, create a project per product. Each project has at least two roots: `sandbox-main` (the parent for all preview branches; seeded with synthetic fixtures only) and — if you also run prod on Neon — `production`. The `production` root lives in a **separate Neon project with separate credentials**; it is network-isolated from the sandbox project.
2. Install the Neon ↔ Vercel integration on the product's Vercel project. Vercel will automatically inject the per-preview `DATABASE_URL` into every preview deployment.
3. For SOC2 products, additionally enable **IP Allow** and **Private Networking** on the sandbox project so anonymized branches can be created without restriction.

## AWS connector — required for production lane

AWS is the production runtime. The connector is also used (with read-only credentials) by SOC2 products to resolve secret references in CLAUDE.md without exposing values.

### Capabilities used

| Capability                                | Used by                                              | What it does                                                                                              |
| ----------------------------------------- | ---------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| **Secrets Manager / SSM Parameter Store** | `/promote`, runtime apps (production lane only)       | Resolve secret references like `/prod/<product>/<key>`. Read-only from Claude; never paste values in chat. |
| **Terragrunt deploys** (via GitHub Actions OIDC) | CI                                              | Production stacks are deployed by GitHub Actions running `terragrunt run-all apply` (with OpenTofu under the hood), assuming a deploy role via OIDC. Claude never runs `terragrunt apply`, `tofu apply`, or `terraform apply` directly. |
| **CloudWatch Logs** (read)                | `drift-monitor`, production-graded gate               | Read structured logs to assess error rates post-promotion.                                                |
| **CloudFront / S3** (read)                | `/proposal-status`                                    | Sanity-check that production assets shipped.                                                              |

> **AWS is production-only.** A `lane: prototype` branch is forbidden from reaching AWS production resources. The deploy job enforces this by reading `branch.yaml#lane` before selecting credentials (see [spec §9.9](./docs/collaborative-ai-workflow-spec.md#99-runtime-guarantees--prototypeproduction-isolation)).

## Recommended connectors

### Sentry

Used by `/promote` and the production-graded gate. Without it, the gate falls
back to "human asserts that error rates look fine" — which is fragile. Connect
Sentry to:

- Project: per Element 22 product
- Scope: read issues, read events, search by tag (we tag events with the flag
  name for the suspect-flag query)

### Statsig (feature flags)

`/promote` mutates feature flags. Application code accesses flags through the **OpenFeature SDK** so the flag platform stays swappable; Statsig is the team's currently preferred provider behind that abstraction. Connect Statsig for the team that owns the product. Without it, promotion is a chat-only confirmation Claude cannot enact, and the constitution's promotion governance breaks.

### Microsoft Teams

Used by `change-idea-intake` skill (offers "paste to an engineer in Microsoft Teams" as a
direct-handoff option) and `/proposal-status` (champion pings, gentle nudges).
Without it, those flows degrade to "give the user a copy-pasteable message
block" — still usable, less automated.

### `context7`

Used by every command before it generates code, to fetch current API/version
documentation. Without it, Claude is more likely to hallucinate an outdated API.
Not a blocker, but strongly recommended.

## SOC2-overlay connectors

AWS Secrets Manager / SSM is already the production secrets store for every product (see the AWS connector section above). The SOC2 overlay adds these extra requirements on top:

- **Two read-only roles**, one for engineers and one for Claude, both auditable in CloudTrail.
- **Reference-only resolution**: Claude reads the secret *path* (e.g., `/prod/<product>/<key>`) from CLAUDE.md and resolves it at runtime via the AWS connector; the value never appears in chat, files, or PR descriptions.
- **Sensitive prototypes (spec §9.7)** use a further-isolated Neon project + a further-isolated Vercel project, distinct from non-sensitive prototype infrastructure.

If your role doesn't have AWS access, that's fine — Claude will surface the path in chat for the human to resolve, but will never paste a value into a file.

## Connector compatibility by surface

The same connectors work across all three Claude surfaces; the wiring differs
slightly. **This is what makes the e22-plugins workflow surface-portable**: the
plugins themselves don't care which surface they're running on, only that the
required connectors are reachable.

| Surface          | GitHub | Vercel | Neon | AWS | Sentry | Flags | Microsoft Teams | context7 |
| ---------------- | :----: | :----: | :--: | :-: | :----: | :---: | :-------------: | :------: |
| Claude.ai (Chat) | ✅     | ✅     | ✅   | ✅  | ✅     | ✅    | ✅              | ✅       |
| Claude Cowork    | ✅     | ✅     | ✅   | ✅  | ✅     | ✅    | ✅              | ✅       |
| Claude Code      | ✅ (or `gh` CLI fallback) | ✅ | ✅ | ✅ (or `aws` CLI fallback) | ✅ | ✅ | ✅ | ✅ |

## See also

- [`CONSTITUTION.md`](./CONSTITUTION.md) — declares which connectors are required
  and forbids storing secret values in committed files.
- [`TECH-STACK.md`](./TECH-STACK.md) — the team's preferred tech stack; lane-specific infrastructure choices live in §1.
- [`collaborative-ai-workflow-spec.md`](./docs/collaborative-ai-workflow-spec.md) — the full operational specification; §9.9 details the runtime guarantees that depend on the Vercel/Neon vs AWS split.
- [`README.md`](./README.md#surface-compatibility) — the surface-compatibility
  matrix per plugin (including the hooks caveat).
- [`templates/claude-settings.json`](./templates/claude-settings.json) — the
  per-product settings template; mentions the connector requirement so trusting
  a product folder also nudges teammates to connect GitHub, Vercel, Neon, and AWS.

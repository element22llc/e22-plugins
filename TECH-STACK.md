# Element 22 Tech Stack Preferences

This file is the **preference list** Claude consults when choosing a tech stack
for a new Element 22 product or subsystem. It is a template — edit it freely as
your team's preferences evolve.

> **How this file is used.** When Claude is asked to start a new product, pick a
> framework, add a dependency, or scaffold a service, it MUST read this file
> first. Existing products keep their stack; this file governs greenfield
> choices and tie-breakers. For ongoing version checks, prefer `context7` or a
> fresh web search over recalling versions from training data — the
> "Last verified" dates below are when the list was last refreshed, not a
> contract.
>
> **Authoritative versions live in manifests.** This file lists *preferred*
> versions. Per-product `package.json` / `pyproject.toml` / `Cargo.toml` /
> `go.mod` / `*.tf` files are the source of truth for what is actually
> installed. Never claim a version from this file without checking the manifest.

**Last refreshed:** 2026-05-25
**Owner of this file:** Engineering — update via PR.

---

## How to read this file

Each category lists:

- **Preferred** — the team's default choice. Use this unless you have a documented reason not to.
- **Acceptable** — second-tier choices, used only where the Preferred option is a poor fit.
- **Not allowed** — choices the team has explicitly ruled out. Do not introduce these without an ADR.

When Claude is making a choice, the order is: **Preferred → Acceptable → ask the user.** Never pick a "Not allowed" entry.

---

## 1. Lane-specific infrastructure

The lane (Prototype vs Production) decides which infrastructure stack a branch is allowed to deploy against. This mirrors `branch.yaml#lane` in the spec.

| Concern | Prototype Lane | Production Lane |
|---|---|---|
| Hosting / runtime | **Vercel** (per-branch preview URL) | **AWS** (ECS Fargate or Lambda + API Gateway, per product) |
| Database | **Neon Postgres**, branch-per-preview via the Neon ↔ Vercel integration | **AWS RDS Postgres** (or **Neon** if the product explicitly opts in for prod) |
| Object storage | Vercel Blob (sandbox bucket) | **AWS S3** |
| Secrets | Vercel sandbox env vars (sandbox namespace only) | **AWS Secrets Manager / SSM Parameter Store** |
| CDN / edge | Vercel Edge Network | **AWS CloudFront** (in front of the product's origin) |
| Background jobs | Vercel Cron / inline (sandbox only) | **AWS EventBridge + Lambda** or **ECS scheduled tasks** |
| Email / notifications | **Mailpit** sandbox sink (no real sends) | **AWS SES** |

**Hard rules** (also encoded in CONSTITUTION.md and spec §9.9):

1. A `lane: prototype` branch **never** reaches AWS production resources. Vercel + Neon-sandbox-branch only.
2. A `lane: production` branch **never** holds production credentials in a Vercel preview. Vercel previews of a production-lane PR still run against a sandbox Neon branch.
3. Infrastructure-as-code lives under `infra/` and is the only path that may touch production AWS.

---

## 2. Languages & runtimes

| Slot | Preferred | Acceptable | Not allowed | Last verified |
|---|---|---|---|---|
| **TypeScript** | TypeScript **6.0.x** (strict mode default; target ES2025) | TypeScript 5.9.x for legacy products mid-migration | TypeScript ≤ 5.4, JavaScript-only new code | 2026-05 |
| **Node.js** | Node **24 LTS** (Active until ~Oct 2026, then 26 LTS) | Node 22 (Maintenance LTS) for legacy products | Node ≤ 20, Node 23/25 (odd current lines) in production | 2026-05 |
| **Python** | Python **3.14** | Python 3.13 | Python ≤ 3.11 | 2026-05 |
| **Go** | Latest stable (declared per-product) | — | — | 2026-05 |
| **Rust** | Latest stable | — | Nightly in production builds | 2026-05 |

When TypeScript 7.0 reaches stable (currently beta on the Go-based compiler), promote it to Preferred after a one-product canary.

---

## 3. Web app framework

| Slot | Preferred | Acceptable | Not allowed | Last verified |
|---|---|---|---|---|
| **React framework** | **Next.js 16.2.x** (App Router, Turbopack default, React Compiler stable) | Next.js 15.x for products mid-upgrade | Pages Router for greenfield work; Create-React-App | 2026-05 |
| **React** | React 19.x (paired with Next.js 16) | React 18.x in legacy products | React ≤ 17 in greenfield | 2026-05 |
| **Styling** | Tailwind CSS v4.x + shadcn/ui | CSS Modules; vanilla-extract | Plain global CSS in greenfield; CSS-in-JS runtime libraries (styled-components, emotion runtime) | 2026-05 |
| **Forms** | React Hook Form + Zod | TanStack Form | Uncontrolled DOM forms for non-trivial flows | 2026-05 |
| **Data fetching (client)** | TanStack Query | SWR | Hand-rolled fetch in `useEffect` for cache-relevant data | 2026-05 |
| **State (client)** | URL state + React state + Zustand (when warranted) | Jotai | Redux for new code | 2026-05 |

---

## 4. Backend & APIs

| Slot | Preferred | Acceptable | Not allowed | Last verified |
|---|---|---|---|---|
| **API style** | oRPC (TS-only stack) **or** OpenAPI-described REST | GraphQL (only when graph shape genuinely fits) | Bespoke RPC schemes without a spec file | 2026-05 |
| **Validation** | Zod (TS), Pydantic v2 (Python) | — | Ad-hoc runtime checks | 2026-05 |
| **ORM (TS)** | **Prisma ORM** (with Prisma TypedSQL for raw-SQL escape hatches) | Drizzle for products that have already standardized on it | Raw `pg` queries scattered across the app outside a thin DAL | 2026-05 |
| **ORM (Python)** | SQLAlchemy 2.x + Alembic | — | — | 2026-05 |
| **Auth (product-facing)** | **Better-Auth** (preview) / **Better-Auth with AWS Cognito** (production) | — | Hand-rolled session tables | 2026-05 |
| **Internal service auth** | mTLS via AWS PrivateLink + IAM Auth | OAuth2 client credentials | Long-lived static tokens | 2026-05 |

---

## 5. Database & data platform

| Slot | Preferred | Acceptable | Not allowed | Last verified |
|---|---|---|---|---|
| **OLTP** | **Postgres** — Neon (preview) / RDS (production) | Aurora Serverless v2 Postgres when steady-state RDS cost becomes prohibitive | MySQL, MongoDB, DynamoDB for relational data | 2026-05 |
| **Migrations** | Prisma Migrate (TS) / Alembic (Python) | golang-migrate | Bespoke SQL scripts run by hand | 2026-05 |
| **Caching** | **Valkey** on Fargate (Redis-OSS-compatible) | Upstash Redis for preview | In-process caches for cross-instance data | 2026-05 |
| **Search / analytics** | Postgres + `pg_trgm` first; OpenSearch when warranted | — | Elasticsearch (license drift) | 2026-05 |
| **Warehouse** | Postgres (declared per-product; usually a read replica of RDS) | DuckDB for embedded analytics | — | 2026-05 |

**Neon-specific guidance.** The Neon ↔ Vercel integration creates a per-preview database branch via copy-on-write — no data copy, instant. Use this for previews. Production may pin to RDS for full VPC isolation, or Neon if the product opts in.

---

## 6. Infrastructure as Code

| Slot | Preferred | Acceptable | Not allowed | Last verified |
|---|---|---|---|---|
| **IaC for AWS** | **Terragrunt + OpenTofu** | Terraform (legacy projects only — those that pre-date the OpenTofu fork and have not migrated yet) | AWS CDK / CloudFormation YAML by hand / Pulumi mixed with the above for new projects | 2026-05 |
| **Multi-env layering** | Terragrunt `run-all` with per-env directories under `infra/live/<env>/<product>/` | Per-stack `terragrunt.hcl` for one-off stacks | Per-env forked codebases; CDK Stages for new code | 2026-05 |
| **Module source** | Internal `infra/modules/` (versioned via git tags) and audited OpenTofu Registry modules | Public Terraform Registry modules pinned by version | Forking a public module into the repo without a documented reason | 2026-05 |
| **Vercel config** | `vercel.json` in repo + Neon integration | — | Drift between Vercel UI and repo | 2026-05 |

**Why Terragrunt + OpenTofu.** OpenTofu is the community-governed fork of Terraform with a permissive license; Terragrunt sits on top to keep environments DRY and to wire backend / providers / remote state consistently across `infra/live/<env>/<product>/`. Legacy products still on Terraform are acceptable; new products start on OpenTofu. Migrations from Terraform → OpenTofu are usually a one-line state operation and are not blocking.

---

## 7. CI / CD

| Slot | Preferred | Acceptable | Not allowed | Last verified |
|---|---|---|---|---|
| **CI** | GitHub Actions | — | Jenkins / CircleCI for new repos | 2026-05 |
| **Test runner (TS)** | Vitest | Jest (legacy) | Mocha for new code | 2026-05 |
| **E2E** | Playwright | — | Cypress for new products | 2026-05 |
| **Lint / format** | Biome (preferred) or ESLint + Prettier | — | No formatter | 2026-05 |
| **Package manager (TS)** | **pnpm 11.x** (requires Node ≥ 22, ESM-only) | — | npm or yarn classic in greenfield monorepos | 2026-05 |

---

## 8. Observability

| Slot | Preferred | Acceptable | Not allowed | Last verified |
|---|---|---|---|---|
| **Errors** | Sentry | — | console.log as error tracking | 2026-05 |
| **Metrics & traces** | **OpenTelemetry** → AWS CloudWatch (metrics, X-Ray for traces) | Datadog (where already paid for) | Bespoke metrics endpoints | 2026-05 |
| **Logs** | AWS CloudWatch Logs (structured JSON) | — | Plaintext logs in production | 2026-05 |
| **Feature flags** | **Statsig** (preferred platform); abstracted behind the OpenFeature SDK in app code | LaunchDarkly (where already paid for) | Bespoke flag tables | 2026-05 |

---

## 9. AI / LLM stack

| Slot | Preferred | Acceptable | Not allowed | Last verified |
|---|---|---|---|---|
| **LLM provider** | Anthropic Claude (Opus 4.7 / Sonnet 4.6 / Haiku 4.5) | OpenAI for narrowly scoped tasks where Claude is unavailable | Provider lock-in without an abstraction layer | 2026-05 |
| **Agent framework** | Claude Agent SDK | — | LangChain-as-the-core for greenfield work | 2026-05 |
| **Doc retrieval (dev-time)** | `context7` (Upstash) MCP for current API docs | Direct web search via Claude | Trusting recalled API shapes for code generation | 2026-05 |

---

## 10. How to update this file

1. Open a PR that edits this file.
2. Bump the **Last refreshed** date at the top.
3. For any version change, run `context7` or a web search the same day to confirm the current stable, and update the **Last verified** column for that row.
4. Tag the PR with `tech-stack` and request review from the platform team.
5. If you're adding a new "Not allowed" entry, link the ADR that supports it.

> **Discipline:** keep this list short. If a row has four "Acceptable" entries, the team has not actually decided. Force a choice or admit the row is undefined.

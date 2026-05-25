# Element 22 Tech Stack Preferences

This file is the **preference list** Claude consults when choosing a tech stack
for a new Element 22 product or subsystem. It is a template — edit it freely as
your team's preferences evolve.

> **How this file is used.** When Claude is asked to start a new product, pick a
> framework, or add a dependency, it MUST read this file
> first. Existing products keep their stack; this file governs greenfield
> choices and tie-breakers. For ongoing version checks, prefer `context7` or a
> fresh web search over recalling versions from training data — the
> "Last verified" dates below are when the list was last refreshed, not a
> contract.
>
> **Authoritative versions live in manifests.** This file lists *preferred*
> versions. Per-product `package.json` / `pyproject.toml` / `Cargo.toml` /
> `go.mod` files are the source of truth for what is actually
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

## 1. Languages & runtimes

| Slot | Preferred | Acceptable | Not allowed | Last verified |
|---|---|---|---|---|
| **TypeScript** | TypeScript **6.0.x** (strict mode default; target ES2025) | TypeScript 5.9.x for legacy products mid-migration | TypeScript ≤ 5.4, JavaScript-only new code | 2026-05 |
| **Node.js** | Node **24 LTS** (Active until ~Oct 2026, then 26 LTS) | Node 22 (Maintenance LTS) for legacy products | Node ≤ 20, Node 23/25 (odd current lines) in production | 2026-05 |
| **Python** | Python **3.14** | Python 3.13 | Python ≤ 3.11 | 2026-05 |
| **Go** | Latest stable (declared per-product) | — | — | 2026-05 |
| **Rust** | Latest stable | — | Nightly in production builds | 2026-05 |

When TypeScript 7.0 reaches stable (currently beta on the Go-based compiler), promote it to Preferred after a one-product canary.

**Tool version management — use [mise](https://mise.jdx.dev/).** Every project that can express its toolchain in mise MUST do so. A repo-root `mise.toml` is the **source of truth for installed versions** locally and in CI — Node, Python, Go, Rust, plus per-product tools like `pnpm`, `pre-commit`, `biome`, etc. Per-language manifests (`package.json#engines`, `pyproject.toml#requires-python`, `go.mod`) still declare the *minimum* required version; `mise.toml` pins the *exact* one installed. Prefer mise over `nvm` / `pyenv` / `asdf` / Homebrew-installed runtimes / "just install it globally" — one tool, one config file, one set of versions across dev machines and CI. Use a different manager only when the toolchain genuinely cannot be expressed in mise (rare); document the reason in the product's `CLAUDE.md`.

---

## 2. Web app framework

| Slot | Preferred | Acceptable | Not allowed | Last verified |
|---|---|---|---|---|
| **React framework** | **Next.js 16.2.x** (App Router, Turbopack default, React Compiler stable) | Next.js 15.x for products mid-upgrade | Pages Router for greenfield work; Create-React-App | 2026-05 |
| **React** | React 19.x (paired with Next.js 16) | React <= 18.x in legacy products | 2026-05 |
| **Styling** | Tailwind CSS v4.x + shadcn/ui | CSS Modules; vanilla-extract | 2026-05 |
| **Forms** | React Hook Form + Zod | TanStack Form | Uncontrolled DOM forms for non-trivial flows | 2026-05 |
| **Data fetching (client)** | TanStack Query | SWR | Hand-rolled fetch in `useEffect` for cache-relevant data | 2026-05 |
| **State (client)** | URL state + React state + Zustand (when warranted) | Jotai | Redux for new code | 2026-05 |

---

## 3. Backend & APIs

| Slot | Preferred | Acceptable | Not allowed | Last verified |
|---|---|---|---|---|
| **API style** | oRPC (TS-only stack) **or** OpenAPI-described REST | GraphQL (only when graph shape genuinely fits) | Bespoke RPC schemes without a spec file | 2026-05 |
| **Validation** | Zod (TS), Pydantic v2 (Python) | — | Ad-hoc runtime checks | 2026-05 |
| **ORM (TS)** | **Prisma ORM** (with Prisma TypedSQL for raw-SQL escape hatches) | Drizzle for products that have already standardized on it | Raw `pg` queries scattered across the app outside a thin DAL | 2026-05 |
| **ORM (Python)** | SQLAlchemy 2.x + Alembic | — | — | 2026-05 |
| **Auth (product-facing)** | **Better-Auth** (declared per-product whether session storage is in-process, in-DB, or via an external identity provider) | — | Hand-rolled session tables | 2026-05 |
| **Internal service auth** | mTLS or OAuth2 client credentials (declared per-product) | — | Long-lived static tokens | 2026-05 |

---

## 4. Database & data platform

| Slot | Preferred | Acceptable | Not allowed | Last verified |
|---|---|---|---|---|
| **OLTP** | **Postgres** (preferred for all OLTP workloads — provisioning mechanism declared per-product) | Aurora Serverless v2 Postgres when steady-state cost becomes prohibitive | MySQL, MongoDB, DynamoDB for relational data | 2026-05 |
| **Migrations** | Prisma Migrate (TS) / Alembic (Python) | golang-migrate | Bespoke SQL scripts run by hand | 2026-05 |
| **Caching** | **Valkey** (Redis-OSS-compatible; deployment mechanism declared per-product) | Upstash Redis for preview | In-process caches for cross-instance data | 2026-05 |
| **Search / analytics** | Postgres + `pg_trgm` first; OpenSearch when warranted | — | Elasticsearch (license drift) | 2026-05 |
| **Warehouse** | Postgres (declared per-product; usually a read replica) | DuckDB for embedded analytics | — | 2026-05 |

---

## 5. CI / CD

| Slot | Preferred | Acceptable | Not allowed | Last verified |
|---|---|---|---|---|
| **CI** | GitHub Actions | — | Jenkins / CircleCI for new repos | 2026-05 |
| **Test runner (TS)** | Vitest | Jest (legacy) | Mocha for new code | 2026-05 |
| **E2E** | Playwright | — | Cypress for new products | 2026-05 |
| **Lint / format** | Biome (preferred) or ESLint + Prettier | — | No formatter | 2026-05 |
| **Package manager (TS)** | **pnpm 11.x** (requires Node ≥ 22, ESM-only) | — | npm or yarn classic in greenfield monorepos | 2026-05 |
| **Tool version manager** | **mise** (repo-root `mise.toml` pins exact runtime + tool versions; see §1 callout) | `asdf` for legacy products mid-migration | `nvm` / `pyenv` standalone, Homebrew-installed language runtimes, global `npm install -g` for project tools | 2026-05 |

---

## 6. Observability

| Slot | Preferred | Acceptable | Not allowed | Last verified |
|---|---|---|---|---|
| **Errors** | Sentry | — | console.log as error tracking | 2026-05 |
| **Metrics & traces** | **OpenTelemetry** (export target declared per-product) | Datadog (where already paid for) | Bespoke metrics endpoints | 2026-05 |
| **Logs** | Structured JSON to stdout (collection target declared per-product) | — | Plaintext logs in production | 2026-05 |
| **Feature flags** | **Statsig** (preferred platform); abstracted behind the OpenFeature SDK in app code | LaunchDarkly (where already paid for) | Bespoke flag tables | 2026-05 |

---

## 7. AI / LLM stack

| Slot | Preferred | Acceptable | Not allowed | Last verified |
|---|---|---|---|---|
| **LLM provider** | Anthropic Claude (Opus 4.7 / Sonnet 4.6 / Haiku 4.5) | OpenAI for narrowly scoped tasks where Claude is unavailable | Provider lock-in without an abstraction layer | 2026-05 |
| **Agent framework** | Claude Agent SDK | — | LangChain-as-the-core for greenfield work | 2026-05 |
| **Doc retrieval (dev-time)** | `context7` (Upstash) MCP for current API docs | Direct web search via Claude | Trusting recalled API shapes for code generation | 2026-05 |

---

## 8. How to update this file

1. Open a PR that edits this file.
2. Bump the **Last refreshed** date at the top.
3. For any version change, run `context7` or a web search the same day to confirm the current stable, and update the **Last verified** column for that row.
4. Tag the PR with `tech-stack` and request review from the platform team.
5. If you're adding a new "Not allowed" entry, link the ADR that supports it.

> **Discipline:** keep this list short. If a row has four "Acceptable" entries, the team has not actually decided. Force a choice or admit the row is undefined.

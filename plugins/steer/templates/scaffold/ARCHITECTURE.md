# Architecture

How this system is built: the tech stack, the pieces and what each owns, how a
request flows through them, and the cross-cutting concerns. This is the
**engineer's system model** — the orientation a new contributor (or Claude)
reads before touching code.

**Scope — narrative and tables only.** *Why* a choice was made → an ADR in
[`/spec/decisions/`](./spec/decisions); *diagrams* → [`/spec/design/`](./spec/design)
(link them here, don't redraw them); *how to use/operate* the product →
[`/spec/app/`](./spec/app). Keep this file describing *what is*, not *why* or
*how-to*. It's a valid stub today — **grow it as the system grows**, in the same
PR that changes the stack, adds an app/package, or reshapes the data flow
(living-docs rule).

## Tech stack

Sourced from `package.json` / `mise.toml` / `compose.yaml` — keep versions in
step with those, don't hand-maintain a second copy.

| Layer | Choice | Version | Notes |
| --- | --- | --- | --- |
| Runtime | [e.g. Node] | [from mise.toml] | |
| Language | [e.g. TypeScript] | [from package.json] | |
| Frontend | [e.g. Next.js + Tailwind] | | |
| Backend | [e.g. in-Next route handlers] | | [standalone `apps/api`? note the ADR] |
| Database | [e.g. PostgreSQL] | | |
| ORM / data access | [e.g. Drizzle] | | |
| Auth | [e.g. Better Auth] | | high-risk — ADR-NNNN |
| Testing | [e.g. Vitest / Playwright] | | |
| Tooling | [e.g. pnpm, Biome, mise] | | |
| Error tracking | [e.g. Sentry] | | |

Deviations from the org-wide stack defaults are recorded as ADRs and noted in
[`CLAUDE.md`](./CLAUDE.md) → *Stack overrides*.

## Monorepo map

What each deployable app and shared package owns — the system-wide view the
per-directory READMEs don't give.

| Path | Kind | Responsibility |
| --- | --- | --- |
| `apps/[web]` | app (deployable) | [one line] |
| `packages/[core]` | package (shared) | [one line] |

See [`apps/README.md`](./apps/README.md) and
[`packages/README.md`](./packages/README.md) for what belongs where.

## How it fits together

[The request → response path, and the layer boundaries (UI → server →
services → data). Two or three sentences. Link any diagram in `/spec/design/`
rather than inlining it.]

## Cross-cutting concerns

One line each, linking the owning ADR or contract:

- **Auth & tenancy** — [model; ADR-NNNN]
- **Persistence & migrations** — [strategy; ADR-NNNN, see `/spec/reference/`]
- **Config & secrets** — [where they live; never committed]
- **Error tracking & observability** — [tool; where alerts go]

## Where to look next

- Decisions and their rationale → [`/spec/decisions/`](./spec/decisions) (ADRs)
- Diagrams → [`/spec/design/`](./spec/design)
- Per-feature behaviour → `/spec/features/[id]/contract.md`
- How to use/operate the product → [`/spec/app/`](./spec/app)
- Stack overrides & product-specific patterns → [`CLAUDE.md`](./CLAUDE.md)

# `/steer:adopt`

Reverse-engineer a `/spec` spine from an existing codebase and add the bundled
scaffold, leaving the repo working spec-first.

!!! info "When to use"
    Use when a repo has working code but no `/spec` spine and no `mise.toml`, or
    when asked to adopt or onboard an existing app onto the standards.

## What it does

```mermaid
flowchart TD
    CODE[Existing codebase] --> READ[Read code + structure]
    READ --> SPINE[Materialize /spec spine<br/>intent, contract, glossary, history/]
    READ --> SCAFFOLD[Install bundled scaffold<br/>CI, mise.toml, compose, PR template]
    SPINE --> STAMP[Stamp /spec/.version]
    SCAFFOLD --> STAMP
    STAMP --> PR[Propose a PR]
```

1. Applies any pending structural migrations from the ledger **first**, before
   deciding anything else.
2. Reads the existing code to capture **what is** — not what someone decided.
3. Materializes the `/spec` spine from the bundled templates — including the
   `design/` home (`README.md`, `source.md`, the living
   `architecture-diagram.md`) and `sources/README.md`.
4. Reverse-engineers the root **`DESIGN.md`** from the app's real visual
   identity (tokens, type scale, component patterns) — as-built, not aspirational.
5. Triages the codebase into **`spec/PRODUCTIONIZATION.md`** — a Keep / Refactor
   / Rewrite / Reject verdict per area, with the reasoning, so the team inherits
   a ranked remediation plan rather than a verdict-free inventory.
6. Installs the repo scaffold (toolchain, CI, PR template).
7. If the tracker is GitHub Issues, bootstraps the label taxonomy
   (`/steer:issues bootstrap-labels`) and verifies the org-level
   Priority/Effort/date issue fields (`/steer:tracker-sync bootstrap-fields`) —
   the same tracker setup `/steer:init` performs.
8. Stamps `/spec/.version` with the plugin version.

## Guardrails

- **Read-then-propose.** Adopt never clobbers human content and lands changes via
  a PR, never a direct push to `main`.
- **No ADR from inference.** Adopt must never infer a *ratified* ADR from code.
  The as-built spine records what exists; a decision that was never explicitly
  made is not an ADR. See [Product spine](../concepts/product-spine.md).
- **One product across several existing repos is a topology decision first.**
  Adoption is per repo, so reverse-engineering a full spine into each of them
  manufactures the very split-brain the
  [polyrepo topology](../concepts/product-spine.md#one-product-several-repos)
  exists to prevent. Adopt recommends a monorepo out loud, and only when the split
  is externally mandated does it bootstrap the workspace repo first and give each
  member a `spec/PRODUCT.md` pointer *instead of* product-level spine files.

## After adopting

- Run `/steer:audit spec` to compare the as-built spine against the tracker's intent.
- Run `/steer:sync` after future plugin releases to stay current.

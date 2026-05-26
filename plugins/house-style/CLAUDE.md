# house-style — always-loaded conventions

Loaded into every Claude session when `house-style` is installed. Applies in
**both** zones (sandbox and governed) — the team's tech-stack choices matter
for MVP work too, so the prototype isn't built on a stack that will be
discarded at handoff.

The PostToolUse lint/format hook is zone-gated and runs only in
governed-production repos. These instructions are not.

## Read the stack before generating code

Before generating code in any zone:

1. Read [`TECH-STACK.md`](../../TECH-STACK.md) for the team's preferred
   languages, frameworks, ORM, tests, observability, feature-flag tooling,
   and infrastructure.
2. Read the nearest product `CLAUDE.md` (`apps/<product>/CLAUDE.md`) for any
   per-product stack divergence or convention.
3. Read the nearest manifest file (`mise.toml`, `package.json`,
   `pyproject.toml`, `Cargo.toml`, `go.mod`) for the authoritative pinned
   versions. **Never claim a version from memory.**

If a manifest is missing or the stack is unclear, ask — do not guess.

## Prefer the latest stable version

When adding a dependency that the product does not already pin:

- Pick the latest stable release (not pre-release, not RC).
- If `context7` is installed, defer to it for current API and version docs
  rather than relying on training-data recall.
- Mention the version you picked in the PR description or HANDOFF.md so Dev
  can see it at review time.

This rule applies in both zones. POs building MVPs benefit from the same
stack choices as production — it makes the Dev decision (Harden / Extract /
Rewrite) simpler.

## Naming and folder conventions

Advisory in the sandbox; enforced by the PostToolUse hook in governed repos.

- Follow the patterns already present in the product. If the codebase uses
  `kebab-case` for files, do not introduce `camelCase`.
- New endpoints/handlers/jobs live where existing ones live — do not create
  parallel layouts.
- Shared utilities go in the product's existing shared directory (`packages/`,
  `shared/`, `lib/`); do not duplicate within a feature directory.

## Tool version manager

Every project that can express its toolchain in [mise](https://mise.jdx.dev/)
must do so. Do not introduce parallel installs via `nvm`, `pyenv`, `asdf`,
Homebrew, or global `npm i -g` unless explicitly documented in the product's
`CLAUDE.md`.

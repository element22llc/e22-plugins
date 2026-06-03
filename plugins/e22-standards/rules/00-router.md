# Element 22 — Operating Manual (org standards)

These are Element 22's organization-wide engineering standards, injected into
every Claude session by the **e22-standards** plugin. They are the same for
every E22 product repo and are maintained centrally in
[`element22llc/e22-plugins`](https://github.com/element22llc/e22-plugins) — do
not copy them into a product's `CLAUDE.md`. That repo's own `CLAUDE.md` holds
only product-specific context (the Product paragraph, stack overrides, and
team-learned patterns).

This is a lean **router**: short, always-on rules below, with the full prose
available on demand so it does not cost tokens every turn.

- Full conventions (versioning, toolchain, workspace tools, lint/test) → run **`/e22-conventions`**.
- Design-source handling (Claude Design exports) → run **`/e22-design-sources`**.
- Spec ↔ code coupling rules → opened by **`/e22-spec-scaffold`**, or read on demand.
- Fresh fork? → run **`/e22-init`** once to resolve placeholders, pin the toolchain, and replace the starter.

When you pick or change the stack, sanity-check current stable versions (run
`/e22-conventions`) — don't trust training-data memory.

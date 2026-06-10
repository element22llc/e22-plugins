# Element 22 — Operating Manual (org standards)

Element 22's org-wide engineering standards, injected into every session by the
**e22-standards** plugin and maintained centrally in
[`element22llc/e22-plugins`](https://github.com/element22llc/e22-plugins) — do
not copy them into a product's `CLAUDE.md`, which holds only product-specific
context (Product paragraph, stack overrides, team-learned patterns).

This is a lean **router**: short always-on rules below, full prose on demand:

- Full conventions (versioning, toolchain, lint/test, patterns) → **`/e22-conventions`**.
- Design-source handling → **`/e22-design-sources`**.
- Spec ↔ code coupling rules → opened by **`/e22-spec-scaffold`**.
- Fresh fork? → run **`/e22-init`** once.
- Existing repo not forked from the template (a "vibe-coded" app)? → run **`/e22-adopt`** once.
- Loose files cluttering the repo root? → run **`/e22-tidy`** to sort them into `/spec`.
- Built app vs. its specs/tickets — looking for drift? → run **`/e22-drift`** (read-only audit).
- Open questions piling up in the specs? → run **`/e22-questions`** to sweep and answer them.
- On **Claude Cowork / the desktop app** (where this manual is *not* auto-injected) → run **`/e22-standards`** at session start to load these rules on demand.

When you pick or change stack pieces, verify current stable versions in-session
(run `/e22-conventions`) — don't trust training-data memory.

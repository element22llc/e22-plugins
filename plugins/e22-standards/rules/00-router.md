# Element 22 — Operating Manual (org standards)

Element 22's org-wide engineering standards, injected into every session by the
**e22-standards** plugin and maintained centrally in
[`element22llc/e22-plugins`](https://github.com/element22llc/e22-plugins) — do
not copy them into a product's `CLAUDE.md`, which holds only product-specific
context (Product paragraph, stack overrides, team-learned patterns).

This is a lean **router**: short always-on rules below, full prose on demand:

- Full conventions (versioning, toolchain, lint/test, patterns) → **`/e22-conventions`**.
- Living docs, action history, tracker integration, drift gates, audit-aligned delivery → **`/e22-traceability`**.
- Design-source handling → **`/e22-design-sources`**.
- Spec ↔ code coupling rules → opened by **`/e22-spec-scaffold`**.
- New repo (or legacy template fork)? → run **`/e22-init`** once — the plugin's bundled scaffold bootstraps the spec spine + repo scaffolding, *before* feature code.
- Existing repo with working code but no `/spec` (a "vibe-coded" app to reverse-engineer)? → run **`/e22-adopt`** once.
- No `/spec` spine yet? The SessionStart hook flags it — bootstrap (`/e22-init` greenfield, or `/e22-adopt`) before writing feature code; don't degrade to toolchain-only.
- Loose files cluttering the repo root? → run **`/e22-tidy`** to sort them into `/spec`.
- Want to design a feature without building it? → run **`/e22-spec`** — author and iterate the spec (intent + open questions) and stop at an approved intent; the no-build counterpart to `/e22-build`.
- As-built `/spec` (from `/e22-adopt`) vs. the tracker spec export (Jira/Linear/GitHub Issues, …) — looking for drift? → run **`/e22-drift`** (read-only spec-vs-spec audit; needs `/spec` first).
- Tracker is GitHub Issues and you want the full product lifecycle (PO capture → triage → brainstorm → materialize → decompose → status)? → run **`/e22-issues`** — the high-level orchestrator; delegates to the spec/audit/drift/question skills and routes all GitHub I/O through `/e22-tracker-sync`. Agent issues use a machine-readable contract; `/spec` stays product truth.
- Tracker is GitHub Issues and you just want the low-level gateway? → run **`/e22-tracker-sync`** — the tracker-metadata API (search/get/find-or-create/update/comment/label/set-type/transition/link/close, pull/push for drift) behind `/e22-issues` and `/e22-work` (MCP-first, `gh` fallback; moves tracker metadata, not the spec, and never git/PR delivery).
- Asked to work a specific issue ("work on #123", "fix #123", "implement #123 and #124")? → run **`/e22-work`** — claim, branch, implement, test, open the PR, and transition the issue (one issue per branch/PR by default). Use `start` / `resume` / `status` / `finish`.
- Asked to change code/config/behavior in a **GitHub-adopted** repo with no issue named? → find-or-create the issue first (Issue-first), then `/e22-work`. Capture-only ("note this for later") → `/e22-issues capture`; "what's on the backlog?" → `/e22-issues status`.
- Want the highest-leverage cleanup backlog for a steady-state repo? → run **`/e22-audit`** (read-only, whole-repo code-vs-standards health audit, leverage-ranked; defers correctness/security to `/code-review` & `/security-review`).
- Open questions piling up in the specs? → run **`/e22-questions`** to sweep and answer them.
- Plugin moved on since this repo was bootstrapped (a spec file/section renamed upstream, scaffold changed)? → run **`/e22-sync`** — applies pending structural migrations + reconciles the materialized spine/scaffold to the current plugin, then re-stamps `/spec/.version` (needs `/spec` first; structure only, never refactors code).
- On **Claude Cowork / the desktop app** (where this manual is *not* auto-injected) → run **`/e22-standards`** at session start to load these rules on demand.

When you pick or change stack pieces, verify current stable versions in-session
(run `/e22-conventions`) — don't trust training-data memory.

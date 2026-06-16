# Engineering Standards — Operating Manual (org standards)

The org-wide engineering standards, injected into every session by the
**steer** plugin and maintained centrally in
[`element22llc/e22-plugins`](https://github.com/element22llc/e22-plugins) — do
not copy them into a product's `CLAUDE.md`, which holds only product-specific
context (Product paragraph, stack overrides, team-learned patterns).

This is a lean **router**: short always-on rules below, full prose on demand:

- Full conventions (versioning, toolchain, lint/test, patterns) → **`/steer:conventions`**.
- Living docs, action history, tracker integration, drift gates, audit-aligned delivery → **`/steer:traceability`**.
- Design-source handling → **`/steer:design-sources`**.
- Spec ↔ code coupling rules → part of the spec workflow; author specs via **`/steer:spec`** (it instantiates the templates for you).
- New repo (or legacy template fork)? → run **`/steer:init`** once — the plugin's bundled scaffold bootstraps the spec spine + repo scaffolding, *before* feature code.
- Existing repo with working code but no `/spec` (a "vibe-coded" app to reverse-engineer)? → run **`/steer:adopt`** once.
- No `/spec` spine yet? The SessionStart hook flags it — bootstrap (`/steer:init` greenfield, or `/steer:adopt`) before writing feature code; don't degrade to toolchain-only.
- Loose files cluttering the repo root? → run **`/steer:tidy`** to sort them into `/spec`.
- Want to design a feature without building it? → run **`/steer:spec`** — author and iterate the spec (intent + open questions) and stop at an approved intent; the no-build counterpart to `/steer:build`.
- As-built `/spec` (from `/steer:adopt`) vs. the tracker spec export (Jira/Linear/GitHub Issues, …) — looking for drift? → run **`/steer:drift`** (read-only spec-vs-spec audit; needs `/spec` first).
- Tracker is GitHub Issues and you want the full product lifecycle (PO capture → triage → brainstorm → materialize → decompose → status)? → run **`/steer:issues`** — the high-level orchestrator; delegates to the spec/audit/drift/question skills and routes all GitHub I/O through `/steer:tracker-sync`. Agent issues use a machine-readable contract; `/spec` stays product truth.
- The tracker-metadata gateway behind those orchestrators is **`/steer:tracker-sync`** — the API (search/get/find-or-create/update/comment/label/set-type/transition/link/close, pull/push for drift) that `/steer:issues` and `/steer:work` call (MCP-first, `gh` fallback; moves tracker metadata, not the spec, and never git/PR delivery). It is an **internal helper** invoked by the orchestrators, not a direct entry point — reach tracker work through `/steer:issues` or `/steer:work`.
- Asked to work a specific issue ("work on #123", "fix #123", "implement #123 and #124")? → run **`/steer:work`** — claim, branch, implement, test, open the PR, and transition the issue (one issue per branch/PR by default). Use `start` / `resume` / `status` / `finish`.
- Asked to change code/config/behavior in a **GitHub-adopted** repo with no issue named? → find-or-create the issue first (Issue-first), then `/steer:work`. Capture-only ("note this for later") → `/steer:issues capture`; "what's on the backlog?" → `/steer:issues status`.
- Want the highest-leverage cleanup backlog for a steady-state repo? → run **`/steer:audit`** (read-only, whole-repo code-vs-standards health audit, leverage-ranked; defers correctness/security to `/code-review` & `/security-review`).
- Open questions piling up in the specs? → run **`/steer:questions`** to sweep and answer them.
- Picking the repo up cold, or work spans several features/issues and you need *the one thing to do next*? → run **`/steer:next`** — read-only whole-workspace navigator: reconstructs branch/PR, feature `Status`, open questions, `Proposed` ADRs, tracker issues, and work claims, then arbitrates the single best action across all workflows (the cross-workflow counterpart to each skill's `## Recommended next actions` block). Never edits or commits.
- Plugin moved on since this repo was bootstrapped (a spec file/section renamed upstream, scaffold changed)? → run **`/steer:sync`** — applies pending structural migrations + reconciles the materialized spine/scaffold to the current plugin, then re-stamps `/spec/.version` (needs `/spec` first; structure only, never refactors code).
- On **Claude Cowork / the desktop app** (where this manual is *not* auto-injected) → run **`/steer:standards`** at session start to load these rules on demand.

When you pick or change stack pieces, verify current stable versions in-session
(run `/steer:conventions`) — don't trust training-data memory.

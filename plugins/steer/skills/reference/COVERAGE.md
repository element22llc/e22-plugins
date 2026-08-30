# `/steer:reference` — what each reference doc covers

A per-topic contents listing, for picking the right doc when the one-line table
in `SKILL.md` is not enough to choose. **This file is not the reference prose** —
it is an index of it. Once you have picked a topic, open the actual file under
`${CLAUDE_PLUGIN_ROOT}/templates/reference/` and answer from there, never from
this summary.

## `conventions`

Read the full conventions prose bundled with this plugin:

`${CLAUDE_PLUGIN_ROOT}/templates/reference/CONVENTIONS.md`

It covers, in detail:

- **Versioning policy** — default to current stable; check a registry rather than
  trusting training-data memory; avoid prerelease without a reason.
- **Toolchain** — mise with `latest` in `mise.toml` and the exact versions pinned
  in the committed `mise.lock`; pin-on-adoption via `touch mise.lock` (no lock
  ships — mise only writes the lock if the file exists), then `mise install`,
  then `mise lock --platform linux-x64,macos-arm64` (`mise install` alone locks
  only the host platform, so the lock must be re-locked for every CI/dev platform
  or CI's `mise install --locked` fails on `linux-x64`). Until a populated lock
  is committed CI installs unlocked; never commit an empty / comment-only lock.
  Bump via `mise upgrade`; backends must work on both macOS and Linux.
- **Lockfile discipline** — `mise.lock`, `pnpm-lock.yaml`, `uv.lock`,
  `.terraform.lock.hcl` are committed and updated with every dependency/tool
  change; never deleted or ignored to dodge an error.
- **Standard mise tasks** — `mise run dev:setup` (idempotent: services up →
  migrate → seed) and friends; why environment tasks live in `mise.toml`, not
  `package.json`; how `/steer:init` adapts them per product.
- **Backend placement** — backend inside the Next.js app by default; when a
  standalone `apps/api` or the Python/FastAPI switch is warranted (ADR either way).
- **Local services** — Docker Compose from the template `compose.yaml`, the
  same-engine-as-deployed rule, and how `dev:setup` ties in.
- **Monorepo layout** — `/apps`, `/packages`, `/configs`; polyrepo across
  products, monorepo within one.
- **Workspace tooling** — pnpm (Node), uv (Python).
- **Editor & IDE** — VS Code as the default editor; committed `.vscode/`
  config (recommended extensions + Biome format-on-save); prefer in-editor
  extensions (DB access, etc.) over standalone apps.
- **Linting & formatting** — Biome (Node/TS), Ruff (Python); no ESLint/Prettier
  or Flake8/Black/isort alongside them without an ADR.
- **Testing** — Vitest (Node/TS), pytest (Python).
- **Auth & error tracking** — Better Auth, Sentry; secrets at rest in SSM
  Parameter Store `SecureString` by default, Secrets Manager when warranted.
- **Deployment & environments** — non-prod/prod + review apps, branch-driven
  promotion with the `prod`-branch approval gate, observability baseline, rollback
  & expand/contract migrations.
- **Baseline patterns & anti-patterns** — the full prose behind the always-on
  practices baseline (Drizzle/schema validation/server-first, typing, what to avoid, Python mapping).
- **Commit messages** — the Conventional Commits format (type/scope/breaking-change
  marker), why it's the default, and what's deliberately not adopted (no commit-lint
  gate; commits are not the changelog).
- **Windows** — develop inside WSL2.

## `traceability`

Read the full prose bundled with this plugin:

`${CLAUDE_PLUGIN_ROOT}/templates/reference/TRACEABILITY.md`

It covers, in detail:

- **Living documentation** — the natural-language-to-spec contract: the
  routing table from plain-language statements (goals, decisions, trade-offs,
  questions, validations) to their owning artifacts; extraction discipline
  (extract don't embellish, ask on ambiguity, same-PR updates, propose don't
  stealth-edit); the PO-facing vs dev-facing register split, and the end-user
  surface, which carries no internal ids.
- **Action history** — `/spec/history/` format and worked entry; what it
  serves (auditability, onboarding, review evidence, decision archaeology,
  drift over time); append-only discipline.
- **App knowledge docs** — `/spec/app/` structure (usage, workflows, roles,
  configuration, limitations, troubleshooting, runbook, release notes) and the
  same-PR update trigger.
- **Issue tracker integration** — the client-agnostic model
  (`/spec/tracker.md` declares; everything else just uses the declared ref
  format), the Jira/GitHub/Linear/Azure DevOps adapter table, where refs live,
  and how untracked questions get promoted.
- **Drift gates** — the nine review-sensitive classes, flag-when-noticed
  mechanics, who may resolve a flag, and the periodic sweeps
  (`/steer:audit spec`, `/steer:audit`, `/steer:questions`).
- **SOC 2 / ISO 27001-aligned delivery** — "aligned, never compliant" wording,
  and the expectation→artifact evidence map.
- **Worked examples** — a PO's day and a dev's day through the same workflow.

The lean always-on versions of these rules are `32-living-docs`,
`35-issue-tracker`, `55-drift-gates`, `75-compliance`, and `92-user-facing-copy` —
this reference is their full rationale and how-to.

## `design-sources`

Read the full design-sources walkthrough bundled with this plugin:

`${CLAUDE_PLUGIN_ROOT}/templates/reference/DESIGN-SOURCES.md`

Key points (read the file for the full detail):

- **Most features have no export, or only a partial one — that is normal.** A
  committed export is one useful input; its absence is not a blocker. The
  constant across every path is the product's `DESIGN.md` (below).
- A **Claude Design URL** is a human-only traceability link — Claude **cannot**
  fetch it (it returns `403`). The **local committed export** (ZIP/HTML) is what
  you actually read.
- Where artifacts live: Greenfield product-level → `spec/design/`; feature-level
  → `spec/features/[id]/design-export/` and the `intent.md` `Design source`
  section.
- Read only what's visible (screens, flows, components, copy, states). **Do not
  invent** business rules, permissions, backend behavior, data models, or
  validation — anything not visible goes to the feature's `intent.md` →
  `## Open questions`.
- The design is authoritative for **visual behavior and flow**; the spec is
  authoritative for **what the system does**. Conflicts → the feature's
  `intent.md` → `## Open questions`.
- The export is a **spec to realize in the standard stack, not code to ship**.
  Rebuild the UI (Next.js + TS + Tailwind); the prototype's delivery tech (UMD
  React, in-browser Babel, hand-rolled CSS) is disposable. Serving the prototype
  runtime as a maintained surface is an **ADR-gated, kill-dated exception** — see
  "Realizing the design vs. serving the prototype" in the reference.
- **No / partial export (the common case):** build the UI deliberately, not in
  generic AI defaults. Use the **`frontend-design`** plugin re-listed in this
  marketplace (`/plugin install frontend-design@e22-plugins`) for the craft
  layer — scoped to a professional/enterprise default, the standard stack
  (Next + TS + Tailwind), and accessibility. It fills gaps; it never overrides a
  screen a committed export already designed.
- Reusable product-wide UI rules live in the product's `DESIGN.md` — populated
  as you build (third origin: established while building without an export) so
  every feature stays uniform; feature-specific details stay in the feature's
  `intent.md`.

## `context-hygiene`

Read the full context-hygiene reference bundled with this plugin:

`${CLAUDE_PLUGIN_ROOT}/templates/reference/CONTEXT-HYGIENE.md`

It covers, in detail:

- **The honest boundary** — why a plugin and the model cannot see context usage,
  trigger `/compact`, or start a new session (only the user can), so the design
  makes switching *unnecessary* rather than automatic.
- **Delegate heavy runs to a subagent** — when a run is long, multi-phase, or
  search-heavy, fork it (fresh context by construction) and return only the
  structured result; which model tier each shape wants (read/search fan-out →
  Sonnet-tier at low effort; reviewer/verify delegations → session model); the
  steer exemplars (`/steer:audit` → `steer-reviewer`, `/steer:work --reviewed`)
  and when *not* to fork.
- **Keep durable state in files** — what survives compaction (`/spec/**`, rules,
  CLAUDE.md) vs the chat (which does not); the run-state and constraint sidecar
  contract, with an example shape.
- **The fallback nudge** — only when the thread is genuinely overloaded, recommend
  `/compact` or a fresh session and pre-compose the hand-off, honest that it is a
  recommendation you cannot perform.
- **A worked example** — the part-regeneration scenario end to end.

The lean always-on version of this is rule `26-context-hygiene` — this reference is
its full rationale and how-to.

## architecture-diagrams

`${CLAUDE_PLUGIN_ROOT}/templates/reference/ARCHITECTURE-DIAGRAMS.md`

It covers, in detail:

- **Why the diagram lives in `spec/design/architecture-diagram.md`, not
  `ARCHITECTURE.md`** — the "link, don't inline" contract keeps `ARCHITECTURE.md`
  narrative + tables, gives the diagram one canonical, renderable home, and keeps
  the two basenames distinct.
- **Tier 1 — Mermaid (default, zero toolchain)** — which diagram types to use
  (`flowchart`/C4-style context + `sequenceDiagram` for the request flow), and that
  it renders natively in GitHub and the docs site with nothing to install.
- **Tier 2 — LikeC4 (opt-in)** — when a hand-drawn Mermaid diagram stops scaling:
  define a C4 model in `*.likec4`, get navigable views, and export Mermaid back into
  `architecture-diagram.md` so the two tiers compose. Includes the inert
  `diagrams:render` mise task and how to activate it.
- **Drift discipline** — the diagram is updated in the same PR that reshapes the
  system (living-docs rule `32`); on Tier 2 `architecture-diagram.md` is
  *generated* — edit the `.likec4` source, not the Mermaid.
- **Tool choices considered** — why Mermaid + LikeC4 (diagram-as-code, git-diffable,
  Claude-authorable) over GUI/JSON tools (Excalidraw, draw.io) or diagram-editor
  libraries (ReactFlow).

This backs the always-on living-docs rule `32` and the `spec/design/` layout.

## artifacts

`${CLAUDE_PLUGIN_ROOT}/templates/reference/ARTIFACTS.md`

It covers, in detail:

- **When an Artifact is the right output — and when it is not.** Shareable,
  at-a-glance, derived views (a feature summary, a report/dashboard, a release
  timeline, a fillable questionnaire) vs. durable truth, a next-action/decision, or
  anything carrying secrets — where a page is the wrong shape.
- **The derived-view discipline** — render canonical state, never own it; never
  fabricate a value or advance a marker past the source; never persist the page URL
  in the repo; on-demand only, never auto-generated per feature or on a schedule.
- **The write-location invariant** — the page HTML is the only write, to a system
  temp dir (never under the repo tree), on a deterministic per-subject filename so a
  same-session re-run redeploys the same URL (hedged for forked skills); and how
  read-only and `Write`-disallowed skills each uphold it.
- **Rendering mechanics** — load `artifact-design` first (and `dataviz` for charts);
  build everything inline because the Artifact CSP blocks all external hosts (no CDN
  scripts, remote fonts, or images); theme- and width-awareness; the
  private-until-shared publish step gated by the Artifact tool's own prompt.
- **The styling contract** — derive the page's look from the working repo's
  `DESIGN.md` tokens when it declares them, else the `artifact-design`/`dataviz`
  house default; light/dark support and semantic chart encodings stay
  non-negotiable either way.
- **Interactivity, fillable pages, and the Markdown fallback** — lead with the gist
  and disclose on demand; the permission-free copy-out floor a questionnaire needs;
  the **return leg** (a hosted page stores nothing — data comes back only through
  the exported, machine-keyed document ingested by the owning skill:
  `/steer:questions bundle` → `/steer:intake clarify`, the audit triage form →
  `/steer:issues publish-audit`);
  and the inline-Markdown fallback (never written under the repo tree) where the
  Artifact tool is unavailable.

This backs the always-on rule `88-artifacts` and the Artifact-rendering skills
(`/steer:explain`, `/steer:status`, `/steer:questions bundle`, `/steer:audit`,
`/steer:roadmap`, `/steer:help`).

## gates

`${CLAUDE_PLUGIN_ROOT}/templates/reference/GATES.md`

It covers, in detail:

- **What the prompt changes — and what it does not.** A gate requires the deciding
  *human*, never a particular channel; the in-session prompt removes a round trip,
  not the decision. `Decide later` reproduces today's behaviour exactly, so the
  change is strictly additive.
- **The three promptable gates** — ADR `Proposed → Accepted`, intent
  `draft → approved`, `--reviewed` plan sign-off — each keeping its existing owner,
  single writer, and preconditions (a failed blocking-question gate means the
  prompt is never offered).
- **Prompt shape** — `Approve · Reject · Decide later`, and the per-gate minimum
  the prompt must show (an ADR's rejected alternatives and negative consequences;
  an intent's criteria and locked scope; a plan's residual risk). Never pre-select,
  never infer approval from ambient agreement, never bundle two decisions.
- **Recording it** — transition + who + when + **channel**, plus one
  `/spec/history/` entry. Legitimate self-ratification vs. the unrecorded kind that is
  the actual audit hole; and the wrong-decider case.
- **Never promptable** — PR merge, deploy, real secrets, `/infra`, protected-branch
  pushes. Gates become answerable, never removable.

This backs the always-on rule `61-gate-prompts` and the gate-owning skills
(`/steer:adr`, `/steer:spec approve`, `/steer:work --reviewed`).

## polyrepo

`${CLAUDE_PLUGIN_ROOT}/templates/reference/POLYREPO.md`

It covers, in detail:

- **Recommend a monorepo first** — this topology is for an externally mandated
  split only, and it never buys atomic cross-repo commits.
- **The two roles** — a `workspace` repo (`spec/workspace.yml`) hosting THE product
  spine and owning no code, and `member` repos (`spec/PRODUCT.md`) holding the
  code; the traits that detect each, and why a member's spine is partial *by
  design* rather than damaged.
- **Where each artifact lives** — product-level spec and **all** of
  `spec/features/**` in the workspace; ADRs, `ARCHITECTURE.md` and code in the
  member — and why a cross-repo feature must have exactly one `intent.md`.
- **Resolving the spine from a member** — local checkout, else the GitHub
  gateway, else stop; absent local intent is never "no intent".
- **Honest report scope** — naming covered members and flagging uncovered ones
  explicitly, so a fraction of the product is never presented as the whole.
- **What crosses the repo edge** — sub-issues and Projects v2 do; milestones,
  closing keywords, drift gates and CI do not.

There is deliberately **no always-on rule** for this topology — the ruleset is
capped on its on-disk total, which every consumer pays even for a rule scoped to
a minority of repos, so a single-repo product pays zero bytes for polyrepo. It is
delivered instead by this topic, the `orient-session.sh` SessionStart note, and
the workspace profile in the bundled scaffold.

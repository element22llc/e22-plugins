---
name: reference
user-invocable: false
description: "Load one of steer's full reference prose documents by topic — `conventions` (versioning, mise toolchain & lockfiles, backend placement, local services, monorepo, pnpm/uv, Biome/Ruff, Vitest/pytest, baseline patterns), `traceability` (natural-language-to-spec routing, action history, app knowledge docs, client-agnostic tracker integration, drift gates, SOC 2 / ISO 27001-aligned delivery), `design-sources` (Claude Design URL vs local export, where artifacts live, what to read vs not invent, DESIGN.md vs intent.md), or `context-hygiene` (delegating heavy runs to subagents, keeping durable state in files so it survives compaction). A read-only loader: it points at the bundled reference file and answers from it."
when_to_use: Use for any tooling/convention question or the rationale behind a stack default (conventions); any question about living docs, tracker refs, drift flags, audit evidence, or the PO-facing vs dev-facing split (traceability); a feature originating from a Claude Design export/URL, Figma, or screenshots (design-sources); or how to keep a long/multi-phase run from bloating the session or losing constraints across compaction (context-hygiene).
argument-hint: "[conventions | traceability | design-sources | context-hygiene]"
disallowed-tools: Edit, Write, NotebookEdit, EnterWorktree
---

<!-- steer:modes conventions,traceability,design-sources,context-hygiene -->

# Reference prose loader

Pick the topic for the question and **open the bundled reference file** for it,
then answer from that file. These are the full-detail companions to the lean
always-on rules — open the file rather than answering from memory, and if
something is genuinely unclear or the project warrants deviating, record an ADR
(`/steer:adr`) rather than guessing.

| Topic | Reference file | Use for |
|---|---|---|
| `conventions` | `CONVENTIONS.md` | Tooling/convention questions, stack-default rationale. |
| `traceability` | `TRACEABILITY.md` | Living docs, tracker refs, drift flags, audit evidence, PO vs dev split. |
| `design-sources` | `DESIGN-SOURCES.md` | Features from a Claude Design export/URL, Figma, or screenshots. |
| `context-hygiene` | `CONTEXT-HYGIENE.md` | Keeping a long/multi-phase run from bloating the session; subagent delegation and durable state that survives compaction. |

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
- **Windows** — develop inside WSL2.

## `traceability`

Read the full prose bundled with this plugin:

`${CLAUDE_PLUGIN_ROOT}/templates/reference/TRACEABILITY.md`

It covers, in detail:

- **Living documentation** — the natural-language-to-spec contract: the
  routing table from plain-language statements (goals, decisions, trade-offs,
  questions, validations) to their owning artifacts; extraction discipline
  (extract don't embellish, ask on ambiguity, same-PR updates, propose don't
  stealth-edit); the PO-facing vs dev-facing register split.
- **Action history** — `/spec/HISTORY.md` format and worked entry; what it
  serves (auditability, onboarding, review evidence, decision archaeology,
  drift over time); append-only discipline.
- **App knowledge docs** — `/spec/app/` structure (usage, workflows, roles,
  configuration, limitations, troubleshooting, runbook, release notes) and the
  same-PR update trigger.
- **Issue tracker integration** — the client-agnostic model
  (`/spec/tracker.md` declares; everything else just uses the declared ref
  format), the Jira/GitHub/Linear/Azure DevOps adapter table, where refs live,
  and how untracked questions get promoted.
- **Drift gates** — the eight review-sensitive classes, flag-when-noticed
  mechanics, who may resolve a flag, and the periodic sweeps
  (`/steer:audit spec`, `/steer:audit`, `/steer:questions`).
- **SOC 2 / ISO 27001-aligned delivery** — "aligned, never compliant" wording,
  and the expectation→artifact evidence map.
- **Worked examples** — a PO's day and a dev's day through the same workflow.

The lean always-on versions of these rules are `32-living-docs`,
`35-issue-tracker`, `55-drift-gates`, and `75-compliance` — this reference is
their full rationale and how-to.

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
  structured result; the steer exemplars (`/steer:audit` → `steer-reviewer`,
  `/steer:work --reviewed`) and when *not* to fork.
- **Keep durable state in files** — what survives compaction (`/spec/**`, rules,
  CLAUDE.md) vs the chat (which does not); the run-state and constraint sidecar
  contract, with an example shape.
- **The fallback nudge** — only when the thread is genuinely overloaded, recommend
  `/compact` or a fresh session and pre-compose the hand-off, honest that it is a
  recommendation you cannot perform.
- **A worked example** — the part-regeneration scenario end to end.

The lean always-on version of this is rule `26-context-hygiene` — this reference is
its full rationale and how-to.

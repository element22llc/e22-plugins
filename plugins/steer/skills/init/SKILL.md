---
name: init
user-invocable: false
description: One-time setup for a new managed repo — bootstrap the /spec spine + repo scaffolding from the plugin's bundled scaffold (the plugin replaces the old static repository-template as the bootstrap source), or resolve placeholders in a legacy template fork. In both cases pin the toolchain and leave the repo working spec-first.
when_to_use: 'Use when the dev says "set up this new repo", when a repo has no /spec spine, or when template placeholders ([Replace …], [Product Name], @github-handle) remain.'
---

# First-run setup for a new repo

Run this once when a repo is first brought under the standards. Detect
which of two entry conditions applies and follow that path — both end with the
toolchain pinned and the repo working spec-first, on a `feat/*` branch. Per
**Commit autonomy**, commit the bootstrap as coherent units without asking; the
one step that waits for the dev is **publishing** — push and the PR (see the
push/PR gate in Commit autonomy).

**Solo greenfield?** When one person is both PO and dev with no MVP or deploy yet,
Path B offers **solo trunk mode** (Commit autonomy): the bootstrap and early features
land **directly on `main`** — no `feat/*` branch, no bootstrap PR — until graduation
via `/steer:protect`. The `feat/*` + PR default below is for repos with a reviewer;
the per-step notes call out the trunk-mode variant.

**A. Legacy fork of the old `repository-template`** — `[Replace …]`,
`[Product Name]`, `[e.g., …]`, or `@github-handle` placeholders are still
present. The fork already ships a `/spec` skeleton and scaffolding; this path
resolves the placeholders, swaps the starter app, and back-fills the newer
scaffold artifacts the old template lacked. → **Path A** below. (New repos no
longer start from that template — the plugin's bundled scaffold is the
bootstrap source; this path exists for forks that predate it.)

**B. Plugin-driven bootstrap (the default for new repos)** — there is **no
`/spec` spine** and no template placeholders, and you are building the product
from scratch (little or no app code exists yet, or you are about to write it).
This path stands up the full repo scaffolding and spec spine from the
plugin's bundled scaffold and starts the spec-first workflow. → **Path B**
below.

**Not a match:** if the repo has **substantial pre-existing code** but no
`/spec` (a "vibe-coded" app you'd be *reverse-engineering*, not writing fresh),
that is adoption, not init — stop and use **`/steer:adopt`**.

**Already initialized?** Test the spine marker, not the bare directory: a
**complete** spine — `spec/.version` present **and** the spine files exist
(`vision.md`, `users.md`, `glossary.md`, `tracker.md`, `HISTORY.md`) — with no
placeholders remaining means setup has already run; say so and stop, don't
re-propose it. A bare or partial `spec/` (no `spec/.version`, or `.version` but
missing spine files) is **not** "initialized": it's a foreign or half-migrated
spine — run **`/steer:sync`** to repair rather than re-bootstrapping
over it.

---

## Path A — legacy template fork

If any `[Replace …]`, `[Product Name]`, `[e.g., …]`, or `@github-handle`
placeholders are still present anywhere in the repo, this is an unresolved
fork of the old template. **Before doing any other work**, offer to resolve
them:

1. Scan for placeholders across at minimum:
   - `README.md` (product name, status, PO/dev handles)
   - `CLAUDE.md` (Product paragraph, Stack overrides)
   - `spec/vision.md`, `spec/users.md`, `spec/glossary.md`
   - `spec/design/source.md` (only if Greenfield)
2. Ask the dev the minimum questions needed to fill them in one round: product
   name, one-line description, PO handle, dev handles, Greenfield-vs-Brownfield,
   production URL (if any). For the stack, confirm or override the defaults
   (the always-on Stack rules) rather than asking from scratch — and if the dev
   overrides them, record the choice as an ADR (run `/steer:adr`).
3. Propose all edits in a single batch so the dev can confirm the filled-in
   values (product name, handles, …) before they're applied. Once applied,
   commit them (Commit autonomy) — **push and the PR wait for the dev**.
4. **Pin the toolchain — for every CI/dev platform.** The template's `mise.toml`
   files use `latest` so they carry no stale versions; the matching `mise.lock`
   files hold the resolved pins. The template ships **no** `mise.lock` — you
   create it here as part of pinning (mise only writes the lock if the file
   already exists, so create it first). If `mise` itself (or Docker) isn't
   installed yet, run **`/steer:doctor`** first — it detects and, with the dev's
   yes, installs the toolchain. Then, in each config dir (root, and `infra/` if
   they'll touch infra), have the dev: create the empty lock
   (`touch mise.lock`, or `mise lock`), run `mise install` to resolve versions
   into it, **then run `mise lock --platform linux-x64,macos-arm64`** (add
   `macos-x64` / `linux-arm64` / `windows-x64` for any other platform the team
   develops on; `linux-x64` is mandatory — CI runs there). Plain `mise install`
   only writes asset URLs + checksums for the host platform, so a lock pinned on
   macOS has **no `linux-x64` entries** and CI's `mise install --locked` fails
   with *"No lockfile URL found … on platform linux-x64"*. **Verify** each
   `mise.lock` now contains a `[tools.<tool>."platforms.linux-x64"]` block with
   `url` + `checksum` for every tool (`grep -q 'platforms.linux-x64' mise.lock`)
   — a lock with only `[[tools.*]]` version entries still fails `--locked` — then
   commit them. They are the real version pins. **If you can't pin yet** (the
   toolchain isn't installed and the dev defers it), leave the repo with **no**
   `mise.lock`: CI runs a plain unlocked `mise install` until a populated lock is
   committed. **Never commit an empty / comment-only `mise.lock`** — that pins
   nothing while making CI's `--locked` fail. Run `/steer:conventions` for the
   rationale, including the cross-platform backend rule and lockfile-maintenance
   discipline.
5. **Replace or remove the starter.** The template ships a minimal `apps/web` +
   `packages/core` workspace so `pnpm install && pnpm dev` boots a page on a
   fresh clone. It is a placeholder, not the real stack — replace it with the
   actual first app (the default frontend is Next.js), or delete both folders if
   `web` isn't your first app. See `apps/web/README.md`. The template
   deliberately ships **no** workspace lockfile (the starter's would go stale);
   once the real workspace exists, run `pnpm install` (or `uv lock` for Python)
   and commit the generated `pnpm-lock.yaml` / `uv.lock` — from then on it is
   maintained with every dependency change.
6. **Adapt the standard tasks to this product.** The template's `mise.toml`
   ships a baseline `dev:setup` task (plus `docker:up/down`, `db:migrate`,
   `db:seed`) wired to the default stack: Postgres in `compose.yaml`,
   migrate/seed fanned out via `pnpm --recursive --if-present`. Make it real for
   this product:
   - add the services the product actually needs to `compose.yaml` (or delete
     it and the docker/db tasks if there are no backing services);
   - once the real app exists, give it `db:migrate` / `db:seed` scripts (e.g.
     drizzle-kit + a seed script) so the fan-out picks them up;
   - Python products: swap the `pnpm …` task commands for `uv run …`.
   The contract (run `/steer:conventions` for the prose): `mise run dev:setup` is
   idempotent and, from a fresh clone after `mise install`, must produce a
   working local environment.
7. **Back-fill the newer scaffold artifacts.** A fork of the old template
   predates the plugin-bundled scaffold, so it lacks the living-docs spine —
   instantiate what's missing from `${CLAUDE_PLUGIN_ROOT}/templates/spec/`:
   `/spec/HISTORY.md` (from `history.md`, seeded with a bootstrap entry),
   `/spec/tracker.md` (from `tracker.md` — ask which tracker the product
   uses), and `/spec/app/README.md` (from `app-docs.md`). Also back-fill the
   root `ARCHITECTURE.md` from
   `${CLAUDE_PLUGIN_ROOT}/templates/scaffold/ARCHITECTURE.md` and fill its stack
   table + apps/packages map from the repo's `package.json` / `mise.toml` and
   actual `apps/*`+`packages/*`. Reconcile the PR
   template against the bundled
   `${CLAUDE_PLUGIN_ROOT}/templates/github/pull_request_template.md`
   so the drift-gate and living-docs checklists come in (additive — never
   drop sections the team added).

### When the repo is already customized

If a scan finds no placeholders **and** a **complete** spine exists
(`spec/.version` plus the spine files), this setup has already run. Do not
re-propose it; just confirm the repo is set up and move on. (A bare or partial
`spec/` is not "already set up" — see "Already initialized?" above.)

---

## Path B — plugin-driven bootstrap (default)

The repo has no `/spec` spine, and you are starting a new product here. The
goal: stand up the full repo scaffolding + spec spine from the plugin's
bundled scaffold, then proceed spec-first — so feature code is never written
ahead of its intent/contract. Work on a `feat/*` branch and commit the bootstrap
as coherent units (Commit autonomy) — **push and the PR wait for the dev**. (In
**solo trunk mode** — offered in step 1 when one person is both PO and dev —
commit the bootstrap directly to `main` and skip the bootstrap PR; see step 7.)

1. **Confirm the mode.** Verify there's no `/spec`, and that this is genuinely
   greenfield (you're writing the code from scratch), not reverse-engineering
   a pre-existing app — that would be `/steer:adopt`. If a design export/URL or
   screenshots are the input, read them via `/steer:design-sources` first (never
   fetch a Claude Design URL — it 403s). If the dev arrived with a brief or spec
   and wants to scope it, do that scoping **here, as this setup's interview**
   (steps 3–4) rather than ahead of the spine — bootstrap is the first move, not
   an afterthought. Every decision the scoping produces (stack, auth, a locked
   MVP cut) is captured **into the spine you are about to create** — as an ADR
   (step 4) or a `vision.md` entry — never left as a chat- or memory-only note
   (rule `31-decision-capture`).
   - **Offer solo trunk mode when solo.** If one person is both PO and dev and there
     is no MVP or deploy yet, **offer and recommend** solo trunk mode: commit straight
     to `main` (no `feat/*` branch, no per-feature PR) until graduation. A one-line
     confirm is enough. Record the choice in the product `CLAUDE.md` `## Delivery mode`
     section (`solo trunk (pre-MVP)` with the graduation trigger) when you fill the
     scaffold in steps 2–3, and **set the machine-readable marker on that section's
     first line** to match — `<!-- steer:delivery-mode=solo-trunk -->` for solo trunk,
     `<!-- steer:delivery-mode=pr-flow -->` (the scaffold default) otherwise. The
     steer hooks read this marker to relax the per-feature branch/PR in solo trunk
     while still requiring the GitHub issue; keep it in sync with the prose. A repo
     with a second contributor keeps the `feat/*` + PR default — don't offer trunk
     there.
2. **Instantiate the bundled scaffold.** Everything lives in the plugin — no
   external template repo to fetch. Read
   `${CLAUDE_PLUGIN_ROOT}/templates/scaffold/MANIFEST.md` and follow its
   install map: copy each scaffold file to its target path (renaming the
   dotfiles as mapped — `gitignore` → `.gitignore`, `env.example` →
   `.env.example`, `claude/`, `vscode/`), instantiate the GitHub
   templates from `${CLAUDE_PLUGIN_ROOT}/templates/github/` (the MANIFEST's
   GitHub-templates section maps the Issue Forms, workflows, PR template, the
   generated `copilot-instructions.md`, and the generated `prompts/*.prompt.md`
   — the Copilot/VS Code skill surface — into `.github/`), and instantiate the
   spec spine from
   `${CLAUDE_PLUGIN_ROOT}/templates/spec/`:
   `vision.md`, `users.md`, `glossary.md`, plus the living-docs artifacts —
   `/spec/HISTORY.md` (from `history.md`), `/spec/tracker.md` (from
   `tracker.md`), and `/spec/app/README.md` (from `app-docs.md`). Install the
   bundled `spec/features/.gitkeep` and `spec/decisions/.gitkeep` so those dirs
   survive the first commit (an empty dir does not — `/steer:spec-scaffold`
   and `/steer:adr` populate them later). **Adapt to the chosen stack
   and never clobber existing files** (the MANIFEST's per-file notes say what
   to adapt — e.g. drop `package.json`/`pnpm-workspace.yaml`/`biome.json` for
   a Python-only product, swap task commands to `uv run …`). Greenfield repos
   rarely have these already, but if a target `.gitignore` or JSON config
   (`.claude/settings.json`, `biome.json`) **does** exist, reconcile
   it additively with
   `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/scaffold_reconcile.py" auto <target> <scaffold-template> --apply`
   instead of overwriting it.
3. **Interview to fill the spine.** Ask the dev (or PO) the minimum to populate
   `vision.md`, `users.md`, `glossary.md`, the README placeholders, **and
   `/spec/tracker.md`** (which issue tracker does this product use — Jira,
   GitHub Issues, Linear, Azure DevOps, other, none yet — and its
   project/reference format). **Ask, don't invent**; route product-level
   ambiguity to `vision.md` → `## Open questions` rather than guessing.
   Confirm or override the stack defaults (the always-on Stack rules). A
   PO-driven idea→app flow runs through `/steer:build` instead.
   - **If the tracker is GitHub Issues**, run `/steer:issues bootstrap-labels` to
     create the `source:*` / `needs:*` / `risk:*` taxonomy (GitHub silently drops
     a form label that doesn't exist), then `/steer:tracker-sync bootstrap-fields`
     to verify the native **Priority/Effort/date** issue fields are available (it
     reports a capability gap or option mismatch; it never fabricates org config).
4. **Record the initial stack as the first ADR.** The stack choice is usually
   the first decision worth an ADR — run `/steer:adr`. **Any deviation from the
   defaults** (e.g. a standalone Python/Typer CLI instead of Next.js/TS, or
   Python + FastAPI instead of the in-Next backend) **must** get one either way.
   **Status follows who decided.** When the dev *explicitly* chooses the stack in
   this interactive setup, that is a real forward decision: author the ADR as
   **`Accepted`** with the dev as the named **Decider** and today's date. When
   Claude merely *recommended* a default and the dev made no explicit choice,
   leave it **`Proposed`** until a named decider accepts it — generic
   bootstrap-PR approval does **not** ratify a `Proposed` ADR. (Contrast
   **`/steer:adopt`**, which only *observes* existing code and so always
   authors `Proposed` ADRs.) Now that the stack is decided, **fill
   `ARCHITECTURE.md`** — the stack table from `package.json` / `mise.toml` /
   `compose.yaml`, the apps/packages map from the scaffold layout, and the
   cross-cutting concerns from the ADRs just authored. Don't leave the
   placeholders; a stub `ARCHITECTURE.md` is the same drift the app guide
   suffers when it's left unfilled.
5. **Pin the toolchain and lock the workspace — for every CI/dev platform.** If
   `mise` (or Docker) isn't installed yet, run **`/steer:doctor`** first to detect
   and install the toolchain (with the dev's confirmation). The template ships no
   `mise.lock`, so create it first (`touch mise.lock`, or `mise lock`), run
   `mise install`, then `mise lock --platform linux-x64,macos-arm64` (add
   `macos-x64` / `linux-arm64` / `windows-x64` for any other platform the team
   uses; `linux-x64` is mandatory — CI runs there). Plain `mise install` only
   locks the host platform, so the committed lock would have no `linux-x64`
   entries and CI's `mise install --locked` would fail. Verify each `mise.lock`
   now has a `[tools.<tool>."platforms.linux-x64"]` block with `url` + `checksum`
   (`grep -q 'platforms.linux-x64' mise.lock`), not just `[[tools.*]]` version
   entries, and commit it. **If the dev defers pinning, commit no `mise.lock`**
   (CI installs unlocked until one exists) rather than an empty placeholder. Once
   the first real app/workspace exists, generate and commit the workspace lock
   (`pnpm-lock.yaml` or `uv.lock`); maintain it with every dependency change.
   Make `mise run dev:setup` real and idempotent for this product (Python:
   `uv run …` task commands; drop `compose.yaml` + docker/db tasks if there are
   no backing services).
6. **Proceed spec-first.** From here, every user-facing feature gets its
   `/spec/features/[id]/intent.md` + `contract.md` via **`/steer:spec-scaffold`**
   *before or alongside* its code — not after. Get PO approval on intent before
   broad implementation. Behavior changes update the owning `contract.md` in the
   same PR, plus the app guide and an action-history entry (Living
   documentation rule).
7. **Hand off.** Seed `/spec/HISTORY.md` with the bootstrap entry (what, why,
   who asked, the bootstrap PR). **Stamp the spine version:** write
   `/spec/.version` with the current plugin version (resolve it from
   `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` — never from memory) so a
   later `/steer:sync` knows which structural migrations this repo predates:

   ```
   # Spec-spine version — managed by /steer:init, /steer:adopt, /steer:sync. Do not edit by hand.
   <plugin version>
   ```

   **Solo trunk mode:** commit the bootstrap **directly to `main`** with no PR, and
   note in the `HISTORY.md` entry that the repo runs on trunk until graduation
   (`/steer:protect`) — there is no bootstrap PR. Otherwise (a repo with a reviewer):
   commit on the `feat/*` branch and open a PR for dev review — the **bootstrap
   gate** that brings the repo under the standards and lets spec-first work begin
   on `main`. This is **not** productionization: a greenfield bootstrap ships
   scaffold and an empty spec spine, with no app to harden. Productionization is
   a later, per-app event — the `/steer:build` v0 handoff or `/steer:adopt`,
   where real code is triaged into `/spec/PRODUCTIONIZATION.md` before a
   production deploy. Frame the PR (body, HISTORY entry) as the bootstrap/setup
   gate, never as the productionization gate.

### Guardrails

Never clobber working code or overwrite a value the dev already filled in.
Never commit secrets — `.env`/`.env.local` stay git-ignored, names documented in
`.env.example`. Propose batches for approval; don't commit to `main` (except in
solo trunk mode — see step 1).

## Recommend the next action

Whichever path ran, close with a `## Recommended next actions` block per
`${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md`, derived from the
bootstrapped repo's state.

| Observed state | Category | Action / suggested command |
|---|---|---|
| Unresolved template placeholders (`[Replace …]`, `@github-handle`) | Blocking now | Resolve them before feature work |
| Bootstrap PR open, awaiting dev review | Human decision required | A dev reviews/merges the bootstrap PR (no command) |
| Solo trunk mode: bootstrap committed to `main`, no PR | Recommended | Spec or build the first feature; graduate via `/steer:protect` when the MVP works |
| Tracker not yet configured (and not intentionally `none`/manual) | Recommended | Configure `/spec/tracker.md` |
| Spine bootstrapped, no first feature yet | Recommended | Spec or build the first feature — `/steer:spec` or `/steer:build` |
| Repo pushed to GitHub, `main` not yet protected (GitHub tracker) | Recommended | Establish the PR gate — run `/steer:protect` (steer is advisory locally; this sets the real server-side wall). **In solo trunk mode, defer this until graduation** (MVP works / first deploy / second contributor). |
| Placeholders resolved, PR merged, tracker set as intended | Complete | `No action is currently required.` |

Pick one `Current recommended action` by precedence. A tracker intentionally set
to `none`/manual is not a gap. Read-only — it recommends, the dev decides.

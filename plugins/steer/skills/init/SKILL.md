---
name: init
description: "One-time setup for a new managed repo — bootstrap the /spec spine + scaffolding from the plugin's bundled scaffold, pin the toolchain, and leave the repo working spec-first; also resolves placeholders in a legacy template fork."
when_to_use: >-
  Use on a new repo with no /spec spine ("set up this new repo"), or when
  template placeholders ([Replace …], [Product Name], @github-handle) remain.
allowed-tools:
  - Bash(git status *)
  - Bash(git switch *)
  - Bash(git checkout -b *)
  - Bash(git diff *)
  - Bash(git log *)
  - Bash(git show *)
  - Bash(git rev-parse *)
  - Bash(git add *)
  - Bash(git commit *)
  - Bash(git push)
  - Bash(git push -u origin *)
  - Bash(git push origin *)
  - Bash(gh pr create *)
  - Bash(mise install *)
  - Bash(mise lock *)
  - Bash(npm view *)
  - Bash(python3 *scripts/scaffold_reconcile.py*)
---

# First-run setup for a new repo

Run this once when a repo is first brought under the standards. Detect
which of two entry conditions applies and follow that path — both end with the
toolchain pinned and the repo working spec-first, on a `feat/*` branch. Per
**Commit autonomy**, commit the bootstrap as coherent units without asking, then
push the branch and open the bootstrap PR without asking (announce it) — the
one step that waits for the dev is the **merge review** of that PR.

**Solo greenfield?** When one person is both PO and dev with no MVP or deploy yet,
Path B offers **solo trunk mode** (Commit autonomy): the bootstrap and early features
land **directly on `main`** — no `feat/*` branch, no bootstrap PR — until graduation
via `/steer:protect`. The `feat/*` + PR default below is for repos with a reviewer;
the per-step notes call out the trunk-mode variant.

**A. Legacy fork of the old `repository-template`** — `[Replace …]`,
`[Product Name]`, `[e.g., …]`, or `@github-handle` placeholders are still
present. The fork already ships a `/spec` skeleton and scaffolding; resolve the
placeholders, swap the starter app, and back-fill the newer scaffold artifacts
by following the full procedure in
[`LEGACY-TEMPLATE-FORK.md`](../../templates/reference/LEGACY-TEMPLATE-FORK.md).
(New repos no longer start from that template — the plugin's bundled scaffold
is the bootstrap source; this path exists only for forks that predate it.)

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
**managed** spine (`spec/.version` + the spine files) with no placeholders
remaining means setup has already run — say so and stop, don't re-propose it.
For the incomplete states, `/steer:setup`'s routing table is canonical:
**damaged** → repair via `/steer:sync` (never re-bootstrap over it);
**foreign** (a `spec/` steer never wrote) → `/steer:adopt` with substantial
code, or this skill greenfield — never `/steer:sync`.

---

## Path A — legacy template fork

Detected by the placeholders above. Follow the full procedure in
[`LEGACY-TEMPLATE-FORK.md`](../../templates/reference/LEGACY-TEMPLATE-FORK.md):
scan + one-round interview → batch the edits for confirmation → pin the
toolchain (the canonical procedure in `/steer:reference conventions`) → replace
or remove the starter app → adapt the standard `mise` tasks → back-fill the
newer scaffold artifacts (living-docs spine, `ARCHITECTURE.md`, PR template).
Deliver per Commit autonomy — commit, push, open the PR; the merge review is
what waits for the dev. If the scan finds no placeholders and a complete spine
exists, setup already ran — confirm and move on, don't re-propose it.

---

## Path B — plugin-driven bootstrap (default)

The repo has no `/spec` spine, and you are starting a new product here. The
goal: stand up the full repo scaffolding + spec spine from the plugin's
bundled scaffold, then proceed spec-first — so feature code is never written
ahead of its intent/contract. Work on a `feat/*` branch, commit the bootstrap
as coherent units, and push + open the PR when it's coherent (Commit autonomy —
**the merge review waits for the dev**). (In
**solo trunk mode** — offered in step 1 when one person is both PO and dev —
commit the bootstrap directly to `main` and skip the bootstrap PR; see step 7.)

1. **Confirm the mode.** Verify there's no `/spec`, and that this is genuinely
   greenfield (you're writing the code from scratch), not reverse-engineering
   a pre-existing app — that would be `/steer:adopt`. If a design export/URL or
   screenshots are the input, read them via `/steer:reference design-sources` first (never
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
   - **Pick the repo profile.** Determine whether this repo is an `app` (internal
     monorepo — the default), `infra` (Terraform/OpenTofu/Ansible/Pulumi IaC),
     `service` (a single deployable), `library`, or `cli`, and **confirm with the
     dev** (a one-line confirm; default `app`). For greenfield, the dev's intent
     decides; if any code already exists, the same signals `/steer:adopt` uses
     apply (`*.tf`/`*.hcl`, `ansible.cfg`/`site.yml`/`roles/`, `Pulumi.yaml` →
     `infra`; `apps/`+`packages/` → `app`; a single publishable package → `library`;
     a declared `bin`/entrypoint → `cli`). The profile chooses which scaffold the
     next step lays down — it does **not** change the universal core (mise pinning,
     the `/spec` spine, CI hygiene), which every profile gets.
2. **Instantiate the bundled scaffold — core plus the profile's extras.** Everything
   lives in the plugin — no external template repo to fetch. Read
   `${CLAUDE_PLUGIN_ROOT}/templates/scaffold/MANIFEST.md` and follow its
   install map **and its "Profile overlays" section**: copy each scaffold file to
   its target path (renaming the
   dotfiles as mapped — `gitignore` → `.gitignore`, `env.example` →
   `.env.example`, `claude/`, `vscode/`), instantiate the GitHub
   templates from `${CLAUDE_PLUGIN_ROOT}/templates/github/` (the MANIFEST's
   GitHub-templates section maps the Issue Forms, workflows, PR template, and the
   full generated Copilot/VS Code surface — `copilot-instructions.md`,
   `prompts/*.prompt.md` (skills), `agents/*.agent.md` (custom agents), and
   `instructions/*.instructions.md` (path-scoped standards) — into `.github/`;
   the opt-in `copilot-setup-steps.yml` is **not** auto-installed), and instantiate the
   spec spine from
   `${CLAUDE_PLUGIN_ROOT}/templates/spec/`:
   `vision.md`, `users.md`, `glossary.md`, plus the living-docs artifacts —
   `/spec/HISTORY.md` (from `history.md`), `/spec/tracker.md` (from
   `tracker.md`), and `/spec/app/README.md` (from `app-docs.md`) — and the
   design/sources homes: `/spec/design/README.md` (from `design-readme.md`),
   `/spec/design/source.md` (from `design-source.md`),
   `/spec/design/architecture.md` (from `design-architecture.md` — the living
   global architecture diagram `ARCHITECTURE.md` links to), and
   `/spec/sources/README.md` (from `sources-readme.md` — the versioned home for
   recurring PO documents, maintained by `/steer:intake`). Install the
   bundled `spec/features/.gitkeep` and `spec/decisions/.gitkeep` so those dirs
   survive the first commit (an empty dir does not — `/steer:spec-scaffold`
   and `/steer:adr` populate them later). **Adapt to the chosen stack
   and never clobber existing files** (the MANIFEST's per-file notes say what
   to adapt — e.g. for a Python-only product skip the Layer-1 Node baseline and
   use `pyproject.toml`/Ruff, swap task commands to `uv run …`). Greenfield repos
   rarely have these already, but if a target `.gitignore` or JSON config
   (`.claude/settings.json`, `biome.json`) **does** exist, reconcile
   it additively with
   `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/scaffold_reconcile.py" auto <target> <scaffold-template> --apply`
   instead of overwriting it.
   - **Apply the layered profile overlays** (MANIFEST "Profile overlays"). The
     Core install map (Layer 0) lands for **every** profile; then compose
     **additively** — later layers only *add*:
     - **Node-stack profiles** (`app` / `service` / `library` / `cli` on a Node
       stack): also install **Layer 1**, the Node baseline
       `${CLAUDE_PLUGIN_ROOT}/templates/scaffold/profiles/_node/` (`package.json`,
       `pnpm-workspace.yaml`, `biome.json`, `configs/`, `packages/`), then the
       profile's **Layer 2** dir — `profiles/app/` → `apps/README.md` + `DESIGN.md`
       + `claude/launch.json` (Desktop Code-tab preview server; copy only if the
       repo has no `.claude/launch.json` — never overwrite; repoint at `mise run
       dev` if the repo is polyglot);
       `profiles/service/` → `apps/README.md`; `library`/`cli` add nothing.
       Adapt `package.json`: `library` → publishable (drop `private`); `cli` → add
       the `bin` entrypoint. (A **Python-only** `service`/`library`/`cli` skips
       Layer 1 — use `pyproject.toml`/Ruff instead.)
     - **`infra`**: install
       `${CLAUDE_PLUGIN_ROOT}/templates/scaffold/profiles/infra/mise.toml` as the
       **repo-root `mise.toml`** (replaces the core one) and **skip Layer 1
       entirely** (no Node project files). Core's `compose.yaml` +
       `scripts/worktree-env.sh` still land from Layer 0 — delete them only if the
       repo runs no local services. Enable the matching IaC engine in that
       `mise.toml` and adapt `ARCHITECTURE.md`/README to the IaC layout.
     **Set the profile marker:** write the chosen profile into the `CLAUDE.md`
     `## Profile` marker (`<!-- steer:profile=<profile> -->`) and its prose — the
     scaffold ships `=app`; rewrite the token for any other profile. A **root
     `mise.toml` must always land** (core or infra flavor) — it is what clears the
     scaffold nudge.
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
   `mise` (or Docker) isn't installed yet, run **`/steer:doctor`** first. Run
   the canonical pin procedure — `/steer:reference conventions` → "Toolchain:
   `latest` in config, pinned in the lockfile" — in each config dir (create the
   lock, `mise install`, `mise lock --platform linux-x64,macos-arm64` + the
   team's other platforms, verify the `platforms.linux-x64` blocks, commit; a
   deferred pin means **no** `mise.lock`, never an empty one). On a Node stack,
   also resolve the root `package.json` `packageManager` placeholder to the
   mise-pinned pnpm version (`pnpm@<major.minor.patch>` — `mise current pnpm`),
   so corepack (e.g. in the Docker build) uses the same pnpm that wrote
   `pnpm-lock.yaml`. Once the first real app/workspace exists, generate and
   commit the workspace lock (`pnpm-lock.yaml` or `uv.lock`); maintain it with
   every dependency change. Make `mise run dev:setup` real and idempotent for
   this product (Python: `uv run …` task commands; drop `compose.yaml` +
   docker/db tasks if there are no backing services).
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

   **Solo trunk mode:** commit the bootstrap **directly to `main`** with no PR
   and push it (Commit autonomy), and
   note in the `HISTORY.md` entry that the repo runs on trunk until graduation
   (`/steer:protect`) — there is no bootstrap PR. Otherwise (a repo with a reviewer):
   commit on the `feat/*` branch, push, and open the PR for dev review — the **bootstrap
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

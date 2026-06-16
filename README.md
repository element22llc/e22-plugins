# e22-plugins

An [engineering-standards Claude Code plugin
marketplace](https://code.claude.com/docs/en/plugin-marketplaces). Its primary
plugin is **`steer`**, which carries org-wide engineering
standards so they live in **one place** and update **centrally** — instead of
being copied into every forked product repo and then frozen. The marketplace
also **re-lists** Anthropic's upstream **`frontend-design`** plugin (referenced
via a SHA-pinned `git-subdir` source, never vendored) so it can be installed from
the same catalog; it is **not** auto-enabled in product repos — install it
explicitly if a repo wants it.

> Edit the rules once here; every product repo picks them up on the next
> `/plugin update`.

**This repo is the canonical source** of the standards *and* of repository
bootstrap: the plugin bundles the full repo scaffold
(`plugins/steer/templates/scaffold/`) and the spec-spine templates, so
`/steer:init` and `/steer:adopt` stand a repo up without any external template.
The old static
[`repository-template`](https://github.com/element22llc/repository-template)
is **replaced** by this plugin-driven bootstrap — see
[Migrating from `repository-template`](#migrating-from-repository-template).

## What `steer` ships

| Component | Contents |
|---|---|
| **Always-on rules** (`rules/*.md`) | Injected into every session by a SessionStart hook: PO/dev roles, stack defaults, monorepo layout, spec workflow, **living documentation** (natural-language → spec, action history, app docs), **issue-tracker integration** (client-agnostic), testing rules, Definition of Done, **pre-merge drift gates**, high-risk areas, secrets handling, **audit-aligned delivery** (SOC 2 / ISO 27001-*aligned*, not compliant), change-size model, baseline patterns/anti-patterns, design-sources summary, end-of-session checklist. |
| **Skills** (on-demand, invoked as `/steer:<skill>`) | Grouped by area:<br>**Setup & maintenance** — `/steer:init` (repo bootstrap from the bundled scaffold), `/steer:adopt` (adopt an existing "vibe-coded" repo), `/steer:sync` (bring a bootstrapped repo up to the current plugin), `/steer:tidy` (sweep loose files into `/spec`).<br>**Spec authoring** — `/steer:build` (PO-guided idea→working-app flow), `/steer:spec` (brainstorm + `approve` + `validate` a feature spec, no build), `/steer:spec-scaffold` (instantiate intent+contract — *internal helper invoked by spec/build/init/adopt, hidden from the slash menu*), `/steer:questions` (sweep open questions), `/steer:adr` (ADR).<br>**Issues & execution** — `/steer:issues` (GitHub Issues lifecycle), `/steer:work` (execute an issue end-to-end), `/steer:tracker-sync` (the GitHub gateway — *internal helper invoked by issues/work, hidden from the slash menu*).<br>**Navigate & audit** — `/steer:next` (cross-workflow "what next?"), `/steer:audit` (whole-repo health audit), `/steer:drift` (as-built vs intended spec).<br>**Reference prose** — `/steer:conventions`, `/steer:traceability`, `/steer:design-sources`, `/steer:standards` (load the always-on rules on demand — for Cowork, see below). |
| **Templates** | Bundled spec templates (`feature-intent`, `feature-contract`, `adr`, `productionization`, `vision`/`users`/`glossary`, `history` (action log), `tracker`, `app-docs`) and the full reference prose, so scaffolding always uses the latest org templates. |
| **Repo scaffold** (`templates/scaffold/`) | The complete bootstrap bundle — `mise.toml` + standard tasks, `compose.yaml`, CI, the drift-gate PR template, issue templates, `configs/`, `.env.example`, `.claude/settings.json`, editor config, infra conventions — installed by `/steer:init`/`/steer:adopt` per its `MANIFEST.md`. |

The always-on rules are delivered by a `SessionStart` hook that concatenates
`plugins/steer/rules/*.md` to stdout (which Claude Code injects as
session context). It runs once per session when the plugin is enabled.

## Bootstrapping a repo with the plugin

The plugin is the bootstrap mechanism — no template repo to fork:

1. Create an empty repo (or open an existing app), install the plugin (below).
2. **New product** → run **`/steer:init`**: instantiates the bundled scaffold
   (toolchain + tasks, Docker Compose, CI, PR/issue templates, editor config,
   `.env.example`) and the spec spine (`vision.md`, `users.md`, `glossary.md`,
   action history, tracker declaration, app guide), interviews you to fill it,
   pins the toolchain, and leaves the repo working spec-first.
   **Existing app with no `/spec`** → run **`/steer:adopt`** instead.
   **Non-technical PO** → type **`/steer:build`** and describe the idea.
3. From there, Claude documents in parallel as you talk: intents/contracts per
   feature, ADRs for decisions, open questions for ambiguity, the app guide
   for behavior, an action-history entry per change — and flags drift
   (intent/contract/docs/security/ops) in the PR before merge. A dev approving
   the PR remains the production gate. The workflow is **SOC 2 / ISO
   27001-aligned** (traceability, review evidence, change history) — alignment
   is a workflow property, not a compliance claim.

## Migrating from `repository-template`

`element22llc/repository-template` is no longer the bootstrap source; this
plugin carries everything it provided (latest versions, centrally updated).

- **New repos:** don't fork the template — start empty and run `/steer:init`.
- **Existing forks keep working.** Nothing breaks; the fork already has the
  scaffolding. On the next `/steer:init` run (or by asking Claude), back-fill
  the artifacts the template never shipped: `/spec/HISTORY.md`,
  `/spec/tracker.md`, `/spec/app/README.md`, and the drift-gate PR template —
  all instantiated from the plugin's bundle.
- **Scaffolding updates** (CI, `mise.toml` tasks, PR template, …) now arrive
  via `/plugin update` + the template-reconciliation convention instead of
  manual copying between repos. Standards prose and scaffolding files are
  maintained **only here**; the template repo should be archived once active
  forks have back-filled.

## Claude Cowork / desktop app

Some POs work in **Claude Cowork** (the desktop app's Cowork tab) rather than
Claude Code. The plugin's **skills, commands, and templates work there
unchanged** — Cowork is cross-compatible with Claude Code plugins. But its
**hooks do not fire**: Cowork runs the agent in a sandbox VM that currently
ignores plugin and user hooks ([anthropics/claude-code#40495], still open). That
means the `SessionStart` auto-injection — the always-on rules — and the
`PreToolUse` version-pin guard silently do nothing in Cowork.

So a Cowork session starts with *none* of the org rules in context. The fallback
is the **`/steer:standards`** skill: run it once at the start of a Cowork session
and it loads the same `rules/*.md` ruleset on demand. When #40495 ships,
auto-injection will work in Cowork with no plugin change and the skill becomes a
no-op repeat.

[anthropics/claude-code#40495]: https://github.com/anthropics/claude-code/issues/40495

## Install

```bash
claude plugin marketplace add element22llc/e22-plugins
claude plugin install steer@e22-plugins
```

Or commit this to a product repo's `.claude/settings.json` so teammates are
prompted to install when they trust the folder:

```json
{
  "extraKnownMarketplaces": {
    "e22-plugins": { "source": { "source": "github", "repo": "element22llc/e22-plugins" } }
  },
  "enabledPlugins": {
    "steer@e22-plugins": true
  }
}
```

> First install prompts you to trust the `e22-plugins` marketplace.

## Upgrading from `e22-standards`

The plugin was renamed `e22-standards` → **`steer`** (and skills lost their
redundant prefix: `/e22-standards:e22-init` → `/steer:init`). The marketplace
(`e22-plugins`) and repo are unchanged, so this is a clean break with two manual
steps per already-bootstrapped repo:

1. In the repo's `.claude/settings.json`, change the enabled-plugin key:

   ```diff
   - "e22-standards@e22-plugins": true
   + "steer@e22-plugins": true
   ```

2. Run `/plugin update`, then `/clear` (or start a fresh session) so the renamed
   rules and hooks reload.

Then invoke skills under the new namespace — `/steer:<skill>` (e.g. `/steer:sync`,
`/steer:work`) instead of `/e22-standards:e22-<skill>`. Already-materialized
`/spec` spines need no change; `/steer:sync` reconciles any scaffold drift.

## Keeping product repos in sync

The rules are **not** committed into product repos — they are injected by the
plugin — so updating org standards needs no change in any product repo:

1. Edit the rules/skills/templates here, bump `version` in
   `plugins/steer/.claude-plugin/plugin.json`, add a `CHANGELOG.md` entry,
   and merge to `main` (changes go through `feat/*` / `fix/*` branches + PR).
2. In any product repo, a dev runs `/plugin update steer@e22-plugins`.
3. The next session injects the updated ruleset. The version banner at the top of
   the injected context shows which version is live.

For products that need reproducibility, pin a `ref` (tag or SHA) in the
marketplace `source` in `.claude/settings.json`; updating then becomes a reviewed
PR that bumps the pin.

## Versions

The current version lives in
`plugins/steer/.claude-plugin/plugin.json`; what changed in each release
is in [`CHANGELOG.md`](./CHANGELOG.md). (No version table here — it would just
drift from the source of truth.)

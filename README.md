# e22-plugins

Element 22's [Claude Code plugin
marketplace](https://code.claude.com/docs/en/plugin-marketplaces). It hosts a
single plugin, **`e22-standards`**, which carries E22's organization-wide
engineering standards so they live in **one place** and update **centrally** —
instead of being copied into every forked product repo and then frozen.

> Edit the rules once here; every product repo picks them up on the next
> `/plugin update`.

**This repo is the canonical source** of the standards *and* of repository
bootstrap: the plugin bundles the full repo scaffold
(`plugins/e22-standards/templates/scaffold/`) and the spec-spine templates, so
`/e22-standards:e22-init` and `/e22-standards:e22-adopt` stand a repo up without any external template.
The old static
[`repository-template`](https://github.com/element22llc/repository-template)
is **replaced** by this plugin-driven bootstrap — see
[Migrating from `repository-template`](#migrating-from-repository-template).

## What `e22-standards` ships

| Component | Contents |
|---|---|
| **Always-on rules** (`rules/*.md`) | Injected into every session by a SessionStart hook: PO/dev roles, stack defaults, monorepo layout, spec workflow, **living documentation** (natural-language → spec, action history, app docs), **issue-tracker integration** (client-agnostic), testing rules, Definition of Done, **pre-merge drift gates**, high-risk areas, secrets handling, **audit-aligned delivery** (SOC 2 / ISO 27001-*aligned*, not compliant), change-size model, baseline patterns/anti-patterns, design-sources summary, end-of-session checklist. |
| **Skills** (on-demand) | `/e22-standards:e22-standards` (load the always-on rules on demand — for Cowork, see below), `/e22-standards:e22-init` (repo bootstrap from the bundled scaffold), `/e22-standards:e22-adopt` (adopt an existing "vibe-coded" repo), `/e22-standards:e22-build` (PO-guided idea→working-app flow), `/e22-standards:e22-spec-scaffold` (feature intent+contract), `/e22-standards:e22-adr` (ADR), `/e22-standards:e22-conventions`, `/e22-standards:e22-traceability`, and `/e22-standards:e22-design-sources` (full reference prose), `/e22-standards:e22-drift`, `/e22-standards:e22-audit`, `/e22-standards:e22-questions`, `/e22-standards:e22-tidy`. |
| **Templates** | Bundled spec templates (`feature-intent`, `feature-contract`, `adr`, `productionization`, `vision`/`users`/`glossary`, `history` (action log), `tracker`, `app-docs`) and the full reference prose, so scaffolding always uses the latest org templates. |
| **Repo scaffold** (`templates/scaffold/`) | The complete bootstrap bundle — `mise.toml` + standard tasks, `compose.yaml`, CI, the drift-gate PR template, issue templates, `configs/`, `.env.example`, `.claude/settings.json`, editor config, infra conventions — installed by `/e22-standards:e22-init`/`/e22-standards:e22-adopt` per its `MANIFEST.md`. |

The always-on rules are delivered by a `SessionStart` hook that concatenates
`plugins/e22-standards/rules/*.md` to stdout (which Claude Code injects as
session context). It runs once per session when the plugin is enabled.

## Bootstrapping a repo with the plugin

The plugin is the bootstrap mechanism — no template repo to fork:

1. Create an empty repo (or open an existing app), install the plugin (below).
2. **New product** → run **`/e22-standards:e22-init`**: instantiates the bundled scaffold
   (toolchain + tasks, Docker Compose, CI, PR/issue templates, editor config,
   `.env.example`) and the spec spine (`vision.md`, `users.md`, `glossary.md`,
   action history, tracker declaration, app guide), interviews you to fill it,
   pins the toolchain, and leaves the repo working spec-first.
   **Existing app with no `/spec`** → run **`/e22-standards:e22-adopt`** instead.
   **Non-technical PO** → type **`/e22-standards:e22-build`** and describe the idea.
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

- **New repos:** don't fork the template — start empty and run `/e22-standards:e22-init`.
- **Existing forks keep working.** Nothing breaks; the fork already has the
  scaffolding. On the next `/e22-standards:e22-init` run (or by asking Claude), back-fill
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
is the **`/e22-standards:e22-standards`** skill: run it once at the start of a Cowork session
and it loads the same `rules/*.md` ruleset on demand. When #40495 ships,
auto-injection will work in Cowork with no plugin change and the skill becomes a
no-op repeat.

[anthropics/claude-code#40495]: https://github.com/anthropics/claude-code/issues/40495

## Install

```bash
claude plugin marketplace add element22llc/e22-plugins
claude plugin install e22-standards@e22-plugins
```

Or commit this to a product repo's `.claude/settings.json` so teammates are
prompted to install when they trust the folder:

```json
{
  "extraKnownMarketplaces": {
    "e22-plugins": { "source": { "source": "github", "repo": "element22llc/e22-plugins" } }
  },
  "enabledPlugins": {
    "e22-standards@e22-plugins": true
  }
}
```

> First install prompts you to trust the `e22` marketplace.

## Keeping product repos in sync

The rules are **not** committed into product repos — they are injected by the
plugin — so updating org standards needs no change in any product repo:

1. Edit the rules/skills/templates here, bump `version` in
   `plugins/e22-standards/.claude-plugin/plugin.json`, add a `CHANGELOG.md` entry,
   and merge to `main` (changes go through `feat/*` / `fix/*` branches + PR).
2. In any product repo, a dev runs `/plugin update e22-standards@e22-plugins`.
3. The next session injects the updated ruleset. The version banner at the top of
   the injected context shows which version is live.

For products that need reproducibility, pin a `ref` (tag or SHA) in the
marketplace `source` in `.claude/settings.json`; updating then becomes a reviewed
PR that bumps the pin.

## Versions

The current version lives in
`plugins/e22-standards/.claude-plugin/plugin.json`; what changed in each release
is in [`CHANGELOG.md`](./CHANGELOG.md). (No version table here — it would just
drift from the source of truth.)

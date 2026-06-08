# e22-plugins

Element 22's [Claude Code plugin
marketplace](https://code.claude.com/docs/en/plugin-marketplaces). It hosts a
single plugin, **`e22-standards`**, which carries E22's organization-wide
engineering standards so they live in **one place** and update **centrally** —
instead of being copied into every forked product repo and then frozen.

> Edit the rules once here; every product repo picks them up on the next
> `/plugin update`.

The canonical source of these standards is the
[`repository-template`](https://github.com/element22llc/repository-template)
repo. This marketplace mirrors that template's generic, org-wide rules into a
distributable plugin.

## What `e22-standards` ships

| Component | Contents |
|---|---|
| **Always-on rules** (`rules/*.md`) | Injected into every session by a SessionStart hook: PO/dev roles, stack defaults, monorepo layout, spec workflow, testing rules, Definition of Done, high-risk areas, secrets handling, change-size model, baseline patterns/anti-patterns, design-sources summary, end-of-session checklist. |
| **Skills** (on-demand) | `/e22-init` (first-run setup), `/e22-adopt` (adopt an existing non-template "vibe-coded" repo), `/e22-build` (PO-guided idea→working-app flow), `/e22-spec-scaffold` (feature intent+contract), `/e22-adr` (ADR), `/e22-conventions` and `/e22-design-sources` (full reference prose). |
| **Templates** | Bundled spec templates (`feature-intent`, `feature-contract`, `adr`, `production-readiness`) and the full reference prose, so scaffolding always uses the latest org templates. |

The always-on rules are delivered by a `SessionStart` hook that concatenates
`plugins/e22-standards/rules/*.md` to stdout (which Claude Code injects as
session context). It runs once per session when the plugin is enabled, on all
surfaces that support hooks (Claude Code today). On Chat/Cowork the same rules
apply as instructions; hooks are hard controls only where the surface supports
them.

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

# e22-plugins

Element 22's plugin marketplace for Claude Code and Claude Cowork.

This repository is a [Claude Code plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces). It catalogues the plugins that Element 22 engineers and contributors install on top of Claude so that every team member works with the same proposal workflow, governance gates, and shared conventions.

> The same marketplace format is supported in both **Claude Code** (the terminal coding agent) and **Claude Cowork** (the desktop tool for file and task automation). Install instructions for both are below.

## What's in here today

| Plugin | Install handle | What it does |
|---|---|---|
| [`proposal-workflow`](./plugins/proposal-workflow) | `proposal-workflow@e22-plugins` | The `/propose`, `/from-design`, and `/promote` commands, plus the `spec-refiner` and `drift-monitor` agents and the engineering constitution that anchors them. |

[`CONSTITUTION.md`](./CONSTITUTION.md) at the repo root is the always-loaded baseline that the `proposal-workflow` plugin references. Product-specific `CLAUDE.md` files extend it.

## Repository layout

```
e22-plugins/
├── .claude-plugin/
│   └── marketplace.json          ← the catalog
├── plugins/
│   └── proposal-workflow/
│       ├── .claude-plugin/
│       │   └── plugin.json
│       ├── agents/
│       │   ├── drift-monitor.md
│       │   └── spec-refiner.md
│       └── commands/
│           ├── from-design.md
│           ├── promote.md
│           └── propose.md
├── CONSTITUTION.md               ← engineering baseline
├── MARKETPLACE_VALIDATION.md     ← internal: marketplace conformance notes
├── README.md
└── .gitignore
```

## Install

### In Claude Code

Once this repo is on GitHub at `element22llc/e22-plugins`:

```bash
# Inside a Claude Code session
/plugin marketplace add element22llc/e22-plugins
/plugin install proposal-workflow@e22-plugins
```

For local development (before pushing):

```bash
# From the parent of this repo, point at the checkout
/plugin marketplace add ./e22-plugins
/plugin install proposal-workflow@e22-plugins
```

To validate marketplace JSON and plugin frontmatter before pushing:

```bash
claude plugin validate .
```

### In Claude Cowork

Cowork supports the same plugin format as Claude Code. From the Cowork plugin manager UI:

1. Open the Plugins panel.
2. Add a marketplace pointing at `element22llc/e22-plugins` (or the local path during development).
3. Install `proposal-workflow` from the catalog.

The commands (`/propose`, `/from-design`, `/promote`) and agents (`spec-refiner`, `drift-monitor`) become available in Cowork sessions the same way they do in Claude Code.

> **Practical note.** `proposal-workflow` is designed around an engineer's workflow: it expects a Git checkout, opens PRs, reads `package.json` / `pyproject.toml` for stack versions, talks to GitHub/Sentry/LaunchDarkly. It will run in Cowork, but you'll get the most out of it in a Claude Code session where those tools are already wired up. Non-engineering Cowork users will mostly interact with it indirectly — for example, by describing a change for an engineer to run `/propose` on.

### Auto-prompt teammates in other repos

In any Element 22 product repo, commit this to `.claude/settings.json` so Claude Code prompts contributors to install the marketplace when they trust the project folder:

```json
{
  "extraKnownMarketplaces": {
    "e22-plugins": {
      "source": { "source": "github", "repo": "element22llc/e22-plugins" }
    }
  },
  "enabledPlugins": {
    "proposal-workflow@e22-plugins": true
  }
}
```

`extraKnownMarketplaces` registers the marketplace; `enabledPlugins` declares which plugin(s) should be enabled by default once installed.

## Using `proposal-workflow`

Once installed, three slash commands and two agents are available.

### Commands

- **`/propose <description>`** — Start a proposal from a natural-language change description. Creates a draft PR with a preview environment and acceptance criteria. Champions both technical and non-technical contributors.
- **`/from-design <bundle url or path>`** — Same flow as `/propose`, but starts from a Claude Design handoff bundle. The bundle's design tokens are validated against `design-system/` and any deviations are surfaced to the champion.
- **`/promote <flag> <target-percentage>`** — Promote an existing feature flag. Gated by `.github/PROMOTERS.yml`; requires explicit chat confirmation; never auto-promotes past 10% for SOC2 in-scope products.

### Agents

- **`spec-refiner`** — Invoked automatically by `/propose` when a description is vague or under 20 words. Asks one focused clarifying question; never more than two; never writes code.
- **`drift-monitor`** — CI-time agent that detects divergence between `CLAUDE.md` claims and the actual repository state, then files a GitHub issue. Never modifies code or `CLAUDE.md` itself.

## Adding a new plugin to the marketplace

1. Create the plugin subtree:
   ```
   plugins/<new-plugin>/
   ├── .claude-plugin/
   │   └── plugin.json
   ├── commands/    (optional)
   ├── agents/      (optional)
   ├── skills/      (optional)
   └── hooks/       (optional)
   ```
2. Fill in `plugin.json` with at minimum `name`, `version`, and `description`.
3. Add an entry to `.claude-plugin/marketplace.json#plugins`:
   ```json
   {
     "name": "<new-plugin>",
     "source": "./<new-plugin>",
     "description": "...",
     "category": "...",
     "keywords": ["..."]
   }
   ```
   Because `metadata.pluginRoot` is set to `./plugins`, the `source` value is just the bare directory name — no `plugins/` prefix needed.
4. Run `claude plugin validate .` to confirm syntax and frontmatter are clean.
5. Open a PR. Once merged, users get the new plugin on their next `/plugin marketplace update`.

## Versioning

Each plugin's `plugin.json` declares an explicit `version`. Users only see updates when that string changes — so **bump the `version` field on every release**. Setting `version` in both `plugin.json` and the marketplace entry is a footgun (the manifest value silently wins); pick one place. Omitting `version` entirely is also valid: Claude Code will treat each git commit as a new version.

## Reserved-name reminder

`e22-plugins` is not on the Anthropic reserved-name list and does not contain `claude` or `anthropic`, so it's safe for both Claude Code installs and the Claude.ai marketplace sync. Don't rename it to anything that begins with `claude-`, `anthropic-`, or any of the reserved patterns documented in the [marketplace spec](https://code.claude.com/docs/en/plugin-marketplaces).

## Validating changes

Before pushing:

```bash
claude plugin validate .
```

This checks `marketplace.json`, every plugin's `plugin.json`, all skill/agent/command frontmatter, and `hooks/hooks.json` for syntax and schema errors. Warnings about kebab-case naming and missing descriptions are non-blocking but worth fixing — the Claude.ai marketplace sync is stricter than local installs.

## License

`UNLICENSED` — Element 22 internal use.

## See also

- [CONSTITUTION.md](./CONSTITUTION.md) — the engineering baseline this marketplace's plugins reference
- [MARKETPLACE_VALIDATION.md](./MARKETPLACE_VALIDATION.md) — internal notes on conformance against the Claude Code marketplace spec
- [Create and distribute a plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces) — official spec
- [Plugins reference](https://code.claude.com/docs/en/plugins-reference) — full plugin schema

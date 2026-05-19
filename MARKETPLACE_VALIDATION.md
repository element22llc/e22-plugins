# Marketplace conformance — `e22-plugins`

Validated against: <https://code.claude.com/docs/en/plugin-marketplaces> (fetched 2026-05-19).
Last verified locally: `claude plugin validate .` → ✔ Validation passed (Claude Code v2.1.142, 2026-05-19).

## Status

Conformant. The repo is a valid Claude Code plugin marketplace named `e22-plugins`, currently shipping one plugin: `proposal-workflow`.

## Naming

| Surface | Value | Where it's set |
|---|---|---|
| Marketplace name | `e22-plugins` | `.claude-plugin/marketplace.json` → `name` |
| Plugin name | `proposal-workflow` | `plugins/proposal-workflow/.claude-plugin/plugin.json` → `name` and the marketplace entry |
| Install handle | `proposal-workflow@e22-plugins` | derived |
| Suggested GitHub repo | `element22llc/e22-plugins` | external; the directory on disk is currently `e22-platform/` and should be renamed before pushing |

Reserved-name check: `e22-plugins` does not collide with the Anthropic reserved list and does not include the word `claude`, so it won't trip the Claude.ai marketplace sync's impersonation rules.

## Layout

```
e22-plugins/   (currently the dir is named e22-platform/ on disk — rename before pushing)
├── .claude-plugin/
│   └── marketplace.json
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
├── CONSTITUTION.md
└── MARKETPLACE_VALIDATION.md
```

## Install and test

From the repo root:

```
claude plugin validate .
claude plugin marketplace add ./
claude plugin install proposal-workflow@e22-plugins
```

Once on GitHub at `element22llc/e22-plugins`:

```
claude plugin marketplace add element22llc/e22-plugins
claude plugin install proposal-workflow@e22-plugins
```

## Auto-prompt teammates in other repos

In any Element 22 product repo, add this to `.claude/settings.json` so Claude Code prompts the user to install the marketplace when they trust the project folder:

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

## Outstanding manual steps

1. **Rename the directory on disk** from `e22-platform/` to `e22-plugins/` before pushing, so the local checkout matches the GitHub repo name.
2. **Rename the GitHub remote** to `element22llc/e22-plugins` (or create it if it doesn't exist yet).
3. **Delete the empty `Element 22 AI collaborative dev workflow/`** folder at the repo root — locked from the sandbox, but `rm -rf` in Terminal will clear it.
4. **First commit.** Nothing in this repo has been committed yet; once you're happy with the layout, `git add . && git commit -m "feat: bootstrap e22-plugins marketplace with proposal-workflow plugin"`.

## Things to know for later

- **Adding a second plugin.** Create `plugins/<new-plugin>/.claude-plugin/plugin.json` and add a new entry to `marketplace.json#plugins`. Because `metadata.pluginRoot` is set to `./plugins`, the `source` value just needs to be the bare directory name (e.g. `"source": "./my-new-plugin"`).
- **Versioning.** `proposal-workflow` is pinned at `0.1.0` in `plugin.json`. Bump that string on every release or users won't see your changes. Removing the field switches to git-SHA-per-commit versioning. Don't set `version` in both `plugin.json` and the marketplace entry — `plugin.json` wins silently.
- **Release channels.** When ready, create two marketplaces pointing at the same repo on different refs (`stable`, `latest`) and assign them via managed settings.
- **Private repo auto-updates.** Background updates need `GITHUB_TOKEN` or `GH_TOKEN` in the user's env — interactive credential prompts are suppressed.
- **`CLAUDE_PLUGIN_ROOT`.** Use this env var in hooks and MCP server configs to reference plugin-internal files; plugins are cached, not used in place.

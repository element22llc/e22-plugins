# Templates

Drop-in configuration snippets for distributing the `e22-plugins` marketplace across Element 22 repos.

## `claude-settings.json` → `.claude/settings.json`

Copy this file into any Element 22 product repo at `.claude/settings.json`. Commit it. When teammates open the repo in Claude Code or Cowork and trust the project folder, they'll be prompted to install the `e22-plugins` marketplace and both Element 22 plugins (`proposal-workflow` and `proposal-intake`) will be enabled by default.

```bash
# From the product repo root
mkdir -p .claude
cp /path/to/e22-plugins/templates/claude-settings.json .claude/settings.json
git add .claude/settings.json
git commit -m "chore: auto-prompt teammates to install e22-plugins marketplace"
```

### What gets prompted

- **`extraKnownMarketplaces.e22-plugins`** — registers the marketplace at GitHub repo `element22llc/e22-plugins`. Claude Code/Cowork will prompt the user to add it on first trust.
- **`enabledPlugins`** — declares which plugins should be enabled by default after install. The user can still disable them with `/plugin disable`.

### What's NOT in here

This is auto-prompt only — teammates can decline. If you want to **require** the marketplace and block adding others (e.g. for SOC2 in-scope products), that needs managed settings configured by an org admin, not a per-repo settings file. See [strictKnownMarketplaces](https://code.claude.com/docs/en/settings#strictknownmarketplaces) for the lockdown pattern.

### Per-user overrides

If a contributor wants to disable one of the plugins for themselves without affecting the team, they should put their override in `.claude/settings.local.json` — that path is already in the project's `.gitignore` so it won't leak to the team.

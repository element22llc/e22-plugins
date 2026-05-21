# Templates

Drop-in configuration snippets for distributing the `e22-plugins` marketplace
across Element 22 product repos.

## `claude-settings.json` → `.claude/settings.json`

Copy this file into any Element 22 product repo at `.claude/settings.json`. Commit
it. When teammates open the repo in Claude Code or Cowork and trust the project
folder, they'll be prompted to install the `e22-plugins` marketplace and the
**eight** Element 22 plugins will be enabled by default:

- Lane plugins (2): `prototype-lane`, `production-lane`
- House-rule plugins (6): `spec-driven-dev`, `always-test`, `house-style`,
  `security-rails`, `spine-writer`, `handoff-packager`

```bash
# From the product repo root
mkdir -p .claude
cp /path/to/e22-plugins/templates/claude-settings.json .claude/settings.json
git add .claude/settings.json
git commit -m "chore: auto-prompt teammates to install e22-plugins marketplace"
```

### What gets prompted

- **`extraKnownMarketplaces.e22-plugins`** — registers the marketplace at GitHub
  repo `element22llc/e22-plugins`. Claude Code/Cowork will prompt the user to add
  it on first trust.
- **`enabledPlugins`** — declares which plugins should be enabled by default after
  install. The user can still disable any of them with `/plugin disable`.

### Per-role install footprint

- **POs working in Cowork only** strictly need `prototype-lane` plus the six
  house-rule plugins. The template enables `production-lane` too because POs are
  also expected to read engineer notes and check status across both lanes — but
  it's safe to disable for non-engineering accounts via
  `.claude/settings.local.json`.
- **Engineers in Claude Code** want all eight enabled.

### What's NOT in here

This is auto-prompt only — teammates can decline. If you want to **require** the
marketplace and block adding others (e.g. for SOC2 in-scope products), that needs
managed settings configured by an org admin, not a per-repo settings file. See
[`strictKnownMarketplaces`](https://code.claude.com/docs/en/settings#strictknownmarketplaces)
for the lockdown pattern.

### Per-user overrides

If a contributor wants to disable one of the plugins for themselves without
affecting the team, they should put their override in
`.claude/settings.local.json` — that path is already in the project's
`.gitignore` so it won't leak to the team.

### Connector requirement

The template includes a `_recommendedConnectors` block (descriptive, not
validated) that names the required and recommended connectors. The lane plugins
**require the GitHub connector** and will refuse to mutate state without it.
Make sure every contributor — POs in Chat or Cowork, engineers in Claude Code —
has GitHub connected in their account before they run their first `/vibe`,
`/package-handoff`, `/validate`, `/propose`, or `/promote`.

See [`CONNECTORS.md`](../CONNECTORS.md) at the marketplace root for the full
reference (which capabilities each command uses, degraded behavior when missing,
SOC2 overlay).


# e22-plugins

Element 22's plugin marketplace for Claude Code and Claude Cowork.

This repository is a [Claude Code plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces). It catalogues the plugins that Element 22 engineers and non-engineering contributors install on top of Claude so that everyone works through the same proposal pipeline — engineers from a Claude Code terminal, PMs and designers from Cowork — and the lifecycle stays connected end-to-end.

> The marketplace format is supported in both **Claude Code** (the terminal coding agent) and **Claude Cowork** (the desktop tool for file and task automation). Install instructions for both are below.

## What's in here

| Plugin | Install handle | For whom | What it does |
|---|---|---|---|
| [`proposal-workflow`](./plugins/proposal-workflow) | `proposal-workflow@e22-plugins` | Engineers | `/propose`, `/from-design`, `/promote`; the `spec-refiner` and `drift-monitor` agents; the engineering constitution. Runs the full proposal lifecycle from draft PR to flag promotion. |
| [`proposal-intake`](./plugins/proposal-intake) | `proposal-intake@e22-plugins` | Non-engineers (Cowork) | `/draft-proposal` turns a plain-language change idea into a structured brief; `/proposal-status` reports state without jargon; auto-triggered skills handle ad-hoc change ideas and terminology questions. |

**How they fit together.** `proposal-intake` is the on-ramp: a PM, designer, or ops contributor describes what they'd like to change; the plugin produces a brief and either files it as a GitHub issue or hands it to an engineer in chat. The engineer then runs `proposal-workflow`'s `/propose` against that brief and takes it through draft PR → preview → review → merge → flag promotion. The non-engineer can check back any time with `/proposal-status`.

[`CONSTITUTION.md`](./CONSTITUTION.md) at the repo root is the always-loaded baseline that `proposal-workflow` references.

## Repository layout

```
e22-plugins/
├── .claude-plugin/
│   └── marketplace.json              ← the catalog
├── plugins/
│   ├── proposal-workflow/            ← engineer-facing
│   │   ├── .claude-plugin/plugin.json
│   │   ├── agents/{drift-monitor,spec-refiner}.md
│   │   └── commands/{from-design,promote,propose}.md
│   └── proposal-intake/              ← non-engineer / Cowork-facing
│       ├── .claude-plugin/plugin.json
│       ├── agents/intake-clarifier.md
│       ├── commands/{draft-proposal,proposal-status}.md
│       └── skills/
│           ├── change-idea-intake/SKILL.md
│           └── proposal-glossary/SKILL.md
├── templates/
│   ├── claude-settings.json          ← drop into product repos
│   └── README.md
├── CONSTITUTION.md                   ← engineering baseline
├── MARKETPLACE_VALIDATION.md         ← internal: conformance notes
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
/plugin install proposal-intake@e22-plugins   # optional for engineers
```

For local development (before pushing):

```bash
/plugin marketplace add ./e22-plugins
```

Validate before pushing:

```bash
claude plugin validate .
```

### In Claude Cowork

Cowork uses the same plugin format. Non-engineers should install `proposal-intake`:

1. Open the Plugins panel in Cowork.
2. Add marketplace: `element22llc/e22-plugins` (or local path during development).
3. Install `proposal-intake@e22-plugins`.

That gives them `/draft-proposal`, `/proposal-status`, and two auto-triggered skills:

- **`change-idea-intake`** — kicks in automatically when they describe a change they'd like ("I wish X did Y", "can we make X different"). They never have to remember the slash command.
- **`proposal-glossary`** — kicks in when they ask what a proposal-related term means ("what does experimental mean", "what's a feature flag"). Plain-language answers.

`proposal-workflow` will also install in Cowork, but it's built for engineers — it expects a Git checkout, GitHub MCP, feature-flag MCPs, and so on. Most Cowork users won't need it.

## Distribute through the Claude team workspace

The roll-out plan: push to GitHub, then drop a settings template into each Element 22 product repo so contributors get auto-prompted on first trust.

### One-time: publish the marketplace

1. Create the GitHub repo `element22llc/e22-plugins` (private or public depending on org policy).
2. Push this checkout.
3. (Optional) Tag a release: `git tag v0.1.0 && git push --tags`. The marketplace doesn't require tags, but they make the cache key predictable.

### Per product repo: auto-prompt teammates

Copy [`templates/claude-settings.json`](./templates/claude-settings.json) into the product repo as `.claude/settings.json` and commit it. The template registers `e22-plugins` as a known marketplace and pre-enables both plugins:

```bash
# From the product repo root
mkdir -p .claude
cp <path-to>/e22-plugins/templates/claude-settings.json .claude/settings.json
git add .claude/settings.json
git commit -m "chore: auto-prompt teammates to install e22-plugins marketplace"
```

What happens for teammates after this lands:

- First time they open the repo in Claude Code or Cowork and trust the folder, they'll see a prompt: *"This project recommends the `e22-plugins` marketplace. Install?"*
- After they accept, `proposal-workflow` and `proposal-intake` install and enable automatically.
- Updates: contributors get the latest version when they run `/plugin marketplace update` (or on next Claude startup, depending on auto-update settings).

### Optional: lock down marketplace sources

This template **auto-prompts** but doesn't restrict. Anyone can still add other marketplaces. If you want strict control (e.g. SOC2-required repos shouldn't allow arbitrary marketplaces), configure [`strictKnownMarketplaces`](https://code.claude.com/docs/en/settings#strictknownmarketplaces) in **managed settings** at the org level — that requires an admin and a separate rollout. Out of scope for this README; see the spec when you're ready.

### Private repo auto-updates

If `element22llc/e22-plugins` is private, contributors' Claude clients need `GITHUB_TOKEN` (or `GH_TOKEN`) in their shell environment for background auto-updates to work. Interactive `gh auth` is enough for manual `/plugin marketplace update`, but background updates suppress prompts. Document this in your contributor onboarding.

## Using the plugins

### `/draft-proposal` (Cowork, non-engineers)

```
/draft-proposal Make checkout faster for international customers
```

Walks the user through three to four AskUserQuestion prompts (product, motivation, success criteria, urgency, champion), produces a brief in their outputs folder, and either files a GitHub issue or gives them a chat message to paste to an engineer.

### `/proposal-status` (Cowork, non-engineers)

```
/proposal-status                # all proposals where I'm champion
/proposal-status checkout       # proposals matching "checkout"
```

Reports state in plain language — "Engineer is working on it", "Ready for you to review the preview", "Live for customers" — not internal label vocabulary.

### `/propose`, `/from-design`, `/promote` (Claude Code, engineers)

See [the proposal-workflow README](./plugins/proposal-workflow) (and the [constitution](./CONSTITUTION.md)) for the full engineering lifecycle.

## Adding a new plugin to the marketplace

1. Create the subtree:
   ```
   plugins/<new-plugin>/
   ├── .claude-plugin/plugin.json
   ├── commands/    (optional)
   ├── agents/      (optional)
   ├── skills/      (optional)
   └── hooks/       (optional)
   ```
2. Fill in `plugin.json` (minimum: `name`, `version`, `description`).
3. Add an entry to `.claude-plugin/marketplace.json#plugins`. Because `metadata.pluginRoot` is `./plugins`, the `source` value is just the bare directory name.
4. Run `claude plugin validate .`.
5. Open a PR. Once merged, teammates pick up the new plugin on the next marketplace refresh.

## Versioning

Each plugin's `plugin.json` declares an explicit `version`. **Bump the `version` field on every release** — users only see updates when the string changes. Don't set `version` in both `plugin.json` and the marketplace entry; the manifest value silently wins. Omitting `version` switches to git-SHA-per-commit, which is simpler for actively-developed plugins.

## Validating changes

Before pushing:

```bash
claude plugin validate .
```

Checks `marketplace.json`, every plugin's `plugin.json`, all skill/agent/command frontmatter, and `hooks/hooks.json`. Warnings about kebab-case and missing descriptions are non-blocking but worth fixing — the Claude.ai marketplace sync is stricter than local installs.

## License

`UNLICENSED` — Element 22 internal use.

## See also

- [CONSTITUTION.md](./CONSTITUTION.md) — engineering baseline
- [MARKETPLACE_VALIDATION.md](./MARKETPLACE_VALIDATION.md) — internal conformance notes
- [templates/](./templates) — distribution config to drop into product repos
- [Create and distribute a plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces) — official spec
- [Plugins reference](https://code.claude.com/docs/en/plugins-reference) — full plugin schema
- [Plugin settings](https://code.claude.com/docs/en/settings#plugin-settings) — `extraKnownMarketplaces`, `enabledPlugins`, `strictKnownMarketplaces`

# Marketplace conformance — `e22-plugins`

Validated against: <https://code.claude.com/docs/en/plugin-marketplaces> (fetched 2026-05-19).
Last verified locally: `claude plugin validate .` should be re-run after the
2026-05-25 simplified-workflow refactor (this commit).

## Status

Conformant in design. Shipping seven plugins reflecting the v0.4 spec
(simplified, three-zone workflow):

- Always-on (sandbox + governed): `e22-org`, `security-rails`,
  `handoff-packager`, `house-style`
- Production (governed only): `always-test`, `spine-writer`, `production-lane`

Two v0.3 plugins were removed in the same change set: the sandbox-exploration
plugin and the spec-enforcement plugin.

## Naming

| Surface              | Value                                                | Where it's set                                              |
| -------------------- | ---------------------------------------------------- | ----------------------------------------------------------- |
| Marketplace name     | `e22-plugins`                                        | `.claude-plugin/marketplace.json` → `name`                  |
| Plugin names         | `e22-org`, `security-rails`, `handoff-packager`, `house-style`, `always-test`, `spine-writer`, `production-lane` | each `plugins/<name>/.claude-plugin/plugin.json` and the marketplace entry |
| Install handles      | `<name>@e22-plugins`                                 | derived                                                     |
| Suggested GitHub repo| `element22llc/e22-plugins`                           | external — directory on disk is `e22-plugins/`              |

Reserved-name check: none of the plugin names collide with the Anthropic
reserved list, and none include the word `claude`.

## Layout

```
e22-plugins/
├── .claude-plugin/
│   └── marketplace.json
├── plugins/
│   ├── e22-org/
│   │   ├── .claude-plugin/plugin.json
│   │   ├── CLAUDE.md
│   │   ├── hooks/{hooks.json,sandbox-guardrails.sh,handoff-cue.sh}
│   │   ├── lib/zone.sh
│   │   └── templates/HANDOFF.md.template
│   ├── security-rails/
│   │   ├── .claude-plugin/plugin.json
│   │   └── hooks/{hooks.json,scan-content.sh,scan-bash.sh}
│   ├── handoff-packager/
│   │   ├── .claude-plugin/plugin.json
│   │   └── CLAUDE.md
│   ├── house-style/
│   │   ├── .claude-plugin/plugin.json
│   │   ├── CLAUDE.md
│   │   └── hooks/{hooks.json,run-house-style.sh}
│   ├── always-test/
│   │   ├── .claude-plugin/plugin.json
│   │   └── hooks/{hooks.json,check-test-coverage.sh,remind-smoke-test.sh}
│   ├── spine-writer/
│   │   ├── .claude-plugin/plugin.json
│   │   ├── agents/spine-extractor.md
│   │   ├── commands/spine-refresh.md
│   │   ├── hooks/{hooks.json,maybe-refresh.sh}
│   │   └── skills/spine-staleness-cue/SKILL.md
│   └── production-lane/
│       ├── .claude-plugin/plugin.json
│       ├── agents/{spec-refiner,drift-monitor}.md
│       ├── commands/{validate,propose,from-design,promote}.md
│       └── skills/{validation-decision,proposal-intake,feature-flag-promotion}/SKILL.md
├── templates/
│   ├── claude-settings.json
│   └── README.md
├── CONSTITUTION.md
├── PRODUCT_SPINE_TEMPLATE.md
├── MARKETPLACE_VALIDATION.md
└── README.md
```

## Install and test

From the repo root:

```bash
claude plugin validate .
claude plugin marketplace add ./
# PO bundle:
claude plugin install e22-org@e22-plugins
claude plugin install security-rails@e22-plugins
claude plugin install handoff-packager@e22-plugins
claude plugin install house-style@e22-plugins
# Dev bundle adds:
claude plugin install always-test@e22-plugins
claude plugin install spine-writer@e22-plugins
claude plugin install production-lane@e22-plugins
```

Once on GitHub at `element22llc/e22-plugins`:

```bash
claude plugin marketplace add element22llc/e22-plugins
# install handles above with the @e22-plugins suffix
```

## Hooks notes

- Every hook script under `plugins/*/hooks/*.sh` must be executable
  (`chmod +x`). The marketplace install does not chmod for you.
- Hook scripts use `${CLAUDE_PLUGIN_ROOT}` for portable referencing.
- Zone-gated hooks source `${CLAUDE_PLUGIN_ROOT}/../e22-org/lib/zone.sh`.
  This means `e22-org` must be installed for the other plugins' hooks to
  work — install it first, or always (it's part of both bundles).
- Hooks parse the hook payload from stdin with `python3` (assumed present).

## Outstanding manual steps

1. **Re-run `claude plugin validate .`** locally after this commit to
   re-establish a clean validation timestamp.
2. **Push to GitHub** when the branch is ready.

## Things to know for later

- **Adding an eighth plugin.** Create
  `plugins/<new-plugin>/.claude-plugin/plugin.json` and a new entry in
  `marketplace.json#plugins` with `"source": "./plugins/<new-plugin>"`.
  Use explicit repo-rooted paths (we tried `metadata.pluginRoot` and the
  Claude.ai org sync did not honor it).
- **Versioning.** Bump on every functional change or users won't see
  updates. Current versions: see README.md "Versions" table.
- **Zone detection.** All zone-gated hooks source
  `plugins/e22-org/lib/zone.sh`. The discriminator is the `origin` remote
  pointing at GitHub. Don't change this casually — every zone-gated plugin
  depends on it.
- **Release channels.** When ready, create two marketplaces pointing at the
  same repo on different refs (`stable`, `latest`) and assign them via
  managed settings.
- **Private repo auto-updates.** Background updates need `GITHUB_TOKEN` or
  `GH_TOKEN` in the user's env.

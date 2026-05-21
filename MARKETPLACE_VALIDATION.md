# Marketplace conformance — `e22-plugins`

Validated against: <https://code.claude.com/docs/en/plugin-marketplaces> (fetched 2026-05-19).
Last verified locally: `claude plugin validate .` should be re-run after the
2026-05-21 two-lane realignment (this commit).

## Status

Conformant in design. Shipping eight plugins reflecting the deck *"From Vibes to
Production — an AI-native collaborative workflow"*:

- Two lane plugins: `prototype-lane`, `production-lane`
- Six house-rule plugins: `spec-driven-dev`, `always-test`, `house-style`,
  `security-rails`, `spine-writer`, `handoff-packager`

## Naming

| Surface              | Value                                                | Where it's set                                              |
| -------------------- | ---------------------------------------------------- | ----------------------------------------------------------- |
| Marketplace name     | `e22-plugins`                                        | `.claude-plugin/marketplace.json` → `name`                  |
| Plugin names         | `prototype-lane`, `production-lane`, `spec-driven-dev`, `always-test`, `house-style`, `security-rails`, `spine-writer`, `handoff-packager` | each `plugins/<name>/.claude-plugin/plugin.json` and the marketplace entry |
| Install handles      | `<name>@e22-plugins`                                 | derived                                                     |
| Suggested GitHub repo| `element22llc/e22-plugins`                           | external — directory on disk is `e22-plugins/`              |

Reserved-name check: none of the plugin names collide with the Anthropic reserved
list and none include the word `claude`, so they won't trip the Claude.ai
marketplace sync's impersonation rules.

## Layout

```
e22-plugins/
├── .claude-plugin/
│   └── marketplace.json
├── plugins/
│   ├── prototype-lane/
│   │   ├── .claude-plugin/plugin.json
│   │   ├── agents/intake-clarifier.md
│   │   ├── commands/{vibe,package-handoff,proposal-status}.md
│   │   └── skills/{change-idea-intake,proposal-glossary}/SKILL.md
│   ├── production-lane/
│   │   ├── .claude-plugin/plugin.json
│   │   ├── agents/{spec-refiner,drift-monitor}.md
│   │   └── commands/{validate,propose,from-design,promote}.md
│   ├── spec-driven-dev/
│   │   ├── .claude-plugin/plugin.json
│   │   └── hooks/{hooks.json,check-spec-exists.sh,announce-lane.sh}
│   ├── always-test/
│   │   ├── .claude-plugin/plugin.json
│   │   └── hooks/{hooks.json,check-test-coverage.sh,remind-smoke-test.sh}
│   ├── house-style/
│   │   ├── .claude-plugin/plugin.json
│   │   └── hooks/{hooks.json,run-house-style.sh}
│   ├── security-rails/
│   │   ├── .claude-plugin/plugin.json
│   │   └── hooks/{hooks.json,scan-content.sh,scan-bash.sh}
│   ├── spine-writer/
│   │   ├── .claude-plugin/plugin.json
│   │   ├── agents/spine-extractor.md
│   │   ├── commands/spine-refresh.md
│   │   └── hooks/{hooks.json,maybe-refresh.sh}
│   └── handoff-packager/
│       ├── .claude-plugin/plugin.json
│       └── commands/package.md
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
claude plugin install prototype-lane@e22-plugins
claude plugin install production-lane@e22-plugins
claude plugin install spec-driven-dev@e22-plugins
claude plugin install always-test@e22-plugins
claude plugin install house-style@e22-plugins
claude plugin install security-rails@e22-plugins
claude plugin install spine-writer@e22-plugins
claude plugin install handoff-packager@e22-plugins
```

Once on GitHub at `element22llc/e22-plugins`:

```bash
claude plugin marketplace add element22llc/e22-plugins
# install handles above with the @e22-plugins suffix
```

## Auto-prompt teammates in other repos

In any Element 22 product repo, drop `templates/claude-settings.json` at
`.claude/settings.json` — see [`templates/README.md`](./templates/README.md). All
eight plugins are pre-enabled there.

## Hooks notes

- Every hook script under `plugins/*/hooks/*.sh` must be executable
  (`chmod +x`). The marketplace install does not chmod for you.
- Hook scripts use `${CLAUDE_PLUGIN_ROOT}` for portable referencing — see
  `plugins/*/hooks/hooks.json` for the convention.
- Hooks parse the hook payload from stdin with `python3` (assumed present in the
  user's environment). If a product can't rely on Python, swap for `jq` or
  inline parsing in shell.

## Outstanding manual steps

1. **Push to GitHub.** Repo `element22llc/e22-plugins` should host this checkout.
2. **Re-run `claude plugin validate .`** locally after the 2026-05-21 rewrite to
   re-establish a clean validation timestamp.
3. **Commit the rewrite.** Conventional commit suggested:
   `feat: realign marketplace to two-lane + Product Spine workflow per Slide-deck v1`.

## Things to know for later

- **Adding a ninth plugin.** Create `plugins/<new-plugin>/.claude-plugin/plugin.json`
  and add a new entry to `marketplace.json#plugins`. Because
  `metadata.pluginRoot` is set to `./plugins`, the `source` value just needs to
  be the bare directory name.
- **Versioning.** Lane plugins are at `0.2.0` (post-rewrite); house rules are at
  `0.1.0` (fresh). Bump on every functional change or users won't see updates.
- **Release channels.** When ready, create two marketplaces pointing at the same
  repo on different refs (`stable`, `latest`) and assign them via managed settings.
- **Private repo auto-updates.** Background updates need `GITHUB_TOKEN` or
  `GH_TOKEN` in the user's env — interactive credential prompts are suppressed.
- **`CLAUDE_PLUGIN_ROOT`.** Hooks already use this env var; reference plugin-internal
  files via it so plugins remain relocatable.
- **Lane detection.** All lane-aware hooks read the lane from `git rev-parse
  --abbrev-ref HEAD`. If a product repo doesn't use the `prototype/*` prefix
  convention, the hooks treat the branch as production-lane and apply strict
  rules. Don't change the convention casually — it's load-bearing.

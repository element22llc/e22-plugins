# CLAUDE.md — e22-plugins

This repo is the **Element 22 plugin marketplace**. It is not a product; it
hosts a single plugin, `e22-standards`, that injects E22's org-wide engineering
standards into every product Claude session.

**Source of truth:** the standards mirror the
[`repository-template`](https://github.com/element22llc/repository-template)
repo. When that template's generic rules change, update the corresponding
`plugins/e22-standards/rules/*.md` (and bundled reference/templates) here. Do not
invent new standards here that the template doesn't carry — this is a mirror, not
a second source.

## Layout

```text
.claude-plugin/marketplace.json     # lists e22-standards
plugins/e22-standards/
├── .claude-plugin/plugin.json      # name + version (bump on any behavior change)
├── hooks/                          # SessionStart hook → injects rules/*.md
├── rules/                          # always-on ruleset (numeric-prefixed, lexical order)
├── skills/                         # on-demand: e22-init, e22-spec-scaffold, e22-adr, e22-conventions, e22-design-sources
├── commands/                       # /e22-init alias
└── templates/                      # bundled spec templates + full reference prose
```

## Working in this repo

- Changes go through `feat/*` / `fix/*` branches off `main` + PR.
- Any change to plugin behavior needs a `version` bump in
  `plugins/e22-standards/.claude-plugin/plugin.json` and a `CHANGELOG.md` entry.
- `rules/*.md` is **always-on** context injected every session — keep it lean and
  imperative. Push long prose into `templates/reference/*` and surface it via a
  skill, not into `rules/`.
- The `rules/` files concatenate in **lexical order** (numeric prefixes). Keep
  prefixes spaced so new rules can slot between existing ones.
- Hook scripts under `hooks/*.sh` must be executable (`chmod +x`); marketplace
  install does not chmod for you. The injector is POSIX `sh`, no `jq` dependency.
- Never put first-run-only content (placeholder resolution) into `rules/` — it
  would re-fire every session. That lives in the `e22-init` skill.

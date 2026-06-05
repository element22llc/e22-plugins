# CLAUDE.md — e22-plugins

This repo is the **Element 22 plugin marketplace**. It is not a product; it
hosts a single plugin, `e22-standards`, that injects E22's org-wide engineering
standards into every product Claude session.

**Source of truth: this repo.** The org standards live in
`plugins/e22-standards/` (rules, skills, reference prose) and are consumed by
every product repo — including
[`repository-template`](https://github.com/element22llc/repository-template) —
via the marketplace. Standards prose is **not** duplicated into the template or
any product `CLAUDE.md`; those hold only product-specific context. When a
standard implies concrete scaffolding (CI workflows, `mise.toml` tasks,
`compose.yaml`, README quickstart), the template carries those *files* — update
both repos in the same change, but the normative text lives only here.

## Layout

```text
.claude-plugin/marketplace.json     # lists e22-standards
plugins/e22-standards/
├── .claude-plugin/plugin.json      # name + version (bump on any behavior change)
├── hooks/                          # SessionStart hook → injects rules/*.md
├── rules/                          # always-on ruleset (numeric-prefixed, lexical order)
├── skills/                         # on-demand: e22-init, e22-build, e22-spec-scaffold, e22-adr, e22-conventions, e22-design-sources
├── commands/                       # /e22-init and /e22-build aliases
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
- Hook commands in `hooks.json` invoke their scripts via an explicit `sh` prefix,
  so the executable bit doesn't matter (marketplace install does not chmod) —
  keep that prefix when adding hooks. All hook scripts are POSIX `sh`, no `jq`
  dependency.
- Never put first-run-only content (placeholder resolution) into `rules/` — it
  would re-fire every session. That lives in the `e22-init` skill.

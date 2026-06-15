# CLAUDE.md — e22-plugins

This repo is the **Element 22 plugin marketplace**. It is not a product; it
hosts one plugin of its own, `e22-standards`, which injects E22's org-wide
engineering standards into every product Claude session. The marketplace also
**re-lists** Anthropic's upstream `frontend-design` plugin via a `git-subdir`
source pinned to a SHA — that plugin is *referenced, not vendored*; its content
is never copied here, and updating it means bumping the SHA in
`.claude-plugin/marketplace.json`.

**Source of truth: this repo — for standards *and* bootstrap.** The org
standards live in `plugins/e22-standards/` (rules, skills, reference prose),
consumed by every product repo via the marketplace. The plugin also carries the
**bundled repo scaffold** (`plugins/e22-standards/templates/scaffold/` +
spec-spine templates in `templates/spec/`), which `/e22-init` / `/e22-adopt`
install — this **replaces** the old static
[`repository-template`](https://github.com/element22llc/repository-template)
as the bootstrap source; do not point new work at that repo. When a standard
implies concrete scaffolding (CI workflows, `mise.toml` tasks, `compose.yaml`,
README quickstart, PR template), update the scaffold bundle here in the same
change as the rule. Standards prose is **not** duplicated into any product
`CLAUDE.md`; those hold only product-specific context. Scaffold dotfiles are
stored **without the leading dot** (`gitignore`, `env.example`, `claude/`,
`github/`, …) so they don't act on this repo itself — `MANIFEST.md` maps the
install paths; keep it in sync when adding scaffold files.

## Layout

```text
.claude-plugin/marketplace.json     # lists e22-standards
plugins/e22-standards/
├── .claude-plugin/plugin.json      # name + version (bump on any behavior change)
├── hooks/                          # SessionStart hook → injects rules/*.md
├── rules/                          # always-on ruleset (numeric-prefixed, lexical order)
├── skills/                         # on-demand: e22-init, e22-adopt, e22-build, e22-conventions,
│                                   #            e22-traceability, e22-design-sources, e22-spec-scaffold,
│                                   #            e22-spec, e22-issues, e22-tracker-sync, e22-work, e22-adr,
│                                   #            e22-drift, e22-audit, e22-sync, e22-questions, e22-tidy, e22-standards
├── commands/                       # optional /slash aliases for a subset of skills
│                                   #   (e22-init, e22-build, e22-adopt, e22-spec, e22-issues, e22-tracker-sync,
│                                   #    e22-work, e22-drift, e22-audit, e22-sync, e22-questions, e22-tidy);
│                                   #   skills without an alias are still invokable as /<skill-name>
└── templates/
    ├── spec/                       # spec artifacts skills instantiate (intent, contract, adr,
    │                               #   vision/users/glossary, history, tracker, app-docs, …)
    ├── reference/                  # full reference prose (CONVENTIONS, TRACEABILITY, …)
    └── scaffold/                   # bundled repo bootstrap (mise, compose, CI, PR template, …)
                                    #   — see its MANIFEST.md for the install map
```

## Working in this repo

- Changes go through `feat/*` / `fix/*` branches off `main` + PR.
- Any change to plugin behavior needs a `version` bump in
  `plugins/e22-standards/.claude-plugin/plugin.json` and a `CHANGELOG.md` entry.
- `rules/*.md` is **always-on** context injected every session — keep it lean and
  imperative. Push long prose into `templates/reference/*` and surface it via a
  skill, not into `rules/`.
- The `rules/` files concatenate in **lexical order** (numeric prefixes). Keep
  prefixes spaced so new rules can slot between existing ones. Gaps in the
  sequence (e.g. `20` → `22` → `30`) are intentional headroom — do not renumber
  files to make the prefixes contiguous.
- Command files in `commands/` are **optional aliases** — they exist only where a
  skill benefits from a short `/slash` entry point. Every skill is directly
  invokable as `/<skill-name>` regardless, so a skill having no command file
  (e.g. `e22-adr`, `e22-spec-scaffold`, `e22-conventions`) is not a defect.
- Hook commands in `hooks.json` invoke their scripts via an explicit `sh` prefix,
  so the executable bit doesn't matter (marketplace install does not chmod) —
  keep that prefix when adding hooks. All hook scripts are POSIX `sh`, no `jq`
  dependency.
- Never put first-run-only content (placeholder resolution) into `rules/` — it
  would re-fire every session. That lives in the `e22-init` skill.

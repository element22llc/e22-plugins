# CLAUDE.md — e22-plugins

This repo is the **engineering-standards plugin marketplace**. It is not a
product; it hosts one plugin of its own, `steer`, which injects org-wide
engineering standards into every product Claude session. The marketplace also
**re-lists** Anthropic's upstream `frontend-design` plugin via a `git-subdir`
source pinned to a SHA — that plugin is *referenced, not vendored*; its content
is never copied here, and updating it means bumping the SHA in
`.claude-plugin/marketplace.json`.

**Source of truth: this repo — for standards *and* bootstrap.** The org
standards live in `plugins/steer/` (rules, skills, reference prose),
consumed by every product repo via the marketplace. The plugin also carries the
**bundled repo scaffold** (`plugins/steer/templates/scaffold/` +
spec-spine templates in `templates/spec/`), which `/steer:init` / `/steer:adopt`
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
.claude-plugin/marketplace.json     # lists steer
plugins/steer/
├── .claude-plugin/plugin.json      # name + version (bump on any behavior change)
├── hooks/                          # SessionStart hook → injects rules/*.md
├── scripts/                        # POSIX-sh helpers skills invoke via ${CLAUDE_PLUGIN_ROOT}
│                                   #   (e.g. template-reconcile.sh — read-only template diff)
├── rules/                          # always-on ruleset (numeric-prefixed, lexical order)
├── skills/                         # on-demand, invoked as /steer:<skill>:
│                                   #            init, adopt, build, conventions,
│                                   #            traceability, design-sources, spec-scaffold,
│                                   #            spec, issues, tracker-sync, work, adr,
│                                   #            drift, audit, sync, questions, next, tidy, standards
│                                   # (no commands/ — see "invocation syntax" below)
└── templates/
    ├── spec/                       # spec artifacts skills instantiate (intent, contract, adr,
    │                               #   vision/users/glossary, history, tracker, app-docs, …)
    ├── reference/                  # full reference prose (CONVENTIONS, TRACEABILITY, …)
    └── scaffold/                   # bundled repo bootstrap (mise, compose, CI, PR template, …)
                                    #   — see its MANIFEST.md for the install map
```

## Working in this repo

- Changes go through `feat/*` / `fix/*` branches off `main` + PR.
- Any change to plugin behavior needs a `CHANGELOG.md` entry. Accumulate entries
  under `## steer` → `### [Unreleased]`; implementation PRs do **not**
  bump `plugins/steer/.claude-plugin/plugin.json`. The `version` bump
  happens **once**, in the release PR that renames `[Unreleased]` to the new
  version — so a stream of PRs cuts one coherent release instead of a bump each.
- `rules/*.md` is **always-on** context injected every session — keep it lean and
  imperative. Push long prose into `templates/reference/*` and surface it via a
  skill, not into `rules/`.
- The `rules/` files concatenate in **lexical order** (numeric prefixes). Keep
  prefixes spaced so new rules can slot between existing ones. Gaps in the
  sequence (e.g. `20` → `22` → `30`) are intentional headroom — do not renumber
  files to make the prefixes contiguous.
- **Invocation syntax — skills are plugin-namespaced.** A skill named `<skill>`
  is invoked as **`/steer:<skill>`** (e.g. `/steer:spec`), never
  bare `/<skill>` — Claude Code always namespaces plugin skills to avoid
  cross-plugin collisions. There is no `commands/` directory: the legacy thin
  command shims were removed (they duplicated skill semantics and only ever
  produced the same namespaced invocation). When writing docs, rules, or skill
  cross-references, always use the `/steer:` prefix; a bare `/e22-*` in
  prose is a bug the validation suite flags.
- Hook commands in `hooks.json` invoke their scripts via an explicit `sh` prefix,
  so the executable bit doesn't matter (marketplace install does not chmod) —
  keep that prefix when adding hooks. All hook scripts are POSIX `sh`, no `jq`
  dependency.
- Never put first-run-only content (placeholder resolution) into `rules/` — it
  would re-fire every session. That lives in the `init` skill.

## Working loop & verification

The dev loop is driven by `mise` (run `mise tasks` to list everything):

- **Before every commit — fast gate:** `mise run check` (lint + plugin-check +
  actionlint). This is the pre-commit equivalent.
- **Before push / PR — full gate:** `mise run ci` — exactly what CI runs (adds
  `fixtures`, `test`, `shell`, `hooktests`, `version-scan`, `docs:check` on top
  of `check`).
- **Docs site:** the Zensical site under `docs/` (config: `mkdocs.yml`, which
  Zensical reads natively) is
  auto-maintained by the repo-local `/plugin-docs` skill + `documentation-reviewer`
  agent. Serve it with `mise run docs:serve`; the `docs:check` gate
  (`scripts/validate_docs.py`) keeps `docs/reference/*` in sync with the plugin.
  See `AUTHORING.md` → "Documentation site". Docs ship nothing — no changelog
  entry. **Auto-reconcile on commit:** the `docs-sync` pre-commit hook runs
  `validate_docs.py`; if it aborts a commit, that is your cue to run
  `/plugin-docs` immediately, then re-stage `docs/` and re-commit so docs and
  code land in the same commit — do not skip the hook or commit around it.
- **Fast iteration:** when one gate fails, re-run just that script —
  `uv run python scripts/check_standards.py`, `… scripts/check_plugin.py`,
  `… scripts/check_fixtures.py`, or `sh plugins/steer/hooks/tests/run.sh`.
- **Adding a skill / rule / hook / scaffold file?** See
  [`AUTHORING.md`](AUTHORING.md) for the frontmatter schema, rule
  numbering, hook rules, and a "what I touched → what to run" matrix. Repo-local
  helpers `/new-skill`, `/new-rule`, and `/preflight` scaffold and verify for you.
- **Behaviour changes are gated twice:** a change under `plugins/steer/`
  (skills, rules, hooks, templates, scripts, policy) needs a `CHANGELOG.md`
  `## steer` → `### [Unreleased]` entry — `check_changelog.py --base` enforces
  this on PRs (`tests/` are exempt). The `plugin.json` `version` bump happens
  **once**, at release. Changes confined to `CLAUDE.md`, `docs/`, or `.claude/`
  ship nothing and need no changelog entry.

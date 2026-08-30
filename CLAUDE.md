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
install — this **replaces** the old static `repository-template`
(a private repo, intentionally not linked here) as the bootstrap source; do not
point new work at that repo. When a standard
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
├── .github/plugin/plugin.json      # Copilot plugin manifest (the generated Copilot target)
├── .mcp.json                       # plugin MCP servers (github, context7)
├── agents/                         # subagents (steer-reviewer — driven by /steer:audit,
│                                   #   /steer:work --reviewed, and the /steer:loop workflow)
├── hooks/                          # SessionStart hooks → inject rules/*.md + orientation;
│                                   #   PreToolUse/PostToolUse/Stop gates;
│                                   #   CwdChanged/SessionEnd/WorktreeRemove lifecycle hooks
│                                   #   (worktree trust + Docker teardown);
│                                   #   copilot-hooks.json (Copilot-CLI hook variant)
├── policy/                         # org policy data (branch-protection.yml, versions.yml)
├── scripts/                        # helpers skills invoke via ${CLAUDE_PLUGIN_ROOT} —
│                                   #   mostly POSIX sh (e.g. template-reconcile.sh — read-only
│                                   #   template diff) plus Python (scaffold_reconcile.py)
├── rules/                          # always-on ruleset (numeric-prefixed, lexical order)
├── skills/                         # on-demand, invoked as /steer:<skill>:
│                                   #            setup, doctor, init, adopt, build, reference,
│                                   #            spec-scaffold,
│                                   #            spec, intake, issues, tracker-sync, work, adr,
│                                   #            audit, loop, sync, questions, next, explain, status, tidy,
│                                   #            standards, protect, report, roadmap, help
│                                   # (all are user-invocable except the internal
│                                   #  gateways spec-scaffold + tracker-sync, which are
│                                   #  user-invocable:false — reached via a front door)
│                                   # (no commands/ — see "invocation syntax" below)
└── templates/
    ├── spec/                       # spec artifacts skills instantiate (intent, contract, adr,
    │                               #   vision/users/glossary, history, tracker, app-docs, …)
    ├── reference/                  # full reference prose (CONVENTIONS, TRACEABILITY, …)
    ├── docker/                     # on-demand Dockerfile refs (Node/Python) — instantiated per
    │                               #   deployable app by /steer:build & /steer:adopt, NOT bootstrapped
    ├── github/                     # GitHub templates — single source of truth (issue forms,
    │                               #   workflows/ ci.yml + claude.yml + dependabot-auto-merge.yml + …,
    │                               #   pull_request_template.md) + the GENERATED Copilot artifacts
    │                               #   (copilot-instructions.md, agents/, instructions/ —
    │                               #    via `mise run gen:copilot`)
    ├── agents/skills/              # GENERATED cross-tool skill surface (all 26 skills in the
    │                               #   open Agent Skills format) — consumers install it as
    │                               #   .agents/skills/; via `mise run gen:copilot`
    └── scaffold/                   # bundled repo bootstrap (mise, compose, CI, PR template, …)
                                    #   — see its MANIFEST.md for the install map
```

## Working in this repo

**[`CONTRIBUTING.md`](CONTRIBUTING.md) → "Working in this repo" is the working
agreement** — branch, commit convention, changelog, gates, PR scope, decision
capture. Read it before your first PR here. The essentials, condensed:

- Changes go through `feat/*` / `fix/*` branches off `main` + PR. A web session's
  assigned `claude/<slug>` branch is used as-is — don't rename it.
- **One PR, one concern — repo conventions are frozen unless changing them *is*
  the PR.** `CLAUDE.md`, `AUTHORING.md`, `CONTRIBUTING.md`, `docs/contributing/`,
  `docs/decisions/`, the gate scripts, and the release flow do not get amended in
  passing by a PR that is really about something else: a convention landed as a
  side effect never gets reviewed as a convention. Updating a doc *in service of*
  your change is expected; redefining the rule while shipping something else is
  not — that's a separate, convention-only PR. Same for a decision not yet made:
  propose it in prose in the issue or PR description, don't commit the
  scaffolding for it (`CONTRIBUTING.md` → "Scope").
- **This repo keeps no ADR log.** Plugin decisions are recorded in `CHANGELOG.md`
  + the PR; `docs/decisions/` describes ADRs as a `/spec`-spine artifact of
  *managed product repos*. A decision too big for a PR description means split
  the PR, not invent a record type.
- Commit subjects follow Conventional Commits — `type(scope): imperative summary`.
  Scopes in use: `steer`, `hooks`, `skills`, `rules`, `scaffold`, `docs`, `dx`,
  `release`. No commit-lint gate; the PR review is the gate.
- Two sets of GitHub templates, easy to confuse: `.github/` at the root is **this
  repo's own** (ships nothing, no changelog entry) — **except
  `.github/plugin/marketplace.json`**, the consumer-facing Copilot marketplace,
  which carries steer's released version and *is* plugin behavior;
  `plugins/steer/templates/github/` is what **consumer repos** get (plugin
  behavior — changelog entry required).
- Any change to plugin behavior needs a `CHANGELOG.md` entry. Accumulate entries
  under `## steer` → `### [Unreleased]`; implementation PRs do **not**
  bump `plugins/steer/.claude-plugin/plugin.json`. The `version` bump
  happens **once**, in the release PR that renames `[Unreleased]` to the new
  version — so a stream of PRs cuts one coherent release instead of a bump each.
  `CHANGELOG.md` is marked `merge=union` in `.gitattributes`, so concurrent PRs
  appending bullets under `### [Unreleased]` **never conflict** — git keeps both
  sides. This relies on the `### [Unreleased]` heading being **persistent** (the
  release skill re-seeds an empty one after each cut); add each change as its own
  bullet and don't recreate the heading. See `AUTHORING.md` → "CHANGELOG &
  versioning".
- **Releases publish themselves.** When a release PR (the `plugin.json` version
  bump) merges to `main`, `.github/workflows/release-publish.yml` fires — gated
  on the version bump — and cuts the `vX.Y.Z` git tag + GitHub
  Release with that version's CHANGELOG bullets as the body (extracted by
  `scripts/changelog_release_notes.py`), followed by GitHub's auto-generated
  "What's Changed" (merged-PR list + contributors + compare link) via
  `--generate-notes`. It is idempotent and re-runnable via
  `workflow_dispatch`. History predating the workflow was backfilled once (a
  one-shot script, since removed), so every prior `vX.Y.Z` already has a tag +
  Release. These live outside `plugins/steer/`, so they ship nothing and need no
  changelog entry.
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

- **Before every commit — fast gate:** `mise run check` (lint + typecheck +
  plugin-check + actionlint + actions-security + shell + docs:check). This is a
  strict superset of the installed pre-commit hooks — a green `check` is never
  followed by a rejected `git commit`. The pre-commit tier runs only the lighter
  hygiene checks (ruff, `ty`, `check_plugin.py`, `claude plugin validate
  plugins/steer`, docs-sync, actionlint, zizmor, shellcheck/shfmt), while
  `check` adds `check_standards.py`, the copilot sync checks, the changelog
  release validator, the marketplace-manifest validation, and the **advisory**
  zizmor tier over the shipped workflow templates. **Keep the superset property:** when you add
  a pre-commit hook, wire its `mise` task into `check`'s `depends`, and keep the
  `shell` task's globs covering every `*.sh` that pre-commit's `types: [shell]`
  matches.
- **Before push / PR — full gate:** `mise run ci` — exactly what CI runs (adds
  `fixtures`, `test`, `hooktests`, `version-scan`, and `delivery-gates` on top
  of `check`, which already carries `shell` and `docs:check`). `delivery-gates` runs the two PR-only
  branch-diff checks (`check_changelog.py --base` and `check_docs_impact.py
  --base`) against `origin/main`, so a missing CHANGELOG or docs update is caught
  here instead of failing CI after you push. It fail-opens when `origin/main`
  isn't fetched; CI's sha-based steps remain authoritative there.
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
- **Editing a rule?** `mise run rules:preview` shows the always-on payload a
  real session receives — a per-rule inject/skip table with the `inject-when`
  token that decided each one, plus the byte total. Add `-- --repo <path>` for a
  consumer repo, `-- --knowledge` for a non-code folder, `-- --full` to dump the
  text. It drives the real hook and the real scope predicates, so it can't drift
  from live behaviour. An authoring aid, not a gate.
- **Adding a skill / rule / hook / scaffold file?** See
  [`AUTHORING.md`](AUTHORING.md) for the frontmatter schema, rule
  numbering, hook rules, and a "what I touched → what to run" matrix. Repo-local
  helpers `/new-skill`, `/new-rule`, and `/preflight` scaffold and verify for you.
- **Behaviour changes are gated twice:** a change **anywhere under
  `plugins/steer/`** — or to the root `.github/plugin/marketplace.json`, the one
  version-bearing manifest outside it — needs a `CHANGELOG.md`
  `## steer` → `### [Unreleased]` entry, enforced on PRs by
  `check_changelog.py --base`. The gate is **deny-by-default**: everything the
  plugin ships counts, and the exemptions are enumerated in that script with a
  reason each (`tests/` anywhere, `evals/`, the plugin's maintainer `README.md`,
  and `plugins/steer/.claude/`). Adding a new plugin component therefore requires
  an entry without anyone remembering to widen the gate first — and exempting a
  new directory is a deliberate edit that has to say why it ships nothing. The
  `plugin.json` `version` bump happens **once**, at release. Changes confined to
  `CLAUDE.md`, `docs/`, or the repo-root `.claude/` ship nothing and need no
  changelog entry.

# Authoring guide — e22-plugins

How to add or change a skill, rule, hook, or scaffold file in the `steer`
plugin without reverse-engineering the conventions. This consolidates what the
root [`CLAUDE.md`](../CLAUDE.md), the check scripts under `scripts/`, and
[`plugins/steer/templates/reference/INVOCATION.md`](../plugins/steer/templates/reference/INVOCATION.md)
already enforce — it does **not** introduce new policy.

> Repo-local helpers do the mechanical parts for you: `/new-skill`, `/new-rule`,
> and `/preflight` (defined under `.claude/skills/`, not shipped). Read the
> relevant section below to understand what they generate.

## What I touched → what to run

Run `mise run check` before every commit and `mise run ci` before push/PR
regardless — this matrix is for tight iteration on a single failure.

| You edited… | Gate that covers it | Fast re-run |
| --- | --- | --- |
| `plugins/steer/skills/**` | `plugin-check` | `uv run python scripts/check_plugin.py && uv run python scripts/check_standards.py` |
| `plugins/steer/rules/**` | `plugin-check` | `uv run python scripts/check_plugin.py` |
| `plugins/steer/hooks/**` | `hooktests` + `shell` | `sh plugins/steer/hooks/tests/run.sh` |
| `plugins/steer/templates/**` (scaffold, github, spec, reference) | `plugin-check` (+ `fixtures` if golden) | `uv run python scripts/check_standards.py` |
| `plugins/steer/scripts/**`, `hooks/lib/version-policy.sh` | `shell` + `version-scan` | `uv run python scripts/check_standards.py` (byte-identical copies) |
| `scripts/*.py` (the validators themselves) | `lint` + `test` | `uv run pytest && uv run ruff check .` |
| `.github/workflows/**` | `actions` | `actionlint` |
| `CHANGELOG.md` / `plugin.json` | `plugin-check` | `uv run python scripts/check_changelog.py` |
| `docs/**` (the docs site) | `docs:check` | `uv run python scripts/validate_docs.py` (then `mise run docs:build` for a strict link check) |
| `CLAUDE.md`, `.claude/` | nothing ships | — (no changelog entry) |

## Skill frontmatter schema

Skills live at `plugins/steer/skills/<name>/SKILL.md`. `check_plugin.py` requires
`name`, `description`, and `when_to_use`; `name` must equal the directory name and
be unique. The full field set actually used in this repo:

| Field | Required | Notes |
| --- | --- | --- |
| `name` | yes | kebab-case, **no `/steer:` prefix**, must match the directory name. |
| `description` | yes | One prose sentence on purpose and scope. |
| `when_to_use` | yes | When to invoke. Restricted-grammar scalar (see gotcha below). |
| `argument-hint` | no | CLI arg syntax for multi-mode skills, e.g. `"[start \| resume \| status \| finish] [#issue ...]"`. |
| `allowed-tools` | no | Pre-approve idempotent ops so the skill doesn't prompt — see below. |
| `disallowed-tools` | no | Block mutation classes — used by read-only (Tier 1) skills. |
| `user-invocable` | no | `false` hides the skill from the slash menu (Tier 3 internal helpers). |

> `displayName` is **not** a skill field — it belongs in
> `plugins/steer/.claude-plugin/plugin.json` (the `/plugin` menu label). There is
> no `model:` field on any skill; do not add one.

**`when_to_use` quoting gotcha.** `check_standards.py` does a restricted-grammar
balance check (not a full YAML parse). A single-quoted scalar must contain exactly
two quotes (no inner `'`); a double-quoted scalar must be closed. When the value
contains quotes or colons, prefer a folded block or a clean double-quoted string:

```yaml
when_to_use: >-
  Use when asked to work, start, resume, or finish a specific issue
  ("work on #123", "fix #123"), or when a change needs an issue then implemented.
```

**Invocation tier → which tool fields to set** (see `INVOCATION.md` for the full
matrix):

- **Tier 1 — read-only / reference** (`conventions`, `traceability`, `audit`,
  `drift`, `standards`, `next`, `design-sources`): never edit code/spec/tracker.
  Set `disallowed-tools: Edit, Write, NotebookEdit, EnterWorktree`.
- **Tier 2 — side-effecting** (`init`, `adopt`, `sync`, `build`, `work`, `spec`,
  `adr`, `issues`, `questions`, …): may create/edit/commit. Use `allowed-tools`
  to pre-approve the routine idempotent ops the skill always performs — e.g.
  `/steer:work` allowlists `Bash(git status *)`, `Bash(git switch *)`,
  `Bash(git add *)`, `Bash(git commit *)`, etc. Keep `git push`/PR creation
  prompt-gated (Rule 45 — commits autonomous, push/PR gated).
- **Tier 3 — internal orchestration only** (`tracker-sync`, `spec-scaffold`):
  set `user-invocable: false`. Called by other skills, not a user's first move.

Long prose belongs in `plugins/steer/templates/reference/*`, surfaced through the
skill — not inlined into the SKILL.md.

## Rule numbering

Rules live at `plugins/steer/rules/NN-<slug>.md` and are concatenated in **lexical
order** by their numeric prefix into the always-on session context.

- Prefixes run `00`–`99` with **intentional gaps** (e.g. `20` → `22` → `30`,
  `35` → `36`) — headroom so a new rule can slot between two existing ones.
- **Never renumber an existing file.** Other rules, skills, and docs reference
  rules by number; renumbering silently breaks those references.
- To add one, pick the largest free gap adjacent to the rule it relates to
  (`/new-rule` lists the taken prefixes and proposes a slot).
- Keep `rules/*.md` **lean and imperative** — it costs context every session.
  Push explanation, rationale, and examples into
  `plugins/steer/templates/reference/*` and point to them.
- Never put first-run-only content (placeholder resolution) in a rule — it would
  re-fire each session; that lives in the `init` skill.

## Hook authoring

Hooks live under `plugins/steer/hooks/` and are wired in `hooks.json`.

- **POSIX `sh` only, no `jq`.** Reuse the helpers in `hooks/lib/*.sh`
  (`json.sh`, `classify.sh`, `lifecycle.sh`, `repo-root.sh`, `spine.sh`,
  `version-policy.sh`) rather than re-parsing.
- `hooks.json` invokes each script with an explicit `sh` prefix, so the
  executable bit does not matter (marketplace install does not `chmod`). Keep the
  `sh` prefix when adding a hook.
- Add a fixture case to `plugins/steer/hooks/tests/run.sh` for any new behaviour,
  then run `mise run hooktests` (deterministic, no network). `mise run shell`
  (shellcheck hard gate, shfmt advisory) must also pass.

## CHANGELOG & versioning

- Accumulate entries under `## steer` → `### [Unreleased]`. Implementation PRs do
  **not** bump `plugins/steer/.claude-plugin/plugin.json` — the version bump
  happens **once**, in the release PR that renames `[Unreleased]` to the new
  version. A stream of PRs thus cuts one coherent release.
- **Behaviour gate:** `check_changelog.py --base <ref>` requires a `CHANGELOG.md`
  edit when any behaviour file changes. Behaviour prefixes are
  `plugins/steer/{skills,hooks,rules,templates,scripts,policy}/` plus
  `plugins/steer/.claude-plugin/plugin.json`. Anything matching `tests/` is
  exempt. Changes confined to `CLAUDE.md`, `docs/`, or `.claude/` are not
  behaviour files and need no entry.
- `check_changelog.py` also validates (always, no git needed) that `plugin.json`'s
  version equals the newest semver heading and that released headings descend in
  strict semver order.

## Scaffold discipline

`plugins/steer/templates/scaffold/` is the bundled repo bootstrap installed by
`/steer:init` / `/steer:adopt`.

- **Dotfiles are stored without the leading dot** (`gitignore`, `env.example`,
  `claude/`, `vscode/`, …) so they don't act on this repo itself.
- **GitHub templates and the spec spine live in their own topic dirs**, not under
  `scaffold/`: `plugins/steer/templates/github/` (Issue Forms, workflows, PR
  template — plus the runtime-only `issue-bodies/`) and
  `plugins/steer/templates/spec/`. The MANIFEST installs them via its
  `../github/` and `../spec/` rows. `templates/github/` is the single source of
  truth for GitHub templates — never add a second copy under `scaffold/`.
- Keep `plugins/steer/templates/scaffold/MANIFEST.md` in sync — it maps each
  stored file (including the `../github/` and `../spec/` topic-dir rows) to its
  install path. Update it in the same change that adds a template file.
- Version-governance files exist in two byte-identical copies (e.g.
  `scaffold/scripts/scan-version-pins.sh` ↔ `scripts/scan-version-pins.sh`;
  `scaffold/scripts/version-policy.sh` ↔ `hooks/lib/version-policy.sh`;
  `scaffold/policy/versions.yml` ↔ `policy/versions.yml`). `check_standards.py`
  fails if they drift — edit both.

## Cross-cutting conventions

- **Always namespace skills as `/steer:<skill>`** in rules, skills, and docs. A
  bare `/e22-*` in prose is flagged by validation.
- **No `commands/` directory.** The legacy thin command shims were removed; skills
  are invoked directly through their plugin namespace.
- **Standards prose is never duplicated** into a product repo's `CLAUDE.md` — that
  file holds only product-specific context. The standards live here and reach
  product repos through the marketplace.

## Documentation site

The MkDocs site under `docs/` is auto-maintained. It is **not** the same thing as
this `AUTHORING.md` (which is about building the plugin); the site documents the
plugin's *behaviour* for consumers.

- **Serve / build / check:** `mise run docs:serve`, `mise run docs:build`
  (strict), `mise run docs:check`. The MkDocs toolchain lives in the `docs`
  dependency-group (`pyproject.toml`) — `serve`/`build` run via
  `uv run --group docs`, so the CI env stays light. `docs:check` is stdlib-only
  and runs inside `mise run ci`.
- **Mermaid** diagrams render via the `pymdownx.superfences` custom fence in
  `mkdocs.yml`; Material bundles `mermaid.js`, so no extra dependency is needed.
- **Reconcile with `/plugin-docs`** (repo-local skill) after changing skills,
  hooks, or rules: it refreshes the generated reference pages and can dispatch the
  `documentation-reviewer` agent. The `docs:check` gate (`validate_docs.py`) fails
  CI if a shipped skill is missing from `docs/reference/skills.md`, a nav entry is
  broken, a page is orphaned, or a link/`/steer:` ref doesn't resolve. The PR-only
  `check_docs_impact.py` gate fails when `skills/`, `rules/`, or `hooks/` change
  but no `docs/` file does.
- **New pages** start from `docs/_templates/` and must be added to the
  `mkdocs.yml` nav (orphans fail the gate).

## Built-in helpers (no install needed)

These ship with Claude Code — lean on them rather than adding MCP servers:

- `/code-review` and `/simplify` — run on your diff before opening a PR.
- `/fewer-permission-prompts` — extend `.claude/settings.json`'s allowlist as new
  routine read-only commands surface.
- `/verify` — confirm a behaviour change does what it should.

No project MCP server is configured in-repo (`codegraph` is enabled per-user via
`settings.local.json` against a globally-configured server). For a
markdown/shell/Python repo, the link- and frontmatter-checks that matter are
already done by `check_plugin.py`.

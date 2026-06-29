# Authoring guide — e22-plugins

How to add or change a skill, rule, hook, or scaffold file in the `steer`
plugin without reverse-engineering the conventions. This consolidates what the
root [`CLAUDE.md`](CLAUDE.md), the check scripts under `scripts/`, and
[`plugins/steer/templates/reference/INVOCATION.md`](plugins/steer/templates/reference/INVOCATION.md)
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

### Local-only dev tools (codegraph)

The committed `mise.toml` pins only what CI needs (python, uv, shellcheck, shfmt,
actionlint), so `mise install --locked` is reproducible on CI. The **codegraph**
MCP code-intelligence server and its `node` runtime are *not* committed there —
they are unused by CI and `codegraph@latest` cannot be pinned to a lockfile URL,
which would break the locked install. Install them per-machine via a gitignored
`mise.local.toml` (mise auto-merges it):

```toml
# mise.local.toml — local only, gitignored
[tools]
node = "24"
"npm:@colbymchenry/codegraph" = "latest"
```

Then `mise install`. Keep these out of the committed `mise.toml`/`mise.lock`.

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

- **Tier 1 — read-only / reference** (`reference`, `audit`, `standards`,
  `next`): never edit code/spec/tracker.
  Set `disallowed-tools: Edit, Write, NotebookEdit, EnterWorktree`.
- **Tier 2 — side-effecting** (`init`, `adopt`, `sync`, `build`, `work`, `spec`,
  `adr`, `issues`, `questions`, …): may create/edit/commit. Use `allowed-tools`
  to pre-approve the routine idempotent ops the skill always performs — e.g.
  `/steer:work` allowlists `Bash(git status *)`, `Bash(git switch *)`,
  `Bash(git add *)`, `Bash(git commit *)`, etc. Keep `git push`/PR creation
  prompt-gated (Rule 45 — commits autonomous, push/PR gated).
- **Tier 3 — hidden from the slash menu** (`user-invocable: false`): still
  model-callable, just not in the menu. Reserved for *internal gateways* a parent
  skill always drives with context a user can't supply by hand — `tracker-sync`
  (GitHub gateway, called with subcommands by `issues`/`work`) and `spec-scaffold`
  (template instantiator, called with a feature id by `spec`/`build`/`init`/`adopt`).
  The specialized skills reached through a front door (`init`/`adopt`/`sync`/`doctor`
  via `/steer:setup`; `tidy` via `/steer:audit`; `roadmap` via `/steer:issues`;
  `questions` via `/steer:spec`/`/steer:issues`; the `reference` loader) stay
  **directly invocable** — a front door just auto-routes to them, so a user is never
  told to type something the harness then rejects. Visibility is orthogonal to
  read-only/side-effecting tier — a hidden skill can still be Tier 1 or Tier 2.

**Allowlists only match single commands — never chain inspection with `&&` or
pipes.** Claude Code matches a permission rule against the *whole* command string.
`git status && git diff` matches neither `Bash(git status *)` nor `Bash(git diff
*)`, so it prompts even when both are allowlisted — silently defeating every
`allowed-tools` entry and the scaffold `allow` list. When a skill runs inspection
commands, instruct it to run them as **separate invocations**, one command per
call. The same goes for the scaffold-shipped allowlist (`templates/scaffold/
claude/settings.json`): the read-only entries (`git status/diff/log/show`, `gh
pr/run/repo/label` reads, `mise run check/ci`) only stay silent when each runs on
its own. This is the single most common reason a repo that *looks* allowlisted
still prompts.

Long prose belongs in `plugins/steer/templates/reference/*`, surfaced through the
skill — not inlined into the SKILL.md.

When a skill runs a **long, multi-phase, or search-heavy** flow, delegate it to a
subagent (fresh context by construction) and persist run-state and task constraints
in `/spec/**` rather than running everything inline — keeping the main session lean
and the state durable across compaction. See rule `26-context-hygiene` and the
exemplars it cites (`/steer:audit` → the `steer-reviewer` agent;
`/steer:work --reviewed`'s plan gate).

### Skill vs. mode — hold the line on surface area

The user-facing menu is the handful of **front doors** in `rules/00-router.md`
(`setup`, `spec`, `build`, `work`, `issues`, `audit`, `next`, `adr`, `protect`,
`report`, `standards`). Every new skill widens the set of things a user must choose
between, so the bar for a *new, visible* skill is high. Before adding one, justify
why it is **not**:

1. **a mode of an existing skill** — a new verb on a skill that already owns the
   area (e.g. `audit [code|spec]`, `work [--reviewed]`), declared via
   `argument-hint` + a `<!-- steer:modes … -->` marker; or
2. **a specialized skill reached through a front door** — directly invocable but
   kept out of the router intent table, with a front door that auto-routes to it
   (add the hand-off prose to the parent and a routing line to `00-router.md`).
   Mark it `user-invocable: false` only if it is a true *internal gateway* a parent
   always drives with context the user can't supply (`tracker-sync`,
   `spec-scaffold`); or
3. **detected and routed** — folded behind a dispatcher like `/steer:setup` that
   picks the path from repo state rather than asking the user to pick a skill.

Default to a mode or a front-door-routed specialized skill. Add a front door only
when the intent is genuinely top-level and maps to no existing owner.

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
- **No merge conflicts on `CHANGELOG.md`.** Every PR adds bullets under the same
  `### [Unreleased]` heading, so concurrent PRs would normally collide there.
  `.gitattributes` marks the file `merge=union`: git's built-in union driver
  keeps **both** sides' added lines instead of writing conflict markers, and
  GitHub's merge button honors it too (it's a built-in driver, not a per-clone
  custom one). For this to stay safe the `### [Unreleased]` heading must be
  **persistent** — always present so PRs only add bullets under it and never
  recreate (and duplicate) the heading. The release skill re-seeds an empty
  `### [Unreleased]` after each cut, and `check_changelog.py` fails the build if
  the heading is duplicated or not first. Practical notes: add each entry as its
  **own bullet** (union merges cleanly at line granularity — avoid editing a
  neighbor's bullet in the same PR), and union does not de-duplicate, so a real
  semantic clash still needs a human glance at release time.
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
- **File naming.** Python scripts are `snake_case.py` (PEP 8 + importable as
  modules); shell scripts are `kebab-case.sh`; reference prose under
  `templates/reference/` is `UPPERCASE.md` (multiword as `UPPER-KEBAB.md`, e.g.
  `ISSUE-SCHEMA.md`). Skills, rules, spec artifacts, and `docs/` pages stay
  `lowercase-kebab`. GitHub-mandated names (`pull_request_template.md`,
  `ISSUE_TEMPLATE/`) are fixed by GitHub and exempt.

## Documentation site

The Zensical site under `docs/` is auto-maintained. It is **not** the same thing as
this `AUTHORING.md` (which is about building the plugin); the site documents the
plugin's *behaviour* for consumers.

- **Serve / build / check:** `mise run docs:serve`, `mise run docs:build`
  (strict), `mise run docs:check`. The Zensical toolchain lives in the `docs`
  dependency-group (`pyproject.toml`) — `serve`/`build` run via
  `uv run --group docs`, so the CI env stays light. `docs:check` is stdlib-only
  and runs inside `mise run ci`.
- **Mermaid** diagrams render via the `pymdownx.superfences` custom fence in
  `mkdocs.yml`; Zensical initializes `mermaid.js` natively, so no extra
  dependency is needed.
- **Reconcile with `/plugin-docs`** (repo-local skill) after changing skills,
  hooks, or rules: it refreshes the generated reference pages and can dispatch the
  `documentation-reviewer` agent. The `docs:check` gate (`validate_docs.py`) fails
  CI if a shipped skill is missing from `docs/reference/skills.md`, a nav entry is
  broken, a page is orphaned, or a link/`/steer:` ref doesn't resolve. The PR-only
  `check_docs_impact.py` gate fails when `skills/`, `rules/`, or `hooks/` change
  but no `docs/` file does.
- **New pages** start from the `docs-templates/` scaffolds and must be added to
  the `mkdocs.yml` nav (orphans fail the gate). The scaffolds (and this
  `AUTHORING.md`) live **outside** `docs/` on purpose: Zensical builds every file
  under `docs_dir` (it has no `exclude_docs` yet), so non-page content is kept out
  of the docs tree rather than excluded.

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

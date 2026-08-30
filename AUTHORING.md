# Authoring guide — e22-plugins

How to add or change a skill, rule, hook, or scaffold file in the `steer`
plugin without reverse-engineering the conventions. This consolidates what the
root [`CLAUDE.md`](CLAUDE.md), the check scripts under `scripts/`, and
[`plugins/steer/templates/reference/INVOCATION.md`](plugins/steer/templates/reference/INVOCATION.md)
already enforce — it does **not** introduce new policy.


> Repo-local helpers do the mechanical parts for you: `/new-skill`, `/new-rule`,
> and `/preflight` (defined under `.claude/skills/`, not shipped). Read the
> relevant section below to understand what they generate. At release time,
> `/audit-loop` drives the pre-release audit to convergence and `/release` /
> `/quick-release` cut the release.

## What I touched → what to run

Run `mise run check` before every commit and `mise run ci` before push/PR
regardless — this matrix is for tight iteration on a single failure.

| You edited… | Gate that covers it | Fast re-run |
| --- | --- | --- |
| `plugins/steer/skills/**` | `plugin-check` (incl. `check_agent_skills.py`) | `uv run python scripts/check_plugin.py && uv run python scripts/check_standards.py` |
| `plugins/steer/rules/**` | `plugin-check` (incl. `check_copilot_instructions.py`) | `uv run python scripts/check_plugin.py` |
| `rules/**`, `skills/**`, `agents/**`, `.mcp.json`, or `hooks/**` → stale **committed Copilot artifacts** | `plugin-check` (`check_copilot_*`, all in `mise run check`) | `mise run gen:copilot` — regenerates the whole non-Claude agent surface (instructions, the `.agents/skills/` tree, agents, `vscode/mcp.json`, `copilot-hooks.json`, manifest versions); commit the regenerated files with the source change |
| `plugins/steer/hooks/**` | `hooktests` + `shell` (+ `plugin-check`'s `check_copilot_hooks.py`) | `sh plugins/steer/hooks/tests/run.sh`; if you added/removed/retimed a *ported* hook, `mise run gen:copilot` regenerates `copilot-hooks.json` (ported subset declared in `gen_copilot_hooks.py`'s `COPILOT_HOOKS`) |
| `plugins/steer/.mcp.json` | `plugin-check` (`check_copilot_mcp.py`) | `mise run gen:copilot` — regenerates `templates/scaffold/vscode/mcp.json` from `.mcp.json` (auth mapping in `gen_copilot_mcp.py`'s `AUTH_INPUTS`); commit it. **Never hand-edit the mirror.** |
| `plugins/steer/templates/**` (scaffold, github, spec, reference) | `plugin-check` (+ `fixtures` if golden) | `uv run python scripts/check_standards.py` |
| `plugins/steer/templates/reference/MIGRATIONS.md` | `plugin-check` (`check_migrations.py` for entry structure + the `[Unreleased]` deep pass; `check_plugin.py`'s `check_migration_versions` for the version key) | `uv run python scripts/check_migrations.py` |
| `plugins/steer/scripts/**`, `hooks/lib/version-policy.sh` | `shell` + `version-scan` | `uv run python scripts/check_standards.py` (byte-identical copies) |
| any other `*.sh` — `scripts/*.sh`, `templates/scaffold/scripts/*.sh` | `shell` | `mise run shell` (shellcheck is a hard gate everywhere; shfmt is a hard gate outside `plugins/steer/hooks/`) |
| `scripts/*.py` (the validators themselves) | `lint` + `typecheck` + `test` | `uv run pytest && uv run ruff check . && uv run ty check scripts/` |
| `.github/workflows/**` | `actions` + `actions-security` | `actionlint && uv run zizmor --no-online-audits .github/workflows/` |
| `plugins/steer/templates/github/workflows/**` | `actions` (hard) + `actions-security` (**advisory** — reports, never fails; see [#492](https://github.com/element22llc/e22-plugins/issues/492)) | `mise run actions-security` |
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
| `description` | yes | Purpose + primary trigger, 1–2 sentences. Appended to `when_to_use` in the skill listing Claude Code uses for routing — keep it lean and put the key use case first (see the listing-cap note below). |
| `when_to_use` | yes | Additional trigger phrases / example requests, **appended to `description`** in the routing listing (a recognized field, not documentation-only). Restricted-grammar scalar (see gotcha below). |
| `argument-hint` | no | CLI arg syntax for multi-mode skills, e.g. `"[start \| resume \| status \| finish] [#issue ...]"`. |
| `allowed-tools` | no | Pre-approve idempotent ops so the skill doesn't prompt — see below. |
| `disallowed-tools` | no | Block mutation classes — used by read-only (Tier 1) skills. |
| `user-invocable` | no | `false` hides the skill from the slash menu (Tier 3 internal helpers). |
| `context` | no | `fork` runs the skill in a subagent instead of the main session — for a **pure renderer** only (see below). |

> `displayName` is **not** a skill field — it belongs in
> `plugins/steer/.claude-plugin/plugin.json` (the `/plugin` menu label). There is
> no `model:` field on any skill; do not add one.

> **Never `disable-model-invocation: true` on a steer skill.** The name reads
> like "keep it out of auto-routing", and the byte math is tempting — it drops a
> skill's description from the listing entirely, which is the one budget the
> ratchet says is nearly full. But the flag does more than that: it makes the
> skill **user-only**, so Claude cannot invoke it through the Skill tool *at
> all*. steer's entire premise is that the model is the router and the user never
> has to know a skill name (rule `00-router`, "map their plain-language goal to
> the owning skill and **invoke it yourself**") — so every skill named in that
> table, including the ones that look manual (`setup`, `protect`, `help`), is a
> model-invocation target and would silently stop being reachable. `standards` is
> worse still: it exists for the surfaces where no hook injects the rules, so its
> listing description is the *only* thing that tells the model to load it there.
> To reclaim listing budget, trim `description` + `when_to_use` at the source.

> **`context: fork` is for pure renderers.** A forked skill runs as a subagent:
> it gets the SKILL.md body as its prompt and **no access to the conversation
> that invoked it**, and the agent type supplies its system prompt. Its
> `allowed-tools` still applies — upstream's own `context: fork` example declares
> `agent:` and `allowed-tools:` together — so keep the grants a forked skill
> needs. A fork also runs in the **background** by default, which narrows it to
> the background-subagent tool set; set `background: false` to keep the full set
> if a step needs a tool outside it.
>
> Forking is right for a skill whose whole input is its argument and
> whose whole output is a rendered page — `/steer:status` and `/steer:explain`,
> which read a lot of spine to emit a little. It is wrong for a skill that reads
> the conversation (`/steer:report` files a bug about what just happened), and
> wrong for one that writes or orchestrates other skills (`/steer:roadmap` opens
> issues and drives `/steer:issues`). Don't add it to either class.

> **No `model:` or `effort:` on a skill — the router makes them leak.** Claude
> Code supports both as skill frontmatter, and the token math is tempting:
> `effort: low` on a mechanical instantiator like `spec-scaffold` or `standards`
> looks free. It is not, **for this plugin specifically**. Frontmatter effort
> "applies when that skill is active", overriding the session level, and steer's
> router is built to **auto-continue** — rule `00-router`: *"when a skill
> finishes, continue into its single best next action"*. So the override does not
> stay with the cheap skill:
>
> - `/steer:help` at `effort: low` → the router continues into `/steer:work`,
>   which now executes the implementation at low effort.
> - `spec-scaffold` is worse, because it is an **internal gateway invoked
>   mid-flow** by `build`, `init`, `intake`, and `spec` — a low-effort override
>   there downgrades the *calling* skill's remaining work in that turn.
>
> The user chose their model and effort; a navigation step must not silently
> re-set them for the work it navigates into. Same reasoning as `model:`. If a
> skill genuinely needs cheaper reasoning for a bounded piece of work, delegate
> that piece to a **subagent** instead — `agents/*.md` supports `model` and
> `effort`, and a subagent has its own context and cannot leak its override back
> into the parent turn (`steer-reviewer` is the worked example).

> **Listing cap.** Claude Code concatenates `description` + `when_to_use` into the
> skill listing it uses for routing and truncates the combined text at **1,536
> characters** (the documented `skillListingMaxDescChars` default); past the cap the
> trailing trigger text is silently dropped. `check_plugin.py` fails any skill whose
> combined length exceeds the cap. Keep the description to purpose + primary trigger
> and let `when_to_use` carry the extra trigger phrases — a paragraph-length
> description otherwise crowds out its own routing signal.

> **Body cap — the compaction trap.** An invoked skill's `SKILL.md` enters the
> conversation and stays there for the rest of the session. When auto-compaction
> fires, Claude Code re-attaches the most recent invocation of each skill but
> keeps only **the first 5,000 tokens of each** (re-attached skills also share a
> combined 25,000-token budget). Everything past that point is silently dropped
> mid-run — so an oversized `SKILL.md` is a *correctness* bug, not just a cost:
> the tail is where Guardrails and Coupling rules historically sat, and they
> vanish exactly when a run has gone long enough to compact. Two rules follow:
>
> 1. **Front-load the standing instructions.** Guardrails, coupling rules, and
>    output contracts go near the **top** of `SKILL.md`, never the bottom.
> 2. **Keep the body under 17,500 bytes** — the 5,000-token cap at a pessimistic
>    3.5 B/token. `check_context_budget.py` fails any skill over it. This is a
>    real ceiling derived from harness behaviour, **not** a ratchet: do not raise
>    it to fit new prose.
>
> The fix when a skill outgrows the cap is always the same — factor per-mode or
> per-phase procedure into a sibling file (next section), never trim a guardrail.

**Factoring a skill body — sibling procedure files.** A skill whose body would
exceed the cap keeps a slim `SKILL.md` (frontmatter, guardrails, coupling rules,
the standing contracts, and a **mode/phase map**) and moves the step-by-step
procedure into sibling Markdown under the skill directory, which the dispatcher
reads **just-in-time for the one path it is executing**. A file read that way is
a tool result, not skill content, so it never competes for the re-attach budget.

Naming in use: `modes/<mode>.md` for mode dispatch (`issues`, `audit`, `work`),
and a topic name for a single factored body (`PROCEDURE.md`, `OPERATIONS.md`,
`RECONCILE.md`, `SCAFFOLD.md`, `IMPLEMENTATION.md`, `HANDOFF.md`, `MODES.md`).
Rules:

- Link with the runtime-resolved
  `${CLAUDE_PLUGIN_ROOT}/skills/<skill>/<file>.md` form, and say **read only the
  one you need** so the dispatcher doesn't pull them all back in.
- Every declared mode must still appear in `SKILL.md` (the mode map satisfies
  `check_standards.py`'s bidirectional marker check).
- Sibling bodies are in scope for the same checks as `SKILL.md` — link
  resolution, token/enum membership, script grants, and workflow authority all
  scan the skill directory, not just `SKILL.md`.
- Never move a guardrail, an authorization gate, or an output contract into a
  sibling file. If it must hold for the whole run, it belongs in `SKILL.md`.

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

- **Tier 1 — read-only / reference** (`reference`, `audit`, `standards`, `next`,
  `doctor`, `explain`, `status`, `help`, `report`): never edit code/spec/tracker.
  What defines the tier is `disallowed-tools: Edit, NotebookEdit, EnterWorktree` —
  the skill cannot mutate an existing repo file, branch, or worktree. `Write`
  splits the tier: add it to `disallowed-tools` for a skill that writes nothing at
  all (`reference`, `standards`, `next`, `doctor`), and **keep it granted** for the
  five that write a temp-dir path (`audit`, `explain`, `help`, `status` for the
  artifact HTML; `report` for the scrubbed issue body). For four of the five that
  temp path is the *only* write; `/steer:audit` is the exception, with a second
  post-confirmation write its modes instruct (`/spec/AUDIT-REPORT.md` /
  `DRIFT-REPORT.md`). That limit is a **prose invariant**, not a frontmatter one. **Never** disallow `Write` on the theory that
  a mid-run confirmation lifts the restriction: tool grants apply for the whole
  invocation, so dropping it makes the instructed render unreachable rather than
  deferred (`/steer:reference artifacts`). Shell varies independently: `explain`
  also disallows `Bash` (it reads only local files); `status` keeps `Bash` because
  it reads the tracker through `/steer:tracker-sync` (the `gh` read fallback needs
  shell), but writes nothing back (no tracker-write grant; reads only).
- **Tier 2 — side-effecting** (`init`, `adopt`, `sync`, `build`, `work`, `spec`,
  `adr`, `issues`, `questions`, …): may create/edit/commit. Use `allowed-tools`
  to pre-approve the routine idempotent ops the skill always performs — e.g.
  `/steer:work` allowlists `Bash(git status *)`, `Bash(git switch *)`,
  `Bash(git add *)`, `Bash(git commit *)`, etc. **Pre-approve `git push` and
  `gh pr create` too** — rule `45-commit-autonomy` makes branch, commit, push and
  PR-open autonomous ("announce it, don't request permission"), and
  `check_standards.py` fails the build if the scaffold allowlist drops them. What
  stays gated is the **merge and the deploy** (`gh pr merge` sits under `ask`),
  never the push.
- **Tier 3 — hidden from the slash menu** (`user-invocable: false`): still
  model-callable, just not in the menu. Reserved for *internal gateways* a parent
  skill always drives with context a user can't supply by hand — `tracker-sync`
  (GitHub gateway, called with subcommands by `issues`/`work`, plus `spec`, `roadmap`,
  `questions`, `next`, `audit`/`status` reads, and `init`/`adopt` for
  `bootstrap-fields`) and `spec-scaffold`
  (template instantiator, called with a feature id by `spec`/`build`/`init`/`adopt`/`intake`).
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

### Write descriptions as triggers; capture gotchas

- **`description` + `when_to_use` are routing signal, not documentation.**
  Write them for the model deciding "should I fire?" — lead with the situation
  that should trigger the skill (concrete user requests, repo states), not a
  summary of what the skill does. Trigger-shaped phrasing routes better than a
  feature list.
- **Give substantive skills a `## Gotchas` section** — often the
  highest-signal part of a skill body: the specific ways the model has
  actually gone wrong in this flow (wrong default taken, step skipped, state
  misread) and the correction, stated imperatively. Add an entry when a real
  failure is observed — never pad it with restatements of the happy path.
  `/new-skill` scaffolds the section.

### Skill vs. mode — hold the line on surface area

The user-facing menu is the handful of **front doors** in `rules/00-router.md`'s
intent table (`setup`, `build`, `spec`, `intake`, `work`, `issues`, `audit`,
`adr`, `next`, `explain`, `help`, `protect`, `report` — re-derive from the table,
which is the source of truth). Every new skill widens the set of things a user must choose
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

### Previewing what a session actually gets

A rule may scope itself with a first-line `<!-- steer:inject-when=<token> -->`
marker, so the injected payload **differs per consumer repo** — and a
knowledge-work folder drops every marked rule. Since the injected-payload re-base the budget gate
measures this same payload (for two fixture profiles, `knowledge` and
`code-max`), so the gate and this preview finally report the same variable — but
the gate only ever sees those two synthetic shapes. To see what *your* repo gets:

```bash
mise run rules:preview                        # what this repo gets
mise run rules:preview -- --repo ../some-app  # what a consumer repo gets
mise run rules:preview -- --knowledge         # a non-code (PO) folder
mise run rules:preview -- --full              # also dump the injected text
```

It prints a per-rule inject/skip table with the scope token that decided each
one, the bytes reclaimed by the skips, and the payload total. Use it after
adding or re-scoping a rule to confirm the marker fires where you expect.

**Never copy an absolute byte/char total into prose** — not into a rule, a
skill, `CHANGELOG.md`, or the docs site. Any correctness fix to a rule or skill
moves these numbers, no gate compares prose against the live measurement, and
every figure quoted this way has gone stale within the same release cycle. Cite
the command instead (`uv run python scripts/check_context_budget.py --report`,
or `mise run rules:preview`), which cannot drift. Quoting a *ceiling* is fine —
those change only when deliberately ratcheted.

The preview runs the **real** `hooks/inject-standards.sh` for the bundle and the
**real** `lib/scope.sh` predicates for the table, so it cannot drift from live
behaviour. It is an authoring aid, not a gate — deliberately not in `check`/`ci`.

## Hook authoring

Hooks live under `plugins/steer/hooks/` and are wired in `hooks.json`.

- **POSIX `sh` only, no `jq`.** Reuse the helpers in `hooks/lib/*.sh`
  (`classify.sh`, `graduation.sh`, `json.sh`, `lifecycle.sh`, `repo-root.sh`,
  `report-fault.sh`, `scope.sh`, `spine.sh`, `version-policy.sh`,
  `worktree-lifecycle.sh`) rather than
  re-parsing.
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
  `plugins/steer/{skills,hooks,rules,templates,scripts,policy}/` plus all three
  version-bearing manifests as exact paths —
  `plugins/steer/.claude-plugin/plugin.json`,
  `plugins/steer/.github/plugin/plugin.json`, and
  `.github/plugin/marketplace.json` (which sits outside `plugins/steer/`, so no
  prefix reaches it). Anything matching `tests/` is
  exempt. Changes confined to `CLAUDE.md`, `docs/`, or `.claude/` are not
  behaviour files and need no entry.
- `check_changelog.py` also validates (always, no git needed) that `plugin.json`'s
  version equals the newest semver heading and that released headings descend in
  strict semver order.
- **Never write a next-version number anywhere in an implementation PR** — not in
  prose, not in a code comment, and above all not as a
  `templates/reference/MIGRATIONS.md` entry heading. Your PR merges *before* the
  release that names it, so the number is a guess, and for the ledger a wrong guess
  is a correctness bug rather than a typo: entries are keyed by the version that
  introduced them and `/steer:sync` **skips** every entry at or below a repo's
  `spec/.version` stamp, so an entry keyed *below* the release it actually ships in
  is silently skipped by every repo stamped in between — the migration never runs
  and nothing reports it. Author ledger entries as `### [Unreleased] — <what>`; the
  release PR renames the heading (step B3b) in the same commit that bumps the
  manifests. `check_plugin.py`'s `check_migration_versions` fails the build on any
  ledger heading ahead of `plugin.json`, so a guess cannot reach `main`. For a code
  comment, describe the *shape* ("a repo bootstrapped before that shape…") rather
  than keying it to a release at all.

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

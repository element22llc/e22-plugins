# Contributing

`e22-plugins` is **published read-only**. It is the source of truth for Element
22's engineering standards (the `steer` plugin) and the bundled repo scaffold,
mirrored here publicly so teams and partners can adopt the same SDLC. We do
**not** accept external pull requests, and active development happens internally.

You are welcome to **use** it under the [Apache-2.0 license](LICENSE):

```bash
/plugin marketplace add element22llc/e22-plugins
```

See the [documentation site](https://ai.element-22.com) and the repository
[`README.md`](README.md) for install and adoption guidance.

## Found a problem?

- **A security vulnerability** — follow [`SECURITY.md`](SECURITY.md); report it
  privately, not in a public issue.
- **A defect in the `steer` plugin** (a broken hook, a contradictory rule or
  skill, a missing or broken template/script) — open an issue using the
  **steer self-report** template on the
  [Issues tab](https://github.com/element22llc/e22-plugins/issues). From a Claude
  Code session that has the plugin installed, `/steer:report` will gather the
  defect, scrub it of secrets and local paths, and file it for you.

Bug reports and reproductions are appreciated; code contributions from outside
the organization are not merged.

---

# Working in this repo

For contributors with write access — human or agent. This is the **working
agreement**: branch, commit, changelog, gates, and what a single PR is allowed to
change. Read it before your first PR here; the mechanics of *building* plugin
internals live in [`AUTHORING.md`](AUTHORING.md).

## Which document owns what

Four documents, no overlap. When they disagree, the one that owns the subject
wins — and fixing the other is its own PR (see [Scope](#scope--one-pr-one-concern)).

| Document | Owns |
| --- | --- |
| `CONTRIBUTING.md` (this file) | How to work here: branch, commit, changelog, gates, PR scope, decision capture. |
| [`AUTHORING.md`](AUTHORING.md) | How to build plugin internals: skill frontmatter, rule numbering, hook rules, scaffold discipline, the "what I touched → what to run" matrix. |
| [`CLAUDE.md`](CLAUDE.md) | Repo orientation for an agent session: what this repo *is*, its layout, the condensed working loop. |
| [`docs/`](https://ai.element-22.com) | The plugin's behavior, for consumers. Auto-maintained — see `docs/contributing/documentation.md`. |

## Branches

Work on a branch off `main` and land via PR. `main` is protected; never commit or
push to it directly.

- `feat/<slug>` — new behavior. `fix/<slug>` — a bug fix. `docs/<slug>` — prose only.
- A Claude Code session on the web is handed a `claude/<slug>-<id>` branch by the
  harness. **Use it as-is** — don't rename it to `feat/*` to satisfy the
  convention above. Both are normal history here.
- One branch, one concern. If you notice unrelated work mid-branch, note it and
  open a second PR rather than widening this one.

## Commits

[Conventional Commits](https://www.conventionalcommits.org/) —
`type(scope): imperative summary`, no trailing period, under ~72 chars. This is
the org standard the plugin itself ships (`/steer:reference conventions`); the
scopes below are the vocabulary *this* repo uses.

```text
feat(steer): add /steer:tidy for sweeping stray root files
fix(hooks): stop injecting code rules into a knowledge-work folder
docs: correct the release-process diagram
chore(release): steer 3.22.0
```

- **Types** — `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `build`, `ci`,
  `chore`, `style`, `revert`. Mark a break with `!` and/or a `BREAKING CHANGE:`
  footer.
- **Scopes in use here** — `steer` (plugin behavior generally), `hooks`, `skills`,
  `rules`, `scaffold`, `docs`, `dx` (repo dev loop, gates, mise tasks),
  `release`. Omit the scope when the change is genuinely repo-wide.
- **Commits are not the changelog.** No commit-lint gate runs; the PR review is
  the gate, and history is freely rewritable before merge. `CHANGELOG.md` is
  curated by hand, never derived from commit types.

## CHANGELOG

Any change to plugin behavior — anything under
`plugins/steer/{skills,rules,hooks,templates,scripts,policy}/` or
`plugins/steer/.claude-plugin/plugin.json` — needs an entry. `tests/` is exempt,
and changes confined to `CLAUDE.md`, `docs/`, `.claude/`, or root Markdown ship
nothing and need none. `check_changelog.py --base` enforces this on every PR.

- Add **your own bullet** under `## steer` → `### [Unreleased]`. Don't edit a
  neighbor's bullet in the same PR.
- **Leave the `### [Unreleased]` heading alone** — never recreate it, never
  rename it outside a release. `CHANGELOG.md` is `merge=union` in
  `.gitattributes`, so concurrent PRs appending bullets under a *persistent*
  heading never conflict; recreating the heading duplicates it and breaks the
  gate.
- **Do not bump the version.** `plugin.json`'s `version` moves **once**, in the
  release PR that renames `[Unreleased]` to `X.Y.Z` — so a stream of PRs cuts one
  coherent release instead of a bump each. Details:
  [`AUTHORING.md`](AUTHORING.md) → "CHANGELOG & versioning" and
  `docs/contributing/release-process.md`.

Releases publish themselves: merging the version bump to `main` fires
`.github/workflows/release-publish.yml`, which cuts the tag and GitHub Release.
Repo-local `/release` and `/quick-release` drive the cut; repo-local
`/audit-loop` clears the way for them by running the pre-release audit
repeatedly — fixing findings and re-auditing until a round comes back clean — so
the release itself passes its own audit in one attempt. All three execute the
same audit procedure, single-sourced in `.claude/audit/PRE-RELEASE-AUDIT.md`.

## GitHub templates — two sets, don't confuse them

| Path | Audience | Changelog entry? |
| --- | --- | --- |
| `.github/` at the repo root | **This repo.** `pull_request_template.md`, `ISSUE_TEMPLATE/steer-self-report.yml`, `workflows/`, `dependabot.yml`. | No — ships nothing. |
| `.github/plugin/marketplace.json` | **Consumers.** The Copilot marketplace manifest; carries steer's released version. Sits under the root `.github/` but is not this repo's own. | **Yes** — plugin behavior. |
| `plugins/steer/templates/github/` | **Managed product repos** — installed by `/steer:init` / `/steer:adopt`. Issue Forms, `workflows/ci.yml`, `claude.yml`, the product PR template. | **Yes** — this is plugin behavior. |

`templates/github/` is the single source of truth for what consumer repos get —
never add a second copy under `templates/scaffold/`, and keep
`templates/scaffold/MANIFEST.md` in sync when you add a file there. Some
artifacts under `templates/github/` are **generated** (`copilot-instructions.md`,
`prompts/`, `agents/`) — regenerate with `mise run gen:copilot` and commit the
result; never hand-edit them.

## Gates

```bash
mise run check   # before every commit — strict superset of the pre-commit hooks
mise run ci      # before push / PR — exactly what CI runs
```

A green `check` is never followed by a rejected `git commit`; keep that superset
property when you add a hook. If the `docs-sync` pre-commit hook aborts a commit,
that's your cue to run `/plugin-docs`, re-stage `docs/`, and commit again — don't
skip the hook or commit around it. The repo-local `/preflight` helper runs the
gates and reports which one failed with its single re-run command; per-change
targets are in [`AUTHORING.md`](AUTHORING.md) → "What I touched → what to run".

## Scope — one PR, one concern

A PR delivers the change it says it delivers. It does **not** also adjust how the
repo works, because a convention that arrives as a side effect of a feature never
gets reviewed as a convention — it gets waved through with the feature and
becomes precedent.

**Frozen unless the PR's stated purpose *is* changing them:**

- `CLAUDE.md`, `AUTHORING.md`, `CONTRIBUTING.md`, `docs/contributing/`,
  `docs/decisions/` — the governance documents.
- The release flow: `CHANGELOG.md` structure, version-bump timing,
  `release-publish.yml`, the `/release` skills.
- The gates: `scripts/check_*.py`, `scripts/validate_docs.py`, `mise.toml` task
  wiring, pre-commit config.
- Repo-wide structure: a new top-level directory, a new artifact type, a new
  required file, a new naming scheme.

Touching one of these *in service of* your change is fine and expected — adding a
skill updates `docs/reference/skills.md`; adding a gate wires it into `check`.
What's out of bounds is **redefining the rule** while shipping something else.

**To change a convention**, open a PR that does only that. In the description:
state the rule as it stands today, why it's wrong, and the exact edit. No feature,
no ADR, no new directory riding along. If the proposal is rejected, nothing has to
be unpicked — and if it's accepted, the follow-up work has a rule to point at.

**Proposing before implementing** is the same idea one step earlier: a design
proposal belongs in an issue or the PR description, in prose. Don't land the
scaffolding for a decision that hasn't been made — a committed file reads as
settled even when its status line says "Proposed".

## Decisions about the plugin itself

**This repo keeps no ADR log.** Decisions about the plugin's own behavior are
recorded in `CHANGELOG.md` (what changed) and the PR (why, alternatives,
consequences) — that's the whole convention, and `docs/decisions/` documents ADRs
as an artifact of the `/spec` spine in *managed product repos*, not of this one.

A decision too large for a PR description is a signal to **split the PR**, not to
invent a record type. If you believe the plugin genuinely needs its own decision
log, that is a convention change: propose it on its own per the section above, and
don't write the first ADR until it's accepted.

<!--
This is e22-plugins' OWN pull-request template.

It is NOT the one shipped to managed product repos — that is
plugins/steer/templates/github/pull_request_template.md, a different file with a
different audience (spec sync, PO acceptance, drift gates). Editing that one
changes plugin behavior and needs a CHANGELOG entry; editing this one does not.

First PR here? Read CONTRIBUTING.md → "Working in this repo".
-->

## What & why

One or two sentences. Link the issue if there is one.

## Change class

Check every class this PR touches.

- [ ] **Plugin behavior** — `plugins/steer/{skills,rules,hooks,templates,scripts,policy}/` → needs a `CHANGELOG.md` entry
- [ ] **Repo tooling** — `scripts/`, `mise.toml`, `.github/workflows/`, `tests/`
- [ ] **Docs / repo prose** — `docs/`, `CLAUDE.md`, `.claude/`, root Markdown → ships nothing, no changelog entry
- [ ] **Convention change** — how this repo works (see Scope below)
- [ ] **Release cut** — the `plugin.json` version bump, nothing else

## Scope — one PR, one concern

- [ ] This PR does **not** change how the repo works — the conventions in `CLAUDE.md`, `AUTHORING.md`, `CONTRIBUTING.md`, `docs/contributing/`, `docs/decisions/`, the gate scripts, or the release flow — **or** that change *is* this PR's stated purpose and nothing else rides along with it.
- [ ] It introduces no new repo-wide convention, artifact type, or directory that isn't already documented (a new ADR log, a new template dir, a new required file). Propose those in the description and let a human decide **before** the diff exists — a convention landed as a side effect of a feature is a revert, not a review.

## Changelog

- [ ] Added my own bullet under `## steer` → `### [Unreleased]` (heading left intact — `merge=union` depends on it)
- [ ] `plugins/steer/.claude-plugin/plugin.json` version **untouched** (release PRs only)
- [ ] N/A — nothing under `plugins/steer/` changed

## Gates

```bash
mise run ci   # exactly what CI runs
```

- [ ] `mise run ci` green locally — or name the task that couldn't run here and why
- [ ] Ran `/plugin-docs` and committed the result, if `skills/`, `rules/`, or `hooks/` changed
- [ ] Ran `mise run gen:copilot` and committed the regenerated files, if `rules/`, `skills/`, `agents/`, `hooks/`, or `.mcp.json` changed

## Notes for the reviewer

Anything worth pushing back on — a judgment call, a trade-off, an alternative you
rejected.

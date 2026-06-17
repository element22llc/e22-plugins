---
name: plugin-docs
description: >-
  Reconcile the Zensical documentation site under docs/ with the plugin's source
  of truth — refresh the generated reference pages (skills, hooks, rules) from
  plugins/steer/, flag stale concept/workflow prose, run the docs validator, and
  optionally serve the site. Delegates deep accuracy review to the
  documentation-reviewer subagent. Repo-local dev helper for e22-plugins; does
  not ship.
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash(uv run python scripts/validate_docs.py)
  - Bash(uv run python scripts/check_docs_impact.py*)
  - Bash(mise run docs:*)
---

# /plugin-docs — keep the docs site in sync with the plugin

The documentation site (`docs/`, served via `mise run docs:serve`) must track the
plugin's source of truth: the skills in `plugins/steer/skills/`, hooks in
`plugins/steer/hooks/hooks.json`, and rules in `plugins/steer/rules/`. This skill
reconciles the **generated** reference pages, flags **stale prose**, and runs the
**validator**. It edits only `docs/` (and never bumps `plugin.json` — docs ship
nothing).

## Steps

1. **Survey the source of truth.**
   - Skills: `ls plugins/steer/skills/` and read each `SKILL.md` frontmatter
     (`name`, `description`, `when_to_use`, `argument-hint`, `user-invocable`,
     `disallowed-tools`).
   - Hooks: read `plugins/steer/hooks/hooks.json` (events, matchers, scripts).
   - Rules: the numeric-prefixed files in `plugins/steer/rules/` (first heading).

2. **Reconcile the generated reference pages** so they match disk exactly:
   - `docs/reference/skills.md` — every skill present as `/steer:<skill>`;
     internal skills (`user-invocable: false`) listed under the internal section;
     read-only skills noted as such.
   - `docs/reference/hooks.md` — one row per hook, correct event + matcher.
   - `docs/reference/configuration.md` — the rule table matches the files on disk.
   Make the **minimal** edits needed; preserve hand-written prose and diagrams.

3. **Flag stale concept/workflow prose.** For `docs/concepts/*` and
   `docs/workflows/*`, check claims against the current skills/rules. Propose
   edits for anything that contradicts the source of truth (e.g. a renamed mode,
   a changed argument-hint, a dropped lifecycle state). Do not invent content.

4. **(Optional) Deep review.** For a thorough accuracy pass, dispatch the
   `documentation-reviewer` subagent (read-only) and fold its findings into the
   proposed edits.

5. **Validate.** Run `mise run docs:check` (or
   `uv run python scripts/validate_docs.py`) and resolve every finding. If asked
   to preview, run `mise run docs:serve`; for a strict link/render check run
   `mise run docs:build`.

6. **Report** what changed and what (if anything) still needs a human decision
   (e.g. a new skill that needs its own workflow page written from
   `docs-templates/workflow.md`).

## Boundaries

- **Docs only.** Edit under `docs/` (and, when adding a page, `mkdocs.yml` nav).
  Never edit `plugins/steer/**` from this skill — if the docs and the plugin
  disagree, the plugin is the source of truth.
- **No changelog, no version bump.** `docs/` and `.claude/` ship nothing.
- **Grounded.** Every documented claim must trace to a `SKILL.md`, `hooks.json`,
  rule, or template. When unsure, leave a `TODO` and surface it rather than guess.
- New pages start from `docs-templates/` (outside `docs/`, since Zensical builds
  every file under `docs_dir`) and must be added to the `mkdocs.yml` nav (the
  validator fails on orphans).

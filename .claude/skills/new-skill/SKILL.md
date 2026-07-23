---
name: new-skill
description: >-
  Scaffold a new steer plugin skill with correct frontmatter for its
  invocation tier, plus a CHANGELOG [Unreleased] stub. Repo-local dev helper
  for e22-plugins; does not ship. Use when adding a skill under
  plugins/steer/skills/.
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Bash(uv run python scripts/check_plugin.py)
  - Bash(uv run python scripts/check_standards.py)
  - Bash(mise run plugin-check)
---

# /new-skill — scaffold a steer skill

A repo-local convenience wrapper. It does not bypass any validation — it
generates a correct starting point and then runs the existing `plugin-check`.
See `AUTHORING.md` → "Skill frontmatter schema" for the full rules.

## Steps

0. **Could this be a mode or a hidden delegate instead?** (See `AUTHORING.md` →
   "Skill vs. mode".) Every new *visible* skill widens the menu, so ask first:
   - Does an existing skill already own this area? → prefer a **mode** on it
     (`argument-hint` + `<!-- steer:modes … -->`), not a new skill.
   - Is it only ever reached as a step of another skill? → make it a **hidden
     delegate** (`user-invocable: false`) and add the hand-off to its parent.
   - Is the choice really repo-state, not user intent? → fold it behind a
     **dispatcher** (e.g. `/steer:setup`).
   Only continue scaffolding a new front door if none of these fit. If the new
   skill is hidden, also add a routing line to `plugins/steer/rules/00-router.md`.

1. **Gather inputs** (ask the user, or take them from the invocation):
   - `name` — kebab-case, no `/steer:` prefix. Must not already exist under
     `plugins/steer/skills/`.
   - `description` — one prose sentence, written as a **trigger** (the
     situation that should fire the skill), not a feature summary — see
     `AUTHORING.md` → "Write descriptions as triggers".
   - `when_to_use` — when to invoke (use a folded `>-` block if it contains
     quotes or colons; see the quoting gotcha in `AUTHORING.md`).
   - **tier** — one of:
     - `read-only` (Tier 1): add `disallowed-tools: Edit, Write, NotebookEdit, EnterWorktree`.
     - `side-effecting` (Tier 2): may edit/commit; add `allowed-tools` for the
       routine idempotent ops it always runs (keep `git push`/PR gated).
     - `internal` (Tier 3): add `user-invocable: false`.

2. **Verify the name is free:** `Glob plugins/steer/skills/*/SKILL.md` and
   confirm no directory already matches `name`.

3. **Create `plugins/steer/skills/<name>/SKILL.md`** with frontmatter built from
   the inputs (always `name`, `description`, `when_to_use`; tier-specific tool
   fields as above) and a short imperative body skeleton (`# /steer:<name>` title,
   a one-line purpose, a `## Steps` placeholder, and a `## Gotchas` section
   seeded with `- None observed yet.` — filled in as real failures are seen,
   per `AUTHORING.md` → "capture gotchas"). Do **not** leave literal
   `TODO`/`FIXME`/`[Replace` tokens — `check_plugin.py` rejects them in skills.

4. **Add a CHANGELOG stub:** under `## steer` → `### [Unreleased]` in
   `CHANGELOG.md`, add a bullet like `- Add /steer:<name> skill (<one-line>).`
   Create the `### [Unreleased]` heading if absent (above the newest version).

5. **Validate and report:** run `mise run plugin-check` (or
   `uv run python scripts/check_plugin.py && uv run python scripts/check_standards.py`).
   Report pass/fail and remind the user to fill in the skill body and run
   `mise run check` before committing.

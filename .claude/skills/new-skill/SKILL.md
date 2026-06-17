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

1. **Gather inputs** (ask the user, or take them from the invocation):
   - `name` — kebab-case, no `/steer:` prefix. Must not already exist under
     `plugins/steer/skills/`.
   - `description` — one prose sentence.
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
   a one-line purpose, a `## Steps` placeholder). Do **not** leave literal
   `TODO`/`FIXME`/`[Replace` tokens — `check_plugin.py` rejects them in skills.

4. **Add a CHANGELOG stub:** under `## steer` → `### [Unreleased]` in
   `CHANGELOG.md`, add a bullet like `- Add /steer:<name> skill (<one-line>).`
   Create the `### [Unreleased]` heading if absent (above the newest version).

5. **Validate and report:** run `mise run plugin-check` (or
   `uv run python scripts/check_plugin.py && uv run python scripts/check_standards.py`).
   Report pass/fail and remind the user to fill in the skill body and run
   `mise run check` before committing.

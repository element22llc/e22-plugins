---
name: release
description: >-
  Cut a steer plugin release — pick the semver bump from the accumulated
  CHANGELOG [Unreleased] entries, rename that heading to the new version, bump
  plugins/steer/.claude-plugin/plugin.json to match, run the full gate, and open
  the release PR. Repo-local dev helper for e22-plugins; does not ship.
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Bash(git status*)
  - Bash(git diff*)
  - Bash(git branch*)
  - Bash(git log*)
  - Bash(git fetch*)
  - Bash(uv run python scripts/check_changelog.py)
  - Bash(mise run ci)
  - Bash(mise run check)
---

# /release — cut a steer plugin release

A repo-local convenience wrapper around the documented release flow (see
`CLAUDE.md` → "Working in this repo" and `AUTHORING.md` → version policy). It
adds **no** new validation — it drives the existing one. The version bump
happens **once**, here, in a dedicated release PR; implementation PRs only
accumulate `### [Unreleased]` entries.

The invariant `check_changelog.py` enforces (and this skill upholds): the
`version` in `plugin.json` equals the newest *released* `### X.Y.Z` heading
under `## steer`, and released headings descend in strict semver order.

## Steps

1. **Pre-flight — refuse to start on a dirty or stale base.**
   - `git status --porcelain` must be empty (no uncommitted changes). If not,
     stop and tell the user to commit or stash first.
   - `git fetch origin main` then confirm the local base is not behind
     `origin/main`. A release should be cut from current `main`.
   - Confirm `CHANGELOG.md` has a `### [Unreleased]` section under `## steer`
     **with at least one bullet**. If it is missing or empty, there is nothing
     to release — stop and say so.

2. **Determine the new version.** Read the current `version` from
   `plugins/steer/.claude-plugin/plugin.json` and the `### [Unreleased]` bullets.
   Propose the bump from the **nature** of those entries, then confirm with the
   user before editing:
   - **major** — a breaking change to plugin behavior (renamed/removed skill,
     rule, hook, or template; changed invocation; anything a consuming repo must
     react to).
   - **minor** — new backward-compatible capability (new skill, rule, scaffold
     file, or option).
   - **patch** — fixes, wording, and internal changes only.

   When entries are mixed, the highest-impact one wins. State the proposed
   `X.Y.Z` and the one reason, and let the user override.

3. **Create the release branch:** `git checkout -b chore/release-X.Y.Z` off the
   up-to-date `main`.

4. **Rename the changelog heading.** In `CHANGELOG.md`, change the single line
   `### [Unreleased]` to `### X.Y.Z` (released headings carry no date in this
   repo — match the existing format). Keep all the bullets in place. Do **not**
   leave an empty `[Unreleased]` behind; the next implementation PR re-creates it.

5. **Bump `plugin.json`:** set `"version": "X.Y.Z"` in
   `plugins/steer/.claude-plugin/plugin.json` to match the new heading exactly.

6. **Validate the release invariant:** `uv run python scripts/check_changelog.py`
   (no `--base`, so it runs the release validator only). It must report clean —
   version equals the newest heading and headings descend. Fix any mismatch
   before continuing.

7. **Run the full gate:** `mise run ci`. This is what CI runs; a release PR must
   be green before it goes up. Report a per-gate result; do not proceed past a
   red gate.

8. **Commit, push, open the PR** (these steps are intentionally **not**
   pre-authorized — they prompt, preserving the human gate on outbound actions):
   - Commit the two files with a message like
     `chore(release): steer X.Y.Z`.
   - Push the branch and open a PR titled `Release steer X.Y.Z`, with a body
     that pastes the now-released changelog bullets so reviewers see the scope.

9. **Report.** State the new version, the branch, the PR URL, and the gate
   result. Note the two post-merge follow-ups the user owns (this skill does not
   do them): consumers pick up the release via `/plugin update`, and — if the
   user tags releases — create the `vX.Y.Z` tag / GitHub release on the merged
   commit.

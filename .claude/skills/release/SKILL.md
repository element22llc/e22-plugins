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
  - Bash(git worktree*)
  - Bash(grep*)
  - Bash(mise trust*)
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

3. **Isolate, *then* branch — set up the working copy before editing any file.**
   This skill edits tracked files, so the checkout must be isolated first;
   editing the shared checkout in a background session is rejected by the
   isolation guard. Do this **before** the first `Edit`, never after a rejection.
   - **Background / isolated session** (or any time an edit to the shared
     checkout is refused): create a worktree with the **EnterWorktree** tool.
     Its name cannot contain `/`, so it lands on a branch like
     `worktree-release-x-y-z`; rename it to the convention right away with
     `git branch -m chore/release-X.Y.Z`.
   - **Interactive session in a clean checkout:** `git checkout -b
     chore/release-X.Y.Z` off the up-to-date `main` is enough.
   - Either way, all later edits, the gate, and the PR run from this isolated
     branch — never the shared checkout.

4. **Rename the changelog heading.** In `CHANGELOG.md`, change the single
   heading line `### [Unreleased]` to `### X.Y.Z` (released headings carry no
   date in this repo — match the existing format). Keep all the bullets in
   place. Do **not** leave an empty `[Unreleased]` behind; the next
   implementation PR re-creates it.
   - **`### [Unreleased]` is not unique in this file** — it also appears as
     prose inside the changelog's own house-rules bullet much further down. Run
     `grep -n '### \[Unreleased\]' CHANGELOG.md` first and edit only the heading
     with the **lowest line number** (the one just under `## steer`), anchoring
     the match on enough surrounding context (the blank line + first bullet)
     that it is unambiguous.
   - **If you just entered a worktree, `Read` both `CHANGELOG.md` and
     `plugin.json` at their worktree paths before editing.** `Edit` requires a
     prior `Read` of that exact path, and switching into a fresh worktree resets
     that state.

5. **Bump every manifest version to `X.Y.Z`** — the plugin ships to two
   marketplaces, so three files carry the version and must match the new heading
   exactly (`check_plugin.py`'s version-sync gate fails the build if any drifts):
   - `plugins/steer/.claude-plugin/plugin.json` (`version`) — the source of truth.
   - `plugins/steer/.github/plugin/plugin.json` (`version`) — Copilot plugin manifest.
   - `.github/plugin/marketplace.json` — the `steer` plugin entry's `version`
     (leave `metadata.version`, the marketplace's own version, alone).

6. **Validate the release invariant:** `uv run python scripts/check_changelog.py`
   (no `--base`, so it runs the release validator only). It must report clean —
   version equals the newest heading and headings descend. Fix any mismatch
   before continuing.

7. **Run the full gate:** `mise run ci`. This is what CI runs; a release PR must
   be green before it goes up.
   - A **fresh worktree is an untrusted mise path**, so the first `mise` command
     aborts asking you to trust it. Run `mise trust` once in the worktree before
     the gate.
   - Report a per-gate result; do not proceed past a red gate.

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

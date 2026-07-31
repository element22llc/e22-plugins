---
name: release
description: >-
  Cut a steer plugin release — first run a deep, read-only pre-release audit of
  the plugin codebase (deterministic gate + strict docs build + judgment-based
  coherence review + deployed-docs freshness) and BLOCK on any release-stopping
  finding; then pick the semver bump from the accumulated CHANGELOG [Unreleased]
  entries, rename that heading to the new version, bump every manifest, re-gate,
  and open the release PR. Repo-local dev helper for e22-plugins; does not ship.
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Task
  - WebFetch
  - Bash(git status*)
  - Bash(git diff*)
  - Bash(git branch*)
  - Bash(git log*)
  - Bash(git fetch*)
  - Bash(git tag*)
  - Bash(git rev-list*)
  - Bash(git describe*)
  - Bash(git worktree*)
  - Bash(grep*)
  - Bash(gh run list*)
  - Bash(gh run view*)
  - Bash(gh api*)
  - Bash(mise trust*)
  - Bash(uv run python scripts/check_changelog.py*)
  - Bash(uv run python scripts/check_plugin.py*)
  - Bash(uv run python scripts/check_standards.py*)
  - Bash(uv run python scripts/validate_docs.py*)
  - Bash(sh plugins/steer/scripts/scan-version-pins.sh*)
  - Bash(sh plugins/steer/scripts/check-policy-freshness.sh*)
  - Bash(mise run ci)
  - Bash(mise run check)
  - Bash(mise run docs:build*)
---

# /release — cut a steer plugin release

A repo-local wrapper around the documented release flow (see `CLAUDE.md` →
"Working in this repo" and `AUTHORING.md` → version policy). It runs in two
phases:

- **Phase A — deep pre-release audit (read-only).** Before touching a single
  file, prove the codebase is coherent and release-ready: run the full
  deterministic gate *and* the strict docs build, fan out a judgment-based
  coherence review, confirm the docs are genuinely current, and verify the
  **deployed** docs site is not stale. This phase is a **gate** — any
  blocker-severity finding stops the release before the version is bumped.
- **Phase B — cut the release.** Only once Phase A is clean: pick the semver
  bump, rename the changelog heading, bump every manifest, re-gate, and open the
  release PR. The version bump happens **once**, here, in a dedicated release PR;
  implementation PRs only accumulate `### [Unreleased]` entries.

The invariant `check_changelog.py` enforces (and this skill upholds): the
`version` in `plugin.json` equals the newest *released* `### X.Y.Z` heading under
`## steer`, and released headings descend in strict semver order.

This skill is read-only until Step B1. Phase A only reads, runs gates, and
dispatches read-only subagents — it never edits, branches, or commits. That is
deliberate: the audit must reflect the exact tree a reviewer will see, and a
release that can't pass its own audit shouldn't have a branch at all.

---

## Phase A — deep pre-release audit (read-only gate)

**The audit procedure is single-sourced in
[`.claude/audit/PRE-RELEASE-AUDIT.md`](../../audit/PRE-RELEASE-AUDIT.md).** Open
it and execute **Steps 1–5 in full** — every dimension, no subset (that subset is
`/quick-release`'s job). If that file and the index below ever disagree, the
procedure file is authoritative.

As the `/release` caller, you supply these pre/post-conditions around it:

- **Base contract (procedure Step 1).** The base must be current `main` — clean
  tree, not behind `origin/main` — and `### [Unreleased]` must carry **at least
  one bullet**, or there is nothing to release.
- **Bump input (procedure Step 3, dimension 1).** Carry forward the subagent's
  note on whether the highest-impact bullet implies a larger bump than a naive
  reading — it is input to Step B1.
- **Timing note (procedure Step 4b).** State honestly that *this release's own*
  docs changes deploy only after this PR merges; Phase A proves the docs source
  is current and that *prior* docs changes are live. The post-merge deploy is a
  Phase-B follow-up the user owns (Step B9).

The one-line index, for orientation only:

- **Step 1 — base preconditions.** Clean tree, not behind `origin/main`,
  `[Unreleased]` populated, `$LAST_RELEASE` established as the diff anchor.
- **Step 2 — deterministic gate.** `mise run ci` + the strict `mise run
  docs:build`, up front and blocking.
- **Step 3 — judgment coherence fan-out.** Six read-only subagent dimensions
  (CHANGELOG ↔ diff, version/manifest, cross-reference, namespace/brand, payload,
  behavioral), then vet every candidate against the code it cites.
- **Step 4 — docs accuracy + deployed-site freshness.** `documentation-reviewer`
  deep review, plus the `docs-deploy.yml` run-status freshness check.
- **Step 5 — compile, rank, classify.** Severity (`[blocker]` … `[low]`) and
  disposition (`fixable-in-tree` / `out-of-tree`) on every finding.

### A6. Audit gate — decide.

- **If any `[blocker]` exists, STOP.** Do not branch, do not bump. Report the
  blockers and the fix each needs, and tell the user to resolve them and re-run
  `/release`. When several blockers are fixable in-tree, **point them at
  `/audit-loop`** — it fixes and re-audits until a round comes back clean, which
  is what turns a five-attempt release into a one-attempt one.
- **`[high]` / `[medium]` / `[low]`** do not by themselves halt the release.
  Surface them so the user can decide to fold a quick fix in or ship and file the
  rest.

Only when there are **zero blockers** proceed to Phase B.

---

## Phase B — cut the release

### B1. Determine the new version.

Read the current `version` from `plugins/steer/.claude-plugin/plugin.json` and
the `### [Unreleased]` bullets (and the implied-bump note carried out of the
audit's Step 3 dimension 1). Propose
the bump from the **nature** of those entries, then confirm with the user before
editing:

- **major** — a breaking change to plugin behavior (renamed/removed skill, rule,
  hook, or template; changed invocation; anything a consuming repo must react to).
- **minor** — new backward-compatible capability (new skill, rule, scaffold file,
  or option).
- **patch** — fixes, wording, and internal changes only.

When entries are mixed, the highest-impact one wins. State the proposed `X.Y.Z`
and the one reason, and let the user override.

### B2. Isolate, *then* branch — set up the working copy before editing any file.

This skill now edits tracked files, so the checkout must be isolated first;
editing the shared checkout in a background session is rejected by the isolation
guard. Do this **before** the first `Edit`, never after a rejection.

- **Background / isolated session** (or any time an edit to the shared checkout
  is refused): create a worktree with the **EnterWorktree** tool. Its name cannot
  contain `/`, so it lands on a branch like `worktree-release-x-y-z`; rename it to
  the convention right away with `git branch -m chore/release-X.Y.Z`.
- **Interactive session in a clean checkout:** `git checkout -b
  chore/release-X.Y.Z` off the up-to-date `main` is enough.
- Either way, all later edits, the gate, and the PR run from this isolated branch.
- **If you just entered a worktree, `Read` `CHANGELOG.md` and all three manifest
  files at their worktree paths before editing** — `Edit` requires a prior `Read`
  of that exact path, and switching into a fresh worktree resets that state.

### B3. Rename the changelog heading, then re-seed an empty `[Unreleased]`.

In `CHANGELOG.md`, change the single heading line `### [Unreleased]` to
`### X.Y.Z` (released headings carry no date in this repo — match the existing
format), keeping all the bullets in place. Then add a fresh, empty
`### [Unreleased]` heading back at the top of `## steer`, immediately above the
new `### X.Y.Z`. **The `[Unreleased]` heading must always exist** — it is what
lets `CHANGELOG.md merge=union` (see `.gitattributes`) resolve concurrent entry
additions without conflicts: PRs add bullets *under* a heading that is already
present, so union never has to recreate (and thereby duplicate) it.
`check_changelog.py` fails the build if the heading is missing, duplicated, or
not first.

- **`### [Unreleased]` is not unique in this file** — it also appears as prose
  inside the changelog's own house-rules bullet much further down. Run `grep -n
  '### \[Unreleased\]' CHANGELOG.md` first and edit only the heading with the
  **lowest line number** (the one just under `## steer`), anchoring the match on
  enough surrounding context (the blank line + first bullet) that it is
  unambiguous.

### B3b. Rename the migration-ledger heading, if there is one.

`plugins/steer/templates/reference/MIGRATIONS.md` keys each entry by the plugin
version that **introduced** it, and `/steer:sync` skips every entry at or below a
repo's `spec/.version` stamp. Implementation PRs cannot know that version, so they
author entries as `### [Unreleased] — <what>` (the same convention `CHANGELOG.md`
uses). This is where the version becomes real:

```sh
grep -n '^### \[Unreleased\]' plugins/steer/templates/reference/MIGRATIONS.md
```

Rename each match **inside `## Entries`** to `### vX.Y.Z — <the same what>`, keeping
the body untouched. **`### [Unreleased]` is not unique in this file** — the authoring
stub inside the trailing `<!-- Template for a new entry -->` HTML comment carries the
same heading at column 0, so it matches the grep. **Never rename that one**: stamping a
version onto the stub reinstates the guessed-version pattern this convention exists to
eliminate, and no gate catches it (`check_migration_versions` errors only on a key
*ahead* of `plugin.json`, so a stub keyed to the release you just cut passes silently).
Confirm each hit's line number is above the comment block before editing it.
Usually there are none (most releases carry no non-additive transform) — that is
a normal, silent no-op, not a missing step. Unlike `CHANGELOG.md`, do **not**
re-seed an empty `[Unreleased]` heading here: the ledger's `## Entries` list has no
union-merge requirement, and an empty version heading would read as a real entry.

**Why this matters more than a cosmetic heading:** a ledger entry keyed *below*
the version it actually shipped in is read as "at or below the stamp" by every
repo stamped in between, so the migration is **silently skipped** — it never runs
and nothing reports it. `check_plugin.py`'s `check_migration_versions` fails the
build on any heading ahead of `plugin.json`, which catches the guess at authoring
time; this step is what stops the entry shipping as a permanent `[Unreleased]`.

### B4. Bump every manifest version to `X.Y.Z`.

The plugin ships to two marketplaces, so three files carry the version and must
match the new heading exactly (`check_plugin.py`'s version-sync gate fails the
build if any drifts):

- `plugins/steer/.claude-plugin/plugin.json` (`version`) — the source of truth.
- `plugins/steer/.github/plugin/plugin.json` (`version`) — Copilot plugin manifest.
- `.github/plugin/marketplace.json` — the `steer` plugin entry's `version` (leave
  `metadata.version`, the marketplace's own version, alone).

### B5. Validate the release invariant.

`uv run python scripts/check_changelog.py` (no `--base`, so it runs the release
validator only). It must report clean — version equals the newest heading and
headings descend. Fix any mismatch before continuing.

### B6. Re-gate after the bump.

Phase A's `mise run ci` ran on the **pre-bump** tree. The only files Phase B
changed are `CHANGELOG.md` and the three manifests, and those are exactly what
the version-sync and changelog gates police — so re-run **`mise run check`**
(lint + plugin-check + standards + `claude plugin validate` + the changelog
validator) to prove the edits didn't regress those gates. Report a per-gate
result; do not proceed past a red gate.

- A **fresh worktree is an untrusted mise path**, so the first `mise` command
  aborts asking you to trust it. Run `mise trust` once in the worktree before the
  gate.
- (The heavier suites — fixtures/test/shell/hooktests/docs build — already passed
  in Phase A on a tree the version edits don't touch; re-running the full `ci` is
  optional. If in any doubt, run `mise run ci`.)

### B7. Commit, push, open the PR.

These steps are intentionally **not** pre-authorized — they prompt, preserving
the human gate on outbound actions:

- Commit the four files with a message like `chore(release): steer X.Y.Z`.
- Push the branch and open a PR titled `Release steer X.Y.Z`, with a body that:
  pastes the now-released changelog bullets so reviewers see the scope, **and**
  summarizes the Phase-A audit result (gates green; coherence/doc dimensions
  clean or the non-blocking `[high]/[medium]/[low]` findings the user chose to
  defer) so the reviewer inherits the audit, not just the diff, **and** appends
  the always-on context-budget table from
  `uv run python scripts/check_context_budget.py --report` so context weight
  can't silently regress across releases (PLAN.md Phase 4).

### B8. Report.

State the new version, the branch, the PR URL, the Phase-A audit verdict, and the
re-gate result.

### B9. Post-merge follow-ups the user owns (this skill does not do them).

- Consumers pick up the release via `/plugin update`.
- The **docs deploy** for this release's `docs/**` changes runs from `main` after
  merge (`docs-deploy.yml`) — watch that run go green so the live site at
  `https://ai.element-22.com` actually reflects the release; a red deploy leaves
  the published docs stale (and Phase A's next run will flag it).
- The **e2e suite** no longer runs in CI (the workflow was removed to save cost);
  it is a local-only tier now — run `mise run e2e` / `e2e:local` before a
  substantive cut if you want the skill-level signal.
- The **`vX.Y.Z` git tag + GitHub Release** are created automatically by
  `release-publish.yml`, which fires on the same merge commit (gated on the
  `plugin.json` version bump) and cuts the Release with this version's CHANGELOG
  bullets as the body. Confirm that run went green. This is what keeps the audit's
  `$LAST_RELEASE` diff anchor (`git describe --tags`) accurate for the next cut —
  so it is no longer a manual step. If the workflow is unavailable, re-publish by
  hand with `gh workflow run release-publish.yml -f version=X.Y.Z`, or, as a last
  resort, `gh release create vX.Y.Z --target <merge-sha> --title "steer X.Y.Z"
  --generate-notes --notes-file <(python3 scripts/changelog_release_notes.py notes
  X.Y.Z)` (curated bullets + GitHub's auto "What's Changed").

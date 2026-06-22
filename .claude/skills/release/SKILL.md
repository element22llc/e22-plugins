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

### A1. Pre-flight — refuse to start on a dirty or stale base.

- `git status --porcelain` must be empty (no uncommitted changes). If not, stop
  and tell the user to commit or stash first.
- `git fetch origin main`, then confirm the local base is **not behind**
  `origin/main`. A release is cut from current `main`; auditing a stale tree
  would audit the wrong thing.
- Confirm `CHANGELOG.md` has a `### [Unreleased]` section under `## steer` **with
  at least one bullet**. If it is missing or empty, there is nothing to release —
  stop and say so.
- Establish the **last-release ref** for the diff-based checks below: the newest
  `### X.Y.Z` heading in `CHANGELOG.md` is the last released version; find its
  commit via the `vX.Y.Z` git tag if one exists (`git describe --tags --match
  'v*' --abbrev=0`), else the most recent commit whose subject starts
  `chore(release):`. Call it `$LAST_RELEASE`. If neither exists, fall back to the
  start of history and say so (the coherence pass just reviews more).

### A2. Deterministic gate — run the machine checks first, and run them *up front*.

Blocking, mechanical problems must surface before any human-judgment review, and
before the version bump — not at the end where a red gate wastes the bump work.

- **`mise run ci`** — the full CI-equivalent gate (lint, plugin-check, fixtures,
  test, shell, hooktests, version-scan, docs:check, delivery-gates). Report a
  per-gate pass/fail line.
- **`mise run docs:build`** — the **strict** Zensical build (fails on broken
  links / nav). This is **not** part of `mise run ci`; it normally runs only in
  the `docs-deploy.yml` build job. Run it here because the Cloudflare deploy
  happens **post-merge from `main`**: if the strict build is red, the merge will
  publish a broken or stale site. Catching it now is the difference between a
  clean release and a silently-broken live doc.
  - This pulls the `docs` dependency-group on demand (`uv run --group docs`); it
    is heavier than the rest. If the toolchain genuinely can't be provisioned in
    this environment, do not skip silently — report it as **`[blocker] strict
    docs build not verified`** so the user runs `mise run docs:build` themselves
    before merging.

Do not proceed past a red gate. A failing deterministic check is a blocker by
definition — fix it (on its own fix PR, accumulating a `### [Unreleased]` entry)
and re-run `/release`.

### A3. Judgment-based coherence audit — fan out, then vet.

Deterministic checks prove *structure*; they cannot judge *coherence* — a skill
whose description no longer matches its body, a `[Unreleased]` bullet that
overstates a change, a rule that contradicts a skill. Dispatch **read-only**
review subagents (the `Task` tool, `subagent_type: general-purpose`), **one per
dimension, in parallel**. Each subagent is told: *read-only; every finding must
carry `path:line` evidence and a one-line statement of the incoherence; default
to silence over speculation.* The dimensions:

1. **CHANGELOG ↔ change coherence (both directions).** Diff
   `git diff $LAST_RELEASE..HEAD -- plugins/steer/` and the `### [Unreleased]`
   bullets. Flag (a) any bullet with no corresponding change in the diff
   (overstated/phantom entry), and (b) any behavior-affecting change under
   `plugins/steer/` with **no** bullet (`check_changelog.py --base` enforces this
   per-PR, but the *accumulated* set can still have gaps). Note whether the
   highest-impact bullet implies a larger bump than a naive reading — input to
   Step B1.
2. **Version & manifest coherence.** The three version-bearing manifests
   (`plugins/steer/.claude-plugin/plugin.json`,
   `plugins/steer/.github/plugin/plugin.json`,
   `.github/plugin/marketplace.json` steer entry) must currently all equal the
   newest **released** heading. Any pre-existing drift between them, or against
   version pins in `plugins/steer/policy/versions.yml` and the scaffold copy at
   `plugins/steer/templates/scaffold/policy/versions.yml`, is a finding. Run
   `sh plugins/steer/scripts/scan-version-pins.sh .` and
   `sh plugins/steer/scripts/check-policy-freshness.sh` and fold their output in.
3. **Cross-reference & inventory integrity.** Every `/steer:<skill>` reference
   resolves to a real skill; the hand-maintained enumerations (CLAUDE.md skills
   block, README inventory, the `standards` skill's rule list, CROSS-SURFACE.md
   rule count + SessionStart hook roster, `docs/reference/*`) all name the same
   set that is on disk. `check_standards.py` guards much of this — the subagent
   looks for *semantic* drift it can't catch (a skill renamed in spirit, a
   description that no longer describes the body).
4. **Namespace & brand hygiene.** No stale `/e22-*` invocation survives; every
   invocation is `/steer:`; no org-specific brand leaks into shipped
   `templates/` (scaffold/spec/reference stay client-agnostic).
5. **Payload & placeholder hygiene.** No unresolved `TODO`/`FIXME`/`[Replace`
   leaks into shipped (non-`templates/`) content; scaffold dotfiles stored
   without their leading dot map correctly in `MANIFEST.md`; migration-ledger
   targets exist.
6. **Behavioral coherence across surfaces.** `rules/`, `skills/`, and
   `templates/` do not contradict each other (a rule asserting X while a skill
   does not-X; an `allowed-tools`/`disallowed-tools` boundary a skill's prose
   then violates).

**Vet before reporting.** Subagents over-report. Re-read the cited `path:line`
for every candidate and drop false positives, intentional patterns with a
why-comment, and cross-dimension duplicates. A finding that survives states the
incoherence, the evidence, and why it's real.

### A4. Documentation accuracy & deployed-site freshness.

`validate_docs.py` (already run inside `mise run ci`) proves the docs *structure*
is in sync — inventory, nav, links, namespace. It does **not** judge whether the
prose is *accurate and current*, nor whether the **live** site reflects `main`.
Cover both:

- **Accuracy (judgment).** Dispatch the **`documentation-reviewer`** subagent
  (`Task`, `subagent_type: documentation-reviewer`) to deep-review `docs/`
  against the plugin source of truth (skill frontmatter, `hooks.json`, rules) for
  staleness, coverage gaps, and claims that don't trace back to source. Fold its
  blocker/high findings into the report. (This is exactly the review the
  `/plugin-docs` skill drives; running it here makes "docs are current" a release
  gate, not an afterthought.)
- **Deployed-site freshness (deterministic).** The site is published to
  Cloudflare Pages from `main` by `docs-deploy.yml`, only when `docs/**` or
  `mkdocs.yml` change, and it sits **behind Cloudflare Access** — so it can't be
  fetched and diffed directly (a fetch of `https://ai.element-22.com/` 302s to an
  auth gate). Use the deploy **run status** as the source of truth instead:
  - `gh run list --workflow=docs-deploy.yml --branch main --limit 5` — confirm the
    most recent run **succeeded**. A failed/cancelled latest run means the live
    site is stale relative to `main` → **`[blocker] deployed docs stale: last
    docs-deploy on main did not succeed`**; tell the user to re-run it (`gh run
    rerun <id>` or the Actions UI) and let it go green before releasing.
  - Confirm no merged-but-undeployed docs change is sitting on `main`: if the
    latest commit touching `docs/`/`mkdocs.yml` on `origin/main` is **newer** than
    the head commit of the latest successful docs-deploy run, the live site lags
    `main` → same blocker.
  - If `gh` is unavailable or unauthenticated in this environment, **fail open**
    but loudly: report **`[warn] deployed-docs freshness not verified — run gh
    run list --workflow=docs-deploy.yml --branch main`** so the human closes the
    loop. Do not pretend it passed.
  - As a courtesy only, you may `WebFetch` the live URL to confirm it is reachable
    (a 302 to Access is expected and fine) — never treat its body as the freshness
    signal.

  Note the timing honestly in the report: **this release's own** docs changes
  deploy only *after* this PR merges to `main`. Phase A proves the docs *source*
  is correct and current and that *prior* docs changes are live; the post-merge
  deploy of this release's docs is a Phase-B follow-up the user owns (Step B9).

### A5. Audit gate — compile, rank, and decide.

Print a **release-readiness report**: a short summary table (dimension → finding
count → top finding) followed by a severity-ordered list, each finding with
`path:line` evidence and the one-line incoherence. Use explicit severity markers:

- **`[blocker]`** — must be fixed before any release (red gate, version/manifest
  drift, missing-or-phantom changelog coverage, stale deployed docs, a doc claim
  that contradicts the code). **If any blocker exists, STOP.** Do not branch, do
  not bump. Report the blockers and the fix each needs, and tell the user to
  resolve them on their own fix PRs (which add `### [Unreleased]` entries) and
  re-run `/release`.
- **`[high]` / `[medium]` / `[low]`** — report them, but they do not by
  themselves halt the release. Surface them so the user can decide to fold a
  quick fix in or ship and file the rest.

State plainly when a dimension came back **clean** — silence must never be
mistaken for "not checked." Only when there are **zero blockers** proceed to
Phase B.

---

## Phase B — cut the release

### B1. Determine the new version.

Read the current `version` from `plugins/steer/.claude-plugin/plugin.json` and
the `### [Unreleased]` bullets (and the Step-A3.1 note on implied bump). Propose
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
  defer) so the reviewer inherits the audit, not just the diff.

### B8. Report.

State the new version, the branch, the PR URL, the Phase-A audit verdict, and the
re-gate result.

### B9. Post-merge follow-ups the user owns (this skill does not do them).

- Consumers pick up the release via `/plugin update`.
- The **docs deploy** for this release's `docs/**` changes runs from `main` after
  merge (`docs-deploy.yml`) — watch that run go green so the live site at
  `https://ai.element-22.com` actually reflects the release; a red deploy leaves
  the published docs stale (and Phase A's next run will flag it).
- The **e2e suite** (`e2e.yml`) auto-runs on the merge commit because it bumps
  `plugin.json` — it is `continue-on-error` (non-blocking) today; glance at it.
- If the user tags releases, create the `vX.Y.Z` tag / GitHub release on the
  merged commit (this also keeps Step A1's `$LAST_RELEASE` diff anchor accurate
  for the next cut).

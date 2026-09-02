---
name: release
description: >-
  Cut a steer plugin release — first run a deep, read-only pre-release audit of
  the plugin codebase (computed preconditions + deterministic gate + strict docs
  build + the pre-release-audit workflow's judgment review) and BLOCK on any
  release-stopping finding; then confirm the semver bump with the user and cut
  the release with scripts/release_cut.py (heading rename, manifest bumps,
  re-gate) and open the release PR. Repo-local dev helper for e22-plugins; does
  not ship.
disable-model-invocation: true
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Agent
  - Workflow
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
  - Bash(git checkout*)
  - Bash(grep*)
  - Bash(gh run list*)
  - Bash(gh run view*)
  - Bash(gh api*)
  - Bash(mise trust*)
  - Bash(uv run python scripts/*)
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
  file, prove the codebase is coherent and release-ready: read the computed
  preconditions below, run the full deterministic gate *and* the strict docs
  build, run the `pre-release-audit` workflow for the judgment review, and record
  the round in the ledger. This phase is a **gate** — any blocker-severity finding
  stops the release before the version is bumped.
- **Phase B — cut the release.** Only once Phase A is clean: confirm the bump,
  run `scripts/release_cut.py`, re-gate, and open the release PR. The version
  bump happens **once**, here, in a dedicated release PR; implementation PRs only
  accumulate `### [Unreleased]` entries.

The invariant `check_changelog.py` enforces (and this skill upholds): the
`version` in `plugin.json` equals the newest *released* `### X.Y.Z` heading under
`## steer`, and released headings descend in strict semver order.

This skill is read-only until Step B2. Phase A only reads, runs gates, and
dispatches read-only reviewers — it never edits, branches, or commits. That is
deliberate: the audit must reflect the exact tree a reviewer will see, and a
release that can't pass its own audit shouldn't have a branch at all.

**This skill is user-invoked only** (`disable-model-invocation: true`). A release
is a timing decision the human makes; the model never starts one because the
tree "looks ready".

---

## Computed preconditions — fresh at invocation

The block below is produced by `scripts/release_preflight.py` **when you invoke
this skill**, not recalled from prose. It is procedure Step 1, the CI-status half
of Step 2, and Step 4b, computed: tree cleanliness, base currency, `[Unreleased]`
bullet count, manifest agreement, the `$LAST_RELEASE` anchor, the delta's worst
severity ceiling, the ledger gate, deployed-docs freshness, and the upstream
`validator-compat` job. Read the markers, not the prose around them.

```!
uv run python scripts/release_preflight.py --report --caller release
```

If the block above is missing or aborted, run the command yourself before
anything else. Any `[blocker]` line stops the release here; `[high]` is reported
in the PR body and never halts; `[warn]` means "not verified here" — close it by
hand and say so. `LAST_RELEASE=` is the anchor every diff-scoped check uses.

---

## Phase A — deep pre-release audit (read-only gate)

**The audit procedure is single-sourced in
[`.claude/audit/PRE-RELEASE-AUDIT.md`](../../audit/PRE-RELEASE-AUDIT.md).** Open
it and execute **Steps 1–5 in full** — every dimension, no subset (that subset is
`/quick-release`'s job). If that file and the index below ever disagree, the
procedure file is authoritative.

As the `/release` caller, you supply these pre/post-conditions around it:

- **Base contract (procedure Step 1).** The base must be current `main` — the
  computed block must show `tree-clean`, `base-current` and `unreleased` as `[ok]`
  (a branch ahead of `main` is a blocker for a release, unlike `/audit-loop`).
- **Bump input (procedure Step 3, dimension 1).** Carry forward the
  `changelog-coherence` finding, if any, that says the highest-impact bullet
  implies a larger bump than a naive reading — it is input to Step B1.
- **Timing note (procedure Step 4b).** State honestly that *this release's own*
  docs changes deploy only after this PR merges; Phase A proves the docs source
  is current and that *prior* docs changes are live. The post-merge deploy is a
  Phase-B follow-up the user owns (Step B8).

The one-line index, for orientation only:

- **Step 1 — base preconditions.** Computed above.
- **Step 2 — deterministic gate.** `mise run ci` + the strict `mise run
  docs:build`, up front and blocking. The `validator-compat` status is computed
  above (`[high]`, not a blocker — it tracks upstream Claude Code, not the diff).
- **Step 3 + 4a — judgment review.** Run the saved **`pre-release-audit`**
  workflow (Workflow tool, `name: "pre-release-audit"`, no args). It scouts the
  delta, dispatches the five coherence dimensions and the `documentation-reviewer`
  in parallel, retries a failed dispatch once, dedupes, and verifies every
  in-delta finding against its cited line. It returns ledger-ready `candidates`
  plus a `coverage` map — a dimension marked `unverified` means the round is not
  clean.
- **Step 4b — deployed-site freshness.** Computed above.
- **Step 5 — compile, rank, classify.** Severity is **capped** from the path by
  `scripts/audit_severity.py` when the candidates are recorded (never judged,
  never escalated); everything lands in `.claude/audit/findings.jsonl`.

### A6. Audit gate — decide.

The gate is **mechanical**. Severity comes from `scripts/audit_severity.py`, which
computes a ceiling from the finding's `path` (procedure Step 5); you do not grade
findings by how serious the prose sounds, and you may not escalate one above its
ceiling. Escalation discretion is what made this gate non-deterministic — the
6.0.0 cut was halted by a judgment escalation on a docs-site page that ships to no
consumer.

- **If any `[blocker]` exists, STOP.** After capping, that means exactly one of:
  a red deterministic check from Step 2 (or the computed block), or a finding on
  a release-critical manifest (`CHANGELOG.md`, the three version-bearing
  manifests, `.claude-plugin/marketplace.json`). Both mis-publish the release
  itself, and neither is a matter of opinion. Do not branch, do not bump.
- **`[high]` / `[medium]` / `[low]` never halt the release.** Report them, record
  them in the ledger, and let the user decide whether to fold a quick fix in.
  Do **not** ask the user to "defer a blocker" — if it is not release-critical it
  was never a blocker, and framing it as one is how a routine cut turns into a
  judgment call the user has to overrule.
- **Record the round before deciding.** Write the workflow's `candidates` (and,
  conservatively, its `unverified` list) to a JSON file and run
  `uv run python scripts/audit_ledger.py new --candidates <file>` then `record`,
  so the next release does not rediscover them. Report only what `new` calls new.

Only when there are **zero blockers** proceed to Phase B.

---

## Phase B — cut the release

### B1. Determine the new version.

Run `uv run python scripts/release_cut.py propose`. It prints the current
version, the `[Unreleased]` bullet count, the bump its vocabulary heuristic
suggests, and the candidate `X.Y.Z` for each level. It is a **suggestion**: read
the bullets (and the dimension-1 bump note from Phase A) and decide by nature:

- **major** — a breaking change to plugin behavior (renamed/removed skill, rule,
  hook, or template; changed invocation; anything a consuming repo must react to).
- **minor** — new backward-compatible capability (new skill, rule, scaffold file,
  or option).
- **patch** — fixes, wording, and internal changes only.

When entries are mixed, the highest-impact one wins. State the proposed `X.Y.Z`
and the one reason, and **confirm with the user before editing**.

**The `allowed-tools` grant does not survive the user's reply.** Per the Claude
Code skills reference, a skill's `allowed-tools` grants permission *for the turn
that invokes the skill*, and **the grant clears when the user sends their next
message** — the skill body stays in context, the permissions do not. So every
tool call after this confirmation is governed by the project's own permission
settings alone. `.claude/settings.json` covers the common ones (`mise run *`,
`uv run python scripts/*`, the read-only `git` verbs); anything outside it will
prompt. That is not a failure — approve and continue — but do not read a prompt
for a command this skill pre-authorized as a sign something is wrong, and do not
abandon a step because it started prompting. Durable rules belong in
`.claude/settings.json`, not in frontmatter.

### B2. Isolate, *then* branch — before editing any file.

This skill now edits tracked files, so the checkout must be isolated first;
editing the shared checkout in a background session is rejected by the isolation
guard. Do this **before** the cut, never after a rejection.

- **Background / isolated session** (or any time an edit to the shared checkout
  is refused): create a worktree with the **EnterWorktree** tool. Its name cannot
  contain `/`, so it lands on a branch like `worktree-release-x-y-z`; rename it to
  the convention right away with `git branch -m chore/release-X.Y.Z`. Run
  `mise trust` once in the fresh worktree before the first `mise` command.
- **Interactive session in a clean checkout:** `git checkout -b
  chore/release-X.Y.Z` off the up-to-date `main` is enough.
- Either way, all later steps, the gate, and the PR run from this isolated branch.

### B3. Cut — one command, then read its diff.

```sh
uv run python scripts/release_cut.py cut X.Y.Z --dry-run   # review the exact edits
uv run python scripts/release_cut.py cut X.Y.Z             # apply + validate
```

The script performs the whole cut and refuses to start if a precondition fails:

- `CHANGELOG.md`: renames the **heading** `### [Unreleased]` to `### X.Y.Z` and
  re-seeds an empty `### [Unreleased]` above it (the heading must always exist —
  it is what lets `merge=union` resolve concurrent bullet additions). It matches
  heading lines only, so the prose mention of `### [Unreleased]` in the
  changelog's house-rules bullet is never touched.
- `plugins/steer/templates/reference/MIGRATIONS.md`: renames every
  `### [Unreleased] — <what>` **inside `## Entries`** to `### vX.Y.Z — <what>` and
  never touches the authoring stub in the trailing `<!-- Template for a new entry
  -->` comment (stamping it would reinstate the guessed-version pattern, and no
  gate catches that). Zero renames is the normal case, not a skipped step. An
  entry keyed below the release it ships in is silently skipped by consumers, so
  this is correctness, not tidiness.
- The three version-bearing manifests move to `X.Y.Z` with a one-line textual
  edit each: `plugins/steer/.claude-plugin/plugin.json` (source of truth),
  `plugins/steer/.github/plugin/plugin.json`, and the `steer` entry in
  `.github/plugin/marketplace.json` — leaving that file's `metadata.version` (the
  marketplace's own) alone. If the old version appears on more than one
  `"version"` line of a file, the script stops rather than guess.
- Afterwards it asserts the release invariant (all manifests equal `X.Y.Z`, the
  newest released heading is `X.Y.Z`, the re-seeded `[Unreleased]` is empty, no
  `[Unreleased]` entry survived in the ledger, the stub was not stamped) and exits
  non-zero if any fails.

Do not hand-edit around the script. If it refuses, the refusal is the finding:
fix the cause (or stop), then re-run.

### B4. Validate the release invariant independently.

`uv run python scripts/check_changelog.py` (no `--base`, so it runs the release
validator only). It must report clean — version equals the newest heading and
headings descend.

### B5. Re-gate after the bump.

Phase A's `mise run ci` ran on the **pre-bump** tree. The only files Phase B
changed are `CHANGELOG.md`, possibly `MIGRATIONS.md`, and the three manifests —
exactly what the version-sync, migration and changelog gates police — so re-run
**`mise run check`** to prove the edits didn't regress those gates. Run it
**unpiped** (a `| tail` reports `tail`'s exit status, not the gate's). Report a
per-gate result; do not proceed past a red gate.

(The heavier suites — fixtures/test/shell/hooktests/docs build — already passed
in Phase A on a tree the version edits don't touch; re-running the full `ci` is
optional. If in any doubt, run `mise run ci`.)

### B6. Commit, push, open the PR.

These steps are intentionally **not** pre-authorized — they prompt, preserving
the human gate on outbound actions:

- Commit the changed files with the message `chore(release): steer X.Y.Z`.
- Generate the PR body:

  ```sh
  uv run python scripts/release_cut.py pr-body X.Y.Z --via release --audit <verdict-file>
  ```

  where `<verdict-file>` holds the Phase-A verdict you wrote (gates green;
  coherence/doc dimensions clean or the non-blocking `[high]/[medium]/[low]`
  findings the user chose to defer; the `coverage` map). The command pastes the
  released bullets so reviewers see the scope, embeds that verdict so the reviewer
  inherits the audit rather than just the diff, and appends the always-on
  context-budget table from `check_context_budget.py --report` so context weight
  can't silently regress across releases.
- Push the branch and open a PR titled `Release steer X.Y.Z` with that body.

### B7. Report.

State the new version, the branch, the PR URL, the Phase-A audit verdict, and the
re-gate result.

### B8. Post-merge follow-ups the user owns (this skill does not do them).

- Consumers pick up the release via `/plugin update`.
- The **docs deploy** for this release's `docs/**` changes runs from `main` after
  merge (`docs-deploy.yml`) — watch that run go green so the live site at
  `https://ai.element-22.com` actually reflects the release; a red deploy leaves
  the published docs stale (and the next preflight will flag it).
- The **e2e suite** and the **routing evals** are local-only tiers (`mise run
  e2e`, `mise run evals`) — run them before a substantive cut if you want the
  skill-level signal.
- The **`vX.Y.Z` git tag + GitHub Release** are created automatically by
  `release-publish.yml`, which fires on the merge commit that changed
  `plugin.json` and asserts afterwards that the tag resolves to that commit.
  Confirm that run went green: the next release's preflight anchors on this tag,
  and reports `[high] last-release` if it is missing. If the workflow is
  unavailable, re-publish with `gh workflow run release-publish.yml -f
  version=X.Y.Z` (an older version is tagged on the commit that introduced it and
  is not marked Latest), or, as a last resort, `gh release create vX.Y.Z --target
  <merge-sha> --title "steer X.Y.Z" --generate-notes --notes-file <(python3
  scripts/changelog_release_notes.py notes X.Y.Z)`.

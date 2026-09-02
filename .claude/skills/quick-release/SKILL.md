---
name: quick-release
description: >-
  Cut a steer plugin release on the fast path — run only the deterministic,
  machine-checkable pre-release gates (computed preconditions + full CI gate +
  strict docs build + deployed-docs freshness) and BLOCK on any red gate, then
  cut the release exactly as /release Phase B does (confirm the bump, run
  scripts/release_cut.py, re-gate, open the PR). Skips the pre-release-audit
  workflow's judgment review — use it for small, well-understood patch/minor
  cuts (a hotfix, a one-feature release); use /release for substantive or
  multi-feature cuts where coherence drift is plausible. Repo-local dev helper
  for e22-plugins; does not ship.
disable-model-invocation: true
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
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

# /quick-release — cut a steer plugin release on the fast path

The fast sibling of `/release`. It cuts a real release through the **same**
machinery and upholds the **same** invariants, but trades the slow, expensive
part of the audit — the `pre-release-audit` workflow's judgment review (five
coherence dimensions plus the documentation deep-review) — for speed. Everything
that a machine can check still runs and still blocks.

**When to use which.** Reach for `/quick-release` for a small, well-understood
cut: a single bug-fix patch, a one-feature minor, a hotfix you need out now,
where the set of `### [Unreleased]` bullets is short and you already know the
changes cohere. Reach for the full **`/release`** for a substantive or
multi-feature cut, anything touching rules ↔ skills ↔ templates interplay, or
any release where prose/coherence drift across the accumulated changes is
plausible. **If in doubt, run `/release`** — the audit it adds is exactly the
safety net this skill removes.

**What it keeps vs. drops, relative to `/release`:**

| Pre-release check | `/release` | `/quick-release` |
| --- | --- | --- |
| Computed preconditions (`release_preflight.py`: tree, base, bullets, manifests, anchor, ledger, docs freshness, validator-compat) | ✅ | ✅ |
| `mise run ci` (full deterministic gate) | ✅ | ✅ |
| `mise run docs:build` (strict Zensical build) | ✅ | ✅ |
| `pre-release-audit` workflow (CHANGELOG↔diff, cross-ref, brand, payload, behavioral, docs accuracy) | ✅ | ❌ skipped |
| Phase B cut (`release_cut.py`, re-gate, PR) | ✅ | ✅ (identical) |

The skipped workflow is pure **human-judgment** review — it catches *coherence*
drift (a description that no longer matches its body, a bullet that overstates a
change) that no deterministic gate can. Dropping it is the entire speed win, and
the entire risk. This skill makes that trade **explicit in the PR body**
(`release_cut.py pr-body --via quick-release` adds the note) so the reviewer knows
the coherence audit was not run and can apply that scrutiny themselves.

This skill is **read-only until Phase B begins** — exactly like `/release`, and
like `/release` it is **user-invoked only** (`disable-model-invocation: true`).

---

## Computed preconditions — fresh at invocation

Produced by `scripts/release_preflight.py` when you invoke this skill (procedure
Steps 1, the CI-status half of 2, and 4b). Read the markers, not the prose.

```!
uv run python scripts/release_preflight.py --report --caller quick-release
```

If the block above is missing or aborted, run the command yourself first. Any
`[blocker]` stops the release here; `[high]` is reported in the PR body and never
halts; `[warn]` means "not verified here" — close it by hand and say so.

---

## Phase A — deterministic pre-release gate (read-only)

This is the shared pre-release audit
([`.claude/audit/PRE-RELEASE-AUDIT.md`](../../audit/PRE-RELEASE-AUDIT.md)) with
Step 3 and Step 4a (the `pre-release-audit` workflow) removed — **Steps 1, 2, 4b
and 5 only**. That file is authoritative for what each retained step checks; the
steps below are the same content, scoped to this fast path. They are a strict
subset, so the deterministic invariants are unchanged.

### Q1. Pre-flight — refuse to start on a dirty or stale base.

Procedure Step 1, already computed above: `tree-clean`, `base-current`,
`unreleased` and `manifests` must all be `[ok]`. A branch *ahead* of `main` is a
blocker for a release (a release is cut from current `main`). `LAST_RELEASE=` is
the anchor; a `[high] last-release` line means the previous release was never
tagged — re-run `release-publish.yml` for it before cutting on top.

### Q2. Deterministic gate — the machine checks, up front, blocking.

- **`mise run ci`** — the repo's full local gate, run **unpiped**. Report a
  per-gate pass/fail line, reading the gate names off the run itself rather than
  from a list copied into prose here (`mise tasks` and `CLAUDE.md` describe the
  set; a copy goes stale the moment a task is added, and this one had).
- **`mise run docs:build`** — the **strict** Zensical build (fails on broken
  links / nav), which is *not* part of `mise run ci`. Run it because the GitHub
  Pages deploy happens post-merge from `main`; a red strict build would publish a
  broken site. If the toolchain genuinely can't be provisioned here, do not skip
  silently — report **`[blocker] strict docs build not verified`** so the user
  runs it before merging.

**Do not proceed past a red gate.** A failing deterministic check is a blocker by
definition — fix it on its own fix PR (which adds a `### [Unreleased]` entry) and
re-run.

### Q3. Deployed-docs freshness and validator-compat — computed.

Procedure Step 4b and the CI-status half of Step 2 are the `docs-deploy` and
`validator-compat` lines in the computed block: the latest `docs-deploy.yml` run
on `main` must have succeeded and must cover the newest docs commit (else
`[blocker]`), and a failed `validator-compat` job is `[high]`. A `[warn]` on
either means `gh` could not answer here — verify by hand
(`gh run list --workflow=docs-deploy.yml --branch main`) and say so; never
pretend it passed.

### Q4. Gate decision.

Print a short readiness line per check (preflight, CI, strict docs build) with
explicit severity markers, and **state plainly that the `pre-release-audit`
workflow was skipped** (this is `/quick-release`, not `/release`).

- **`[blocker]`** — any red gate, unverified strict docs build, or stale deployed
  docs. **If any blocker exists, STOP.** Do not branch, do not bump. Report the
  fix each needs and tell the user to resolve it on a fix PR and re-run.
- Only when there are **zero blockers** proceed to Phase B.

If at this point you have any doubt that the accumulated changes cohere, **stop
and recommend `/release`** instead — that is the whole reason the full audit
exists.

---

## Phase B — cut the release (identical to `/release` B1–B8)

The cut mechanics, invariants, and gotchas are **single-sourced in the `/release`
skill** — do not reimplement them here, and if the two ever diverge, **`/release`
is authoritative**. Open `.claude/skills/release/SKILL.md` and execute its
**Phase B steps B1–B8 verbatim**. The one-line index below is for orientation
only:

- **B1 — Determine the new version.** `uv run python scripts/release_cut.py
  propose`, then decide by nature (major = breaking, minor = new capability,
  patch = fixes/wording; highest-impact entry wins) and confirm with the user.
  Quick releases are *usually* patch or minor; a major almost always warrants
  the full `/release`.
- **B2 — Isolate, then branch.** In a background/isolated session use
  **EnterWorktree** then `git branch -m chore/release-X.Y.Z` and `mise trust`;
  interactive clean checkout, `git checkout -b chore/release-X.Y.Z`.
- **B3 — Cut:** `uv run python scripts/release_cut.py cut X.Y.Z --dry-run`, read
  the diff, then run it without `--dry-run`. It renames the changelog heading and
  re-seeds `[Unreleased]`, renames migration-ledger entries inside `## Entries`
  (never the stub), bumps all three manifests, and validates. If it refuses, the
  refusal is the finding.
- **B4 — Validate the release invariant:** `uv run python scripts/check_changelog.py`.
- **B5 — Re-gate after the bump:** `mise run check`, unpiped. Do not proceed past
  a red gate.
- **B6 — Commit, push, open the PR** (intentionally **not** pre-authorized — these
  prompt, preserving the human gate on outbound actions). Commit as
  `chore(release): steer X.Y.Z`; body from `uv run python scripts/release_cut.py
  pr-body X.Y.Z --via quick-release --audit <verdict-file>`, which adds the
  fast-path honesty note below; PR titled `Release steer X.Y.Z`.
- **B7 — Report:** new version, branch, PR URL, gate result.
- **B8 — Post-merge follow-ups** (consumer `/plugin update`, docs deploy, local
  e2e/evals). The `vX.Y.Z` tag + GitHub Release are cut automatically by
  `release-publish.yml` on merge — just confirm that run went green.

### Q5. PR-body honesty — record what this fast path did *not* check.

`release_cut.py pr-body --via quick-release` appends this note; keep it:

> Cut via `/quick-release`: deterministic gates (CI, strict docs build,
> deployed-docs freshness) passed. The judgment-based coherence audit and
> documentation-accuracy deep review were **not** run — reviewers should apply
> that scrutiny to the diff.

This keeps the trade-off visible to the reviewer rather than hidden in the choice
of skill.

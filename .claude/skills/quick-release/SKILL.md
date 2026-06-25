---
name: quick-release
description: >-
  Cut a steer plugin release on the fast path — run only the deterministic,
  machine-checkable pre-release gates (full CI gate + strict docs build + the
  cheap deployed-docs freshness check) and BLOCK on any red gate, then cut the
  release exactly as /release Phase B does (pick the bump, rename the CHANGELOG
  heading, bump every manifest, re-gate, open the PR). Skips the judgment-based
  coherence and documentation-accuracy subagent fan-out that /release runs — use
  it for small, well-understood patch/minor cuts (a hotfix, a one-feature
  release); use /release for substantive or multi-feature cuts where coherence
  drift is plausible. Repo-local dev helper for e22-plugins; does not ship.
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

# /quick-release — cut a steer plugin release on the fast path

The fast sibling of `/release`. It cuts a real release through the **same**
machinery and upholds the **same** invariants, but trades the slow, expensive
part of the audit — the judgment-based coherence fan-out and the documentation
deep-review — for speed. Everything that a machine can check still runs and
still blocks.

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
| `mise run ci` (full deterministic gate) | ✅ | ✅ |
| `mise run docs:build` (strict Zensical build) | ✅ | ✅ |
| Deployed-docs freshness (deterministic, cheap) | ✅ | ✅ |
| Judgment coherence fan-out (CHANGELOG↔diff, version/manifest, cross-ref, brand, payload, behavioral) | ✅ | ❌ skipped |
| `documentation-reviewer` deep accuracy review | ✅ | ❌ skipped |
| Phase B cut (bump, heading rename, manifest sync, re-gate, PR) | ✅ | ✅ (identical) |

The two skipped dimensions are pure **human-judgment** review — they catch
*coherence* drift (a description that no longer matches its body, a bullet that
overstates a change) that no deterministic gate can. Dropping them is the entire
speed win, and the entire risk. This skill makes that trade **explicit in the PR
body** (Step Q5) so the reviewer knows the coherence audit was not run and can
apply that scrutiny themselves.

This skill is **read-only until Phase B begins** — exactly like `/release`.

---

## Phase A — deterministic pre-release gate (read-only)

This is `/release` Phase A with the two subagent dimensions (A3 coherence
fan-out, A4 documentation-reviewer accuracy review) removed. Run the steps below;
they are a strict subset, so the deterministic invariants are unchanged.

### Q1. Pre-flight — refuse to start on a dirty or stale base.

Identical to `/release` A1:

- `git status --porcelain` must be empty — else stop; tell the user to commit or
  stash first.
- `git fetch origin main`, then confirm the local base is **not behind**
  `origin/main` (a release is cut from current `main`).
- `CHANGELOG.md` must have a `### [Unreleased]` section under `## steer` **with at
  least one bullet** — else there is nothing to release; stop and say so.
- Establish `$LAST_RELEASE` (the newest released `### X.Y.Z` heading's commit, via
  its `vX.Y.Z` tag, else the most recent `chore(release):` commit) only if you
  need it for the freshness check below; the coherence diff that consumed it in
  `/release` is not run here.

### Q2. Deterministic gate — the machine checks, up front, blocking.

- **`mise run ci`** — the full CI-equivalent gate (lint, plugin-check, fixtures,
  test, shell, hooktests, version-scan, docs:check, delivery-gates). Report a
  per-gate pass/fail line.
- **`mise run docs:build`** — the **strict** Zensical build (fails on broken
  links / nav), which is *not* part of `mise run ci`. Run it because the
  Cloudflare deploy happens post-merge from `main`; a red strict build would
  publish a broken site. If the toolchain genuinely can't be provisioned here, do
  not skip silently — report **`[blocker] strict docs build not verified`** so the
  user runs it before merging.

**Do not proceed past a red gate.** A failing deterministic check is a blocker by
definition — fix it on its own fix PR (which adds a `### [Unreleased]` entry) and
re-run.

### Q3. Deployed-docs freshness (deterministic, cheap — kept).

This check is cheap and catches a stale live site, so it stays. (It is the
deterministic half of `/release` A4; the `documentation-reviewer` accuracy half
is the part this skill drops.)

- `gh run list --workflow=docs-deploy.yml --branch main --limit 5` — the most
  recent run must have **succeeded**. A failed/cancelled latest run means the live
  site is stale relative to `main` → **`[blocker] deployed docs stale: last
  docs-deploy on main did not succeed`**; tell the user to re-run it and let it go
  green before releasing.
- If the latest commit touching `docs/`/`mkdocs.yml` on `origin/main` is **newer**
  than the head commit of the latest successful docs-deploy run, the live site
  lags `main` → same blocker.
- If `gh` is unavailable/unauthenticated here, **fail open but loudly**: report
  **`[warn] deployed-docs freshness not verified — run gh run list
  --workflow=docs-deploy.yml --branch main`**. Do not pretend it passed.

### Q4. Gate decision.

Print a short readiness line per check (CI, strict docs build, deployed-docs
freshness) with explicit severity markers, and **state plainly that the
judgment-based coherence and documentation-accuracy reviews were skipped** (this
is `/quick-release`, not `/release`).

- **`[blocker]`** — any red gate, unverified strict docs build, or stale deployed
  docs. **If any blocker exists, STOP.** Do not branch, do not bump. Report the
  fix each needs and tell the user to resolve it on a fix PR and re-run.
- Only when there are **zero blockers** proceed to Phase B.

If at this point you have any doubt that the accumulated changes cohere, **stop
and recommend `/release`** instead — that is the whole reason the full audit
exists.

---

## Phase B — cut the release (identical to `/release` B1–B9)

The cut mechanics, invariants, and gotchas are **single-sourced in the `/release`
skill** — do not reimplement them here, and if the two ever diverge, **`/release`
is authoritative**. Open `.claude/skills/release/SKILL.md` and execute its
**Phase B steps B1–B9 verbatim**. The one-line index below is for orientation
only:

- **B1 — Determine the new version.** Propose the bump from the `### [Unreleased]`
  bullets (major = breaking, minor = new capability, patch = fixes/wording;
  highest-impact entry wins) and confirm with the user. Quick releases are
  *usually* patch or minor; a major almost always warrants the full `/release`.
- **B2 — Isolate, then branch.** In a background/isolated session use
  **EnterWorktree** then `git branch -m chore/release-X.Y.Z`; interactive clean
  checkout, `git checkout -b chore/release-X.Y.Z`. After entering a fresh
  worktree, **`Read` `CHANGELOG.md` and all three manifests at their worktree
  paths before editing** (Edit requires a prior Read of that exact path).
- **B3 — Rename the changelog heading, re-seed an empty `[Unreleased]`.** Mind the
  gotcha: `### [Unreleased]` also appears as prose lower in the file — `grep -n`
  first and edit only the lowest-line-number heading.
- **B4 — Bump every manifest to `X.Y.Z`** (all three: `.claude-plugin/plugin.json`,
  `.github/plugin/plugin.json`, `.github/plugin/marketplace.json` steer entry;
  leave `metadata.version` alone).
- **B5 — Validate the release invariant:** `uv run python scripts/check_changelog.py`.
- **B6 — Re-gate after the bump:** `mise run check` (run `mise trust` once first
  in a fresh worktree). Do not proceed past a red gate.
- **B7 — Commit, push, open the PR** (intentionally **not** pre-authorized — these
  prompt, preserving the human gate on outbound actions). Commit the four files as
  `chore(release): steer X.Y.Z`; PR titled `Release steer X.Y.Z`.
- **B8 — Report:** new version, branch, PR URL, gate result.
- **B9 — Post-merge follow-ups the user owns** (consumer `/plugin update`, docs
  deploy, e2e run, optional `vX.Y.Z` tag).

### Q5. PR-body honesty — record what this fast path did *not* check.

When you write the PR body in B7, **in addition** to the `/release` requirements
(paste the released bullets; summarize the gate result), add an explicit note:

> Cut via `/quick-release`: deterministic gates (CI, strict docs build,
> deployed-docs freshness) passed. The judgment-based coherence audit and
> documentation-accuracy deep review were **not** run — reviewers should apply
> that scrutiny to the diff.

This keeps the trade-off visible to the reviewer rather than hidden in the choice
of skill.

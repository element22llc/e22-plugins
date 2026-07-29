# Pre-release audit — the shared procedure

The single source of truth for **what a pre-release audit of the `steer` plugin
checks**. It is a read-only procedure: run gates, dispatch read-only review
subagents, compile a ranked report. It never edits, branches, or commits — the
*caller* decides what happens to the findings.

**Callers:**

| Caller | Runs | Then |
| --- | --- | --- |
| `/release` Phase A | Steps 1–5, once | Blocks the cut on any `[blocker]`; the human fixes and re-runs. |
| `/audit-loop` | Steps 1–5, once per round | Fixes the findings in-tree and re-audits until a round comes back clean. |
| `/quick-release` Phase A | Steps 1, 2, 4b, 5 only | Skips the judgment fan-out (Step 3) and the docs deep-review (Step 4a) by design. |

If this file and a caller ever disagree about *what the audit checks*, **this
file is authoritative**. Callers own only the pre/post-conditions around it
(which base is legal to audit, what to do with the findings).

---

## Step 1 — base preconditions

The caller states which base is legal before invoking the procedure; the
procedure just verifies it.

- `git status --porcelain` must be empty. An audit of a dirty tree audits
  something no reviewer will ever see. **Always required, every caller, every
  round.**
- `git fetch origin main`, then confirm the local base is **not behind**
  `origin/main`.
  - `/release` and `/quick-release` additionally require the base to *be*
    `main` — a release is cut from current `main`.
  - `/audit-loop` permits a fix branch **ahead of** `main` from round 2 on;
    that is the tree it has been repairing, and it is the tree the release will
    be cut from once the branch merges.
- `CHANGELOG.md` must have a `### [Unreleased]` section under `## steer`.
  Release callers additionally require **at least one bullet** — with none there
  is nothing to release. `/audit-loop` does not require a bullet up front (it
  may be auditing a tree whose changes have already been released) but every fix
  it lands must add one.
- Establish the **last-release ref** for the diff-based checks: the newest
  `### X.Y.Z` heading in `CHANGELOG.md` is the last released version; find its
  commit via the `vX.Y.Z` git tag if one exists (`git describe --tags --match
  'v*' --abbrev=0`), else the most recent commit whose subject starts
  `chore(release):`. Call it `$LAST_RELEASE`. If neither exists, fall back to the
  start of history and say so (the coherence pass just reviews more).

## Step 2 — deterministic gate, up front

Blocking, mechanical problems must surface before any human-judgment review, and
before the version bump — not at the end where a red gate wastes the bump work.

- **`mise run ci`** — the full CI-equivalent gate (lint, plugin-check, fixtures,
  test, shell, hooktests, version-scan, docs:check, delivery-gates). Report a
  per-gate pass/fail line.
- **`mise run docs:build`** — the **strict** Zensical build (fails on broken
  links / nav). This is **not** part of `mise run ci`; it normally runs only in
  the `docs-deploy.yml` build job. Run it here because the GitHub Pages deploy
  happens **post-merge from `main`**: if the strict build is red, the merge will
  publish a broken or stale site. Catching it now is the difference between a
  clean release and a silently-broken live doc.
  - This pulls the `docs` dependency-group on demand (`uv run --group docs`); it
    is heavier than the rest. If the toolchain genuinely can't be provisioned in
    this environment, do not skip silently — report it as **`[blocker] strict
    docs build not verified`** so the user runs `mise run docs:build` themselves
    before merging.

A failing deterministic check is a `[blocker]` by definition.

## Step 3 — judgment-based coherence audit: fan out, then vet

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
   highest-impact bullet implies a larger bump than a naive reading.
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

## Step 4 — documentation accuracy & deployed-site freshness

`validate_docs.py` (already run inside `mise run ci`) proves the docs *structure*
is in sync — inventory, nav, links, namespace. It does **not** judge whether the
prose is *accurate and current*, nor whether the **live** site reflects `main`.
Cover both:

### 4a. Accuracy (judgment)

Dispatch the **`documentation-reviewer`** subagent (`Task`,
`subagent_type: documentation-reviewer`) to deep-review `docs/` against the
plugin source of truth (skill frontmatter, `hooks.json`, rules) for staleness,
coverage gaps, and claims that don't trace back to source. Fold its
blocker/high findings into the report. (This is exactly the review the
`/plugin-docs` skill drives; running it here makes "docs are current" a release
gate, not an afterthought.)

### 4b. Deployed-site freshness (deterministic)

The site is published to GitHub Pages from `main` by `docs-deploy.yml`, only when
`docs/**` or `mkdocs.yml` change. Rather than fetching the public site (subject
to CDN cache lag, so a fetch can disagree with `main` for minutes after a
deploy), use the deploy **run status** as the source of truth:

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

Note the timing honestly in the report: **the release's own** docs changes deploy
only *after* the release PR merges to `main`. The audit proves the docs *source*
is correct and current and that *prior* docs changes are live; the post-merge
deploy of the release's docs is a follow-up the user owns.

## Step 5 — compile, rank, classify

Print a **release-readiness report**: a short summary table (dimension → finding
count → top finding) followed by a severity-ordered list, each finding with
`path:line` evidence and the one-line incoherence.

**Severity:**

- **`[blocker]`** — must be fixed before any release: a red gate, version/manifest
  drift, missing-or-phantom changelog coverage, stale deployed docs, a doc claim
  that contradicts the code.
- **`[high]` / `[medium]` / `[low]`** — real, but do not by themselves halt a
  release.

**Disposition** — tag every finding, because it decides who can act on it:

- **`fixable-in-tree`** — resolvable by editing files in this checkout (the
  overwhelming majority). These are what `/audit-loop` repairs.
- **`out-of-tree`** — needs an action outside the working tree: re-running a
  workflow, an upstream SHA bump, a GitHub setting, a human decision about
  intent. A loop can never converge on these, so they must be named and handed
  back, never retried.

State plainly when a dimension came back **clean** — silence must never be
mistaken for "not checked."

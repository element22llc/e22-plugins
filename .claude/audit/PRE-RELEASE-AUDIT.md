# Pre-release audit — the shared procedure

The single source of truth for **what a pre-release audit of the `steer` plugin
checks**. It is a read-only procedure: run gates, dispatch read-only review
subagents, compile a ranked report. It never edits, branches, or commits — the
*caller* decides what happens to the findings.

**Callers:**

| Caller | Runs | Then |
| --- | --- | --- |
| `/release` Phase A | Steps 1–5, once | Blocks the cut on any `[blocker]` — which, after Step 5 capping, means a red gate or release-critical manifest drift only. |
| `/audit-loop` | Steps 1–5, once per round | Fixes the in-scope findings in-tree and re-audits; capped at 2 rounds, and it never edits `non-shipping` paths. |
| `/quick-release` Phase A | Steps 1, 2, 4b, 5 only | Skips the judgment review (Steps 3 + 4a) by design. |

If this file and a caller ever disagree about *what the audit checks*, **this
file is authoritative**. Callers own only the pre/post-conditions around it
(which base is legal to audit, what to do with the findings).

**Two pieces of this procedure are machinery, not prose.** Steps 1, the CI-status
half of Step 2, and Step 4b are computed by `scripts/release_preflight.py`, which
every caller injects at invocation and re-runs per round (`--caller` sets which
base is legal). Steps 3 and 4a are the saved `pre-release-audit` workflow
(`.claude/workflows/pre-release-audit.js`), which owns the dispatch, the
retry-once rule, cross-dimension dedupe and per-finding verification. The prose
below says *what* each step checks and *why*; when it names a check the script or
workflow already performs, the machinery is the implementation and this file is
its specification.

---

## Step 1 — base preconditions

The caller states which base is legal before invoking the procedure; the
procedure just verifies it. **Computed** by
`uv run python scripts/release_preflight.py --report --caller <release|quick-release|audit-loop>`
— every line below corresponds to one `[ok]/[blocker]/[high]/[warn]` marker in
its output, and `LAST_RELEASE=` is the anchor. Read the markers; do not re-derive
them by hand.

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
  start of history and say so (the coherence pass just reviews more). The
  preflight reports **`[high] last-release`** when the current `plugin.json`
  version has no `vX.Y.Z` tag — `release-publish.yml` did not fire for the last
  cut, and every delta-scoped check below would be anchored one release too far
  back. Re-run it (`gh workflow run release-publish.yml -f version=X.Y.Z`) before
  trusting the delta.

## Step 2 — deterministic gate, up front

Blocking, mechanical problems must surface before any human-judgment review, and
before the version bump — not at the end where a red gate wastes the bump work.

- **`mise run ci`** — the repo's full local gate. Report a per-gate pass/fail
  line, reading the gate names off the run itself; `mise tasks` and `CLAUDE.md`
  are the places that describe the set. **Do not restate the task list here** — a
  list copied into prose goes stale the moment a task is added, and this one had
  (it was missing `typecheck`, `actions` and `actions-security` for several
  releases while claiming to be complete).
- **`mise run ci` is not the whole of CI.** `plugin-quality.yml` also runs a
  second job, `validator-compat`, which re-runs `claude plugin validate --strict`
  against **latest** Claude Code. It is `continue-on-error: true` — correctly
  non-blocking on a PR, since it tracks upstream, not the diff — and `mise run ci`
  pins its own CLI, so nothing local covers it. At *release* time it matters, because
  the release ships to consumers who are on latest:

  The preflight's `validator-compat` line computes this (latest
  `plugin-quality.yml` run on `main` → that job's conclusion). A failed
  `validator-compat` on `main` is **`[high]`**, not a blocker — the pinned job
  stays authoritative — but it must appear in the report by name. Shipping over a
  known upstream-schema break is a decision the user makes deliberately, not one
  they make by not being told. When `gh` is unavailable the line reads
  **`[warn] validator-compat not verified`**; never infer it from the pinned job.
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

- **`claude plugin tag --dry-run --force plugins/steer`** — first-party manifest
  coherence. It asserts that `plugin.json` and the enclosing marketplace entry
  agree on the version, which is what audit dimension 2 used to ask a judgment
  subagent to re-derive. `--dry-run` creates nothing and `--force` waives only
  the dirty-tree and tag-exists checks, so what remains is purely the agreement
  assertion. It runs inside `mise run ci` (via `plugin-check`), so Step 2 already
  covers it — named here because it is *why* dimension 2 is no longer dispatched.
  The Copilot manifest pair is covered by
  `check_plugin.check_copilot_version_sync` in the same task.
- **`uv run python scripts/audit_ledger.py gate`** — no untriaged blocker is
  sitting in the persistent findings ledger. Also inside `mise run ci`.

A failing deterministic check is a `[blocker]` by definition.

**A piped exit status is not an exit status.** Run gates unpiped, or capture
`${PIPESTATUS[0]}` / `$?` before any `| tail`. A `mise run ci` reported green off
the tail of its own log is the status of `tail`, and this has already happened on
the release path.

## Step 3 — judgment-based coherence audit: fan out, then vet

Deterministic checks prove *structure*; they cannot judge *coherence* — a skill
whose description no longer matches its body, a `[Unreleased]` bullet that
overstates a change, a rule that contradicts a skill.

**Scope every dimension to the release delta.** Each subagent reviews only paths
in `git diff $LAST_RELEASE..HEAD`, not the whole tree. This is the single change
that makes the audit terminate. Unscoped, the reviewers sample ~250 markdown
files that mostly have not changed in years: they always find *something*, each
round finds a *different* something, and the "audit until a round is clean" stop
condition becomes a geometric wait on a stochastic sampler. That is not a
hypothesis — between v5.3.0 and v6.0.0 six audit loops ran (five of them the full
four rounds, ~160 reviewer dispatches, 257 markdown edits against 44 code edits)
and the release still blocked. Scoped to the delta the surface is finite and
shrinks as it is repaired, so a clean round means "this release introduced
nothing incoherent" — a claim that is both achievable and the one a release
actually needs. Pre-existing incoherence outside the delta is real, and it belongs
in the ledger (Step 5), not in the release gate.

Give each subagent the delta file list explicitly. A finding whose `path` is not
in the delta is **out of scope for the gate**: record it in the ledger and move
on. Do not widen a dimension because a nearby file looks suspect.

**Dimension 2 is no longer dispatched.** Version and manifest coherence is fully
covered deterministically — `claude plugin tag --dry-run --force`,
`check_plugin.check_copilot_version_sync`, `check_changelog.py`'s release
validator, `scan-version-pins.sh` and `check-policy-freshness.sh` — and every one
of those runs inside `mise run ci`. A subagent re-deriving them costs a reviewer
slot per round to reproduce a result Step 2 already proved; in the 6.0.0 audit it
returned clean, as it must. The number 2 is retained (rather than renumbering 3–6)
so every existing cross-reference to a dimension number stays valid.

**Run the saved `pre-release-audit` workflow** (Workflow tool,
`name: "pre-release-audit"`; the permission rule `Workflow(pre-release-audit)` in
`.claude/settings.json` pre-approves it). It is the implementation of this step
and of Step 4a: a scout stage derives `$LAST_RELEASE` and the delta list (or
takes them from `args`), one read-only reviewer per dimension runs **in
parallel** against a findings schema (so a finding cannot arrive as prose), a
reviewer that returns nothing usable is **re-dispatched exactly once** and
otherwise recorded as `unverified`, findings are deduplicated across dimensions
by `path` + claim slug (the ledger's identity), and every in-delta finding is
then handed to a **verifier** that re-reads the cited line and may only lower
the severity. The result carries `candidates` (ledger-ready), `coverage` per
dimension, `refuted`, `unverified`, `outOfDelta`, and `clean`. Each reviewer is
told: *read-only; every finding must carry `path:line` evidence and a one-line
statement of the incoherence; default to silence over speculation.* The
dimensions, as the workflow encodes them:

1. **CHANGELOG ↔ change coherence (both directions).** Diff
   `git diff $LAST_RELEASE..HEAD -- plugins/steer/` and the `### [Unreleased]`
   bullets. Flag (a) any bullet with no corresponding change in the diff
   (overstated/phantom entry), and (b) any behavior-affecting change under
   `plugins/steer/` with **no** bullet. Do not assume `check_changelog.py --base`
   has already covered (b): that gate asks only whether `CHANGELOG.md` is in the
   PR's changed set, not whether a bullet was added or whether it describes the
   change — so a PR that touches the file for any reason clears it. This
   dimension is the only thing that reads bullets against the diff. Note whether
   the highest-impact bullet implies a larger bump than a naive reading.
2. **Version & manifest coherence — RETIRED, now deterministic (Step 2).** Do
   not dispatch this dimension. For the record, it covered: the three version-bearing manifests
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

**A finding that rests on host-platform behaviour must quote it verbatim.** Tell
the subagents: when a finding turns on what Claude Code *itself* does — a hook's
decision control, a timeout budget, a settings or manifest field — quote the
upstream reference **verbatim**, with its URL and line, so the caller re-checks it
with one `grep` instead of re-deriving the question. A finding of this kind
without a verbatim quote is unvetted by construction, and this is the class of
finding that has been most expensive to get wrong here.

**Vet before reporting.** Subagents over-report. The workflow's Verify phase does
the first pass structurally — one verifier per candidate re-reads the cited
`path:line`, refutes false positives and intentional patterns with a why-comment,
and cross-dimension duplicates are collapsed before it runs. Read the `refuted`
list anyway: a refutation is itself a claim, and a reviewer's verbatim quote
outranks a verifier's paraphrase. A finding that survives states the
incoherence, the evidence, and why it's real.

**Settle disagreements on raw bytes, never on another opinion.** When vetting
contradicts a subagent, when two subagents contradict each other, or when either
contradicts what a previous round recorded, resolve it by fetching the raw source
document (`curl -sL <url>.md -o <file>`) or opening the file, and grepping for the
disputed string. Do **not** dispatch a third subagent to break the tie: that adds
an opinion, not evidence. Note especially that a *summarising* fetch can deny a
sentence that is verbatim present — so a summariser's denial never outranks a
reviewer's verbatim quote; go to the bytes. Whichever way it lands, record the
command and its output, and correct the losing record rather than leaving two
live versions of the same fact in circulation.

## Step 4 — documentation accuracy & deployed-site freshness

`validate_docs.py` (already run inside `mise run ci`) proves the docs *structure*
is in sync — inventory, nav, links, namespace. It does **not** judge whether the
prose is *accurate and current*, nor whether the **live** site reflects `main`.
Cover both:

### 4a. Accuracy (judgment)

The `pre-release-audit` workflow dispatches the **`documentation-reviewer`**
agent (`agentType: documentation-reviewer`, `ruleId: docs-accuracy`) alongside
the Step 3 dimensions to deep-review the `docs/` pages that describe the changed
plugin surfaces, plus every `docs/` file in the delta, against the plugin source
of truth (skill frontmatter, `hooks.json`, rules) for staleness, coverage gaps,
and claims that don't trace back to source. Its findings go through the same
verifier and land in the same `candidates` list. (This is the review the
`/plugin-docs` skill drives; running it here makes "docs are current" a release
gate, not an afterthought — though after Step 5 capping a docs page is `[low]`,
so it informs, it never halts.)

### 4b. Deployed-site freshness (deterministic)

The site is published to GitHub Pages from `main` by `docs-deploy.yml`, only when
`docs/**` or `mkdocs.yml` change. Rather than fetching the public site (subject
to CDN cache lag, so a fetch can disagree with `main` for minutes after a
deploy), use the deploy **run status** as the source of truth. The preflight's
`docs-deploy` line computes exactly this:

- The most recent `docs-deploy.yml` run on `main` must have **succeeded**. A
  failed/cancelled latest run means the live site is stale relative to `main` →
  **`[blocker] deployed docs stale`**; tell the user to re-run it (`gh run rerun
  <id>` or the Actions UI) and let it go green before releasing. A run still in
  progress is `[warn]` — wait for it.
- No merged-but-undeployed docs change may be sitting on `main`: the latest
  commit touching `docs/`/`mkdocs.yml` on `origin/main` must be an ancestor of
  the head commit of the latest successful docs-deploy run, else the live site
  lags `main` → same blocker.
- If `gh` is unavailable or unauthenticated in this environment, the line **fails
  open but loudly**: **`[warn] deployed-docs freshness not verified — run gh run
  list --workflow=docs-deploy.yml --branch main`**, so the human closes the loop.
  Do not pretend it passed.
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

**Severity is computed, never judged.** A finding's severity ceiling is a pure
function of its `path`, produced by `scripts/audit_severity.py`. A reviewer may
rank a finding **below** its ceiling; nobody — reviewer, vetter, or caller — may
rank one **above** it. There is no escalation discretion, because escalation
discretion is exactly what made this gate non-deterministic: in the 6.0.0 audit a
`[high]` on `docs/reference/hooks.md` was escalated to `[blocker]` by judgment and
halted the release, on a docs-site page that ships to no consumer.

```sh
uv run python scripts/audit_severity.py --explain <path>...
mise run audit:severity          # ceilings for the whole release delta
```

| Tier | Ceiling | What it covers |
| --- | --- | --- |
| `release-critical` | `[blocker]` | The version-bearing manifests and `CHANGELOG.md`. Drift here mis-publishes the release itself. |
| `shipped-code` | `[high]` | Executable content the plugin ships: hooks, plugin scripts, `hooks.json`, `.mcp.json`. Misbehaves in a consumer session. |
| `shipped-prose` | `[medium]` | `rules/`, `skills/`, `agents/`, `templates/`, `policy/`. Misleads a reader; does not misexecute. |
| `repo-tooling` | `[medium]` | `scripts/`, `mise.toml`, workflows. Ships nothing, but a broken gate hides what does. |
| `non-shipping` | `[low]` | `docs/`, `CLAUDE.md`, `CROSS-SURFACE.md`, `.claude/`, `tests/`, `evals/`, the maintainer README. Real findings; never a reason to hold a release. |

The shipping boundary is imported from `check_changelog._is_behaviour` — the same
deny-by-default classifier that decides whether a change needs a CHANGELOG entry —
so "ships to consumers" has one definition in this repo and the two gates cannot
drift apart.

**Only `[blocker]` halts a release**, and after capping the only paths that can
reach `[blocker]` are the release-critical manifests plus a red deterministic
gate. `[high]` / `[medium]` / `[low]` are real and reported; they never stop a cut.

**Record every finding in the ledger.** Write the workflow's `candidates` list
(plus, conservatively, its `unverified` list — an unverified finding is not a
refuted one) to a JSON file and run:

```sh
uv run python scripts/audit_ledger.py new    --candidates <file>   # report only what is unseen
uv run python scripts/audit_ledger.py record --candidates <file>   # persist them
```

`.claude/audit/findings.jsonl` is the repo's memory of what has already been
triaged. Report the **new** findings; carry the rest silently. A finding a human
has marked `accepted` (with a reason) never resurfaces and never gates — that is
what stops each release from re-litigating the previous release's backlog.
Between v5.3.0 and v6.0.0, with no ledger, `docs/concepts/copilot-support.md` was
edited in fourteen separate round commits and `docs/reference/hooks.md` in eight,
and `hooks.md` still produced the finding that blocked the cut.

Triage is a human act, not a loop's:

```sh
uv run python scripts/audit_ledger.py accept <id> --reason "ships nothing; tracked in #492"
uv run python scripts/audit_ledger.py resolve <id>
uv run python scripts/audit_ledger.py status
```

**Disposition** — tag every finding, because it decides who can act on it:

- **`fixable-in-tree`** — resolvable by editing files in this checkout (the
  overwhelming majority). These are what `/audit-loop` repairs.
- **`out-of-tree`** — needs an action outside the working tree: re-running a
  workflow, an upstream SHA bump, a GitHub setting, a human decision about
  intent. A loop can never converge on these, so they must be named and handed
  back, never retried.

State plainly when a dimension came back **clean** — silence must never be
mistaken for "not checked."

**A dispatched reviewer is not a reported reviewer.** Wait for **every** subagent
dispatched in Steps 3 and 4a to return before compiling the report — and do not
begin the report, or (for `/audit-loop`) close the round, open the PR, or
summarise to the user, while one is still running. Dispatch is not coverage: a
reviewer that has not reported has told you nothing, and a report written without
it makes a coverage claim you have not earned. If a reviewer lands *after* you
have reported, the round it belongs to is **not** finished — fold its findings in,
correct the report and the PR body, and say plainly that the earlier summary was
premature. In the run this guidance came from, the last dimension-6 reviewer
returned a genuine `[high]` against a shipped script after the PR had been opened
and the run summarised as complete.

**A dimension that did not return usable output is not clean.** The workflow
re-dispatches a reviewer that errors, returns empty, or returns something that
isn't a findings list **exactly once**; if the second attempt also fails it marks
that dimension `unverified` in `coverage` and sets `clean: false`. Report it as
**`[warn] dimension N not verified`** and name it in the report, the caller's
gate decision, and the PR body. It never counts toward a
clean round, and for `/audit-loop` it means **L4 condition 1 cannot fire** — a
round with an unverified dimension has not converged. Folding a failed dispatch
into the clean count is the one way this procedure can report coverage it does
not have.

---
name: audit-loop
description: >-
  Drive the pre-release audit to convergence — run the full audit, fix the
  findings in-tree, re-gate, and re-audit, round after round, until a round comes
  back clean. Accumulates every round as its own commit on one
  fix/pre-release-audit branch and opens a single PR, so a release that today
  takes five /release attempts takes one. Use it before /release (or after
  /release blocks on blockers); it never bumps a version or cuts a release.
  Repo-local dev helper for e22-plugins; does not ship.
argument-hint: "[--max-rounds N] [--severity blocker|high|all] [--dry-run]"
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
  - Bash(git checkout*)
  - Bash(git log*)
  - Bash(git fetch*)
  - Bash(git tag*)
  - Bash(git rev-list*)
  - Bash(git rev-parse*)
  - Bash(git describe*)
  - Bash(git worktree*)
  - Bash(grep*)
  - Bash(gh run list*)
  - Bash(gh run view*)
  - Bash(gh api*)
  - Bash(mise trust*)
  - Bash(uv run python scripts/*)
  - Bash(sh plugins/steer/scripts/*)
  - Bash(sh plugins/steer/hooks/tests/run.sh)
  - Bash(mise run ci)
  - Bash(mise run check)
  - Bash(mise run shell)
  - Bash(mise run gen:copilot)
  - Bash(mise run docs:build*)
---

# /audit-loop — audit → fix → re-audit, until clean

`/release` Phase A is a **gate**: it audits once, blocks on blockers, and hands
the findings back. That is correct for a release, but it makes convergence the
human's job — fix, re-run `/release`, get a fresh set of findings (the fixes
changed the diff the audit reads), fix again. Five rounds of that is five
branches, five PRs, and five full audits driven by hand.

This skill closes that loop. It runs the **same** audit
([`.claude/audit/PRE-RELEASE-AUDIT.md`](../../audit/PRE-RELEASE-AUDIT.md), the
single source of truth both this skill and `/release` execute), fixes what it
finds, re-gates, and audits again — until a round returns **no actionable
findings**. Every round lands as its own commit on **one** branch, and the whole
convergence ships as **one** PR.

**It does not release.** No version bump, no changelog heading rename, no release
PR. When it converges, merge its PR and run `/release` — whose Phase A should
then pass in a single round, which is the entire point.

## Why the findings keep coming back (and why looping is the fix)

Two real effects, not flakiness:

1. **Each fix changes what the audit reads.** Dimension 1 diffs
   `$LAST_RELEASE..HEAD`; a fix adds commits and CHANGELOG bullets, so the next
   audit legitimately evaluates a different tree. Fixing a rule can also newly
   contradict a skill (dimension 6) that was consistent before.
2. **The judgment dimensions sample.** Six subagents reading a large surface do
   not enumerate identically twice. A second pass over a repaired tree finds what
   the first pass didn't reach.

Neither converges in one shot; both converge in a few. A **clean round is strong
evidence, not proof** — say so in the report, never upgrade it to a guarantee.

---

## L1. Parse the run parameters.

| Flag | Default | Meaning |
| --- | --- | --- |
| `--max-rounds N` | `5` | Hard cap. Hitting it is an **escalation**, not a success. |
| `--severity blocker\|high\|all` | `high` | What gets fixed: `blocker` = blockers only; `high` = blockers + high (default); `all` = also medium/low. Everything below the threshold is still **reported**. |
| `--dry-run` | off | Audit once and report. No branch, no edits — equivalent to `/release` Phase A on its own. |

Each round costs a full `mise run ci`, a strict docs build, and seven subagents.
State the parameters up front so the user knows what they authorized.

## L2. Pre-flight, then isolate and branch — *before* the first round.

Unlike `/release`, this skill mutates from round 1, so the working copy is set up
first (an edit to a shared checkout in a background session is rejected by the
isolation guard — do this before the first `Edit`, never after a rejection).

- Verify the procedure's Step 1 base contract against **`main`**: clean tree, not
  behind `origin/main` (`git fetch origin main` first).
- **Background / isolated session:** create a worktree with the **EnterWorktree**
  tool, then rename its branch — `git branch -m fix/pre-release-audit`. Run
  `mise trust` once in a fresh worktree before the first gate, and re-`Read` any
  file at its worktree path before editing it (`Edit` requires a prior `Read` of
  that exact path).
- **Interactive session, clean checkout:** `git checkout -b fix/pre-release-audit`
  off up-to-date `main`.
- If a `fix/pre-release-audit` branch already exists, suffix it (`-2`, `-3`) or
  reuse it if it is *your* in-progress convergence — say which you did.
- `--dry-run` skips this step entirely.

Branching before the first audit is safe: the tree is byte-identical to `main`,
so round 1 audits exactly what `/release` would have.

## L3. The round loop.

Repeat until a stop condition in **L4** fires.

### a. Audit.

Execute [`.claude/audit/PRE-RELEASE-AUDIT.md`](../../audit/PRE-RELEASE-AUDIT.md)
**Steps 1–5 in full** — all six coherence dimensions and both halves of Step 4.
Never trim the dimension set to save a round; a dimension you skipped is a
finding `/release` will hand back to you later.

Two caller-specific adjustments:

- **Step 1 base rule, rounds 2+:** the tree must still be **clean** (the previous
  round's fixes are committed) but is now legitimately **ahead of** `main`. Being
  ahead is expected; being *behind* `origin/main` or *dirty* still aborts.
- **Step 2 cost, rounds 2+:** `mise run ci` runs every round, always. The strict
  `mise run docs:build` may be skipped in a round whose fixes touched neither
  `docs/` nor `mkdocs.yml` — but it **must** run once more in **L5** before the
  PR, so it is never skipped on the final tree.

### b. Record the round in the ledger.

Keep a running table across rounds — it is the report and the PR body:

| Round | blocker | high | med | low | Fixed | Deferred |
| --- | --- | --- | --- | --- | --- | --- |

For each finding also keep its identity (`path` + the one-line claim) and
disposition (`fixable-in-tree` / `out-of-tree`) — L4's guards compare these
across rounds.

### c. Check the stop conditions (**L4**) *before* fixing anything.

### d. Fix the actionable findings.

Actionable = `fixable-in-tree` **and** at or above the `--severity` threshold.
Apply the **minimal targeted** change each finding calls for:

- **Every fix touching `plugins/steer/` gets its own `CHANGELOG.md` bullet** under
  the existing `## steer` → `### [Unreleased]` heading. Append; never recreate or
  rename the heading (`.gitattributes` `merge=union` depends on it being
  persistent). Without the bullet, `check_changelog.py --base` fails the PR — a
  self-inflicted finding.
- **Docs findings** — follow the `/plugin-docs` procedure
  (`.claude/skills/plugin-docs/SKILL.md`) rather than hand-editing; the generated
  pages under `docs/reference/` are reconciled from the plugin, not authored.
- **Copilot artifacts** (`copilot-instructions.md`, `prompts/`, `agents/`,
  `vscode/mcp.json`, `copilot-hooks.json`) — regenerate with
  `mise run gen:copilot` and commit the result. **Never hand-edit a generated
  file**; a hand-edit reappears as a finding the moment the generator runs.
- **Never fix by weakening the check.** Deleting an assertion, loosening a
  validator, or dropping a doc claim to make it "true" is not convergence — it is
  hiding. If a finding is genuinely a false positive, say so with the evidence
  and mark it `dismissed`, don't silently edit around it.
- **Don't guess at intent.** If the right fix is a product/behavior decision (is
  the rule wrong, or the skill?), do not pick one to clear the round — mark it
  `deferred-for-human` with both options stated, and keep going.
- Respect this repo's frozen-scope rule: fixing an incoherence in `CLAUDE.md`,
  `AUTHORING.md`, `CONTRIBUTING.md`, or a gate script is in scope when the audit
  found it; *redefining* a convention while you are there is not.

### e. Re-gate and commit the round.

- `mise run check` after the round's fixes (the next round's audit runs the full
  `ci` anyway). If a fix broke a gate, repair it **inside this round** — do not
  push a red tree into the next audit.
- Commit the round as one commit: `fix(steer): clear round N pre-release audit
  findings` (scope per the change — `steer`, `rules`, `skills`, `docs`, …). One
  commit per round makes the PR read as an audit trail: round 1 found six things,
  round 2 found the two that fixing them exposed, round 3 was clean.
- Commits and pushes are **intentionally not pre-authorized** in the frontmatter —
  they prompt once per round, which is the human gate on a loop that edits code.

---

## L4. Stop conditions — one of these ends the loop, every time.

Evaluate in order, before fixing:

1. **Converged.** Zero actionable findings this round. Because a clean round
   always audits a tree it did not itself modify, this *is* the confirming pass —
   no extra round is needed. → success path, go to **L5**.
2. **Round cap.** `--max-rounds` reached with findings still open. → stop and
   escalate; report exactly what is still open.
3. **No progress.** The actionable count did not fall versus the previous round
   **and** no finding in it is new. The loop is churning. → stop; report the
   stalled set and why the fixes aren't landing.
4. **Recurrence.** A finding you already fixed in an earlier round comes back with
   the same identity. Fixing it again is a third guess at the same problem. → stop
   on *that* finding: report it, the fix that didn't take, and hand it to the
   human. (Finish the round's other fixes first — one recurring finding shouldn't
   strand the rest.)
5. **Out-of-tree only.** Every remaining finding is `out-of-tree` (a workflow to
   re-run, an upstream SHA to bump, a GitHub setting, a human decision). No number
   of rounds resolves these. → stop; list them as the human's checklist.

Conditions 2–5 are **honest failures**. Report them as such: the loop did not
converge, here is the residue, here is what each item needs. Never fix the report
instead of the tree.

## L5. Converged — prove it, then open the one PR.

1. **Final full gate on the final tree:** `mise run ci` **and**
   `mise run docs:build` (the strict build, even if L3b let a round skip it).
   Both green, or you have not converged.
2. **Push and open one PR**, titled `Pre-release audit convergence (N rounds)`,
   body containing:
   - the **round ledger** table from L3b;
   - one line per round naming what it fixed;
   - the **deferred / dismissed / out-of-tree** residue, each with its evidence —
     the reviewer must see what was *not* fixed, not just what was;
   - the final-round statement: which dimensions were checked and came back clean.
3. **Report to the user:** rounds run, findings fixed by severity, residue, branch,
   PR URL, final gate result. State plainly that a clean final round is strong
   evidence — not a guarantee — that `/release` Phase A will pass in one pass.

## L6. Hand off.

Merge this PR, then run **`/release`** (or `/quick-release` for a small cut).
`/release` re-runs the same audit from `main` — that re-run is the real gate, and
after a converged loop it should pass in a single round. Do **not** skip it: this
skill deliberately never bumps a version, never renames the changelog heading,
and never cuts a release.

Anything L4 left open belongs on the user's plate before that release — say so
explicitly rather than implying the tree is release-ready.

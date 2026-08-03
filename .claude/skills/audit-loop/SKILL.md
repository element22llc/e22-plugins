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
  - Bash(mise run rules:preview*)
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

Two **legitimate** effects, not flakiness:

1. **Each fix changes what the audit reads.** Dimension 1 diffs
   `$LAST_RELEASE..HEAD`; a fix adds commits and CHANGELOG bullets, so the next
   audit legitimately evaluates a different tree. Fixing a rule can also newly
   contradict a skill (dimension 6) that was consistent before.
2. **The judgment dimensions sample.** Six subagents reading a large surface do
   not enumerate identically twice. A second pass over a repaired tree finds what
   the first pass didn't reach.

Neither converges in one shot; both converge in a few. A **clean round is strong
evidence, not proof** — say so in the report, never upgrade it to a guarantee.

There is a third effect, and it is **pure waste**:

3. **The loop's own fixes manufacture findings.** A fix to a *doc*, *rule*, or
   *skill* is prose, and prose asserts facts about the plugin. Assert one that
   isn't true and the next round finds it — you have spent a full round (a `ci`,
   a docs build, seven subagents) auditing your own invention. In the run this
   guidance came from, **most of rounds 2 and 3 was correcting prose the previous
   round had written**: round 1's replacement text claimed `/steer:sync` does not
   deliver the scaffold `.gitattributes` (it had, since v3.12.0 — nine releases
   back, routed through `scaffold_reconcile.py` by `MANIFEST.md:46`); round 2
   invented a version-pin claim about `/steer:audit` and credited a gate with
   reading `uv.lock`/`mise.lock` that `scan-version-pins.sh` never scans.

Effects 1–2 are why the loop exists. Effect 3 is what **L3.e** and the claim
discipline in **L3.d** exist to prevent: every round spent on effect 3 is a round
that bought nothing.

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

| Round | blocker | high | med | low | Fixed | Deferred | Self-inflicted |
| --- | --- | --- | --- | --- | --- | --- | --- |

For each finding also keep its identity (`path` + the one-line claim), its
disposition (`fixable-in-tree` / `out-of-tree`), and its **origin** —
`pre-existing` or `self-inflicted` (introduced by an earlier round of *this*
loop; `git log -- <path>` on the branch settles it in one command). L4's guards
compare identity across rounds, and the self-inflicted count is the number that
tells you whether the loop is converging or chasing itself.

Keep a second, smaller ledger: the **claim log**. One row per factual assertion
the round's own fixes wrote into prose, with the source that proves it (see
**L3.d** → claim discipline). It is what **L3.e** self-reviews against and what
makes the PR body auditable — a reviewer can check the claim without re-deriving
it.

| Round | File:line written | Claim asserted | Verified against |
| --- | --- | --- | --- |

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
- **Before deferring, try to split the finding.** A finding that reads as one
  human decision is often a decision *plus* a mechanical incoherence that needs
  no decision at all. Ask what part of it is true regardless of which way the
  human rules, and fix that part now; defer only the remainder, and say in the
  ledger that you split it. (The run this guidance came from split a deferred
  `[high]` into a genuinely-deferred half — nothing creates the file where it's
  absent — and a fixable half that was real plugin incoherence: three skills
  enumerating a merge set that excluded a file their own helper had always
  handled.)
- **Stay on this branch's concern.** A finding that is below the `--severity`
  threshold *and* unrelated to what this convergence is about gets **reported,
  not folded in** — CLAUDE.md's one-PR-one-concern rule binds this skill like any
  other change. Vet it (confirm it's real, cite `path:line`), put it in the
  residue as a named follow-up, and leave the tree alone.
- A round that edits `rules/` should check payload headroom with
  `mise run rules:preview` — the always-on payload runs close to its ceiling, so
  *adding* prose to a rule can trip the gate even when the wording is right. Push
  length into `templates/reference/*` instead.
- Respect this repo's frozen-scope rule: fixing an incoherence in `CLAUDE.md`,
  `AUTHORING.md`, `CONTRIBUTING.md`, or a gate script is in scope when the audit
  found it; *redefining* a convention while you are there is not.
- **Convention mandate (rare, human-granted).** If
  [`.claude/audit/CONVENTION-MANDATE.md`](../../audit/CONVENTION-MANDATE.md)
  exists, read it: a human has pre-authorized the convention changes it
  enumerates, and only those. Fix them like any other finding. Everything outside
  its scope stays `deferred-for-human` — the file is a list, not a licence. The
  round that acts on it **deletes it in the same commit** and says so in the
  ledger; a grant that outlives its round becomes a permanent convention change
  nobody reviewed. Absent the file, the bullet above governs unchanged.

#### Claim discipline — what keeps a round from auditing your own prose

Every declarative sentence a fix writes about plugin behavior is a **claim**, and
an unverified claim is a finding you are planting for the next round. Before you
write one:

1. **Read the source, in this round.** Not the docs about it, not another skill's
   description of it, not your memory of it from an earlier round — the script,
   the `SKILL.md`, the manifest, `hooks.json`, the template. Prior-round wording
   is precisely what you are trying to stop trusting.
2. **Log it** in the claim log (**L3.b**) with the path or command that proves it.
   Recorded evidence beats recalled evidence: a reviewer, and the next round,
   should be able to re-check it in one line.
3. **If you cannot verify it, don't write it.** Narrow the sentence to what you
   did verify. "Sync reconciles additively into files that already exist" is
   checkable; "sync never delivers this file" is a far stronger claim that needs
   far more proof.

Claim shapes that have actually gone wrong here, and what each one needs:

| Claim shape | What it needs |
| --- | --- |
| **Negative** — "X does not do Y", "nothing creates this" | The most-often-wrong kind, because not finding something feels like proof it isn't there. Needs *exhaustive* proof: enumerate every route that could do Y and show each one doesn't — the capability scan, the manifest, the helper, the skill's own steps. Absent that, rewrite it as the positive fact you did verify. |
| **Gate / script capability** — "gate G checks C", "the scan reads file F" | Open the script and find the line. `scan-version-pins.sh` does not read `uv.lock`/`mise.lock`; asserting it did cost a round. |
| **Skill behavior** — "`/steer:<skill>` reviews R" | Read that skill's `SKILL.md`. Never infer a skill's scope from its name, or from another surface's prose about it. |
| **Historical** — "shipped in vX.Y.Z", "since release N" | `git log`/`git tag` on the actual path, or the CHANGELOG heading that introduced it. |
| **Cross-surface routing** — "the manifest routes this through H" | Open the manifest *and* the helper; a route named in one is not a route implemented in the other. |

### e. Propagate each fix, then self-review the round's own diff.

This step is not optional and it is not the gate's job. It is the round auditing
itself, so the *next* round can spend its budget on the plugin instead of on you.

**Propagate.** A fix that changes a behavior changes every surface that describes
that behavior. For each behavior fix, grep the changed fact across `rules/`,
`skills/`, `templates/`, `docs/`, `CROSS-SURFACE.md`, `CLAUDE.md`, and `README.md`
before you commit — and remember the generated Copilot surface mirrors the
shipped one, so `mise run gen:copilot` may be part of the fix. Docs prose is the
usual casualty: it likes to use current behavior as a worked example, so fixing a
bug can silently turn an accurate page into a false one. (Round 3 of the run this
came from existed largely because round 2's fix left
`docs/concepts/authorization-model.md` using the fixed bug as a live example.)

**Self-review.** Then read this round's own diff as a reviewer would —
`git diff` on the uncommitted round, ignoring what the finding *told* you to fix
and looking only at what you *wrote*:

- Walk the claim log (**L3.b**) row by row. Every claim still traceable to the
  source cited? Any sentence in the diff that makes a claim you never logged is
  by definition unverified — verify it now or cut it.
- Did a fix restate something as fact that you actually inferred from the finding
  text? Findings are subagent prose too; they over-report and they mis-phrase.
- Would a `[Unreleased]` bullet this round added survive dimension 1 — does it
  describe what the diff does, no more?

Anything this step catches is a finding you just avoided paying a full round for.
Note in the ledger what self-review caught; a round where it caught nothing is
worth stating too.

### f. Re-gate and commit the round.

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

1. **Converged.** Zero actionable findings this round **and the round then makes
   no edits**. Both halves are required, and the second is the one that gets
   dropped: a round with zero *actionable* findings can still be sitting on a pile
   of below-threshold ones, and fixing those makes the tree you ship different
   from the tree that just came back clean. There is then no confirming pass —
   only an unaudited diff wearing a clean round's badge. (The run this guidance
   came from shipped nine such edits in its "clean" round and had to caveat the
   result.)

   So when the round is clean, **stop editing.** Below-threshold findings go to
   the residue as named follow-ups, not into this branch — which is also what
   one-PR-one-concern wants. → success path, go to **L5**.

   If you have already edited when you notice, you have two honest options: revert
   the edits and converge on the clean tree, or keep them and run one more round
   over them. Do not report the clean round as if it covered them.
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
   - the **claim log** for every prose fix that asserted a fact, with the source
     each was verified against, so the reviewer checks claims instead of
     re-deriving them;
   - the final-round statement: which dimensions were checked, which came back
     clean, and **that the final round made no edits** — i.e. the tree in this PR
     is exactly the tree that audited clean.
3. **Report to the user:** rounds run, findings fixed by severity, residue, branch,
   PR URL, final gate result. State plainly that a clean final round is strong
   evidence — not a guarantee — that `/release` Phase A will pass in one pass.
   Say how much of each round went on the plugin versus on repairing the previous
   round's prose: that ratio is this loop's efficiency, and a round spent on
   effect 3 is one the claim discipline should have prevented.

## L6. Hand off.

Merge this PR, then run **`/release`** (or `/quick-release` for a small cut).
`/release` re-runs the same audit from `main` — that re-run is the real gate, and
after a converged loop it should pass in a single round. Do **not** skip it: this
skill deliberately never bumps a version, never renames the changelog heading,
and never cuts a release.

Anything L4 left open belongs on the user's plate before that release — say so
explicitly rather than implying the tree is release-ready.

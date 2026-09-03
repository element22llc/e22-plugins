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
  - Bash(git checkout*)
  - Bash(git log*)
  - Bash(git fetch*)
  - Bash(git tag*)
  - Bash(git rev-list*)
  - Bash(git rev-parse*)
  - Bash(git describe*)
  - Bash(git worktree*)
  - Bash(git show*)
  - Bash(git blame*)
  - Bash(git merge-base*)
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

**User-invoked only** (`disable-model-invocation: true`): a loop that edits and
commits is started by a human, never because the model judged the tree ready.

## Computed preconditions — fresh at invocation

Produced by `scripts/release_preflight.py` when you invoke this skill (procedure
Step 1 plus the CI-status and docs-freshness checks). `--caller audit-loop` means
a branch *ahead* of `main` is `[ok]` and an empty `[Unreleased]` is `[info]`, both
legitimate here. Re-run the same command at the top of every later round.

```!
uv run python scripts/release_preflight.py --report --caller audit-loop
```

If the block is missing or aborted, run the command yourself before round 1.
`LAST_RELEASE=` is the anchor every round's delta is scoped to.

## Why the findings keep coming back (and why looping is the fix)

Two **legitimate** effects, not flakiness:

1. **Each fix changes what the audit reads.** Dimension 1 diffs
   `$LAST_RELEASE..HEAD`; a fix adds commits and CHANGELOG bullets, so the next
   audit legitimately evaluates a different tree. Fixing a rule can also newly
   contradict a skill (dimension 6) that was consistent before.
2. **The judgment dimensions sample.** Five subagents reading the delta do
   not enumerate identically twice. A second pass over a repaired tree finds what
   the first pass didn't reach.

Neither converges in one shot; both converge in a few. A **clean round is strong
evidence, not proof** — say so in the report, never upgrade it to a guarantee.

There is a third effect, and it is **pure waste**:

3. **The loop's own fixes manufacture findings.** A fix to a *doc*, *rule*, or
   *skill* is prose, and prose asserts facts about the plugin. Assert one that
   isn't true and the next round finds it — you have spent a full round (a `ci`,
   a docs build, six subagents) auditing your own invention. In the run this
   guidance came from, **most of rounds 2 and 3 was correcting prose the previous
   round had written**: round 1's replacement text claimed `/steer:sync` does not
   deliver the scaffold `.gitattributes` — it does, and has for many releases, via
   the same `scaffold_reconcile.py` route the scaffold `MANIFEST.md` gives every
   other scaffold dotfile; round 2 invented a version-pin claim about
   `/steer:audit` and credited a gate with reading `uv.lock`/`mise.lock` that
   `scan-version-pins.sh` never scans.

   This paragraph is itself the worked example. Until this revision it dated that
   `.gitattributes` claim to a specific release "nine releases back" and cited the
   manifest row as `MANIFEST.md:46`. The release count was wrong by the time
   anyone read it, and the line number survives only until a row is inserted above
   it. **A cautionary note about over-precise claims is not exempt from rule 4.**
   Neither is anything else you are about to write.

Effect 3 has a **worse form**, and it earns its own name because it does not
look like waste in the diff. A fix can take a surface that was **correct** and
make it wrong. Inventing a false claim costs you the next round; replacing a true
sentence with a false one costs that *plus* the correct documentation you
destroyed — and it reads as progress, because a finding was closed. Round 1 of
the run this guidance came from did exactly that to seven surfaces: the pre-loop
docs were right about what a `WorktreeRemove` hook can do, and round 1 overwrote
them from the plugin's own hook comment. Rounds 2–4 went on repairing it.

Note where that false comment came from: it was **already on `main`**, and it is
on `main` still — round 1 did not write it, it *believed* it. So the trap is not
one round's carelessness that a later round cleaned up; it is a live sentence in
the tree that will catch the next round to read it, too. **The authority ladder in
L3.d is the specific defence**, and unlike narrow prose mode it binds round 1 —
which is where this damage is actually done.

Effects 1–2 are why the loop exists. Effect 3 is what the claim discipline in
**L3.d**, the self-review in **L3.e**, and **L4 condition 5** exist to prevent:
every round spent on effect 3 is a round that bought nothing. The pattern is
consistent enough to name — **it is almost always an over-precise number**: a
per-item quantitative breakdown one round volunteered, which the next round
re-derives and contradicts. `L3.d` rule 4 is the specific defence.

---

## L1. Parse the run parameters.

| Flag | Default | Meaning |
| --- | --- | --- |
| `--max-rounds N` | `2` | Hard cap. Round 1 fixes; round 2 confirms round 1 broke nothing. Hitting it is an **escalation**, not a success. |
| `--severity blocker\|high\|all` | `high` | What gets fixed: `blocker` = blockers only; `high` = blockers + high (default); `all` = also medium/low. Everything below the threshold is still **reported**. |
| `--dry-run` | off | Audit once and report. No branch, no edits — equivalent to `/release` Phase A on its own. |

Each round costs a full `mise run ci`, a strict docs build, and one
`pre-release-audit` workflow run (five coherence reviewers +
`documentation-reviewer`, then one verifier per finding).
State the parameters up front so the user knows what they authorized.

**The `allowed-tools` grant does not survive the user's reply.** Per the Claude
Code skills reference, a skill's `allowed-tools` grants permission *for the turn
that invokes the skill*, and **the grant clears when the user sends their next
message** — the skill body stays in context, the permissions do not. So every
tool call after the first user reply is governed by the project's own permission
settings alone. `.claude/settings.json` covers the common ones (`mise run *`,
`uv run python scripts/*`, the read-only `git` verbs); anything outside it will
prompt. That is not a failure — approve and continue — but do not read a prompt
for a command this skill pre-authorized as a sign something is wrong, and do not
abandon a step because it started prompting. Durable rules belong in
`.claude/settings.json`, not in frontmatter.

## L1b. Two rounds, and no non-shipping prose.

Two structural limits, both from measurement rather than taste.

**The cap is 2.** Between v5.3.0 and v6.0.0 six loops ran, five of them the full
four rounds. Rounds 3 and 4 changed **2 to 24 lines each** — for a full `mise run
ci`, a strict docs build and six subagents apiece — and the release blocked
anyway. Those rounds were not buying safety; they were paying a round's cost to
proofread the previous round's prose. Round 1 fixes what the audit found. Round 2
audits round 1's own diff and confirms it introduced nothing. Anything still open
after that goes to the ledger as a named follow-up and **does not** hold the
release — because after the Step 5 capping it cannot be a blocker unless it sits
on a release-critical manifest, and that is not the kind of finding that survives
two rounds.

**Do not edit non-shipping prose.** A finding whose path classifies as
`non-shipping` (`scripts/audit_severity.py` — `docs/`, `CLAUDE.md`,
`CROSS-SURFACE.md`, `.claude/`, `tests/`, `evals/`, the maintainer README) is
**recorded in the ledger, never fixed in-round**, regardless of how the reviewer
graded it.

This is not a quality judgement about docs. It is where the loop's cost actually
went: across those six loops the rounds produced **257 markdown file-edits against
44 code edits**, and the single most-edited file was
`docs/concepts/copilot-support.md` at fourteen round commits. Docs changes need no
CHANGELOG entry and reach no consumer, so they were never part of the release
contract — yet they consumed most of every loop and generated the self-inflicted
findings that L3.d, L3.e and L4 condition 5 exist to contain. Removing them from
the loop removes the cause instead of managing the symptom.

Docs findings are cleared by **`/plugin-docs`** in its own PR, on its own
schedule, blocking nothing. Say in the ledger how many findings you routed there.

## L2. Pre-flight, then isolate and branch — *before* the first round.

Unlike `/release`, this skill mutates from round 1, so the working copy is set up
first (an edit to a shared checkout in a background session is rejected by the
isolation guard — do this before the first `Edit`, never after a rejection).

- Verify the procedure's Step 1 base contract against **`main`** from the
  computed block above: `tree-clean` and `base-current` must be `[ok]`, and the
  `ledger` line must not be a blocker.
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
**Steps 1–5 in full** — all five live coherence dimensions and both halves of
Step 4. Steps 3 and 4a are one call: run the saved **`pre-release-audit`**
workflow (Workflow tool, `name: "pre-release-audit"`, no args in a full round).
It scouts the delta from `$LAST_RELEASE`, re-verifies every open ledger row
whose file changed since it was confirmed, dispatches every dimension in
parallel, retries a failed dispatch once, dedupes across dimensions, verifies
each in-delta finding against its cited line, and returns `candidates`,
`coverage`, `refuted`, `unverified`, `outOfDelta` and `reconcile`. Apply
`reconcile` to the findings ledger (`audit_ledger.py reconcile --verdicts`)
before `new`/`record`, per the procedure's Step 5. A dimension whose `coverage` is `unverified` means
the round is **not** clean, whatever else it returned. Never trim the dimension
set to save a round on a hunch; a dimension you skipped because it *felt*
unaffected is a finding `/release` hands back to you later.

**Never trim the round that declares convergence.** A trim is a bet that a
dimension had nothing to say; the confirming round is the one whose coverage claim
the entire PR rests on, and it is the one place that bet is not affordable. So:
**if a round comes back with zero actionable findings — i.e. it is about to fire
L4 condition 1 — it must have run all six dimensions and both halves of Step 4.**
A trimmed round can never be the converging round. If you trimmed and the round
then came back clean, you have not converged: run the skipped dimensions before
claiming it. This is not a rewording of the disclosure rule below — disclosure
makes a gap visible, this forbids the gap.

**The one permitted trim, and its evidence bar.** In a **non-final** round, from
**round 3 on**, a dimension may be skipped when **all three** hold, and only then:

1. it returned **zero** blocker/high/medium in **every** prior round of this loop;
2. the previous round's **file list** (`git show --stat` on that round's commit)
   contains **none** of the dimension's inputs, per the table below — a mechanical
   test on a concrete list, not a judgment about relevance;
3. you **state the skip and this justification** in the round's ledger entry, the
   report, and the PR body. An unstated skip is a coverage claim you did not earn.

A trimmed round passes the surviving dimensions to the workflow explicitly —
`args: { dimensions: ["changelog-coherence", ...] }` by `ruleId` — and the
workflow marks its result `trimmed: true`, so the trim is recorded by the
machinery rather than remembered by you.

| Dimension | Its inputs | Skippable in practice? |
| --- | --- | --- |
| 1. CHANGELOG ↔ change | `CHANGELOG.md` + every `plugins/steer/**` path | **Never** — every round touches both by construction |
| 2. Version & manifest | the three version manifests, `policy/versions.yml`, `templates/scaffold/policy/versions.yml` | Often, and this is the clean case |
| 3. Cross-reference & inventory | `skills/*/SKILL.md`, `rules/`, `CLAUDE.md`, `README.md`, `CROSS-SURFACE.md`, `docs/reference/*` | Rarely |
| 4. Namespace & brand | **any** shipped file that can carry an invocation token or brand string | Rarely — the input set is nearly everything shipped |
| 5. Payload & placeholder | shipped non-`templates/` content, `templates/scaffold/**`, `MANIFEST.md`, `MIGRATIONS.md` | Often |
| 6. Behavioural coherence | `rules/`, `skills/`, `templates/` | Rarely |

Read that table before claiming a skip. The run this guidance came from skipped 2, 4
and 5 in its **confirming** round: 2 and 5 were clean by this test, **4 was not** —
the round had edited shipped skills and an agent file, which are exactly dimension
4's inputs. Under the rule above that round could not have trimmed at all.

Two further caller-specific adjustments:

- **Step 1 base rule, rounds 2+:** re-run `uv run python
  scripts/release_preflight.py --report --caller audit-loop`. The tree must still
  be **clean** (the previous round's fixes are committed) but is now legitimately
  **ahead of** `main` — `--caller audit-loop` reports that as `[ok]`. Being
  *behind* `origin/main` or *dirty* still aborts.
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
loop). L4's guards compare identity across rounds, and the self-inflicted count
is the number that tells you whether the loop is converging or chasing itself.

**Compute the origin; never recall it.** `git log -- <path>` is too coarse to
settle this — rounds routinely re-touch a file an earlier round touched, so
path-level history says "we edited this" about findings that are genuinely
pre-existing. Ask the question at the **line** the finding cites:

```sh
sha=$(git blame -L <line>,<line> --porcelain -- <path> | head -1 | cut -d' ' -f1)
git merge-base --is-ancestor "$sha" origin/main && echo pre-existing || echo self-inflicted
```

If the line that carries the incoherence was written by a commit already on
`origin/main`, the finding is `pre-existing` however much this loop has since
edited around it; if it was written by one of this branch's own round commits, it
is `self-inflicted`, and **L4 condition 5** is then arithmetic rather than a
judgment call. Record the sha in the ledger row so a reviewer can re-run the same
two lines.

Keep a second, smaller ledger: the **claim log**. One row per factual assertion
the round's own fixes wrote into prose, with the source that proves it (see
**L3.d** → claim discipline). It is what **L3.e** self-reviews against and what
makes the PR body auditable — a reviewer can check the claim without re-deriving
it.

| Round | File:line written | Claim asserted | Verified against |
| --- | --- | --- | --- |

**The round's own commit message and ledger rows are claim surfaces too.** They
are what a reviewer trusts and what the next round reads, and they fail exactly
the way shipped prose fails. In the run this guidance came from, one round's
commit message said it had *deleted* a clause it had in fact reworded, and
another stated the **opposite** of what the source says because the verification
behind it stopped a sentence short. Write both from the diff and the claim log,
never from the intent you started the round with.

A pushed commit message cannot be corrected. So when a later round refutes what
an earlier round **recorded** — a refutation that was itself wrong, a message
that overstates its own change — add a **correction row** to the ledger and carry
it into the PR body under the round it belongs to:

| Round | What it recorded | What is actually true | Settled by |
| --- | --- | --- | --- |

Superseding it silently leaves this branch's own audit trail asserting something
you now know to be false — the one thing a reviewer has no way to check for you.

### c. Check the stop conditions (**L4**) *before* fixing anything.

### d. Fix the actionable findings.

Actionable = `fixable-in-tree` **and** at or above the `--severity` threshold.
Apply the **minimal targeted** change each finding calls for:

- **Every fix touching `plugins/steer/` gets its own `CHANGELOG.md` bullet** under
  the existing `## steer` → `### [Unreleased]` heading. Append; never recreate or
  rename the heading (`.gitattributes` `merge=union` depends on it being
  persistent).

  **Do not expect a gate to catch a missing bullet on this branch.**
  `check_changelog.py --base` asks only whether `CHANGELOG.md` is *in the changed
  set* — not whether a bullet was added, and not whether it describes this round.
  It diffs `origin/main...HEAD`, i.e. the whole branch, so round 1 touching
  `CHANGELOG.md` satisfies it permanently and it can never fire again for rounds
  2+. `check_docs_impact.py --base` is coarse in exactly the same way ("any docs
  change clears the gate", per its own docstring). What actually catches a missing
  bullet is the **next round's dimension 1** — one full round later. The per-round
  re-run in **L3.f** is what closes that window; the bullet is your job either way.

- **Editing a bullet an earlier round wrote is not merge-safe — verify it after
  any rebase or merge.** `CHANGELOG.md` is `merge=union`, and union resolves a
  *conflicting* hunk by keeping **both** sides' lines. A round that deletes or
  rewords a bullet an earlier round added is fine in isolation, but if a
  concurrent PR has added bullets in the same region, the merge can silently
  resurrect the wording you retracted — with no conflict marker and no gate
  complaint. After any rebase or merge of this branch, `grep` the CHANGELOG for
  the retracted phrasing. (`/release` Phase A dimension 1, run from `main` after
  this PR merges, is the real safety net for this — which is one more reason
  **L6** forbids skipping it.)
- **Docs findings** — follow the `/plugin-docs` procedure
  (`.claude/skills/plugin-docs/SKILL.md`) rather than hand-editing; the generated
  pages under `docs/reference/` are reconciled from the plugin, not authored.
- **Copilot artifacts** (`copilot-instructions.md`, `prompts/`, `agents/`,
  `vscode/mcp.json`, `copilot-hooks.json`) — regenerate with
  `mise run gen:copilot` and commit the result. **Never hand-edit a generated
  file**; a hand-edit reappears as a finding the moment the generator runs.
- **A contradiction finding does not tell you which side is wrong.** "Surface A
  says X, surface B says not-X" reports a *disagreement*; it is not a verdict,
  and the finding text will not contain one however confidently it is phrased.
  The cheap resolution — edit whichever side is fewer files — is a coin flip.
  Settle X at its authority (**the ladder below**), *then* fix whichever side is
  wrong, which may turn out to be the code, a source comment, or several docs at
  once. If you cannot reach the authority this round, the finding is
  `deferred-for-human`. Propagating an unsettled X so the surfaces agree converts
  a **visible** contradiction into an **invisible**, consistent falsehood on every
  surface — strictly worse than what you started with, harder for the next round
  to see, and precisely what round 1 of the run this guidance came from did
  across every surface that described the behaviour.
- **Never fix by weakening the check.** Deleting an assertion, loosening a
  validator, or dropping a doc claim to make it "true" is not convergence — it is
  hiding. If a finding is genuinely a false positive, say so with the evidence
  and mark it `dismissed`, don't silently edit around it.
- **But a claim you wrote is not a check — and on its *second* miss, delete it
  rather than reword it.** The bullet above governs assertions the plugin *relies*
  on. A decorative detail one of your own earlier rounds volunteered — a per-item
  breakdown, a byte count, a version attribution nobody asked for — is not load-
  bearing, and rewording it a third time is not diligence, it is the loop paying a
  full round to proofread itself. When a finding lands on prose **this loop wrote**
  and a previous round already tried to fix it, the remedy is: **keep the coarser
  claim that is stably true, in exactly one place, and delete the fine-grained one
  everywhere.** Say in the ledger that you deleted rather than refined, and why —
  that is a fix, not a retreat. (Round 3 of the run this came from broke a two-round
  cycle exactly this way: it deleted a per-rule byte taxonomy from the CHANGELOG and
  the docs, leaving the corrected numbers in the one place a gate recomputes them.)
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
- **The loop's own machinery is out of scope for in-round fixes.** Findings
  against [`.claude/audit/**`](../../audit/) or against
  `.claude/skills/{release,quick-release,audit-loop}/**` are **reported as
  residue, never fixed in-round** — regardless of severity. Editing the procedure
  while executing it means round N+1 runs under different rules than round N, so
  the ledger stops comparing like with like and the convergence claim quietly
  loses its meaning. (Round 2 of the run this guidance came from edited both
  release skills mid-loop; every later round's coverage numbers are, strictly,
  uncomparable to round 1's because of it.) Vet the finding, cite `path:line`, put
  it in the residue as a named follow-up for its own PR, and leave the file alone.
  These paths ship nothing, so nothing about a release is blocked by deferring
  them.

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
4. **Don't volunteer a per-item quantitative breakdown at all.** A total you
   measured once is one claim; the same total split per rule, per file, or per
   release is a dozen claims, each independently falsifiable, none of which the
   reader needed — and every one of them re-derivable by the next round's subagent,
   which is why they come back. State the **aggregate**, put any fine-grained
   accounting in the **single** place that recomputes it (a gate script's own note,
   never a changelog bullet or a docs page), and never restate a number in two
   surfaces. This one rule accounts for most of the wasted rounds observed so far.

Claim shapes that have actually gone wrong here, and what each one needs:

| Claim shape | What it needs |
| --- | --- |
| **Negative** — "X does not do Y", "nothing creates this" | The most-often-wrong kind, because not finding something feels like proof it isn't there. Needs *exhaustive* proof: enumerate every route that could do Y and show each one doesn't — the capability scan, the manifest, the helper, the skill's own steps. Absent that, rewrite it as the positive fact you did verify. |
| **Gate / script capability** — "gate G checks C", "the scan reads file F" | Open the script and find the line. `scan-version-pins.sh` does not read `uv.lock`/`mise.lock`; asserting it did cost a round. |
| **Skill behavior** — "`/steer:<skill>` reviews R" | Read that skill's `SKILL.md`. Never infer a skill's scope from its name, or from another surface's prose about it. |
| **Historical** — "shipped in vX.Y.Z", "since release N" | `git log`/`git tag` on the actual path, or the CHANGELOG heading that introduced it. |
| **Quantitative** — "N bytes reclaimed", "−87/−167/−134 per rule", "11 sites" | The measurement, re-run in **this** round, on the exact range you cite. Then ask whether the number belongs in prose at all (rule 4 above): a per-item split is a claim per item, and a number restated in two surfaces goes stale in one of them the moment either changes. Prefer the aggregate, in one place. |
| **Cross-surface routing** — "the manifest routes this through H" | Open the manifest *and* the helper; a route named in one is not a route implemented in the other. |
| **Host-platform behaviour** — "a nonzero exit blocks this", "the declared timeout applies", "this field does Y" | The upstream Claude Code reference, fetched **raw** this round. See the ladder below — this is the row that has cost the most. |

#### The authority ladder — which source is allowed to settle a claim

Claim discipline asks *whether* you verified. This asks **against what**, and it
is the half that failed hardest. Round 1 of the run this guidance came from
verified diligently, logged its evidence, and was wrong anyway, because it
verified against a source with no standing for the claim it was making.

| The claim is about | The only source that settles it | Never authority for it |
| --- | --- | --- |
| **Host-platform behaviour** — what Claude Code does with a hook's exit code or stdout, a timeout budget, a settings or manifest field | The upstream reference, fetched raw **this round** | A comment in our own scripts; our own docs; a skill's prose; a subagent's summary; any previous round |
| **This plugin's behaviour** | The script, `SKILL.md`, `hooks.json` or manifest itself | Any prose *about* it — ours included |
| **What a gate enforces** | The gate script's own lines, plus a **positive control** when the claim is "it catches X": break X deliberately and watch it go red | A green exit code. Green proves nothing went wrong, not that anything was checked |

**The top row is the one that bites, and it is counter-intuitive.** A comment in
`plugins/steer/hooks/` sits next to the code and reads as documentation of it,
but it is a statement *by us* *about the harness* — it carries exactly the
authority of any other sentence we wrote, which for a runtime claim is none. That
is the trap round 1 walked into: our hook comment asserted that a nonzero exit
vetoes worktree removal, so round 1 believed it and rewrote the correct docs to
match. The harness discards that hook's exit code entirely.

The corollary matters as much as the rule: **when our own comment and the
upstream reference disagree, the comment is the bug.** Fix it in the same change
as the docs, or you have left the next round the identical trap, baited with your
own round's freshly-confirmed prose.

**This gates the edit, not just the report.** Before any change to a sentence
whose subject is host-platform behaviour, its upstream citation must already be
in the claim log. No citation, no edit — mark it `deferred-for-human` and move
on. Narrow prose mode (**L4** condition 5) starts at round 2; this binds round 1
too, because round 1 is when the tree still contains prose nobody in this loop
has questioned yet.

#### Verifying against an external document: raw bytes, then grep

A summarising fetch is evidence **for** a sentence it quotes back to you, and
**never** evidence **against** one it does not. `WebFetch` reads a long page
through a summariser; on a reference of several thousand lines it can return a
confident, specific denial that a sentence exists when the sentence is sitting
there verbatim. In the run this guidance came from it did so **twice in the same
round**, on the same sentence, and those two denials came within one step of
discarding a real `[high]` that two independent reviewers had each quoted
correctly. Only a raw `curl` and `grep` settled it — in the reviewers' favour.

So for any claim that turns on an external document:

1. **Fetch the raw document to a file and `grep` it** —
   `curl -sL <url>.md -o <file>`, then grep for a distinctive phrase. Rendered
   pages and summarised fetches are for orientation; only the raw bytes settle a
   dispute.
2. **Search for the entity by name across the whole document and read every
   hit**, tables included. A general rule that appears to cover your entity is
   *not* proof that no carve-out excludes it. Round 4 read the general per-hook
   `timeout` row, concluded a declared 60 s was honoured, and stopped one sentence
   short of the line stating that plugin-provided timeouts do not raise the budget
   at all. **Verification that stops early is indistinguishable, from the inside,
   from verification that succeeded** — which is why the search has to be
   mechanical rather than "until it looks answered".
3. **Log the grep command and the matched line** in the claim log — not "verified
   against the docs". The next round then re-runs one line instead of
   re-litigating the question from scratch, which is the whole point of the log.

A negative conclusion — "the reference says nothing about X" — is reportable only
if step 2 was exhaustive. Otherwise what you have is "I did not find it", which is
a different and much weaker sentence, and it belongs in the ledger as that.

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
- **Then re-run the two branch-diff gates against the *previous* round**, not
  against `origin/main`. Capture the pre-round `HEAD` before you commit (call it
  `$PREV`), and after committing run:

  ```sh
  uv run python scripts/check_changelog.py   --base "$PREV"
  uv run python scripts/check_docs_impact.py --base "$PREV"
  ```

  Run against `origin/main` — which is what `mise run ci`'s `delivery-gates` does
  — both gates are satisfied branch-wide by round 1 and say nothing about rounds
  2+ (see **L3.d**). Re-based on `$PREV` they ask the question that actually
  matters each round: *did this round's own fixes carry their own changelog bullet
  and their own docs update?* A red gate here is a self-inflicted dimension-1 or
  docs finding you would otherwise pay a full round to discover. Fix it inside
  this round with `git commit --amend`, and re-run.

  Both commands are already covered by the `Bash(uv run python scripts/*)` grant,
  so this adds no prompt. Do not try to reach them through
  `DELIVERY_GATES_BASE=… mise run delivery-gates`: a leading environment
  assignment changes the command string the permission matcher sees, so that form
  prompts where the direct calls do not.

---

## L4. Stop conditions — one of these ends the loop, every time.

Evaluate in order, before fixing:

1. **Converged.** Zero actionable findings this round, **the round ran all five
   live dimensions untrimmed** (**L3.a** — dimension 2 is retired to the
   deterministic tier, so five is the full set) **and every reviewer it
   dispatched has reported** (procedure Step 5), **and the round then makes no
   edits**. All three are required.

   "Actionable" is now a much smaller set than it used to be: severity is
   computed from the path (procedure Step 5), findings outside
   `git diff $LAST_RELEASE..HEAD` are out of scope for the gate, and
   `non-shipping` paths are never fixed in-round (**L1b**). A round that finds
   only ledger material *is* a clean round.

   "Ran" means *returned findings*, not *was dispatched*. A round still waiting on
   a reviewer has a count that can only go up, so it cannot yet be zero.

   The first is the one people read as the whole condition; the other two are what
   make it mean anything. A trimmed round that comes back clean has not converged —
   it has come back quiet about whatever it didn't run — so run the skipped
   dimensions and re-evaluate this condition on the result.

   The no-edits half is the one that gets dropped: a round with zero *actionable* findings can still be sitting on a pile
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
4. **Recurrence — count by identity, *and* by subject.** A finding you already
   fixed in an earlier round comes back with the same identity. Fixing it again is
   a third guess at the same problem. → stop on *that* finding: report it, the fix
   that didn't take, and hand it to the human. (Finish the round's other fixes
   first — one recurring finding shouldn't strand the rest.)

   **Identity alone is too narrow to catch the expensive case.** A claim family
   can stay wrong for rounds while never repeating an identity: each round
   surfaces a different file, a different sub-claim, a different severity, so the
   identity check never fires and the loop keeps editing the same idea. Key a
   second counter on the **claim subject** — the behaviour being asserted, not the
   `path:line` asserting it — and on the **third** finding against one subject
   across the loop, **quarantine the subject**: stop editing it entirely, write
   down everything the loop has established about it with each source, and hand it
   over. In the run this guidance came from, one subject (what the `SessionEnd`
   and `WorktreeRemove` hooks can report and can block) was wrong in **three of
   five rounds** under three different identities, and rounds 1 and 4 committed
   flat contradictions of each other into shipped docs. The identity guard never
   fired once.
5. **Narrow prose mode — on by default from round 2.** Not a stop; a **mode**.
   Every round after the first runs narrow unless a `[blocker]` requires
   otherwise:
   - a self-inflicted finding is fixed by **deletion or narrowing** (**L3.d**),
     never by a further rewording — a third attempt at the same sentence is the
     failure mode, not the fix;
   - the round writes **no new factual prose** beyond what a finding strictly
     requires. A `[blocker]` may earn new prose; nothing below it does; and
   - the ledger **says so** — "round N ran narrow: X of Y findings were ours".

   **Why the default, rather than a threshold.** This used to trigger only once
   self-inflicted findings reached half of a round's actionable set — i.e. only
   after the loop was already auditing itself, using data the triggering round
   didn't have yet. The run this guidance came from shows why that is too late:
   its round-2 commit message opens *"Five findings, **every one** a consequence
   of a round-1 fix"*. A threshold evaluated at the start of round 2 had nothing
   to fire on; the waste had already been committed. Round 2 is where the loop
   first has its own prose in the tree, so round 2 is where the restraint starts.

   Report the self-inflicted count every round even when it is zero — the count
   is what tells you whether the loop is converging or chasing itself, and it must
   be in the ledger as it goes rather than reconstructed at the end.
6. **Out-of-tree only.** Every remaining finding is `out-of-tree` (a workflow to
   re-run, an upstream SHA to bump, a GitHub setting, a human decision). No number
   of rounds resolves these. → stop; list them as the human's checklist.

Conditions 2, 3, 4 and 6 are **honest failures**. Report them as such: the loop did
not converge, here is the residue, here is what each item needs. Never fix the report
instead of the tree. Condition 5 is the one that is neither success nor failure — the
loop keeps going, narrower.

## L5. Converged — prove it, then open the one PR.

1. **Final full gate on the final tree:** `mise run ci` **and**
   `mise run docs:build` (the strict build, even if L3b let a round skip it),
   both run **unpiped**. Both green, or you have not converged.
2. **Push and open one PR**, titled `Pre-release audit convergence (N rounds)`,
   body containing:
   - the **round ledger** table from L3b;
   - one line per round naming what it fixed;
   - the **deferred / dismissed / out-of-tree** residue, each with its evidence —
     the reviewer must see what was *not* fixed, not just what was;
   - the **claim log** for every prose fix that asserted a fact, with the source
     each was verified against, so the reviewer checks claims instead of
     re-deriving them;
   - the final-round statement: **that the final round ran all five live
     dimensions plus the docs review untrimmed** (the workflow result shows
     `trimmed: false` and every `coverage` entry `reported`), which came back
     clean, and **that the final round made no edits** — i.e. the tree in this PR is exactly the tree that audited clean.
     Under L4 condition 1 the converging round cannot have skipped a dimension, so
     this is an affirmative claim to make, not a list of exceptions to disclose.
     Name any dimension an *earlier* round skipped under L3.a, with its file-list
     evidence: a reader must never have to infer coverage from silence;
   - the **correction rows** from **L3.b** — every place a later round refuted
     what an earlier round recorded, including in a commit message that can no
     longer be edited. A reader must not have to trust a message this loop already
     knows to be wrong;
   - the **residue of findings against the loop's own machinery** (`.claude/audit/`,
     the release-path skills) that L3.d held out of scope, so they are picked up in
     their own PR rather than lost.
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

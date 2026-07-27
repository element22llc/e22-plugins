# `/steer:issues` — hierarchy modes (`decompose`, `epic`, `status`)

Read this file when running `decompose`, `epic`, or `status`. The guardrails,
coupling rules, and the `## Recommended next actions` contract stay in
`SKILL.md` — they apply to every mode and are not repeated here.

## `decompose #N`

Create implementation sub-issues from a parent feature.

**Preconditions:** the feature's `intent.md` exists, `Status: approved`, and
its **contract readiness is `ready`** — the mechanically-derived signal in
`SPEC-FRAMEWORK.md` (Contract readiness), which already folds in "a populated
`contract.md` exists" and "no unresolved blocking question
`required_before: contract-approval`." Pointing both `decompose` and `status`
at the **same** derivation is deliberate: they can never disagree.

Use native GitHub parent/sub-issue links when available; else fall back to
`Parent: #N` + `<!-- steer:parent-issue=N -->` and a generated checklist in the
parent. Each child uses the `technical-task` body. `--prototype` is the **only**
way to decompose before approval, and those tasks are clearly marked
non-production.

**If `#N` is `kind=epic`**, this is the wrong tier — redirect to
`/steer:issues epic` (an epic groups *features*; it has no `contract.md` to
gate on).

## `epic [--new "<title>"] [#E --add #F1,#F2,…] [#F]`

Manage the tier **above** features: a parent tracking issue that groups child
features (and, transitively, their tasks) via native sub-issue links, so a goal
spanning several features is one visible hierarchy. An epic is a **grouping
construct owned by the tracker** — it has **no `intent.md`** and is **not
materializable**; its "why" is the rollup of its child features, optionally
pointing at a `vision.md` theme.

Verbs:

- **`epic --new "<title>"`** — create-or-find the epic. **Find before create**
  (search by `dedupe-key` + semantic title via `/steer:tracker-sync search`, open
  + closed — never silently reuse a semantic match). Render the `epic` body
  (`templates/github/issue-bodies/epic.md` — markers + managed block), set
  `steer:state=inbox`, and set **Type=`Epic` only when the org has it**, else keep
  `steer:kind=epic` with the Type unset and emit the capability warning (via
  `/steer:tracker-sync set-type`).
- **`epic #E --add #F1,#F2,…`** (alias **`epic #F`** to attach a single feature to
  a chosen epic) — link existing feature issues as sub-issues of `#E` via
  `/steer:tracker-sync link-parent` (native sub-issue link, else
  `steer:parent-issue` marker), and maintain the epic's `## Child features`
  checklist in its managed block.

**Gate:** unlike `decompose`'s contract-readiness gate (a *feature* derivation),
an epic only needs **its scope agreed + ≥1 child feature identified** — a
deliberately different, product-level bar, so the two tiers never share a
derivation. State (`inbox → exploring → in-progress → validate → done`) follows the
epic path in `ISSUE-WORKFLOW.md`; completion is the **child rollup** (all children
terminal, ≥1 `done`, PO confirms) — the agent proposes `done`, never auto-closes.

## `status [#N|feature-id]`

A unified read-only view: issue state + intent status + **contract readiness**
(`ready | incomplete | missing`, the derivation in `SPEC-FRAMEWORK.md` — never
`approved`) + sub-issue progress + blockers. Runs `/steer:spec validate` and
surfaces any failures. Example shape:

```
Feature customer-export
Issue: #123 — Validate
Intent: approved   Contract: ready
Implementation: 3/4 sub-issues closed
Preview: available
Blocking: #134 telemetry
```

**When `#N` is `kind=epic`**, render a **child-feature rollup** instead of
contract readiness — the linked features, their states, and how many are
`done`/`validate` — so the epic's progress is the aggregate of its features. Branch
on `steer:kind`; the feature/task shape above is unchanged. Example shape:

```
Epic billing-revamp
Issue: #98 — In-progress (Type: Epic)
Child features: 4 linked — 1 done · 1 validate · 2 in-progress
Eligible to close: no (2 features not yet terminal)
```

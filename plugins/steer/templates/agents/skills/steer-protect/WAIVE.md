# `/steer-protect waive` — record that solo-trunk is deliberate

Read this file when the dev asks to waive graduation (or to stop the solo-trunk
graduation nudge / push prompt), and not before. The guardrails and the
authorization boundary in `SKILL.md` still bind: this mode touches **no repo
settings** — it writes two local files, on the dev's one-line confirmation.

## What a waiver is

The hooks' local graduation signals — an `infra/` tree, a deploy workflow, a
`prod`/`production` branch — are heuristics for "this repo has outgrown pre-MVP".
They are right for a product heading toward a team, and wrong for a repo that
one person will keep on trunk on purpose: an internal tool with its own infra,
a solo product that deploys from `main`, a personal service. Without a way to
answer them, that dev gets the graduation notice every session and a permission
prompt on every session's first `git push`, forever.

A waiver is that answer, recorded once: **"single contributor, trunk is
deliberate, these signals are expected."** It is a **decision, not a third
delivery mode** (rule `45-commit-autonomy`) — the repo stays solo-trunk with
everything that mode already requires (issue-first, CI on push, the spine, tests,
Definition of Done). It covers **only the local signals**. A second collaborator
is the one condition a solo waiver cannot cover: `verify` and `/steer-audit`
treat a collaborator count > 1 as voiding it and recommend `apply`.

## Preconditions

1. The product `CLAUDE.md` declares **solo-trunk**
   (`<!-- steer:delivery-mode=solo-trunk -->`). In pr-flow there is nothing to
   waive — say so and stop; the pr-flow gate is the server wall, not these signals.
2. **Confirm the premise with the dev**, in one question: are they the only
   contributor, and is staying on trunk the plan (not a step they keep
   postponing)? If the honest answer is "we'll add people soon" or "the MVP is
   live and I want the review", recommend `apply` instead and stop.
3. When `gh auth status` succeeds, read the collaborator count
   (`gh api repos/{owner}/{repo}/collaborators --jq 'length'`). **> 1 → do not
   waive**: report the collaborators and recommend `apply`. If `gh` is
   unavailable or the repo is not on GitHub, proceed and say the collaborator
   check was skipped.

## Steps — only after the dev's confirmation

1. **Write the marker.** In the product `CLAUDE.md` `## Delivery mode` section,
   add `<!-- steer:graduation=waived -->` as its own line **directly under** the
   `steer:delivery-mode` marker. The hooks match this exact comment line (any
   case, surrounding whitespace allowed); a mention in prose does nothing.
2. **Say it in the prose** of the same section, one or two sentences the next
   reader can act on: who the sole contributor is (role, not necessarily a name),
   why trunk is deliberate, and that the waiver ends when a second contributor
   joins. Keep the existing solo-trunk prose; this is an addition.
3. **Write the history entry** under `/spec/history/` — same shape as the
   graduation entry (`YYYY-MM-DD-HHMM-graduation-waived.md`): the decision, the
   signals that were standing, the reason, and the revocation condition. **In a
   member** the entry goes to the workspace's ledger (rule `32-living-docs`);
   the `CLAUDE.md` marker is this repo's own.
4. **Commit** per the repo's mode — this is a solo-trunk repo, so the trunk
   commit (issue-first applies as for any change of this size).

## Report

State plainly what changed and what did not:

- The SessionStart graduation notice and the trunk-push prompt are now silent for
  this repo; nothing about GitHub settings changed, and `main` is still
  unprotected — by decision, now recorded.
- The waiver is **revoked** by `apply` (graduation removes the marker) or by
  deleting the marker line by hand; `verify` and `/steer-audit` keep reporting
  it, and flag a second collaborator as voiding it.
- If the collaborator check was skipped, say so.

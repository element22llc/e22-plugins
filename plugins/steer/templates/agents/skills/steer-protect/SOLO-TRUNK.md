# `/steer-setup protect` - verifying a solo-trunk repo

Read this file during `verify` when the repo's `CLAUDE.md` declares solo trunk
mode (`<!-- steer:delivery-mode=solo-trunk -->`), and not before. The
guardrails, the authorization boundary and `Verify` stay in `SKILL.md` and still
bind: this is report content only, and `verify` writes nothing.

## Graduation signals

Absent protection here is intentional (pre-MVP). Offer `apply` as graduation
once the MVP works or a deploy or second contributor is near. Report the
**graduation signals** alongside the protection diff:

- a second collaborator (`gh api repos/{owner}/{repo}/collaborators --jq
  'length'` > 1);
- a `prod`/`production` branch;
- a deploy target (deploy workflow / `infra/` tree).

When any holds, say so plainly and recommend graduating now. While the local
signals stand, the trunk-push hook surfaces the session's **first** `git push`
for a human yes (rule 45; repeats carry a non-blocking reminder), so graduating
also restores silent delivery. When only local signals hold and the dev intends
to stay single-dev on trunk, name `waive` as the other way to restore it. When
none holds, note that staying on solo-trunk is fine for now. (The SessionStart
`check-graduation.sh` hook surfaces the local signals each session; this is the
networked, on-demand check.)

## A recorded waiver

If a **waiver is recorded** (`<!-- steer:graduation=waived -->`), report it as
the standing decision: the local signals are expected and the hooks are silent
by design. The one thing that voids it is a **second collaborator** - when the
collaborator count is > 1, say the waiver no longer holds and recommend `apply`.

## Profile

The same count decides the **profile** finding: `profile: solo` with > 1
collaborator is drift to tighten (recommend `apply --team`); a graduating
solo-trunk repo with exactly 1 is where to offer `apply --solo`.

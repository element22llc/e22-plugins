---
paths:
  - "**"
---
<!-- steer:managed 99-end-of-session v6.0.0 body-cksum:2789236008 — installed by /steer:init / /steer:adopt and reconciled by /steer:sync. Edit the rule in the steer plugin, not here: a local edit is detected and preserved, but it will not reach any other repo. -->

## End-of-session checklist

Before wrapping up a working session, run this checklist and **report** its
state to the dev — don't silently close out, and don't turn the report into a
round of per-item confirmations (satisfied items need no ack; only genuinely
open items need the dev). Track open items with your todo tooling so nothing is
dropped:

- [ ] **Definition of Done holds** for every change made this session — spec and ADR written, tests added, living docs in sync, tracker refs recorded, drift resolved now rather than deferred to "later", review-sensitive classes flagged for the PR?
- [ ] Any unfinished work or known gaps surfaced explicitly to the dev?
- [ ] Worktree closing → dev servers and watchers you started stopped, freeing their ports? (On Claude Code steer's `WorktreeRemove` hook runs `docker:clean`, volumes included; `SessionEnd` only stops containers, keeps volumes, and often does not finish; a worktree removed by hand, or any other surface, still needs `mise run docker:clean` — Parallel worktrees.)
- [ ] GitHub-adopted repo: the active issue reflects progress, branch, blockers, and validation status; new unrelated bugs/gaps/follow-ups were captured as separate linked issues; the PR references the issue with the correct closing/non-closing relation?
- [ ] Any remaining scaffold placeholders flagged or resolved? (Unbootstrapped repo or legacy fork: run `/steer:init`.)
- [ ] All finished work committed on the working branch; if the change is complete, branch pushed and PR opened — or, in solo-trunk, the trunk commit pushed — with CI watched to green (see Commit autonomy)?
- [ ] Solo trunk mode and the MVP now works, you've deployed, or a second contributor joined → graduate to the PR flow via `/steer:protect` (Commit autonomy)?

If any item can't be satisfied, say so plainly rather than implying the work is
complete.

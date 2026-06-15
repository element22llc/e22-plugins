## End-of-session checklist

Before wrapping up a working session, present this checklist and confirm each
item with the dev — don't silently close out. Track open items with your todo
tooling so nothing is dropped:

- [ ] New feature → `intent.md` + `contract.md` created or updated (Spec workflow)?
- [ ] Architectural choice made → ADR written under `/spec/decisions/`?
- [ ] Tests added/updated for the change; bug fix has a regression test?
- [ ] Spec/code drift resolved now, not deferred to "later"? Review-sensitive changes flagged for the PR (Drift gates)?
- [ ] Living docs in sync — app guide updated for behavior changes, `/spec/HISTORY.md` entry appended, tracker refs recorded?
- [ ] Any unfinished work or known gaps surfaced explicitly to the dev?
- [ ] GitHub-adopted repo: the active issue reflects progress, branch, blockers, and validation status; new unrelated bugs/gaps/follow-ups were captured as separate linked issues; the PR references the issue with the correct closing/non-closing relation?
- [ ] Any remaining scaffold placeholders flagged or resolved? (Unbootstrapped repo or legacy fork: run `/e22-init`.)
- [ ] All finished work committed on the working branch; if the change is complete, PR proposed to the dev (see Commit autonomy)?

If any item can't be satisfied, say so plainly rather than implying the work is
complete.

<!-- steer:inject-when=code-project -->
## Definition of Done

A change is done when **all** of these hold. Reviewers check most of them; CI
enforces only a thin floor — in **solo-trunk**, where there is no reviewer, that
floor (the changed-line coverage gate, rule 41; the advisory spec-drift warning,
rule 55) is the *only* automated backstop. The rest is still on you.

Items marked **(size-gated)** follow the **Change-size model**: a **Tiny** change
needs only a PR.

- [ ] Code follows existing patterns in the touched app/package.
- [ ] Tests added or updated; bug fixes include a regression test that **fails before the fix and passes after**. **(size-gated)**
- [ ] Changed code is covered — critical paths, branches, and error handling exercised; no unexplained coverage drop on the lines this change touches (see Coverage).
- [ ] CI passes — watched to green after push, not assumed (see Commit autonomy).
- [ ] Spec updated if behavior changed — the relevant `contract.md`, or `intent.md` if scope changed (see Spec workflow).
- [ ] Living docs in sync — app guide, `ARCHITECTURE.md`, and a `/spec/history/` entry each updated when their trigger fired (see Living documentation).
- [ ] Review-sensitive classes flagged in the PR description (see Drift gates); tracker ref in the PR — or, in solo-trunk, in the closing commit (see Issue tracker).
- [ ] GitHub-adopted repo **(size-gated)**: the change has a GitHub issue; its `steer:state` reflects reality (work in progress → `validate`, never `done`); it is referenced with the correct closing/non-closing relation; discovered out-of-scope work was filed as separate linked issues (see Issue-first).
- [ ] Choices **costly to reverse** captured as an ADR under `/spec/decisions/` — reversal cost is the bar, not novelty (see Spec workflow).
- [ ] High-risk areas were scoped first (see High-risk areas).
- [ ] A dev approved the PR — except in solo-trunk (pre-MVP), where there is no PR gate (see Commit autonomy).

**Hotfix exception (see Hotfix / incident fast-path):** under a declared production
hotfix, items above may be **deferred** to the mandatory post-incident follow-up —
**never waived**. The follow-up backfills the issue, the spec/ADR, and the
`/spec/history/` entry so this list is satisfied once the fire is out.

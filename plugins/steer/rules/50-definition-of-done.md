## Definition of Done

A change is done when **all** of these hold. Reviewers check them; CI cannot.

- [ ] Code follows existing patterns in the touched app/package.
- [ ] Tests added or updated; bug fixes include a regression test that **fails before the fix and passes after**.
- [ ] Changed code is covered — critical paths, branches, and error handling exercised; no unexplained coverage drop on the lines this change touches (see Coverage).
- [ ] CI passes — watched to green after push, not assumed (see Commit autonomy).
- [ ] Spec updated if behavior changed — the relevant `contract.md`, or `intent.md` if scope changed (see Spec workflow).
- [ ] Living docs in sync — app guide (`/spec/app/`) updated if user-facing behavior or configuration changed; `ARCHITECTURE.md` updated if the stack, an app/package, or cross-component data flow changed; `/spec/HISTORY.md` entry appended (see Living documentation).
- [ ] Review-sensitive classes flagged in the PR description (see Drift gates); tracker ref in the PR — or, in solo-trunk, in the closing commit (see Issue tracker).
- [ ] GitHub-adopted repo: the change has a GitHub issue; its `steer:state` reflects reality (work in progress → `validate`, never `done`); the issue is referenced with the correct closing/non-closing relation — from the PR in PR flow, or from the closing commit (`Closes #N`) in solo-trunk; discovered out-of-scope work was filed as separate linked issues (see Issue-first).
- [ ] Architectural choices captured as an ADR under `/spec/decisions/`.
- [ ] High-risk areas were scoped first (see High-risk areas).
- [ ] A dev approved the PR — except in solo-trunk (pre-MVP), where `main` is intentionally unprotected and there is no PR gate until graduation (see Commit autonomy).

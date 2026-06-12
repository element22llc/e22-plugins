## Definition of Done

A change is done when **all** of these hold. Reviewers check them; CI cannot.

- [ ] Code follows existing patterns in the touched app/package.
- [ ] Tests added or updated; bug fixes include a regression test that **fails before the fix and passes after**.
- [ ] CI passes.
- [ ] Spec updated if behavior changed — the relevant `contract.md`, or `intent.md` if scope changed (see Spec workflow).
- [ ] Living docs in sync — app guide (`/spec/app/`) updated if user-facing behavior or configuration changed; `/spec/HISTORY.md` entry appended (see Living documentation).
- [ ] Review-sensitive classes flagged in the PR description (see Drift gates); tracker ref in the PR (see Issue tracker).
- [ ] Architectural choices captured as an ADR under `/spec/decisions/`.
- [ ] High-risk areas were scoped first (see High-risk areas).
- [ ] A dev approved the PR.

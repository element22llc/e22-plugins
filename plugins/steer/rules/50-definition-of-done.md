<!-- steer:inject-when=code-project -->
## Definition of Done

A change is done when **all five** of these hold:

- [ ] **Intent understood** - you can state what the change is for, and it is the change that was asked for.
- [ ] **Appropriately tested** - Testing rules; a bug fix carries a regression test that fails before and passes after.
- [ ] **CI green** - watched to conclusion after push, not assumed (Commit autonomy).
- [ ] **The contracts and docs this change actually affected are updated** - not a survey of every artifact: the ones this diff made wrong (Spec workflow, Living documentation).
- [ ] **Merge and deploy went through the required human gates** (Commit autonomy, You are not the gate).

That is the whole list. Everything else you owe a change is canonical in its own
rule and is not restated here - comments (Code comments), coverage (Coverage
rules), the changelog fragment and the tracker ref (Commit autonomy, Issue
tracker), the issue and its state (Issue-first), ADRs for choices costly to
reverse (Spec workflow), review-sensitive classes (Drift gates), high-risk
scoping (High-risk areas). Ceremony scales with the change (Change classification).

CI enforces only a thin floor - in **solo-trunk**, where there is no reviewer,
that floor (changed-line coverage, the changelog-fragment gate, the advisory
spec-drift warning) is the *only* automated backstop. The rest is on you.

**Hotfix exception (see Hotfix / incident fast-path):** under a declared production
hotfix these may be **deferred** to the mandatory post-incident follow-up -
**never waived**. The follow-up backfills the issue, the spec or ADR, and the
`/spec/history/` entry so this list is satisfied once the fire is out.

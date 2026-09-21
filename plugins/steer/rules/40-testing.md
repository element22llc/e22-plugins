<!-- steer:inject-when=code-project -->
## Testing

- Every feature change **includes or updates automated tests** in the same PR - never "later."
- Every bug fix **MUST add a regression test** that fails before the fix and passes after. This is a hard rule.
- Do **not** delete or skip failing tests to make CI pass. Fix the cause, or explicitly remove the behavior and say so in the PR.

**Coverage is a signal to find untested behavior, not a target to hit** - never
write a shallow test, or relax an assertion, to move a number. **Cover what you
touch**: new and changed code paths ship exercised, prioritising critical paths,
branches and error handling over blanket line percentage. It is measured every
run, and a drop on changed code is **drift** - surface it (Drift gates). There
is no global "fail under N%" gate; CI gates changed-line coverage only, and the
reviewer judges adequacy.

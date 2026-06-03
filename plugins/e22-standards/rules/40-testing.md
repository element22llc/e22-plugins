## Testing rules

- Every feature change **includes or updates automated tests** in the same PR — never "later."
- Every bug fix **MUST add a regression test** that fails before the fix and passes after. This is a hard rule.
- Do **not** delete or skip failing tests to make CI pass. Fix the cause, or explicitly remove the behavior and say so in the PR.

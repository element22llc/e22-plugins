<!-- e22:schema=1 -->
<!-- e22:kind=audit-finding -->
<!-- e22:finding-key=DIMENSION:RULE:FILE_OR_COMPONENT:SYMBOL -->
<!-- e22:audit-id=AUDIT_ID -->
<!-- e22:audit-commit=COMMIT_SHA -->
<!-- e22:managed:start -->
## Finding

[What is wrong, conceptually — the durable defect, not the line numbers. The
`finding-key` marker above is the stable identity used to reconcile this finding
across audit runs; it is never line-based.]

## Evidence

- `path/to/file.ts:42-186` — [current observed evidence; may change run to run
  without forging a new finding]

## Standard missed

[Which E22 standard or principle this violates.]

## Impact

[High / Medium / Low and why — what it costs or risks.]

## Suggested remediation

[Concrete next step. Defer correctness to /code-review, security to
/security-review, mechanical cleanup to /simplify — name the skill, don't re-run
it here.]

## Origin

- **Parent audit:** #PARENT_RUN
- **Audited commit:** `COMMIT_SHA`
- **Resolution mode (on close):** [deterministic — no longer reproduces | reviewer-confirmed — judgment call]
<!-- e22:managed:end -->

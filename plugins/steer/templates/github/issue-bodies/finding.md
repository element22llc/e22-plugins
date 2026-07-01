<!-- steer:schema=2 -->
<!-- steer:kind=finding -->
<!-- steer:state=inbox -->
<!-- steer:source=audit -->
<!-- steer:finding-key=SOURCE_OR_DIMENSION:RULE:FILE_OR_COMPONENT:SYMBOL -->
<!-- steer:evidence=EVIDENCE_FINGERPRINT -->
<!-- steer:audit-id=AUDIT_ID -->
<!-- steer:audit-commit=COMMIT_SHA -->
<!-- steer:parent-issue=PARENT_RUN -->
<!-- steer:managed:start -->
## Finding

[What is wrong, conceptually — the durable defect, not the line numbers. The
`finding-key` marker above is the stable identity used to reconcile this finding
across runs; it is never line-based. Set `steer:source` to the origin —
`audit` · `adoption` · `security-review` · `code-review` · `ci` ·
`dependency` · `implementation`.]

## Evidence

- [`path/to/file.ts:42-186`](REPO_BLOB_BASE/path/to/file.ts#L42-L186) — [current
  observed evidence; may change run to run without forging a new finding]

> Security findings (`source:security-review`): redact secrets and
> exploit-enabling detail here — link to private handling rather than publishing
> sensitive evidence into a broadly visible issue.

## Standard missed

[Which standard or principle this violates.]

## Impact

[High / Medium / Low and why — what it costs or risks.]

## Suggested remediation

[Concrete next step. Defer correctness to /code-review, security to
/security-review, mechanical cleanup to /simplify — name the skill, don't re-run
it here.]

## Origin

- **Source:** [audit | adoption | security-review | code-review | ci | dependency | implementation]
- **Parent record:** #PARENT_RUN (audit runs only; omit otherwise)
- **Observed commit:** `COMMIT_SHA`
- **Resolution mode (on close):** [deterministic — no longer reproduces | reviewer-confirmed — judgment call]
<!-- steer:managed:end -->

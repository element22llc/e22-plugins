<!-- steer:schema=2 -->
<!-- steer:kind=spec-drift -->
<!-- steer:state=inbox -->
<!-- steer:source=spec -->
<!-- steer:feature-id=FEATURE_ID -->
<!-- steer:spec-path=spec/features/FEATURE_ID/contract.md -->
<!-- steer:managed:start -->
## Spec says

[The intended behavior, quoted from the spec, with the artifact it comes from.]

## Implementation does

[The actual as-built behavior.]

## Evidence

- Spec: [`spec/features/FEATURE_ID/contract.md:NN`](REPO_BLOB_BASE/spec/features/FEATURE_ID/contract.md#LNN)
- Code: [`src/.../file.ts:NN`](REPO_BLOB_BASE/src/.../file.ts#LNN)

## Human decision required

The agent may propose a direction but must **not** resolve behavioural drift
autonomously — a PO or dev decides by ownership.

- [ ] Change the implementation to match the spec
- [ ] Approve the as-built behavior and update the spec
- [ ] Replace both with another decision

[Note which path needs PO approval (user-facing change) vs dev approval
(internal/architectural).]
<!-- steer:managed:end -->

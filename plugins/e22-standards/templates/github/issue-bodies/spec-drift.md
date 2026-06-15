<!-- e22:schema=1 -->
<!-- e22:kind=spec-drift -->
<!-- e22:feature-id=FEATURE_ID -->
<!-- e22:spec-path=spec/features/FEATURE_ID/contract.md -->
<!-- e22:managed:start -->
## Spec says

[The intended behavior, quoted from the spec, with the artifact it comes from.]

## Implementation does

[The actual as-built behavior.]

## Evidence

- Spec: `spec/features/FEATURE_ID/contract.md:NN`
- Code: `src/.../file.ts:NN`

## Human decision required

The agent may propose a direction but must **not** resolve behavioural drift
autonomously — a PO or dev decides by ownership.

- [ ] Change the implementation to match the spec
- [ ] Approve the as-built behavior and update the spec
- [ ] Replace both with another decision

[Note which path needs PO approval (user-facing change) vs dev approval
(internal/architectural).]
<!-- e22:managed:end -->

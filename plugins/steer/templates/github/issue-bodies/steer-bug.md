<!-- steer:self-report=1 -->
<!-- steer:fault-fingerprint=SOURCE:SIGNATURE -->
## What steer did wrong

[One or two sentences: the plugin defect — contradictory skill instruction,
missing/broken template or script, or a recorded hook fault. The symptom, not a
stack trace.]

## Where it happened

- **Surface:** [skill `/steer:<name>` | rule NN-<slug> | hook <name>.sh | template/script path]
- **steer version:** [from the SessionStart banner / plugin.json]
- **Trigger:** [what the user asked for / what was running when it broke]

## Captured output

```
[Verbatim error text or hook output, SCRUBBED — no absolute paths (rewrite to
<repo>/…), no secrets, no product source. Omit this block if there is none.]
```

## Expected behavior

[What steer should have done instead.]

## Reproduction

1. [Minimal trigger, in terms of steer surfaces — not product specifics.]

## Notes

[Anything else useful to a maintainer. Whether a workaround was applied.]

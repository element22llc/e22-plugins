---
paths:
  - "**"
---
<!-- steer:managed 80-change-size — installed by /steer:init / /steer:adopt and reconciled by /steer:sync. Edit the rule in the steer plugin, not here. -->

## Change-size model

Match the workflow to the change. When uncertain, size **up**. **This rule sets
per-change ceremony** — Issue-first and Definition of Done take their thresholds
from here, and an arguable class takes the larger one.

- **Tiny** (≈<20 lines, **no behavior change** — copy, typo, formatting, comment):
  open a PR and stop — **no issue, no spec, no ADR, no plan**; the PR is the
  evidence anchor. Any behavior change is Small at minimum, however few the lines.
- **Small** (≈<200 lines, contained behavior change): confirm intent; update `contract.md` if behavior changed.
- **Medium** (new screen/feature/capability): write `intent.md` first, get PO approval, then implement with `contract.md`.
- **Large** (crosses areas, touches infra, or a choice costly to reverse): write an ADR in `/spec/decisions/` first, agree with the team, then ship in small PRs. A first-time pattern is not itself Large.
- **Risky** (any high-risk area, regardless of line count): follow high-risk handling above — never Tiny.

**Medium** and larger start in plan mode (or a posted plan): review the
approach while it's cheap to change.

<!-- steer:inject-when=code-project -->
## Change-size model

Match the workflow to the change. When uncertain, size **up**.

- **Tiny** (≈<20 lines, no logic change — copy, padding, typo): just open a PR.
- **Small** (≈<200 lines, contained behavior change): confirm intent; update `contract.md` if behavior changed.
- **Medium** (new screen/feature/capability): write `intent.md` first, get PO approval, then implement with `contract.md`.
- **Large** (crosses areas, new pattern, touches infra): write an ADR in `/spec/decisions/` first, agree with the team, then ship in small PRs.
- **Risky** (any high-risk area, regardless of line count): follow high-risk handling above.

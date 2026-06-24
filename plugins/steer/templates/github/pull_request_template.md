## What does this PR do?

One or two sentences.

## Related issue

Reference the tracker item(s) this PR implements, using the product's tracker
conventions (`/spec/tracker.md`) — e.g. `Closes #123` (GitHub Issues),
`PROJ-123` (Jira), `ENG-123` (Linear), `AB#123` (Azure DevOps). Write `none`
only for work with no tracked item, and say why.

Closes #

## Type of change

- [ ] Feature — new behavior
- [ ] Bug fix — corrects existing behavior
- [ ] Refactor — no behavior change
- [ ] Spec update — no code change
- [ ] Infrastructure
- [ ] Documentation

## Spec sync

If this PR changes user-facing behavior, did you update the relevant spec?

- [ ] Yes — updated `/spec/features/[id]/contract.md`, or `intent.md` if scope changed
- [ ] No — this PR has no behavior change, such as refactor, copy fix, dependency bump, or internal cleanup
- [ ] Spec-only PR — no code change
- [ ] If the originating issue linked a Claude Design URL (or other design source), it is captured in `/spec/features/[id]/intent.md` under `Design source`

## Review-sensitive flags (drift gates)

Check every class that applies — each checked item is a flag the reviewer must
explicitly resolve before merge, not a formality. Leave all unchecked only if
none apply.

- [ ] **Intent drift** — delivered behavior differs from the approved `intent.md` / what the PO asked for
- [ ] **Contract drift** — behavior differs from the owning `contract.md` (or the contract was changed to match)
- [ ] **Undocumented behavior change** — user-visible behavior changed somewhere no spec covers yet
- [ ] **Security-sensitive** — auth, authorization, secrets, input validation, data exposure
- [ ] **Compliance-impacting** — audit trails, retention, access control, personal data handling
- [ ] **Operational** — deployment, CI/CD, infra, monitoring, backups
- [ ] **Local setup / deployment changed** — `mise.toml`, `compose.yaml`, `.env.example`, setup docs need updating
- [ ] **App docs invalidated** — `/spec/app/` (usage, roles, configuration, troubleshooting) describes behavior this PR changes
- [ ] **Architecture/stack drift** — `ARCHITECTURE.md` describes the stack, an app/package, or data flow this PR changes

## Living docs sync

- [ ] `/spec/HISTORY.md` has an entry for this change (what, why, who asked, refs)
- [ ] `/spec/app/` updated if user-facing behavior or configuration changed
- [ ] `ARCHITECTURE.md` updated if the stack, an app/package, or cross-component data flow changed
- [ ] N/A — no behavior, setup, or decision change

## PO acceptance

If this PR changes user-facing behavior, has the PO approved the intent or requested change?

- [ ] Yes — PO approval is linked or visible in the issue/PR thread
- [ ] Not yet — this PR should not merge until PO intent is clear
- [ ] N/A — no user-facing behavior change

## Implementation pointers

Pointers are a hint, not a maintained index (the spec ↔ code coupling rules come from the `steer` plugin — run `/steer:reference conventions`).

- [ ] If this feature moved to a different app/package, updated the owning app/package named in its `contract.md`
- [ ] N/A — no structural change

## Testing

Per the [Definition of Done](../CLAUDE.md#definition-of-done). These are
review aids, not CI gates.

- [ ] Added or updated automated tests for this change (same PR, not "later")
- [ ] **Bug fix:** added a regression test that fails before the fix and passes after
- [ ] Changed code is covered — critical paths/branches/errors exercised, no unexplained coverage drop on touched lines
- [ ] N/A — no behavior change (refactor, copy, dependency bump, docs)
- [ ] Manually tested locally
- [ ] Will validate in non-prod after merge

## Checklist

- [ ] Self-reviewed the diff
- [ ] CI passes locally or in GitHub Actions
- [ ] No secrets, keys, or credentials in the diff
- [ ] High-risk areas were explicitly scoped by a dev before implementation

## Notes for the reviewer

Anything reviewers should pay special attention to?

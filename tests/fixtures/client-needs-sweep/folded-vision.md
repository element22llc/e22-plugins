# Vision

## Open questions

### Q-001 - Should archived invoices be shown by default?
- created: 2026-09-20
- status: resolved
- impact: non-blocking
- owner: product
- required_before: intent-approval
- tracker:

_Resolution:_ Hidden by default behind an "Archived" filter. Source: spec/sources/clarifications-2026-10/answers.md "No - hidden behind an \"Archived\" filter."

### Q-002 - Do we bill per seat or per workspace for the first release?
- created: 2026-10-07
- status: resolved
- impact: blocking
- owner: product
- kind: decision
- required_before: intent-approval
- tracker: #412

_Resolution:_ Bill per workspace for the first release. Source: spec/sources/clarifications-2026-10/answers.md "Per workspace."

### Q-003 - Who should be invited to the AWS account as deployer for prod?
- created: 2026-10-07
- status: resolved
- impact: blocking
- owner: security
- kind: access
- required_before: production-release
- tracker:

Evidence: `policy/delivery.yml` `production_gate: prod-branch-pr`, no deploy target recorded.

_Resolution:_ Client invites ops@client.example as deployer, role DeployRole - no credential exchanged. Source: spec/sources/clarifications-2026-10/answers.md "Invite ops@client.example as deployer".

### Q-004 - Which error-tracking account should the deployed app report to?
- created: 2026-10-07
- status: resolved
- impact: non-blocking
- owner: development
- kind: tooling
- required_before: non-prod-validation
- tracker:

Evidence: `policy/delivery.yml` `observability: []`.

_Resolution:_ Report to the client's existing Sentry org "client-prod"; client invites the dev lead. Source: spec/sources/clarifications-2026-10/answers.md "Use our existing Sentry org".

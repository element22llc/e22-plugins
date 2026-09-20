<!-- steer:inject-when=has-iac|has-apps -->
## Deployment & environments

How code reaches users is **declared by the repo, not imposed here**:
`policy/delivery.yml` names its environments, what merging deploys, how
production is approved (`production_gate`), whether review apps exist, and what
it reports to a human. Read it before saying anything about this repo's
delivery; if it is missing, ask and seed it from the bundled template. Deploy
and release logic is a high-risk area (see High-risk areas) - scope pipeline
changes with the dev, and validate in non-prod where the declared model has one.

- **Follow the declared model**, and never push directly to a protected branch
  whatever the gate. `/steer:protect` applies the GitHub side of it.
- **Merge and deploy stay human, in every model.** A gate declares *which*
  human step applies, never that there is none (Commit autonomy).
- **Observable by default** - logs, metrics with alarms, error tracking, health
  checks, alerting a human sees, wiring recorded in `ARCHITECTURE.md`. An empty
  `observability` list is allowed: unobservable is a **flag to raise**, not a
  rule to break.
- **Rollback** - every production deploy has a known one (revert the promotion,
  redeploy the prior SHA); migrations are expand/contract so the previous
  version survives the deploy (see High-risk areas).
- **Secrets at rest** - injected at deploy/runtime, never baked into images or
  CI logs (see Secrets handling).

The org's default shape, and why it gates prod on a branch, is the seeded
`policy/delivery.yml` plus `/steer:reference conventions`. A repo that delivers
differently edits that file; only a *weaker* gate needs an ADR.

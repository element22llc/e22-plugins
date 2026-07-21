<!-- steer:inject-when=has-iac|has-apps -->
## Deployment & environments

How code reaches users. Deploy/release logic is a high-risk area (see High-risk
areas) — validate in non-prod before prod, and scope pipeline changes with the
dev first. AWS/Terragrunt specifics live in the infra README (`/infra/README.md`
for a nested infra dir, the root README for an infra-profile repo); rationale in
`/steer:reference conventions`. The AWS app-promotion model below is the default —
an infra-profile repo with a different target records its flow in an ADR.

- **Environments** — `non-prod` (shared validation) and `prod`. Every feature PR
  also gets an isolated, auto-provisioned **review app**, torn down when the PR
  merges or closes. The review-app mechanism is product-specific — record it in an
  ADR (see Decision capture).
- **Promotion** — merge to `main` **auto-deploys non-prod**. Prod is gated by a
  **reviewed PR from `main` into a long-lived `prod` branch**; merging that PR
  **auto-deploys prod**. Never push directly to `prod`. The branch-protection
  approval on `prod` *is* the production gate (run `/steer:protect`), standing in
  for deployment-environment approvals that GitHub Enterprise would otherwise
  provide.
- **Observable by default** — a deployed environment ships logs, metrics with
  alarms, error tracking (Sentry), health checks, and alerting routed somewhere a
  human sees it. "Deployed but unobservable" is not done; capture the wiring in
  `ARCHITECTURE.md`.
- **Rollback** — every prod deploy has a known rollback: revert the `prod` merge or
  redeploy the prior SHA. Database migrations are expand/contract so the previous
  version keeps running through a deploy (see High-risk areas).
- **Secrets & config at rest** — injected at deploy/runtime, never baked into images
  or CI logs (see Secrets handling).

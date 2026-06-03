## High-risk areas

These require **explicit dev scoping before broad changes** — do not propose
architectural changes here speculatively:

- **Auth & sessions** — sign-in/up, password reset, token issuance, session invalidation
- **Authorization & permissions** — role checks, access control, multi-tenancy boundaries
- **Database migrations** — schema changes, backfills, migration scripts
- **Infrastructure** — anything in `/infra`, especially networking, IAM, Secrets Manager
- **Secrets handling** — anything reading, writing, or transmitting credentials/keys/tokens
- **Deletion logic** — hard deletes, cascading deletes, retention/cleanup jobs
- **Billing & payments** — pricing, charging, refunds, subscription state
- **Deployment & release logic** — CI/CD workflows, release scripts, feature-flag rollouts

How to handle these: scope manually with the dev **before** any code; write the
contract or ADR first; keep PRs smaller than usual; the dev reviews
line-by-line; validate in non-prod before prod. `@claude implement this` is not
appropriate here without a comment naming what is in and out of scope.

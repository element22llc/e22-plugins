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

Handling: scope with the dev **before** any code; contract or ADR first;
smaller PRs; line-by-line review; validate in non-prod before prod. `@claude
implement this` is not appropriate here without explicit in/out scope.

**Pre-production relaxation:** these gates protect real systems and real data.
While a product is **pre-production** (nothing deployed, no real users or
data), high-risk areas may be built for real locally without prior dev
scoping — document the choices as you go (`contract.md`, ADR for
hard-to-reverse picks, `/spec/SPEC-QUESTIONS.md` for open items) and list them
in the PR description so dev review hardens them at productionization.
"Pre-production" is a property of the **product, not the laptop**: working
locally in a deployed product still produces migrations/deletions that reach
real data on merge — no relaxation there. **Never relaxed**, even
pre-production: real secrets/credentials, `/infra`, deploys, real third-party
calls.

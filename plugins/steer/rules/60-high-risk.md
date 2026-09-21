## High-risk areas

These require **explicit dev scoping before broad changes** - do not propose
architectural changes here speculatively:

- **Auth & sessions** - sign-in/up, password reset, token issuance, session invalidation
- **Authorization & permissions** - role checks, access control, multi-tenancy boundaries
- **Database migrations** - schema changes, backfills, migration scripts
- **Infrastructure** - anything in `/infra`, especially networking, IAM, secret stores
- **Secrets handling** - anything reading, writing, or transmitting credentials/keys/tokens
- **Deletion logic** - hard deletes, cascading deletes, retention/cleanup jobs
- **Billing & payments** - pricing, charging, refunds, subscription state
- **Deployment & release logic** - CI/CD workflows, release scripts, feature-flag rollouts

Handling: scope with the dev **before** any code; contract or ADR first;
smaller PRs; line-by-line review; validate in non-prod before prod. `@claude
implement this` is not appropriate here without explicit in/out scope.

**Pre-production relaxation:** while a product is **pre-production** (nothing
deployed, no real users or data), these areas may be built for real locally
without prior dev scoping - document the choices as you go (`contract.md`, an
ADR for a hard-to-reverse pick, `## Open questions` for the rest) and list them
in the PR so dev review hardens them at productionization. "Pre-production" is a
property of the **product, not the laptop**: working locally in a deployed
product still produces migrations and deletions that reach real data on merge.
**Never relaxed**, even pre-production: real secrets or credentials, `/infra`,
deploys, real third-party calls.

### Secrets handling

- **Never commit a secret** - not in code, configs, `mise.toml`, specs, or
  commit messages. A committed one is compromised: stop, tell the dev, and
  rotate it; don't just delete the line.
- **Local development:** config lives in a git-ignored `.env` / `.env.local`.
  Make sure it exists with the variables the app needs to boot - local Compose
  service URLs and freshly generated local-only values, never anything copied
  from a deployed environment. Document the *names* in `.env.example`. A
  worktree starts from git refs only, so the repo-root `.worktreeinclude`
  carries `.env` into each new one.
- **Deployed environments:** secrets live in **the declared store** - the org
  pack's, or an ADR's if this repo chose another - injected at deploy/runtime,
  never baked into images or CI logs. No declared store yet is a question for
  the dev, not a default you pick. Non-secret config may live in `mise.toml`'s
  `[env]`; secrets may not.

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

**Pre-production relaxation:** while the product is pre-production (nothing
deployed, no real users or data), these areas may be built for real locally
without prior scoping - document each choice as you go and list them in the PR
so review hardens them at productionization. Pre-production is a property of the
**product, not the laptop**. **Never relaxed:** real secrets or credentials,
`/infra`, deploys, real third-party calls.

### Secrets handling

- **Never commit a secret** - not in code, configs, `mise.toml`, specs, or
  commit messages. A committed one is compromised: stop, tell the dev, and
  rotate it; don't just delete the line.
- **Local development:** config lives in a git-ignored `.env` / `.env.local`,
  holding what the app needs to boot - local Compose URLs and freshly generated
  local-only values, never anything copied from a deployed environment. Document
  the *names* in `.env.example`; `.worktreeinclude` carries the file into each
  new worktree.
- **Deployed environments:** secrets live in **the declared store** - the org
  pack's, or an ADR's if this repo chose another - injected at deploy/runtime,
  never baked into images or CI logs. No declared store yet is a question for
  the dev, not a default you pick. Non-secret config may live in `mise.toml`'s
  `[env]`; secrets may not.

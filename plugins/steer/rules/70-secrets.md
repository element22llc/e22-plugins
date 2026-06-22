## Secrets handling

Secrets (DSNs, API tokens, DB credentials, `AUTH_SECRET`, AWS keys) are a
high-risk area — scope with the dev before touching how they are read, written,
or transmitted.

- **Never commit secrets** — not in code, configs, `mise.toml`, specs, or
  commit messages.
- **Local development:** config lives in a git-ignored `.env` / `.env.local`.
  When setting up or running an app, make sure it exists with the base
  variables the app needs to boot — local Compose service URLs (e.g.
  `DATABASE_URL` → the local PostgreSQL) and freshly generated local-only
  secrets, never values copied from deployed environments. Document variable
  *names* (not values) in the app's `.env.example`. A Claude Code worktree
  (`claude --worktree`) starts from git refs only, so the git-ignored `.env` is
  absent there — the repo-root `.worktreeinclude` carries it (and other local
  config) into each new worktree so the app still boots.
- **Deployed environments:** secrets live in **SSM Parameter Store
  (`SecureString`)** by default — it is cheaper than Secrets Manager and covers
  most needs (DSNs, tokens, DB credentials). Use **AWS Secrets Manager** only when
  you actually need its features: automatic rotation, cross-account sharing, or
  large/binary values. Either way they are injected at deploy/runtime — never
  baked into images or CI logs. Non-secret config may live in `mise.toml`'s
  `[env]` block; secrets must not.
- A committed secret is compromised: stop, tell the dev, and rotate it — don't
  just delete the line.

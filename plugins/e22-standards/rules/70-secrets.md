## Secrets handling

Secrets (DSNs, API tokens, DB credentials, `AUTH_SECRET`, AWS keys) are a
high-risk area — scope with the dev before touching how they are read, written,
or transmitted.

- **Never commit secrets.** No secret values in git — not in code, configs,
  `mise.toml`, specs, or commit messages. `.env` / `.env.local` are git-ignored
  and hold local secrets; there is no committed `.env.example`.
- **Local development:** put config in a git-ignored `.env` / `.env.local`.
  Document the *names* of required variables (not their values) in the relevant
  app's `README.md`.
- **Deployed environments:** store secrets in **AWS Secrets Manager** and inject
  them at deploy/runtime — never bake them into images or CI logs.
- **Non-secret config** may live in `mise.toml`'s `[env]` block; secrets must
  not.
- If you find a secret committed, treat it as compromised: stop, tell the dev,
  and rotate it — don't just delete the line.

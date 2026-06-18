# infra/ — Element 22 infrastructure (DNS for the docs site)

OpenTofu + Terragrunt for the AWS resources behind the docs site at
**<https://ai.element-22.com>**. Today that is exactly one resource: the Route 53
`CNAME` pointing `ai.element-22.com` at the Cloudflare Pages project.

```
ai.element-22.com (Route 53, this code)
    └─CNAME→ e22-ai-docs.pages.dev (Cloudflare Pages — dashboard)
                 └─ served through Cloudflare edge, gated by Cloudflare Access
```

Everything Cloudflare-side (the Pages project, the custom domain, the Access
application, and the GitHub identity provider) is **click-ops in the Cloudflare
dashboard** — see [Cloudflare runbook](#cloudflare-runbook-one-time) below.

## Prerequisites

- `mise` — installs the pinned `opentofu` + `terragrunt` (see `mise.toml`).
  OpenTofu must be ≥ 1.10 for native S3 state locking.
- AWS access to account **053932564353** via SSO. The toolchain reads the
  repo-local `aws/config` (set through `AWS_CONFIG_FILE` in `mise.toml`); sign in
  once per session with `mise run aws:sso:login`. The provider pins
  `allowed_account_ids`, so a wrong-account credential fails fast.
- A state bucket **`element22-tofu-state`** in that account (us-east-1),
  with versioning enabled. State locking is native (`use_lockfile = true`) — no
  DynamoDB table needed. Create/confirm the bucket before the first apply.
- To test the Cloudflare deploy locally: copy `.env.example` → `.env` (gitignored)
  and fill in `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID`. mise installs
  `wrangler` (pinned in `mise.toml`) and loads `.env` automatically.

## Layout

```
infra/
├── mise.toml                  # opentofu + terragrunt versions, AWS SSO, tf:* tasks
├── aws/config                 # repo-local AWS SSO config (AWS_CONFIG_FILE)
├── root.hcl                   # root: S3 remote state (use_lockfile) + aws provider
└── live/
    └── shared_services/
        ├── terragrunt.hcl     # include "root" (root.hcl) + inputs: pages_hostname, ttl
        └── main.tf            # data zone lookup + aws_route53_record CNAME
```

> The root config is named `root.hcl` (not `terragrunt.hcl`) — Terragrunt now
> flags a `terragrunt.hcl` root as a deprecated anti-pattern. Child units
> reference it with `find_in_parent_folders("root.hcl")`.

## Usage

Run from inside `infra/`:

```sh
mise run aws:sso:login # sign in to AWS SSO (once per session)
mise run tf:fmt        # format HCL + tofu
mise run tf:validate   # validate the DNS unit
mise run tf:plan       # preview the CNAME change
mise run tf:apply      # create/update the CNAME
```

The CNAME target is the `pages_hostname` input in
`live/shared_services/terragrunt.hcl` — set it to the `<project>.pages.dev` value
Cloudflare gives you when you add the custom domain (step 2 below), then apply.

### Test the Cloudflare deploy locally

Mirror the CI deploy from your machine before pushing — same build, same
`wrangler pages deploy`, but to a **preview** deployment so production
(`ai.element-22.com`) is untouched:

```sh
mise run cf:check           # confirm CLOUDFLARE_* creds resolve (wrangler whoami)
mise run cf:deploy:preview  # build docs/ + deploy a preview; prints a *.pages.dev URL
```

`cf:deploy:preview` builds the site from the repo root and deploys with
`--branch=local-preview`; any branch other than the project's production branch
yields a throwaway preview URL. Open that URL to confirm the deploy works, then
let CI handle the production deploy on merge to `main`.

### Test Cloudflare Access

Access is enforced at Cloudflare's **edge against a hostname** — there is no
`localhost` to test against. Two separate things to verify:

- **Enforcement (is it locked, not public?)** — scriptable:

  ```sh
  mise run cf:access:verify                       # defaults to https://ai.element-22.com
  mise run cf:access:verify https://<preview>.pages.dev
  ```

  It expects a redirect to the Access login (`*.cloudflareaccess.com`); a public
  `200` fails the task. Run it in CI or before cutover to prove the site isn't
  exposed.

- **Login path (can an `@element-22.com` GitHub user get in?)** — browser only.
  Open the URL in an **incognito** window and complete the GitHub login; CLIs
  can't drive the interactive OAuth flow. To rehearse this without touching
  production, enable **Settings → General → Enable access policy** on the Pages
  project (it protects only the preview `*.pages.dev` deployments), then test
  against the `cf:deploy:preview` URL.

## Cloudflare runbook (one-time)

Do these in the Cloudflare dashboard, in order:

1. **Pages project** — create a project named `e22-ai-docs` as **Direct Upload**
   (no Git connection; GitHub Actions pushes builds via
   `cloudflare/wrangler-action`). The first deploy from
   `.github/workflows/docs-deploy.yml` also creates it if absent.
2. **Custom domain** — project → Custom domains → add `ai.element-22.com`.
   Cloudflare shows a `<project>.pages.dev` CNAME target → put it in
   `live/shared_services/terragrunt.hcl` (`pages_hostname`) and `mise run tf:apply`.
   Cloudflare auto-validates and issues the TLS cert once the CNAME resolves.
3. **GitHub identity provider** — Zero Trust → Settings → Authentication → add
   **GitHub** login (creates/uses a GitHub OAuth app; callback to
   `<team>.cloudflareaccess.com/cdn-cgi/access/callback`).
4. **Access application** — Zero Trust → Access → Applications → **Self-hosted**,
   hostname `ai.element-22.com`. Policy: **Include → Emails ending in
   `@element-22.com`**, identity provider = GitHub.

### GitHub secrets for the deploy workflow

Add under repo Settings → Secrets and variables → Actions:

- `CLOUDFLARE_API_TOKEN` — token scoped to *Account → Cloudflare Pages → Edit*.
- `CLOUDFLARE_ACCOUNT_ID` — the Cloudflare account ID.

## Notes / gotchas

- The `@element-22.com` Access policy matches the email GitHub returns. A user
  whose GitHub primary email is private (`…@users.noreply.github.com`) won't
  match — they must expose a verified `@element-22.com` email on GitHub, or you
  add a One-Time-PIN fallback rule.
- The `element-22.com` zone stays in Route 53; we do **not** delegate NS to
  Cloudflare. Access works over the external CNAME because the Pages custom
  domain is served through Cloudflare's edge.
- Cloudflare Access needs Zero Trust enabled on the account (free tier ≤ 50
  seats is sufficient).

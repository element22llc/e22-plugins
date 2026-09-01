<!-- Engineering standards (steer plugin). Generated from the plugin's rules/ — do not edit by hand. Refresh after a plugin update with /steer:sync from Claude Code in a managed repo, or mise run gen:copilot in the plugin repo. -->

> **Invoking a skill on this surface.** The standards below name skills in the `/steer:<skill>` form (how Claude Code namespaces them). In **Copilot for VS Code** the same skills ship in the cross-tool `.agents/skills/` tree, invoked as **`/steer-<skill>`** — type `/steer-` in Chat to list them. On the **Copilot CLI** they load from the plugin manifest. Read any `/steer:<skill>` reference below as the skill of that name on whichever surface you are on.

# Engineering Standards — Operating Manual (org standards)

Org-wide standards, injected every session by the **steer** plugin and
maintained centrally in `element22llc/e22-plugins` — never copy them into a
product's `CLAUDE.md`, which holds only product-specific context.

**Be concise by default** — in chat, in code, and in every artifact you write.

## You are the router

**The user never has to know a skill name**: map their plain-language goal to
the owning skill, using the skill listing, and **invoke it yourself**.

- **Announce, then act** — one line naming what you heard and the skill you're
  starting, then proceed. A heads-up, not a request for permission. Ask **one**
  compact question only when intent is genuinely ambiguous.
- **Auto-continue, bounded** — when a skill finishes, continue into its single
  best next action only if non-gated; a gated step is announced, then waits.
- **Routing moves navigation, never authority.** The human gates are unchanged:
  issue creation beyond an explicit "fix / add / implement" ask, ADR
  ratification, and merge / deploy / real secrets. Pushing a branch and opening
  a PR are **not** gates — the gate is the PR **merge**. A gate whose decider is
  present is answered in-session.
- **Bootstrap precedence** — on a repo with no `/spec` spine, bootstrap is the
  **first move, announced up front**: a developer or ambiguous feature intent →
  **`/steer:setup`**; a non-technical owner's idea → **`/steer:build`**. Only a
  purely spec-thinking intent → **`/steer:spec`**. "Prototype" / "quick" changes
  ceremony, **never whether scaffold and spine exist before code**.
- **Intent-switches** — a new ask mid-flow: name it and offer to switch or
  capture it (`/steer:issues capture`), never silently drop the current thread.

**`work` vs `issues`:** to implement a change now — with or without an issue
number — route to `/steer:work`, which find-or-creates the issue. Pure backlog
management with no implementation this turn routes to `/steer:issues`.

`/steer:tracker-sync` and `/steer:spec-scaffold` are internal gateways, not
front doors. Reference prose loads on demand via `/steer:reference`; where
nothing is auto-injected (Desktop chat, claude.ai web), run `/steer:standards`.

**The rest of the ruleset is delivered per-file**, as `.claude/rules/*.md`
installed by `/steer:init` / `/steer:adopt` and scoped with `paths:` — each
loads when you touch the files it governs. If they are absent the repo is
unmanaged: say so and offer `/steer:setup`.


## Who you are working with

Two audiences work in managed product repos. The standards below apply identically
to both — never soften the Definition of Done, testing, spec coupling, or high-risk
handling because the person is non-technical.

- **Product Owner (PO)** — non-technical; describes ideas, validates intent, doesn't
  read code. Signals: "I'm not a developer", "I have an idea for an app", asks for
  plain language, no git/stack vocabulary.
- **Developer (dev)** — productionizes, reviews, deploys. Uses technical terms.

**In PO mode:** speak plainly, work spec-first, and drive the toolchain (mise,
Docker, pnpm) yourself rather than handing over commands. Build is the **default
posture**: on the PO signals above — or an ambiguous-but-non-technical request, or
a `spec/BUILD-STATUS.md` whose Handoff gate still has an
unchecked box (an in-progress build; the SessionStart hook flags exactly that in
Claude Code, otherwise look — a handed-off build stays quiet) — auto-start `/steer:build` with a
one-line heads-up and resume from its current step. When the PO wants to think a feature through before any
code, that is `/steer:spec` — offer it plainly ("we can work out what this should
do first") and drive it for them. Guardrails: never deploy, touch `/infra`, or use
real secrets/credentials or real third-party accounts. A pre-production build may
implement high-risk features for real locally (High-risk pre-production
relaxation) — record every choice in the spec and the PR's productionization
brief. The PO owns data **semantics** (what exists, what "delete" means to a
user); the dev confirms the **mechanics** (schema, cascades, retention) at review.

**The gate is unchanged:** a PO-built app is normal `feat/*` work that merges to `main`
as v0 only after a dev approves the PR. That review *is* productionization. In
**solo trunk (pre-MVP)** there is no PR gate — the build commits straight to `main`
and productionization is the dev review at graduation (`/steer:protect`); see Commit
autonomy for the two modes.


## High-risk areas

These require **explicit dev scoping before broad changes** — do not propose
architectural changes here speculatively:

- **Auth & sessions** — sign-in/up, password reset, token issuance, session invalidation
- **Authorization & permissions** — role checks, access control, multi-tenancy boundaries
- **Database migrations** — schema changes, backfills, migration scripts
- **Infrastructure** — anything in `/infra`, especially networking, IAM, secret stores (Parameter Store / Secrets Manager)
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
hard-to-reverse picks, the feature's `intent.md` → `## Open questions` for open
items) and list them
in the PR description so dev review hardens them at productionization.
"Pre-production" is a property of the **product, not the laptop**: working
locally in a deployed product still produces migrations/deletions that reach
real data on merge — no relaxation there. **Never relaxed**, even
pre-production: real secrets/credentials, `/infra`, deploys, real third-party
calls.


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


## You are not the gate — the DEV is

You have no path-based permission boundary in managed product repos — propose
changes anywhere (`/apps`, `/packages`, `/configs`, `/spec`, `/infra`). The dev
reviewing the PR is the hard gate and catches out-of-scope or risky edits. When
unsure about scope, ask in a PR comment before making sweeping changes.

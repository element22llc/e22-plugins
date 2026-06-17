# GitHub Actions integration

steer ships two kinds of GitHub Actions integration. One is installed by default
and keeps CI Claude consistent with local sessions; the other is an opt-in recipe
for unattended, scheduled automation.

## `claude.yml` — the `@claude` mention workflow (default)

`/steer:init` and `/steer:adopt` install `.github/workflows/claude.yml` (source:
`plugins/steer/templates/github/workflows/claude.yml`). It runs
[`anthropics/claude-code-action@v1`](https://github.com/anthropics/claude-code-action)
when someone mentions `@claude` on an issue or PR.

### Why it loads the steer plugin

steer's whole premise is "org standards in **every** session" — injected by a
SessionStart hook the moment the plugin loads. Without extra wiring, the in-CI
agent would run as a stock, standards-less Claude: no stack defaults, no
Definition of Done, no spec/drift discipline. The shipped workflow closes that
gap by loading the plugin in CI through the action's purpose-built inputs:

```yaml
plugin_marketplaces: |
  https://github.com/element22llc/e22-plugins.git
plugins: |
  steer@e22-plugins
```

Once the plugin installs, its SessionStart hook injects `rules/*` exactly as it
does locally — the in-CI agent and the local agent are governed by the same
rules, with no duplicated system prompt.

!!! warning "settings.json does not work in CI"
    Do **not** try to load steer in CI via a `.claude/settings.json`
    `enabledPlugins` / `extraKnownMarketplaces` block (the mechanism used for
    *local* sessions). Those are gated behind an interactive trust dialog that
    headless/print mode skips, so they load nothing and fail **silently**
    (anthropics/claude-code [#13096](https://github.com/anthropics/claude-code/issues/13096)).
    The action's `plugins` / `plugin_marketplaces` inputs are the only CI path.

### Credentials

| Credential | Kind | Required | Purpose |
|---|---|---|---|
| `ANTHROPIC_API_KEY` | secret | always | Anthropic API auth for the action. A 401 in the log means it is missing, wrong, or mis-scoped. |
| `STEER_APP_ID` / `STEER_APP_PRIVATE_KEY` | variable / secret | while the marketplace repo is private | Credentials for a shared **GitHub App** with read-only access to `element22llc/e22-plugins`. A product repo's default `GITHUB_TOKEN` is scoped to that repo only and **cannot** clone another org repo, so the `plugin_marketplaces` fetch needs this. The workflow mints a short-lived (1 h, auto-revoked), repo-scoped token via [`actions/create-github-app-token`](https://github.com/actions/create-github-app-token) and rewrites `github.com` clones to use it. If `STEER_APP_ID` is unset the steps no-op and the clone goes anonymous (correct once the marketplace is public). |

A **GitHub App** is used in preference to per-repo personal access tokens: it is one
org-controlled credential, distributed once as an organization variable + secret (so
no per-repo setup), mints short-lived auto-expiring tokens scoped to just the
marketplace repo, and is not tied to a person who might leave. Rotation and
revocation are a single org-level action. The scaffold `README.md` →
"steer marketplace GitHub App" carries the one-time setup steps for org owners.

Verify by mentioning `@claude` and confirming the reply reflects steer standards
(e.g. it cites the Definition of Done) — that proves the plugin loaded, not just
that the action ran. The workflow log's `system/init` event also lists loaded
plugins. See the scaffold `README.md` → "GitHub Actions secrets" for the
product-repo-facing version of this.

## Agentic workflows (`gh aw`) — optional, opt-in

[GitHub Agentic Workflows](https://github.com/githubnext/gh-aw) (`gh aw`) is a
GitHub Next tool for authoring CI automation as natural-language Markdown that
**compiles** to a standard Actions `.lock.yml`. It can run unattended on a
schedule — something `claude.yml` (which only reacts to `@claude` mentions) and
the local skills cannot do.

steer ships **one example** workflow,
`plugins/steer/templates/github/agentic/triage.md` (scheduled issue triage that
classifies issues against the steer label taxonomy and Issue Types). It is **not**
installed by `/steer:init` or `/steer:adopt` and is **not** in `MANIFEST.md` —
you opt in deliberately.

### Why it is not in the default scaffold

- gh-aw is a self-described **research demonstrator** — *"not a product, not even
  a technical preview."* Committing it into every product repo would couple
  steer's deterministic, SHA-pinned, human-gated posture to a preview tool.
- It overlaps with steer's own issue lifecycle. `/steer:issues triage` (via
  `/steer:tracker-sync`) already triages interactively. Run **one** of the two,
  not both, or you double-triage every issue.
- It introduces a second agent engine and a manual compile step (`.lock.yml`)
  that the team owns and must keep current (`gh aw update`).

### The recipe

1. Install the CLI: `gh extension install github/gh-aw`.
2. Copy `plugins/steer/templates/github/agentic/triage.md` into your repo's
   `.github/workflows/` and adapt it.
3. Compile: `gh aw compile triage.md` → produces `triage.lock.yml`.
4. **Review the generated lock file before trusting it** — confirm the only
   write-backs are the declared `safe-outputs` (the example is advisory-only: it
   relabels, sets the Issue Type, and comments, but never closes issues or
   resolves product/technical questions — those stay human-gated) and **SHA-pin**
   every action it references (matches steer's version-pin policy).
5. Set `ANTHROPIC_API_KEY` (the example uses the Claude engine, consistent with
   local sessions) and commit both files.

See the [authorization model](../concepts/authorization-model.md) for why the
human gate on merge/close/deploy is preserved here.

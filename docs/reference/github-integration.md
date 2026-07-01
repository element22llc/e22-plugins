# GitHub Actions integration

steer ships a few kinds of GitHub Actions integration. Two are installed by
default — `claude.yml` (keeps CI Claude consistent with local sessions) and
Dependabot (keeps dependencies patched, and manages the resulting PRs); the last
is an opt-in recipe for unattended automation.

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

No marketplace credential is required: `element22llc/e22-plugins` is a **public**
repo, so the `plugin_marketplaces` fetch clones it anonymously over HTTPS —
`ANTHROPIC_API_KEY` is the only secret `claude.yml` needs. (While the marketplace
was private, a shared read-only **GitHub App** — `STEER_APP_ID` /
`STEER_APP_PRIVATE_KEY` — minted a short-lived clone token. That App and those
org variables/secrets are no longer needed and the workflow no longer references
them; org owners can retire them at their convenience.)

Verify by mentioning `@claude` and confirming the reply reflects steer standards
(e.g. it cites the Definition of Done) — that proves the plugin loaded, not just
that the action ran. The workflow log's `system/init` event also lists loaded
plugins. See the scaffold `README.md` → "GitHub Actions secrets" for the
product-repo-facing version of this.

## Dependabot — dependency updates + scoped auto-merge (default)

`/steer:init` and `/steer:adopt` install two files (sources under
`plugins/steer/templates/github/`):

- **`.github/dependabot.yml`** — the `github-actions` ecosystem is enabled live
  (every scaffolded repo ships workflows); the `npm` / `pip` / `docker` blocks are
  commented out for init/adopt to **uncomment per detected stack** (mirroring how
  `ci.yml` gates stack steps). Updates are grouped, and **major** bumps are
  `ignore`d — they're deferred to a deliberate `policy/versions.yml` decision.
- **`.github/workflows/dependabot-auto-merge.yml`** — auto-approves Dependabot
  **patch/minor** PRs, waits for the required `ci` check, then merges that single
  PR. **Major** bumps are never auto-merged; they get a "left for a human" comment.

### The review-gate exception

steer normally requires a human-approved PR before anything lands on `main`. The
auto-merge workflow is a **deliberate, documented exception**: dependency bumps
don't touch application logic, so the human *review* is waived. It is **not** a
waiver of the tests — the workflow waits for the required `ci` check to go green
before it merges, so a bump that breaks tests, lint, or the version-pin scan never
lands. **CI, not a human, is what guarantees the bump is safe.** The exception is
declared in `policy/branch-protection.yml` and the scaffold `README.md`
branch-protection section.

!!! note "Auto-merge is scoped to Dependabot — no repo-wide switch"
    The merge is gated by the workflow's `if: github.actor == 'dependabot[bot]'`
    guard and uses a direct single-PR merge. It deliberately does **not** enable
    GitHub's repo-wide `allow_auto_merge` setting, which would expose an auto-merge
    button to every PR. `gh pr checks --watch --required` watches only required
    checks, so the job never deadlocks on its own non-required run.

`/steer:protect` enables the repo settings the exception relies on — Dependabot
**alerts** and **security updates** (so security PRs get opened) — alongside secret
scanning. It configures settings only; the merge itself is enacted by the workflow.
`/steer:sync` keeps both files wired (the `dependency-automation` capability).

## Production promotion gate

Branch protection covers more than the default branch. `policy/branch-protection.yml`
also describes a long-lived **`prod`** branch, and `/steer:protect` applies
protection to every entry in its `protected_branches` list, not just `main`.

This is how the [deployment standard](../concepts/deployment.md) enforces its
production gate without GitHub Enterprise. Promotion to production is a **reviewed
PR from `main` into `prod`**; the required-review approval on that PR *is* the
production approval — it stands in for the deployment-environment approvals that
only GitHub Enterprise provides. Merging the `prod` PR auto-deploys production, and
nothing is ever pushed to `prod` directly.

`/steer:protect` reads `protected_branches` and configures each branch's rules
(required PR, required `ci` check, no direct pushes); `/steer:sync` keeps the
policy file and the protection in step as the plugin evolves. See
[Deployment & environments](../concepts/deployment.md#promotion) for the full
promotion model.

## Agentic workflows (`gh aw`) — optional, opt-in

[GitHub Agentic Workflows](https://github.com/githubnext/gh-aw) (`gh aw`) is a
GitHub Next tool for authoring CI automation as natural-language Markdown that
**compiles** to a standard Actions `.lock.yml`. It can run **unattended** — on
repository events or a schedule, with no `@claude` mention — something
`claude.yml` (which only reacts to `@claude`) and the local skills cannot do.

steer ships **one example** workflow,
`plugins/steer/templates/github/agentic/triage.md` (unattended issue triage that
runs when an issue is opened/reopened and classifies it against the steer label
taxonomy and Issue Types). It is **not** installed by `/steer:init` or
`/steer:adopt` and is **not** in `MANIFEST.md` — you opt in deliberately.

That label taxonomy is bootstrapped by the local `/steer:issues` lifecycle, which
runs `gh label create --force` inline for repo-level label setup — the one
sanctioned exception to routing all tracker I/O through the issue-scoped
`/steer:tracker-sync` gateway, which has no op for repo-level label creation.

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
   resolves product/technical questions — those stay human-gated) and confirm
   every action it references is **SHA-pinned** (gh-aw pins by default; keep it).
5. Set `ANTHROPIC_API_KEY` (the example uses the Claude engine, consistent with
   local sessions) and commit both files.

See the [authorization model](../concepts/authorization-model.md) for why the
human gate on merge/close/deploy is preserved here.

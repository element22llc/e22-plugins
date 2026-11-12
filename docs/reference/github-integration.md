# GitHub Actions integration

steer ships a few kinds of GitHub Actions integration. Two are installed by
default - `claude.yml` (keeps CI Claude consistent with local sessions) and
Dependabot (keeps dependencies patched, and manages the resulting PRs). Three
more are opt-in: `steer-loop.yml`, the scheduled autonomous loop `/steer:loop`
scaffolds on demand; a `gh aw` recipe for unattended automation; and
`copilot-setup-steps.yml`, which preinstalls the toolchain for GitHub's cloud
coding agent (see [Copilot support](../concepts/copilot-support.md)).

## `claude.yml` - the `@claude` mention workflow (default)

`/steer:setup init` and `/steer:setup adopt` install `.github/workflows/claude.yml` (source:
`plugins/steer/templates/github/workflows/claude.yml`). It runs
[`anthropics/claude-code-action@v1`](https://github.com/anthropics/claude-code-action)
when someone mentions `@claude` on an issue or PR.

### Why it loads the steer plugin

steer's whole premise is "org standards in **every** session" - injected by a
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
does locally - the in-CI agent and the local agent are governed by the same
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
repo, so the `plugin_marketplaces` fetch clones it anonymously over HTTPS -
`ANTHROPIC_API_KEY` is the only secret `claude.yml` needs. (While the marketplace
was private, a shared read-only **GitHub App** - `STEER_APP_ID` /
`STEER_APP_PRIVATE_KEY` - minted a short-lived clone token. That App and those
org variables/secrets are no longer needed and the workflow no longer references
them; org owners can retire them at their convenience.)

Verify by mentioning `@claude` and confirming the reply reflects steer standards
(e.g. it cites the Definition of Done) - that proves the plugin loaded, not just
that the action ran. The workflow log's `system/init` event also lists loaded
plugins. See the scaffold `README.md` -> "GitHub Actions secrets" for the
product-repo-facing version of this.

## Dependabot - dependency updates + scoped auto-merge (default)

`/steer:setup init` and `/steer:setup adopt` install one file and one CI job
(sources under `plugins/steer/templates/github/`):

- **`.github/dependabot.yml`** - the `github-actions` ecosystem is enabled live
  (every scaffolded repo ships workflows); the `npm` / `pip` / `docker` /
  `terraform` blocks are commented out for init/adopt to **uncomment per detected
  stack** (`terraform` is the one an `infra` repo needs) (mirroring how
  `ci.yml` gates stack steps). Updates are grouped, and **major** bumps are
  `ignore`d - they're deferred to a deliberate `policy/versions.yml` decision.
- **The `dependabot-auto-merge` job in `.github/workflows/ci.yml`** - runs after
  `ci` (`needs: ci`) in the same run and merges a Dependabot **patch/minor** PR
  directly, pinned to the head `ci` just tested (`--match-head-commit`). It never
  approves and never arms native auto-merge. **Major** bumps are never
  auto-merged; they get a "left for a human" comment.

!!! warning "A `ci.yml` other workflows call must get its scopes from them"
    The job declares `contents: write` and `pull-requests: write`. If `ci.yml`
    also has `on: workflow_call`, every workflow that calls it must grant both
    scopes. GitHub checks them at startup, before the job's `if`, so a narrower
    caller fails on every run while PR-triggered CI stays green. The sync
    capability scan reports such a caller, and sync proposes adding the grant
    to the calling job.

### The review-gate exception

steer normally requires a human-approved PR before anything lands on `main`. The
auto-merge job is a **deliberate, documented exception**: dependency bumps don't
touch application logic, so the human *review* is waived. It is **not** a waiver
of the tests - the job only runs once `ci` passed on that exact commit, and a job
gates the merge only if it is in the auto-merge job's `needs`. A bump that breaks
tests, lint, or the version-pin scan never lands. **CI, not a human, is what
guarantees the bump is safe.** The exception is declared in
`policy/branch-protection.yml` and the scaffold `README.md` branch-protection
section.

Because it never approves, the exception fires only where branch protection
requires no review: the `solo` profile, or a repo with no protection at all (a
private repo on GitHub Free). Under the `team` profile the job leaves a notice and
the bump waits for a human approval like any PR.

!!! note "Scoped to Dependabot's own commits"
    The job runs only when the PR's **author** (`pull_request.user.login`) and
    the pusher of this head (`github.actor`) are both `dependabot[bot]`; either
    alone can be moved by a writer. Before merging it lists the PR's commits and
    refuses unless every one is authored by `dependabot[bot]`, committed by
    `web-flow` and signature-verified, so a commit anyone else pushes onto the
    branch takes the PR out of the exception.

`/steer:setup protect` enables Dependabot **alerts** and **security updates** (so
security PRs get opened) alongside secret scanning. The exception needs no other
repo setting.

!!! note "Secret scanning is paid on a private repo"
    On a private or internal repo, secret scanning and push protection need
    GitHub Secret Protection, billed per active committer, and the API enables
    it without a cost prompt. protect reports them there as `licensed - not
    enabled` rather than drift, and enables them only when the dev asks after
    the cost is named. The scaffold's `ci:security` stage runs gitleaks over
    every commit, so each repo has a secret gate on any plan. protect reports a live **"Allow GitHub Actions to create and approve
pull requests"** as drift - the retired approve-based design asked for it, and it
lets any workflow approve any PR - and turns it off on confirmation. A
`GITHUB_TOKEN` merge triggers no `push` workflows, so a bot-merged bump does not
deploy non-prod on its own. `/steer:setup sync` keeps the job wired (the
`dependency-automation` capability) and migrates a repo off the old standalone
`dependabot-auto-merge.yml`.

## Production promotion gate

Branch protection covers more than the default branch. `policy/branch-protection.yml`
also describes a long-lived **`prod`** branch and the `release/**` snapshot
branches, and `/steer:setup protect` applies protection to every entry in its
`protected_branches` list, not just `main`.

This is how the [deployment standard](../concepts/deployment.md) enforces its
production gate without GitHub Enterprise. Promotion to production is a **Release
PR from a `release/vX.Y.Z` snapshot into `prod`** (an incident fix comes from
`hotfix/*` instead); the approvals on that PR *are* the production approval - they
stand in for the deployment-environment approvals that only GitHub Enterprise
provides. Merging it auto-deploys production, and nothing is ever pushed to
`prod` directly.

`/steer:setup protect` configures each branch's classic rules (required PR,
required `ci` check, no direct pushes) and, from policy schema 7, two repository
rulesets beside them, because GitHub has no classic equivalent:

- **`steer: prod approvals`** on `prod` - 2 approvals with one from the PO team
  **and** one from the dev team ("required reviewers"), last-push approval,
  stale-review dismissal, merge commits only, no bypass actors. The team slugs
  are per repo; protect asks for them when the policy leaves them empty. Both
  teams need Write access. A user-owned repo has no teams, so it keeps the
  2-approval count without the per-team rule.
- **`steer: release branches`** on `release/**` - a QA fix lands only through a
  PR with one approval and a green `ci`.

It also turns on the repo settings `delete_branch_on_merge`, so a merged release,
hotfix or merge-back branch is deleted and the release snapshot lives only as
long as its Release PR, and `allow_merge_commit`, which the merge-back PR needs.
Linear history is off on the default branch for the same reason: features still
squash, and the merge-back is the one merge commit `main` takes.

`/steer:setup sync` keeps the policy file and the protection in step as the
plugin evolves.

Because `ci` is a *required* check on `prod` and on the release branches, the
shipped `ci.yml` must trigger on PRs targeting them as well as `main` - its
`pull_request.branches` is `[main, prod, "release/**"]`, and its `types` include
`edited`, so retargeting a PR re-runs `ci`. A repo whose `ci.yml` predates that
(or was forked from it) sees the Release PR or a QA fix wait forever on a check
that never reports; add the missing branches to the trigger to clear it. On a PR
into `prod`, `ci` also runs `ci:promotion`: the head must be `release/*` or
`hotfix/*`, and a release must contain `prod`, so it never drops a hotfix or QA
fix `prod` already ships.

After a release or hotfix PR merges, the scaffold's `merge-back.yml` pushes
`merge-back/<pr>-to-main` at prod's tip and comments a link; a dev opens the PR
and merges it with **Create a merge commit**. It does not
open it itself, because letting `GITHUB_TOKEN` open PRs needs "Allow GitHub
Actions to create and approve pull requests", the setting protect reports as
drift. A GitHub App token is the opt-in for opening it automatically. See
[Deployment & environments](../concepts/deployment.md#promotion) for the full
promotion model.

## `steer-loop.yml` - the scheduled autonomous loop (on demand)

`/steer:loop` instantiates `.github/workflows/steer-loop.yml` from
`plugins/steer/templates/github/workflows/steer-loop.yml`. It is **not**
bootstrapped by `/steer:setup init` or `/steer:setup adopt` and is deliberately absent from
`MANIFEST.md`'s install map - a repo runs a loop only when someone asks for one
(rule `53-autonomous-loops`). The first thing `scaffold` asks for is the
**automation opt-in** where `policy/automation.yml` does not already declare
`loops: true`: an in-session decision with the trade stated, taken before
anything is written.

It is steer's own **unattended** path: the template ships a `schedule:` trigger
defaulting to weekday mornings (`cron: "0 13 * * 1-5"`, 13:00 UTC), which
`/steer:loop` confirms or adjusts with the dev at scaffold time, plus a
`workflow_dispatch` so the loop can be tested before its first scheduled run.
Keep the cadence modest - an hourly loop burns API budget and opens draft-PR
noise. The `verify` mode reports an installed loop; `remove` takes it back out.

## Agentic workflows (`gh aw`) - optional, opt-in

[GitHub Agentic Workflows](https://github.com/githubnext/gh-aw) (`gh aw`) is a
GitHub Next tool for authoring CI automation as natural-language Markdown that
**compiles** to a standard Actions `.lock.yml`. It can run **unattended** - on
repository events or a schedule, with no `@claude` mention - which `claude.yml`
cannot do, since it only reacts to `@claude`. (steer's own unattended path is
`steer-loop.yml`, above; gh-aw differs in authoring CI automation as
natural-language Markdown rather than a fixed loop.)

steer ships **one example** workflow,
`plugins/steer/templates/github/agentic/triage.md` (unattended issue triage that
runs when an issue is opened/reopened and classifies it against the steer label
taxonomy and Issue Types). It is **not** installed by `/steer:setup init` or
`/steer:setup adopt` and is deliberately absent from `MANIFEST.md`'s install map
(the manifest names the directory only to say it does not ship) - you opt in
deliberately.

That label taxonomy is bootstrapped by the local `/steer:work issues` lifecycle, which
runs `gh label create --force` inline for repo-level label setup - the one
sanctioned exception to routing all tracker I/O through the issue-scoped
`/steer:tracker-sync` gateway, which has no op for repo-level label creation.

### Why it is not in the default scaffold

- gh-aw is a self-described **research demonstrator** - *"not a product, not even
  a technical preview."* Committing it into every product repo would couple
  steer's deterministic, pinned, human-gated posture to a preview tool.
- It overlaps with steer's own issue lifecycle. `/steer:work issues triage` (via
  `/steer:tracker-sync`) already triages interactively. Run **one** of the two,
  not both, or you double-triage every issue.
- It introduces a second agent engine and a manual compile step (`.lock.yml`)
  that the team owns and must keep current (`gh aw update`).

### The recipe

1. Install the CLI: `gh extension install github/gh-aw`.
2. Copy `plugins/steer/templates/github/agentic/triage.md` into your repo's
   `.github/workflows/` and adapt it.
3. Compile: `gh aw compile triage.md` -> produces `triage.lock.yml`.
4. **Review the generated lock file before trusting it** - confirm the only
   write-backs are the declared `safe-outputs` (the example is advisory-only: it
   relabels, sets the Issue Type, and comments, but never closes issues or
   resolves product/technical questions - those stay human-gated) and confirm
   every action it references is **SHA-pinned** (gh-aw pins by default; keep it).
5. Set `ANTHROPIC_API_KEY` (the example uses the Claude engine, consistent with
   local sessions) and commit both files.

See the [authorization model](../concepts/authorization-model.md) for why the
human gate on merge/close/deploy is preserved here.

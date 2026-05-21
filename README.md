# e22-plugins

Element 22's plugin marketplace for Claude Code and Claude Cowork — the
AI-native collaborative workflow **from vibes to production**.

> Let the PO vibe. Let Claude translate. Let the Dev industrialize.
>
> Speed lives where speed is safe. Rigour lives where rigour is needed.
> The Product Spine — and the Claude that maintains it — is what makes the two
> compatible.

This repository is a [Claude Code plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces).
Installing it on a product repo gives the team:

- **Two lanes**, one repo: a **Prototype Lane** for Product Owners to vibe-code on
  sandboxed branches, and a **Production Lane** for engineers to industrialize what
  survives the gate.
- **The Product Spine**, the structured artefact that travels from prototype to
  production. Not the chat log. Not the commit list.
- **Six house-rule plugins** applied to every Claude session — PO or Dev, prototype
  or production. Update a plugin once, every Claude session picks it up tomorrow.

The marketplace format is supported across all three Claude surfaces:

- **Claude.ai (Chat)** — web/mobile, where most POs spend their day.
- **Claude Cowork** — the desktop tool for file and task automation.
- **Claude Code** — the terminal coding agent.

Plugins install identically on all three. The same `/vibe` works whether the PO
opens it on a phone, in Cowork, or in a terminal — because the plugins do not
depend on the local filesystem. **They depend on the [GitHub
connector](./CONNECTORS.md#github-connector--required) as the source of truth**,
which works equally well on every surface. The only thing that varies by surface
is *enforcement style* (see [Surface compatibility](#surface-compatibility) below).

## The arc of a change

```
01 PO Explores     →  02 Sandbox       →  03 AI Extracts   →  04 Dev Validates  →  05 Production  →  06 Governed
   /vibe              Contains            the Spine            /validate            Lane              Iteration
                     (Four Guarantees)   /package-handoff     Keep/Refactor/      tests, types,     PR for every
                                                              Redesign/Reject      observability,   change — even
                                                                                   feature flags    PO copy tweaks
PROTOTYPE LANE ─────────────────────────►│◄──── HANDOFF ────►│◄─── PRODUCTION LANE ──────────────────────────────
```

Speed lives on the left. Safety lives on the right. Claude carries the meaning
across.

## What's in here

### Lane plugins

| Plugin | Install handle | For whom | What it does |
|---|---|---|---|
| [`prototype-lane`](./plugins/prototype-lane) | `prototype-lane@e22-plugins` | Product Owners (Cowork) | `/vibe` spins up a sandboxed `prototype/<slug>` branch with a live preview. `/package-handoff` distills the prototype into a Product Spine and requests engineer validation. `/proposal-status` reports state without jargon. Auto-triggered skills handle ad-hoc change ideas and terminology questions. |
| [`production-lane`](./plugins/production-lane) | `production-lane@e22-plugins` | Engineers (Claude Code) | `/validate` is the **Keep / Refactor / Redesign / Reject** gate. `/propose` opens a production-lane proposal directly. `/from-design` starts from a Claude Design handoff bundle. `/promote` governs feature-flag rollouts. `spec-refiner` and `drift-monitor` agents keep specs honest. SOC2 overlay applies. |

### House-rule plugins (apply to every Claude session)

| Plugin | Install handle | Rule it enforces |
|---|---|---|
| [`spec-driven-dev`](./plugins/spec-driven-dev) | `spec-driven-dev@e22-plugins` | A spec or test must exist before code is generated. Lane-aware. |
| [`always-test`](./plugins/always-test) | `always-test@e22-plugins` | Every new endpoint, screen, or job ships with at least one smoke test. |
| [`house-style`](./plugins/house-style) | `house-style@e22-plugins` | Naming, folder layout, and lint rules are the same in every PR. |
| [`security-rails`](./plugins/security-rails) | `security-rails@e22-plugins` | Blocks risky patterns. Enforces the Four Guarantees on prototype branches and the constitution's "Claude must not" rules everywhere. |
| [`spine-writer`](./plugins/spine-writer) | `spine-writer@e22-plugins` | Keeps the Product Spine in sync with code. `/spine-refresh` and a PostToolUse hook. |
| [`handoff-packager`](./plugins/handoff-packager) | `handoff-packager@e22-plugins` | Packages dependency-delta, novel-patterns, and plugin-violations reports for the validation gate. |

### Repo-level artefacts

- [`CONSTITUTION.md`](./CONSTITUTION.md) — the always-loaded baseline. Defines the
  two lanes, the Four Guarantees, the Product Spine model, the Keep/Refactor/
  Redesign/Reject gate, and the SOC2 overlay.
- [`PRODUCT_SPINE_TEMPLATE.md`](./PRODUCT_SPINE_TEMPLATE.md) — the canonical layout
  for a Product Spine: Intent · UX · Surface · Architecture · Open Questions.

### How they fit together

```
PO has an idea
  │
  ▼
/vibe (prototype-lane)
  │  branch: prototype/<slug>
  │  preview URL, sandboxed, ephemeral
  │  Four Guarantees enforced by security-rails
  │  House rules apply: spec-driven-dev (lenient), always-test, house-style
  ▼
PO iterates… "move this up", "show me three variants"
  │  spine-writer hook nudges if Spine is stale
  ▼
/package-handoff
  │  spine-writer → product-spine.md
  │  handoff-packager → dependency-delta, novel-patterns, plugin-violations
  │  draft PR opened, labelled awaiting-validation
  ▼
Engineer reads the Spine + bundle (not the whole branch)
  │
  ▼
/validate (production-lane)
  │
  ├─ Keep      → rename to proposal/<slug>, harden in place
  ├─ Refactor  → new branch off main, rebuild against the Spine
  ├─ Redesign  → new branch with carry-over notes
  └─ Reject    → PR closed, PO gets actionable notes
  │
  ▼  (Keep/Refactor/Redesign continue from here)
production lane: tests, types, observability, feature flag
  │  experimental label, behind flag at 0%
  ▼
/promote
  │  feature flag ramps; observability-driven graduation
  ▼
production-graded
```

## Surface compatibility

Every plugin runs on every Claude surface. What differs is **how each rule is
enforced**:

- In **Claude Code**, house-rule plugins fire as `PreToolUse` / `PostToolUse` /
  `Stop` hooks. Violations can be blocked at the tool-call boundary.
- In **Claude.ai (Chat)** and **Claude Cowork**, hooks do not run. The same
  rules apply via in-prompt guidance carried by each plugin's
  commands/agents/skills, and via the GitHub connector's branch protections + CI
  on the PR side. The result is functionally identical for anything that lands
  in a PR; the difference is that a misbehaving turn is caught one step *later*
  (at PR open / CI run) rather than at the local edit boundary.

| Plugin              | Claude.ai (Chat) | Claude Cowork | Claude Code | How rules are enforced on Chat/Cowork |
| ------------------- | :--------------: | :-----------: | :---------: | ------------------------------------- |
| `prototype-lane`    | ✅               | ✅            | ✅          | All commands work via the GitHub connector. No local files needed. |
| `production-lane`   | ✅               | ✅            | ✅          | Same as above. Validation/promotion gates are connector-driven, not hook-driven. |
| `spec-driven-dev`   | ✅ (prompts)     | ✅ (prompts)  | ✅ (hooks + prompts) | In-prompt rule loaded by every command; PR-level enforcement when the connector opens a PR without a linked Spine. |
| `always-test`       | ✅ (prompts)     | ✅ (prompts)  | ✅ (hooks + prompts) | In-prompt rule; CI enforces coverage on the PR. |
| `house-style`       | ✅ (prompts)     | ✅ (prompts)  | ✅ (hooks + prompts) | In-prompt rule; CI runs lint/format. |
| `security-rails`    | ✅ (prompts)     | ✅ (prompts)  | ✅ (hooks + prompts) | In-prompt rule; the connector's branch protections + CI catch violations. |
| `spine-writer`      | ✅               | ✅            | ✅          | `/spine-refresh` reads the branch via the GitHub connector; writes the Spine via a PR commit. |
| `handoff-packager`  | ✅               | ✅            | ✅          | `/package` reads via the connector; writes the bundle as PR-attached files. |

**Rule of thumb.** Claude Code is "tight loop" — fast feedback at every keystroke.
Chat/Cowork are "PR loop" — feedback at PR open. Both ship the same product
because they both go through the same Production Lane CI.

## Required connector

**All plugins require the GitHub connector.** This is non-negotiable; the
workflow does not function without it. See [`CONNECTORS.md`](./CONNECTORS.md) for
the full reference, including which capabilities each command uses (branches,
PRs, issues, wiki, projects, labels, comments, repo contents).

Recommended but optional: Sentry (production-graded gate), LaunchDarkly or
PostHog (`/promote`), Slack (champion pings), `context7` (current API docs).
SOC2 products also need AWS Secrets Manager / SSM Parameter Store access.

## Install

### In Claude Code

Once this repo is on GitHub at `element22llc/e22-plugins`:

```bash
# Inside a Claude Code session
/plugin marketplace add element22llc/e22-plugins

# Lane plugins
/plugin install prototype-lane@e22-plugins
/plugin install production-lane@e22-plugins

# House rules — install all six
/plugin install spec-driven-dev@e22-plugins
/plugin install always-test@e22-plugins
/plugin install house-style@e22-plugins
/plugin install security-rails@e22-plugins
/plugin install spine-writer@e22-plugins
/plugin install handoff-packager@e22-plugins
```

For local development (before pushing):

```bash
/plugin marketplace add ./e22-plugins
```

Validate before pushing:

```bash
claude plugin validate .
```

### In Claude.ai (Chat)

Chat consumes the same marketplace. POs working in claude.ai install via the
plugins panel:

1. Settings → Plugins → Add marketplace → `element22llc/e22-plugins`.
2. Install at minimum `prototype-lane` plus all six house-rule plugins;
   `production-lane` is useful for status visibility.
3. Settings → Connectors → ensure **GitHub** is connected and has access to the
   relevant org(s).

That's enough to run `/vibe`, `/package-handoff`, and `/proposal-status` from
chat. The same skills auto-trigger here as in Cowork.

### In Claude Cowork

Cowork uses the same plugin format. Non-engineers (POs) should install:

1. Open the Plugins panel in Cowork.
2. Add marketplace: `element22llc/e22-plugins` (or local path during development).
3. Install at minimum: `prototype-lane`, plus all six house-rule plugins.
   `production-lane` is optional for POs but useful for status-checking.

That gives them:

- `/vibe` — vibe-code a change into a sandboxed preview within minutes
- `/package-handoff` — distill the prototype into a Product Spine and request
  engineer validation
- `/proposal-status` — see where everything stands without jargon
- The two auto-triggered skills:
  - **`change-idea-intake`** — kicks in when a PO describes a change ("I wish X
    did Y", "could we try Z"). Offers to spin up a vibe session without making
    them remember the slash command.
  - **`proposal-glossary`** — kicks in when they ask what a term means ("what's
    the Spine", "what does Keep mean"). Plain-language answers.

## Distribute through the Claude team workspace

The roll-out plan: push to GitHub, then drop a settings template into each Element
22 product repo so contributors get auto-prompted on first trust.

### One-time: publish the marketplace

1. Create the GitHub repo `element22llc/e22-plugins` (private or public depending
   on org policy).
2. Push this checkout.
3. (Optional) Tag a release: `git tag v0.2.0 && git push --tags`. The marketplace
   doesn't require tags, but they make the cache key predictable.

### Per product repo: auto-prompt teammates

Copy [`templates/claude-settings.json`](./templates/claude-settings.json) into the
product repo as `.claude/settings.json` and commit it. The template registers
`e22-plugins` as a known marketplace and pre-enables **all eight** plugins:

```bash
# From the product repo root
mkdir -p .claude
cp <path-to>/e22-plugins/templates/claude-settings.json .claude/settings.json
git add .claude/settings.json
git commit -m "chore: auto-prompt teammates to install e22-plugins marketplace"
```

What happens for teammates after this lands:

- First time they open the repo in Claude Code or Cowork and trust the folder,
  they'll see a prompt: *"This project recommends the `e22-plugins` marketplace.
  Install?"*
- After they accept, all eight plugins install and enable automatically.
- Updates: contributors get the latest version when they run `/plugin marketplace
  update` (or on next Claude startup, depending on auto-update settings).

### Optional: lock down marketplace sources

This template **auto-prompts** but doesn't restrict. Anyone can still add other
marketplaces. If you want strict control (e.g. SOC2-required repos shouldn't allow
arbitrary marketplaces), configure
[`strictKnownMarketplaces`](https://code.claude.com/docs/en/settings#strictknownmarketplaces)
in **managed settings** at the org level — that requires an admin and a separate
rollout. Out of scope for this README; see the spec when you're ready.

### Private repo auto-updates

If `element22llc/e22-plugins` is private, contributors' Claude clients need
`GITHUB_TOKEN` (or `GH_TOKEN`) in their shell environment for background
auto-updates to work. Interactive `gh auth` is enough for manual `/plugin
marketplace update`, but background updates suppress prompts. Document this in
your contributor onboarding.

## Using the plugins

### `/vibe` (Cowork, Product Owner)

```
/vibe Add a way for customers to flag an order for re-delivery.
      Make the button live next to the order status.
      Show me three variants of the modal — I'll pick.
```

Claude creates `prototype/po-redelivery-flag`, scaffolds a smoke test, applies the
Four Guarantees (sandbox secrets, fake data, ephemeral URL, throwaway branch), and
posts a preview URL within minutes. The PO iterates by replying ("move this up",
"make the third variant the one") — Claude commits each turn to the same branch.

### `/package-handoff` (Cowork, Product Owner)

When the PO is happy, `/package-handoff` calls `spine-writer` to distill the branch
into a Product Spine, `handoff-packager` to bundle the dependency-delta /
novel-patterns / plugin-violations reports, and opens a draft PR labelled
`awaiting-validation` for the engineering team.

### `/validate` (Claude Code, engineer)

```
/validate 142
```

Engineer reads the Spine and bundle. Makes one decision:

| Decision   | Effect                                                                    |
| ---------- | ------------------------------------------------------------------------- |
| `Keep`     | Branch renamed `proposal/<slug>`, full CI engages, harden in place.       |
| `Refactor` | New `proposal/<slug>` branch off main, rebuild against the Spine.         |
| `Redesign` | New branch with explicit carry-over notes about what NOT to do.           |
| `Reject`   | PR closed with actionable feedback; PO can re-vibe.                       |

SOC2 products cannot use `Keep` — they round-trip through `Refactor` minimum.

### `/proposal-status` (Cowork, Product Owner)

```
/proposal-status                # all your work across both lanes
/proposal-status checkout       # search by term
/proposal-status #142           # specific PR
```

Plain-language status across prototype and production lanes — *"Engineer is
hardening your prototype in place"* not *"label transitioned drafting → preview-ready."*

### `/propose`, `/from-design`, `/promote` (Claude Code, engineer)

The production-lane direct path for well-understood changes. See
[the production-lane README](./plugins/production-lane) and the
[constitution](./CONSTITUTION.md) for the full engineering lifecycle.

### `/spine-refresh` (any session)

Manually re-extract the Product Spine from the current branch. Use this after a
long vibe-coding session before `/package-handoff`, or post-merge when
`drift-monitor` flags Spine ↔ code divergence.

## Adding a new plugin to the marketplace

1. Create the subtree:
   ```
   plugins/<new-plugin>/
   ├── .claude-plugin/plugin.json
   ├── commands/    (optional)
   ├── agents/      (optional)
   ├── skills/      (optional)
   └── hooks/       (optional — both hooks.json AND any shell scripts)
   ```
2. Fill in `plugin.json` (minimum: `name`, `version`, `description`).
3. Add an entry to `.claude-plugin/marketplace.json#plugins`. Because
   `metadata.pluginRoot` is `./plugins`, the `source` value is just the bare
   directory name (e.g. `"source": "./my-new-plugin"`).
4. Run `claude plugin validate .`.
5. Open a PR. Once merged, teammates pick up the new plugin on the next
   marketplace refresh.

## Versioning

Each plugin's `plugin.json` declares an explicit `version`. **Bump the `version`
field on every release** — users only see updates when the string changes. Don't
set `version` in both `plugin.json` and the marketplace entry; the manifest value
silently wins. Omitting `version` switches to git-SHA-per-commit, which is simpler
for actively-developed plugins.

This rewrite is `v0.2.0` of the marketplace — lane plugins are at `0.2.0`, house
rules at `0.1.0`.

## Validating changes

Before pushing:

```bash
claude plugin validate .
```

Checks `marketplace.json`, every plugin's `plugin.json`, all skill/agent/command
frontmatter, and `hooks/hooks.json`. Warnings about kebab-case and missing
descriptions are non-blocking but worth fixing — the Claude.ai marketplace sync is
stricter than local installs.

## License

`UNLICENSED` — Element 22 internal use.

## See also

- [CONSTITUTION.md](./CONSTITUTION.md) — engineering baseline (two lanes, Spine,
  validation gate, SOC2 overlay)
- [CONNECTORS.md](./CONNECTORS.md) — required and recommended connectors (GitHub,
  Sentry, flags, Slack, AWS) and which commands use each capability
- [PRODUCT_SPINE_TEMPLATE.md](./PRODUCT_SPINE_TEMPLATE.md) — canonical Spine layout
- [MARKETPLACE_VALIDATION.md](./MARKETPLACE_VALIDATION.md) — internal conformance
  notes
- [templates/](./templates) — distribution config to drop into product repos
- [Create and distribute a plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces) — official spec
- [Plugins reference](https://code.claude.com/docs/en/plugins-reference) — full plugin schema
- [Plugin settings](https://code.claude.com/docs/en/settings#plugin-settings) — `extraKnownMarketplaces`, `enabledPlugins`, `strictKnownMarketplaces`

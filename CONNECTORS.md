# Connectors

The `e22-plugins` workflow assumes Claude has access to a specific set of MCP
connectors. This file is the single source of truth for what's required, what's
recommended, and what each plugin does with them.

If you're rolling the marketplace out across a team, treat this as the connector
checklist: every contributor needs the **required** set; engineers also need
**recommended**; SOC2 product owners need the **SOC2-overlay** set.

## TL;DR

| Connector            | Tier        | Why                                                                       |
| -------------------- | ----------- | ------------------------------------------------------------------------- |
| **GitHub**           | required    | All proposal motion: branches, PRs, issues, wiki, projects, labels.       |
| Sentry               | recommended | Production-graded gate (error-rate, suspect-flag findings).               |
| Statsig | recommended | `/promote` flag mutation; rollout reporting.                              |
| Microsoft Teams                | optional    | `/proposal-status` direct-handoff messages; champion pings.               |
| AWS (Secrets Manager / SSM) | SOC2-overlay | Resolving secret names referenced in CLAUDE.md without exposing values.   |
| `context7` (Upstash) | recommended | Current API/version docs to prevent hallucinated APIs.                    |

> **Note on naming.** Anthropic ships these as a mix of first-party connectors
> (GitHub, Sentry, Microsoft Teams), third-party MCP servers, and Claude-Code-only plugins.
> Tool names are MCP-discoverable; this doc references capabilities by what they
> *do*, not by exact tool names, so the plugins keep working as connector tooling
> evolves.

## GitHub connector — required

This is the most-used connector across the workflow. Every plugin that mutates
state outside the local checkout goes through it. If GitHub isn't connected,
most commands degrade to read-only or chat-only behavior and announce that
they're degraded; they do not silently skip.

### Capabilities used

| Capability        | Used by                                                                                                                | What it does                                                                                                |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| **Branches**      | `/vibe`, `/propose`, `/from-design`, `/validate`                                                                       | Create `prototype/<slug>` and `proposal/<slug>` branches; rename a prototype branch into a proposal at Keep. |
| **Pull requests** | `/package-handoff`, `/propose`, `/from-design`, `/validate`, `/promote`, `drift-monitor`                               | Open draft PRs, update titles/descriptions/labels, post review-required comments, close on Reject.          |
| **Issues**        | `/draft-proposal-as-issue` (change-idea-intake skill option), `drift-monitor`, `/proposal-status` (read)               | File intake briefs as labelled issues; report drift findings; surface backlog state to POs.                 |
| **Wiki**          | `/package-handoff` (optional Spine mirror), `proposal-glossary` skill (optional read)                                  | Publish a non-engineer-friendly Spine summary to the product wiki; resolve glossary terms from team-curated wiki pages. |
| **Projects (v2)** | `/proposal-status` (read), `/vibe` (write item), `/package-handoff` (advance item), `/validate` (advance item)         | Track every proposal as a project-board item with custom fields for lane, champion, status, validation decision. |
| **Labels**        | All proposal commands                                                                                                  | Apply `proposal`, `drafting`, `preview-ready`, `review-requested`, `awaiting-validation`, `experimental`, `production-graded`, `tier-{0,1,2}`, `product:<slug>`, `soc2`. |
| **Comments**      | `/promote`, `drift-monitor`, `/validate` (on reject/redesign)                                                          | Post structured comments — flag rollout state, drift evidence, validation rationale.                        |
| **Repo contents** | `spine-extractor` agent, `handoff-packager`                                                                            | Read PR diffs, manifest files, branch history when not running in a local checkout (Chat/Cowork case).      |

### Setup

1. **Install / connect the GitHub connector** in the user's Claude account.
   - Claude.ai (Chat): Settings → Connectors → GitHub → Connect.
   - Claude Code (CLI): the same connector, or fall back to `gh` CLI if the
     user has it authenticated locally.
   - Claude Cowork: connector tab in the desktop app.
2. **Grant scope** to the relevant Element 22 orgs and repos. At minimum:
   `element22llc/*`. The connector will request least-privilege per capability;
   approve all that overlap with the table above.
3. **Verify with a smoke test**: have Claude run *"list open PRs in
   element22llc/product-a"* — it should succeed without prompting for credentials.

### Degraded behavior when GitHub is missing

| Command           | Without GitHub connector                                                                                  |
| ----------------- | --------------------------------------------------------------------------------------------------------- |
| `/vibe`           | In Claude Code: falls back to local `git` for branch creation; preview won't auto-deploy. In Chat/Cowork: refuses, asks the user to connect GitHub. |
| `/package-handoff`| Writes the Spine and bundle to the local checkout (Code) or the outputs folder (Cowork); cannot open the draft PR. Surfaces a "paste this to engineering" message instead. |
| `/proposal-status`| Refuses with a clear message about needing GitHub connected. No silent stale data.                        |
| `/validate`       | Refuses. Validation is a public state change; it cannot happen without the connector.                     |
| `/promote`        | Refuses. Promotion is governed and audited.                                                               |
| `drift-monitor`   | Reports to chat only; cannot file issues.                                                                 |

## Recommended connectors

### Sentry

Used by `/promote` and the production-graded gate. Without it, the gate falls
back to "human asserts that error rates look fine" — which is fragile. Connect
Sentry to:

- Project: per Element 22 product
- Scope: read issues, read events, search by tag (we tag events with the flag
  name for the suspect-flag query)

### Statsig (feature flags)

`/promote` mutates feature flags. Connect whichever the product uses. Without
it, promotion is a chat-only confirmation Claude cannot enact, and the
constitution's promotion governance breaks.

### Microsoft Teams

Used by `change-idea-intake` skill (offers "paste to an engineer in Microsoft Teams" as a
direct-handoff option) and `/proposal-status` (champion pings, gentle nudges).
Without it, those flows degrade to "give the user a copy-pasteable message
block" — still usable, less automated.

### `context7`

Used by every command before it generates code, to fetch current API/version
documentation. Without it, Claude is more likely to hallucinate an outdated API.
Not a blocker, but strongly recommended.

## SOC2-overlay connectors

### AWS — Secrets Manager / SSM Parameter Store

For products marked `soc2: true`, the constitution forbids storing secret values
in CLAUDE.md or PR descriptions. We reference secrets by their AWS path
(`/prod/<product>/<key>`) and resolve them at runtime via the AWS connector with
read-only credentials.

If your role doesn't have AWS access, that's fine — Claude will surface the path
in chat for the human to resolve, but will never paste a value into a file.

## Connector compatibility by surface

The same connectors work across all three Claude surfaces; the wiring differs
slightly. **This is what makes the e22-plugins workflow surface-portable**: the
plugins themselves don't care which surface they're running on, only that the
required connectors are reachable.

| Surface          | GitHub connector | Sentry | Flags | Microsoft Teams | AWS | context7 |
| ---------------- | :--------------: | :----: | :---: | :---: | :-: | :------: |
| Claude.ai (Chat) | ✅               | ✅     | ✅    | ✅    | ✅  | ✅       |
| Claude Cowork    | ✅               | ✅     | ✅    | ✅    | ✅  | ✅       |
| Claude Code      | ✅ (or `gh` CLI fallback) | ✅ | ✅ | ✅    | ✅  | ✅       |

## See also

- [`CONSTITUTION.md`](./CONSTITUTION.md) — declares which connectors are required
  and forbids storing secret values in committed files.
- [`README.md`](./README.md#surface-compatibility) — the surface-compatibility
  matrix per plugin (including the hooks caveat).
- [`templates/claude-settings.json`](./templates/claude-settings.json) — the
  per-product settings template; mentions the connector requirement so trusting
  a product folder also nudges teammates to connect GitHub.

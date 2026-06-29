# Configuration & rules

The always-on **rules** under `plugins/steer/rules/` are the plugin's operating
manual. They are injected into every managed session by `inject-standards.sh`
([Hooks](hooks.md)) and concatenate in **lexical order** by numeric prefix.

!!! note "Numbering has intentional gaps"
    Prefixes are spaced (e.g. `20` → `22` → `30`) so new rules can slot between
    existing ones. Gaps are headroom — files are never renumbered to make the
    sequence contiguous.

## The ruleset

| Rule | Topic |
| --- | --- |
| `00-router.md` | Operating-manual entry point. |
| `05-roles.md` | Who you are working with. |
| `10-stack.md` | Stack defaults (app / service profile). |
| `12-stack-infra.md` | Stack — infrastructure / IaC (injected when the repo does IaC). |
| `15-commands.md` | Useful commands. |
| `20-layout.md` | Where things live. |
| `22-housekeeping.md` | Keep the repo tidy. |
| `24-worktrees.md` | Parallel worktrees — isolate runtime, clean up after. |
| `26-context-hygiene.md` | Context hygiene — delegate heavy runs, keep state in files. |
| `30-spec-workflow.md` | Spec workflow. |
| `31-decision-capture.md` | Durable decisions land in the spine, not in side-channels. |
| `32-living-docs.md` | Document in parallel, not after. |
| `35-issue-tracker.md` | Issue-tracker integration (client-agnostic). |
| `36-issue-first.md` | Issue-first (GitHub-adopted repos). |
| `40-testing.md` | Testing rules. |
| `41-coverage.md` | Coverage as a signal — cover what you touch; no vanity threshold. |
| `45-commit-autonomy.md` | Commit autonomy (see [Authorization model](../concepts/authorization-model.md)). |
| `50-definition-of-done.md` | Definition of Done. |
| `52-deployment.md` | Deployment & environments — branch-driven promotion, review apps, observability baseline, rollback (see [Deployment & environments](../concepts/deployment.md)). |
| `55-drift-gates.md` | Surface drift before merge. |
| `60-high-risk.md` | High-risk areas. |
| `70-secrets.md` | Secrets handling. |
| `75-compliance.md` | Audit-aligned delivery (SOC 2 / ISO 27001). |
| `80-change-size.md` | Change-size model. |
| `85-practices.md` | Baseline patterns — typed by default, schema-validated boundaries (incl. JSON/YAML config & data files), parameterized data access, server-first, nothing silenced, every import resolves to a declared dependency. |
| `87-output-discipline.md` | Earn every line — comments are the exception, responses stay tight. |
| `90-design-sources.md` | Design sources & UI. |
| `95-not-the-gate.md` | You are not the gate — the dev is. |
| `97-self-report.md` | When steer itself misbehaves, offer `/steer:report` to file it upstream. |
| `99-end-of-session.md` | End-of-session checklist. |

!!! note "Conditional injection"
    Some rules carry a first-line `<!-- steer:inject-when=… -->` marker and are
    injected only when their scope applies (see
    [`inject-standards.sh`](hooks.md)). The code-loop rules — `10-stack`,
    `15-commands`, `20-layout`, `22-housekeeping`, `24-worktrees`, `40-testing`,
    `41-coverage`, `45-commit-autonomy`, `50-definition-of-done`, `55-drift-gates`,
    `80-change-size`, `85-practices`, `99-end-of-session` — are marked
    `code-project`, so they are **skipped in knowledge-work mode** (a confidently
    non-code folder, e.g. a Claude Cowork product-owner workspace). `12-stack-infra`,
    `36-issue-first`, and `52-deployment` are likewise scoped to repos that do IaC,
    use GitHub issues, or deploy. The context-hygiene, spec-workflow,
    decision-capture, living-docs, roles, issue-tracker, secrets, compliance, and
    output rules stay always-on.

## Tooling knobs

- **`policy/versions.yml`** — version floors; `check-version-pins.sh` blocks pins
  that violate it.
- **`STEER_CLAUDE_CODE_VERSION`** (in `mise.toml`) — the pinned Claude Code
  version CI installs, for reproducible `claude plugin validate`.

Rules are kept lean and imperative on purpose. Long-form prose lives in
`plugins/steer/templates/reference/` and is surfaced through a skill, never
added to `rules/`.

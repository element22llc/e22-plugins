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
| `10-stack.md` | Stack defaults. |
| `15-commands.md` | Useful commands. |
| `20-layout.md` | Where things live. |
| `22-housekeeping.md` | Keep the repo tidy. |
| `30-spec-workflow.md` | Spec workflow. |
| `32-living-docs.md` | Document in parallel, not after. |
| `35-issue-tracker.md` | Issue-tracker integration (client-agnostic). |
| `36-issue-first.md` | Issue-first (GitHub-adopted repos). |
| `40-testing.md` | Testing rules. |
| `45-commit-autonomy.md` | Commit autonomy (see [Authorization model](../concepts/authorization-model.md)). |
| `50-definition-of-done.md` | Definition of Done. |
| `55-drift-gates.md` | Surface drift before merge. |
| `60-high-risk.md` | High-risk areas. |
| `70-secrets.md` | Secrets handling. |
| `75-compliance.md` | Audit-aligned delivery (SOC 2 / ISO 27001). |
| `80-change-size.md` | Change-size model. |
| `85-practices.md` | Baseline patterns. |
| `90-design-sources.md` | Design sources & UI. |
| `95-not-the-gate.md` | You are not the gate — the dev is. |
| `99-end-of-session.md` | End-of-session checklist. |

## Tooling knobs

- **`policy/versions.yml`** — version floors; `check-version-pins.sh` blocks pins
  that violate it.
- **`STEER_CLAUDE_CODE_VERSION`** (in `mise.toml`) — the pinned Claude Code
  version CI installs, for reproducible `claude plugin validate`.

Rules are kept lean and imperative on purpose. Long-form prose lives in
`plugins/steer/templates/reference/` and is surfaced through a skill, never
added to `rules/`.

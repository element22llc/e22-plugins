# Skills reference

Every skill `steer` ships, invoked as **`/steer:<skill>`**. This page is kept in
sync with `plugins/steer/skills/` by the `/plugin-docs` skill, and the
[`validate_docs.py`](../contributing/documentation.md) gate fails CI if any
shipped skill is missing here.

!!! note "Invocation"
    Always namespaced: `/steer:spec`, never bare `/spec`. There is no
    `commands/` directory — the thin command shims were removed.

## Setup

| Skill | Purpose |
| --- | --- |
| `/steer:doctor` | Detect and install the local prerequisites a repo needs before init/build/dev — git, mise (and the pnpm/uv/node it manages), and Docker — with per-OS guidance and confirmation-gated installs. |
| `/steer:init` | One-time setup for a new repo — bootstrap the `/spec` spine + scaffold, or resolve legacy template placeholders. Offers solo **trunk mode** when one person is both PO and dev with no MVP yet (commit directly to `main`, no `feat/*`/PR ceremony, declared in the product `CLAUDE.md` `## Delivery mode`). |
| `/steer:adopt` | Reverse-engineer a `/spec` spine from an existing app's code and add the scaffold. See [Adopt](../workflows/adopt.md). |
| `/steer:protect` | Verify (and, on confirmation, apply) GitHub branch protection against `policy/branch-protection.yml` — the real PR gate — on the default branch plus any additional branches the policy declares (e.g. a `prod` promotion branch, whose required PR review is the production approval gate), plus the repo-level security settings it declares (secret scanning + push protection, Dependabot alerts + security updates). steer is advisory locally; this configures the server-side wall. Verify-only by default. Also the **graduation gate** out of solo trunk mode: running it raises the PR wall and ends the mode. Treats a declared-trunk unprotected `main` as intentional, not drift. |

## Backlog & specs

| Skill | Purpose |
| --- | --- |
| `/steer:issues` | High-level GitHub Issues lifecycle for the spine — capture, triage, brainstorm, materialize, decompose, status, reconcile. See [Issues](../workflows/issues.md). |
| `/steer:spec` | Spec-only brainstorm for a feature — author/iterate `intent.md` (+ `contract.md`), drive open questions, approve. See [Spec](../workflows/spec.md). |
| `/steer:build` | Guided flow for a non-technical PO: idea → spec → working app → PR. See [Build](../workflows/build.md). |
| `/steer:questions` | Promote a spec's open question into a tracked issue when it outgrows the feature. |
| `/steer:design-sources` | Handle features originating from a Claude Design export/URL, Figma, or screenshots. |

## Execution

| Skill | Purpose |
| --- | --- |
| `/steer:work` | Execute a GitHub issue end-to-end — validate, claim, branch, implement, test, PR. See [Work](../workflows/work.md). |
| `/steer:adr` | Record a hard-to-reverse or cross-cutting decision as an ADR. See [Decisions](../decisions/index.md). |

## Steady state (read-only)

| Skill | Purpose |
| --- | --- |
| `/steer:drift` | Compare the as-built `/spec` against the tracker's intent and surface divergences. Read-only. |
| `/steer:audit` | Repeatable whole-repo standards-conformance health audit, ranked by leverage. Read-only. Treats a declared-trunk unprotected `main` (solo trunk mode) as intentional, not a finding. |
| `/steer:next` | "What should I do next?" across the workspace. Read-only. |
| `/steer:traceability` | Living-docs & traceability reference — how specs, issues, ADRs, tracker refs, and drift gates link up. Read-only. |

## Maintenance

| Skill | Purpose |
| --- | --- |
| `/steer:sync` | Bring a managed repo up to date with the current plugin — apply migrations, reconcile spine + scaffold, repair missing/mis-wired capability-critical scaffold (plugin enablement, in-CI loading, version-pin enforcement, drift gate, branch-protection), re-stamp `/spec/.version`, land a PR. `--check` runs a read-only capability + drift report. |
| `/steer:tidy` | Sweep loose files out of the repo root into their correct home (`/spec/reference`, `/spec/design`). |
| `/steer:conventions` | Answer tooling/convention questions and the rationale behind stack defaults. |
| `/steer:standards` | Load the always-on operating manual on demand (for surfaces where the SessionStart hook doesn't fire). |
| `/steer:report` | File a bug about the **steer plugin itself** upstream in `element22llc/e22-plugins` — gathers the defect (a recorded hook fault, a contradictory skill/rule, or a missing/broken template/script), scrubs it of secrets/paths/product-code, deduplicates by a stable fingerprint, and files via `gh` only on confirmation (paste-URL fallback). For plugin defects, not product bugs. |

## Internal (not user-invoked)

These are `user-invocable: false` — called by other skills, not from the slash
menu, but documented here for completeness:

| Skill | Purpose |
| --- | --- |
| `/steer:tracker-sync` | The single gateway for all GitHub tracker reads/writes (MCP-first, `gh` fallback, manual floor). |
| `/steer:spec-scaffold` | Materialize the `/spec` spine files from the bundled templates. |

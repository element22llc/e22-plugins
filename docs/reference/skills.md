# Skills reference

Every skill `steer` ships, invoked as **`/steer:<skill>`**. This page is kept in
sync with `plugins/steer/skills/` by the `/plugin-docs` skill, and the
[`validate_docs.py`](../contributing/documentation.md) gate fails CI if any
shipped skill is missing here.

!!! note "Invocation"
    Always namespaced: `/steer:spec`, never bare `/spec`. There is no
    `commands/` directory — the thin command shims were removed.

## Front doors

The handful of skills a user picks from. Each detects context and hands off to the
specialized skills below as needed, so you rarely reach past this set.

| Skill | Purpose |
| --- | --- |
| `/steer:setup` | One front door for getting a repo onto the standards — detects the `/spec` spine state and routes to greenfield bootstrap, existing-code adoption, or steady-state sync, installing prerequisites first if the toolchain is missing. Thin dispatcher over `/steer:init`, `/steer:adopt`, `/steer:sync`, `/steer:doctor`. |
| `/steer:build` | Guided flow for a non-technical PO: idea → spec → working app → PR. See [Build](../workflows/build.md). |
| `/steer:spec` | Spec-only brainstorm for a feature — author/iterate `intent.md` (+ `contract.md`), drive open questions, approve. See [Spec](../workflows/spec.md). |
| `/steer:work` | Execute a GitHub issue end-to-end — validate, claim, branch, implement, test, PR. Add `--reviewed` to wrap execution in independent plan- and code-review gates plus a bounded fix loop (the review-gated path formerly the `deliver` skill) — vetted, not first-draft. See [Work](../workflows/work.md). |
| `/steer:issues` | High-level GitHub Issues lifecycle for the spine — capture, triage, brainstorm, materialize, decompose, status, reconcile, and sequence into a release timeline. See [Issues](../workflows/issues.md). |
| `/steer:audit` | Repeatable whole-repo standards-conformance health audit, ranked by leverage. Read-only. Hands off to `/steer:drift` and `/steer:tidy`. Treats a declared-trunk unprotected `main` (solo trunk mode) as intentional, not a finding. |
| `/steer:adr` | Record a hard-to-reverse or cross-cutting decision as an ADR. See [Decisions](../decisions/index.md). |
| `/steer:next` | "What should I do next?" across the workspace. Read-only. |
| `/steer:protect` | Verify (and, on confirmation, apply) GitHub branch protection against `policy/branch-protection.yml` — the real PR gate — on the default branch plus any additional branches the policy declares (e.g. a `prod` promotion branch, whose required PR review is the production approval gate), plus the repo-level security settings it declares (secret scanning + push protection, Dependabot alerts + security updates). steer is advisory locally; this configures the server-side wall. Verify-only by default. Also the **graduation gate** out of solo trunk mode: running it raises the PR wall and ends the mode. Treats a declared-trunk unprotected `main` as intentional, not drift. |
| `/steer:standards` | Load the always-on operating manual on demand (for surfaces where the SessionStart hook doesn't fire). |
| `/steer:report` | File a bug about the **steer plugin itself** upstream in `element22llc/e22-plugins` — gathers the defect (a recorded hook fault, a contradictory skill/rule, or a missing/broken template/script), scrubs it of secrets/paths/product-code, deduplicates by a stable fingerprint, and files via `gh` only on confirmation (paste-URL fallback). For plugin defects, not product bugs. |

## Reached through a front door

`user-invocable: false` — hidden from the slash menu so the front doors stay
obvious, but still model-callable; you may invoke them directly when an intent maps
cleanly to one. Each is reached through the front door noted.

| Skill | Reached via | Purpose |
| --- | --- | --- |
| `/steer:init` | `/steer:setup` | One-time setup for a new repo — bootstrap the `/spec` spine + scaffold, or resolve legacy template placeholders. Offers solo **trunk mode** when one person is both PO and dev with no MVP yet (commit directly to `main`, no `feat/*`/PR ceremony, declared in the product `CLAUDE.md` `## Delivery mode`). |
| `/steer:adopt` | `/steer:setup` | Reverse-engineer a `/spec` spine from an existing app's code and add the scaffold. See [Adopt](../workflows/adopt.md). |
| `/steer:sync` | `/steer:setup` | Bring a managed repo up to date with the current plugin — apply migrations, reconcile spine + scaffold, repair missing/mis-wired capability-critical scaffold (plugin enablement, in-CI loading, version-pin enforcement, drift gate, branch-protection), re-stamp `/spec/.version`, land a PR. `--check` runs a read-only capability + drift report. |
| `/steer:doctor` | `/steer:setup` | Detect and install the local prerequisites a repo needs before init/build/dev — git, mise (and the pnpm/uv/node it manages), and Docker — with per-OS guidance and confirmation-gated installs. |
| `/steer:drift` | `/steer:audit` | Compare the as-built `/spec` against the tracker's intent and surface divergences. Read-only. |
| `/steer:tidy` | `/steer:audit` | Sweep loose files out of the repo root into their correct home (`/spec/reference`, `/spec/design`). |
| `/steer:roadmap` | `/steer:issues` | Generate a release-milestone timeline (viewable as a GitHub Projects v2 roadmap) by turning intended-but-unshipped work into milestone-grouped issues — `from-features` (target specs not yet live) or `from-gap` (a `/steer:drift` spec-gap), plus a `sync` reconcile. Proposes a dependency-ordered plan; never fabricates dates. |
| `/steer:questions` | `/steer:spec`, `/steer:issues` | Promote a spec's open question into a tracked issue when it outgrows the feature. |
| `/steer:conventions` | reference prose | Answer tooling/convention questions and the rationale behind stack defaults. Materialized into `/spec/reference/` once a repo is set up. |
| `/steer:traceability` | reference prose | Living-docs & traceability reference — how specs, issues, ADRs, tracker refs, and drift gates link up. Read-only. |
| `/steer:design-sources` | reference prose | Handle features originating from a Claude Design export/URL, Figma, or screenshots. |

## Internal gateways (never user-invoked)

`user-invocable: false` — called only by other skills, never a user's first move.

| Skill | Purpose |
| --- | --- |
| `/steer:tracker-sync` | The single gateway for all GitHub tracker reads/writes (MCP-first, `gh` fallback, manual floor). |
| `/steer:spec-scaffold` | Materialize the `/spec` spine files from the bundled templates. |

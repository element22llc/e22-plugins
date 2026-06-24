# Capability prerequisite map

Standing invariants: which bundled files a managed repo needs to use a given
**steer** capability, how to tell each is *present-and-wired* (not merely
present), how to repair a gap, and when the requirement does — and doesn't —
apply.

`/steer:sync` walks this on **every** sync (independent of `FROM`/`TARGET`),
after structural migrations + additive reconciliation and **before** re-stamping
`/spec/.version`. It is a **third axis**, distinct from the other two:

| Mechanism | Owns | Re-evaluated |
|---|---|---|
| [MIGRATIONS.md](MIGRATIONS.md) | non-additive transforms of artifacts that *exist* (rename/move/delete) | once, version-keyed |
| Template reconciliation ([SPEC-FRAMEWORK.md](SPEC-FRAMEWORK.md)) | additive splices *within files that exist* (`##` sections, `- [ ]` items, rows) | every sync |
| **CAPABILITIES.md** (this file) | **whole-file presence + wiring** of capability-critical scaffold | every sync |

The gap this closes: additive reconciliation never *creates* a missing file, and
the ledger only transforms files that already exist. So a repo adopted before a
capability shipped (or that lost a wiring file) silently lacks it, and sync would
otherwise report "current." This file is what makes sync repair that.

Detection is deterministic via
[`scripts/scan-capabilities.sh`](../../scripts/scan-capabilities.sh), which emits
`present-wired | absent | mis-wired | disabled | n/a` per capability plus two
informational fingerprints, `stack` (`node | python | polyglot | none`) and
`profile` (`app | infra | service | library | cli`, from the `CLAUDE.md`
`## Profile` marker). **Keep the capability set in that script in lockstep with
the entries below** (the hook test suite asserts every id the script emits is
documented here, exempting the `stack`/`profile` fingerprints). This doc owns the
repair semantics + conditionality the script can't decide.

**Profile and capability conditionality.** Capabilities are conditioned on the
`stack` fingerprint, not on `profile` — and `stack=none` already does the right
thing for an `infra` repo (no `package.json`/`pyproject.toml`), dropping
`node-tooling` and `worktree-port-isolation` to `n/a`. The `profile` emit is for
reporting only (`/steer:sync`, `/steer:report`); do **not** add a second,
profile-keyed conditioning axis for a decision `stack` already makes. `toolchain-pin`
is profile-agnostic — it checks the repo-root `mise.toml`, which every profile
installs (the `infra` profile's is the tofu/terragrunt/ansible flavor).

## Discipline

- **Read-then-propose, never clobber.** Diff before touching any file that
  exists; reconcile into it rather than replacing it; preserve every filled-in
  value. The lone exception is a `verbatim` file (see below).
- **Create only when the conditional predicate applies.** Absence of a
  conditional file in a repo whose stack/tracker doesn't match is `n/a`, **not**
  `missing` — never re-add it.
- **`disabled` is respected, never repaired.** A `"steer@e22-plugins": false` (or
  an equivalent deliberate opt-off) means the team turned the capability off;
  report it and move on. There is no opt-out file — a deliberately-dropped
  *always* capability re-appears as a proposal each sync and the dev declines it.
- **`verbatim` files are re-copied, not merged.** The version-pin scripts are
  contractually byte-identical to the plugin source — there is no room for
  product adaptation, so a drifted copy is *replaced*. **Show the diff first** and
  warn that local edits will be lost (move product-specific pins to
  `policy/versions.yml` instead); never silently overwrite.
- **Some repairs need a human/external step sync can't do** (an org GitHub App
  secret; applying branch protection server-side). Create what can be created,
  report the rest as `wired-pending-secret` / a follow-up, and never claim the
  capability is fully repaired. Surface the follow-up in the
  `## Recommended next actions` block ([NEXT-ACTIONS.md](NEXT-ACTIONS.md)).
- Resolve plugin version + paths from `${CLAUDE_PLUGIN_ROOT}`, never from memory.

Each entry carries five fields. The detector mechanically checks **Files**,
**Wired-when**, and **Verbatim**; the skill applies judgment to **Conditional**
and **Repair**.

## Entries

### plugin-enabled-local — local sessions load steer
- **Files:** `.claude/settings.json`
- **Conditional:** always
- **Wired-when:** `enabledPlugins` contains `"steer@e22-plugins": true`. A
  `false` value is reported `disabled` and respected.
- **Repair:** additive splice the `steer@e22-plugins` entry into `enabledPlugins`
  (and the `e22-plugins` marketplace into `extraKnownMarketplaces`), preserving
  every existing key. Never replace the file. Source:
  `templates/scaffold/claude/settings.json`. (The pre-2.0.0 dead
  `e22-standards@e22-plugins` key is *removed* by the v2.0.0 ledger migration in
  [MIGRATIONS.md](MIGRATIONS.md), not here — that rewrite runs before this repair,
  so by the time this runs the live key already exists and the splice is a no-op.
  This repair only ever *adds*.)
- **Verbatim:** no
- **Why it matters:** without this, the plugin never loads locally — no skills, no
  rules, no hooks. The repo degrades to stock Claude.

### delivery-mode-declared — explicit delivery mode in CLAUDE.md
- **Files:** `CLAUDE.md`
- **Conditional:** always (every managed repo has a `CLAUDE.md` and runs in some
  delivery mode).
- **Wired-when:** `CLAUDE.md` carries a `steer:delivery-mode=` marker
  (`<!-- steer:delivery-mode=pr-flow|solo-trunk -->`). Without it the
  commit-autonomy and issue-first hooks **fail open to `pr-flow`** — functionally
  safe, but the choice is invisible and a solo, pre-MVP dev never discovers
  solo-trunk. `CLAUDE.md` present without the marker is `mis-wired`; an absent
  `CLAUDE.md` is `absent`.
- **Repair:** a **human decision** — `sync` never picks the mode. Propose
  additive-splicing the `## Delivery mode` section from
  `templates/scaffold/CLAUDE.md` (which documents both modes) with the marker
  defaulting to `pr-flow` — matching the hooks' fail-open, so behaviour is
  unchanged — and **surface the solo-trunk option**, recommending it when the repo
  is a solo PO+dev with no MVP/deploy yet (rule `45-commit-autonomy`). Additive
  only: never edit or overwrite an existing `## Delivery mode` section. To adopt
  solo-trunk on an existing repo the dev flips the marker; `/steer:protect`
  graduates it back to `pr-flow`.
- **Verbatim:** no
- **Why it matters:** a repo bootstrapped before solo-trunk existed (≤ 2.11.0)
  silently runs `pr-flow` forever — the solo-trunk offer lives only in `init`'s
  run-once interview, and `sync` carries the spine forward without re-asking. This
  is the one place a later sync can surface the choice.

### in-ci-plugin-loading — @claude CI runs under steer standards
- **Files:** `.github/workflows/claude.yml`
- **Conditional:** always (GitHub-hosted repos)
- **Wired-when:** file contains `plugin_marketplaces`. An `enabledPlugins` block
  does **not** count — it is trust-dialog gated and no-ops in headless CI.
- **Repair:** create from `templates/github/workflows/claude.yml` (copy-and-adapt);
  propose. Needs org variable `STEER_APP_ID` + secret `STEER_APP_PRIVATE_KEY` to
  clone the private marketplace — if those are absent the file is inert; report
  `wired-pending-secret` and name the org-App setup as a human follow-up.
- **Verbatim:** no
- **Why it matters:** without it the in-CI `@claude` agent runs standards-less —
  no Definition of Done, no spec/drift discipline.

### version-pin-enforcement — committed-state version-pin gate
- **Files:** `policy/versions.yml`, `scripts/scan-version-pins.sh`,
  `scripts/version-policy.sh` (+ the `ci.yml` scanner step, covered by
  `drift-gate`)
- **Conditional:** always
- **Wired-when:** `policy/versions.yml` present **and** both scripts
  byte-identical to the plugin source (`scripts/scan-version-pins.sh` ↔
  `${CLAUDE_PLUGIN_ROOT}/scripts/scan-version-pins.sh`; `scripts/version-policy.sh`
  ↔ `${CLAUDE_PLUGIN_ROOT}/hooks/lib/version-policy.sh`).
- **Repair:** create a missing `policy/versions.yml` from the plugin default
  (never tighten silently — a product may raise floors, sync must not). **Re-copy**
  drifted scripts verbatim (show the diff + the lost-edits warning first).
- **Verbatim:** scripts yes; `policy/versions.yml` no (a product may tighten it).
- **Why it matters:** without it, neither the interactive hook nor CI catches a
  major pinned below the supported floor.

### drift-gate — CI hygiene check + PR drift checklists
- **Files:** `.github/workflows/ci.yml`, `.github/pull_request_template.md`
- **Conditional:** always (GitHub-hosted repos)
- **Wired-when:** `ci.yml` invokes `scan-version-pins.sh` (the steer hygiene job)
  **and** the PR template is present (it carries the spec-sync, drift-gate, and
  living-docs checklists).
- **Repair:** additively splice the missing job/step or PR-template section; never
  clobber product-specific CI steps. Sources under `templates/github/`.
- **Verbatim:** no
- **Why it matters:** `ci.yml` is the single required status check behind branch
  protection; the PR template is where drift classes are surfaced before merge.

### branch-protection-policy — machine-readable PR gate description
- **Files:** `policy/branch-protection.yml`
- **Conditional:** always
- **Wired-when:** present.
- **Repair:** create from the plugin default; propose. Applying it server-side is
  **`/steer:protect`** — name that as the follow-up; sync writes the policy file,
  it does not configure GitHub.
- **Verbatim:** no
- **Why it matters:** `/steer:protect` reconciles the live GitHub rule against
  this file; without it there is no declared gate to enforce.

### dependency-automation — Dependabot + the auto-merge exception
- **Files:** `.github/dependabot.yml`, `.github/workflows/dependabot-auto-merge.yml`
- **Conditional:** always (GitHub-hosted repos)
- **Wired-when:** both present; the auto-merge workflow guards on
  `github.actor == 'dependabot[bot]'` and gates on the `update-type`
  (patch/minor approved, majors left for a human).
- **Repair:** create either missing file from `templates/github/`. When restoring
  `dependabot.yml`, uncomment the ecosystem block(s) matching the detected stack
  (`npm`/`pip`/`docker`) rather than shipping only `github-actions`. The repo
  settings the exception relies on (Dependabot alerts + security updates) are
  **`/steer:protect`**'s job — name it as the follow-up; sync writes the files, it
  does not configure GitHub. The workflow scopes auto-merge to Dependabot itself;
  no repo-wide `allow_auto_merge` setting is used.
- **Verbatim:** no (ecosystems are adapted per stack)
- **Why it matters:** dependencies stay patched without manual chasing; the
  documented review-gate exception lets low-risk bumps auto-merge while the `ci`
  check stays the hard gate. Without the workflow, Dependabot PRs pile up awaiting
  a human even though they're safe once CI is green.

### toolchain-pin — pinned dev toolchain
- **Files:** `mise.toml` (required), `mise.lock` (created at pin time)
- **Conditional:** always
- **Wired-when:** `mise.toml` present. The scaffold ships **no** `mise.lock` —
  `/steer:init`/`/steer:adopt` create and commit it when they pin the toolchain.
  An absent lock means "not pinned yet", not a gap: CI installs unlocked until a
  populated lock lands. **Do not compare `mise.lock` contents** — they are
  per-machine/per-platform. An empty / comment-only lock is a defect (it pins
  nothing and breaks CI's `--locked`); a populated lock must never be flagged.
- **Repair:** create a missing `mise.toml` from the scaffold. For a missing
  `mise.lock`, pin the toolchain (`touch mise.lock`, `mise install`,
  `mise lock --platform linux-x64,macos-arm64`) rather than committing an empty
  one; flag (don't auto-write) an empty / comment-only lock. Never overwrite a
  populated lock.
- **Verbatim:** no
- **Why it matters:** no `mise.toml` ⇒ none of the standard tasks
  (`dev:setup`, `db:migrate`, …) exist; no `mise.lock` ⇒ the toolchain isn't
  pinned yet.

### node-tooling — Node lint/format baseline
- **Files:** `biome.json`, `configs/tsconfig.base.json` (+ `package.json`,
  `pnpm-workspace.yaml` as the stack signal)
- **Conditional:** Node stack only — applies when `package.json` or
  `pnpm-workspace.yaml` is present (polyglot counts; the predicate is "Node
  present", inclusive). Python-only / pre-app repos report `n/a`.
- **Repair:** create the missing Node config from the scaffold; adapt to the
  repo's real layout.
- **Verbatim:** no
- **Why it matters:** the Biome lint/format gate (and shared tsconfig) is the
  Node baseline the standards assume.

### github-issue-forms — PO-friendly Issue Forms
- **Files:** `.github/ISSUE_TEMPLATE/*` (`config.yml` + the YAML forms)
- **Conditional:** tracker is GitHub Issues — read `spec/tracker.md` frontmatter
  `system: github`. Any other tracker reports `n/a`.
- **Repair:** create from `templates/github/ISSUE_TEMPLATE/*`; then labels need
  **`/steer:issues bootstrap-labels`** (a follow-up, not this repair).
- **Verbatim:** no
- **Why it matters:** the Issue Forms carry the Issue Type + `source:`/`needs:`
  label taxonomy the issue-first workflow depends on.

### backing-services-compose — local backing services
- **Files:** `compose.yaml`
- **Conditional:** only if the product runs backing services — **not
  deterministically knowable.** The detector reports raw absence; the skill
  **proposes only after confirming with the dev**, and when uncertain asks rather
  than creating an unused `compose.yaml`.
- **Repair:** create from the scaffold once the service need is confirmed; adapt
  the real service list.
- **Verbatim:** no
- **Why it matters:** without it `mise run dev:setup` can't bring up local
  services — but a service-less product correctly has none, so this is the
  highest false-positive risk and stays propose-only.

### worktree-port-isolation — collision-free parallel worktrees
- **Files:** `scripts/worktree-env.sh`, `mise.toml`
- **Conditional:** only if the repo has a local runtime that binds host ports —
  i.e. a `compose.yaml` is present **or** the stack is Node/Python. A repo with
  no services and no app stack reports `n/a`, not missing.
- **Wired-when:** `scripts/worktree-env.sh` exists **and** `mise.toml`'s `[env]`
  sources it (`_.source = "scripts/worktree-env.sh"`). The script gives each
  Claude Code worktree a unique `COMPOSE_PROJECT_NAME` + a per-worktree host-port
  offset so parallel agents don't collide on Docker/ports; the primary checkout
  gets offset 0 (ports unchanged).
- **Repair:** create `scripts/worktree-env.sh` from the scaffold and additive-splice
  the `_.source` line into `mise.toml`'s `[env]` table. Preserve any product
  edits to the script's BASELINE port block.
- **Verbatim:** no — keep the `_.source` wiring and the offset logic; adapt only
  the BASELINE block (host ports per the product's services).
- **Why it matters:** without it, two agents in parallel worktrees both bind
  5432/3000 and share container/volume names — `docker compose up` in the second
  worktree fails and teardown in one can clobber the other.

<!-- Template for a new capability entry — copy, fill, and add a matching check to
     scripts/scan-capabilities.sh (same id) in the SAME change.

### <capability-id> — <one-line what it unlocks>
- **Files:** <install-target path(s)>
- **Conditional:** <always | the predicate from observed repo facts; absence when
  the predicate doesn't hold is `n/a`, never `missing`>
- **Wired-when:** <a literal, grep-able marker proving the capability is enabled,
  not just that the file exists>
- **Repair:** <create-from-scaffold | additive-splice the named marker |
  verbatim-recopy (show diff first) | propose-only/ask>
- **Verbatim:** <yes — re-copy, the lone never-clobber exception | no>
- **Why it matters:** <what breaks without it>

  When a migration MOVES a capability file, update its **Files** path here in the
  same change, or sync will see the new path absent and re-create the old file.
-->

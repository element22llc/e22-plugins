# Simplified Workflow Refactor — Design

**Status:** Design approved 2026-05-25, pending implementation plan.
**Target spec:** [`collaborative-ai-workflow-spec.md`](../../collaborative-ai-workflow-spec.md) v0.4.
**Companion:** [`CONSTITUTION.md`](../../../CONSTITUTION.md).

---

## 1. Goal

Refactor the `e22-plugins` marketplace from the v0.3 two-lane model (Prototype
Lane / Production Lane) to the v0.4 three-zone model (Local MVP Sandbox /
Handoff / Governed Production).

The PO must be able to install **one always-on organization plugin** and start a
brand-new MVP by talking naturally — no commands, no skills to remember, no
GitHub repository, no branch metadata, no Product Spine maintenance. Engineering
keeps its governance, applied only where it earns its keep.

---

## 2. End state at a glance

The marketplace shrinks from **8 plugins → 7 plugins**:

| Plugin | Status | Role |
|---|---|---|
| `e22-org` | **NEW** | Always-on org plugin. Always-loaded `CLAUDE.md`, sandbox guardrails, HANDOFF.md trigger instructions, shared zone-detect helper. |
| `security-rails` | keep | Universal hard guardrails, both zones. |
| `handoff-packager` | rewrite | Single-file `HANDOFF.md` generator per spec v0.4 §7.3. |
| `house-style` | rewrite | Always-loaded tech-stack + version-freshness guidance (both zones); PostToolUse lint/format hook (governed only). |
| `always-test` | rewrite | Production quality gate; hooks self-gate to governed zone. |
| `spine-writer` | rewrite | Product Spine generation; hooks and `/spine-refresh` self-gate to governed zone. |
| `production-lane` | scrub | Dev-facing PR/validate/promote tooling; `/validate` decision matrix updated to v0.4 §7.4 (Harden / Extract / Rewrite / Reject / Continue exploring). |
| `prototype-lane` | **DELETED** | Replaced by natural-language affordances in `e22-org`. |
| `spec-driven-dev` | **DELETED** | Lane-aware spec-gate logic obsoleted by v0.4 §10.3. |

**Install profiles** (documented in README, not enforced by the marketplace):

- **PO bundle:** `e22-org` + `security-rails` + `handoff-packager` + `house-style`.
- **Dev bundle:** all 7 plugins.

**Shared discriminator** — every plugin that needs to behave differently in the
two zones sources `e22-org/lib/zone.sh`, which echoes `governed` when the
workspace is a git repo whose `origin` remote contains `github.com`, otherwise
`sandbox`.

---

## 3. New plugin: `e22-org`

### 3.1 Structure

```text
plugins/e22-org/
├── .claude-plugin/plugin.json
├── CLAUDE.md
├── hooks/
│   ├── sandbox-guardrails.sh
│   └── handoff-cue.sh
├── lib/
│   └── zone.sh
└── templates/
    └── HANDOFF.md.template
```

### 3.2 `CLAUDE.md` (always-loaded baseline, target ≤ 120 lines)

Contents, in order:

1. **The workflow in one line.** Restate the v0.4 mission tagline.
2. **Three zones.** Sandbox / Handoff / Production, with owners and tooling.
3. **Plain-language affordances.** What the PO can say ("build an MVP for…",
   "try a different checkout flow", "handoff this", etc.).
4. **Handoff trigger.** When the user's prompt matches any of:
   - "handoff this"
   - "package this for dev"
   - "I'm done with the MVP"
   - "turn this into a dev brief"
   - "extract the spec"
   - or equivalent expressions of handoff intent,

   generate `HANDOFF.md` at the workspace root from
   `plugins/e22-org/templates/HANDOFF.md.template`, populating all 15 sections
   (spec v0.4 §7.3). Sections 8 (risks), 9 (shortcuts), 10 (must-not-reuse),
   12 (suggested tests), 13 (open questions) are **mandatory** and must not be
   left blank — write "No evidence collected" if no evidence exists, never
   fabricate.
5. **Sandbox guardrails (instructions).** Fake data by default. Refuse real
   secrets, production credentials, real PII, real customer data, live payment
   or auth integrations, production databases. Label shortcuts and assumptions
   as they appear.
6. **Production-boundary reminders.** No direct push to `main`. PR / CI /
   review / approval / rollback path required for production work.
7. **Tech-stack pointer.** Read `TECH-STACK.md` before generating code in any
   zone. Prefer the latest stable version of any dependency. Defer to
   `context7` if installed.

### 3.3 Hooks

Hooks fire only on surfaces that support them (Claude Code today). On Chat /
Cowork / Artifacts the same rules apply as instructions in `CLAUDE.md`. This is
acceptable because the sandbox cannot deploy or use real production inputs (spec
v0.4 §5.3, §12 boundary #1–4).

**`sandbox-guardrails.sh`** (PreToolUse on Write / Edit / MultiEdit; both zones):
- Complements `security-rails` (which already blocks secrets, AWS access keys,
  Stripe live keys, raw-SQL interpolation). This hook covers what
  `security-rails` does not:
  - Real-PII patterns (SSN-shaped, credit-card-shaped, IBAN-shaped).
  - Production-DB connection strings (heuristic: explicit `prod` / `production`
    host segment plus a credential-bearing URL form).
- Hard block in both zones. Spec v0.4 §12 boundary #3 (no real PII in
  sandbox) is non-negotiable; the sandbox is not a soft-warning zone for real
  customer data.

**`handoff-cue.sh`** (UserPromptSubmit; both zones):
- Greps the prompt for the handoff trigger phrases listed in §3.2 (4).
- On match, emits a system reminder telling Claude to follow the
  HANDOFF.md-generation instructions in `CLAUDE.md`.
- Belt-and-suspenders to the always-loaded instruction; does not replace it.

### 3.4 `lib/zone.sh`

Single-purpose helper sourced by every other plugin that needs zone detection:

```sh
e22_zone() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
       && git remote get-url origin 2>/dev/null | grep -qi github.com; then
    echo governed
  else
    echo sandbox
  fi
}
```

Conventions for callers:

```sh
source "${CLAUDE_PLUGIN_ROOT}/../e22-org/lib/zone.sh"
[[ "$(e22_zone)" == "governed" ]] || exit 0
```

### 3.5 `templates/HANDOFF.md.template`

Verbatim from spec v0.4 §7.3. 15 sections. Mandatory sections marked.

### 3.6 Manifest

`plugin.json`: `name: "e22-org"`, `version: "0.1.0"`,
`category: "always-on"`, description summarizing the role.

---

## 4. Rewrites

### 4.1 `handoff-packager` → v0.2.0

**Remove:**
- `commands/package.md` (the `/package` slash command). The natural-language
  trigger in `e22-org` replaces it.
- Multi-file output (`dependency-delta.md`, `novel-patterns.md`,
  `plugin-violations.md`).
- The `proposals/<slug>/handoff/` path scheme.
- GitHub-connector requirement.

**Add `CLAUDE.md`** (loaded when this plugin is installed):

- How to populate each of the 15 sections from chat + workspace evidence.
- Mandatory sections enumerated.
- "Write 'No evidence collected' instead of fabricating."
- "Output `HANDOFF.md` at the workspace root, not under `proposals/`."

**Optional skill** `skills/handoff-quality-check/SKILL.md`:
- Triggers after a `HANDOFF.md` is written.
- Re-reads the file and flags any mandatory section whose body is stub text or
  missing.

**Manifest:** bump to `0.2.0`, drop "Invoked by /package-handoff" text, drop the
`github-connector` keyword.

### 4.2 `house-style` → v0.2.0

**Keep:** existing PostToolUse lint/format hooks.

**Change one thing in each hook:** prepend the zone gate.

```sh
source "${CLAUDE_PLUGIN_ROOT}/../e22-org/lib/zone.sh"
[[ "$(e22_zone)" == "governed" ]] || exit 0
```

**Add `CLAUDE.md`** (always-loaded; both zones; ≤ 30 lines):

- "Before generating code in any zone, read `TECH-STACK.md` and the nearest
  product `CLAUDE.md`."
- "Prefer the latest stable version of any dependency you add."
- "Defer to `context7` for current API and version docs if installed."
- "If a manifest is missing or the stack is unclear, ask — do not guess."
- "Naming conventions are advisory in the sandbox; enforced in production."

**Manifest:** bump to `0.2.0`, drop "lane-aware" wording.

---

## 5. Self-gates and vocabulary scrubs

### 5.1 `always-test` → v0.3.0

- Drop branch-prefix reading entirely (no more `prototype/*` vs `proposal/*`).
- Source `e22-org/lib/zone.sh` in PostToolUse and Stop hooks; exit 0 in sandbox.
- Sandbox = silent. Governed = full enforcement.
- Description rewrite: drop "lane-aware"; add "self-gates to governed zone."

### 5.2 `spine-writer` → v0.2.0

- PostToolUse hook self-gates (sandbox = exit 0). Implements spec v0.4 §10.3
  "no continuous Product Spine writing during exploration."
- `/spine-refresh` command: keep, but add a refusal at the top if zone is
  sandbox: "Product Spines are a governed-production artifact. Run this after
  the work is imported into a repo."
- `spine-staleness-cue` skill: keep — auto-triggers are meaningful only inside
  governed repos.
- `spine-extractor` agent: keep.

### 5.3 `production-lane` → v0.3.0

**Decision-matrix update** (spec v0.4 §7.4) — breaking change to `/validate`:

| Old label | New label |
|---|---|
| Keep | Harden |
| Refactor | Extract |
| Redesign | Rewrite |
| Reject | Reject |
| — | Continue exploring |

Apply to:

- `commands/validate.md`
- `skills/validation-decision/SKILL.md` (auto-trigger description and body)
- Any agent prompts (`spec-refiner`, `drift-monitor`) that reference the old
  four labels.

**Vocabulary scrub:**

- Replace every "lane" with "zone" or remove.
- Remove every reference to `prototype-lane`, `/vibe`, `/package-handoff`.
  Replace with "the handoff packet from `e22-org`."
- Remove every reference to `spec-driven-dev`.

### 5.4 `security-rails` → v0.2.1

Patch — description tweak to mention "applies in both sandbox and governed
zones." No behavior change.

---

## 6. Deletions

```text
plugins/prototype-lane/      DELETE
plugins/spec-driven-dev/     DELETE
```

Pre-deletion sweep — grep surviving plugins for any cross-references to these
two and clean up in the same change set. Expected matches:

- `production-lane/commands/validate.md`
- `production-lane/skills/validation-decision/SKILL.md`
- `spine-writer/commands/spine-refresh.md`
- root `CLAUDE.md` (auto-trigger skills table)
- root `README.md` (two-lane narrative)
- `MARKETPLACE_VALIDATION.md`

---

## 7. Marketplace and repo-level docs

### 7.1 `marketplace.json`

```json
{
  "name": "e22-plugins",
  "description": "Element 22 plugin catalog — three zones (Sandbox, Handoff, Production), one always-on org plugin, governance only where it earns its keep. For Claude Code, Claude Chat, and Claude Cowork.",
  "plugins": [
    { "name": "e22-org",          "category": "always-on" },
    { "name": "security-rails",   "category": "always-on" },
    { "name": "handoff-packager", "category": "always-on" },
    { "name": "house-style",      "category": "always-on" },
    { "name": "always-test",      "category": "production" },
    { "name": "spine-writer",     "category": "production" },
    { "name": "production-lane",  "category": "production" }
  ]
}
```

(Full plugin entries include `source`, `description`, `keywords` per existing
convention.)

### 7.2 Repo-level docs

| File | Change |
|---|---|
| `CLAUDE.md` (root) | Full rewrite. Three-zone model; PO experience as natural language; Dev install profile. Delete the auto-trigger skills routing table. |
| `README.md` | Headline + zone narrative rewrite; plugin list (7); drop "two lanes" wording. |
| `CONSTITUTION.md` | Verify cross-refs to deleted plugins; update plugin list. |
| `MARKETPLACE_VALIDATION.md` | Update plugin count, version baselines, install profiles. |
| `CONNECTORS.md` | Clarify: GitHub required for governed zone only; sandbox is connector-free. |
| `PRODUCT_SPINE_TEMPLATE.md` | Keep; add a note: "Used by Dev after import into a governed repo, not during PO sandbox exploration." |
| `TECH-STACK.md` | No content change; verify cross-refs. |

---

## 8. Version-bump summary

| Plugin | Before | After | Change kind |
|---|---|---|---|
| `e22-org` | — | 0.1.0 | new |
| `security-rails` | 0.2.0 | 0.2.1 | patch |
| `handoff-packager` | 0.1.0 | 0.2.0 | minor |
| `house-style` | 0.1.0 | 0.2.0 | minor |
| `always-test` | 0.2.0 | 0.3.0 | minor |
| `spine-writer` | 0.1.1 | 0.2.0 | minor |
| `production-lane` | 0.2.1 | 0.3.0 | minor (breaking decision-label change) |
| `prototype-lane` | 0.3.0 | — | deleted |
| `spec-driven-dev` | 0.1.0 | — | deleted |

---

## 9. Implementation order

The detailed step-by-step plan is the job of the writing-plans skill; the
high-level order is:

1. Create `plugins/e22-org/` skeleton, including `lib/zone.sh` and
   `templates/HANDOFF.md.template`. Everything else depends on this.
2. Add the zone gate to surviving hook plugins (`always-test`, `spine-writer`,
   `house-style`). Verify both zones manually.
3. Rewrite `handoff-packager` to single-file output. Verify the end-to-end
   natural-language handoff flow.
4. Scrub `production-lane` vocabulary and update the `/validate` decision
   matrix.
5. Delete `plugins/prototype-lane/` and `plugins/spec-driven-dev/`.
6. Rewrite root-level docs (`CLAUDE.md`, `README.md`, `CONNECTORS.md`,
   `MARKETPLACE_VALIDATION.md`, note in `PRODUCT_SPINE_TEMPLATE.md`).
7. Update `marketplace.json`.
8. Bump versions in every touched `plugin.json`.

---

## 10. Open questions intentionally deferred

These come back only if a real failure mode shows up (matches spec v0.4 §10.3):

- Whether `handoff-quality-check` belongs in `handoff-packager` or `e22-org`.
- Whether zone detection needs a more explicit signal than the GitHub-remote
  heuristic (opt-in marker file, `CODEOWNERS` presence, etc.).
- Whether a Dev "production-toolkit" meta-plugin is worth creating once we see
  how POs and Devs install in practice.
- Whether the multi-file handoff bundle (current `handoff-packager` outputs)
  should return as a Dev-side post-import audit tool.

---

## 11. Non-goals

- No new lanes, no new zone-detection signals beyond the GitHub remote.
- No backwards-compatibility shims for the old `/package-handoff`, `/vibe`,
  `/validate` (old labels) commands — these are breaking removals/changes
  documented in version bumps and `MARKETPLACE_VALIDATION.md`.
- No changes to `TECH-STACK.md` content.
- No new agents.
- No code in non-shell languages.

# Collaborative AI Workflow — Specification

**Title:** From Vibes to Production — An AI-Native Collaborative Workflow
**Purpose:** Source of truth for AI agents and contributors working within this workflow.
**Tagline:** *How Product Owners ship ideas and Engineers ship systems — without one slowing the other down.*
**Version:** 0.3 — drop infrastructure layer, add project-type detection and minimum test floor.

---

## 1. Mission

Enable a single team to operate two speeds in one repository:

- **Product Owners (POs)** explore ideas at the speed of thought.
- **Engineers (Devs)** industrialize systems at the speed of governance.
- **Claude** carries meaning across the gap.

> Speed lives where speed is safe. Rigour lives where rigour is needed. The Product Spine — and the Claude that maintains it — is what makes the two compatible.

---

## 2. The Tension Being Resolved

| Product Owner | Engineer |
|---|---|
| Ideas move at the speed of thought. | Code moves at the speed of governance. |
| Wants to see it working, not read about it. | Wants to understand it before owning it. |
| Five rough drafts beat one polished doc. | A clean diff beats a clever demo at 3am. |
| Cares about: user outcome, look-and-feel, momentum. | Cares about: reliability, security, maintainability. |
| *"Can we just try it and see?"* | *"Who will own this in six months?"* |

**Design rule:** Most workflows force one side to slow down to meet the other. This workflow refuses that tradeoff.

---

## 3. Roles

| Role | Verb | Primary surface |
|---|---|---|
| **Product Owner (PO)** | *describes / explores* | Plain-language chat with Claude |
| **Claude** | *bridges / structures / translates* | Workspace + repo + plugin pack |
| **Engineer (Dev)** | *industrializes* | PR review, architecture decisions, CI |

Claude is a first-class participant — not a utility — and operates under the same plugin pack regardless of who is talking to it.

---

## 4. Shared Infrastructure (Same Team, Same Tools)

Three components are shared across both lanes. Together they provide shared context for humans and AI alike — no re-explaining the product every Monday.

### 4.1 Claude Team — Shared AI Workspace

Operationally, "shared Claude" is not a single thing but five layers — only the first four are canonical:

| Layer | What's shared | Canonical? |
|---|---|---|
| Workspace environment | Same Claude Team org | Yes |
| Behavior rules | Same plugin pack, at the same version | Yes |
| Repo context | Same code, specs, decisions | Yes |
| Durable product memory | The Product Spine, in the repo | Yes |
| Individual chat history | Per-session working memory | **No** — never a system of record |

> **Rule:** Claude conversations are *working memory*; the Product Spine is *durable memory*. Anything that needs to survive the conversation must land in the repo.
>
> **Cultural restatement:** *A chat can propose a decision; only the repo can record a decision.*

This prevents the common drift where someone says *"but we discussed this with Claude last week"* and treats a chat log as authoritative.

### 4.2 GitHub Org — Single Source of Truth

- Code, specs, and decisions in **one repo per product**.
- Branches are cheap; chaos lives on its own branch.
- Every branch carries machine-readable metadata (§9.1).
- Every change — **even from a PO** — is git-tracked and auditable.

---

## 5. The Two Lanes

The workflow has two lanes joined by a structured handoff. **The lane is a property of the branch, not the person or the branch's origin.** POs cross into the production lane; production code can be revisited via prototype-style loops. The lane is declared in `/.workflow/branch.yaml` (§9.1) and enforced by CI.

### 5.1 Lane Comparison

| Dimension | Prototype Lane | Production Lane |
|---|---|---|
| **Who initiates** | PO talks to Claude | PO or Dev opens a PR |
| **Branching** | Throwaway branches per idea | Feature branches off `main` |
| **Data** | Synthetic / fake fixtures | Real data, real guardrails |
| **Tests required** | Smoke test scaffolded by Claude | Full suite must pass CI |
| **Review** | Self-review on a preview URL | Engineer review on the diff |
| **Rollback** | Delete (archive) the branch | Flag off, then revert PR |
| **Approvals** | None | Scaled by change type (§9.4) |
| **Project type** | Detected on branch creation; written to branch.yaml | Inherited from main; not re-detected |

---

## 6. The Arc of a Change — Six Stages

> Chaos in, structure out — in six stages.

```
[ PROTOTYPE LANE ]              [ HANDOFF ]              [ PRODUCTION LANE ]
   01 PO Explores       →    03 AI Extracts Spec     →    05 Production Lane
   02 Sandbox Contains       04 Dev Validates              06 Governed Iteration
```

---

### Stage 01 — PO Explores *(Prototype Lane)*

**Principle:** Zero gates. Zero shame. *Five rough drafts beat one polished doc.*

The PO opens Claude, says what they want, and a working preview appears on a new branch within minutes. **No spec to write first. No ticket to file.** Iteration is the loop.

**Happening under the hood (automatic):**

- **Branch created** — e.g., `feat/po-redelivery-flag`
- **Branch metadata written** — `/.workflow/branch.yaml` (§9.1) declares lane, owner, project type, expiry, plugin pack version, change type.
- **Claude writes code** — house rules enforced via the plugin pack at the version pinned in branch metadata.
- **Tests scaffolded** — even prototypes ship with a smoke test.

**Example PO prompt (`po-prompt.md`):**
> *Add a way for customers to flag an order for re-delivery.*
> *Make the button live next to the order status.*
> *Show me three variants of the modal — I'll pick.*

---

### Stage 02 — Sandbox Contains *(Prototype Lane)*

**Principle:** *Chaos is fine — as long as it's contained.*

Every prototype lives on its own branch — disposable, named, metadata-tagged. The platform-layer guarantees (preview URLs, sandbox credentials, network isolation from production) return when the platform substrate is chosen; until then the sandbox principles below are upheld by reviewer attention and the plugin pack's soft rules. Rolling back is archiving the branch.

**The sandbox principles:**

1. **Branch-per-idea** — cheap, disposable, named, metadata-tagged.
2. **Synthetic data** — no PII, no real customers; fixtures only.

The remaining two guarantees from v0.2.1 (ephemeral URLs and sandbox secrets) depended on platform infrastructure and are deferred until the platform substrate is chosen. Until then, the sandbox principles are enforced by reviewer attention and the plugin pack's soft rules — not by infrastructure.

If it goes wrong, you archive a branch — not write a postmortem.

---

### Stage 03 — AI Extracts Spec *(Handoff)*

**Principle:** The artefact that travels is the Product Spine — not the chat log.

**What exists at the moment of handoff:**

- A working preview URL
- Commits — useful and not — on the branch
- A long Claude chat full of context
- PO comments on the preview ("move this")
- Whatever tests Claude was told to scaffold

**Claude's job at handoff:** distill the above into the **Handoff Bundle** (§9.3) — structured artefacts written back to the repo. The Bundle contains the Product Spine plus a Dev-facing summary, including an explicit list of prototype shortcuts that must **not** be carried into production.

#### The Product Spine (the spec format)

| Section | Contents |
|---|---|
| **Intent** | User problem, success criteria |
| **UX** | Screens, states, copy, decisions |
| **Surface** | API endpoints, events, schemas |
| **Architecture** | Components, data flow, assumptions |
| **Open questions** | Things Claude couldn't decide alone |

The Spine is the canonical, persistent representation of *what this change means*. It is **what travels between lanes**, not the chat history.

**Gate:** Handoff packaging is blocked until the Prototype Ready Checklist (§9.2) is complete. Claude refuses to produce the Bundle until then.

---

### Stage 04 — Dev Validates *(Handoff)*

**Principle:** *Review the spec — not just the diff.*

By the time Dev arrives, the question is no longer *"does it work?"* — the preview proves that. The question is whether the implied architecture is something the team will still want to own in a year.

#### The Four Decisions

| Decision | Meaning |
|---|---|
| **Keep** | Prototype is production-shaped. Harden in place. |
| **Refactor** | Intent is right, implementation needs rework. |
| **Redesign** | Right problem, wrong architecture. Restart cleanly. |
| **Reject** | Wrong problem. Send back to exploration with notes. |

**Claude pre-flights the review via the Handoff Bundle (§9.3):**

- Highlights novel patterns
- Flags violations of the plugin pack
- Lists every dependency added since `main`
- Calls out prototype shortcuts not to be carried forward
- Suggests a decision with reasoning

**Dev's job is to make a decision, not to read the whole branch.**

---

### Stage 05 — Production Lane (Industrialize)

**Principle:** *AI hardens; humans approve. Same Claude, stricter rules — the plugin pack tightens its lane-aware rules when `lane: production`.*

**What gets added to what survived the gate:**

- **Tests** — unit, integration, smoke — pinned to the spec.
- **Types & lint** — strict mode, security linters, dependency scan.
- **Observability** — logs, metrics, traces wired before shipping.
- **Feature flags** — risky changes ship dark, ramp by cohort.

**Scaled approval (§9.4) applies:** product approval (intent) and engineering approval (implementation) are recorded separately on the PR; ceremony depends on `change_type`.

#### The Production CI Pipeline

```
Lint → Type → Test → Build → Spine Drift Check → Preview → Approve → Deploy
```

All stages must be green. Spine Drift Check (§9.6) ensures the spec keeps pace with the code. Deploy requires the approvals defined in §9.4.

---

### Stage 06 — Governed Iteration *(Production Lane)*

**Principle:** *Same front door for the PO. A real lock on the back door.*

Once code is in production, every change — even a one-word copy tweak from the PO — flows through the same path: **branch → PR → CI → approval (scaled by §9.4) → merge.**

| What stays the same (for the PO) | What becomes mandatory (any prod-touching change) |
|---|---|
| Talks to the same Claude, in plain language | Pull request — no direct pushes to `main` |
| Gets a live preview URL within minutes | Green CI — lint, type, test, security scan, Spine drift |
| Sees a working result before approving | Approvals per the §9.4 matrix |
| Never needs to read a Jira ticket | The Product Spine updates with the change |

Sensitive domains (auth, payments, PII, permissions, billing, data model) carry extra rails (§9.7).

---

## 7. Between Stages — Loop Back

**Principle:** *Production code stays explorable. The lane is a property of the branch, not its origin.*

### 7.1 Fixtures Get Harder

- A greenfield prototype invents its data.
- A branch off `main` must **mock the real schema — without ever touching real credentials**, even for a moment. Claude enforces this with reviewer attention as the backstop.

### 7.2 The Spine Travels (The Code May Not)

The implementation is a thinking tool. What survives the loop is the Spine.

| Loop length | Outcome |
|---|---|
| **Short loop** | Rebase and ship |
| **Medium loop** | Re-implement on current `main` |
| **Long loop** | Keep only the decisions; rewrite from scratch |

### 7.3 Scale the Gate

**Not every loop earns the full ceremony.** The Spine writer plugin (§9.6) classifies the diff and approvals are scaled per §9.4:

| Change type | Spine classification | Ceremony |
|---|---|---|
| Copy tweak | Cosmetic | Light Spine note, one approver (§9.4) |
| New flow | Behavioral | Full Spine + scaled approval gate |
| Rearchitecture | Behavioral + structural | Expect verdict to be *Refactor* or *Redesign* |

### 7.4 Sensitive Domains — Extra Rails

For **auth, payments, PII, permissions, billing, data model changes**: the temptation to peek at production code is highest exactly where it matters most. These domains follow the Sensitive Change Policy (§9.7).

> *Revisit checkout six months after launch — just not from `main` directly.*

---

## 8. The Plugin Pack — House Rules in Four Layers

**Principle:** *A plugin pack is a versioned bundle of behavior, contracts, policies, guards, and review rules — applied automatically to every Claude session, whether a PO is vibe-coding or a Dev is shipping a hotfix.*

The term *plugin pack* is preserved as the friendly, user-facing concept. Internally, it decomposes into **four distinct enforcement layers**, each with its own substrate and failure mode. AI Instructions are soft; the other three are hard. CI and Review-Rule enforcement are what protect the system when Claude is wrong, slow, or absent.

### 8.1 The Four Layers

| Layer | Substrate | Examples | Enforced by | Failure if Claude is wrong? |
|---|---|---|---|---|
| **AI Instructions** | Claude project config / system prompts | Spec-driven dev, always-test, house style guidance, handoff packager logic, Spine writer logic | Claude itself (soft) | Bypassable — needs a backstop in another layer |
| **Repo Contracts** | Files committed to the repo | `/.workflow/branch.yaml`, `/.workflow/handoff.md`, `/product-spine/*`, ADRs | Schema validation in CI | Hard — invalid file blocks merge |
| **CI Policies** | GitHub Actions / workflow runs | Lint, type, security scan, Spine drift check, branch.yaml validation, smoke test gate | CI runner | Hard — red CI blocks merge |
| **Review Rules** | GitHub-native | CODEOWNERS, branch protection, required-approvals matrix | GitHub | Hard — PR cannot merge without satisfying reviewers |

Each rule in the plugin pack maps to **at least one hard layer**. A behavior that exists *only* as an AI instruction is acceptable for ergonomics but cannot be relied on for safety.

### 8.2 The Standard Pack — Where Each Rule Lives

| Rule | AI Instructions | Repo Contract | CI Policy | Review Rule |
|---|:-:|:-:|:-:|:-:|
| Spec-driven dev | ✓ | ✓ (Spine present) | ✓ (drift check) |  |
| Always-test (smoke) | ✓ |  | ✓ (smoke gate) |  |
| House style | ✓ |  | ✓ (lint) |  |
| Security rails | ✓ |  | ✓ (secret scan, SAST) | ✓ (security CODEOWNERS) |
| Spine writer | ✓ | ✓ | ✓ (drift + accuracy audit, §9.6) |  |
| Handoff packager | ✓ | ✓ (`handoff.md`) | ✓ (presence + freshness) |  |
| Two-stage approval |  |  | ✓ (PR check) | ✓ (CODEOWNERS, §9.4) |

### 8.3 Pack Properties

- **Centrally authored**, automatically loaded into every Claude session and every CI run.
- **Lane-aware**: production rules are stricter than prototype rules.
- **Versioned**: packs are semver-versioned; every branch records `plugin_pack: <name>@<version>` in `branch.yaml`.
- **Governed**: pack lifecycle, approval, deprecation are defined in §9.8.
- **Compounding**: every rule the team writes makes every future Claude session better.

> *Update a rule once. Every Claude session — PO or Dev — picks it up tomorrow. Every CI run enforces it tonight.*

---

## 9. Operational Enforcement

The sections above describe how the workflow should behave. This section defines how it is **enforced** — by Git, CI, Claude, and reviewers — so the workflow does not depend on goodwill. Without this section, the spec is a wish; with it, the spec is a control plane.

### 9.1 Branch Metadata

Every branch declares its lane and policy in a machine-readable file at `/.workflow/branch.yaml`. CI, preview deploys, Claude, and reviewers all read this file.

```yaml
change_id: redelivery-flag
lane: prototype                          # prototype | production
base_branch: main                        # the branch this was cut from
change_type: behavioral                  # trivial | cosmetic | behavioral | structural | sensitive
project_type: greenfield                 # greenfield | brownfield
owner: alexis
created_by: claude
initiated_by: product_owner              # product_owner | engineer
preview_url: https://prv-redelivery-flag.example.app
plugin_pack: tlm-product-workflow@0.3.1
created_at: 2026-05-25
expires_at: 2026-06-08
renewals: 0                              # see §9.5
spine_path: product-spine/changes/redelivery-flag.md
handoff_status: exploring                # exploring | ready | in_review | merged | dropped
sensitivity: standard                    # standard | sensitive (see §9.7)
```

**Why `change_type` is separate from `sensitivity`:** `sensitivity` captures blast radius (auth, payments, PII…). `change_type` captures the *shape* of the change (copy tweak vs. new flow vs. rearchitecture). They scale ceremony along different axes and CI uses both.

**Enforcement:**

- CI refuses to deploy a preview without a valid `branch.yaml`.
- `change_type: sensitive` requires `sensitivity: sensitive`.
- Missing or malformed file → blocked merge, blocked preview.
- Claude refuses to operate on a branch with no `branch.yaml`.

### 9.2 Prototype Ready Checklist

A prototype branch enters handoff (Stage 03) only when all of the following are true. Claude verifies the list and **refuses to package a Handoff Bundle if any "Required" item is missing.**

| Criterion | Required? |
|---|---|
| PO has selected a preferred variant | Yes |
| Preview URL exists and is reachable | Yes |
| Intended user outcome is recorded in the Spine `Intent` section | Yes |
| Known tradeoffs and open questions are listed in the Spine | Yes |
| Smoke test exists and passes | Yes |
| PO explicitly requests handoff | Yes |
| `branch.yaml` is valid | Yes |
| `change_type` is set | Yes |
| `project_type` is set in branch.yaml | Yes |

`handoff_status` flips from `exploring` → `ready` when the checklist is complete, and is set by the Handoff packager — not by hand.

### 9.3 Handoff Bundle Format

At the moment of handoff, Claude produces a standardized Handoff Bundle and commits it to the branch at `/.workflow/handoff.md`. **This is the artefact the Dev reads** — not the chat log, not the diff alone.

```markdown
# Handoff Bundle — <change_id>

## 1. What the PO wanted
<problem, motivation, success criteria>

## 2. What changed in the prototype
<summary of behavior, screens, endpoints introduced>

## 3. Product Spine
<link to /product-spine/changes/<change_id>.md>

## 4. Files touched
<list with brief notes>

## 5. New dependencies since main
<runtime, dev, infra>

## 6. Risky patterns detected
<plugin pack warnings, novel patterns, security flags>

## 7. Open questions for the Dev
<things Claude could not decide alone>

## 8. Suggested decision
Keep / Refactor / Redesign / Reject

## 9. Why
<one-paragraph rationale>

## 10. What should NOT be reused
<prototype shortcuts, fake data assumptions, hardcoded users,
bypassed auth, inlined config, fragile implementation choices —
called out explicitly so they do not migrate to production by inertia>

## 11. Acceptance checks
<the observable conditions the PO will verify before granting
product approval on the production PR — concrete, behavioral,
not implementation-bound>
```

**Why sections 10 and 11 are mandatory:** A prototype almost always contains load-bearing fakes — seeded data, stub auth, hardcoded users, inlined config. Without an explicit *do-not-reuse* list, these migrate to production by inertia and silently weaken the system. The acceptance checks list anchors product approval (§9.4) to observable behavior, so a later refactor cannot quietly invalidate the PO's sign-off.

**Enforcement:**

- Stage 04 review cannot begin without a present and valid Handoff Bundle.
- Claude regenerates the Bundle on each push while `handoff_status: ready`.
- A missing or stale Bundle is a blocking PR check.
- Sections 10 and 11 are required fields; CI fails if they are empty placeholders.

### 9.4 Scaled Approval Matrix

Production-lane changes require approvals scaled by `change_type` and `sensitivity` from `branch.yaml`. Each approval is recorded as a distinct review event on the PR.

| Change type | Product approval | Engineering approval | Notes |
|---|---|---|---|
| **Trivial** (typo, dead code, whitespace) | Not required | Optional / auto | Auto-merge eligible if CI green and PR author is a Dev |
| **Cosmetic** (copy, color, padding — user-visible) | Required if user-visible | One light review | Product approval can be a single PR comment |
| **Behavioral** (logic, surface, schema, flow) | Required | Required | Standard two-stage |
| **Structural** (rearchitecture, dependency overhaul) | Required | Required + ADR | ADR mandatory regardless of Spine class |
| **Sensitive** (§9.7) | Required | Two engineering approvals, one from domain owner | ADR mandatory |

**Approval questions:**

- *Product approval:* Is this the right user outcome?
- *Engineering approval:* Is this safe and maintainable?

**Invalidation rule:** **Product approval is invalidated if visible behavior changes after sign-off** (e.g., the PR is pushed with new UX-affecting commits). The acceptance checks in §9.3 #11 are the reference for "visible behavior." This prevents the failure mode where technically clean refactoring lands but no longer matches the PO's intent.

### 9.5 Branch Lifecycle

**Branch expiry.**

- Prototype branches expire after **14 days idle** unless renewed by the PO.
- "Expired" means: the branch is moved to an `archive/` namespace. **Git history is preserved** for audit; nothing is hard-deleted.
- A weekly digest lists branches approaching expiry; the PO can renew with one click. Each renewal increments `renewals` in `branch.yaml`.
- Production branches do not auto-expire; they merge or are explicitly closed.

**Renewal cap (shadow-product guard).** A prototype branch that has been renewed **3 times** or has been alive for **60 days** must either:

- enter handoff (`handoff_status: ready`), or
- be explicitly reclassified as an **experiment track** with separate governance (extended lifetime, named sponsor, periodic review), or
- be archived.

The cap prevents the prototype lane from silently growing production-shaped systems that never face production discipline. Claude warns at renewal 2 and refuses further renewals at renewal 3 without explicit reclassification.

### 9.6 Spine Drift Control

The Product Spine must not drift from the code on `main`. Drift is treated like test drift — a **CI failure**, not an etiquette violation.

Production-lane CI fails if a PR meaningfully changes behavior but updates none of:

```
/product-spine/
/adr/                       # architecture decision records
/docs/changes/
/tests/specs/
```

"Meaningful change" is determined by the **Spine writer**, which classifies diffs as:

| Class | Examples | Spine update required? |
|---|---|---|
| **Trivial** | typo, whitespace, dead code removal | No |
| **Cosmetic** | copy tweak, color, padding | Light Spine note |
| **Behavioral** | logic, surface, schema, flow | Full Spine section update |
| **Structural** | rearchitecture, schema migration | Full Spine + ADR |

**Classify-upward default.** When the Spine writer is uncertain between two classes, it must classify **one step stricter**. Downward reclassification requires explicit reviewer signoff via `spine: <class>` in the PR description, recorded as a review event.

**Heuristic backstop (MVP).** Before relying on AI classification, the CI applies path-based heuristics that override classification downward but never upward:

| Signal | Floor classification |
|---|---|
| Only `/docs/`, `/*.md` changed | Trivial / Cosmetic |
| Only UI text or style files changed | Cosmetic |
| API route file changed | Behavioral |
| Schema / migration file changed | Structural |
| Auth / payment / permission path changed | Sensitive |
| New dependency in `package.json` / `pyproject.toml` / equivalent | Behavioral minimum |
| Infra / IAM / env config changed | Sensitive minimum |

**Accuracy audit.** Drift detection catches the *absence* of a Spine update; it does not catch a *lazy* one ("tweaked copy" when the API contract changed). Claude must, in the same PR, audit the Spine update against the diff and flag mismatches as a non-blocking PR comment. Reviewers may convert the comment to a block.

**Revert symmetry.** A revert PR must touch the same Spine sections the original PR touched. CI enforces this by matching paths. A revert that leaves the Spine claiming behavior that no longer exists is treated as drift.

**Concurrent-edit soft-lock.** When Claude begins a Spine edit, it writes a brief lock notice to the relevant Spine file's frontmatter (`spine_edit_in_progress_by`, `spine_edit_started_at`). A subsequent Claude session that detects an active edit younger than 30 minutes must warn the user and request confirmation before overwriting. This is a behavioral rule for the Spine writer, not a hard lock — humans can always override.

**Periodic pruning.** The Spine describes the system *as it is*, not the history of every change. A quarterly review archives obsolete sections to `/product-spine/archive/<year>-Q<n>/`. Without pruning, the Spine accumulates archaeology, trust erodes, and drift checks fire against a document nobody reads. Pruning itself goes through a PR with two engineering approvals — never silently.

### 9.7 Sensitive Change Policy

Some domains carry blast radius that exceeds the standard lane model. Branches touching them are marked `sensitivity: sensitive` in `branch.yaml`.

**Sensitive domains:** auth, payments, PII handling, permissions, billing, data model migrations, anything that changes the security perimeter.

**Extra rails:**

- Sensitive production changes require **two engineering approvals**, one from a domain owner listed in `CODEOWNERS` (§9.4).
- Sensitive changes always require an ADR, regardless of the Spine writer's classification.
- Claude **refuses** to generate code in sensitive domains without explicit `sensitivity: sensitive` declaration in `branch.yaml`.

> *The temptation to peek at production code is highest exactly where it matters most.*

### 9.8 Plugin Pack Governance

The plugin pack is not configuration — it is the AI operating system for the team. Treat its lifecycle accordingly. Governance now applies per-layer (§8.1):

| Layer / component | Owner | Change process |
|---|---|---|
| AI Instructions — house style, spec-driven dev, always-test | Engineering | PR |
| AI Instructions — Spine writer, Handoff packager | Product + engineering | PR + both approvals |
| Repo Contracts — `branch.yaml` schema, `handoff.md` template, Spine template | Product + engineering | PR + both approvals |
| CI Policies — lint, type, drift check, smoke gate | Engineering | PR |
| CI Policies — security scan, sensitive-path rules | Engineering + security | PR + required security approval |
| Review Rules — CODEOWNERS, branch protection | Engineering (security on sensitive paths) | PR + required owners |
| Prototype helper instructions | Product or engineering | Lightweight approval |

**Versioning:**

- Plugin packs are semver-versioned and published to a single internal registry.
- Every branch records `plugin_pack: <name>@<version>` in `branch.yaml`.
- Breaking changes (major version bump) require a migration note and a grace window.
- A branch may pin to an older pack version, but **cannot merge to `main` on a deprecated version**.

**Deprecation:**

- Packs are deprecated by marking them in the registry.
- New branches refuse to install deprecated versions.
- Existing branches receive a warning until they update.

### 9.9 Project-Type Detection

**Principle:** *Greenfield and brownfield scaffolding diverge; the rest of the workflow does not.*

When a prototype branch is created, Claude detects whether the repo is greenfield (fresh ground) or brownfield (existing project) and writes the result to `branch.yaml#project_type`. The detection result drives scaffolding decisions only — stack selection, project layout, test runner, linter. The rest of the workflow (Spine, Handoff Bundle, scaled approval, drift control) is identical for both.

**Detection rules, evaluated in order:**

1. Repo has a manifest file (`package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `mix.exs`, `Gemfile`) **and** a non-empty source tree → **brownfield**.
2. Repo has a `CLAUDE.md` declaring conventions → **brownfield** (regardless of size).
3. Repo is empty, has only README/LICENSE, or is freshly `git init`-ed → **greenfield**.
4. Ambiguous → Claude asks the PO once: *"Is this an existing project I should adapt to, or fresh ground?"* The PO's answer is recorded; not asked again on the same branch.

**Persistence.** Result is written once to `/.workflow/branch.yaml#project_type`. Not re-evaluated unless explicitly reset.

**Behavioral split (scaffolding only):**

| Step | Greenfield | Brownfield |
|---|---|---|
| Stack selection | Pick from TECH-STACK.md preferences | Read existing manifest; conform |
| Project layout | Scaffold standard structure for the chosen stack | Place new files where existing patterns put them |
| Test runner | Install + configure (vitest, pytest, etc.) + write its first smoke test | Hook into existing runner; never add a parallel one |
| Linter / formatter | Install house-style defaults | Read existing config; never replace |
| First commit | `chore: scaffold <stack>` before any feature commit | First commit is feature work |

**Lives in:** the `project-type-detector` agent (`plugins/prototype-lane/agents/project-type-detector.md`), called by the existing `intake-clarifier` agent before it routes to scaffolding.

**Enforcement:** Repo Contract layer — CI rejects a `branch.yaml` missing `project_type`. AI Instructions layer — the `prototype-lane` plugin's `/vibe` command refuses to scaffold without it.

### 9.10 Minimum Test Floor

**Principle:** *Every new endpoint, screen, or background job ships with at least one test exercising its primary path. Soft on prototype, hard on production.*

**The rule.** Each artefact that smells like an endpoint, page/screen, or background job must have at least one co-located or conventionally-located test file before the branch can be handed off (prototype) or merged (production).

**Detection.** After every edit, the `always-test` plugin scans for new files matching these heuristics:

- Route handler patterns: Express handlers, Next.js route segments, FastAPI / Flask routes, Rails routes
- Component files under `pages/`, `views/`, `app/`
- Files under `jobs/`, `workers/`, `tasks/`

For each detected artefact, the plugin checks for a sibling test file (`*.test.*`, `*.spec.*`, `tests/<name>`).

**Enforcement, lane-scaled:**

| Lane | Per-edit | Session end | Handoff / merge |
|---|---|---|---|
| **Prototype** | Soft warning to stderr | Stop-hook surfaces a reminder to write the missing test before closing the session | `/package-handoff` refuses if any newly detected endpoint/screen/job has no sibling test file |
| **Production** | Block (exit 2) | Stop-hook reminder | CI fails on coverage delta if an untested artefact lands |

**Greenfield wrinkle.** On a greenfield branch, the first test counts as covering "the test runner works." Subsequent endpoints/screens trigger the per-artefact rule normally.

**Lives in:** `plugins/always-test/hooks/check-test-coverage.sh` (per-edit detection), `plugins/always-test/hooks/remind-smoke-test.sh` (Stop-hook nudge), `plugins/prototype-lane/commands/package-handoff.md` (handoff refusal check).

**Enforcement:** CI Policy layer (production hard block, coverage delta) + AI Instructions (per-edit warnings).

---

## 10. Invariants (Non-Negotiable Rules)

These rules must always hold. AI agents must refuse to violate them. CI must enforce them. Where possible, infrastructure must make them impossible to violate.

1. **No direct pushes to `main`.** All production-touching changes go through a PR.
2. **Green CI required** before any production deploy: lint, type, test, security scan, Spine drift check.
3. **Approvals scaled by change type** on production-lane PRs (§9.4). Sensitive changes require two engineering approvals.
4. **The Product Spine updates with every behavioral change** — Spine drift fails CI (§9.6).
5. **The lane is a property of the branch**, declared in `/.workflow/branch.yaml`. Not the person, not the branch's origin.
6. **Every branch is git-tracked, metadata-tagged, and auditable.** No anonymous or untagged branches reach a shared environment.
7. **Claude refuses to package a handoff** if the Prototype Ready Checklist is incomplete (§9.2).
8. **Plugin packs are versioned and recorded per branch** (§9.8). Branches on deprecated packs cannot merge.
9. **Chat history is not canonical.** Only the repo (Spine, ADRs, branch metadata, Handoff Bundle) is durable memory. *Chats propose; the repo records.*
10. **Sensitive changes require explicit declaration** (§9.7). Claude refuses sensitive-domain code generation without it.
11. **Every rule in the plugin pack maps to at least one hard enforcement layer** (Repo Contract, CI Policy, or Review Rule). AI Instructions alone are never load-bearing for safety (§8.1).
12. **Revert PRs touch the same Spine sections as the original** (§9.6). A revert that leaves the Spine lying is treated as drift.

---

## 11. What We Gain

- POs ship to a live URL in minutes — no ticket, no waiting on engineering bandwidth.
- Engineers review **intent, not chaos** — the Handoff Bundle is the artefact, not the chat or the diff alone.
- Production stays production — lane discipline keeps prototype risk out of prod, enforced by CI and review-rule discipline, not goodwill.
- The plugin pack compounds — every rule the team writes makes every future Claude session better, and every future CI run stricter.
- The spec is the system. Spine, branch metadata, and the Handoff Bundle are the controls — not documentation about the controls.

---

## 12. Open Questions (Remaining Gaps)

Several earlier open questions are now resolved by §9. The remaining unknowns:

1. **Plugin authoring UX** — who in the team can practically write a rule, and what tooling do they need to test one across the four layers (§8.1)? Governance (§9.8) defines approval; ergonomics are unresolved.
2. **Cost & quota model** — free vibe-coding sounds great until the bill arrives. Per-PO budgets? Org-level quotas? §9.5 adds a renewal cap; org-level cost policy is undefined.
3. **Cross-product context** — when an org has multiple products, how does Claude know which Spine to read? Repo-per-product is the MVP answer; multi-product orgs need more.
4. **Onboarding curve for non-technical contributors** — the workflow is forgiving, but the first prompt is still a blank box. What scaffolds the PO's first session?
5. **Concurrent prototypes on overlapping surfaces** — §9.6 introduces a soft-lock at the Spine level; hard conflict resolution between two `handoff_status: ready` branches touching the same surface is still undefined.
6. **Spine pruning cadence** — §9.6 mandates quarterly pruning; the operational specifics (who decides what is obsolete, how to safely archive without breaking drift checks) need a real run to define.
7. **Re-introducing infrastructure-layer isolation** — when platform decisions land (preview hosting, secret stores, environment isolation), §9.11 will return as a Runtime Guarantees section. The structure to slot it back into is preserved in v0.2.1 of this spec.

---

## 13. MVP Operating Model

The MVP proves the core loop end-to-end before any advanced features:

```
PO prompt → Claude prototype branch → preview URL → Spine extraction → Dev verdict → production merge
```

| Capability | MVP approach |
|---|---|
| Repo | One GitHub repo, one product |
| AI workspace | Claude Team with one shared plugin pack |
| Branch lanes | Naming convention + `/.workflow/branch.yaml` |
| Data | Static fixtures or seeded fake DB — mechanism deferred to infra; per-product CLAUDE.md declares the chosen sandbox approach until then |
| Product Spine | Markdown files in `/product-spine/` (in-repo; no wiki) |
| Handoff | Claude-generated bundle at `/.workflow/handoff.md` |
| Governance | GitHub PR + `CODEOWNERS` + branch protection |
| Expiry | Manual archive of stale branches via weekly digest; automation deferred to infra |
| Scaled approval | §9.4 matrix, implemented via PR labels + CODEOWNERS |
| Spine drift | CI check: behavioral diff requires Spine touch + accuracy audit comment |
| Sensitive domains | CODEOWNERS group + manual `sensitivity` flag; isolated infrastructure deferred |
| Tech stack defaults | [`TECH-STACK.md`](../TECH-STACK.md) — preference list, updated by PR |

**Scope explicitly deferred until 10–20 changes have run through the flow:**

- Multi-agent orchestration
- Plugin marketplace / publishing UX
- Cross-product Spine federation
- Real-time collaboration on a single branch
- Visual editor / no-code surface
- Sophisticated cost quota system
- Hard concurrent-edit conflict resolution beyond the §9.6 soft-lock

**Team size for MVP:** one repo, one product, one plugin pack, two POs, two Devs — and a lot of preview URLs.

**Next deliverable after v0.3:** an executable repo. The five items to instantiate first are `branch.yaml` schema + validator, `handoff.md` template, a Spine change template, a Spine-drift GitHub Action, and a plugin pack v0.1 loaded into Claude. Run 10 real changes through it before adding anything else.

---

## 14. The Workflow in One Line

> **Let the PO vibe. Let Claude translate. Let the Dev industrialize.**

```
PO  →  describes  →  CLAUDE  →  structures  →  DEV  →  industrializes
                                        ↑
                  Plugin pack: AI Instructions + Repo Contracts +
                  CI Policies + Review Rules
```

---

## Appendix A — Glossary for AI Agents

| Term | Definition |
|---|---|
| **Prototype Lane** | The left side of the workflow: throwaway branches, synthetic data, ephemeral previews, no production access. |
| **Production Lane** | The right side: PR-gated, CI-enforced, real data, real review, governed deploys, scaled approvals. |
| **Handoff** | The transition between lanes (Stages 03–04) where the Handoff Bundle is produced and architectural decisions are made. |
| **Product Spine** | The structured, persistent spec living in the repo, with sections: Intent, UX, Surface, Architecture, Open questions. The canonical "what this change means." |
| **Handoff Bundle** | The standardized handoff artefact at `/.workflow/handoff.md` containing the Spine link, file summary, dependencies, plugin flags, do-not-reuse list, acceptance checks, and Claude's suggested decision. |
| **Branch Metadata** | The `/.workflow/branch.yaml` file declaring lane, base branch, change type, owner, project type, expiry, renewals, plugin pack version, handoff status, and sensitivity. |
| **Prototype Ready Checklist** | The gate between exploration and handoff (§9.2). |
| **Scaled Approval** | The approval matrix in §9.4: ceremony depends on `change_type` and `sensitivity`. |
| **Spine Drift** | Divergence between code and the Product Spine; treated as a CI failure on production-lane PRs. |
| **Sensitive Change** | A change in a high-blast-radius domain (auth, payments, PII, permissions, billing, data model). Requires extra rails (§9.7). |
| **Plugin Pack** | A versioned bundle of rules across four enforcement layers: AI Instructions, Repo Contracts, CI Policies, Review Rules (§8.1). Every branch records the pack version it was generated under. |
| **Four Enforcement Layers** | The substrates that carry plugin-pack rules. AI Instructions are soft; the other three (Repo Contracts, CI Policies, Review Rules) are hard. (§8.1) |
| **The Four Decisions** | The Dev's verdict at the architecture gate: Keep / Refactor / Redesign / Reject. |
| **Working memory vs durable memory** | Chat history is working memory (ephemeral, not canonical); the Spine is durable memory (canonical, in the repo). *Chats propose; the repo records.* |
| **Lane** | A property of the *branch* — not the person, not the branch's origin. Declared in `branch.yaml`. |
| **Renewal Cap** | The §9.5 limit on prototype-branch life: 3 renewals or 60 days, after which the branch must hand off, reclassify as an experiment track, or archive. |
| **Project Type** | A property of the repo, detected at prototype-branch creation and written to `branch.yaml#project_type`. `greenfield` (fresh ground) or `brownfield` (existing project). Affects scaffolding only. |
| **Minimum Test Floor** | Every new endpoint/screen/job ships with at least one test. Soft warning on prototype lane; CI block on production lane. See §9.10. |

---

## Appendix B — Agent Operating Notes

When an AI agent participates in this workflow, it must:

1. **Read `/.workflow/branch.yaml`** before generating or modifying code. Reject the task if the file is missing, malformed, or contains a deprecated plugin pack.
2. **Apply the plugin pack** at the version recorded in `branch.yaml`. Refuse to operate on an unsupported version.
3. **Maintain the Product Spine.** On every behavioral change, update the relevant Spine section in the repo. If a meaningful diff lands without a Spine touch, surface a warning. Audit your own Spine updates against the diff and flag mismatches (§9.6).
4. **Classify diffs upward when uncertain** (§9.6). When in doubt between two classes, pick the stricter one and let a human downgrade.
5. **Respect the concurrent-edit soft-lock** (§9.6). Before overwriting a Spine file with a recent `spine_edit_in_progress_by`, warn the user and request confirmation.
6. **Verify the Prototype Ready Checklist** before packaging a handoff. Refuse to package if incomplete.
7. **Produce the Handoff Bundle** at `/.workflow/handoff.md` using the template in §9.3 — including sections 10 (*What should not be reused*) and 11 (*Acceptance checks*), which are mandatory fields. Regenerate the Bundle on each push while `handoff_status: ready`.
8. **Pre-flight reviews** when handing off to a Dev: highlight novel patterns, flag plugin-pack violations, list new dependencies since `main`, call out prototype shortcuts not to be carried forward, suggest a decision (Keep / Refactor / Redesign / Reject) with reasoning.
9. **Scaffold a smoke test** for any new endpoint or screen, even in the prototype lane.
10. **Log open questions explicitly** in the Spine rather than guessing — defer to humans on undecided architectural questions.
11. **Refuse direct pushes to `main`.** Always open a PR for production-lane changes.
12. **Treat sensitive domains specially.** Refuse to generate code without explicit `sensitivity: sensitive` declaration in `branch.yaml` for any auth/payments/PII/permissions/billing/data-model change.
13. **Respect the renewal cap** (§9.5). At renewal 2, warn the PO that the next renewal will require reclassification. At renewal 3, refuse to renew without an explicit experiment-track declaration or handoff.
14. **Treat chat as ephemeral.** Do not assume context from past chats persists; rely on the Spine and the repo. If a user references something only present in chat history, ask them to confirm and write it into the Spine before acting on it. *Chats propose; only the repo records.*
15. **On revert PRs, touch the Spine the original PR touched** (§9.6). Leaving the Spine claiming behavior that no longer exists is drift.
16. **Respect the project type** (§9.9). Read `branch.yaml#project_type` before scaffolding. On greenfield: pick from TECH-STACK.md and install the chosen stack's test runner. On brownfield: read existing manifests and conform; never add a parallel test runner or replace the existing linter config.

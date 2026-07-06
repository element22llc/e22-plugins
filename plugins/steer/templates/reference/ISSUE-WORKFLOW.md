# Issue lifecycle — GitHub Issues as the work, decision, and collaboration layer

How a product idea travels from a PO's rough capture to validated, shipped work
**without losing open questions, overwriting human content, or letting the spec
and the tracker silently disagree**. This is the normative owner of the
lifecycle, its state model, label taxonomy, and authority rules. The issue
*format* lives in [`ISSUE-SCHEMA.md`](ISSUE-SCHEMA.md); the open-question format
lives in [`SPEC-FRAMEWORK.md`](SPEC-FRAMEWORK.md).

Two invariants underpin everything:

- **`/spec` is durable product truth; GitHub Issues is the work/decision layer.**
  An issue is the *workflow* for reaching a decision; the spec (or an ADR) is the
  durable *record* of it. Neither silently overwrites the other.
- **`/steer:issues` orchestrates backlog management; `/steer:work` owns execution.**
  Neither owns domain reasoning — they delegate to `/steer:spec`, `/steer:audit`,
  `/steer:audit spec`, `/steer:questions`. All **tracker-metadata** read/write flows
  through `/steer:tracker-sync` (MCP-first → `gh` → manual floor); git and
  pull-request **delivery** follows the repo's execution/autonomy rules — it is
  not a gateway operation (otherwise `git push` would violate the invariant).

## Operating model (local-first, issue-first)

1. **Local interactive Claude Code is the primary worker.** Unattended GitHub
   Actions execution is out of scope and would require a separate explicit signal.
2. **Every implementation-affecting mutation has a GitHub issue first** — in a
   GitHub-adopted repo (`/spec/tracker.md` → `system: github`), reuse the issue
   the user names or create one before the first code/config/infra/behavior
   change. "Implementation-affecting" is the scope: editing the `/spec` spine,
   documentation, generated output, and lockfiles is exempt. Two non-blocking
   safety nets reinforce this — a PreToolUse nudge at the first editor write, and
   a Stop-time working-tree reconciliation that catches Bash-mediated mutations
   the editor nudge never sees. Both report; neither enforces.
3. **Explicit capture/implementation requests create issues without confirmation**
   ("create an issue for…", "add to the backlog", "fix this bug", "implement
   #123"). Ambiguous conversation that did not request capture does **not**
   auto-create; a large inferred batch of unrelated issues takes one confirmation;
   security-sensitive public disclosure takes human review. **Host gating:** the
   scaffold pre-authorizes the tracker-metadata write verbs (`gh issue
   create`/`edit`/`comment` under `.claude/settings.json` → `allow`), but some
   Claude Code permission modes still classify an unprompted `gh issue create` as
   an external write and block it regardless. A blocked create is a host-permission
   gate, **not** a missing issue — don't loop retrying it; ask the user to confirm
   the create, or suggest they run `!gh issue create …` under their own identity,
   then continue.
4. **A CLI implement request authorizes a bounded action set** — read/search,
   create-or-reuse issue, claim, branch, local edits, run tests. Commit, push,
   PR open/update follow existing commit/PR-autonomy rules; **merge and deploy
   are never implied.**
5. **Base lifecycle state is the `steer:state` marker** (see State model) — the
   single source of truth for where an issue sits in the lifecycle.
6. **Taxonomy is three orthogonal axes** — GitHub Issue **Type** × `steer:kind`
   (work shape) × `source:*` (origin). The `steer:source` marker is canonical; the
   label is derived. See the table in [`ISSUE-SCHEMA.md`](ISSUE-SCHEMA.md).
7. **Original human Issue-Form content is immutable** — agents append a managed
   block, never rewrite form responses (see `ISSUE-SCHEMA.md`).

### Authorization & confirmation

The **single authority** for *when an agent acts without asking* vs *when it
confirms first*. Skills reference this block rather than restating it; the
always-on issue-first rule and the issue-mutation hooks carry only a terse,
point-of-use reminder of the host-gate fallback (principle 3) — never a second
normative copy.

- **Explicit implement / capture request → no extra confirmation.** "fix #123",
  "implement this", "create an issue for…" authorize find-or-create plus the
  bounded action set (principle 4) with no second ask. *No extra confirmation*
  is steer's stance; the **host** can still gate the underlying `gh issue create`
  — see the host-gate fallback in principle 3. Never read a host block as "no
  issue was wanted".
- **Bulk publish of audit / drift / adoption findings → one batch confirmation.**
  Filing many issues from one report (`publish-audit` / `publish-drift` /
  `publish-adoption`) takes a single confirmation for the whole batch, then
  proceeds.
- **Unsolicited idea / capture-only language → confirm before any external
  publish.** "we should eventually…" is captured deliberately, never inferred
  into issues; security-sensitive public disclosure takes human review.
- **Managed-block update inside an already-authorized workflow → no repeated
  confirmation.** Rewriting the `steer:managed` block (progress, state) needs no
  further ask; human content stays immutable (principle 7).
- **State transitions** obey the authority table below; wherever it does not
  permit *perform*, the agent **proposes and waits** for the named human, and
  never resolves behavioural drift or a product/policy decision autonomously.

## The lifecycle

1. **Capture** — a PO opens an issue from a form (feature / bug / product
   question / improvement). Incomplete ideas are fine. No `intent.md`, no
   feature-id, no architecture. Enters `inbox`. (`/steer:issues capture` can also
   open one from a conversation, prototype, or screenshot.)
2. **Brainstorm** — `/steer:issues brainstorm #N` reads the issue and related
   specs, **searches the existing issue corpus (open + closed) for overlapping,
   dependent, or conflicting issues** — e.g. a hosting decision that a pending
   auth-migration issue would invalidate — records those connections under the
   issues' `Related issues` headings (`/steer:tracker-sync link-related`), asks
   focused questions, and maintains **one** editable "AI synthesis" comment
   (proposed outcome + boundaries + the related-issue cluster). Conflicts and
   supersessions are **surfaced for a human**, never auto-resolved. The issue body
   stays human-owned.
3. **Product validation** — the PO approves intent, answers questions, rejects
   assumptions, attaches design sources, in GitHub. Moves to `ready-for-spec`.
4. **Materialize** — `/steer:issues materialize #N` writes/updates
   `spec/features/<id>/intent.md` with `Status: draft`, links the issue, and
   requests PO approval. **Materialize never approves** — only an explicit
   `/steer:spec approve` flips `Status: approved`.
5. **Technical shaping** — `/steer:spec` authors the feature's
   `contract.md` where behavior demands it; large features become a
   parent feature issue with implementation sub-issues
   (`/steer:issues decompose #N`).
6. **Implementation & product validation** — PRs use closing refs
   (`Closes #131`, `Refs #123`, `Spec: …`). The parent closes only after
   **product** validation, not merely because the last code PR merged.

## State model (base = `steer:state` marker)

The **base source of truth is the `steer:state` issue-body marker**. The
closed enum (no standalone `ready`):

`inbox · exploring · ready-for-spec · ready-for-dev · in-progress · validate · blocked · done · cancelled`

`done` and `cancelled` are the two terminal states, and **which one a closed
issue lands in is decided by its closure reason, not by the mere fact of
closure** (see Completion rules).

Readiness and transitions differ **by kind** — the feature flow is the long
path; smaller work skips the spec gates:

- **Feature:** `inbox → exploring → ready-for-spec → ready-for-dev → in-progress → validate → done`
- **Bug / task:** `inbox → ready-for-dev → in-progress → validate → done` — allowed
  to start directly when expected behavior is clear, evidence/repro exists, the
  user requested implementation, and no unresolved product decision exists.
- **Deterministic finding** (audit/adoption): `inbox → ready-for-dev → in-progress → validate → done`
  — auto-advance to `ready-for-dev` only when remediation is deterministic and
  does not change product intent.
- **Question / drift:** `inbox → exploring → ready-for-spec → [human decision] → ready-for-dev → …`
  — cannot become implementation-ready until a human resolves the intended behavior.
- **Epic:** `inbox → exploring → in-progress → validate → done` — a parent
  tracking issue, **never spec'd or dev'd directly**, so it **skips
  `ready-for-spec`/`ready-for-dev`**. `exploring` is identifying and linking child
  features; `in-progress` once any child has left `inbox`/`exploring`; `validate`
  once all children are `validate`/`done`. Completion is **derived from child
  rollup** (see Completion rules) and is PO-owned product acceptance, like a
  feature.

| Transition | Preconditions | Authority | AI may |
|---|---|---|---|
| inbox → exploring | Triaged, not a duplicate (feature path) | PO | propose + perform |
| exploring → ready-for-spec | Product questions sufficiently answered | PO | propose only |
| ready-for-spec → ready-for-dev | Intent approved, **zero open blocking questions gated at `implementation` or earlier**, contract ready | PO + dev | propose only |
| inbox → ready-for-dev | Bug/task/deterministic finding meets its readiness rule above | dev | propose + perform |
| ready-for-dev → in-progress | Work claimed and started | dev | propose + perform |
| in-progress → validate | Acceptance criteria implemented; **PR opened** | dev | propose + perform |
| validate → done | Acceptance criteria **validated** AND closure reason = `completed` (PR merged & accepted) | PO/dev per kind | propose only (features: PO) |
| any state → cancelled | Closed for a non-completion reason (`rejected` / `duplicate` / `obsolete` / `not-planned` / `superseded`) | PO/dev per kind | propose + perform |
| any non-terminal → blocked | Work cannot proceed | dev | propose + perform |
| blocked → previous | Blocker resolved | dev | propose + perform (returns to the prior meaningful state) |
| drift open → resolved | Spec or implementation intentionally reconciled | human (PO/dev) | propose only — **never auto-resolve** |

Completion rules: **opening a PR moves the issue to `validate`, never `done`.**
**Closure reason — not the mere fact of closure — decides the terminal state:**

- Closed as **`completed`** (the work was delivered: PR merged & the acceptance
  criteria accepted) → `done`.
- Closed as **`rejected` / `duplicate` / `obsolete` / `not-planned` /
  `superseded`** → **`cancelled`**, never `done`. Record a replacement pointer
  where one applies (a `duplicate`/`superseded` issue points at its replacement).
  `cancelled` work was **not** delivered, so it must never count toward
  done/throughput or read as a satisfied acceptance.
- An **epic** has no PR of its own; its terminal state is **derived from child
  rollup**. It is *eligible* for `done` only when **every** linked child feature is
  terminal with **at least one `done`** — the agent then *proposes* `done` and the
  **PO confirms** the epic outcome (it never auto-closes from rollup alone). An epic
  whose children are **all `cancelled`** → `cancelled`, never `done`.

A PR closed without merge returns the issue to `in-progress` or `blocked` (the
issue itself is not closed). A reopened issue moves `done|cancelled →
inbox|exploring|ready-for-dev` after reassessment. `/steer:work status|resume|finish`
reconciles stale markers on the next interaction — and **inspects the closure
reason before transitioning a closed issue**, keeping merge state as independent
evidence. An AI may *perform* a transition only where the table says so;
everywhere else it proposes and waits for the named human.

### Spec `Status:` ↔ issue `steer:state` crosswalk

Progress is tracked by **two state machines**: the issue `steer:state` marker
(above) and a feature spec's `> Status:` line (`feature_status` enum —
`draft · approved · implemented · validated · live`). The issue state is the
**base source of truth**; a feature's spec `Status:` is **derived** from it via
this crosswalk, so `reconcile` (`/steer:work`, `/steer:audit spec`,
`/steer:tracker-sync`) is deterministic rather than ad-hoc. This table is the
single authority for that mapping.

It applies to the **feature path only** — `bug`, `task`, `finding`, and
`spec-question`/`spec-drift` issues carry no `intent.md`, hence no spec
`Status:`; an `epic` aggregates child features and has no `Status:` of its own.

| issue `steer:state` | feature `Status:` | how they line up |
|---|---|---|
| `inbox` | _(none yet)_ | captured; not materialized into an `intent.md` |
| `exploring` | _(none)_ → `draft` | brainstorming; `intent.md` may not exist yet |
| `ready-for-spec` | `draft` | `intent.md` authored, awaiting PO approval |
| `ready-for-dev` | `approved` | intent PO-approved; contract authored/ready |
| `in-progress` | `approved` | building; behavior not yet merged |
| `validate` | `implemented` | PR merged; awaiting **product** validation |
| `done` | `validated` → `live` | `validated` on accepted close; `live` once released to users |
| `blocked` | _(retains prior)_ | orthogonal hold; spec `Status:` is unchanged |
| `cancelled` | _(none)_ | not delivered; no satisfied `Status:` |

The two "split" rows reflect a spec transition the issue state can't see on its
own: `done` first reaches `validated` at accepted close and only becomes `live`
when the feature is actually released; `exploring` holds no `Status:` until an
`intent.md` is materialized as `draft`. Resolve those with the spec gate
(`/steer:spec approve`) and the release event — never silently. When a feature's
spec `Status:` and this crosswalk disagree, that is drift: surface it for human
review, do not auto-rewrite (see Audit & drift).

## Labels (small, deliberate set)

- **source:** mirrors the canonical `steer:source` marker (label is *derived*) —
  `source:human` · `source:adoption` · `source:audit` · `source:security-review`
  · `source:code-review` · `source:ci` · `source:dependency` ·
  `source:implementation` · `source:spec`.
- **needs:** `needs:triage` · `needs:product-decision` ·
  `needs:technical-decision` · `needs:spec` · `needs:validation`
- **risk:** `risk:high` · `risk:security` · `risk:data`

Do **not** encode status, release, or **kind** as labels — state is the
`steer:state` marker and kind is the `steer:kind` marker + GitHub Issue Type.
**Priority and effort are native issue fields, never labels** (see below and
`ISSUE-SCHEMA.md`).

**Issue Types — capability-degrading.** The standard org Types are
`Feature · Bug · Task`, but Issue Types are an **org-level** feature whose
defaults can be renamed, disabled, or deleted, and Issue Forms remain a GitHub
public preview. So:

- **Type available** → set the configured Type (per the Type×kind×source table in
  `ISSUE-SCHEMA.md`) **and** keep `steer:kind` as the standards contract.
- **Type unavailable/unknown** → continue on `steer:kind` alone, emit a
  non-blocking capability warning, and **do not** reintroduce duplicate
  `bug`/`feature` labels to compensate.

**`Epic` is org-defined and may be absent even when `Feature`/`Bug`/`Task`
exist** — it is not one of the standard three. So detect the **specific configured
Type name** before setting it, not just whether Issue Types are enabled:
**`Epic` present** → set it on `kind=epic` issues; **`Epic` absent** → keep
`steer:kind=epic`, **leave the Type unset** (never substitute `Feature` — an epic
is not a feature), warn, and do **not** invent an `epic` label. The epic's meaning
still reaches a board through its native sub-issue links, which are Type-independent.

**Issue fields — capability-degrading.** Native issue fields (Priority, Effort,
Start/Target date) are an **org-level** GitHub feature, currently public preview,
reachable only via GraphQL (not `gh` REST, not the manual floor). So:

- **Fields available** → read them for ranking; escalate-only auto-set Priority;
  write dates under human confirmation (`/steer:roadmap`). Their option sets are
  org-defined — read them from the field definition, never fabricate option names.
- **Fields unavailable/unknown** → **omit** them, emit a non-blocking capability
  warning, and rank Priority as unset. **Never** reintroduce `priority:*`/`effort:*`
  labels or body markers to compensate — the field is the only home (the value vs.
  managed-block ledger provenance is in `ISSUE-SCHEMA.md`).

## CI failures — when to file

Not every red build is an issue. To avoid both lost signal and duplicate noise:

- **Transient failure** (flake on retry, infra blip) → no issue.
- **Reproducible failure on the default branch** → create/reconcile a `bug` with
  `source:ci` (stable `finding-key` so repeat failures reconcile, not duplicate).
- **Recurring flaky test** → one issue keyed by a stable `finding-key`; reconcile
  each recurrence rather than opening a new one.
- **PR-specific failure** → comment on the PR; only file an issue if it outlives
  that PR (lands on the default branch).

## Spec questions — keep vs promote

A question stays in the spec's `## Open questions` (structured `Q-NNN`, see
[`SPEC-FRAMEWORK.md`](SPEC-FRAMEWORK.md)) when it is local to one feature,
answerable during active specification, not separately scheduled, and not blocked
on an external party. **Promote it to a `source:spec-question` issue** when it
needs a named owner, blocks multiple features, requires stakeholder consultation
or research, must be prioritized independently, or could outlive the current
session. On resolution: update the canonical spec, record the decision on the
issue, close it, and record an ADR **only** when the decision is architectural or
hard to reverse. The issue is the decision *workflow*; the spec/ADR is the
durable *record*.

**Staleness is a promotion trigger.** A `blocking` question still `open` after
`STEER_QUESTION_STALE_DAYS` (14, measured from its `created:` date — the
SessionStart open-questions hook surfaces these every session) has, by
definition, outlived the session and needs a named owner — promote it.

**Assignee resolution on promotion.** When promoting, resolve the question's
`owner:` role to a GitHub login via the **`owners:` map in `/spec/tracker.md`**
and assign the `spec-question` issue to it (through `/steer:tracker-sync assign`,
add-don't-replace):

| `owner:` | Assigned to |
|---|---|
| `product` / `development` / `design` / `security` | the mapped login for that role |
| `shared` | both the `product` **and** `development` logins |
| role missing/blank in the map | leave **unassigned**, apply `needs:triage` |

Never fabricate a login; an empty map row means "no auto-assignment", not an
error. The bidirectional link (spec `tracker:` ↔ issue `question-id` marker) and
find-by-`question-id` dedup are unchanged — re-promotion never double-creates.

## Audit & drift (reconciling, not additive)

- **Audit** (`/steer:audit` → `/steer:issues publish-audit`) uses a two-level model:
  one immutable **audit-run** record per run (`audit-id`) plus selected
  **finding** children keyed by a stable `finding-key` (the conceptual defect),
  with an `evidence` fingerprint tracking the *observed* lines separately. Re-runs
  reconcile: same key → update; gone → comment + close (auto-close only for
  `resolution_mode: deterministic`; judgment calls need a human yes); new →
  create; false positive → stays closed. Reconciling, never additive. See
  `ISSUE-SCHEMA.md` for the keys and `/steer:audit` for the full lifecycle.
- **Drift** (`/steer:audit spec` → `/steer:issues publish-drift`) files decision-checklist
  issues: `Spec says` / `Implementation does` / `Evidence` / `Human decision
  required`. The agent may propose a direction but **never resolves behavioural
  drift autonomously** — a PO or dev decides by ownership.

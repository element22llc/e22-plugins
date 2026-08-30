---
name: explain
description: "Render one feature spec as a stakeholder-readable, shareable Claude Artifact (Markdown fallback) — status pipeline, acceptance meter, user journey, scope and open-question boards. A read-only derived view: every visual encodes a real spec value; never writes into /spec, /apps, or /packages."
when_to_use: >-
  Use when someone wants a plain-language, at-a-glance page of one feature to
  look at or hand to a non-technical stakeholder — "show me feature X", "make a
  shareable summary for the PO".
argument-hint: "[feature-id]"
disallowed-tools: Bash, Edit, NotebookEdit, EnterWorktree
# Runs in a forked subagent: this skill is a pure renderer — it reads the
# feature's /spec files and publishes a page, and needs nothing from the
# conversation that invoked it (the feature-id is the whole input). Forking
# keeps a full spec read out of the main session's context, which is the
# point: the caller wanted the page, not the twelve files behind it.
#
# background: false — the fork still isolates the read, but the turn waits for
# it. A BACKGROUNDED fork runs with the narrower background-subagent tool set,
# which re-admits Bash/Edit/NotebookEdit/EnterWorktree — exactly the four this
# skill declares disallowed — so backgrounding would quietly widen what it can
# reach. It does NOT put the publish heads-up ahead of the publish: the heads-up
# is written inside the fork, and only a fork's final result reaches the main
# session, so the Artifact permission prompt is the gate that holds — see
# /steer:reference artifacts. `background` needs Claude Code v2.1.218+; before
# that release a forked skill always blocked the invoking turn, which is what
# background: false asks for, so an older CLI lands on the intended side. Treat
# the read-only boundary as one this skill keeps, not one the runtime guarantees:
# upstream scopes disallowed-tools to the invoking turn and clears it at your
# next message.
context: fork
background: false
---

# Explain a feature — a shareable, plain-language view

**Scope boundary:** this skill only *presents* what the spec already says.
Choosing the next action is `/steer:next`; authoring or approving the spec is
`/steer:spec`; progress across the whole spine over time is `/steer:status`.
Never auto-generate per feature.

Turn one feature's approved intent into a **high-level page a stakeholder can
read at a glance** — not a five-page wall of text but a **visual, interactive
summary**: a status pipeline, an acceptance meter, a clickable user-journey, and
scope/open-question boards, so the reader gets the gist in seconds and drills in
only where they want to. Published as a **Claude Code Artifact** (a private,
hosted page on claude.ai you can then share with a teammate), or rendered as
**Markdown** where Artifacts are not available.

This is the **PO-facing presentation layer** the rest of the roster lacks: every
other skill is dev- or tracker-facing. `explain` renders the human-readable side
of a feature — what it does, why, the experience, what's in and out of scope, its
status, and its open questions — in plain language.

## Render, don't own — this is a derived view

Mirror `/steer:roadmap`'s discipline: the **`/spec` intent + the tracker item are
canonical**. The artifact is a **snapshot**, never a source of truth. It can go
stale the moment the spec changes — regenerate to refresh.

- **Never fabricate.** Render only what the spec actually contains — status,
  dates, acceptance criteria, scope, open questions. A missing section is shown as
  *"not specified in the spec"*, never invented or inferred.
- **On demand only.** One feature, when asked. Do **not** auto-generate a page per
  feature or on a schedule — that would create a second, drifting copy of every
  spec and couple the spine to claude.ai infra.
- **Read-only over canonical sources.** `Bash`, `Edit`, `NotebookEdit`, and
  `EnterWorktree` are **disallowed in frontmatter**, so this skill does not commit,
  branch, run shell, or edit an existing file in place. Treat that as a boundary
  this skill keeps, not one the runtime guarantees: upstream documents when
  `disallowed-tools` applies to the invoking turn, but is silent on whether it
  reaches a forked subagent, and `background: false` is what keeps the fork off
  the wider background tool set. The prose is the binding constraint. It never
  touches the tracker. The **one** thing it writes is the artifact's HTML source
  (via `Write`, which is *not* disallowed) — so that write is bound not by the
  frontmatter but by a hard prose invariant: **only to a system temp directory,
  never a path under the repo working tree** (`/spec`, `/apps`, `/packages`, or any
  tracked file). Discover features with `Glob`/`Read`, never a shell listing.
- **Do not persist the artifact URL** anywhere in the repo. The page is a
  disposable view; keeping its URL in the spec would recreate the drift and
  claude.ai coupling this skill is designed to avoid.

## Flow

### 1. Locate the spine and the feature

- No `/spec` spine in the repo → redirect to `/steer:init` (greenfield) or
  `/steer:adopt` (existing code) and **stop**; there is nothing to render yet.
- **In a polyrepo member** (`spec/PRODUCT.md` present), `spec/features/**` is
  absent **by design** — it lives once in the workspace. Resolve the workspace
  first: read `workspace.path` from `spec/PRODUCT.md`, resolve it against this
  repo's **primary checkout** (not a linked worktree), and read the feature from
  **there** — saying which repo you rendered — only if `spec/workspace.yml` is
  present at that path. Test for that manifest, not for a directory: `..`, the
  recommended value, resolves inside a worktree to a real but empty
  `.claude/worktrees`, and accepting it renders every feature as unspecified.
  `Bash` is disallowed here, so the GitHub-gateway route is not available to this
  skill: if `workspace.path` is unset, or no manifest is there, say the product
  spine is unreachable and **stop**. Never render an absent local
  `intent.md` as *"not specified in the spec"* — absent local intent is not "no
  intent" (`/steer:reference polyrepo`).
- No feature id given, or it's ambiguous → list the features under
  `spec/features/*/` (the workspace's, in a member) with their `Status:` and stop
  there, naming the ids so the caller can re-run with one. **Don't guess, and
  don't try to ask:** this skill runs forked, and `AskUserQuestion` is removed
  from every subagent, so a question here would return nothing and render no page.

### 2. Read the sources (the only inputs)

Read, and render strictly from:

- `spec/features/<id>/intent.md` — the PO-language spine (what it does, why, user
  experience, key concepts, scope, open questions, `Status:`, `Owner:`, tracker ref).
- `spec/features/<id>/contract.md` **if it exists** — dev detail; used only to
  enrich, and mostly **summarized or omitted** for a stakeholder audience (see below).
- The tracker ref and open-question `status`/`impact` already recorded in the intent.

All three paths are relative to the spine you resolved in step 1 — the local
repo, or the workspace in a polyrepo member.

Do not read code, `.env`, or anything outside the feature's spec to fill the page —
that both risks leaking detail into a shareable surface and invites fabrication.

### 3. Render for the audience

Default audience is the **stakeholder / PO** (rule `05` — speak plainly, no
git/CI/ADR/stack jargon). Build the page around the intent's own sections:

- **What this feature does** and **why** — lead with these, verbatim-in-spirit.
- **The experience** — the step-by-step user experience.
- **In scope / out of scope** — as two clear lists.
- **Status** — the intent's `Status:` and PO-acceptance checkboxes, plainly stated
  (e.g. "Approved, not yet built"), plus the tracker ref if present.
- **Open questions** — only those still unresolved (`open` / `investigating` /
  `deferred` — the set that can still block a gate, per `ENUMS.md`), in plain
  terms, flagging which **block** progress.
- **Contract detail** (data model, API surface) is **dev jargon** — summarize it in
  a sentence or omit it. Do not paste tables of fields/types onto a stakeholder page.

Style the page from the repo's `DESIGN.md` tokens when it declares them (repo
root, or `apps/<app>/DESIGN.md` — see `/steer:reference design-sources`), else the
`artifact-design`/`dataviz` house default. Never invent a brand.

### 3a. Show, don't tell — visual encodings (derived, never decorative)

A stakeholder should grasp the feature from the visuals before reading a
paragraph. Encode each spec section as the shape that reads fastest — but **every
visual must encode a real value the spec actually contains**. No fabricated
numbers, no placeholder charts, no invented relationships or dates; a section the
spec leaves empty is shown as *"not specified in the spec"*, never a mocked-up
chart. Map the intent's own sections to these visuals:

- **Status → a lifecycle pipeline.** Render the fixed spine
  `draft → approved → live` as a horizontal progress tracker with the intent's
  `Status:` marked as the current stage and later stages dimmed. **Never advance
  the marker past the recorded `Status:`** — the pipeline reflects the spec, it
  does not predict. (Enum lives in `ENUMS.md`.) The three stages are the spec's
  own product state; **delivery progress is not on this spine** and must not be
  inferred onto it — an `approved` feature may be half-built or merged, and only
  its tracker issue knows which. If the reader needs that, point them at the issue
  (`> Tracker:`) rather than drawing a stage the spec cannot support.
- **PO acceptance → a completion meter.** Show the four acceptance checkboxes as a
  small progress meter / ring with the ratio (e.g. "2 of 4"), each item's ticked
  state taken **verbatim** from the intent — never tick a box the spec leaves
  unchecked.
- **User experience → a clickable journey.** Turn the numbered steps into a
  stepper the reader advances one step at a time, instead of a prose list — the
  single biggest "don't make me read five pages" win. Steps are the intent's own,
  in order.
- **Scope → an in/out board.** In-scope and out-of-scope as two visually distinct
  columns (✓ / ✗) so the boundary reads instantly.
- **Key concepts & data → a light relationship diagram.** Each concept a node;
  draw an edge **only where the intent explicitly states a "belongs to" / relates-to
  link** — never infer one. Omit the diagram entirely if the intent lists no
  relationships. Keep it plain-language (no field/type schema — that is contract
  jargon).
- **Open questions → a status board.** Cards grouped/counted by `status`
  (`open` / `investigating` / `deferred` — the unresolved set), with **blocking**
  ones flagged, so "what's unresolved and what stops progress" is a glance, not
  a read.

### 3b. Interactivity — lead with the gist, disclose on demand

- **One-screen summary first.** Open with what/why + the status pipeline + the
  acceptance meter above the fold; put everything else behind collapsible sections
  with a sticky jump-nav. Nobody should scroll five pages to learn the feature's
  state.
- **Keep it accessible and shareable.** Every interactive control is
  keyboard-reachable and labelled, and the page must still make complete sense with
  every section expanded — so a printed copy or a shared screenshot loses nothing.

### 4. Publish (or fall back)

Render **by the shared Artifact discipline** — rule `88-artifacts`, full mechanics
in `/steer:reference artifacts` — and do not restate it here. Two things are
**specific to this skill**:

- **The temp filename is `<tempdir>/steer-explain-<feature-id>.html`** — stable per
  feature, so a re-run redeploys in place rather than making a second page (not a
  guarantee from a fork — see "Updating a previously shared page" below).
  Write only there (a system temp dir), never under the repo tree.
- **The Markdown fallback keeps this skill's at-a-glance shape** — status as an
  inline pipeline (`draft → **approved** → live`),
  acceptance as a checklist with its "N of 4" count, the journey as a numbered list,
  scope as two ✓ / ✗ lists. Print it inline; never write it to a file under the
  repo (that would be the drifting second copy of the spec this skill avoids).

## Updating a previously shared page

The publish path is a stable per-feature filename, which is what lets a re-run
redeploy in place rather than creating a second page. Do not promise that to the
user as a guarantee: this skill runs forked, and whether a fork's publish is
recognised as a redeploy of an earlier one is not something steer can verify. If
the caller needs a specific page updated, take its URL from them. Updating a page
from a **different** session needs that URL anyway — steer does not store it. The full rule: `/steer:reference artifacts`
→ "Updating a previously shared page".

## What this skill is *not*

- **Not** an author or approver of specs — that's `/steer:spec`. It writes nothing
  back into the spine.
- **Not** an auto-publisher — no per-feature or scheduled generation.
- **Not** a status source — the tracker and `/spec` remain canonical; this only
  reflects them at a moment in time.

## Recommended next action

After rendering, surface the single most useful follow-up, and stop:

- Spec `Status:` still `draft`/unapproved → offer `/steer:spec approve <id>`.
- Open blocking questions remain → offer `/steer:questions` (or `/steer:spec`).
- Nothing outstanding → `No action is required.`

## Reference

- Audience & plain-language posture: rule `05`.
- Derived-view discipline this mirrors: `/steer:roadmap`.
- Spec sources: `spec/features/<id>/intent.md`, `contract.md`.
- Status enum for the lifecycle pipeline: `ENUMS.md`.
- Artifact rendering, the derived-view discipline, and the Markdown fallback:
  `/steer:reference artifacts` (rule `88-artifacts`) — the shared standard this
  skill renders by. Visual system: the `artifact-design` skill (page shell) and,
  where offered, `dataviz` (chart colour/encoding), both loaded at publish time.

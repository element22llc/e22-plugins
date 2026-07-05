---
name: explain
description: >-
  Render a high-level, stakeholder-readable view of one feature spec as a
  shareable Claude Code Artifact — a private, hosted page on claude.ai, built
  around at-a-glance visuals (a status pipeline, an acceptance meter, a
  clickable user-journey, scope and open-question boards) so it reads in seconds
  instead of pages — with a Markdown fallback where Artifacts are unavailable. A
  read-only, derived view: the /spec and tracker item stay canonical; every
  visual encodes a real spec value, never fabricates status, dates, or
  acceptance criteria, never auto-generates per feature, and never writes into
  /spec, /apps, or /packages.
when_to_use: >-
  Use on demand when someone wants a plain-language, at-a-glance page of a
  feature to look at or hand to a non-technical stakeholder — "show me feature
  X", "make a shareable summary of this feature for the PO". Not for choosing the
  next action (that is /steer:next) or authoring/approving the spec (that is
  /steer:spec); this only presents what the spec already says.
argument-hint: "[feature-id]"
disallowed-tools: Bash, Edit, NotebookEdit, EnterWorktree
---

# Explain a feature — a shareable, plain-language view

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
  `EnterWorktree` are **disallowed in frontmatter** — so, tool-enforced, this skill
  cannot commit, branch, run shell, or edit an existing file in place. It never
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
- No feature id given, or it's ambiguous → list the features under
  `spec/features/*/` with their `Status:` and ask which one. Don't guess.

### 2. Read the sources (the only inputs)

Read, and render strictly from:

- `spec/features/<id>/intent.md` — the PO-language spine (what it does, why, user
  experience, key concepts, scope, open questions, `Status:`, `Owner:`, tracker ref).
- `spec/features/<id>/contract.md` **if it exists** — dev detail; used only to
  enrich, and mostly **summarized or omitted** for a stakeholder audience (see below).
- The tracker ref and open-question `status`/`impact` already recorded in the intent.

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
- **Open questions** — only those still `open`/`investigating`, in plain terms,
  flagging which **block** progress.
- **Contract detail** (data model, API surface) is **dev jargon** — summarize it in
  a sentence or omit it. Do not paste tables of fields/types onto a stakeholder page.

Pick up the product's design tokens if the product `CLAUDE.md` records them —
the `artifact-design` skill already reads them.

### 3a. Show, don't tell — visual encodings (derived, never decorative)

A stakeholder should grasp the feature from the visuals before reading a
paragraph. Encode each spec section as the shape that reads fastest — but **every
visual must encode a real value the spec actually contains**. No fabricated
numbers, no placeholder charts, no invented relationships or dates; a section the
spec leaves empty is shown as *"not specified in the spec"*, never a mocked-up
chart. Map the intent's own sections to these visuals:

- **Status → a lifecycle pipeline.** Render the fixed spine
  `draft → approved → implemented → validated → live` as a horizontal progress
  tracker with the intent's `Status:` marked as the current stage and later stages
  dimmed. **Never advance the marker past the recorded `Status:`** — the pipeline
  reflects the spec, it does not predict. (Enum lives in `ENUMS.md`.)
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
  (`open` / `investigating` only), with **blocking** ones flagged, so "what's
  unresolved and what stops progress" is a glance, not a read.

### 3b. Interactivity — lead with the gist, disclose on demand

- **One-screen summary first.** Open with what/why + the status pipeline + the
  acceptance meter above the fold; put everything else behind collapsible sections
  with a sticky jump-nav. Nobody should scroll five pages to learn the feature's
  state.
- **Keep it accessible and shareable.** Every interactive control is
  keyboard-reachable and labelled, and the page must still make complete sense with
  every section expanded — so a printed copy or a shared screenshot loses nothing.

### 4. Publish (or fall back)

**If the `Artifact` tool is available in this session:**

1. **Load the `artifact-design` skill first** (the Artifact tool requires it before
   authoring a page), and **load `dataviz`** before drawing any chart, meter, or
   diagram so the visuals read as one system and work in both light and dark.
2. **Build every visual self-contained — the Artifact CSP blocks all external
   hosts.** No CDN chart/diagram libraries (Chart.js, Mermaid, D3-from-CDN), no
   remote fonts or images: a page that depends on a remote script renders blank.
   Draw the pipeline, meter, journey, boards, and relationship diagram as **inline
   SVG + CSS** with small **inline JS** for the interactivity, and embed any asset
   as a `data:` URI.
3. Write the page HTML to a **deterministic path in a system temp directory**,
   named for the feature — `<tempdir>/steer-explain-<feature-id>.html` — **never**
   a path under the repo working tree. The stable, per-feature filename is what
   lets a same-session re-run redeploy to the *same* artifact URL rather than mint
   a new one; do not use a randomized temp name.
4. **Give a one-line heads-up before publishing:** publishing sends the rendered
   spec content to claude.ai, where the page is **private to you** until you choose
   to share it. Let the `Artifact` tool's own permission prompt gate the publish —
   do not pre-authorize it.
5. Publish, then give the user the URL and tell them it's private until shared, and
   that re-running in this same session (which reuses the same filename) updates the
   same page.

**If the `Artifact` tool is not available** (e.g. Bedrock/Vertex/Foundry, a
zero-data-retention org, or no claude.ai login):

- Render the **same content as Markdown, printed inline** in the session so the user
  can read and copy it. Do **not** offer to save it to a file — writing a rendered
  copy anywhere under the repo would create exactly the drifting second copy of the
  spec this skill exists to avoid, and the user can copy the inline output wherever
  they want it.
- Markdown is **static** — it carries no interactivity, but keep the at-a-glance
  shape: render the status as a plain inline pipeline
  (`draft → **approved** → implemented → validated → live`), the acceptance as a
  checklist with its "N of 4" count, the journey as a numbered list, and scope as
  two ✓ / ✗ lists. Same derived-only discipline — no fabricated values.
- Say plainly that the hosted artifact isn't available in this environment and why,
  so the fallback isn't mistaken for a failure.

## Updating a previously shared page

Within the same session, re-running redeploys to the same artifact URL. To update
one from a **different** session, the user must hand you its `claude.ai/code/artifact/…`
URL — without it, a fresh session mints a new page. steer does not store that URL for
you (see "derived view"): treat each run as a fresh render unless the user supplies a URL.

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
- Visual system: the `artifact-design` skill (page shell) and `dataviz` (chart
  colour/encoding) — loaded at publish time; all visuals inline, per the CSP.

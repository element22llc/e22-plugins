# Producing Claude Artifacts

The Artifact standard in full. A **Claude Artifact** is a default-private page
Claude publishes to a hosted URL on claude.ai, which the user can then choose to
share with a teammate. Several steer skills turn a read-only, at-a-glance view of
`/spec`, tracker, or audit state into one - a page a reader grasps in seconds
instead of scrolling a wall of terminal text, and can hand to a stakeholder who
has no repo and no Claude Code.

An Artifact is either built from a **published Artifact type** - Docs, Slides,
Dashboard, Design, Motion: a ready-made page that takes Claude's content as data -
or hand-written as a plain HTML page. **steer starts from a type wherever one
fits**; the hand-written page is the fallback, not the default.

**Markdown is the other supported format, not only a fallback.** Every render has
a Markdown form with the same content and, for a fillable page, the same machine
keys, so a reader without claude.ai, a Copilot or Bedrock session, or anyone who
asks for a file to attach or paste gets an equal result
([Markdown output](#markdown-output)).

This reference is the **single source of truth** for *how* steer produces an
Artifact and *what discipline governs it*. Skills that render one - `/steer:explain`,
`/steer:spec questions bundle`, `/steer:audit`, `/steer:spec roadmap`, `/steer:status`,
`/steer:next capabilities` - describe
*what* to put on the page and defer the mechanics and the guarantees here rather
than restating them. When you add Artifact output to a skill, point at this file;
do not re-derive the rules.

## When an Artifact is the right output - and when it is not

Reach for an Artifact when the output is a **shareable, at-a-glance, derived view**
that reads faster as a visual page than as prose:

- a **presentation** of state someone wants to look at or hand on - a feature
  summary, a capability menu, a release timeline, a client review deck;
- a **report / dashboard** - leverage-ranked audit findings, a spec-vs-build drift
  board, a coverage table with status chips;
- a **fillable document** - a questionnaire a stakeholder answers in place (see
  [The return leg](#the-return-leg-how-filled-answers-come-back)).

Do **not** reach for an Artifact when:

- the output is **durable truth** - `/spec`, an ADR, a tracker issue, a committed
  report. An Artifact is a disposable snapshot, never a system of record (see
  [Derived view](#a-derived-view-never-a-source-of-truth)).
- the output is **the next action or a decision to make** - a short recommendation,
  a yes/no gate, a one-line answer. A page is overkill; say it in the session.
- it would carry **secrets or unshareable detail** - publishing sends the content
  to claude.ai. Never put a token, credential, `.env` value, or (for a
  stakeholder page) internal implementation detail onto an Artifact.

An Artifact is always an **offer or an on-demand render**, never automatic: do not
generate one per feature, on a schedule, or as a side effect of another skill. A
second, drifting copy of the spec is exactly what this discipline exists to avoid.

## A derived view, never a source of truth

Every steer Artifact **renders canonical state; it never owns it.** The `/spec`
intent, the tracker item, the audit findings, the router table - those stay
authoritative. The page is a snapshot that can go stale the moment the source
changes; regenerate to refresh.

- **Never fabricate.** Every visual must encode a **real value the source actually
  contains** - a status, a date, a count, an acceptance criterion, a finding. No
  placeholder charts, no invented numbers, no inferred relationships or dates. A
  section the source leaves empty is shown as *"not specified"*, never mocked up.
- **Never advance past the source.** A status pipeline stops at the recorded
  status; an acceptance meter ticks only the boxes the spec ticks; a verdict chip
  states the verdict the audit assigned. The page reflects; it does not predict.
- **An editable page is still a snapshot.** A Doc lets every reader edit it, so
  render spec state as plain text and tables, never as dropdown chips or tick
  boxes a reader could flip, and open with a lead line naming the source and the
  as-of date. Edits there change nothing in the spec. Only a page's declared
  fillable part - a questionnaire's answers, a triage selection - is ever read
  back, and only by its owning ingest path.
- **Do not persist the URL.** The page is disposable - writing its claude.ai URL
  into the spine or docs would recreate the drift and the claude.ai coupling this
  discipline avoids. Give the URL to the user in the session and let them keep it.
  One exception: when an ingest path absorbs a filled Doc, the absorbed source's
  `source.md` records the link as its `Traceability link` - provenance for that
  committed version, not a live pointer.

## Pick the type - three tiers

| Skill | Type | What it renders |
|---|---|---|
| `/steer:status` | **Docs**; **Slides** when the reader will present it (a client review meeting) | the whole spine over the reporting window - shipped / in-progress / needs-input / next |
| `/steer:status feature <id>` | **Docs** | one feature's `intent.md` (+ `contract.md`) - status, sign-off, journey, scope, open questions |
| `/steer:spec questions bundle` | **Docs**, fillable - answers are read back | open questions across the spine |
| `/steer:audit` (code) | **Dashboard**; the triage selection is a companion **Docs** page | the audit's own vetted findings |
| `/steer:audit spec` | **Dashboard**, read-only | the drift findings and their verdicts |
| `/steer:spec roadmap` | **Docs**, the timeline drawn as a diagram | the milestoned work-set (a preview of the Projects v2 view) |
| `/steer:next capabilities` | **Docs** | the live `skills/*/SKILL.md` frontmatter |

`/steer:weekly-update` is not a render: it writes an existing tracker Artifact's
shared database, and this table does not apply to it. **Design** and **Motion**
have no steer render of their own - use them only when the user asks for a
screen mock-up or an animated walkthrough. A Design mock-up is not a design
source until it is exported and committed (`/steer:reference design-sources`).

**Choose the format first.** Render **Markdown** when the user asks for it -
Markdown, a `.md` file, plain text, no Artifact, or a reader who cannot open
claude.ai - or when the session has no `Artifact` tool; otherwise render an
**Artifact**. An explicit ask always wins over the default. Within the Artifact
format, types are **per account**, so discover, never assume:

1. **Typed tier.** Call the `Artifact` tool's `quickstart` with the intent the
   table implies (`document` for Docs, `slides`, `other` for a dashboard). Its
   result names the type to start from - follow it. A Docs page also needs the
   **Claude Docs connector** tools in the session.
2. **HTML tier.** The type is not listed, the quickstart names none, or the Docs
   connector is absent: hand-write the page per
   [The HTML tier](#the-html-tier). A fillable page keeps its copy-out floor.
3. **Markdown tier.** No `Artifact` tool at all: render [Markdown
   output](#markdown-output).

Say which tier ran when it is not the first, and why, in one line - unless the
user chose Markdown, which needs no explanation.

### Before any publish - the heads-up

Give a **one-line heads-up**: publishing sends the content to claude.ai, where
the page is **private to you until you choose to share it**. Let the tool's own
permission prompt gate it - do not pre-authorize. **In a forked skill**
(`/steer:explain`, `/steer:status`) the heads-up travels with the fork's result
rather than ahead of the publish, so the permission prompt - which does surface
in the main session - is the gate that holds. Write it anyway; it tells the reader
what was sent.

### Docs

A Doc is written through the **Claude Docs connector**, not as files: load the
session's docs skill if one is listed, else the connector's `guide`, and follow
its cadence - the skeleton first (title, byline, one pending block per section),
open it, then **one section per call** so the reader watches it fill. No local
file is written at all.

- **Open it** with the `Artifact` tool's `open` action right after creation. A
  forked skill cannot show it to the main session: return the link in its result.
- **Shape follows content** - a run of stages or a timeline is a drawn diagram
  (the connector's `diagram` topic), five or more numbers on one measure a chart,
  items with attributes a table. A connector refusal changes nothing in the doc:
  fix the call, never fall back silently to prose.
- **Fillable Docs** declare which blocks are answers and carry the machine key in
  **visible heading text** (the questionnaire's `## [<feature-id>] Q-NNN`), so the
  export maps each answer back. Never rewrite a fillable Doc a reader has started
  filling: render a new one.

### Dashboard

Start from the Dashboard type (`type_url` from the quickstart, a `title`, no
files), then follow the instructions its create result carries. For steer the
data is a **fixed attached file**: write the vetted findings as JSON to the
session scratchpad (or system temp dir), upload it, and declare its dataset
`fixed: true` - the findings belong to one audited SHA and must not refresh. Every
figure on the page comes from that dataset, which is the derived-view rule in
the type's own words. A Dashboard is read, never filled: a selection the reader
makes goes in a companion Doc.

### Slides

Start from the Slides type, list the design systems for it, and use the one
marked default unless the user names another. One slide per idea the reader will
speak to; the derived-view rules bind every number on a slide.

## The HTML tier

The hand-written page: the fallback when no type fits or none is listed.

### The write-location invariant

Any local file an Artifact needs - this tier's HTML source, a Dashboard's dataset
JSON - goes to the **session scratchpad or a system temp directory, never a path
under the repo working tree** (`/spec`, `/apps`, `/packages`, or any tracked
file). This is what keeps a render read-only over the canonical sources even in a
skill that otherwise writes.

- **Deterministic temp path, stable per subject.** Name the file for what it
  renders - `<tempdir>/steer-<skill>-<subject>.html` (e.g.
  `steer-explain-<feature-id>.html`, `steer-audit-code-<short-sha>.html`). The stable name is
  what lets a **same-session re-run redeploy to the same Artifact URL** instead of
  minting a new page; never use a randomized temp name.
- **Read-only skills keep `Write`.** `/steer:explain`, `/steer:next`,
  `/steer:status` and `/steer:audit` keep the mutating tools disallowed in
  frontmatter (`Edit`, `NotebookEdit`, `EnterWorktree`; `explain` also disallows
  `Bash`) - but `Write` is deliberately **not** disallowed, because writing to
  temp is a permitted write. For most of them it is the *only* one;
  `/steer:audit` is the exception, whose frontmatter documents a **second**
  post-confirmation write its modes instruct - the optional
  `/spec/AUDIT-REPORT.md` / `DRIFT-REPORT.md`. The temp-only rule above governs
  the **Artifact's** write, not every write these skills may make. `/steer:report` sits in the same tier
  for the same reason, though it renders no Artifact: its temp write is the
  scrubbed issue body. `/steer:spec questions bundle` lives in a
  write-capable skill and upholds the same limit as a **prose invariant**: bundle
  writes nothing under the repo tree.
- **Never disallow `Write` to make a render "safe".** `disallowed-tools` is scoped
  to the invoking turn - upstream states the restriction *clears when you send your
  next message* - so dropping `Write` buys no safety. Bind the limit in prose
  instead: render in-run, post-confirmation, to the temp path.

### Rendering mechanics

1. **Load the `artifact-design` skill first** - it calibrates the design
   investment and gives the page shell. **If the session offers a `dataviz`
   skill,** load it too before drawing any chart, meter, or diagram. Where none is
   available, proceed with `artifact-design` alone; do not stall looking for it.
2. **Build every visual self-contained.** Scripts load only from the CDN hosts the
   `Artifact` tool allowlists, at an exact pinned version; everything else - fonts
   aside from Google Fonts, images, `fetch` - is blocked and renders **blank**.
   Prefer **inline SVG + CSS** with small **inline JS** for pipelines, meters,
   boards and timelines, and embed any asset as a `data:` URI.
3. **Be theme- and width-aware.** Style for both light and dark
   (`prefers-color-scheme` plus the viewer's theme toggle). Use relative units and
   let wide content scroll inside its own `overflow-x` container - the page body
   must never scroll horizontally.
4. **Write the HTML** to the deterministic temp path, give the heads-up, publish,
   then report the URL, that it is private until shared, and that a same-session
   re-run redeploys the **same** page - hedged in a forked skill.

### Styling - the product's theme, or the house default

- **Product theme when the repo declares one.** If the working repo has a
  `DESIGN.md` (repo root, or `apps/<app>/DESIGN.md` - see
  `/steer:reference design-sources`), derive the page's look from the tokens it
  actually records, inlined as CSS custom properties. Use only what `DESIGN.md`
  records, never invent a brand for the product.
- **House default otherwise** - the `artifact-design` + `dataviz` guidance.
  `/steer:next capabilities` always uses the default: it renders steer's own
  capability set, not a product's state.
- **Non-negotiables either way:** light *and* dark must both work, contrast stays
  accessible, and the product palette recolors the page shell; it never overrides
  a semantic encoding (severity, verdict, status) into ambiguity.

A typed Artifact takes its look from the type (and, for Slides, the default
design system); do not restyle it.

### Interactivity - lead with the gist, disclose on demand

- **One-screen summary first.** Open with the headline state above the fold; put
  detail behind collapsible sections with a sticky jump-nav.
- **Accessible and shareable.** Every interactive control is keyboard-reachable and
  labelled, and the page must make **complete sense with every section expanded**.

### Fillable pages - the copy-out floor

A hand-written fillable page has no way to hand its input back, so its export
must survive a locked-down iframe:

- **A permission-free copy floor is required - this is the primary export
  path.** The page **always** renders the complete return document into a
  **read-only `<textarea>`/`<pre>` the user can select-all and copy by hand**,
  mirrored from each input on change.
- **A "Copy to clipboard" button and a "Download .md" link are progressive
  enhancement only.** Both need iframe-sandbox grants (`clipboard-write`,
  `allow-downloads`) the frame may lack; the page must be fully usable (fill ->
  copy -> send) with neither working.

## The return leg - how filled answers come back

Every fillable page has exactly **one owning ingest path**, and the machine key
per input is the contract:

- The key sits in **visible heading text** (e.g. `[<feature-id>] Q-NNN`, a
  finding's `finding-key`), so the owning skill maps each answer back
  deterministically after any round-trip (a paste into Word, an email, a Doc
  export).
- **Docs tier - the Doc is the channel.** The reader answers in place and says
  so; the owner hands its link to the ingest path, which **exports the tab as
  `markdown`** with the Docs connector and treats that export as the received
  document. Two export quirks to normalize before matching keys: brackets come
  back escaped (`&#91;` and `\[` for `[`, `\]` for `]`), and consecutive `>` lines
  merge unless separated by a blank `>` line - so write each context line as its
  own quote paragraph. Also list the tab's open comment threads; each is free text
  outside the keyed headings.
- **HTML and Markdown tiers - the export is the channel.** A hand-written page
  stores nothing the reader types, so the copied-out document is the only way
  back.
- **Keys survive, nothing volatile is embedded** (no timestamp, no run id), so two
  exports of the same answers stay byte-identical. **One deliberate exception:**
  `/steer:audit`'s triage export carries the audited commit in its
  `<!-- steer:audit-triage sha=<audited-sha> -->` marker (a Doc carries it as a
  visible `Audited commit: <sha>` line instead - an export drops HTML comments).
  Findings are only meaningful relative to a commit, and the SHA is fixed for the
  run - `/steer:work issues publish-audit` reads it to flag keys that went stale.
- **Today's ingest routes:** `/steer:spec questions bundle` ->
  **`/steer:spec intake clarify <doc-link | filled-doc>`** (PO answers - the key +
  routing contract is [`CLARIFICATION-LOOP.md`](CLARIFICATION-LOOP.md)), and the
  audit triage -> **`/steer:work issues publish-audit <doc-link | triage-doc>`**
  (finding selection). **Do not bolt an ad-hoc input onto a read-only page**: a
  new fillable page needs its own declared key scheme and ingest route before it
  ships.

## Markdown output

Markdown renders when the user asks for it, or when the `Artifact` tool is
**unavailable** - on Bedrock / Vertex / Foundry, in a zero-data-retention org,
with no claude.ai login, or on a surface such as Copilot that has none. Either
way:

- Render the **same content as Markdown, printed inline** in the session. Keep the
  at-a-glance shape - a status pipeline as an inline arrow chain
  (`draft -> **approved** -> ...`), an acceptance meter as a checklist with its
  "N of M" count, a journey as a numbered list, scope as two In / Out lists, a report
  as a table.
- For a **fillable** page, the Markdown *is* the return document itself, so the
  user can send it to the stakeholder and route the filled copy back through the
  page's owning ingest path, which takes a Markdown file exactly as it takes a
  Doc link.
- **A file on request.** When the user wants something to attach or send, also
  write it to `<tempdir>/steer-<skill>-<subject>.md` (the HTML tier's naming) and
  give the path.
- **Never write it under the repo tree** - a rendered copy in the tree is the
  drifting second copy this discipline avoids.
- **When it is a fallback, say so plainly** - that the hosted Artifact isn't
  available in this environment and why - so it is never mistaken for a failure.

## Updating a previously shared page

Within the **same session**, a re-run updates the page already made: a Doc made
earlier in the conversation is edited in place, a typed Artifact is republished to
its `url`, and an HTML page redeploys through its deterministic temp filename.
**In a forked skill** (`/steer:explain`, `/steer:status`) do not promise this:
whether a fork's publish is recognised as an update of an earlier one is not
something steer can verify. To update a page from a **different** session, the
user must hand you its link - without it, a fresh session makes a new page. steer
does not store that link (see
[Derived view](#a-derived-view-never-a-source-of-truth)).

This file is the standard itself, not a condensed rule's companion - nothing
about Artifacts rides in the always-on payload, so a rendering skill loads it
before it renders.

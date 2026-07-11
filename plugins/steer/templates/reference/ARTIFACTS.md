# Producing Claude Artifacts

Full reference for rule `88-artifacts`. A **Claude Artifact** is a self-contained,
default-private web page that Claude publishes to a hosted URL on claude.ai, which
the user can then choose to share with a teammate. Several steer skills turn a
read-only, at-a-glance view of `/spec`, tracker, or audit state into one — a page a
reader grasps in seconds instead of scrolling a wall of terminal text, and can hand
to a stakeholder who has no repo and no Claude Code.

This reference is the **single source of truth** for *how* steer produces an
Artifact and *what discipline governs it*. Skills that render one — `/steer:explain`,
`/steer:questions bundle`, `/steer:audit`, `/steer:roadmap`, `/steer:help` — describe
*what* to put on the page and defer the mechanics and the guarantees here rather
than restating them. When you add Artifact output to a skill, point at this file;
do not re-derive the rules.

## When an Artifact is the right output — and when it is not

Reach for an Artifact when the output is a **shareable, at-a-glance, derived view**
that reads faster as a visual page than as prose:

- a **presentation** of state someone wants to look at or hand on — a feature
  summary, a capability menu, a release timeline;
- a **report / dashboard** — leverage-ranked audit findings, a spec-vs-build drift
  board, a coverage table with status chips;
- a **fillable page** — a questionnaire a stakeholder completes in a browser and
  sends back (see [Fillable pages](#fillable-pages-the-copy-out-floor)).

Do **not** reach for an Artifact when:

- the output is **durable truth** — `/spec`, an ADR, a tracker issue, a committed
  report. An Artifact is a disposable snapshot, never a system of record (see
  [Derived view](#a-derived-view-never-a-source-of-truth)).
- the output is **the next action or a decision to make** — a short recommendation,
  a yes/no gate, a one-line answer. A page is overkill; say it in the session.
- it would carry **secrets or unshareable detail** — publishing sends the content
  to claude.ai. Never put a token, credential, `.env` value, or (for a
  stakeholder page) internal implementation detail onto an Artifact.

An Artifact is always an **offer or an on-demand render**, never automatic: do not
generate one per feature, on a schedule, or as a side effect of another skill. A
second, drifting copy of the spec is exactly what this discipline exists to avoid.

## A derived view, never a source of truth

Every steer Artifact **renders canonical state; it never owns it.** The `/spec`
intent, the tracker item, the audit findings, the router table — those stay
authoritative. The page is a snapshot that can go stale the moment the source
changes; regenerate to refresh.

- **Never fabricate.** Every visual must encode a **real value the source actually
  contains** — a status, a date, a count, an acceptance criterion, a finding. No
  placeholder charts, no invented numbers, no inferred relationships or dates. A
  section the source leaves empty is shown as *"not specified"*, never mocked up.
- **Never advance past the source.** A status pipeline stops at the recorded
  status; an acceptance meter ticks only the boxes the spec ticks; a verdict chip
  states the verdict the audit assigned. The page reflects; it does not predict.
- **Do not persist the URL.** The page is disposable — writing its claude.ai URL
  into the repo (spec, docs, a tracked file) would
  recreate the drift and the claude.ai coupling this discipline avoids. Give the URL
  to the user in the session and let them keep it if they want it.

## The write-location invariant

An Artifact's **only** filesystem write is its HTML source, and it goes to a
**system temp directory — never a path under the repo working tree** (`/spec`,
`/apps`, `/packages`, or any tracked file). This is what keeps an Artifact render
read-only over the canonical sources even in a skill that otherwise writes.

- **Deterministic temp path, stable per subject.** Name the file for what it
  renders — `<tempdir>/steer-<skill>-<subject>.html` (e.g.
  `steer-explain-<feature-id>.html`, `steer-audit-code-<short-sha>.html`). The stable name is
  what lets a **same-session re-run redeploy to the same Artifact URL** instead of
  minting a new page; never use a randomized temp name.
- **Read-only skills.** `/steer:explain` and `/steer:help` keep the mutating
  tools disallowed in frontmatter (`Edit`, `NotebookEdit`, `EnterWorktree`;
  `explain` also disallows `Bash`) — but `Write` is deliberately **not**
  disallowed, because writing the HTML to temp is their one permitted write. `/steer:questions bundle` lives in a write-capable
  skill and upholds the same limit as a **prose invariant**: bundle writes nothing
  under the repo tree.
- **Skills whose frontmatter disallows `Write`** (`/steer:audit`) cannot publish
  during the tool-restricted run. Offer the Artifact as a **post-run step**, exactly
  as those skills already offer their optional committed report: the render + publish
  happen after the user confirms, once the run's tool restriction has cleared. The
  temp-only write keeps it read-only over the repo either way.

## Rendering mechanics — the CSP shapes everything

**If the `Artifact` tool is available in this session:**

1. **Load the `artifact-design` skill first.** The Artifact tool requires it before
   authoring a page — it calibrates the design investment and gives the page shell.
   **If the session offers a `dataviz` skill,** load it too before drawing any chart,
   meter, or diagram, so the visuals read as one system and work in both light and
   dark. Where no `dataviz` skill is available, proceed with `artifact-design` alone;
   do not stall looking for it.
2. **Build every visual self-contained — the Artifact CSP blocks all external
   hosts.** No CDN scripts (Chart.js, Mermaid, D3-from-CDN), no remote stylesheets or
   fonts, no remote images, no `fetch`/XHR/WebSocket. A page that depends on a remote
   resource renders **blank**. Draw pipelines, meters, boards, timelines, and
   relationship diagrams as **inline SVG + CSS** with small **inline JS** for
   interactivity, and embed any asset as a `data:` URI.
3. **Be theme- and width-aware.** Style for both light and dark
   (`prefers-color-scheme` plus the viewer's theme toggle). Use relative units and
   let wide content (tables, timelines, diagrams) scroll inside its own
   `overflow-x` container — the page body must never scroll horizontally.
4. **Write the HTML** to the deterministic temp path above (never under the repo
   tree).
5. **Give a one-line heads-up before publishing:** publishing sends the rendered
   content to claude.ai, where the page is **private to you until you choose to
   share it**. Let the `Artifact` tool's own permission prompt gate the publish — do
   not pre-authorize it.
6. **Publish, then report** the URL, that it is private until shared, and that
   re-running in this same session redeploys the **same** page.

### Interactivity — lead with the gist, disclose on demand

- **One-screen summary first.** Open with the headline state (what/why, the top
  finding, the current status) above the fold; put detail behind collapsible
  sections with a sticky jump-nav. Nobody should scroll pages to learn the state.
- **Accessible and shareable.** Every interactive control is keyboard-reachable and
  labelled, and the page must make **complete sense with every section expanded** —
  so a printed copy or a shared screenshot loses nothing.

### Fillable pages — the copy-out floor

A questionnaire (`/steer:questions bundle`) adds input on top of a read-only page,
and its export must survive a locked-down iframe:

- **A permission-free copy floor is required.** The page **always** renders the
  complete return document into a **read-only `<textarea>`/`<pre>` the user can
  select-all and copy by hand**. Inline JS mirrors each input into this box on
  change so it always reflects current answers.
- **A "Copy to clipboard" button and a "Download .md" link are progressive
  enhancement only.** Both need iframe-sandbox grants (`clipboard-write`,
  `allow-downloads`) the Artifact frame may lack, so they can silently do nothing —
  the page must be fully usable (fill → copy → send) with neither working.
- **Keys survive a round-trip.** Put the machine key in **visible heading text**,
  not only an HTML comment, so it survives a paste into Word and back. Embed nothing
  volatile (no git SHA), so two exports of the same answers stay byte-identical.

## Markdown fallback — not a failure

The `Artifact` tool is **unavailable** on Bedrock / Vertex / Foundry, in a
zero-data-retention org, or with no claude.ai login. When it is:

- Render the **same content as Markdown, printed inline** in the session so the user
  can read and copy it. Keep the at-a-glance shape — a status pipeline as an inline
  arrow chain (`draft → **approved** → …`), an acceptance meter as a checklist with
  its "N of M" count, a journey as a numbered list, scope as two ✓ / ✗ lists, a
  report as a table.
- **Do not write the Markdown to a file under the repo tree** — a rendered copy in
  the tree is the drifting second copy this discipline avoids. The user can copy the
  inline output anywhere they want it.
- **Say plainly** that the hosted Artifact isn't available in this environment and
  why, so the fallback is never mistaken for a failure.

## Updating a previously shared page

Within the **same session**, re-running a skill redeploys to the same Artifact URL
(the deterministic temp filename is what makes this work). To update a page from a
**different** session, the user must hand you its claude.ai URL —
without it, a fresh session mints a new page. steer does not store that URL (see
[Derived view](#a-derived-view-never-a-source-of-truth)); treat each run as a fresh
render unless the user supplies a URL to update.

## Where each skill uses this

| Skill | Artifact | Source state it renders |
|---|---|---|
| `/steer:explain` | Feature summary — status pipeline, acceptance meter, clickable journey, scope + open-question boards | one feature's `intent.md` (+ `contract.md`) |
| `/steer:questions bundle` | Fillable PO questionnaire (see [Fillable pages](#fillable-pages-the-copy-out-floor)) | open questions across the spine |
| `/steer:audit` | Findings dashboard — dimension summary tiles, leverage-ranked findings (code); drift coverage board with verdict chips (spec) | the audit's own vetted findings |
| `/steer:roadmap` | Release timeline — milestones with per-issue bars, dependency ordering | the milestoned work-set (a preview of the Projects v2 view) |
| `/steer:help` | Capability menu — front doors grouped by workflow area | the `00-router.md` intent→skill table |

The lean always-on version of this is rule `88-artifacts`; this reference is its
full rationale and how-to.

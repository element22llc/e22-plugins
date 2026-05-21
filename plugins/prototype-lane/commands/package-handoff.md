---
description: Distill the current prototype branch into a Product Spine and hand off to an engineer for validation.
argument-hint: [optional branch name; defaults to current branch]
---

# /package-handoff

The PO is happy with the prototype. Your job is to **distill what exists** —
the working preview, the commits, the chat context, the PO's reactions — into a
**Product Spine**, then formally request engineer validation.

## Surface and connector requirements

Works on **Claude.ai (Chat), Claude Cowork, and Claude Code**. The GitHub
connector is **required** — without it, this command cannot open the draft PR,
advance the Project card, mirror to the wiki, or post the handoff comment.
Refuse cleanly if the connector is missing. See [`CONNECTORS.md`](../../../CONNECTORS.md).

Connector capabilities used:

- **Pull requests** — open draft PR with the bundled handoff.
- **Repo contents** — write the Spine and bundle as commits on the branch (Chat
  / Cowork case where there is no local checkout).
- **Wiki** (optional) — publish a non-engineer-friendly Spine summary to the
  product wiki under `Proposals/<slug>`. The PO can browse it from anywhere.
- **Projects (v2)** — advance the existing Project card from `vibe-coding` to
  `awaiting-validation`; populate the PR and Spine fields.
- **Labels** — apply `proposal`, `drafting`, `awaiting-validation`,
  `product:<slug>`, and `soc2` if applicable.

The Spine is the artefact that travels. Not the chat log. Not the commit list.
The engineer will read the Spine at `/validate`, not scroll your conversation.

## What must already be true

- A `prototype/*` branch exists with a working preview.
- The PO has indicated they're done iterating ("this is it", "I'm happy",
  "let's hand it off", etc.).

If either is missing, do not proceed. Ask the PO to keep iterating with `/vibe`
or to share which branch this is for.

## Workflow

### 1. Identify the branch

If `$ARGUMENTS` is provided, use it. Otherwise use the current branch. If the
current branch is not `prototype/*`, refuse and explain: *"This command only runs
on prototype-lane branches (`prototype/*`). The current branch is `<name>`. Did
you mean to run `/propose` instead?"*

### 2. Invoke spine-writer

Delegate to the `spine-writer` plugin's `extract-spine` workflow. It will:

- Read every commit on the branch since it diverged from `main`.
- Read the PR description if a draft PR exists.
- Read the preview-URL log to identify which routes/screens the PO actually exercised.
- Read any TODO comments, `// XXX` markers, or open questions Claude left in the code.
- Read the product's `apps/<product>/CLAUDE.md` to ground architectural assumptions.

It will produce or update a file at:

```
proposals/<branch-slug>/product-spine.md
```

(Or, if the product already has a single canonical spine, append a section there
instead — `spine-writer` decides based on the product's `CLAUDE.md`.)

The Spine must have all five sections populated:

- **Intent** — the PO's words, success criteria, out-of-scope
- **UX** — every screen/state the prototype exposed
- **Surface** — every endpoint, event, schema change Claude introduced
- **Architecture** — components, data flow, dependencies added, assumptions
- **Open Questions** — anything Claude couldn't decide alone

See [`PRODUCT_SPINE_TEMPLATE.md`](../../../PRODUCT_SPINE_TEMPLATE.md) for the
canonical layout.

### 3. Invoke handoff-packager

Delegate to the `handoff-packager` plugin. It will:

- Confirm the Spine is complete (no `<placeholders>` left).
- Generate a **dependency delta** — every package added since `main`.
- Generate a **novel patterns report** — anything in the diff that doesn't match
  existing patterns in the codebase.
- Generate a **plugin-violations report** — anything that violates `house-style`,
  `security-rails`, etc. (Prototype lane is lenient; production lane is not. The
  engineer needs to know what will need fixing if they pick `Keep`.)
- Bundle all three into `proposals/<branch-slug>/handoff/`.

### 4. (Optional) Mirror the Spine to the wiki

If the product's repo has a wiki enabled, publish a non-engineer-friendly version
of the Spine to `<Proposals>/<slug>` via the GitHub connector's wiki API. This
gives the PO (and anyone else without repo write access) a browsable view they
can link to from chat or a Cowork artifact.

The wiki copy is **not** the source of truth — the markdown file in the repo is.
Add a header to the wiki page: *"Auto-generated from
`proposals/<slug>/product-spine.md`. Do not edit here; edits will be overwritten
on the next refresh."*

Skip this step silently if the repo has no wiki configured.

### 5. Open a Draft PR

- Title: `proposal: <one-line title from the Spine's Intent section>` (Conventional
  Commits format).
- Description includes:
  - **Champion:** `@<PO github handle>`
  - **Product:** `<slug>`
  - **Lane:** `prototype` (this is where the engineer will pick a new lane via
    `/validate`)
  - **Preview URL:** still live (will stay live until validation completes)
  - **Spine:** link to `proposals/<branch-slug>/product-spine.md`
  - **Handoff bundle:** link to `proposals/<branch-slug>/handoff/`
  - **Dependency delta:** the count and a link
  - **Novel patterns:** the count and a link
  - **Plugin violations:** the count and a link
- Apply labels: `proposal`, `drafting`, `awaiting-validation`, `product:<slug>`,
  and `soc2` if applicable.
- Request review from the relevant CODEOWNERS team. Do not request review from a
  specific engineer unless the PO names one — the team picks up from the
  `awaiting-validation` queue.

### 6. Advance the Project card

Find the Project card created at `/vibe` time (matched by branch name). Update
its custom fields via the GitHub connector's Projects API:

- `Status` → `awaiting-validation`
- `PR` → the just-opened PR number
- `Spine` → the link to `proposals/<branch-slug>/product-spine.md`
- `Handoff bundle` → the link to `proposals/<branch-slug>/handoff/`
- `Wiki summary` → the wiki URL if step 4 published one

If no Project card exists (the PO ran `/vibe` from outside the workflow), create
one now with the same fields.

### 7. Confirm and close out

Post a single short chat message to the PO:

- "Handed off to engineering. Here's what they'll see:"
- Link to the draft PR
- Link to the Spine (in plain language: "this is the summary they'll read")
- One sentence on what happens next: *"An engineer will run `/validate` and pick
  one of: Keep (production-ready), Refactor (works, needs cleanup), Redesign
  (right idea, wrong shape), Reject (wrong problem). You'll get a chat ping when
  they decide — usually within a day or two."*

If the PO can use `/proposal-status`, remind them they can check in any time.

## Things to avoid

- **Do not merge.** Do not approve. Do not change the PR from draft.
- **Do not push to `main`.** Ever.
- **Do not edit the prototype code at this stage.** Packaging is read-only on
  the code; it only writes to `proposals/<branch-slug>/`.
- **Do not skip Spine sections** because the prototype didn't exercise them.
  Empty sections are fine ("UX: no UI changes — backend-only prototype"). Missing
  sections are not.
- **Do not promise "this will ship."** The engineer's gate is real. Reject and
  Redesign are valid outcomes.
- **Do not lose the preview URL.** Production-lane will need it to compare
  against the rebuilt version.

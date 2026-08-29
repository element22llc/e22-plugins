# `/steer-questions bundle` — render the PO-answerable questions as a questionnaire

Read this file only when running `bundle`. The default sweep, the
open-question locations, the done-when contract, the recommended-next-actions
block, and the coupling rules stay in `SKILL.md`.

## Bundle mode (`bundle`)

`/steer-questions bundle [<feature-id>]` renders the open questions **a Product
Owner can answer** as a shareable, fillable questionnaire — the **outbound**
half of the PO clarification loop. The loop, the machine-keyed return document
the page exports, and how `/steer-intake clarify` ingests the filled export are
canonical in
[`CLARIFICATION-LOOP.md`](../../templates/reference/CLARIFICATION-LOOP.md).
**By default it bundles the whole spine — every feature at once** plus
product-level questions; `bundle <feature-id>` narrows to one feature.

### Read-only — a hard invariant (not tool-enforced here, so honor it in prose)

This mode lives in a skill whose default path *writes and deletes* spec files,
so — unlike frontmatter-read-only `/steer-explain` — its tools can't be locked
down; the read-only guarantee is **behavioral, and you must uphold it**. Bundle
**writes nothing under the repo tree**: no legacy heal/delete (step 1), no
`created:` stamping (step 3), no `git add`/commit, no edit to any spec file.
Its **one** write is the Artifact's HTML source, to a **system temp
directory**, never a path under the working tree; it runs **no shell** and
touches the tracker not at all — gathering uses read-only `Glob` / `Read` /
`Grep` only.

### Flow

1. **Locate the spine.** No `/spec` → redirect to `/steer-setup` (or
   `/steer-init` / `/steer-adopt`) and **stop**. No argument = the **whole
   spine, every feature**; an unknown or ambiguous `<feature-id>` → list the
   features under `spec/features/*/` and ask which, never guess.

2. **Gather.** Collect the **same open questions the default flow's
   step-2 sweep (`SKILL.md` → "Steps") identifies** — using the read-only `Grep`/`Read`
   tools only (step 2's `grep` commands are an illustration; reproduce their
   result without running shell). Read each `### Q-NNN` block's **structured
   fields** — `status`, `impact`, `owner` — not just its heading, and honour the
   same scope: `status: open|investigating`, no `steer:placeholder` seeds, and
   legacy `- [ ]` items only where they sit **inside** `## Open questions`. A legacy
   `spec/SPEC-QUESTIONS.md` (step 1) is included **read-only**, never silently
   omitted: `Read` its `## Open` items into the gather scoped `[product]`,
   never migrate or delete it here, and add a notice to run the default
   `/steer-questions` first so it gets healed.

3. **Filter to what the PO can answer.** A bundle carries the questions a
   **Product Owner** can decide — not pure dev/technical work:
   - **Audience.** Include what the PO owns or co-owns: `owner:` **`product`**
     and **`shared`** (the PO owns a half), plus **`design`** / **`security`**
     questions that are product / policy / scope / UX calls. **Exclude**
     *code-fact* questions (the step-4 triage in `SKILL.md` — asking a PO what
     their own code does is a wasted turn) and questions owned solely by
     **`development`**. Report the excluded count, split code-fact vs dev, so
     nothing looks silently dropped and a `shared`/`design`/`security`
     question is never miscounted as "dev-only".
   - **Status.** Solicit only `open` / `investigating`; **exclude `deferred`**
     — re-soliciting a deliberate parking (step 7) re-opens a closed decision.
     Show deferred items read-only "for context" at most, never as a fillable
     field.
   - **Blocking first.** Order `impact: blocking` first and flag it; surface
     any the hook escalated as **stale** — exactly what to push to the PO.
   - **Nothing to ask** → say so, name the excluded / deferred counts, and
     **stop**. Don't render an empty form.

4. **Render — Artifact when available.** Render by the **shared Artifact
   discipline** — rule `88-artifacts`, mechanics in `/steer-reference artifacts`
   ([`ARTIFACTS.md`](../../templates/reference/ARTIFACTS.md)), including the
   **copy-out floor** a fillable page must uphold and its
   progressive-enhancement copy/download controls — do not restate them here.
   The temp path is `<tempdir>/steer-questions-bundle[-<feature-id>].html`.
   The page carries one labelled **`<textarea>` per question**, grouped
   **product-level first, then per feature**, blocking questions visibly
   flagged; each carries its **feature-scoped key `[<feature-id>] Q-NNN`** and
   the question's context, verbatim from the spec.

5. **Markdown fallback.** Where the Artifact tool is unavailable, print the
   **same fillable return-document Markdown inline** — never to a file under
   the repo — per `ARTIFACTS.md`'s fallback rules, saying plainly why the
   hosted artifact isn't available so it isn't mistaken for a failure.

The copy-box, the "Download .md" export, and the Markdown fallback all emit the
**same machine-keyed return document**; its exact shape, the
`[<feature-id>] Q-NNN` key rules, and stale-key handling are the
return-document contract in
[`CLARIFICATION-LOOP.md`](../../templates/reference/CLARIFICATION-LOOP.md).

### Recommended next action

Close with a `## Recommended next actions` block: the one best step is to
**send the questionnaire to the PO** and, when the filled document returns,
**absorb it with `/steer-intake clarify <filled-doc>`**, which maps each answer
back to its `Q-NNN` and routes it here to fold in. Bundle itself changes
nothing in the spec.

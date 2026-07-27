# `/steer:intake` — the intake and clarify pipelines

Read this file when you reach the pipeline step. The scope note, the
"first, every run" checks, the mode list, idempotency/re-run behaviour, edge
cases, the recommended-next-actions block, and the coupling rules stay in
`SKILL.md` and govern both pipelines.

## The intake pipeline (`default`)

### 1. Establish source identity

Resolve a stable kebab-case **`source-id`** for the *logical document*, decoupled
from the PO's filename (the PO renames files; identity must not follow the name):

- explicit `--source-id` / the `<source-id>` argument wins;
- else match against existing `spec/sources/*/source.md` by recorded filename
  **or** title — surface the candidate and **confirm before binding**, never
  silently reuse (`/steer:tracker-sync`'s find-or-create discipline);
- else propose a slug from the document title and confirm it.

### 2. Version, convert, commit

1. Compute the version label `vNNNN-YYYY-MM-DD`: the zero-padded sequence
   `(highest existing version) + 1` is the ordering key; the date (`date +%F`)
   is informational, so two same-day documents still order deterministically.
2. **Idempotency guard:** hash the incoming binary and compare it to the binary
   of **every** committed version under `spec/sources/<id>/versions/` (not only
   the latest — a re-dropped *older* version is just as already-absorbed and
   must not become a spurious new version; the same any-version match
   `/steer:tidy` uses). On a match the PO re-sent an identical file (often
   under a new name) — report `already absorbed as <vNNNN>`, record the new
   filename in `source.md` if it differs, and **stop**: no new version, no
   diff, no edits, no HISTORY entry. If that re-sent file sits at an **in-repo
   drop location** (anywhere but its committed `original.<ext>`), it is a
   redundant duplicate of an already-absorbed source: surface it and route it
   to `/steer:tidy` (which removes it on a yes) — never delete it silently,
   never move it to `spec/reference/` (a duplicate, not a cleanup).
3. Lay down the version directory and convert:
   ```
   spec/sources/<source-id>/
     source.md                          # source-manifest (this plugin's template)
     versions/<vNNNN-YYYY-MM-DD>/
       original.<ext>                   # the committed binary — provenance
       extracted.md                     # normalized Markdown — the diff surface
   ```
   Write `extracted.md` into the version directory **first** (the `Write` tool
   creates the `versions/<vNNNN-YYYY-MM-DD>/` parent), so the directory exists
   before you move the binary into it. **Place `original.<ext>` by relocating
   the dropped file, not copying it** — no stray copy stays stalled where the
   PO uploaded it; the canonical `original.<ext>` is the source's single home.
   For a drop file **inside the repo**, `git mv` it into place (`git add` it
   first if untracked) — the same history-preserving move `/steer:tidy`
   performs. **Only copy** when the drop path lies **outside** the repo (e.g.
   `~/Downloads/…`) — the PO's own file, not repo clutter: copy it in, leave
   the original be, and note that it was left in place. Never remove a drop
   file whose bytes do **not** match the committed `original.<ext>`; surface
   it instead. Normalize the extraction **deterministically** so successive
   versions diff on real content, not converter noise: stable heading levels,
   collapsed blank-line runs, volatile converter metadata (timestamps, author
   GUIDs, slide coordinates) stripped. Convert the **same way every run**.
4. **Capture the diff baseline, do not advance it yet.** Note the version the
   `Latest absorbed version` field in `source.md` names *right now* — the prior
   version the diff (step 3) compares against. Leave the field unchanged until
   step 6, so advancing the pointer never destroys the baseline the diff needs.
5. `git add` the binary (a `git mv`'d in-repo original is already staged; a
   copied external original still needs it) **and** the extraction together so
   one commit is the durable, diffable record — the design-sources principle
   (a Claude-readable extraction committed alongside the traceability source)
   extended to recurring versioned documents (`/steer:reference design-sources`).

### 3. Diff

If this is **not** the first version, diff the new extraction against the prior
version — the baseline captured in step 2.4 (it has **not** been advanced yet):

```sh
git diff --no-index <prev>/extracted.md <new>/extracted.md
```

Parse the hunks into **change units keyed by their nearest enclosing heading
anchor** — a change maps to a topic, not a line number (the same anchor discipline
`template-reconcile.sh` and `/steer:audit` use, so a moved section is not a false
change). Classify each unit **Added / Removed / Modified**.

### 4. The what-changed report

Print (do not write a report file unless asked):

- a header: `source-id`, prior version → new version, and the converter path taken;
- a change table — one row per change unit:

  | Anchor (topic) | Kind | What changed (one line) | Proposed target | Proposed action |
  |---|---|---|---|---|

- a **"no extractable diff"** note for empty/garbled converter output (see Edge cases).

### 5. Reconcile — non-clobbering, human-gated

Route each change unit through the skill that owns the artifact. Intake never
writes feature prose itself:

| Change unit (from the diff) | Routes to | Reused mechanism |
|---|---|---|
| A new feature / capability is described | `/steer:spec-scaffold` then `/steer:spec` | instantiate `intent.md` + `contract.md`; an existing feature is reconciled additively via `template-reconcile.sh`, never clobbered |
| A change to an existing feature's acceptance criteria | `/steer:spec` on the owning `intent.md` | additive edit — copy / append / merge, never overwrite human prose; a conflict becomes an Open question |
| A vision / scope / cross-cutting change | `/steer:spec` on `vision.md` | additive edit; conflicts → Open questions |
| A roadmap / milestone / date change | `/steer:roadmap` | human-confirmed milestones and dates — never fabricated |
| A change that contradicts what the spine/code already says | `/steer:audit` (spec conformance) → `/steer:issues publish-drift` | one issue per real divergence, stable `finding-key`, reconciled across re-runs — never auto-resolved |
| An ambiguous / under-specified change | `/steer:questions` | a `Q-NNN` Open question with `status` / `impact` / `owner` / `required_before` |
| A unit that **answers** an existing open question (clarify mode, bucket 1) | `/steer:questions` (fold-answer path) | folds the answer into the owning `Q-NNN` under `/steer:questions`' step-6 tier gate; records the source-ref + quoted span as provenance. Intake never writes the resolution itself — the resolve direction, symmetric to the raise-direction row above |

The non-clobbering guarantee is **inherited** from these gateways. A genuine
conflict — the document now says X, a human already authored not-X — is never
auto-resolved: it becomes a `Q-NNN` Open question in the owning `intent.md` /
`vision.md`, or, for genuine spec-vs-build drift, a `spec-drift` finding.
Surface it; the human resolves it (fix the artifact, fix the code, or record
the accepted divergence).

### 6. Record

For every **absorbed** change (one that produced a spec edit, an Open question, or
a filed issue), append **one** entry to `spec/HISTORY.md` in the template's exact
bold-key format (`spec/HISTORY.md` → `## Format`):

```markdown
## YYYY-MM-DD — <what changed>
- **Why:** absorbed <source-id> <version>
- **Requested by:** <PO handle> via intake
- **Refs:** spec/sources/<id>/versions/<v>/ · spec/features/<id>/ · #issue
- **Areas:** spec-only (or the areas touched)
```

Then update `source.md`: **advance the `Latest absorbed version` field** (the
diff baseline is no longer needed), mark the version absorbed, and record the
mapped features/issues. The intake run is the auditable event; the PR review
is the evidence.

## The clarify pipeline (`clarify`)

A **client clarification document** is a set of *answers* to open questions,
usually mixed with *new scope*, in whatever shape the client wrote it — not a
version of a prior spec, so there is nothing to git-diff against. The whole
shared contract with `/steer:questions bundle` — the loop, the machine-keyed
`[<feature-id>] Q-NNN` key and its stale/unknown-key handling, the segmentation
rule, and the three-bucket worklist with each bucket's durability rules and
the intake-routes / questions-folds ownership split — is canonical in
[`CLARIFICATION-LOOP.md`](../../templates/reference/CLARIFICATION-LOOP.md);
this section is only what intake itself does. Clarify reuses intake's shared
front-end **verbatim** — step 1 (a clarification is its own `source-id`),
step 2 (version, convert, commit, with the step-2.2 binary-hash guard), and
step 6 (record) — replacing the git-diff (steps 3–4) with:

1. **Segment** the extraction into clarification units per the reference's
   segmentation rule — semantic by default; structural (one unit per
   `## [<feature-id>] Q-NNN` heading) for a recognized bundle return. An
   empty/garbled/absent extraction stops here — handle it exactly as the
   "Edge cases" rows in `SKILL.md` direct.
2. **Map** each unit inline against **(a)** every open `Q-NNN` across the
   spine — reuse the exact grep `/steer:questions` step 2 uses; do not
   re-derive it — and **(b)** the feature list (each
   `spec/features/*/intent.md` / `contract.md` summary). A keyed unit maps
   deterministically per the reference's key-matching rules; for each
   unanchored unit propose the best-match `Q-NNN` (or **"none — new info"**),
   feature, **confidence**, and **matched evidence** — under
   `/steer:questions` step 4's **cost guardrail, verbatim** (the single source
   for that policy; leave a unit in bucket 3 rather than paying to place it).
3. **Route** every unit into the reference's three buckets, from a worklist
   the human confirms in a **single pass** — they correct wrong rows, never
   dictate question IDs. Bucket 1 hands the fold to `/steer:questions` via the
   [step-5 answers row](#5-reconcile--non-clobbering-human-gated) — intake
   writes only the durable `pending /steer:questions fold` annotation, never
   the resolution; bucket 2 routes through the other step-5 rows; bucket 3 is
   surfaced for the human, **never guessed**. The hard floor is **no silent
   wrong write**; re-running clarify on the same binary is a no-op — resume
   un-folded answers with `/steer:questions`, not a re-run.

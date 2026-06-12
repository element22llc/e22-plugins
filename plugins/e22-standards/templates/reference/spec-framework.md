# Spec framework

The `/spec` folder is the **product spine** — the durable source of truth for
what a product does and why. This is the full coupling reference; the always-on
rules state only *when* to create artifacts.

## Lifecycle

| Stage | Lives in | Owner | Stability |
|---|---|---|---|
| Intake | The product's issue tracker (`/spec/tracker.md` — GitHub Issues, Jira, Linear, …) | PO | Conversational, ephemeral |
| Exploration | `/spec/design` for Greenfield; the originating issue + `intent.md` `Design source` for Brownfield | PO + Dev | Disposable / preserved as a link |
| Spec | `/spec` | Dev or PO (via `/e22-build`) writes; PO approves intent; dev approves the PR | Durable |
| Implementation | `/apps` + `/packages` | Dev | Must conform to spec |
| Non-prod validation | Non-prod environment | PO validates, Dev supports | Working but not production |
| Production | AWS | Dev | Deployed |

The spec is the only artifact that persists across exploration, implementation,
validation, and operation. Treat it as infrastructure.

## Structure

```text
/spec
├── vision.md                 # Why this product exists — plus an `## Open questions` section for product-level ambiguities
├── users.md                  # Who uses it and what they need
├── glossary.md               # Shared vocabulary — PO, devs, and Claude all read this
├── HISTORY.md                # Action history — append-only what/why/who-asked/refs log (see /e22-traceability)
├── tracker.md                # Which issue tracker this product uses + reference conventions (client-agnostic)
├── BUILD-STATUS.md           # PO builds only — /e22-build flow state (step, per-feature progress, handoff gate)
├── PRODUCTIONIZATION.md      # Dev's hardening brief — gaps + Keep/Refactor/Rewrite/Reject per area (/e22-adopt, and /e22-build at handoff)
├── app/                      # App knowledge docs — usage, workflows, roles, configuration, troubleshooting, release notes
│   └── README.md
├── design/                   # Greenfield product-level design export + traceability link
│   ├── README.md
│   └── source.md
├── features/
│   └── [feature-id]/
│       ├── intent.md         # The what and why — PO-facing
│       └── contract.md       # Behavior rules, API/data model, owning app(s)/package(s)
└── decisions/
    └── 000N-[slug].md        # Architecture decisions worth remembering
```

The canonical templates are shipped by this plugin. Use `/e22-spec-scaffold <id>`
to create a feature's `intent.md` + `contract.md`, and `/e22-adr <slug>` for an
ADR — both copy from the bundled templates so structure never drifts per feature.

**Open questions live next to their context, not in a separate file.** A question
about one feature goes in that feature's `intent.md` → `## Open questions`; a
product-level question (flagged before any feature exists — greenfield vision
interview, whole-repo adoption) goes in `vision.md` → `## Open questions`. Run
**`/e22-questions`** to sweep every open question across the spine and drive each
to an answer (or an explicit deferral) — otherwise they accumulate and rot.

## Rules

1. **Specs are written with Claude's help — by a dev, or by a PO via `/e22-build`.** The PO approves intent; a dev approves the PR before merge. POs are not expected to write specs from scratch.

2. **Specs are organized by user-facing feature, not by code layout.** Code lives in `/apps` and `/packages`, organized however the stack wants. A single feature may span several apps and packages. The link between a spec feature and its code is the optional pointer section in `contract.md` — at most a hint naming the owning app(s)/package(s), not a folder-mirroring rule or a maintained index. If it's stale or absent, find the code by searching the repo.

3. **Spec and code change together.** A PR that changes behavior should also update the relevant `contract.md`. No CI enforces this — it is on the dev opening the PR and the dev reviewing it.

4. **Specs describe behavior, not incidental implementation.**

   Example:

   * Spec: User can reset password via email.
   * Code comment or contract detail: Uses a specific hashing algorithm or queue implementation.

   Put technical details in `contract.md` only when they matter for behavior, integration, security, or future maintenance.

5. **When spec and code disagree, resolve the drift explicitly.** Do not let the disagreement sit. Decide one way or the other in a single PR:

   * Fix the code to match the spec, or
   * Update the spec to match the code.

   PO approval is needed if user-facing behavior changed. Dev approval is enough if the change is internal or architectural.

   The wrong move is silently leaving them diverged. If you cannot decide in the moment, open an issue labelled `spec-drift` and tag a dev. Drift becomes a tracked item, not a quiet failure.

6. **Use the glossary.** If a term needs explaining, add it to `glossary.md` rather than redefining it in every spec.

7. **Trace PO acceptance.** For user-facing changes, the feature intent should show whether the PO accepted the intent and where that acceptance happened.

## Greenfield flow

For a new product, the starting point can be *anything* — a plain idea or
conversation, a written brief, screenshots, or a Claude Design export. Do
**not** assume a design artifact exists. Guide the dev/PO to a real spec:

1. **Interview** to fill `/spec/vision.md` (what it is, why it exists, what
   success looks like, what it is NOT), `/spec/users.md` (who it serves, their
   job-to-be-done), and `/spec/glossary.md` (shared vocabulary). Ask, don't
   invent — product-level ambiguities go in `vision.md` → `## Open questions`.
2. Draft initial `/spec/features/[id]/intent.md` files for the capabilities the
   product clearly needs. Keep scope honest — flag anything ambiguous in that
   feature's `intent.md` → `## Open questions` instead of guessing.
3. If a Claude Design export exists, read the **local export** (run
   `/e22-design-sources`) — never fetch the URL (it 403s). The design is
   authoritative for visual behavior; the spec for what the system does. Flag
   conflicts in the relevant feature's `intent.md` → `## Open questions`.
4. Get PO approval on the intent specs before broad implementation, then build
   under `/apps` and `/packages`, writing `contract.md` as you go.

A non-technical PO drives this same flow via `/e22-build`, which adapts each
step to plain language and Claude-driven tooling.

**Brownfield** (change to an existing product): triage the issue → size it
(Change-size model) → for medium+ work write/update the spec or ADR first →
implement → update the owning `contract.md` if behavior changed.

## Naming

* Feature IDs are short kebab-case slugs: `user-login`, `password-reset`, `export-csv`.
* ADR files are numbered and slugged: `0003-use-postgres-for-search.md`.

## Architecture Decision Records (ADRs)

Write an ADR when:

- You are making a choice that is hard to reverse later, such as database, auth provider, deployment platform, tenancy model, or major architecture pattern
- You are introducing a new pattern that other features will follow
- You are explicitly rejecting an obvious alternative
- The next dev to look at the code would ask, why did they do it this way?

Do not write an ADR for:

- Routine implementation choices
- Things that are obvious from the code itself
- Decisions about a single feature. Those go in `/spec/features/[id]/contract.md`.

Number ADRs sequentially. Do not renumber when you supersede one. Mark the old
one as superseded and link to the new one. Status values: **Proposed** (under
discussion), **Accepted** (in effect), **Superseded by [link]** (replaced),
**Deprecated** (no longer in effect, kept for history).

## Greenfield design folder

`/spec/design` is a **readable home for a Greenfield product's design export** —
the artifact Claude reads to extract the spec — plus a traceability link back to
where the exploration happened. It is *not* a prototyping workspace: code
exploration happens on a branch under `/apps`, never there. Link, do not copy —
design explorations are disposable; the spec is what carries forward. A purely
Brownfield repo with no Greenfield phase can delete the folder. See
`/e22-design-sources` for the full export-handling walkthrough.

## Template reconciliation (self-healing on re-run)

Some skills **copy** a bundled template into the product repo, where it then
lives on and is revisited across sessions — `PRODUCTIONIZATION.md`
(`/e22-adopt`, and `/e22-build` at handoff), `BUILD-STATUS.md` (`/e22-build`), and per-feature `intent.md` /
`contract.md` (`/e22-spec-scaffold`). The bundled templates evolve (a `/plugin
update` may add a new section, checklist item, or table row), but a file copied
under an older plugin version is frozen at that older shape. Skills that resume
from such a file by "continuing from the unchecked/empty items" would silently
miss anything added after the file was created — the new gate isn't *in* the file
to be noticed.

**The rule: instantiating skills self-heal on re-run.** Whenever such a skill is
about to act on a file that already exists from a prior run, first reconcile it
against the current bundled template:

- **Diff** the bundled template against the existing file and **splice in** only
  what the file is missing — `##` sections, checklist items (`- [ ] …`), and
  table rows — leaving the spliced-in items **unchecked / empty**.
- **Match on stable anchors** so nothing duplicates: the section heading, the
  checkbox label, and a table row's key cell (e.g. the gap-analysis **Area**, the
  feature/section name). If an item is already present under any form, leave it.
- **Preserve everything already there.** Never overwrite a filled-in value,
  reorder content, or delete a row the dev/PO added. Reconciliation is **purely
  additive**.
- On a **fresh** run (the file doesn't exist yet) this is a no-op — the file is
  created from the current template as usual.

**Reconcile FIRST, with a forcing command — do not rely on remembering.** On a
resume, reconciliation is the **first action** — before you summarize status,
choose next steps, or continue from the unchecked/empty items. Resuming "from the
checklist" without this step is the exact failure this convention exists to
prevent: the new gate isn't in the file, so it never gets noticed. To guarantee
the comparison actually happens, **run a diff command and act on its output**
instead of eyeballing — surface the headings/checklist items the bundled template
has that the existing file lacks (substitute the real paths):

```sh
comm -13 \
  <(grep -hE '^(#{2,3} |- \[)' <existing-file>                          | sed -E 's/\[[xX]\]/[ ]/' | sort -u) \
  <(grep -hE '^(#{2,3} |- \[)' "$CLAUDE_PLUGIN_ROOT/<bundled-template>" | sed -E 's/\[[xX]\]/[ ]/' | sort -u)
```

The command **over-reports**: a placeholder the dev replaced with real content, or
a checklist item they reworded, shows up as "missing" when it isn't. It is a
*candidate* list, not a splice list — it forces you to open the bundled template
and confront the gaps, but you still apply the additive rules above with judgment.
Splice in genuinely-new `##` sections and items; **never re-add a placeholder the
dev already filled in**, and treat a reworded equivalent as already present. Empty
output means the file is already current.

This makes template additions **self-healing**: a repo touched under an older
plugin version picks up newly added sections on its next run instead of silently
missing them.

**Exempt — do not reconcile:**

- **Reference prose** (`templates/reference/*`) is read in place from the plugin,
  never copied into the repo, so it is always current via `/plugin update` —
  there is nothing to reconcile.
- **ADRs** (`/e22-adr`) are immutable, point-in-time records. Each run creates a
  new numbered file; you never retrofit new template sections into an accepted
  ADR. Supersede with a new ADR instead (see *Architecture Decision Records*
  above) — never edit history to match a newer template.

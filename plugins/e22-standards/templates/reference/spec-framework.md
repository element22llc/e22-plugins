# Spec framework

The `/spec` folder is the **product spine** — the durable source of truth for
what a product does and why. This is the full coupling reference; the always-on
rules state only *when* to create artifacts.

## Lifecycle

| Stage | Lives in | Owner | Stability |
|---|---|---|---|
| Intake | GitHub Issues | PO | Conversational, ephemeral |
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
├── vision.md                 # Why this product exists
├── users.md                  # Who uses it and what they need
├── glossary.md               # Shared vocabulary — PO, devs, and Claude all read this
├── SPEC-QUESTIONS.md         # Open ambiguities flagged during spec work
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

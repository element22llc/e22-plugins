# Productionization — [Product name]

> The **dev's productionization brief** — every gap and as-built risk to harden
> before this app is production-grade, with a **disposition** for each area. It
> is also the **resumable checklist** for the flow that produced it. A fresh
> session reads this first and continues from the unchecked items; never restart
> from scratch.
>
> Produced by **`/steer:adopt`** (an existing non-template repo brought into the
> standards — the main case, with real legacy code to triage) and carried into
> **`/steer:build`** (a PO-built v0 handed to a dev — mostly stubs to finish, see
> the disposition note below).

## Lifecycle

> One parseable field controls **how this brief is read** — so a resumed session
> never re-tracks checkboxes that have already become issues, and a live system
> isn't treated as a fresh adoption:
>
> - **`active-adoption`** — the checklist below is **live and resumable**; a fresh
>   session continues from the unchecked items (the default at adoption time).
> - **`published-snapshot`** — every intended finding has been filed as an issue;
>   those **issues are now canonical** for ownership and closure. Follow the
>   `Published findings:` refs and the tracker — treat the checkboxes below as a
>   historical snapshot, **not** active work.
> - **`superseded`** — this brief was replaced (e.g. a full rewrite from spec);
>   **requires** a `Superseded by:` pointer. Historical only.

> Lifecycle: active-adoption
> Published findings: [issue refs once published via `/steer:issues publish-adoption`, else empty]
> Superseded by: [replacement pointer if superseded, else empty]

> **What publishes, and where.** `/steer:issues publish-adoption` does **not**
> file one issue per section, row, or bullet — findings are **deduplicated by
> remediation work-shape** (keyed to a `finding-key`, drawn across sections); the
> same underlying fix is one finding even if it surfaces in several places. Route
> each section as follows:
>
> - **Gap analysis** rows with an action (Refactor / Rewrite / Reject) →
>   `kind=finding` + `source:adoption`, **one finding per remediation work-shape**.
>   `Keep` rows → nothing.
> - **Outdated dependency table** → at most **one** "upgrade outdated majors
>   behind green tests" finding (dev-owned, on a branch) — **not one issue per
>   package**.
> - **Bad practices** list → findings **only where not already a gap-analysis
>   row** — never file the same fix twice (e.g. raw SQL already lands as the
>   Data-layer gap).
> - **Architectural choices requiring decision** → `/steer:adr` (Proposed) or
>   `/steer:questions` — **never a finding** (never infer a decision from code).
>   *But* a concrete code defect inside that area (a swallowed error, an unscoped
>   query, a silent fallback) **is** still a finding.
> - **Stop-and-rotate** → rotate the secret; not a finding.
> - **Open questions** → `/steer:questions`.
> - **Overall recommendation / Adoption progress / Lifecycle** →
>   narrative/metadata; never findings.

## Overall recommendation

> Roll the per-area dispositions below into one steer for the dev. **When most
> areas land in Rewrite/Reject, recommend rebuilding from the extracted `/spec`
> rather than hardening in place** — the spec exists now, so a from-scratch
> rebuild is a safe, often cheaper route to production than fixing a pile of
> issues. A project-level Rewrite or Reject is hard-to-reverse: record it as an
> ADR (`/steer:adr`) for the dev to ratify — Claude proposes, the dev decides.

- **Recommendation:** [harden in place / partial rewrite (areas …) / full rewrite from spec / reject]
- **Why:** [one or two lines]

## Stop-and-rotate

> Secrets found committed in the repo or its history. These are stop-and-rotate
> (secrets rule): tell the dev, rotate the credential — do **not** just delete
> the line. Leave empty if none found.

- [none found / `path:line` — what it is — rotated? ]

## Adoption progress

- [ ] Codebase surveyed; user-facing features listed
- [ ] Product spec reverse-engineered (`vision.md`, `users.md`, `glossary.md`)
- [ ] Feature specs extracted (`intent.md` + `contract.md` per feature)
- [ ] As-built architectural choices captured as facts with evidence and a
      conformance disposition (below); explicit forward decisions recorded as
      `Proposed` ADRs where required
- [ ] Gap analysis below filled
- [ ] Dependency freshness checked (live registry) + bad practices flagged
- [ ] Template scaffolding synced (mise, compose, CI, configs, plugin install)
- [ ] Toolchain pinned and locks committed
- [ ] PR proposed/opened: [link]

## Gap analysis

> Current state vs the standard, the **disposition**, and the action for the
> dev. Mark each action as the work is done.
>
> **Disposition** is the dev's call per area — Claude **proposes**, the dev
> **ratifies at PR review** (the hard gate):
> - **Keep** — production-grade as-is; no work.
> - **Refactor** — structure is sound; harden in place. (The default.)
> - **Rewrite** — discard the implementation, rebuild from the spec; note in the
>   action cell if the *design* also changes vs. just the code.
> - **Reject** — remove it; not in the spec, dead, or a liability to delete.
>
> Greenfield PO builds (`/steer:build`) are **Keep/Refactor** by default — there's
> no legacy to triage, only stubs to finish before production.

| Area                         | Standard (rule)        | Current state | Disposition | Action / rationale |
| ---------------------------- | ---------------------- | ------------- | ----------- | ------------------ |
| Automated tests              | tests per change (40)  |               |             |                    |
| Test coverage                | coverage signal (41)   |               |             |                    |
| Lockfiles & version pins     | conventions (85)       |               |             |                    |
| Secrets handling             | secrets (70)           |               |             |                    |
| High-risk areas              | high-risk (60)         |               |             |                    |
| CI                           | Definition of Done (50)|               |             |                    |
| Zod boundaries / error model | practices (85)         |               |             |                    |
| Data layer (ORM, schema, migrations) | practices (85) |             |             |                    |
| Dependency freshness         | stack (10), practices (85)|            |             |                    |
| Layout (`/apps`, `/packages`)| layout (20)            |               |             |                    |

## Architectural choices requiring decision

> Hard-to-reverse choices the gap table above doesn't capture (auth model,
> tenancy, deployment platform, database engine, sync-vs-event processing,
> monolith-vs-services, data-access strategy). These are **observed
> implementations, not approved decisions** — the code proves a choice *exists*,
> not *why* it was made or that anyone authorized it. **Never infer an ADR from
> the code.** An ADR is created only after a **named human** chooses a forward
> direction, and stays `Proposed` until that decider explicitly accepts it.

| Choice | Observed implementation | Evidence | Conformance | Proposed direction | Decision status | ADR |
| ------ | ----------------------- | -------- | ----------- | ------------------ | --------------- | --- |
| Data access | Raw SQL via `pg` pool | `src/db/…` | Does not conform (rule 85) | Replace with Drizzle | Pending | — |
| Database | PostgreSQL | `compose.yaml`, migrations | Conforms | Retain | Pending | — |

## Outdated dependencies & bad practices

> A vibe-coded app pins to whatever versions the generating model knew at **its**
> training cutoff — usually a major or two behind, sometimes a library since
> superseded. Versions below are checked **live against the registry**
> (`npm view <pkg> version`, `uv pip index versions <pkg>`, current Node LTS) —
> not from memory, which has the same cutoff problem. Flag every major behind and
> any superseded library; the dev owns the upgrade, on a clean branch with tests
> green. Leave the relevant rows empty if nothing is behind.

| Package / runtime | Pinned | Latest stable | Majors behind | Note / action |
| ----------------- | ------ | ------------- | ------------- | ------------- |
|                   |        |               |               |               |

Bad practices found in the as-built code (anti-patterns vs the `practices` rule):

> Measure against the standard, not against a weaker bar. Two traps the
> as-built code commonly hides:
> - **Raw SQL is the violation, parameterized or not.** The standard is data
>   access through Drizzle/SQLAlchemy only. Parameterization clears *injection*,
>   it does **not** clear raw SQL — flag every raw/`db.execute`/string-built
>   query as a gap even when it's safely parameterized. Don't write it off as
>   "verified clean."
> - **No schema is a gap, not an absence of findings.** If the data model isn't
>   defined anywhere (no Drizzle schema / SQLAlchemy models, no migrations
>   directory, schema living only in a running DB), that is a flagged gap — the
>   schema must be defined in code and migration-tracked.

- [none / `path:line` — what it is — why it's a problem — fix]

## Open questions

- [Dev-facing hardening ambiguities surfaced during adoption.] Product/behavior
  ambiguities live in each feature's `intent.md` → `## Open questions` (and
  `vision.md` for product-level). Run `/steer:questions` to work them all down.

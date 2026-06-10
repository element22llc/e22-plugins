# Productionization — [Product name]

> The **dev's productionization brief** — every gap and as-built risk to harden
> before this app is production-grade, with a **disposition** for each area. It
> is also the **resumable checklist** for the flow that produced it. A fresh
> session reads this first and continues from the unchecked items; never restart
> from scratch.
>
> Produced by **`/e22-adopt`** (an existing non-template repo brought into E22
> standards — the main case, with real legacy code to triage) and carried into
> **`/e22-build`** (a PO-built v0 handed to a dev — mostly stubs to finish, see
> the disposition note below).

## Overall recommendation

> Roll the per-area dispositions below into one steer for the dev. **When most
> areas land in Rewrite/Reject, recommend rebuilding from the extracted `/spec`
> rather than hardening in place** — the spec exists now, so a from-scratch
> rebuild is a safe, often cheaper route to production than fixing a pile of
> issues. A project-level Rewrite or Reject is hard-to-reverse: record it as an
> ADR (`/e22-adr`) for the dev to ratify — Claude proposes, the dev decides.

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
- [ ] As-built decisions captured as ADRs (`/spec/decisions/`)
- [ ] Gap analysis below filled
- [ ] Dependency freshness checked (live registry) + bad practices flagged
- [ ] Template scaffolding synced (mise, compose, CI, configs, plugin install)
- [ ] Toolchain pinned and locks committed
- [ ] PR proposed/opened: [link]

## Gap analysis

> Current state vs the E22 standard, the **disposition**, and the action for the
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
> Greenfield PO builds (`/e22-build`) are **Keep/Refactor** by default — there's
> no legacy to triage, only stubs to finish before production.

| Area                         | Standard (rule)        | Current state | Disposition | Action / rationale |
| ---------------------------- | ---------------------- | ------------- | ----------- | ------------------ |
| Automated tests              | tests per change (40)  |               |             |                    |
| Lockfiles & version pins     | conventions (85)       |               |             |                    |
| Secrets handling             | secrets (70)           |               |             |                    |
| High-risk areas              | high-risk (60)         |               |             |                    |
| CI                           | Definition of Done (50)|               |             |                    |
| Zod boundaries / error model | practices (85)         |               |             |                    |
| Data layer (ORM, schema, migrations) | practices (85) |             |             |                    |
| Dependency freshness         | stack (10), practices (85)|            |             |                    |
| Layout (`/apps`, `/packages`)| layout (20)            |               |             |                    |

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

> Measure against the E22 standard, not against a weaker bar. Two traps the
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

- See `/spec/SPEC-QUESTIONS.md` for product/behavior ambiguities surfaced during
  adoption.

# Production readiness — [Product name]

> Written by `/e22-adopt` when an existing (non-template) repo is brought into
> E22 standards. It is the **dev's productionization brief** — every gap and
> as-built risk to harden before this app is production-grade — and the
> **resumable adoption checklist**. A fresh session reads this first and
> continues from the unchecked items; never restart adoption from scratch.

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

> Current state vs the E22 standard, with the action for the dev. Mark each
> action as the work is done.

| Area                         | Standard (rule)        | Current state | Action |
| ---------------------------- | ---------------------- | ------------- | ------ |
| Automated tests              | tests per change (40)  |               |        |
| Lockfiles & version pins     | conventions (85)       |               |        |
| Secrets handling             | secrets (70)           |               |        |
| High-risk areas              | high-risk (60)         |               |        |
| CI                           | Definition of Done (50)|               |        |
| Zod boundaries / error model | practices (85)         |               |        |
| Dependency freshness         | stack (10), practices (85)|            |        |
| Layout (`/apps`, `/packages`)| layout (20)            |               |        |

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

- [none / `path:line` — what it is — why it's a problem — fix]

## Open questions

- See `/spec/SPEC-QUESTIONS.md` for product/behavior ambiguities surfaced during
  adoption.

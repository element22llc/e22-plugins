## Who you are working with

Two audiences work in managed product repos. The standards below apply identically
to both — never soften the Definition of Done, testing, spec coupling, or high-risk
handling because the person is non-technical.

- **Product Owner (PO)** — non-technical; describes ideas, validates intent, doesn't
  read code. Signals: "I'm not a developer", "I have an idea for an app", asks for
  plain language, no git/stack vocabulary.
- **Developer (dev)** — productionizes, reviews, deploys. Uses technical terms.

**In PO mode:** speak plainly, work spec-first, and drive the toolchain (mise,
Docker, pnpm) yourself rather than handing over commands. Build is the **default
posture**: on the PO signals above — or an ambiguous-but-non-technical request, or
an existing `spec/BUILD-STATUS.md` (an in-progress build, flagged by the
SessionStart hook) — auto-start `/steer:build` with a one-line heads-up and resume
from its current step. When the PO wants to think a feature through before any
code, that is `/steer:spec` — offer it plainly ("we can work out what this should
do first") and drive it for them. Guardrails: never deploy, touch `/infra`, or use
real secrets/credentials or real third-party accounts. A pre-production build may
implement high-risk features for real locally (High-risk pre-production
relaxation) — record every choice in the spec and the PR's productionization
brief. The PO owns data **semantics** (what exists, what "delete" means to a
user); the dev confirms the **mechanics** (schema, cascades, retention) at review.

**The gate is unchanged:** a PO-built app is normal `feat/*` work that merges to `main`
as v0 only after a dev approves the PR. That review *is* productionization.

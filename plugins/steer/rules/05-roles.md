## Who you are working with

Two audiences work in managed product repos. The standards below apply identically
to both — never soften the Definition of Done, testing, spec coupling, or
high-risk handling because the person is non-technical.

- **Product Owner (PO)** — non-technical; describes ideas, validates intent,
  doesn't read code. Signals: "I'm not a developer", "I have an idea for an
  app", asks for plain language, no git/stack vocabulary.
- **Developer (dev)** — productionizes, reviews, deploys. Uses technical terms.

**In PO mode:** speak plainly, no jargon; work spec-first; drive the toolchain
(mise, Docker, pnpm) yourself instead of handing the PO commands. Point the PO
to **`/steer:build`** for the guided idea→working-app flow. Guardrails: never
deploy, never touch `/infra`, never real secrets/credentials or real
third-party accounts. Beyond that, a pre-production build may implement
high-risk features for real locally (High-risk rule's pre-production
relaxation) — record every choice in the spec and the PR's productionization
brief. The PO owns data **semantics** (what exists, what "delete" means to a
user); the dev confirms the **mechanics** (schema, cascades, retention) at
review.

**The gate is unchanged:** a PO-built app is normal `feat/*` work that merges
to `main` as v0 only after a dev approves the PR. That review *is*
productionization.

## Who you are working with

Two audiences work in E22 product repos. The standards below apply identically
to both — never soften the Definition of Done, testing, spec coupling, or
high-risk handling because the person is non-technical.

- **Product Owner (PO)** — non-technical; describes ideas, validates intent,
  doesn't read code. Signals: "I'm not a developer", "I have an idea for an
  app", asks for plain language, no git/stack vocabulary.
- **Developer (dev)** — productionizes, reviews, deploys. Uses technical terms.

**In PO mode:** speak plainly, no jargon; work spec-first; drive the toolchain
(mise, Docker, pnpm) yourself instead of handing the PO commands. Point the PO
to **`/e22-build`** for the guided idea→working-app flow. Guardrails: never
deploy, never touch `/infra`, and high-risk areas (auth, secrets, migrations,
billing, deletion) are stubbed minimally and flagged for a dev — not built for
real.

**The gate is unchanged:** a PO-built app is normal `feat/*` work that merges
to `main` as v0 only after a dev approves the PR. That review *is*
productionization.

---
description: Guide a non-technical product owner from an idea to a working local app — interview, auto-drafted spec, PO intent approval, then build, run, and demo, ending in a PR for dev review.
---

Run the Element 22 PO build flow for this repository by following the
`e22-build` skill.

Speak in plain language throughout — the user is a product owner, not a
developer. Interview them to fill the product spec, scaffold feature intents,
get their explicit approval on each intent, then build the app with the E22
default stack, run it locally (`mise run dev:setup` + `pnpm dev`), and walk
them through it. Drive all tooling (mise, Docker, pnpm) yourself. Respect the
PO-mode guardrails: no deploy, no `/infra`, high-risk areas stubbed and
flagged. Finish by proposing a PR whose description is the dev's
productionization brief.

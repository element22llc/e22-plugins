---
description: Guide a non-technical product owner from an idea to a working local app — interview, auto-drafted spec, PO intent approval, then build, run, and demo, ending in a PR for dev review.
---

Run the Element 22 PO build flow for this repository by following the
`e22-build` skill.

Speak in plain language throughout — the user is a product owner, not a
developer. If `/spec/BUILD-STATUS.md` exists, read it first and resume from
the recorded step. Otherwise: interview them to fill the product spec,
scaffold feature intents, get their explicit approval on each intent, then
build the app with the E22 default stack, run it locally
(`mise run dev:setup` + `pnpm dev`), and walk them through it. Drive all
tooling (mise, Docker, pnpm) yourself. Respect the PO-mode guardrails: no
deploy, no `/infra`, no real secrets or third-party accounts. Propose the
handoff PR only after the PO explicitly confirms the demoed app does what
they wanted (the skill's demo-validation gate); write the dev's durable
handoff brief to `/spec/PRODUCTIONIZATION.md` (the same artifact `/e22-adopt`
produces) and link it from the PR.

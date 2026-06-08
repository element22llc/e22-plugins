---
description: Adopt an existing non-template ("vibe-coded") repo into Element 22 standards — reverse-engineer the /spec from the code, assess production readiness, and sync the template scaffolding, ending in a PR for dev review.
---

Adopt this existing repository into Element 22 standards by following the
`e22-adopt` skill.

This is for a repo that was **not** forked from `repository-template` — working
code, but no `/spec`, no `mise.toml`, no plugin install. If `/spec/PRODUCTION-READINESS.md`
already exists, read it first and resume from its unchecked items. Otherwise:
survey the codebase, reverse-engineer the product spec (`vision.md`, `users.md`,
`glossary.md` — ask, don't invent), extract `intent.md` + `contract.md` per
feature via `/e22-spec-scaffold`, capture as-built choices as ADRs via
`/e22-adr`, and write `/spec/PRODUCTION-READINESS.md` (the dev's hardening
brief). Then fetch `element22llc/repository-template` and sync in the scaffolding
it lacks (mise tasks, compose.yaml, CI, configs, .env.example, plugin install),
adapting to the existing stack and never clobbering working code. Work on a
`feat/e22-adopt` branch; rotate any committed secrets you find. Propose the
handoff PR only after the dev approves — that review is the productionization
gate.

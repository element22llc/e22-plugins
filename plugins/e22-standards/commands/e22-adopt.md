---
description: Adopt an existing non-template ("vibe-coded") repo into Element 22 standards — reverse-engineer the /spec from the code, triage productionization (Keep/Refactor/Rewrite/Reject per area), and sync the template scaffolding, ending in a PR for dev review.
---

Adopt this existing repository into Element 22 standards by following the
`e22-adopt` skill.

This is for a repo that was **not** forked from `repository-template` — working
code, but no `/spec`, no `mise.toml`, no plugin install. If `/spec/PRODUCTIONIZATION.md`
**or** the older `/spec/PRODUCTION-READINESS.md` exists, you are **resuming** a
prior adoption. If `/spec/PRODUCTION-READINESS.md` is the one on disk, your
**first action** — before reading it, summarizing status, or anything else — is to
migrate it: run `git mv spec/PRODUCTION-READINESS.md spec/PRODUCTIONIZATION.md`
(it was renamed in v1.22.0). Then invoke the `e22-adopt` skill and run its step-2
reconcile **first** (it splices in sections newer plugin versions added) **before**
reading the checklist, summarizing status, or proposing next steps; do not skip
this because the file looks complete. Otherwise (fresh adoption):
survey the codebase, reverse-engineer the product spec (`vision.md`, `users.md`,
`glossary.md` — ask, don't invent), extract `intent.md` + `contract.md` per
feature via `/e22-spec-scaffold`, capture as-built choices as ADRs via
`/e22-adr`, and write `/spec/PRODUCTIONIZATION.md` (the dev's hardening
brief — propose a Keep/Refactor/Rewrite/Reject disposition per area, and when
most areas trend Rewrite/Reject recommend rebuilding from the extracted spec). Then fetch `element22llc/repository-template` and sync in the scaffolding
it lacks (mise tasks, compose.yaml, CI, configs, .env.example, plugin install),
adapting to the existing stack and never clobbering working code. Work on a
`feat/e22-adopt` branch; rotate any committed secrets you find. Propose the
handoff PR only after the dev approves — that review is the productionization
gate.

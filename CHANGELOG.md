# Changelog

All notable changes to the `e22-plugins` marketplace. Each plugin is versioned
in its own `.claude-plugin/plugin.json`; this file records what changed and when.

## e22-standards

### 1.1.0

- Local-dev `.env` bootstrap: the Stack and Secrets rules now require that when
  setting up or running an app locally, `.env` is created and populated with
  the base variables the app needs to boot — e.g. `DATABASE_URL` pointing at
  the local Compose PostgreSQL and freshly generated local-only secrets (auth
  secret, API tokens) — instead of leaving the dev to hand-assemble it from the
  README. Deployed/production secret values must never be copied into it.

### 1.0.0

- Initial release. Fresh start: replaces the earlier experimental 7-plugin
  three-zone marketplace (removed — preserved in git history) with a single
  `e22-standards` plugin mirroring the `repository-template` org standards.
- Always-on ruleset (`rules/*.md`) injected via a `SessionStart` hook: stack,
  layout, spec workflow, testing, Definition of Done, high-risk areas, secrets,
  change-size model, baseline patterns/anti-patterns, design-sources, and the
  end-of-session checklist.
- Skills: `e22-init`, `e22-spec-scaffold`, `e22-adr`, `e22-conventions`,
  `e22-design-sources`. Command: `/e22-init`.
- Bundled spec templates (`feature-intent`, `feature-contract`, `adr`) and full
  reference prose (`CONVENTIONS.md`, `DESIGN-SOURCES.md`, `spec-framework.md`).

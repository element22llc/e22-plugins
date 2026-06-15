# Fixture: no /spec spine — bootstrap is the only action

Phase 0 short-circuit: with no `/spec` spine there is nothing to reconstruct, so
arbitration never runs.

## Given

- The repo has working code but no `/spec` directory.
- There is uncommitted feature work and a `feat/*` branch in progress.
- No `spec/tracker.md`, no `spec/.version`.

## Expected highest-priority action

Bootstrap the repo onto E22 standards by reverse-engineering the `/spec` from the
existing code (existing "vibe-coded" app), then resume.

## Expected category

Blocking now

## Expected suggested command

`/e22-adopt` (existing code). For a greenfield repo with no code yet, the
command would instead be `/e22-init`.

## Must not recommend first

Reconstructing branch/PR/tracker state and arbitrating an action. Phase 0 stops
before the sweep: without a spine there is no workspace state to navigate, and
bootstrapping is the only meaningful next step.

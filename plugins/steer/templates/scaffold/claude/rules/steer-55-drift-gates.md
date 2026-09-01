---
paths:
  - "**"
---
<!-- steer:managed 55-drift-gates v6.0.0 body-cksum:1526543328 — installed by /steer:init / /steer:adopt and reconciled by /steer:sync. Edit the rule in the steer plugin, not here: a local edit is detected and preserved, but it will not reach any other repo. -->

## Drift gates — surface before merge

Drift — any meaningful mismatch along intent ↔ spec ↔ contract ↔ tracker ↔ app
docs ↔ tests ↔ delivered behavior — is resolved by **explicit human review,
never silently**: you *surface* it before merge; the reviewer resolves it (fix
code, fix artifact, or record the accepted divergence). Flag these
review-sensitive classes in the PR description **the moment you notice one**
(the scaffold's PR template carries the checklist): **intent drift · contract
drift · undocumented behavior change · security-sensitive ·
compliance-impacting · operational (deploy/CI/infra) · local setup or
deployment changed · app docs invalidated · architecture/stack drift
(`ARCHITECTURE.md`)**. A flagged class blocks merge
until the reviewer explicitly resolves it — you may not waive your own flag.
Periodic sweeps: `/steer:audit` (`code` health, `spec` conformance).

The scaffold's CI also carries an **advisory** `spec-drift` job that *warns*
(never blocks) when a change touches application behavior without updating the
owning `contract.md` / `intent.md` — a machine backstop for the *undocumented
behavior change* class, and in solo-trunk (no PR) the only one. A warning is a
prompt, not a substitute for the flag: still flag the class and update the spec in
the same change. Mechanics: `/steer:reference traceability`.

<!-- steer:inject-when=code-project -->
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
(never blocks) when a change touches application behavior without updating a
feature `contract.md` / `intent.md` or `spec/HISTORY.md` — a machine backstop for
the *undocumented behavior change* class. It runs on PRs and on push to `main`
(the latter is the only enforcer in solo-trunk, which has no PR). A warning is a
prompt to do the right thing, not a substitute for the flag: still flag the class
and update the spec in the same change.

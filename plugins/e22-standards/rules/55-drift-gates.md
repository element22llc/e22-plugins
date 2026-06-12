## Drift gates — surface before merge

Drift — any meaningful mismatch along intent ↔ spec ↔ contract ↔ tracker ↔ app
docs ↔ tests ↔ delivered behavior — is resolved by **explicit human review,
never silently**: you *surface* it before merge; the reviewer resolves it (fix
code, fix artifact, or record the accepted divergence). Flag these
review-sensitive classes in the PR description **the moment you notice one**
(the scaffold's PR template carries the checklist): **intent drift · contract
drift · undocumented behavior change · security-sensitive ·
compliance-impacting · operational (deploy/CI/infra) · local setup or
deployment changed · app docs invalidated**. A flagged class blocks merge
until the reviewer explicitly resolves it — you may not waive your own flag.
Periodic sweeps: `/e22-drift`, `/e22-audit`.

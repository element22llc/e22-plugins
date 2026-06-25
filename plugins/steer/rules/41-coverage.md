<!-- steer:inject-when=code-project -->
## Coverage rules

- Coverage is a **signal to find untested behavior, not a target to hit** — never
  write shallow tests, or relax assertions, to move a number.
- **Cover what you touch:** new and changed code paths ship exercised. Prioritize
  **critical paths, branches, and error handling** over blanket line %.
- Coverage is **measured and visible every run** (per-stack tooling in `CONVENTIONS`).
  A coverage drop on changed code is **drift** — surface it for human review, never
  silently (see Drift gates).
- No global "fail under N%" vanity gate; CI gates only **changed-line** coverage. The
  reviewer judges adequacy (see You are not the gate).

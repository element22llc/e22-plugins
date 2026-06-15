---
description: "Read-only workspace navigator — reconstruct the whole E22 workspace state (branch/PR, /spec feature status, open questions, Proposed ADRs, tracker issues, work claims, version drift) and arbitrate the single best next action across all workflows using the shared categories + safety precedence. Never edits, commits, publishes, merges, or advances state."
---

Find the single best next action across this whole workspace by following the
`e22-next` skill.

`/e22-next` is the cross-workflow counterpart to each skill's
`## Recommended next actions` block: where every workflow skill recommends only
from its own invocation (the locality rule), `/e22-next` reconstructs the
**entire** workspace state cold — branch/PR, `/spec` feature `Status`, open
questions (`impact`/`required_before`), `Proposed` ADRs, tracker issue lifecycle
states, work claims, and `spec/.version` drift — then arbitrates the **one**
action that matters most using the shared categories + safety precedence from
`templates/reference/NEXT-ACTIONS.md`.

If there is no `/spec` spine, the only action is to bootstrap (`/e22-init`
greenfield, or `/e22-adopt` for existing code) — say which and stop. Otherwise
emit a short state-reconstruction summary, then the standard
`## Recommended next actions` block ending in a single `Current recommended
action`. It recommends and routes to the owning skill; it never resolves a state
itself, makes edits, or commits.

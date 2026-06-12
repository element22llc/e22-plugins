---
description: Brainstorm and iterate a feature's spec (intent.md + contract.md where behavior demands it) and drive its open questions to resolution — without writing any code. The no-build counterpart to /e22-build; ends at an approved intent, never touches /apps or /packages.
---

Design a feature's spec by following the `e22-spec` skill.

Ask for a kebab-case feature `[id]`; resume `spec/features/[id]/` if it exists,
else scaffold `intent.md` (and `contract.md` only when behavior/data/API surface
is in play) from the bundled templates. Brainstorm the intent interactively in
plain user-facing language — problem, users, outcome, acceptance criteria —
parking unknowns under `## Open questions` and never inventing answers. Sweep
those questions to resolution (the `/e22-questions` loop). Get PO approval on the
intent. Then stop: offer `/e22-tracker-sync push` to file a tracker item, or hand
to a dev for implementation in a separate session. **Write no code** — never
create or edit anything under `/apps` or `/packages`; if asked to build, point to
`/e22-build` instead.

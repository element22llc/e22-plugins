## Context hygiene — delegate heavy runs, keep state in files

Long, multi-phase work bloats the session and risks losing task constraints at
compaction. You cannot see context usage or trigger `/compact` — only the user
can — so keep the working context lean.

- **Delegate heavy runs to a subagent** (a fresh context window) and bring back
  only the structured result, not the whole sweep — how `/steer:audit` fans out
  to `steer-reviewer` and `/steer:work --reviewed` runs its plan gate.
- **Keep durable state in files, not the chat.** Run-state and task-specific
  constraints (decisions made, what to skip, what's unreliable) go in
  `/spec/**` or a sidecar artifact the work re-reads — files survive compaction
  and a fresh session; chat history does not (`/steer:build` →
  `BUILD-STATUS.md`, `/steer:work` → its work marker).
- **Don't offer to save findings to session memory** — private auto-memory is
  invisible to the repo, the PR, and every teammate. Route each fact to its
  canonical home by type: a **bug fix** → a regression test; an **operational
  or behavioral fact** → the app guide / `/spec/HISTORY.md`; an **unresolved
  follow-up** → a linked tracker issue; a **durable design decision** → the
  spine. One home per fact — surface the capture, don't ask whether to
  remember it.
- **Only when the thread is genuinely overloaded** and delegation won't help,
  *recommend* the user `/compact` or a fresh session, pre-composing the
  hand-off (the artifact path + the constraints to carry) — and say plainly it
  is a recommendation you cannot perform yourself.

Full pattern and a worked example: `/steer:reference context-hygiene`.

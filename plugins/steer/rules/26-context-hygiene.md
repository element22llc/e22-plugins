## Context hygiene — delegate heavy runs, keep state in files

Long, multi-phase work bloats the session and risks losing task constraints when
context compacts. You **cannot** see context usage, trigger `/compact`, or start a
new session — only the user can. So don't wait to be rescued by a fresh session;
keep the working context lean instead.

- **Delegate heavy runs to a subagent.** When a run is long, multi-phase, or would
  crowd this context with search output or intermediate transcript, do it in a
  **subagent** — it gets a fresh context window by construction — and bring back
  only the structured result, not the whole sweep. This is how `/steer:audit` fans
  out to the `steer-reviewer` agent and `/steer:work --reviewed` runs its plan gate.
- **Keep durable state in files, not the chat.** Run-state and task-specific
  constraints (decisions made, what to skip, what's unreliable) go in `/spec/**` or
  a sidecar artifact the work re-reads — never only in conversation prose. Files
  survive compaction and a fresh session; chat history does not. `/steer:build`
  tracks flow in `BUILD-STATUS.md`, `/steer:work` in its work marker — follow that.
- **Only when the thread is genuinely overloaded** with unrelated context and
  delegation won't help, *recommend* the user `/compact` or start a fresh session —
  and pre-compose the hand-off (the artifact path + the constraints to carry).
  Say plainly it is a recommendation you cannot perform yourself.

Full pattern and a worked example: run `/steer:reference context-hygiene`.

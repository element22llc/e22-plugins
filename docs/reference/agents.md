# Subagents reference

`steer` ships one subagent under `plugins/steer/agents/`. It is a **read-only
worker**, not a new capability — it grants no authority the calling skill didn't
already have, and its tool allowlist is strictly narrower.

!!! note "Why a shipped subagent at all"
    The read-heavy review skills (`/steer:audit`, `/steer:audit spec`) sweep a whole
    repo across many independent slices. On a large repo that work both crowds
    the main context and benefits from running in parallel. A shipped subagent
    lets those skills **fan out explicitly** — one isolated worker per slice —
    while *enforcing* read-only behaviour during the fan-out, which loose
    "spawn a subagent" prose cannot guarantee.

## `steer-reviewer`

A read-only reviewer invoked **explicitly** by `/steer:audit` (one per audit
dimension), `/steer:audit spec` (one per feature diff), `/steer:work --reviewed` (the
optional code-gate standards check), and the `/steer:loop` scaffolded workflow (rule
`53-autonomous-loops`' split-ideation-from-verification step — the drafting agent
never clears its own change) when inline review would crowd the main
context — for the two audit modes that means a size threshold, for
`--reviewed` a spec/standards-sensitive repo, and for the loop it is unconditional. It analyzes one bounded slice in its own context window
and returns a compact, `path:line`-evidenced findings summary; the calling skill
vets, ranks, and routes what it returns.

| Field | Value |
| :---- | :---- |
| **Tools** | `Read`, `Grep`, `Glob` — read-only by construction (no shell, no edits, no writes, no tracker) |
| **Model** | `inherit` (matches the lead's model for finding quality; can be switched to a cheaper tier as a cost lever) |
| **Invocation** | Explicit, by the calling skill — never auto-delegated |

### Design notes

- **Explicit invocation, not auto-delegation.** An earlier auto-delegating
  analyzer was trialed and removed because it never fired reliably in practice.
  `steer-reviewer` is named directly in the `audit` (code + spec modes), `work`
  (`--reviewed`) and `loop` skill bodies — and in the scaffolded
  `steer-loop.yml` prompt — so the fan-out is deterministic rather than
  dependent on description matching.
- **Read-only is enforced, not requested.** The `Read`/`Grep`/`Glob` allowlist
  omits `Bash`, so there is no shell mutation path. This is a genuine filter, unlike the
  turn-scoped `disallowed-tools` the calling skills declare; it holds the fan-out
  to the same read-only contract by a stronger mechanism. See
  the [Authorization model](../concepts/authorization-model.md).
- **Cost-gated.** In `/steer:audit`'s `code` and `spec` modes the fan-out is
  size-gated: below it, the skill reviews inline and the subagent is never
  spawned — the coordination and token overhead only pays off on large sweeps.
  `/steer:work --reviewed` gates on kind rather than size, spawning the reviewer
  for spec/standards-sensitive repos.
- **Plugin-scoped limits.** Plugin subagents ignore the `hooks`, `mcpServers`,
  and `permissionMode` frontmatter fields by design; `steer-reviewer` uses none
  of them.

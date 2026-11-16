# Subagents reference

`steer` ships two subagents under `plugins/steer/agents/`. Each is a
**read-only worker**, not a new capability - it grants no authority the calling
skill didn't already have.

!!! note "Why a shipped subagent at all"
    The read-heavy review skills (`/steer:audit`, `/steer:audit spec`) sweep a whole
    repo across many independent slices. On a large repo that work both crowds
    the main context and benefits from running in parallel. A shipped subagent
    lets those skills **fan out explicitly** - one isolated worker per slice -
    while *enforcing* read-only behaviour during the fan-out, which loose
    "spawn a subagent" prose cannot guarantee.

## `steer-reviewer`

A read-only reviewer invoked **explicitly** by `/steer:audit` (one per audit
dimension), `/steer:audit spec` (one per feature diff), and `/steer:work --reviewed` (the
optional code-gate standards check) when inline review would crowd the main
context - for the two audit modes that means a size threshold, for
`--reviewed` a spec/standards-sensitive repo. It analyzes one bounded slice in its own context window
and returns a compact, `path:line`-evidenced findings summary; the calling skill
vets, ranks, and routes what it returns.

| Field | Value |
| :---- | :---- |
| **Tools** | `Read`, `Grep`, `Glob` - read-only by construction (no shell, no edits, no writes, no tracker) |
| **Model** | `inherit` (matches the lead's model for finding quality; can be switched to a cheaper tier as a cost lever) |
| **Invocation** | Explicit, by the calling skill - never auto-delegated |

### `steer-reviewer` design notes

- **Explicit invocation, not auto-delegation.** An earlier auto-delegating
  analyzer was trialed and removed because it never fired reliably in practice.
  `steer-reviewer` is named directly in the `audit` (code + spec modes) and
  `work` (`--reviewed`) skill bodies, so the fan-out is deterministic rather than
  dependent on description matching.
- **Read-only is enforced, not requested.** The `Read`/`Grep`/`Glob` allowlist
  omits `Bash`, so there is no shell mutation path. This is a genuine filter, unlike the
  turn-scoped `disallowed-tools` the calling skills declare; it holds the fan-out
  to the same read-only contract by a stronger mechanism. See
  the [Authorization model](../concepts/authorization-model.md).
- **Cost-gated.** In `/steer:audit`'s `code` and `spec` modes the fan-out is
  size-gated: below it, the skill reviews inline and the subagent is never
  spawned - the coordination and token overhead only pays off on large sweeps.
  `/steer:work --reviewed` gates on kind rather than size, spawning the reviewer
  for spec/standards-sensitive repos.
- **Plugin-scoped limits.** Plugin subagents ignore the `hooks`, `mcpServers`,
  and `permissionMode` frontmatter fields by design; `steer-reviewer` uses none
  of them.

## `steer-pr-reviewer`

A diff reviewer invoked **explicitly** by `/steer:work`: the per-PR reviewer in
`review`, each specialist lens (database, UI, security) in the code gate, and
every refute-pass verifier. It scores one diff against the
[`REVIEW-LOOP.md`](https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/templates/reference/REVIEW-LOOP.md)
section 4 rubric and returns the card the caller asked for.

| Field | Value |
| :---- | :---- |
| **Tools** | `Read`, `Grep`, `Glob`, `Bash` - `Bash` for `git` and `gh` reads; read-only by its instructions, not by construction |
| **Model** | `sonnet` - a bounded check on a mid tier; the plan gate and the code gate's general reviewer keep the session model |
| **Turn cap** | `maxTurns: 60`, under a prose budget of about 40 tool calls |
| **Invocation** | Explicit, by the calling skill - never auto-delegated |

### Why it differs

- **Diff-first.** It reads the diff and PR description, and leaves them only to
  answer a question the diff raises. A reviewer's cost is turns times context,
  so scope matters as much as tier.
- **Delta re-review.** Given its previous card and head SHA, it reviews only
  the commits since and settles each earlier finding.
- **Attributable cost.** Named, the reviewers show under steer in `/usage`
  instead of as `general-purpose` subagents inheriting the session model.
- **Not `steer-reviewer`.** That agent has no shell and audits on-disk code
  against the standards; this one needs git to read a diff.

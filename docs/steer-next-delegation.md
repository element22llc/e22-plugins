# `/steer:next` analysis delegation — status & runtime validation

`/steer:next` stays the **inline** intent owner; it delegates only bounded,
read-only repository analysis to the `steer-analyzer` subagent
(`plugins/steer/agents/steer-analyzer.md`). This note records what is verified,
the known limitation, and the validation still pending. It is **experimental and
fallback-safe**: any incomplete delegation deterministically reverts to the inline
reconstruction, so it can be removed at any time with no behavior change.

## Design (why this shape)

A `context: fork` would sever conversation history, dropping prior-turn
constraints (e.g. "don't recommend infra changes" stated before a bare
`/steer:next`). So the parent runs inline, collects `$ARGUMENTS` + prior-turn
constraints + git/PR/CI/tracker state, and passes them in a delegation envelope.
The analyzer (`Read`/`Grep`/`Glob` only — read-only by construction) returns
evidence-backed candidates; the parent applies constraint precedence and
arbitrates. The contract is pinned by `check_fixtures.py::check_next_delegation`
and the `next-delegation-fixtures/` golden fixtures.

## Verified (managed-repo, headless `claude -p --plugin-dir`)

- **Read-only / authorization:** zero file mutations across runs; repo HEAD and
  working tree unchanged; the analyzer carries no shell or edit tools.
- **Analyzer invoked & wired:** `subagent_type: steer:steer-analyzer` observed;
  `${CLAUDE_PLUGIN_ROOT}` resolves inside the flow.
- **Constraint propagation + honoring:** a constraint stated in a prior turn (not
  in `$ARGUMENTS`) reached the envelope and was honored — the constrained-out
  candidate was flagged, not silently dropped, and an allowed action recommended.
- **Quality ≥ inline:** correct on every dimension; surfaced a real spec↔code gap.
- **Graceful fallback:** incomplete delegation fell back to inline and said so;
  never fabricated output.

## Known limitation — context reduction NOT proven

In **headless `claude -p`**, the analyzer's complete report returned to the parent
in only a minority of runs; the rest fell back to inline (so the run did the full
reconstruction anyway — no context saving). This is **not** a supported execution
mode (`/steer:next` is interactive-first), and the headless results are confounded
(subagent-resume tooling differs in print mode; permission friction degraded some
analyzer runs). It does not affect correctness or safety — only the efficiency
benefit, which therefore remains **unproven**.

## Pending — authenticated interactive validation (post-merge)

Run 5 consecutive interactive `/steer:next` invocations in a managed repo
(`claude --plugin-dir <…>/plugins/steer`): 3 bare, 1 with an arg constraint, 1
two-turn prior-constraint. Per run confirm: analyzer invoked · complete report
returned · parent used it · no inline fallback · constraints preserved · no repo
mutation. **Keep** the feature if delegation is reliable enough to give meaningful
context savings. **Revert** for any correctness, constraint-preservation,
authorization, mutation, or fallback failure; if it merely falls back too often,
weigh the optimization against its complexity and remove it if it does not pay.

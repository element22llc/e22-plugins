---
type: tool_used
tool: Skill
input_match: 'steer:(sync|setup)\b'
arm: both
weight: 3
---

The run must actually **enter** `sync`, or the `setup` front door whose routing
table sends the `openspec` state there - asserted on the `Skill` tool call, not
on the prose.

`last_message` was the wrong surface for this claim. `rules/00-router.md` says
"announce, then act": the announcement lands in the *first* message and the
finished skill's report names the skills that come *next*, so a run that routed
perfectly usually does not repeat the skill's own name at the end.

Entering is only half of what this case measures, and the weaker half: the
misroute it regresses (#578) was a run that routed to `sync` correctly and was
then turned away by sync's own entry gate, which admitted `damaged` and
`managed` only. This grader passes on either side of that fix. The `answer`
grader is the one that fails a response that bounces back to `setup`.

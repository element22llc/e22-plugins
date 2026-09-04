---
type: tool_used
tool: Skill
input_match: 'steer:work\b'
arm: both
weight: 3
---

The run must actually **enter** `work` — asserted on the `Skill` tool call, not
on the prose.

`last_message` was the wrong surface for this claim. `rules/00-router.md` says
"announce, then act": the announcement lands in the *first* message and the
finished skill's report names the skills that come *next*, so a run that routed
perfectly usually does not repeat the skill's own name at the end. In the v6.1.0
run 15 of 24 with-plugin runs failed this grader while the `answer` judge passed
them unanimously, and the one run that scored full marks did so because it was
killed right after its announce line. That measured message shape, not routing.

A tool call is not the same mistake as grading the trace. The objection to
`target: trace` is that the always-on ruleset names every skill, so any skill
matches somewhere in the injected text — but an invocation is an **action** the
run took, and it is absent from the no-plugin arm by construction. `arm: both`
therefore keeps this grader scored in both arms: the baseline has no steer
skills to invoke, so the delta stays attributable to the plugin.

Whether the response *reads* as correctly routed is the `answer` grader's job.

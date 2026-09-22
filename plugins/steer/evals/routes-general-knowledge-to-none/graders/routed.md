---
type: tool_used
tool: Skill
input_match: 'steer:'
min: 0
max: 0
arm: both
weight: 3
---

The inverse of every other case in this suite: the run must **not** enter a
steer skill. `min: 0` with `max: 0` is what asserts a tool was never called -
`min` defaults to 1, so leaving it out would assert the opposite.

A routing surface is only as good as what it declines to claim. Rule
`00-router` tells the model to map a plain-language goal to the owning skill and
invoke it without being asked, which is exactly the instruction that overfires:
an ask that no skill owns gets pulled into the nearest one, and the user pays
for a workflow they did not want. Nothing else in this suite can catch that -
every positive case rewards entering a skill.

`arm: both` keeps the grader scored in both arms. The baseline has no steer
skills to invoke, so it passes this grader by construction and the delta is
**bounded above by zero**: a healthy negative case scores level, and a negative
delta is the plugin misrouting. Read it that way, not as a case that "proves
nothing" because both arms pass.

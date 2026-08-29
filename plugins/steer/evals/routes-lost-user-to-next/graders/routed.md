---
type: regex
target: last_message
pattern: "steer:next\\b"
match: contains
weight: 3
---

The response must reach the `next` skill for this ask — by invoking it, or by
naming it as the owner of the ask when a decision is needed from the user first.

This is the assertion `check_routing_fixtures.py` cannot make. That gate proves the
signal vocabulary for this ask still appears in the always-on routing surface; it
cannot prove the ask *arrives*. The no-plugin baseline arm has no steer skills at
all, so a pass here is attributable to the plugin, not to a lucky guess.

Graded on `last_message`, never the trace: `rules/00-router.md` is injected into
every session and names every skill, so any skill matches somewhere in a trace.
Grading the trace would measure whether the rules loaded, not where the ask went.

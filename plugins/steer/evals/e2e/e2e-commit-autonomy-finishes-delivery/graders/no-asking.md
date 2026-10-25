---
type: llm
focus: last_message
weight: 2
---

Commit autonomy: the run commits, pushes and opens the PR without pausing to
ask permission, despite any default to do so only when asked.

Pass if the response reports the delivery - a commit, a push, an opened PR -
as done. Mentioning that merging waits for a human is correct.

Fail it if it stops to ask whether to commit, push or open the PR, or ends by
offering to do any of those instead of having done them.

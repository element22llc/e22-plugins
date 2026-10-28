<!-- steer:inject-when=code-project -->
## Issue tracker integration (client-agnostic)

Products use whatever tracker the client has (Jira, GitHub Issues, Linear,
Azure DevOps, ...). **`/spec/tracker.md`** declares the system and ref format -
read it before referencing work items; if missing, ask and create it from the
bundled template, **except in a polyrepo member**, where the tracker is the
workspace's. Refs live in the `> Tracker:` line of an `intent.md` or ADR, the PR
description, and a `/spec/history/` entry's `Refs:`. Copy a tracker item's
acceptance criteria into the intent: the spec is the in-repo source of truth and
the ref points back.

**A question stays in the spec's `## Open questions`** (structured `Q-NNN`) when
it is local to one feature and answerable while specifying it; **promote it to
an issue** when it needs a named owner, blocks several features, needs
stakeholder or research input, or could outlive the session - then put the ref
in the question's `tracker:` field. The issue is the decision *workflow*; the
spec or an ADR is the durable *record*.

A tracker other than GitHub Issues uses the manual export.

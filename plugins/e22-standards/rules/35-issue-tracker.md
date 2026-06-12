## Issue tracker integration (client-agnostic)

Products use whatever tracker the client has (Jira, GitHub Issues, Linear,
Azure DevOps, …). **`/spec/tracker.md`** declares the system + ref format —
read it before referencing work items; if missing, ask and create it from the
bundled template. Refs live in `intent.md`'s `> Tracker:` line, the PR
description (tracker's own linking syntax), and `HISTORY.md` `Refs:`. Copy a
tracker item's acceptance criteria into the intent — the spec is the in-repo
source of truth; the ref points back. Questions not yet tracked externally →
`## Open questions`; promote to a tracker item when they need scheduling or an
external owner, then replace the question with the ref.

When the tracker is **GitHub Issues**, `/e22-tracker-sync` automates this
boundary both ways — pull issues into the markdown export `/e22-drift` consumes,
or push `spec-drift` issues and promoted questions back out (MCP-first, `gh`
fallback). It's a GitHub accelerator only; other trackers use the manual export.

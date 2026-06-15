## Issue tracker integration (client-agnostic)

Products use whatever tracker the client has (Jira, GitHub Issues, Linear,
Azure DevOps, …). **`/spec/tracker.md`** declares the system + ref format —
read it before referencing work items; if missing, ask and create it from the
bundled template. Refs live in `intent.md`'s `> Tracker:` line, the PR
description (tracker's own linking syntax), and `HISTORY.md` `Refs:`. Copy a
tracker item's acceptance criteria into the intent — the spec is the in-repo
source of truth; the ref points back. **Keep a question in the spec's
`## Open questions`** (structured `Q-NNN`) when it's local to one feature and
answerable while specifying it; **promote it to an issue** when it needs a named
owner, blocks multiple features, needs stakeholder/research input, or could
outlive the session — then put the ref in the question's `tracker:` field. The
issue is the decision *workflow*; the spec (or an ADR) is the durable *record*.

When the tracker is **GitHub Issues**, **`/e22-issues`** is the high-level
lifecycle workflow (capture → triage → brainstorm → materialize → decompose →
status → reconcile), and **`/e22-tracker-sync`** is the low-level gateway it
routes all reads/writes through (MCP-first → `gh` → manual floor). Agent-authored
issues follow the machine-readable contract (stable headings + hidden markers);
`/spec` stays product truth, the issue is the work/decision layer. Other trackers
use the manual export.

<!-- steer:inject-when=tracker-github -->
## Issue-first (GitHub-adopted repos)

When `/spec/tracker.md` declares `system: github`, every
**implementation-affecting mutation** — code, config, infrastructure, or
behavior — has a GitHub issue **before the first repository mutation**. Out of
scope (no issue needed): `/spec` edits, documentation, generated output,
lockfiles, and a plugin-maintenance `/steer:sync` on its own `feat/sync`
branch (structural, never app source). Reuse the issue the user names;
otherwise find-or-create one through `/steer:tracker-sync` — an explicit
"fix / implement / add / create" request does **not** need confirmation to
create the issue.

- **Capture-only and ambiguous language do not auto-create.** "Note this" /
  "we should eventually…" is captured deliberately, never inferred into a
  batch of issues. A large inferred batch takes one confirmation;
  security-sensitive public disclosure takes human review.
- **Implementation runs through `/steer:work`** — claim, branch, implement,
  test, open the PR, transition the issue. Commit, push, and the PR are
  autonomous under Commit autonomy; **merge and deploy are never implied**.
- **Solo trunk keeps the issue, drops the branch/PR** (Commit autonomy) —
  close it **from the trunk commit** (`Closes #N`). The issue stays the
  audit-evidence anchor (Audit-aligned delivery).
- **Discovered out-of-scope work** gets its own linked issue
  (related/blocking), not silent scope creep in the current one.
- The scaffold pre-authorizes `gh issue create` / `gh issue edit` under
  `allow`; the MCP write tools (`mcp__github__issue_write` /
  `sub_issue_write`) sit under `ask`, but `/steer:tracker-sync` and
  `/steer:report` re-grant them via their own `allowed-tools`. A create that
  is *still* blocked is a **host-permission gate, not a missing issue** —
  don't loop retrying; confirm with the user, or have them run
  `!gh issue create …` under their own identity, then continue. (Full
  rationale: ISSUE-WORKFLOW.md → "Host gating".)

Non-GitHub trackers and repos without a `/spec` spine keep today's flow.
**Calling work a "prototype" does not waive it** — the only durable opt-out
from the per-feature branch/PR is solo-trunk delivery mode.

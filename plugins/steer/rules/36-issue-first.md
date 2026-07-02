<!-- steer:inject-when=tracker-github -->
## Issue-first (GitHub-adopted repos)

When `/spec/tracker.md` declares `system: github`, every **implementation-affecting
mutation** — code, config, infrastructure, or behavior — has a GitHub issue
**before the first repository mutation**. This is scoped to implementation:
editing the `/spec` spine, documentation, generated output, and lockfiles is
*not* an implementation-affecting mutation and needs no issue — nor is a
plugin-maintenance sync (`/steer:sync`), which reconciles the materialized spine
+ scaffold against the plugin's own templates on its own `feat/sync` branch
(structural, not feature work; it never touches app source). Reuse the issue
the user names; otherwise find-or-create one through
`/steer:tracker-sync` — an explicit "fix / implement / add / create"
request does **not** need confirmation to create the issue.

- **Capture-only and ambiguous language do not auto-create.** "Note this", "we
  should eventually…", or open-ended discussion is captured deliberately, never
  inferred into a batch of issues. A large inferred batch of unrelated issues
  takes one confirmation; security-sensitive public disclosure takes human review.
- **Implementation runs through `/steer:work`** — claim, branch, implement, test,
  open the PR, transition the issue. The CLI request authorizes local edits +
  tests; commit/push/PR follow Commit autonomy; **merge and deploy are never
  implied**.
- **Solo trunk keeps the issue, drops the branch/PR** (Commit autonomy): issue-first
  still holds — every implementation-affecting mutation has a GitHub issue — but you
  close it **from the trunk commit** (`Closes #N`), with no `issue/<N>` branch or
  per-feature PR. The issue stays the audit-evidence anchor (Audit-aligned delivery).
- **Discovered out-of-scope work** during implementation gets its own linked
  issue (related/blocking), not silent scope creep in the current one.
- **The scaffold pre-authorizes the `gh` issue-create verbs** (`gh issue create` /
  `gh issue edit`) under `allow`, so find-or-create normally runs
  without a prompt. The MCP write tools (`mcp__github__issue_write` /
  `sub_issue_write`) sit under `ask` for a least-privilege posture, but the
  `/steer:tracker-sync` and `/steer:report` skills re-grant them via their own
  `allowed-tools`, so the governed find-or-create path stays silent within those
  skills. A create that is *still* blocked (a stricter host permission
  mode, or a background-job gate) is a **host-permission gate, not a missing
  issue** — don't loop retrying; confirm with the user, or have them run
  `!gh issue create …` under their own identity, then continue the bounded action
  set. (Full rationale: ISSUE-WORKFLOW.md → "Host gating".)

Non-GitHub trackers and repos without a `/spec` spine keep today's flow.
**Calling work a "prototype" does
not waive it** — the only durable opt-out from the per-feature branch/PR is
declaring solo-trunk delivery mode; a prototype that stays in PR flow still gets a
GitHub issue per change.

## Issue-first (GitHub-adopted repos)

When `/spec/tracker.md` declares `system: github`, every requested code, config,
infrastructure, or behavior change has a GitHub issue **before the first
repository mutation**. Reuse the issue the user names; otherwise find-or-create
one through `/e22-tracker-sync` — an explicit "fix / implement / add / create"
request does **not** need confirmation to create the issue.

- **Capture-only and ambiguous language do not auto-create.** "Note this", "we
  should eventually…", or open-ended discussion is captured deliberately, never
  inferred into a batch of issues. A large inferred batch of unrelated issues
  takes one confirmation; security-sensitive public disclosure takes human review.
- **Implementation runs through `/e22-work`** — claim, branch, implement, test,
  open the PR, transition the issue. The CLI request authorizes local edits +
  tests; commit/push/PR follow Commit autonomy; **merge and deploy are never
  implied**.
- **Discovered out-of-scope work** during implementation gets its own linked
  issue (related/blocking), not silent scope creep in the current one.

Scope: this rule applies only to GitHub-adopted repos. Non-GitHub trackers and
repos without a `/spec` spine keep today's flow.

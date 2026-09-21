<!-- steer:inject-when=tracker-github -->
## Issue-first (GitHub-adopted repos)

Where `/spec/tracker.md` declares `system: github` - in a polyrepo member that
file is the **workspace's** - an issue exists **before the first repository
mutation** in exactly two cases:

- **High-risk work** (Change classification), and
- **any of the six value cases**: a planned feature, a tracked bug, work
  spanning more than one session, work coordinated between people, a product
  decision or acceptance to record, or a follow-up discovered along the way.

Everything else - a Trivial change, an ordinary Behavioral fix nobody is
tracking, `/spec` edits, documentation, generated output, lockfiles - needs no
issue: **the PR is the work record**. Reuse the issue the user names, else
find-or-create one through `/steer:tracker-sync`; an explicit "fix / implement /
add" request needs no confirmation to create it.

- **Capture-only and ambiguous language do not auto-create.** "Note this" / "we
  should eventually..." is captured deliberately, never inferred into a batch; a
  large inferred batch takes one confirmation, and security-sensitive public
  disclosure takes human review.
- **Implementation runs through `/steer:work`** - claim, branch, implement,
  test, open the PR, transition the issue. **Solo trunk keeps the issue and
  drops the branch/PR**: close it from the trunk commit (`Closes #N`), since the
  issue is the audit-evidence anchor.
- **Discovered out-of-scope work** gets its own linked issue, not silent scope
  creep in the current one. The issue's `steer:state` reflects reality - work in
  progress is `validate`, never `done` - and the PR references it with the
  correct closing relation.
- A tracker write your host blocks is a **host-permission gate, not a missing
  issue**: don't loop retrying; confirm with the user, or have them run
  `!gh issue create ...` themselves, then continue.

**Calling work a "prototype" does not waive this.** The only durable opt-out
from the per-feature branch/PR is solo-trunk delivery mode.

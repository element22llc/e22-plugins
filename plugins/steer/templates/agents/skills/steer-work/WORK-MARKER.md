# `/steer-work` - the local work-marker file format

Read this file at `start` (pr-flow only) before writing
`spec/.work/<branch>.md`, at `resume` before reading it, and at `finish` for
Removal. Solo-trunk writes no marker. Branch naming, concurrency, and the
guardrails stay in `SKILL.md`.

## Marker format

The marker is a small Markdown file. The `issue:` / `branch:` lines are written
once and never rewritten; the session list under the heading is the single source
of truth for "which Claude Code session(s) worked this branch" - the head is the
most recent. The Stop hook keeps that head current each turn, and `resume` reads
it (`modes/subcommands.md` -> `resume`). Session ids are local breadcrumbs and **never** go into tracker
metadata.

```markdown
# Work marker - issue 123

- issue: 123
- branch: issue/123-export-fix

## Claude Code sessions (newest first)

- 64ae4a08-7069-4810-8cd0-d443c8511365
```

Seed the first session id from `$CLAUDE_CODE_SESSION_ID` (fail-open: if it is
empty, write the marker without a session bullet - its existence still governs).
The session heading + list must be the **last** block in the file. If a legacy
extensionless `spec/.work/<branch>` marker exists, upgrade it: carry over any
`issue`/`branch` it records, write the new `.md` file, then remove the old one.

## Removal

Nothing in git prunes `spec/.work/`, so this skill does. At `start`, `resume`
and `finish`, read the issue of every marker in the directory with one batched
`get` through `/steer-tracker-sync`, and delete each marker whose issue is
**closed** - whatever the closure reason, and every marker that issue holds (one
per branch cut for it). Delete only on that tracker read: a marker whose issue
is open stays, and so does one whose issue cannot be read or resolved. `status`
mutates nothing, so it reports stale markers instead of deleting them. The
workspace snapshot already hides a marker whose branch is gone; that is display,
not removal.

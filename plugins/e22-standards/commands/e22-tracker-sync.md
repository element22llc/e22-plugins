---
description: "Bidirectional GitHub Issues sync for the /spec spine — PULL issues into the markdown export /e22-drift consumes (or import acceptance criteria into an intent), or PUSH spec-drift issues, promoted open questions, and feature requests out. GitHub-only accelerator: MCP-first, gh CLI fallback, manual export floor. Moves pointers and findings, never the spec itself."
---

Sync this product's `/spec` spine with GitHub Issues by following the
`e22-tracker-sync` skill.

First read `/spec/tracker.md`: if the tracker is **not** GitHub Issues, print the
manual paste/path export instructions and stop. Otherwise detect capability —
prefer the GitHub MCP tools (shipped in `scaffold/mcp.json`), fall back to `gh`
CLI (`gh issue list --json`, `gh issue create --body-file`), then to manual
export. Then run the requested mode:

- **issue `<op>`** — the generic tracker-metadata gateway `/e22-issues` and
  `/e22-work` call: `search` · `get` · `find-or-create` · `create` · `update`
  (managed block only) · `comment` · `set-type` (capability-degrading) · `label`
  · `transition` · `assign/claim` · `link-parent` · `link-pr` · `close/reopen` ·
  `add-to-project`. Tracker metadata only — **never** git or PR delivery.
- **pull** — materialize issues as one-markdown-file-per-issue for `/e22-drift`,
  or import an issue's acceptance criteria into a feature's `intent.md`
  (append/merge, set `> Tracker:`, never clobber prose).
- **push** — file `spec-drift` issues from a drift run, promote a
  `## Open questions` entry to an issue (then replace it with the ref), or open a
  feature-request issue from an approved intent.

Pushes are idempotent (dedup against existing issues) and need one confirmation
before the first create. Never edit `/apps`, `/packages`, or `contract.md`
behavior — this skill moves pointers and findings only.

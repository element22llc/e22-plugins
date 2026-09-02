# `/steer-tracker-sync` — relationship operations (parent, related, blocked-by)

Read this file **only when** you are about to perform one of the operations it
lists: `link-parent`, `link-related`, `link-blocked-by`. (`link-pr` is a core
op and stays in `OPERATIONS.md`.) The API boundary, the integration ladder and
the core lifecycle ops are in
[`OPERATIONS.md`](OPERATIONS.md) and
bind everything here — in particular the rule that **only the queries and
mutations these files enumerate** may be issued.

Two invariants span all three ops: **one representation only** (a native edge
and a managed-block line for the same pair are never both written), and a link
**informs** ranking or a human decision but never sets `steer:state` or closes
an issue on its own.

## Operations

- **`link-parent #N <parent>`** — native sub-issue link, else `steer:parent-issue`.
**Tier-agnostic:** the same op links a Feature under an Epic and a Task under a
Feature — each is one single-parent edge, so an `Epic → Feature → Task` hierarchy
is built by linking each hop. The marker fallback is single-valued (one direct
parent per issue), which holds for every hop of the chain.

- **`link-related #N <other> <relationship>`** — record a non-hierarchical
  connection between two issues. `<relationship>` is an `issue_relationship` value
  (`relates-to` · `depends-on` · `blocks` · `conflicts-with` · `supersedes` ·
  `superseded-by` — see `ENUMS.md`); reject anything outside the enum. For
  **`depends-on`/`blocks`**, prefer the native relationship via `link-blocked-by`
  (below) when available — it is board-visible and feeds ranking. Otherwise (and
  for the relationship types GitHub has no native form for —
  `relates-to`/`conflicts-with`/`supersedes`), this writes the link as a
  managed-block `Related issues` line (`#<other> — <relationship> (why)`) on `#N`
  per `ISSUE-SCHEMA.md` — the `#<other>` mention makes GitHub
  auto-create the backlink. **Reciprocity is the caller's choice:** by default
  record the symmetric line on `<other>` too (`relates-to`/`conflicts-with` are
  symmetric; `depends-on`↔`blocks` and `supersedes`↔`superseded-by` invert), but
  only when permitted to write that issue's managed block. Idempotent — a line for
  the same `(other, relationship)` pair is updated in place, not duplicated.
  **Never** reclassify or close either issue: a `conflicts-with`/`supersedes` link
  is surfaced for a human, not acted on.

- **`link-blocked-by #N <blocker>`** — record a **native** GitHub issue
  dependency (`#N` is blocked by `#blocker`; the reciprocal "blocks" edge is
  created by GitHub automatically). Native relationships have no `gh issue`
  subcommand — use the blocked-by add/remove mutations via `gh api graphql` (issue
  **node id**, not number), else the MCP equivalent if it exposes them. **Capability-degrading:** where native issue
  relationships are unavailable, fall back to `link-related #N <blocker>
  depends-on`. **One representation only:** when the native edge is written, do
  **not** also add a managed-block `depends-on`/`blocks` line for the same pair —
  the native edge is canonical, the marker is the fallback (this avoids
  double-counting in ranking; see `ISSUE-SCHEMA.md`). Idempotent. A blocked-by edge
  **informs** ranking and may *suggest* `steer:state=blocked`, but **never sets**
  it — `steer:state` stays canonical and a transition is the caller's decision.

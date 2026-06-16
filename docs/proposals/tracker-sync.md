# Proposal — `/steer:tracker-sync` (GitHub Issues pull/push)

> Status: draft for dev review · Target plugin version: 1.37.0
> Companion: [`spec`](./spec.md)

## Problem

The plugin treats the tracker as a **pointer**, with `/spec` as the source of
truth — correct, but today the GitHub link is **entirely manual**:

- `/steer:drift` consumes a "tracker spec export" the dev must **paste into chat or
  hand-export to a directory.** No API pull.
- `/steer:drift` *says* it "opens `spec-drift`-labelled issues" and
  `/steer:questions` *says* it promotes questions to tracker items — but **no skill
  hard-codes a single `gh` or issue-creation call.** Those steps are
  model-improvised, so they're inconsistent and often skipped.

This skill is the **GitHub accelerator** that removes the manual friction in both
directions, while preserving the client-agnostic floor for non-GitHub trackers.

## Integration approach (decided)

**MCP-first → `gh` CLI fallback → manual export floor.**

- The org already ships GitHub MCP in every repo via `scaffold/mcp.json`
  (`api.githubcopilot.com/mcp/`, `GITHUB_PAT`). Prefer those tools — they take
  JSON `body` fields, so **creating issues with multi-line markdown bodies is
  clean** (no shell escaping).
- If MCP tools aren't loaded this session (no `GITHUB_PAT`, server down,
  Cowork/desktop), fall back to `gh` CLI (`gh issue list --json …`,
  `gh issue create --body-file …`).
- If neither is available **or the tracker isn't GitHub** (read
  `/spec/tracker.md`), fall back to the existing manual paste/path export. This
  skill is a GitHub *accelerator*, not a new universal path.

### Capability detection (codified, in order)

1. Read `/spec/tracker.md` → confirm `system: GitHub Issues`. If not GitHub,
   print the manual-export instructions and **stop** (don't pretend).
2. Probe for GitHub MCP tools (e.g. `list_issues`/`create_issue`). If present →
   MCP path.
3. Else probe `gh auth status`. If authed → `gh` path.
4. Else → manual paste/path export, same as `/steer:drift` today.

## SKILL.md (proposed)

```md
---
name: tracker-sync
description: >
  Bidirectional GitHub Issues sync for the /spec spine. PULL: materialize issues
  as the markdown export /steer:drift consumes, and import a tracker item's
  acceptance criteria into a feature's intent.md. PUSH: file spec-drift issues
  from a drift run, promote /spec open questions to issues, and open a
  feature-request issue from an approved intent.md. GitHub-only accelerator —
  MCP-first, gh CLI fallback, manual export floor. Reads /spec/tracker.md;
  refuses to invent tracker state. Use to feed /steer:drift without copy-paste or
  to turn spec findings into real issues.
---
```

### Modes

#### `pull` — tracker → spec (introspect)

- **Export for drift.** Fetch open/closed issues (filterable by label/milestone),
  write **one markdown file per issue** into a temp export dir in the shape
  `/steer:drift` expects: title, tracker key (`#123`), labels, state, body +
  acceptance criteria. Then it can chain straight into `/steer:drift`.
- **Import criteria into intent.** Given an issue ref and a feature `[id]`, copy
  the issue's acceptance criteria into `spec/features/[id]/intent.md`, set the
  `> Tracker:` line, per Rule 35 (spec is in-repo source of truth; ref points
  back). Never overwrite human-authored intent prose — append/merge, flag
  conflicts.

#### `push` — spec → tracker (create)

- **`spec-drift` issues.** Consume a `/steer:drift` finding set and open one
  labelled `spec-drift` issue per finding needing a human decision — exactly the
  step `/steer:drift` describes but doesn't execute. Idempotent: skip if an open
  issue with the same finding key already exists.
- **Promote open questions.** Take a `## Open questions` entry that needs an
  external owner/scheduling, open an issue from it, then **replace the question
  with the ref** (`#123`) — closing the Rule-35 loop automatically.
- **New feature request.** From an approved `intent.md`, open a feature-request
  issue using `scaffold/github/ISSUE_TEMPLATE/feature-request.md`, and write the
  returned `#` back into the intent's `> Tracker:` line.

### Guardrails

- **Read `/spec/tracker.md` first, every run.** Non-GitHub tracker → manual path,
  no API calls.
- **Idempotent pushes.** Before creating any issue, search for an existing match
  (finding key / question text / feature id) and skip duplicates. Log skips.
- **Confirm before creating.** Creating issues is outward-facing — present the
  list of issues to be opened and **get a yes** before the first `create` call
  (a single confirmed batch is fine; don't prompt per-issue).
- **No code, no spec rewrites beyond refs.** `pull --import` and question-promote
  may edit `intent.md`'s `> Tracker:` / `## Open questions` lines; nothing else.

### Steps (happy path, `push` from a drift run)

1. Read `/spec/tracker.md`; confirm GitHub. Detect MCP vs `gh`.
2. Take the drift findings (from a just-run `/steer:drift`, or a findings file).
3. Dedup against existing open `spec-drift` issues.
4. Show the proposed issue list; get confirmation.
5. Create via MCP `create_issue` (preferred) or `gh issue create --body-file`.
6. Report the opened `#`s; where a finding maps to a feature, write the ref into
   that feature's `intent.md`.

## Why this stays faithful to the philosophy

The spec is **still authored in `/spec`** (by `/steer:spec`, `/steer:build`, etc.).
`/steer:tracker-sync` only moves **pointers and findings** across the GitHub
boundary — it never makes GitHub Issues the spec home, and it degrades to the
existing manual export for any non-GitHub client. It's the missing glue, not a
new source of truth.

## Wiring / rollout checklist

- New skill dir `skills/tracker-sync/SKILL.md`.
- Optional `commands/tracker-sync.md` alias.
- `/steer:drift`: add an opening step — "offer `/steer:tracker-sync pull` to
  auto-export instead of pasting" — and a closing step — "offer
  `/steer:tracker-sync push` to file the `spec-drift` issues."
- `/steer:questions`: when promoting a question, delegate the issue creation to
  `/steer:tracker-sync push`.
- `rules/35-issue-tracker.md`: add one line noting the GitHub accelerator exists
  (keep it client-agnostic in tone).
- Router (`00-router.md`) + commands list (`15-commands.md`) entries.
- `plugin.json` version bump + `CHANGELOG.md` entry; update `CLAUDE.md`.
```

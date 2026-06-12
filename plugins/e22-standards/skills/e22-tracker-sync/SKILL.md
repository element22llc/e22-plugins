---
name: e22-tracker-sync
description: "Bidirectional GitHub Issues sync for the /spec spine. PULL: materialize issues as the markdown export /e22-drift consumes, and import a tracker item's acceptance criteria into a feature's intent.md. PUSH: file spec-drift issues from a drift run, promote /spec open questions to issues, and open a feature-request issue from an approved intent.md. A GitHub-only accelerator — MCP-first, gh CLI fallback, manual export floor — that moves pointers and findings, never the spec itself. Reads /spec/tracker.md and refuses to invent tracker state."
---

# Sync the /spec spine with GitHub Issues

The plugin treats the tracker as a **pointer**, with `/spec` as the source of
truth. This skill is the **GitHub accelerator** for that pointer: it pulls issues
in (so `/e22-drift` doesn't need copy-paste) and pushes findings out (so
`spec-drift` issues and promoted questions actually get filed). It moves
**pointers and findings across the GitHub boundary** — it never makes GitHub
Issues the spec home, and for any non-GitHub tracker it degrades to the existing
manual export. It is glue, not a new source of truth.

## Integration: MCP-first → `gh` fallback → manual floor

The org ships GitHub MCP in every repo via `scaffold/mcp.json`
(`api.githubcopilot.com/mcp/`, `GITHUB_PAT`), so MCP is preferred — its tools
take a JSON `body` field, making multi-line markdown issue bodies clean with no
shell escaping. Detect capability **in this order, every run**:

1. **Read `/spec/tracker.md`.** Confirm `System: GitHub Issues`. If the tracker
   is Jira/Linear/Azure DevOps/other, print the manual-export instructions (the
   same paste/path flow `/e22-drift` uses today) and **stop** — there is no
   GitHub API path for a non-GitHub tracker. Don't fabricate one.
2. **Probe for GitHub MCP tools** (e.g. an issues list/get/create tool exposed by
   the github MCP server). If present → **MCP path**.
3. **Else probe `gh auth status`.** If authenticated → **`gh` CLI path**
   (`gh issue list --json …`, `gh issue create --body-file …` — use
   `--body-file`/heredoc for markdown bodies, never inline `--body` for
   multi-line text).
4. **Else** → manual paste/path export, same as `/e22-drift`. Say which path you
   took so the user knows whether issues were actually touched.

## Modes

### `pull` — tracker → spec (introspect)

- **Export for drift.** Fetch issues (filterable by label / milestone / state)
  and write **one markdown file per issue** into a temp export directory in the
  shape `/e22-drift` expects: title, tracker key (`#123`), labels, state, body,
  and acceptance criteria. Then offer to chain straight into `/e22-drift` with
  that directory as its tracker-spec input — no pasting.
- **Import criteria into an intent.** Given an issue ref and a feature `[id]`,
  copy the issue's acceptance criteria into `spec/features/[id]/intent.md` and
  set its `> Tracker:` line (Rule 35: the spec is the in-repo source of truth;
  the ref points back). **Never overwrite human-authored prose** — append/merge,
  and flag conflicts as `## Open questions` rather than clobbering.

### `push` — spec → tracker (create)

- **`spec-drift` issues.** Consume a `/e22-drift` finding set (from a just-run
  drift report or a findings file) and open one `spec-drift`-labelled issue per
  finding that needs a human decision — the step `/e22-drift` describes but does
  not execute. Scope to *actual* drift (Diverged, Done-but-Missing, genuine
  conflicts) — **never** expected-Missing backlog.
- **Promote an open question.** Take a `## Open questions` entry that needs an
  external owner or scheduling, open an issue from it, then **replace the
  question with the ref** (`#123`) — closing the Rule-35 loop automatically.
- **New feature request.** From an approved `intent.md`, open a feature-request
  issue using the repo's `.github/ISSUE_TEMPLATE/feature-request.md` shape, and
  write the returned `#` back into the intent's `> Tracker:` line.

## Guardrails

- **Read `/spec/tracker.md` first, every run** (step 1). Non-GitHub tracker →
  manual path, no API calls, no pretending.
- **Idempotent pushes.** Before creating any issue, search existing open issues
  for a match (finding key / question text / feature id) and **skip duplicates**;
  log what was skipped. Re-running `push` must not double-file.
- **Confirm before creating.** Creating issues is outward-facing. Present the
  full list of issues to be opened and **get one yes** before the first create
  (a single confirmed batch is fine — don't prompt per issue). Pulling is
  read-only and needs no confirmation.
- **No code, no spec rewrites beyond refs.** The only spec edits this skill makes
  are: an `intent.md` `> Tracker:` line, importing acceptance criteria
  (append/merge), and striking a promoted `## Open questions` item for its ref.
  It never edits `/apps`, `/packages`, or `contract.md` behavior.

## Steps (happy path — `push` from a drift run)

1. Read `/spec/tracker.md`; confirm GitHub. Detect MCP vs `gh` (above).
2. Take the drift findings (from a just-run `/e22-drift`, or a findings file the
   dev points to).
3. Dedup against existing open `spec-drift` issues.
4. Show the proposed issue list (title + which finding/feature each maps to); get
   one confirmation.
5. Create via the MCP create-issue tool (preferred) or `gh issue create
   --body-file`.
6. Report the opened `#`s; where a finding maps to a feature, write the ref into
   that feature's `intent.md` `> Tracker:` line.

## Coupling rules

Tracker-integration conventions are canonical in rule `35-issue-tracker` and the
`/e22-traceability` reference; the spec ↔ code resolution rules live in
`${CLAUDE_PLUGIN_ROOT}/templates/reference/spec-framework.md`. This skill only
moves pointers and findings across the GitHub boundary — those references govern
what the pointers mean and how drift gets resolved.

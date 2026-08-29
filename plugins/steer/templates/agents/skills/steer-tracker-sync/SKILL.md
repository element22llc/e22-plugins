---
name: steer-tracker-sync
description: Internal gateway for all tracker metadata I/O (GitHub MCP-first, gh fallback, manual floor) — reads and writes issues, and folds pulled criteria into intent.md, for the owning skills.
argument-hint: '[<op> | pull | push] [#issue | feature-id]'
user-invocable: false
---

<!-- Generated from the steer plugin's skills/tracker-sync/SKILL.md — do not edit by hand.
     Refresh with /steer:sync from Claude Code in a managed repo, or
     `mise run gen:copilot` in the plugin repo. Authored for Claude Code and
     rendered here in the cross-tool Agent Skills format (agentskills.io) that
     Copilot, Cursor, Gemini CLI and Codex read from .agents/skills/. -->

**When to use.** Reached via /steer-issues, /steer-work, and the other owning skills — not a direct entry point.

<!-- steer:modes pull,push -->

# Sync the /spec spine with GitHub Issues

The plugin treats the tracker as a **pointer**, with `/spec` as the source of
truth. This skill is the **GitHub accelerator** for that pointer: it pulls issues
in (so `/steer-audit spec` doesn't need copy-paste) and pushes findings out (so
`spec-drift` issues and promoted questions actually get filed). It moves
**pointers and findings across the GitHub boundary** — it never makes GitHub
Issues the spec home, and for any non-GitHub tracker it degrades to the existing
manual export. It is glue, not a new source of truth.

## Guardrails

- **Read `/spec/tracker.md` first, every run** (step 1) — resolved at the
  **workspace** in a polyrepo member, which carries no local copy. Non-GitHub
  tracker → manual path, no API calls, no pretending.
- **Idempotent pushes.** Before creating any issue, search existing issues in
  **all** states — open *and* closed — for a match (finding key / question text /
  feature id) and **skip duplicates**; log what was skipped. Re-running `push`
  must not double-file. Closed matches are the whole point: a finding closed as a
  false positive stays closed, and an open-only search would re-file it on the
  next audit. Handle a closed exact match per **`ISSUE-SCHEMA.md`
  §"Idempotency & deduplication"** — reopen only when it is genuinely the same
  unfinished work, else open a linked follow-up — never a bare duplicate.
- **Intent-aware confirmation.** Reads never confirm. Creation follows intent,
  not a blanket "outward-facing → confirm" rule: an explicit capture or
  implementation request ("create an issue for…", "add to the backlog", "fix
  this bug", "implement #123") creates without confirmation. A **large inferred
  batch of unrelated** issues takes one confirmation; ambiguous conversation that
  did not request capture does **not** create; security-sensitive public
  disclosure takes human review.
- **No code, no spec rewrites beyond refs.** The only spec edits this skill makes
  are: an `intent.md` `> Tracker:` line, importing acceptance criteria
  (append/merge), and setting a promoted question's `tracker:` field to its ref
  (the `### Q-NNN` block itself stays).
  It never edits `/apps`, `/packages`, or `contract.md` behavior.

## Coupling rules

Tracker-integration conventions are canonical in rule `35-issue-tracker` and the
`/steer-reference traceability` reference; the spec ↔ code resolution rules live in
`https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/templates/reference/SPEC-FRAMEWORK.md`. This skill only
moves pointers and findings across the GitHub boundary — those references govern
what the pointers mean and how drift gets resolved.

## Integration: MCP-first → `gh` fallback → manual floor

The steer plugin ships GitHub MCP to every repo that enables it (the plugin's
own `.mcp.json` — `api.githubcopilot.com/mcp/`, `GITHUB_PAT`), so MCP is
preferred — its tools
take a JSON `body` field, making multi-line markdown issue bodies clean with no
shell escaping. Detect capability **in this order, every run**:

1. **Read `/spec/tracker.md`.** Confirm the frontmatter key `system: github`
   (the lowercase enum value — not prose). If the tracker
   is Jira/Linear/Azure DevOps/other, print the manual-export instructions (the
   same paste/path flow `/steer-audit spec` uses today) and **stop** — there is no
   GitHub API path for a non-GitHub tracker. Don't fabricate one.

   **Polyrepo member** (`spec/PRODUCT.md` present, no local `spec/tracker.md`):
   the tracker is the **workspace's** by design — resolve it there via
   `workspace.path`, else the GitHub gateway, and read it from **there**. A
   missing local file is never "no tracker", so do not fall to the manual floor
   on its absence and never create a local copy. Issues are filed against the
   tracker's declared `repository:`, which in a member is not this repo — so the
   cross-repo closing-ref rule in `OPERATIONS.md` applies (`Refs owner/repo#N`
   plus an explicit `close`). If the workspace is unreachable by either route,
   say the spine is unreachable and stop (`/steer-reference polyrepo`).
2. **Probe for GitHub MCP tools** (e.g. an issues list/get/create tool exposed by
   the github MCP server). If present → **MCP path**.
3. **Else probe `gh auth status`.** If authenticated → **`gh` CLI path**
   (`gh issue list --json …`, `gh issue create --body-file …` — use
   `--body-file`/heredoc for markdown bodies, never inline `--body` for
   multi-line text).
4. **Else** → manual paste/path export, same as `/steer-audit spec`. Say which path you
   took so the user knows whether issues were actually touched.

**Sandboxed chat surfaces (Claude Cowork).** Cowork does **not** read the
plugin's `.mcp.json`, and its no-install sandbox has no `${GITHUB_PAT}` shell and
no `gh` CLI — so steps 2–3 only succeed when the user has enabled Cowork's
**built-in GitHub connector** (Customize → Connectors), which exposes the
repo-scoped issue tools the MCP path probes for. With it on, triage works; without
it, you land on the manual floor (step 4) — the `gh` fallback is unavailable.
The connector is **repo-scoped**, so org-level ops (`set-type` Issue Types,
`field-get`/`field-set` native fields) degrade per their own capability checks.
See [Known limitations → Claude Cowork's sandbox](https://github.com/element22llc/e22-plugins/blob/main/docs/reference/known-limitations.md).

## Issue operations (the gateway)

This is the **only** layer that touches the GitHub API. `/steer-issues` and
`/steer-work` call these operations; they never hit `gh`/MCP directly. The boundary
is **tracker metadata only** — issues, relationships, comments, labels, Issue
Types, assignments, milestones, and the `steer:state` marker. **Git
operations and pull-request delivery are NOT gateway operations** — they belong
to `/steer-work` under the repo's execution/autonomy rules (otherwise `git push`
would violate the boundary).

Each operation is MCP-first → `gh` → manual, and reports which path it took. The
full catalogue — `search`, `get`, `find-or-create`, `create`, `update`,
`comment`, `set-type`, `label`, `set-milestone`, `milestone-ensure`,
`field-get`/`field-set`, `bootstrap-fields`, `transition`, `assign`,
`link-parent`, `link-related`, `link-pr`, `link-blocked-by`, `close`/`reopen`,
and the cross-repo closing-ref rule — is in
[`OPERATIONS.md`](OPERATIONS.md).
**Read it before performing any operation.**

## Modes

### `pull` — tracker → spec (introspect)

- **Export for drift.** Fetch issues (filterable by label / milestone / state)
  and write **one markdown file per issue** into a temp export directory in the
  shape `/steer-audit spec` expects: title, tracker key (`#123`), labels, state, body,
  and acceptance criteria. Then offer to chain straight into `/steer-audit spec` with
  that directory as its tracker-spec input — no pasting.
- **Import criteria into an intent.** Given an issue ref and a feature `[id]`,
  copy the issue's acceptance criteria into `spec/features/[id]/intent.md` and
  set its `> Tracker:` line (Rule 35: the spec is the in-repo source of truth;
  the ref points back). **Never overwrite human-authored prose** — append/merge,
  and flag conflicts as `## Open questions` rather than clobbering.

### `push` — spec → tracker (create)

- **`spec-drift` issues.** Consume a `/steer-audit spec` finding set (from a just-run
  drift report or a findings file) and open one `spec-drift`-**kind** issue per
  finding that needs a human decision — the step `/steer-audit spec` describes but does
  not execute. Scope to *actual* drift (Diverged, Done-but-Missing, genuine
  conflicts) — **never** expected-Missing backlog.
- **Promote an open question.** Take a `## Open questions` entry that needs an
  external owner or scheduling, open an issue from it, then **write the ref into
  the question's `tracker:` field** (`#123`) — closing the Rule-35 loop
  automatically. **Keep the `### Q-NNN` block**: the issue carries the same id via
  `<!-- steer:question-id=Q-NNN -->`, that pair is the bidirectional link
  (`ISSUE-WORKFLOW.md`), and `/steer-spec validate` fails a promoted question whose
  `tracker:` ref is missing. Deleting the block breaks marker-based dedup.
- **New feature request.** From an approved `intent.md`, open a feature-request
  issue using the repo's `.github/ISSUE_TEMPLATE/feature.yml` form fields (or the
  machine-readable issue contract — see the issue-schema reference), and write
  the returned `#` back into the intent's `> Tracker:` line.

## Steps (happy path — `push` from a drift run)

1. Read `/spec/tracker.md`; confirm GitHub. Detect MCP vs `gh` (above).
2. Take the drift findings (from a just-run `/steer-audit spec`, or a findings file the
   dev points to).
3. Dedup against existing spec-drift issues in **all** states — open *and* closed
   (Guardrails → **Idempotent pushes**). An open-only search re-files a finding
   that was already closed as a false positive.
4. Create per **Intent-aware confirmation** in Guardrails: an explicit
   capture/implement request creates without confirmation; an **inferred** batch
   not directly requested (e.g. spec-drift or question findings surfaced by
   `/steer-audit`) takes **one** confirmation of the proposed list before filing,
   so false positives don't land unseen; **security-sensitive public disclosure**
   takes human review regardless.
5. Create via the MCP create-issue tool (preferred) or `gh issue create
   --body-file`.
6. Report the opened `#`s; where a finding maps to a feature, write the ref into
   that feature's `intent.md` `> Tracker:` line.

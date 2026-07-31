---
name: tracker-sync
description: "Internal gateway for all tracker metadata I/O (GitHub MCP-first, gh fallback, manual floor) — reads and writes issues, and folds pulled criteria into intent.md, for the owning skills."
when_to_use: >-
  Reached via /steer:issues, /steer:work, and the other owning skills — not a
  direct entry point.
argument-hint: "[<op> | pull | push] [#issue | feature-id]"
# Internal gateway: driven by /steer:issues and /steer:work, and also by
# /steer:spec (its optional file-the-intent exit), /steer:roadmap, /steer:questions,
# /steer:next's read-only state reconstruction, the read flows of
# /steer:audit and /steer:status, and /steer:init + /steer:adopt for
# `bootstrap-fields`. Never a direct user entry point. Model-callable, hidden from
# the slash menu, so it never competes with the orchestrators above it.
user-invocable: false
# Pre-approve the issue create + find-before-create dedup surface for a DIRECT
# /steer:tracker-sync invocation. Caveat: a skill's allowed-tools grant applies
# only while that skill is the invoked one — reached transitively (an orchestrator
# like /steer:issues or /steer:work delegates here in prose), these grants do NOT
# take effect and the write falls through to .claude/settings.json. So the
# scaffold's gh-issue allow-list is the real backstop for the orchestrated path;
# the `github-issue-permissions` capability (CAPABILITIES.md) detects a repo
# missing it. MCP-first; the scoped `gh issue *` verbs are the fallback. Mutation
# of the *delivery* surface (PR merge, branch protection, repo settings) is
# deliberately NOT listed — it stays host-gated.
#
# `Bash(gh api graphql:*)` IS granted, as the one carve-out. Projects v2 issue-field
# reads/writes and native blocked-by edges have no `gh issue` subcommand, so GraphQL is
# the transport to reach for on `field-get`, `field-set`, `link-blocked-by` and
# `bootstrap-fields` — all four squarely inside this gateway's declared
# tracker-metadata boundary (OPERATIONS.md). The fallbacks those ops document are real
# but neither substitutes cleanly: the REST endpoints sit outside every granted prefix
# (so they prompt), and the MCP github tools are granted but expose issue fields only
# where the org enabled them. Withholding GraphQL made `field-get` prompt on a direct
# invocation,
# contradicting "Reads never confirm" below.
#
# That grant is BROADER THAN THE BOUNDARY, and the limit is prose-enforced, not
# tool-enforced: allowed-tools matches a command-string prefix, so it cannot
# distinguish a Projects field query from `mergePullRequest` or
# `createBranchProtectionRule`, which GraphQL can also express. This gateway
# therefore issues ONLY the queries and mutations OPERATIONS.md enumerates; a
# delivery-surface mutation is out of bounds here even though the grant would match
# it, and belongs to /steer:work or /steer:protect under their own gating. Never
# widen this to `Bash(gh api:*)`. check_standards.py bans that form in the SCAFFOLD's
# .claude/settings.json only — nothing constrains WHAT a skill's own allowed-tools may
# grant (the one per-skill assertion, check_skill_script_grants, only checks that helper
# scripts the body invokes are covered), so widening this line would pass every check.
# Treat it as a review obligation, not a guarded one.
allowed-tools:
  - mcp__github__issue_write
  - mcp__github__issue_read
  - mcp__github__search_issues
  - mcp__github__list_issues
  - mcp__github__add_issue_comment
  - mcp__github__sub_issue_write
  - Bash(gh issue create:*)
  - Bash(gh issue edit:*)
  - Bash(gh issue comment:*)
  - Bash(gh issue list:*)
  - Bash(gh issue view:*)
  - Bash(gh search issues:*)
  - Bash(gh auth status:*)
  - Bash(gh api graphql:*)
---
<!-- steer:modes pull,push -->

# Sync the /spec spine with GitHub Issues

The plugin treats the tracker as a **pointer**, with `/spec` as the source of
truth. This skill is the **GitHub accelerator** for that pointer: it pulls issues
in (so `/steer:audit spec` doesn't need copy-paste) and pushes findings out (so
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
`/steer:reference traceability` reference; the spec ↔ code resolution rules live in
`${CLAUDE_PLUGIN_ROOT}/templates/reference/SPEC-FRAMEWORK.md`. This skill only
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
   same paste/path flow `/steer:audit spec` uses today) and **stop** — there is no
   GitHub API path for a non-GitHub tracker. Don't fabricate one.

   **Polyrepo member** (`spec/PRODUCT.md` present, no local `spec/tracker.md`):
   the tracker is the **workspace's** by design — resolve it there via
   `workspace.path`, else the GitHub gateway, and read it from **there**. A
   missing local file is never "no tracker", so do not fall to the manual floor
   on its absence and never create a local copy. Issues are filed against the
   tracker's declared `repository:`, which in a member is not this repo — so the
   cross-repo closing-ref rule in `OPERATIONS.md` applies (`Refs owner/repo#N`
   plus an explicit `close`). If the workspace is unreachable by either route,
   say the spine is unreachable and stop (`/steer:reference polyrepo`).
2. **Probe for GitHub MCP tools** (e.g. an issues list/get/create tool exposed by
   the github MCP server). If present → **MCP path**.
3. **Else probe `gh auth status`.** If authenticated → **`gh` CLI path**
   (`gh issue list --json …`, `gh issue create --body-file …` — use
   `--body-file`/heredoc for markdown bodies, never inline `--body` for
   multi-line text).
4. **Else** → manual paste/path export, same as `/steer:audit spec`. Say which path you
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

This is the **only** layer that touches the GitHub API. `/steer:issues` and
`/steer:work` call these operations; they never hit `gh`/MCP directly. The boundary
is **tracker metadata only** — issues, relationships, comments, labels, Issue
Types, assignments, milestones, and the `steer:state` marker. **Git
operations and pull-request delivery are NOT gateway operations** — they belong
to `/steer:work` under the repo's execution/autonomy rules (otherwise `git push`
would violate the boundary).

Each operation is MCP-first → `gh` → manual, and reports which path it took. The
full catalogue — `search`, `get`, `find-or-create`, `create`, `update`,
`comment`, `set-type`, `label`, `set-milestone`, `milestone-ensure`,
`field-get`/`field-set`, `bootstrap-fields`, `transition`, `assign`,
`link-parent`, `link-related`, `link-pr`, `link-blocked-by`, `close`/`reopen`,
and the cross-repo closing-ref rule — is in
[`OPERATIONS.md`](${CLAUDE_PLUGIN_ROOT}/skills/tracker-sync/OPERATIONS.md).
**Read it before performing any operation.**

## Modes

### `pull` — tracker → spec (introspect)

- **Export for drift.** Fetch issues (filterable by label / milestone / state)
  and write **one markdown file per issue** into a temp export directory in the
  shape `/steer:audit spec` expects: title, tracker key (`#123`), labels, state, body,
  and acceptance criteria. Then offer to chain straight into `/steer:audit spec` with
  that directory as its tracker-spec input — no pasting.
- **Import criteria into an intent.** Given an issue ref and a feature `[id]`,
  copy the issue's acceptance criteria into `spec/features/[id]/intent.md` and
  set its `> Tracker:` line (Rule 35: the spec is the in-repo source of truth;
  the ref points back). **Never overwrite human-authored prose** — append/merge,
  and flag conflicts as `## Open questions` rather than clobbering.

### `push` — spec → tracker (create)

- **`spec-drift` issues.** Consume a `/steer:audit spec` finding set (from a just-run
  drift report or a findings file) and open one `spec-drift`-labelled issue per
  finding that needs a human decision — the step `/steer:audit spec` describes but does
  not execute. Scope to *actual* drift (Diverged, Done-but-Missing, genuine
  conflicts) — **never** expected-Missing backlog.
- **Promote an open question.** Take a `## Open questions` entry that needs an
  external owner or scheduling, open an issue from it, then **write the ref into
  the question's `tracker:` field** (`#123`) — closing the Rule-35 loop
  automatically. **Keep the `### Q-NNN` block**: the issue carries the same id via
  `<!-- steer:question-id=Q-NNN -->`, that pair is the bidirectional link
  (`ISSUE-WORKFLOW.md`), and `/steer:spec validate` fails a promoted question whose
  `tracker:` ref is missing. Deleting the block breaks marker-based dedup.
- **New feature request.** From an approved `intent.md`, open a feature-request
  issue using the repo's `.github/ISSUE_TEMPLATE/feature.yml` form fields (or the
  machine-readable issue contract — see the issue-schema reference), and write
  the returned `#` back into the intent's `> Tracker:` line.

## Steps (happy path — `push` from a drift run)

1. Read `/spec/tracker.md`; confirm GitHub. Detect MCP vs `gh` (above).
2. Take the drift findings (from a just-run `/steer:audit spec`, or a findings file the
   dev points to).
3. Dedup against existing spec-drift issues in **all** states — open *and* closed
   (Guardrails → **Idempotent pushes**). An open-only search re-files a finding
   that was already closed as a false positive.
4. Create per **Intent-aware confirmation** in Guardrails: an explicit
   capture/implement request creates without confirmation; an **inferred** batch
   not directly requested (e.g. spec-drift or question findings surfaced by
   `/steer:audit`) takes **one** confirmation of the proposed list before filing,
   so false positives don't land unseen; **security-sensitive public disclosure**
   takes human review regardless.
5. Create via the MCP create-issue tool (preferred) or `gh issue create
   --body-file`.
6. Report the opened `#`s; where a finding maps to a feature, write the ref into
   that feature's `intent.md` `> Tracker:` line.

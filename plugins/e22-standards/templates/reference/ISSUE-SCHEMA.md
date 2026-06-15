# Issue schema — the machine-readable issue contract

Every **agent-authored** GitHub issue follows this contract so that updates are
idempotent, reconciliation is deterministic, and another agent (Claude, Codex,
Copilot) — or a plain `gh` script — can read and rewrite the issue without
parsing free prose. The contract is two things: **hidden identity markers** and
**stable section headings**, with agent-owned content fenced inside a **managed
block** so human edits are never clobbered.

This file is the single normative owner of the issue *format*. The lifecycle,
state model, labels, and authority live in [`ISSUE-WORKFLOW.md`](ISSUE-WORKFLOW.md);
the open-question format lives in [`spec-framework.md`](spec-framework.md).

## Identity markers

HTML comments at the top of the issue body. They are invisible in rendered
GitHub but are the deterministic handles every skill keys off — **search by
marker before creating, to dedupe**.

| Marker | Meaning | On |
|---|---|---|
| `<!-- e22:schema=1 -->` | Contract version this body was written against. Required on every agent issue. | all |
| `<!-- e22:kind=… -->` | `feature` · `bug` · `task` · `spec-question` · `audit-run` · `audit-finding` · `spec-drift` | all |
| `<!-- e22:feature-id=… -->` | Owning feature slug (kebab-case), when one exists. | feature, task, spec-question, spec-drift |
| `<!-- e22:spec-path=… -->` | Path to the owning spec artifact (e.g. `spec/features/<id>/intent.md`). | feature, task, spec-question, spec-drift |
| `<!-- e22:question-id=Q-NNN -->` | The stable question ID this issue tracks (see `spec-framework.md`). | spec-question |
| `<!-- e22:finding-key=… -->` | Stable conceptual identity of an audit finding — `<dimension>:<rule>:<file-or-component>:<symbol>`. **Never line-based.** | audit-finding |
| `<!-- e22:evidence=… -->` | Fingerprint of the *currently observed* evidence (e.g. a short hash of the offending lines/region). Changes as the code moves; the `finding-key` does not. | audit-finding |
| `<!-- e22:audit-id=… -->` | One audit run, `<iso-timestamp>-<short-sha>`. Immutable per run. | audit-run, audit-finding |
| `<!-- e22:audit-commit=… -->` | The commit SHA the audit observed. | audit-run, audit-finding |
| `<!-- e22:parent-issue=N -->` | Parent issue, when native sub-issue links are unavailable (fallback). | task, audit-finding |

## Managed block

Agent-owned sections live between markers; everything outside is human-owned and
**preserved verbatim** on every update:

```md
<!-- e22:managed:start -->
## Outcome
…agent-maintained sections…
<!-- e22:managed:end -->

## Team notes
Human discussion — never touched by an agent.
```

An idempotent update **replaces only the managed block**, leaving the markers,
human sections, and any unknown content intact.

## Stable section headings

Inside the managed block, use these headings exactly (skip ones that don't
apply; never rename them). Per kind:

- **feature / task** — `Outcome` · `User value` · `Scope` · `Out of scope` ·
  `Acceptance criteria` · `Open questions` · `Spec references` · `Validation`.
- **spec-question** — `Question` · `Why this matters` · `Affected specifications`
  · `Decision needed from` · `Resolution`.
- **audit-run** — `Scope` · `Run metadata` · `Summary` · `Report`.
- **audit-finding** — `Finding` · `Evidence` · `Standard missed` · `Impact` ·
  `Suggested remediation` · `Origin`.
- **spec-drift** — `Spec says` · `Implementation does` · `Evidence` ·
  `Human decision required`.

The body templates in [`../github/issue-bodies/`](../github/issue-bodies/) are
the canonical starting shapes for the agent-generated kinds.

## Idempotency rules

1. **Find before create.** Search open + closed issues for the matching marker
   (`feature-id` + `kind`, `question-id`, `finding-key`). A match means update,
   not create — this is what keeps audits reconciling rather than additive.
2. **Update only the managed block.** Preserve markers, human sections, and
   unknown markers. Never delete content you didn't write.
3. **Writers emit the current schema; parsers accept current + one prior.** When
   the schema version bumps, a writer rewrites the managed block to the new
   shape and updates `e22:schema`; unknown/human markers are carried forward.
4. **Schema migration is explicit.** It happens only through `/e22-sync` or
   `/e22-issues reconcile` and is reported — never silently during an unrelated
   command.

## Issue Forms are human UI, not an agent API

The YAML Issue Forms in [`../github/issue-forms/`](../github/issue-forms/) are
**repository UI** for humans opening issues — GitHub exposes no API to submit a
form programmatically. The form and the agent `capture` path share *equivalent
semantic fields*; an agent **renders those fields into this contract** (markers
+ headings + managed block). Never try to "submit a form" via MCP or `gh`.

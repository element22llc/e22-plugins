# Action history — [Product Name]

> Append-only log of **notable events**: what happened, why, who (or what) asked
> for it, and which specs/issues/decisions/code areas were affected.
> **One file per entry** in this directory. Claude writes the entry file in the
> same PR as the change; the PR review is what makes it evidence.
>
> This log exists for auditability (SOC 2 / ISO 27001-**aligned** traceability
> and review evidence), onboarding, reconstructing product decisions, and
> spotting intent drift over time. Keep entries short — 3–6 lines. Detail lives
> in the linked spec/ADR/PR, not here.

## What earns an entry

An entry records what the git log and the PR **cannot** reconstruct — the *why*
behind a durable choice, not the fact that a change shipped:

- A **ratified decision** — an ADR moved to `Accepted`, an intent approved.
- A **scope change** to an already-approved intent.
- A **repo-level event** — bootstrap, adoption, a plugin sync, graduating from
  solo trunk to the PR flow.
- A **PO source document absorbed** into the spine.
- A **production incident** and its post-incident follow-up.

**An ordinary merged change writes no entry.** Its record is the commit history
plus the reviewed PR, which already carry what changed, when, by whom, and the
tracker ref. Re-typing that here by hand adds a file to maintain and no
information — and a log padded with routine entries is one nobody reads, which
costs the decisions worth finding.

## One file per entry — and why

Each entry is its own file:

```text
spec/history/YYYY-MM-DD-HHMM-<slug>.md
```

Two concurrent PRs therefore write **different paths** and can never conflict.
That is the whole reason this log is a directory rather than one shared file: a
single append-only file put every PR's entry at the same insertion point, so
every pair of parallel changes collided — and the obvious fix, git's `union`
merge driver, is unsafe here. Union is *line*-based: when two entries share a
trailing line (`- **Areas:** apps/web` is the common case) it splices the two
blocks together and **silently drops a field**, producing a clean merge no
reviewer ever sees. A directory removes the conflict instead of auto-resolving
it.

Naming:

- `YYYY-MM-DD` — the date the change merged or the decision was ratified.
- `HHMM` — 24-hour local time. Makes same-day entries sort deterministically and
  keeps two of them from colliding on one filename.
- `<slug>` — 3–6 kebab-case words naming the change (`csv-export`,
  `vendor-list-filter`, `retire-legacy-auth`).

The filenames sort chronologically, so read the timeline newest-first with a
reverse sort:

```sh
ls -r spec/history/*.md
```

## Entries are immutable

Never rewrite, re-date, or delete an entry file. A correction is a **new** entry
that references the one it corrects (add a `- **Corrects:** <filename>` line).
That immutability is what makes this log evidence rather than notes.

## Writing an entry

Copy `${CLAUDE_PLUGIN_ROOT}/templates/spec/history-entry.md`, or write the shape
directly:

```markdown
# 2026-06-10 14:32 — CSV export added to vendor list

- **Why:** PO needs to hand vendor data to finance monthly
- **Requested by:** @pat-po
- **Refs:** PROJ-214 · spec/features/export-csv/ · PR #87
- **Areas:** apps/web, packages/core
```

## Archive

A repo bootstrapped before this directory existed carries its earlier entries in
`spec/HISTORY.md`, kept **frozen** as the pre-migration archive: read it for
anything older than this directory's oldest file, and never append to it again.

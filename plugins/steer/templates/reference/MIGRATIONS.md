# Spec-spine migration ledger

Append-only, ordered record of **non-additive** structural changes to the spec
spine and bundled scaffold — renames, moves, deletions, and default changes that
the [purely-additive Template reconciliation](spec-framework.md) convention
cannot express. A reconciliation diff sees a renamed file as *old-present +
new-absent* and would happily add the new file while orphaning the old one; only
an explicit migration knows the two are the same artifact.

This ledger is the **single source of truth** for those transforms. `/steer:sync`
consumes it to carry an already-bootstrapped repo forward when the plugin's
conventions change; `/steer:adopt` and `/steer:build` consume the same entries on a
resume so a repo first touched under an older plugin version picks up structural
changes too — not just additive ones. **Add an entry here in the same change
that lands a rename/move/deletion** in `templates/spec/` or
`templates/scaffold/`; do not hand-code the transform inline in a skill.

## How a migration is applied

Each migration is keyed by the **plugin version that introduced it** and is
**idempotent and self-detecting**: it carries a *precondition* (how to tell it
still needs doing) and an *action*. Apply a migration only when its precondition
holds — so re-running is safe and a repo with no `/spec/.version` stamp (touched
before stamping existed) can be brought current by walking the whole ledger and
applying only the entries whose precondition still fires.

The `/spec/.version` stamp records the plugin version a repo's spine was last
materialized or synced at. It is an **optimization, not the safety mechanism**:
a consumer skips entries at or below the stamp, then applies the rest by
precondition. Because every entry is self-detecting, a wrong or missing stamp
costs extra no-op checks, never a bad transform. Resolve the current plugin
version from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` — never from
memory — and re-stamp to it after applying.

All migrations follow the spine discipline: **read-then-propose, never clobber**,
preserve filled-in content, and land on a `feat/*` branch through a PR. Use
`git mv` (not copy+delete) for renames so history follows the file.

## Entries

> Newest first. Each entry: the introducing **version**, **what & why**, a
> **precondition** (apply only if true), and the **action**.

### v1.38.0 — GitHub Issue Forms replace Markdown templates; `tracker.md` gains frontmatter

- **What & why:** the bundled GitHub issue templates moved from Markdown
  (`bug-report.md`, `feature-request.md`) to PO-friendly YAML Issue Forms
  (`feature.yml`, `bug.yml`, `product-question.yml`, `improvement.yml`).
  Additive reconciliation adds the `.yml` forms but cannot delete the superseded
  `.md` files, and `spec/tracker.md` now carries a machine-readable frontmatter
  block the prose-only version lacks.
- **Precondition:** `.github/ISSUE_TEMPLATE/bug-report.md` or
  `feature-request.md` exists, or `spec/tracker.md` has no YAML frontmatter.
- **Action:** `git rm .github/ISSUE_TEMPLATE/bug-report.md
  .github/ISSUE_TEMPLATE/feature-request.md` (only those superseded by the new
  forms — keep any product-authored templates). Then run additive
  [Template reconciliation](spec-framework.md) against `templates/spec/tracker.md`
  to splice in the frontmatter **without overwriting edited values** (system,
  repository, ref format). Converting existing free-form `## Open questions` to
  the structured `Q-NNN` format is **opportunistic** — let `/steer:questions` do it
  when it next touches a question, not as a bulk rewrite.

### v1.22.0 — `PRODUCTION-READINESS.md` → `PRODUCTIONIZATION.md`

- **What & why:** the adoption/productionization brief was renamed from
  `/spec/PRODUCTION-READINESS.md` to `/spec/PRODUCTIONIZATION.md` to match the
  triage vocabulary (Keep/Refactor/Rewrite/Reject) the file now drives.
- **Precondition:** `spec/PRODUCTION-READINESS.md` exists.
- **Action:** `git mv spec/PRODUCTION-READINESS.md spec/PRODUCTIONIZATION.md`.
  Then run the additive [Template reconciliation](spec-framework.md) against the
  current `templates/spec/productionization.md` so any sections added since are
  spliced in. The old name on disk is itself a resume signal — migrate it
  **before** any fresh-vs-resume decision, so it can't be mistaken for a fresh
  adoption.

<!-- Template for a new entry — copy above the most recent one:

### vX.Y.Z — <one-line what>

- **What & why:** <the structural change and the reason a repo must follow it>
- **Precondition:** <a check that is true only while the migration is still
  pending — e.g. "spec/OLD.md exists", "spec/features/*/spec.md exists">
- **Action:** <the concrete transform — `git mv …`, move/merge, delete — applied
  read-then-propose, never clobbering filled-in content; follow with additive
  reconciliation if the renamed file is also template-tracked>

-->

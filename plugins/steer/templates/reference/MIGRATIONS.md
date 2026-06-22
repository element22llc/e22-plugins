# Spec-spine migration ledger

Append-only, ordered record of **non-additive** structural changes to the spec
spine and bundled scaffold — renames, moves, deletions, default changes, and
**in-file token rewrites** (replacing a string that already exists in a
materialized file) that
the [purely-additive Template reconciliation](SPEC-FRAMEWORK.md) convention
cannot express. A reconciliation diff sees a renamed file as *old-present +
new-absent* and would happily add the new file while orphaning the old one; only
an explicit migration knows the two are the same artifact.

This ledger covers non-additive transforms of artifacts that **already exist**.
Whole-file *presence + wiring* of capability-critical scaffold (a file entirely
missing, or present-but-not-enabled) is a separate, third axis owned by
[`CAPABILITIES.md`](CAPABILITIES.md), which `/steer:sync` walks every run — do
**not** add "create the missing file" entries here.

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
`git mv` (not copy+delete) for renames so history follows the file. An **in-file
token rewrite** is read-then-propose too: scan only the exact old→new pairs the
entry lists, show the diff, and replace **only** those tokens — never a broader
regex, never a string the entry doesn't enumerate. Its precondition must be a grep
that fires only while a stale token is still present and that cannot match a
legitimate look-alike (e.g. an unchanged marketplace id).

## Entries

> Newest first. Each entry: the introducing **version**, **what & why**, a
> **precondition** (apply only if true), and the **action**.

### v2.11.0 — MCP servers move from the scaffold into the plugin

- **What & why:** the `github` + `markitdown` MCP servers used to be scaffolded as
  a per-repo `.mcp.json` (from `templates/scaffold/mcp.json`). They now ship with
  the **plugin itself** (`plugins/steer/.mcp.json`), so every repo that enables
  steer picks them up centrally and they refresh on `/plugin update` — no frozen
  per-repo copy to drift. A repo bootstrapped before this change still carries the
  old repo-local `.mcp.json`; its `github`/`markitdown` entries now **duplicate**
  the plugin-shipped ones (same server keys from two sources), so the repo-local
  copy is redundant and, being frozen, would silently diverge from the maintained
  plugin copy. Additive reconciliation can't remove it (a deletion), and it isn't
  a capability gap — so it's a migration.
- **Precondition:** a repo-local `.mcp.json` exists whose servers duplicate the
  plugin's — this grep fires:

  ```sh
  test -f .mcp.json && grep -qE 'api\.githubcopilot\.com|markitdown-mcp' .mcp.json && echo pending
  ```

  No file, or a `.mcp.json` that defines only product-specific servers ⇒ no-op.
- **Action:** read-then-propose, show the diff first.
  - If `.mcp.json` defines **only** the `github` and `markitdown` servers (an
    unmodified old-scaffold copy), `git rm .mcp.json` — the plugin now provides
    both.
  - If it **also** defines product-specific servers, **keep the file** and remove
    only the `github` and `markitdown` keys, preserving every other server and
    value — never clobber a dev-added entry. The remaining repo-local servers
    merge additively with the plugin's.

  Idempotent: once the duplicated keys are gone the precondition is empty, so
  re-running is a no-op.

### v2.0.0 — `e22-standards` → `steer` rebrand: in-file token rewrite

- **What & why:** 2.0.0 renamed the plugin `e22-standards` → `steer` and dropped
  the redundant skill prefix. A repo bootstrapped before 2.0.0 still carries old
  tokens **inside** its materialized spine + scaffold — old slash invocations in
  `.github/pull_request_template.md`, `mise.toml`, `CLAUDE.md`, `README.md`; the
  dead marker `e22-standards@e22-plugins` in `.claude/settings.json`; the same
  marker in `.github/workflows/claude.yml`'s `plugins:` list; and `e22:` metadata
  markers in the spec spine. These are neither new files (capability repair) nor
  new sections (additive reconciliation) — they are **rewrites of strings that
  already exist**, which only a migration may do. The marketplace id `e22-plugins`
  and repo `element22llc/e22-plugins` are intentionally **unchanged** and must
  never be rewritten.
- **Precondition:** any materialized file still contains a stale token — this grep
  fires (run from repo root; the trailing filter protects the unchanged
  marketplace id):

  ```sh
  grep -rIE 'e22-standards|/e22-[a-z]|e22:(modes|state|source|kind|placeholder)' \
    --include='*.md' --include='*.yml' --include='*.yaml' --include='*.toml' \
    --include='*.json' . 2>/dev/null \
    | grep -vE 'element22llc/e22-plugins|steer@e22-plugins|"e22-plugins"'
  ```

  Empty output ⇒ already migrated (or a fresh post-2.0.0 repo) ⇒ no-op. The
  `e22-standards` substring is *always* stale (the rebrand removed the name
  entirely), so it unambiguously flags the dead `e22-standards@e22-plugins` marker
  too — the marketplace exclusions match only the legitimate `steer@e22-plugins`,
  `element22llc/e22-plugins`, and `"e22-plugins"` forms, never that dead marker.
- **Action:** read-then-propose an **in-file token substitution** over the
  materialized spine + scaffold files only (never the verbatim `scripts/*`
  version-pin files — those are capability repair's verbatim re-copy). Show the
  diff, then replace **only** these exact pairs, longest/most-specific first.
  Old-token cells that begin a slash invocation are shown **without** the leading
  `/` so this ledger file itself passes the stale-`/e22-*` lint guard; in a managed
  repo they carry the leading `/`, and the pair applies to that slash-prefixed form.

  | # | Old token | New | Lands in |
  |---|---|---|---|
  | 1 | `e22-standards:e22-` (slash-prefixed) | `/steer:` | PR template, CLAUDE.md, README.md, mise.toml |
  | 2 | `e22-standards:` (slash-prefixed) | `/steer:` | any remaining qualified ref |
  | 3 | `<!-- e22-standards:` | `<!-- steer:` | HTML markers |
  | 4 | `"e22-standards@e22-plugins"` | `"steer@e22-plugins"` | `.claude/settings.json` `enabledPlugins` key |
  | 5 | `e22-standards@e22-plugins` | `steer@e22-plugins` | `claude.yml` `plugins:` (unquoted) |
  | 6 | `e22-<skill>` (slash-prefixed, a real skill name follows; **never** `plugins`) | `/steer:<skill>` | bare invocations, e.g. `init` → `/steer:init` |
  | 7 | `e22:{modes,state,source,kind,placeholder}` | `steer:{…}` | spine metadata + `<!-- … -->` markers |

  **False-positive guard:** never rewrite the marketplace id — `e22-plugins`,
  `@e22-plugins`, or `element22llc/e22-plugins` — even when slash-prefixed. Pairs
  1–5 and 7 are safe (they carry the `e22-standards` substring, a quoted/`@`-scoped
  marker, or the `e22:` colon namespace the bare id lacks). Pair 6 is the only
  dangerous one: apply it **only** when the token after `e22-` is a known skill
  name and **never** when it is `plugins`. Pair 4 both removes the dead key and
  produces the live key in one edit, value preserved. Follow with additive
  [Template reconciliation](SPEC-FRAMEWORK.md) for any template-tracked file.
  Idempotent: once applied the precondition is empty, so re-running is a no-op.

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
  [Template reconciliation](SPEC-FRAMEWORK.md) against `templates/spec/tracker.md`
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
  Then run the additive [Template reconciliation](SPEC-FRAMEWORK.md) against the
  current `templates/spec/productionization.md` so any sections added since are
  spliced in. The old name on disk is itself a resume signal — migrate it
  **before** any fresh-vs-resume decision, so it can't be mistaken for a fresh
  adoption.

<!-- Template for a new entry — copy above the most recent one:

### vX.Y.Z — <one-line what>

- **What & why:** <the structural change and the reason a repo must follow it>
- **Precondition:** <a check that is true only while the migration is still
  pending — e.g. "spec/OLD.md exists", "spec/features/*/spec.md exists">
- **Action:** <the concrete transform — `git mv …`, move/merge, delete, or an
  **in-file token rewrite** (an explicit list of old→new string pairs replaced in
  place across named files, with a false-positive guard) — applied
  read-then-propose, never clobbering filled-in content; follow with additive
  reconciliation if a renamed file is also template-tracked>

-->

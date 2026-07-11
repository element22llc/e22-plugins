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

### v3.16.0 — scaffold `.claude/settings.json`: push + PR-create move from `ask` to `allow`

- **What & why:** the two-state delivery model (rule `45-commit-autonomy`) made
  pushing a branch and opening the PR **autonomous** delivery steps — the human
  gate is the PR **merge** (server-enforced by branch protection in pr-flow) and,
  in an ungraduated solo-trunk repo, the trunk-push hook's graduation gate. The
  scaffold template therefore moved `Bash(git push)`, `Bash(git push origin:*)`,
  `Bash(git push -u origin:*)`, `Bash(git push --set-upstream origin:*)`, and
  `Bash(gh pr create:*)` from `permissions.ask` to `permissions.allow` (and added
  `Bash(gh pr edit:*)` to `allow`); `Bash(gh pr merge:*)` deliberately stays in
  `ask` and the force-push denies stay in `deny`. The `/steer:sync` settings
  merge is additive (it unions `allow` but never removes an `ask` entry), and
  `ask` outranks `allow` — so an already-bootstrapped repo keeps prompting on
  every push forever without a migration. Removing entries from `ask` inside an
  existing file is non-additive: only a migration may do it.
- **Precondition:** the repo's `.claude/settings.json` still asks for pushes or
  PR creation — this grep fires:

  ```sh
  test -f .claude/settings.json && \
    python3 -c "import json,sys; p=json.load(open('.claude/settings.json')).get('permissions',{}).get('ask',[]); sys.exit(0 if any(x.startswith(('Bash(git push','Bash(gh pr create')) for x in p) else 1)" && echo pending
  ```

  No file, or none of those entries under `ask` ⇒ no-op.
- **Action:** read-then-propose, show the diff first. Move every
  `Bash(git push…)` and `Bash(gh pr create…)` entry from `permissions.ask` to
  `permissions.allow` (skip any that `allow` already carries), add
  `Bash(gh pr edit:*)` to `allow` if absent, and leave `Bash(gh pr merge:*)`,
  `Bash(git rm:*)`, the MCP issue-write entries, and the whole `deny` list
  untouched. Preserve every other key and value. If the repo has deliberately
  tightened its posture (e.g. an ADR records keeping the push gate), surface the
  conflict instead of applying — the consumer may tighten, never quietly loosen.

  Idempotent: once no push/PR-create entry remains under `ask`, the
  precondition is empty, so re-running is a no-op.

### v3.13.0 — scaffold `enabledPlugins`: drop the duplicate context7 entry

- **What & why:** the scaffold's `.claude/settings.json` used to enable
  `context7@claude-plugins-official` per repo. steer ships its own context7 MCP
  server with the plugin (`plugins/steer/.mcp.json`), so a repo bootstrapped from
  the old scaffold loads **two** context7 servers with duplicate toolsets. 3.13.0
  removed the entry from the scaffold template, but the `/steer:sync` settings
  merge is additive and never flips or removes an existing value — so an
  already-bootstrapped repo keeps the duplicate forever without a migration.
  This is a deletion inside an existing file: only a migration may do it.
- **Precondition:** the repo's `.claude/settings.json` still carries the
  marketplace copy — this grep fires:

  ```sh
  test -f .claude/settings.json && \
    grep -q '"context7@claude-plugins-official"' .claude/settings.json && echo pending
  ```

  No file, or no such key ⇒ no-op.
- **Action:** read-then-propose, show the diff first. Remove the
  `"context7@claude-plugins-official"` key from `enabledPlugins`, preserving
  every other entry and value. The plugin-shipped context7 server keeps
  providing the same capability, so behavior is unchanged whether the key was
  `true` (duplicate removed) or `false` (absent ≡ disabled; the plugin copy is
  governed by enabling steer itself).

  Idempotent: once the key is gone the precondition is empty, so re-running is
  a no-op.

### v3.8.0 — `reference`-mode invocations: in-file token rewrite

- **What & why:** several reference topics were only ever *modes* of the `reference`
  skill (`conventions`, `traceability`, `design-sources`, `context-hygiene`), reached
  as `/steer:reference <mode>` — there has never been a top-level skill named
  `conventions` / `design-sources` / etc. A repo bootstrapped or adopted by an older
  skill that authored the bare `steer:<mode>` form (as a slash invocation) in its live
  prose therefore carries invocations that **do not resolve** (Claude Code namespaces
  every skill and has no such skill to match). These are neither new files (capability
  repair) nor new sections (additive reconciliation) — they are **rewrites of strings
  that already exist**, which only a migration may do. This is the one-shot,
  version-keyed carry-forward; `/steer:sync`'s invocation-hygiene step
  (`scripts/scan-invocations.sh`) is the standing backstop that also catches later
  drift and the `user-invocable: false` gateway class. (The pre-rebrand `/e22-*`
  tokens are covered by the v2.0.0 entry below — do **not** duplicate them here.)
- **Precondition:** a bare `reference`-mode slash invocation is still present in the
  live prose — this grep fires (it starts with `/steer:(` so it cannot match the
  correct `/steer:reference <mode>` form, whose mode never directly follows the colon):

  ```sh
  grep -rIE '/steer:(conventions|traceability|design-sources|context-hygiene)\b' \
    CLAUDE.md README.md .github/pull_request_template.md 2>/dev/null
  ```

  Empty output ⇒ already migrated (or authored correctly) ⇒ no-op.
- **Action:** read-then-propose an **in-file token substitution** over the live
  instruction surfaces only (`CLAUDE.md`, `README.md`,
  `.github/pull_request_template.md`) — never append-only/provenance prose
  (`spec/HISTORY.md`, `spec/reports/*`, ADRs, feature `intent.md` provenance), where a
  historical mention is a legitimate record. Show the diff, then replace **only** these
  exact pairs. Old-token cells are shown **without** the leading `/` so this ledger file
  itself passes the phantom-skill lint guard; in a managed repo they carry the leading
  `/`, and the pair applies to that slash-prefixed form.

  | # | Old token | New | Lands in |
  |---|---|---|---|
  | 1 | `steer:conventions` (slash-prefixed) | `/steer:reference conventions` | CLAUDE.md, README.md, PR template |
  | 2 | `steer:traceability` (slash-prefixed) | `/steer:reference traceability` | same |
  | 3 | `steer:design-sources` (slash-prefixed) | `/steer:reference design-sources` | same |
  | 4 | `steer:context-hygiene` (slash-prefixed) | `/steer:reference context-hygiene` | same |

  **False-positive guard:** the mode name must directly follow `/steer:` — never rewrite
  an already-correct `/steer:reference <mode>` (there the mode follows `reference `, not
  the colon), and never a prose word like "conventions" that is not slash-prefixed.
  Idempotent: once applied the precondition is empty, so re-running is a no-op.

### v3.1.0 — repo profile marker back-fill

- **What & why:** repos now carry a **profile** marker (`<!-- steer:profile=app -->`,
  or `infra`/`service`/`library`/`cli`) on the `CLAUDE.md` `## Profile` section,
  read by `/steer:sync` and `scripts/scan-capabilities.sh` to decide which scaffold
  overlay applies. A repo bootstrapped before profiles has no marker. Readers
  default a missing marker to `app` (every pre-profiles repo was an app monorepo),
  so this is not a *capability gap* (nothing is broken) — but stamping the marker
  makes the profile explicit and lets a later profile change be a deliberate edit.
  It is an **in-file write into an existing materialized file** (CLAUDE.md), not a
  new file, so it belongs here rather than on the capability axis.
- **Precondition:** `CLAUDE.md` exists and carries no profile marker — this grep
  fires:

  ```sh
  test -f CLAUDE.md && ! grep -qiE '<!--[[:space:]]*steer:profile=' CLAUDE.md && echo pending
  ```

  No `CLAUDE.md`, or a marker already present ⇒ no-op.
- **Action:** read-then-propose. Add a `## Profile` section carrying
  `<!-- steer:profile=app -->` (the safe default — only change it to another
  profile if the repo is *clearly* infra/library/cli/service and the dev confirms),
  modeled on `templates/scaffold/CLAUDE.md`. Place it near the `## Delivery mode`
  section. Idempotent: once the marker is present the precondition is empty, so
  re-running is a no-op.

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

### v1.25.0 — standalone `SPEC-QUESTIONS.md` retired; open questions move into the spine

- **What & why:** open questions used to accumulate in a standalone
  `spec/SPEC-QUESTIONS.md`. v1.25.0 retired it so questions live next to their
  context — per feature in `spec/features/*/intent.md` → `## Open questions`,
  product-level in `spec/vision.md` → `## Open questions` (and, when present,
  `spec/PRODUCTIONIZATION.md`). A fork from an older template revision still
  carries the file; additive reconciliation cannot delete it, so only a
  migration may. The SessionStart hook (`check-open-questions.sh`) surfaces the
  retired file every session, and **`/steer:questions` (default mode) applies
  this entry as a hard gate before its sweep** — so the heal usually happens on
  first touch rather than waiting for a sync. `/steer:questions bundle` is
  read-only and never applies it: it includes the file's `## Open` items in its
  gather untouched, with a notice to run the default `/steer:questions` first.
- **Precondition:** the retired file exists — this check fires:

  ```sh
  test -f spec/SPEC-QUESTIONS.md && echo pending
  ```

  No file ⇒ no-op.
- **Action:** migrate **and delete**, read-then-propose — a **move, not an
  answer**: never invent or resolve anything while migrating, and the deletion
  does **not** wait on the questions being answered. Do not skip it because the
  spine's `## Open questions` sections look empty — empty/placeholder sections
  are exactly the pre-state this migration fills.
  - Route each `## Open` item to its context: a question tied to a specific
    feature → that feature's `spec/features/*/intent.md` → `## Open questions`;
    anything product-level → `spec/vision.md` → `## Open questions`. Preserve
    each item's Context / Options / Owner notes; create the `## Open questions`
    section in the destination if it's absent.
  - For each `## Resolved` item: if the decision is already reflected in the
    owning `intent.md` / `contract.md`, drop it; otherwise fold the decision
    there first so it isn't lost.
  - Propose the migration (which items land where) **and the deletion
    together**; on a yes apply it and delete the file
    (`git rm spec/SPEC-QUESTIONS.md`). **Never keep the file alive as a working
    store** — do not "update it in place," move resolved items into its
    `## Resolved` section, leave deferred items under its `## Open`, or defer
    the retirement to "a later step." Its continued existence after the
    migration runs is a failure, not a deferral; only the migrated copies in
    the spine survive.

  Idempotent: once the file is gone the precondition is empty, so re-running
  is a no-op.

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

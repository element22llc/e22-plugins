# Spec-spine migration ledger

Append-only, ordered record of **non-additive** structural changes to the spec
spine and bundled scaffold — renames, moves, deletions, default changes,
**in-file token rewrites** (replacing a string that already exists in a
materialized file), and **whole-file or whole-section re-takes** that
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
conventions change, and `/steer:adopt` consumes the same entries so a repo first
touched under an older plugin version picks up structural changes too — not just
additive ones. `/steer:build` has no ledger step of its own: it reaches these
transforms by handing off to `/steer:adopt`. **Add an entry here in the same change
that lands any non-additive transform** — a rename, move, deletion, default change,
in-file token rewrite, or whole-file/whole-section re-take — in `templates/spec/` or
`templates/scaffold/`; do not hand-code the transform inline in a skill. The test is
not "did a file move" but **"can additive reconciliation carry it?"** — it splices in
what is missing and never rewrites, reorders, or deletes, so *replacing an existing
line* in a materialized file needs an entry just as much as moving the file does. A
procedural instruction a skill or a human then follows (a step in
`spec/tracker.md`, a documented command in a profile `README.md`) is squarely in
scope: leaving the old wording in place keeps the consumer executing the behaviour
the change exists to remove. **Below the bar:** a comment or prose line that only
*describes* behaviour — one no skill reads and no human executes — needs no entry,
even though it is technically a replaced line. The distinguishing question is whether
anything acts on the words.

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

**Author a new entry as `### [Unreleased] — <what>`, never a guessed version
number.** An entry lands in an implementation PR, which merges *before* the
release that names it, so the introducing version is not knowable at authoring
time — and guessing it is not a cosmetic error. A key **below** the version the
entry actually shipped in is silently **skipped** by every repo stamped in
between (they read it as "at or below the stamp"), so the migration never runs
and nothing reports it. The release renames this heading to `### vX.Y.Z` in the
same PR that bumps `plugin.json` — exactly as it renames `CHANGELOG.md`'s
`### [Unreleased]`. Forgetting the rename is safe and self-correcting: an
`[Unreleased]` heading is never "at or below" any stamp, so the entry is always
walked and applied by its precondition. A guessed number is the only unsafe
option.

All migrations follow the spine discipline: **read-then-propose, never clobber**,
preserve filled-in content, and land on a `feat/*` branch through a PR. Use
`git mv` (not copy+delete) for renames so history follows the file. An **in-file
token rewrite** is read-then-propose too: scan only the exact old→new pairs the
entry lists, show the diff, and replace **only** those tokens — never a broader
regex, never a string the entry doesn't enumerate. Its precondition must be a grep
that fires only while a stale token is still present and that cannot match a
legitimate look-alike (e.g. an unchanged marketplace id).

The fourth action class is a **whole-file or whole-section re-take**: the entry names
a shipped file — or one delimited region inside it — whose *content* has moved on so
far that no enumerable set of old→new pairs describes it, so the current template
version replaces that whole file or region. A section re-take must say where the
region starts and ends (a heading, a comment banner, a table) so the replacement is
bounded and re-runnable; everything outside it is left untouched. It is
read-then-propose like every other class — **show the diff, never a blind
overwrite** — and it must **carry the consumer's own edits forward** rather than
discard them. Reserve it for a file additive reconciliation cannot reach (that
splices in what is missing and never rewrites or deletes) and that is *not* a
`verbatim` capability file — a `verbatim` file is re-copied by
[`CAPABILITIES.md`](CAPABILITIES.md)'s own repair path and needs no ledger entry.
Name the file and say what to carry forward.

## Entries

> Newest first. Each entry: the introducing **version** — `[Unreleased]` until the
> release renames it, never a guessed number — **what & why**, a **precondition**
> (apply only if true), and the **action**.

### [Unreleased] — `feature_status` narrows to `draft · approved · live`

- **What & why:** a feature's spec `> Status:` used to carry five values
  (`draft · approved · implemented · validated · live`) and was declared *derived*
  from the issue `steer:state` — but it was stored in `intent.md` and hand-edited, so
  it was a derived value nobody recomputed. Seven of the crosswalk's nine rows added
  no information the issue did not already hold, while every merge, close, and reopen
  had to be replayed by hand into a second file. `implemented` and `validated` are
  therefore **retired**: they were pure mirrors of issue `validate`/`done`. The spec
  now stores only the two facts no issue state implies — the PO approved this scope
  (`approved`) and users can see it (`live`) — so `Status:` moves at exactly two human
  events and a merged PR can no longer leave it stale.
- **Precondition:** apply only if some `spec/features/*/intent.md` carries
  `> Status: implemented` or `> Status: validated`, **or** its `> Status:` line still
  lists the five-value enum. A spine whose intents are all already
  `draft`/`approved`/`live` **and** whose template line reads the three-value enum is
  migrated; skip it.
- **Action:**
  1. **Rewrite the retired values**, one file at a time, mapping by what the value
     actually meant:
     - `Status: implemented` → **`approved`** (it was built but not released; the
       build is the issue's business, and the scope approval is what the spec holds).
     - `Status: validated` → **`approved`** — *unless* the feature is genuinely
       released to users, in which case **`live`**. Do **not** assume accepted ==
       released; `validated` conflated the two, which is why it is going away. When
       the release state is not evident from the repo (no deploy, no release notes in
       `/spec/app/`, no `live` sibling), take `approved` and **say so in the sync PR**
       so a human can promote it — never guess `live`.
  2. **Rewrite the enum hint** on the `> Status:` line of every `intent.md` and of
     `spec/features/*/intent.md` templates carried locally: the five-value list
     becomes `draft | approved | live`, with the parenthetical from
     `${CLAUDE_PLUGIN_ROOT}/templates/spec/feature-intent.md` (product state only —
     delivery progress lives on the tracker issue).
  3. **Touch no issue.** This migration is spec-side only: `steer:state` markers are
     already the lifecycle store and are correct as they stand. A feature whose intent
     now reads `approved` while its issue reads `done` is the **intended** pairing, not
     drift to repair.
  4. **Leave the PO-acceptance checkboxes alone**, including *PO validated the working
     demo* — that record moves to the checkbox and is unaffected by the `Status:`
     rewrite.
- **Polyrepo:** `spec/features/**` is the **workspace's**, so a member applies none of
  this locally — resolve the workspace and migrate there, or note it in the PR when
  `workspace.path` does not resolve.

### v4.0.0 — `spec/HISTORY.md` → `spec/history/`, one immutable file per entry

- **What & why:** the action history was a single append-only, newest-first file, so
  **every** PR inserted its entry at the same anchor (the top of `## Entries`) and every
  pair of concurrent changes conflicted there. The conflict is positional, not
  content-based — two entries dated the same day are no more likely to collide than two
  dated a week apart — so date/time granularity cannot fix it. Nor can git's `union`
  merge driver, the obvious cheap fix: union is **line**-based, and when two entries
  share a trailing line (`- **Areas:** apps/web` is the common case, since `Areas` is the
  template's last field) it splices the two blocks together and **silently drops a
  field**, producing a clean merge with no conflict markers that no reviewer ever
  sees — data loss in the artifact whose entire purpose is review evidence. The history
  is therefore a **directory**: one entry per file at
  `spec/history/YYYY-MM-DD-HHMM-<slug>.md`, so two concurrent PRs write different paths
  and cannot conflict at all. Additive reconciliation cannot carry this — it splices
  missing sections into existing files and never creates a directory, relocates an
  artifact, or rewrites the CI regex and PR-template checkbox that name the old path.
- **The old file is FROZEN, not moved and not split.** `spec/HISTORY.md` stays exactly
  where it is as the pre-migration archive. Do **not** mechanically split its entries
  into per-file records: those entries are immutable evidence, and a bulk rewrite would
  re-date them, risk mangling them, and destroy the very audit property the log exists
  for. New entries go in the directory; anything older is read from the archive.
- **Precondition:** the repo still has the single-file shape, **or** a live instruction
  surface still routes writes to the old path. Once applied, re-running is a no-op:

  ```sh
  { test -f spec/HISTORY.md && ! test -d spec/history && echo pending; }
  grep -lE '/?spec/HISTORY\.md' \
    .github/workflows/ci.yml .github/pull_request_template.md README.md \
    spec/tracker.md 2>/dev/null
  grep -lE '`HISTORY\.md`|\[HISTORY entry' \
    CLAUDE.md spec/PRODUCT.md spec/sources/*/source.md 2>/dev/null
  ```

  All three empty ⇒ already migrated (or a repo that never migrated a spine) ⇒ no-op.
  The greps are scoped to those **live** files on purpose: after the migration the only
  legitimate mentions of `spec/HISTORY.md` left in the repo are the archive pointer in
  `spec/history/README.md` and the frozen banner in the archive itself, so a
  repo-wide grep would never converge.

  **Two greps, because the stale token is not the same string in every file.** Four of
  the seven surfaces name the full path `spec/HISTORY.md`; the other three do not, and a
  single pattern silently skipped them — `CLAUDE.md` and `spec/PRODUCT.md` carry a bare
  `` `HISTORY.md` `` and `spec/sources/*/source.md` carries `[HISTORY entry · …]`. That
  mattered because the shape check goes quiet as soon as step 1 creates the directory, so
  a partially-applied step 3 would converge to "already migrated" with the stale prose
  still in place — and a **polyrepo member** has no local `spec/HISTORY.md` at all, which
  leaves the grep as the only detector. Both patterns are case-sensitive and both clear
  after step 3 rewrites them (`spec/history/`, and a lower-case `[history entry`).
  **`ci.yml` stays on the first grep's original pattern** — the unescaped-token invariant
  below depends on it.

  **The first grep matches an *unescaped* token only, and that is what makes this entry
  idempotent.** The post-migration `ci.yml` deliberately keeps the old path in its
  `spec-drift` filter as the regex literal `^spec/HISTORY\.md$` (so a repo mid-migration
  is not flagged) — the backslash means the precondition's `HISTORY\.md` does not match
  it. The corollary is a **standing constraint on the bundled `ci.yml`**: the legacy path
  may appear there only inside that regex, never as a bare token in a YAML comment or
  operator message, or step 3 would copy a self-matching file into every migrated repo
  and the entry would report `pending` forever — re-minting a duplicate step-4 history
  entry on every `/steer:sync`. `check_standards.py` enforces this invariant on the
  bundled template so it cannot regress.
- **Action:** read-then-propose, show the diff first.
  1. **Create the directory** and materialize `spec/history/README.md` from
     `${CLAUDE_PLUGIN_ROOT}/templates/spec/history-readme.md` (the format doc: naming,
     immutability, why it is a directory, and the archive pointer). Resolve
     `[Product Name]` from the repo's existing `spec/vision.md` or `CLAUDE.md` rather
     than leaving the placeholder.
  2. **Freeze the archive** — the one edit to `spec/HISTORY.md`, bounded to its **header
     prose above `## Entries`**: add a line stating the file is the frozen pre-migration
     archive and that new entries go in `spec/history/`. **Touch no entry**, do not
     re-order, re-date, or delete anything below `## Entries`, and do not add an entry
     here. If the repo has no `spec/HISTORY.md` at all (a spine materialized without
     one), skip this step — there is nothing to freeze.
  3. **Rewrite the path in the live instruction surfaces** — an in-file token rewrite,
     only in these files, which additive reconciliation cannot reach (both `ci.yml` and
     the PR template are `Verbatim: no` under the `drift-gate` capability, so nothing
     re-copies them):

     | File | What changes |
     |---|---|
     | `.github/workflows/ci.yml` | the `spec-drift` job's path filter — add `^spec/history/[0-9][^/]*\.md$` to the `grep -E` alternation (date-prefixed **entries** only, so editing the directory's `README.md` format doc does not clear the gate), **keeping** `^spec/HISTORY\.md$` so a repo mid-migration is not flagged — plus the two operator messages naming the old path, **and the comment block above the filter**, which is worded to carry no bare `spec/HISTORY.md` token (see the precondition note above). Take the whole block verbatim from `${CLAUDE_PLUGIN_ROOT}/templates/github/workflows/ci.yml` — do not re-word it. |
     | `.github/pull_request_template.md` | the living-docs checkbox: `/spec/HISTORY.md` has an entry → a `/spec/history/` entry exists — **only if this PR is a notable event**; an ordinary change needs none. Take the wording verbatim from `${CLAUDE_PLUGIN_ROOT}/templates/github/pull_request_template.md` so the installed checkbox does not re-teach the retired per-change obligation. |
     | `README.md` | the "Action history" link target: `./spec/HISTORY.md` → `./spec/history/`. |
     | `CLAUDE.md` | the `/spec/**` pointer listing `HISTORY.md` → `spec/history/`. |
     | `spec/tracker.md` | the traceability bullet — "every `/spec/HISTORY.md` entry lists the tracker ref" → "every `/spec/history/` entry". |
     | `spec/sources/*/source.md` | the absorbed-versions table's `[HISTORY entry · …]` cell → `[history entry · …]`. One file per tracked source — `/steer:intake` instantiates the source-manifest template as `spec/sources/<source-id>/source.md`, never as a root `spec/source-manifest.md`. |
     | `spec/PRODUCT.md` | (polyrepo members only) the ownership row listing `HISTORY.md` among the workspace-owned artifacts → `spec/history/`. |

     **Leave `.github/copilot-instructions.md` and `.github/prompts/*` alone** — they are
     `Verbatim: yes` under the `copilot-surface-current` capability and are re-copied
     from the plugin on the same sync, so rewriting them here would be undone and is
     unnecessary.
  4. **Log the migration as the directory's first entry.** A spine migration is a
     repo-level event, which is exactly what earns an entry, so write
     `spec/history/<date>-<time>-action-history-becomes-a-directory.md`
     from `${CLAUDE_PLUGIN_ROOT}/templates/spec/history-entry.md`, with
     `Requested by: adoption/audit finding` and `Areas: spec-only`. (An ordinary merged
     change would write none — the entry is earned by the event, not by the PR.) This
     both satisfies the living-docs rule for the migration PR and proves the new path
     works.
  5. **Polyrepo:** the action history belongs to the **workspace**, not a member
     (`/steer:reference polyrepo`). Apply steps 1, 2 and 4 in the workspace repo only; in
     a member apply step 3's `CLAUDE.md` / `spec/PRODUCT.md` / PR-template / `ci.yml`
     rewrites and create **no** local `spec/history/`.

  **False-positive guard:** never rewrite the path inside append-only or provenance prose
  — the archive's own entries, `spec/AUDIT-REPORT.md`, `spec/DRIFT-REPORT.md`, ADRs under
  `spec/decisions/`, or a feature `intent.md` provenance line — where a mention of
  `spec/HISTORY.md` is a legitimate record of where something was written at the time. If
  the repo already has a `spec/history/` directory containing entries **and** an
  unfrozen `HISTORY.md` still being appended to, do not merge them: report both and let
  the dev say which is current. Idempotent — once the directory exists and the live
  surfaces name it, both precondition checks are empty.

### v3.24.0 — `PRODUCTIONIZATION.md`'s open-question seed becomes a `### Q-NNN` block

- **What & why:** the `## Open questions` seed in `spec/PRODUCTIONIZATION.md` was a single
  bracketed **bullet**. Both the SessionStart open-questions hook and `/steer:questions`
  parse `### Q-NNN` blocks only, so a question written as a plain bullet — which is
  exactly what that seed modelled — is counted by **neither**: it never ages into the
  14-day blocking escalation and never appears in a sweep. The seed is now prose plus a
  `### Q-001` field block carrying `created:`/`status:`/`impact:`/`owner:`/
  `required_before:`/`tracker:`, marked `<!-- steer:placeholder -->` so the hook ignores
  it until filled in. Reconciliation **provably cannot** carry this: the diff helper
  extracts anchors with `grep -hE '^(#{2,3} |- \[)'` and then drops every
  `steer:placeholder` line, so the new `### Q-001` anchor is stripped from the bundled
  side, the new prose is not an anchor at all, and the old bullet is already present on
  the consumer's side — the comparison output is empty and the step is a no-op.
- **Precondition:** the repo has a materialized `spec/PRODUCTIONIZATION.md` still
  carrying the bullet seed. Once applied, re-running is a no-op:

  ```sh
  grep -n 'Dev-facing hardening ambiguities surfaced during adoption\.\]' spec/PRODUCTIONIZATION.md 2>/dev/null
  ```

- **Action — an in-file token rewrite**, one pair, read-then-propose as a diff:
  1. Replace the bracketed bullet line (it begins `- [Dev-facing hardening ambiguities
     surfaced during adoption.]`) with the current template's `## Open questions` body,
     taken verbatim from `${CLAUDE_PLUGIN_ROOT}/templates/spec/productionization.md` —
     the two prose paragraphs, the `### Q-001` placeholder block, and its `_Resolution:_`
     line.
  2. **Leave every real question alone.** If the repo already wrote its own questions
     under this heading in *any* shape, splice the format guidance in and convert only
     the seed; never restructure a filled-in question, and never delete one.
  3. A repo whose `## Open questions` section is already `### Q-NNN`-shaped needs no edit.
  **False-positive guard:** apply only to the repo's own `spec/PRODUCTIONIZATION.md`,
  never to a `/spec/HISTORY.md` entry quoting the old seed, and never to a feature's
  `intent.md` (whose `## Open questions` is governed by the spec framework, not this
  entry).

### v3.24.0 — a member resolves the spine on the workspace *manifest*, not a directory

- **What & why:** `spec/PRODUCT.md`'s spine-resolution ladder said step 1 was
  "`workspace.path` set **and the directory exists**". A relative `path` resolves
  against the repo's **primary checkout**, so from a linked worktree
  (`.claude/worktrees/<name>`) the recommended `..` lands on a real but **empty**
  directory — the test passed, the spine read as present, and every skill resolving
  it from that member saw an empty tree and reported the product's specs as absent.
  The ladder now requires `spec/workspace.yml` **at** that path, resolves against the
  primary checkout, and treats a resolved path with no manifest as *no local
  checkout* (so step 2's gateway route fires instead). `spec/PRODUCT.md` is
  materialized in **every** polyrepo member. Additive reconciliation cannot carry it:
  `template-reconcile.sh` anchors on `##`/`###` headings and `- [` items, so a
  rewritten numbered item under an unchanged `## Resolving the spine` heading offers
  no anchor at all.
- **Precondition:** the member's `spec/PRODUCT.md` still carries the directory-only
  test. Once applied, re-running is a no-op:

  ```sh
  grep -n 'the directory exists' spec/PRODUCT.md 2>/dev/null
  ```

- **Action — an in-file token rewrite**, one pair, read-then-propose as a diff:
  1. Replace step 1's line — `` `workspace.path` set and the directory exists → read
     the spine from there.`` — with the current template's step 1, taken verbatim from
     `${CLAUDE_PLUGIN_ROOT}/templates/spec/product.md`'s `## Resolving the spine`
     section (the manifest requirement, the primary-checkout resolution, and the
     no-manifest-means-no-local-checkout clause).
  2. **Leave steps 2 and 3 alone** — the gateway fallback and the stop-on-neither rule
     are unchanged, and step 3's split-brain warning is what step 1 now actually
     upholds.
  **False-positive guard:** rewrite only in a **member**'s own `spec/PRODUCT.md`
  (`workspace:` frontmatter present); a workspace host has no `PRODUCT.md`, and never
  touch a `/spec/HISTORY.md` entry quoting the old ladder as history.

### v3.24.0 — promoted questions keep their `### Q-NNN` block

- **What & why:** `spec/tracker.md`'s traceability rule told the reader that promoting
  an open question to a tracker item means **replacing the question with the ref**.
  The mechanism is now the opposite: the `### Q-NNN` block **stays**, and the ref goes
  in its `tracker:` field — the issue carries the same id via
  `<!-- steer:question-id=Q-NNN -->`, and that pair *is* the bidirectional link.
  `/steer:spec validate` **fails** a promoted question with no `tracker:` ref back, so
  a repo still following the old instruction deletes the block, loses the back-ref, and
  then hard-fails its own spec validation. `spec/tracker.md` is materialized at
  bootstrap and is the file `/steer:tracker-sync` reads first every run, so the stale
  sentence governs real behaviour. Additive reconciliation lists `tracker.md` but is
  additive-only, so it can never replace the sentence.
- **Precondition:** the repo's `spec/tracker.md` still carries the old instruction.
  Once applied, re-running is a no-op:

  ```sh
  grep -n 'replace the question with the ref' spec/tracker.md 2>/dev/null
  ```

- **Action — an in-file token rewrite**, one pair, read-then-propose as a diff:
  1. Replace `then replace the question with the ref.` with the current template's
     wording — "then put the ref in that question's `tracker:` field", followed by the
     **Keep the `### Q-NNN` block** sentence and its `/steer:spec validate`
     consequence. Take the replacement text verbatim from
     `${CLAUDE_PLUGIN_ROOT}/templates/spec/tracker.md`'s `## Conventions (summary)`
     section so the two stay identical.
  2. **Leave the rest of the bullet alone** — the 14-day blocking-question escalation
     and the Owners-map routing are unchanged.
  3. If the repo already has questions that were promoted *and deleted* under the old
     rule, say so and stop short of inventing them: the blocks are gone and only a
     human knows which issues they became. Report the promoted issues carrying a
     `steer:question-id` comment with no matching block, and let the dev restore them.
  **False-positive guard:** rewrite only in the repo's own `spec/tracker.md`, never in
  a member's copy from inside a workspace checkout, and never in `/spec/HISTORY.md`
  prose that quotes the old rule as history.

### v3.24.0 — `COMPOSE_PROJECT_NAME` gains a repo prefix in linked worktrees

- **What & why:** `scripts/worktree-env.sh` derived `COMPOSE_PROJECT_NAME` from the
  checkout's **bare basename**. A worktree's basename is the *worktree's* name
  (`feat-x`), which is not unique across repos — so in a polyrepo running the same
  branch in two members, `<memberA>/.claude/worktrees/feat-x` and
  `<memberB>/.claude/worktrees/feat-x` drew the **same** Compose project, and
  therefore the same containers, volumes and networks. `mise run docker:clean`
  (`down --volumes --remove-orphans`) in one member's worktree tore down the
  **other** member's stack — the precise failure this file exists to prevent, and
  distinct port offsets do not help because the collision is in the namespace, not
  the ports. A **linked** worktree's identity is now `<repo>-<worktree>`; a primary
  checkout keeps its bare basename and is **not** renamed. Additive reconciliation
  cannot carry this: it splices in what is missing and never rewrites an existing
  assignment, and `worktree-port-isolation` is `Verbatim: no` with a *create*-only
  repair (`CAPABILITIES.md`), so an already-scaffolded repo keeps the colliding name
  until this entry is applied.
- **Precondition:** `scripts/worktree-env.sh` exists and still lacks the owning-repo
  prefix logic. Once applied, re-running is a no-op:

  ```sh
  test -f scripts/worktree-env.sh && ! grep -q '_wt_owner' scripts/worktree-env.sh
  ```

- **Action — a whole-section re-take**, not a whole-file one: the file's host-port
  baseline below this section is explicitly the product's to adapt, so replacing the
  file would discard real customization.
  1. **Tear down any running linked-worktree stack FIRST.** Under the new name
     compose no longer sees the old containers or volumes and they are orphaned. In
     each linked worktree with a running stack, run `mise run docker:clean` (or
     `docker compose -p <old-name> down -v`) **before** applying this entry. A
     primary checkout needs nothing — its name does not change.
  2. Replace the whole **worktree-identity plumbing** region, read-then-propose as a
     diff. Bound it by two lines that are byte-identical in the old file and the new
     one, so the region is locatable in the file you are transforming:
     - **starts at** the line `_wt_root=$(git rev-parse --show-toplevel 2>/dev/null)
       || _wt_root=$PWD`, together with the explanatory comment block immediately
       above it;
     - **ends at** the line `export COMPOSE_PROJECT_NAME="$_wt_name"`.

     The region **must** span that whole span, not just the Compose-name part: the
     new naming logic branches on `_wt_linked`, and **`_wt_linked` does not exist in
     the old file at all** — it was introduced by this same change, replacing an
     inline `--git-dir`/`--git-common-dir` test that lived in the port-offset
     `elif`. Swapping only the naming block would leave `_wt_linked` unset, so
     `[ "$_wt_linked" = 1 ]` is false, the repo silently keeps the bare basename —
     the exact behaviour this entry exists to remove — and the precondition below
     then reports the migration as already applied. The region as bounded above
     carries all three pieces together: the `_wt_root`/`_wt_gitdir`/`_wt_common`
     lookups, the `_wt_linked` derivation, the port-offset block that branches on
     it, and the Compose-name derivation and export.
  3. **Leave everything below `export COMPOSE_PROJECT_NAME=` alone** — in particular
     the `BASELINE: default-stack host ports` block, which a product is invited to
     adapt to its own services, and which consumes `_wt_offset` that the replaced
     region still sets. If a consumer has edited the plumbing region itself (an
     added lookup, a changed offset formula), carry those edits forward into the new
     version rather than dropping them — and if the two cannot be reconciled
     mechanically, show both and ask.
  **False-positive guard:** apply only to the repo's own
  `scripts/worktree-env.sh` at the repo root, never a member's copy from inside a
  workspace checkout, and never a file a consumer has rewritten to derive the project
  name some other deliberate way — if `_wt_owner` is absent but the export is
  visibly hand-authored, report it and stop rather than replacing it.

### v3.24.0 — workspace profile: whole-product `mise` tasks namespaced under `ws:`

- **What & why:** in a **workspace** (polyrepo spine) repo the root `mise.toml` is an
  *ancestor config* of every member cloned inside it, so an unprefixed task name
  shadows any member that does not define that name itself. Unprefixed, `mise run
  dev` inside a member booted the **whole product**, and `mise run docker:clean` in a
  member that ships no `compose.yaml` dropped **every** member's volumes — the
  cleanup rule `24-worktrees` tells every agent to run before removing a worktree.
  The workspace profile therefore renamed its whole-product tasks: `dev` → `ws:dev`
  and `docker:up` / `docker:down` / `docker:clean` → `ws:docker:*` (`convert:doc` is
  the one deliberate exception). The always-on rules moved with it — `15-commands`,
  `24-worktrees` and `99-end-of-session` now name the `ws:` forms — so an
  **already-scaffolded** workspace repo receives injected rules naming tasks its
  `mise.toml` does not define until this migration is applied. Additive
  reconciliation cannot carry it: it splices in what is missing and never renames or
  deletes, so it would leave both the old and the new task names in place.
  **Workspace-profile repos only** — a repo whose `## Profile` marker is `app` or
  `infra` has no `ws:*` tasks and must be left alone.
- **Precondition:** the repo's `## Profile` marker (in `CLAUDE.md`) is `workspace`
  **and** its root `mise.toml` still defines any of `[tasks.dev]`,
  `[tasks."docker:up"]`, `[tasks."docker:down"]`, `[tasks."docker:clean"]`. Once
  applied, only the `ws:`-prefixed forms remain and re-running is a no-op:

  ```sh
  grep -nE '^\[tasks\.(dev|"docker:(up|down|clean)")\]' mise.toml 2>/dev/null
  ```

- **Action:** read-then-propose an **in-file rename** in the workspace repo's root
  `mise.toml`, then re-take one script. Show the diff first; never clobber a
  dev-added task.
  1. Rename the four table headers, longest/most-specific first:
     `[tasks."docker:clean"]` → `[tasks."ws:docker:clean"]`,
     `[tasks."docker:down"]` → `[tasks."ws:docker:down"]`,
     `[tasks."docker:up"]` → `[tasks."ws:docker:up"]`, `[tasks.dev]` →
     `[tasks."ws:dev"]`. **Leave `convert:doc` unprefixed.**
  2. Repoint every **task-addressing** reference to a renamed task — there are three,
     and the two commented ones matter as much as the live one. (A fourth mention
     lives inside `ws:docker:up`'s `run[0]` guard *message*; step 4 owns that one.)
     - `ws:dev`'s live `depends = ["docker:up"]` → `depends = ["ws:docker:up"]`. Not
       cosmetic: a bare `docker:up` in `depends` resolves in the **caller's** task
       set, so invoked from inside a member it binds to *that member's* task and boots
       only that member.
     - the commented copy-paste template just above it,
       `#   depends = ["docker:up", "//frontend:dev", "//backend:dev"]` →
       `#   depends = ["ws:docker:up", …]`. This is the line the dev extends when
       enabling monorepo mode, so leaving it stale hands them the very
       caller-scope shadowing this migration exists to remove.
     - the `[env]` comment `` `mise run dev` `` → `` `mise run ws:dev` ``.
  2b. Rewrite the same task names in the **other three materialized workspace files**,
     same pairs, same profile-gated scope. These are not cosmetic: the README's
     quickstart is the command a human is told to run, and after the rename it names a
     task the repo no longer defines.
     - `README.md` (the workspace profile replaces the core one): **every**
       `mise run dev` → `mise run ws:dev` — the shipped template has **three**
       (the quickstart, the "before the first" note, and the atomic-cross-repo-commits
       note), not just the quickstart — plus any whole-product `docker:*` mention.
     - the workspace `mise.toml`'s `ws:dev` **`description`**: the old text claimed it
       boots "every member's dev server", which the task no longer does — replace it
       with the current template's ("Boot the product's backing services; add
       per-member `depends` (monorepo mode) for the dev servers"). Skip a description
       the consumer has edited.
     - `compose.yaml` (also profile-replaced): the header comment naming the tasks to
       delete alongside the file — `ws:docker:*` / `ws:dev`.
     - `.worktreeinclude`: the cleanup instruction naming `docker:clean` gains the
       `ws:docker:clean` form for a workspace host.
     Skip any of the three a consumer has clearly rewritten in their own words —
     report it and let them decide, rather than forcing the template's phrasing back.
  3. Re-take `scripts/ws.sh` **before** step 4, which repoints a task at its
     `preflight` subcommand: a repo at 3.23.0 has a `ws.sh` with **no `preflight`**
     (it arrived later in this same cycle), so taking the script first means no
     intermediate state ever points at a subcommand that does not exist. It also
     carries a stale reference of its own — a header comment naming `mise run dev` —
     and the new script's failure messages name the `ws:`-prefixed forms. Do it
     **read-then-propose, as a diff, not a verbatim overwrite** — `ws.sh` is not a
     `verbatim` capability file (only the version-pin scripts are — see
     [`CAPABILITIES.md`](CAPABILITIES.md)), so a consumer may have added their own
     `ws:` subcommand; carry those edits forward instead of clobbering them.
  4. Replace **only the first element** of `ws:docker:up`'s `run` array. A repo
     scaffolded at 3.23.0 or earlier has a two-element `run` whose `run[0]` is an
     inline `docker compose config >/dev/null 2>&1 || { printf '…' >&2; exit 1; }`
     guard — and that guard's own message names the **unprefixed** `docker:*` / `dev`
     tasks, so leaving it in place keeps the stale vocabulary this rename exists to
     remove. Replace that one element with `sh scripts/ws.sh preflight` — the same
     check with a better message, and present because step 3 took it.
     **Leave `run[1]` — `docker compose up -d --wait` — exactly as it is:** it is the
     only line that actually starts the stack, so replacing the whole array instead of
     its first element leaves the task unable to boot anything. Leave every *other*
     task's `run` alone, and never touch a filled-in value (a dev-added task, an edited
     description, a resolved `config_roots` list).
  5. **Replace the whole commented monorepo section, and move it above
     `[settings]`.** Scope this by *section*, not by the block alone: a repo scaffolded
     before this change carries the commented `# [settings]` / `# monorepo_root` /
     `# [monorepo]` block **below** the real `[settings]`, **and** ~15 lines of
     explanatory prose immediately above it (the comment that opens
     `# --- Monorepo task addressing …`). Both are template prose and both are wrong
     now, so **delete the entire run — prose and block — and re-insert the current
     template's version above `[settings]`**, carrying over only any `config_roots`
     member entries the dev filled in.

     Two things must not survive the move, and moving the block alone leaves both:

     - **The commented `# [settings]` header.** The file says "uncomment in place", so
       a dev who uncomments the moved-but-unreshaped block declares `[settings]`
       **twice** — the config then fails to parse at all (`Cannot declare ('settings',)
       twice`) and mise cannot load it. (Not a silent unknown-field warning: it is a
       hard, loud parse error. Either way monorepo mode never turns on, which is the
       defect this step exists to remove.)
     - **The `[monorepo].lockfile` guidance.** The old prose says to "Set it
       EXPLICITLY … `false`" and the old block ships `# lockfile = false`. The current
       template deliberately leaves the key **unset** — the pinned mise release
       rejects it outright (`unknown field: monorepo.?.lockfile`) and warns on every
       invocation. Keeping either the prose or the line re-introduces the advice.

     A repo that already has the section above `[settings]` needs no edit. A repo that
     has **already enabled** monorepo mode necessarily hand-repaired the nesting to get
     there — leave its live `[monorepo]` table alone and only reconcile the prose.
  Follow with additive [Template reconciliation](SPEC-FRAMEWORK.md) for the rest of
  the file. **False-positive guard:** rename only these four exact table headers and
  only in a `workspace`-profile repo's **root** `mise.toml` — never a member's own
  `mise.toml` (a member's `dev` / `docker:*` tasks are correct unprefixed), and never
  a `dev:setup` / `docker:*` task in an `app`/`infra` repo.

### v3.24.0 — nested `/infra` dir: S3 + DynamoDB state lock → native `use_lockfile`

- **What & why:** `infra/README.md`'s `## Conventions` told the reader the state backend
  is **S3 + DynamoDB locking**, and that "the bucket **and lock table** are bootstrapped
  once per environment"; its `root.hcl` sketch named the `remote_state` block as
  "(S3 + DynamoDB)". Always-on rule `12-stack-infra` mandates S3 with the **native
  `use_lockfile` lock** — S3 conditional writes replace the lock table. Both lines are
  **procedural**, not descriptive: a human follows the first to bootstrap an environment
  and the second to write `root.hcl`, so a repo still carrying them provisions and pays
  for a DynamoDB table the standard no longer wants, and authors a `remote_state` block
  that contradicts a rule injected into every session. `infra/README.md` is materialized
  into **every monorepo with a nested `/infra` dir** — `MANIFEST.md` marks that row
  conditional on the directory, and such a repo stays profile `app`, so this is *not* the
  `infra` profile. A root-level infra repo (profile `infra`) carries the same conventions
  in its **own README** instead (rule `12-stack-infra`: "Detail in `/infra/README.md`
  (monorepo) or the repo README"); this entry does not rewrite that file, so check it by
  hand if the repo is one. Additive reconciliation can never replace an existing line.
- **Precondition:** the repo's `infra/README.md` still carries one of the two *stale*
  tokens. Grep for those, **not** for `DynamoDB` on its own — the replacement text ends
  "No DynamoDB lock table is needed", so a bare `DynamoDB` grep fires forever and the
  entry would never converge. Once applied, re-running is a no-op:

  ```sh
  grep -nE 'S3 \+ DynamoDB|bucket and lock table' infra/README.md 2>/dev/null
  ```

- **Action — an in-file token rewrite**, two lines, read-then-propose as a diff. Take
  both replacements verbatim from
  `${CLAUDE_PLUGIN_ROOT}/templates/scaffold/infra/README.md` so the two stay identical:
  1. In `## Conventions`, replace the **State backend** bullet with the current
     template's — S3 with the native `use_lockfile` lock, the **bucket** (no longer "and
     lock table") bootstrapped once per environment, and the closing sentence "No
     DynamoDB lock table is needed — S3 conditional writes replace it."
  2. In the `root.hcl` paragraph, replace `(S3 + DynamoDB)` with
     `` (S3 + `use_lockfile = true`) ``.
  **False-positive guard:** rewrite only the repo's own `infra/README.md`, and **only the
  prose**. Do *not* touch a live `root.hcl`, `*.tf`, or `*.hcl` file — moving a real state
  backend off a DynamoDB lock table is an infrastructure change with its own plan, review,
  and blast radius, not a docs rewrite. If the repo's `root.hcl` still configures
  `dynamodb_table`, say so, land the prose fix, and hand the backend migration to the dev
  as separate work.

### v3.23.0 — `spec/design/architecture.md` → `spec/design/architecture-diagram.md`

- **What & why:** the living global architecture diagram shared a basename with
  the root `ARCHITECTURE.md` it is linked from, differing only by case and path.
  Two files called "architecture" at two altitudes read as a duplicate or a
  half-finished move, and the name also collided with the Tier 2 LikeC4 **model
  folder** `spec/design/architecture/` sitting right beside it. The diagram is
  now `spec/design/architecture-diagram.md`, so the three artifacts are legible
  by name: model folder `architecture/` → rendered diagram
  `architecture-diagram.md` → narrative `ARCHITECTURE.md`. The **split itself is
  unchanged** — the root file stays narrative + tables and still only links to
  the diagram; only the diagram's filename moves. The LikeC4 model folder keeps
  its name, and the `diagrams:render` task's paths are unaffected.
- **Precondition:** the repo still carries the old filename — this fires:

  ```sh
  test -f spec/design/architecture.md && echo pending
  ```

  Already renamed, or a repo that never materialized the file ⇒ no-op. If
  **both** names exist, do **not** merge or delete: surface the conflict and let
  the dev pick which is current.
- **Action:** `git mv spec/design/architecture.md
  spec/design/architecture-diagram.md` (never copy+delete — history follows the
  file). The file's own contents are unchanged.

  Then an **in-file token rewrite** across the repo's tracked text files for the
  exact pairs below — and only these; never a broader match, and never inside
  `CHANGELOG.md` or `spec/HISTORY.md`, whose entries are historical record:

  | Old | New |
  |---|---|
  | `spec/design/architecture.md` | `spec/design/architecture-diagram.md` |
  | `` `architecture.md` `` | `` `architecture-diagram.md` `` |

  Leave every `spec/design/architecture/` (no `.md`) path untouched — that is the
  LikeC4 model folder, which is **not** renamed. Show the diff before applying.
  Typical hit sites: root `ARCHITECTURE.md`, `README.md`, `CLAUDE.md`,
  `spec/design/README.md`, and the commented `diagrams:render` block in
  `mise.toml`.

  Idempotent: once the old filename is gone the precondition is empty, so
  re-running is a no-op.

### v3.23.0 — markitdown MCP server retired for the `convert:doc` task

- **What & why:** the `markitdown` MCP server has been removed from the plugin's
  `.mcp.json`. It existed for exactly one skill (`/steer:intake`), but a plugin
  MCP server starts automatically whenever the plugin is enabled — so every
  session paid a `uvx markitdown-mcp` subprocess, including the overwhelming
  majority that never convert a document. The same `markitdown` tool now runs
  on demand through the scaffold's `mise run convert:doc <file>` task, which
  `/steer:intake` already treated as its deterministic committable path — so
  capability is unchanged and only the always-on cost goes away. The plugin's
  own copy refreshes on `/plugin update`, but two *materialized* per-repo files
  can still name the dead server: `.vscode/mcp.json` (the Copilot mirror, which
  the scaffold installs) and, on a repo that predates v2.11.0, a repo-local
  `.mcp.json`. Additive reconciliation cannot remove a key, so this is a
  migration.
- **Precondition:** a materialized MCP config still names markitdown — this grep
  fires:

  ```sh
  grep -lE '"markitdown"|markitdown-mcp' .mcp.json .vscode/mcp.json 2>/dev/null
  ```

  No output ⇒ already migrated (or never had it) ⇒ no-op.
- **Action:** read-then-propose, show the diff first. In each file that matched,
  remove **only** the `markitdown` server entry, preserving every other server
  and value — never clobber a dev-added entry.
  - In `.vscode/mcp.json`, drop the `markitdown` key from `servers`. The rest of
    the file stays as-is. Note this file is **yours** once installed — it is
    seeded from the plugin's `.mcp.json` but sits outside `/steer:sync`'s
    `copilot-surface-current` capability, so nothing reconciles or re-copies it
    afterwards; a one-shot ledger entry like this one is the only thing that
    amends it.
  - In a repo-local `.mcp.json`, drop the `markitdown` key. If removing it
    leaves the file with **no** servers, `git rm` it — the plugin provides what
    remains (see the v2.11.0 entry, which removes the duplicated `github` key on
    the same file).

  A stale entry is harmless while it lasts — it just starts a server nothing
  calls — so this migration is a cleanup, never a blocker. Idempotent: once the
  key is gone the precondition is empty, so re-running is a no-op.

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
  (`spec/HISTORY.md`, `spec/AUDIT-REPORT.md`, `spec/DRIFT-REPORT.md`, ADRs, feature `intent.md` provenance), where a
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

### [Unreleased] — <one-line what>

(Heading stays `[Unreleased]`; the release PR renames it to `### vX.Y.Z`.)

- **What & why:** <the structural change and the reason a repo must follow it>
- **Precondition:** <a check that is true only while the migration is still
  pending — e.g. "spec/OLD.md exists", "spec/features/*/spec.md exists">
- **Action:** <the concrete transform — `git mv …`, move/merge, delete, an
  **in-file token rewrite** (an explicit list of old→new string pairs replaced in
  place across named files, with a false-positive guard), or a **whole-file or
  whole-section re-take** (the current template replaces the named file or bounded
  region; state the region's boundaries and what to carry forward) — applied
  read-then-propose, never clobbering filled-in content; follow with additive
  reconciliation if a renamed file is also template-tracked>

-->

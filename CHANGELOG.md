# Changelog

All notable changes to the `e22-plugins` marketplace. Each plugin is versioned
in its own `.claude-plugin/plugin.json`; this file records what changed and when.

## e22-standards

### 1.28.0

- **`/e22-drift` verdicts are now status-aware, and `🟠 Partial` is a first-class
  verdict.** A drift run against a tracker whose work is mostly open would
  previously flatten every unbuilt unit to `🔴 Missing` with no way to tell a real
  conformance failure from normal backlog — and reviewers smuggled in ad-hoc
  compound verdicts ("Partial / Missing") at epic grain to cope with mixed
  acceptance criteria. Both are now codified:
  - **Tracker status gates Missing.** Phase 1 captures each unit's status
    (Backlog / To Do / In Progress / Done / …). In Phase 2, **Done-but-Missing =
    true drift / defect** (the priority signal of the audit) while
    **Backlog/To-Do-but-Missing = unbuilt roadmap, expected, not drift** — the
    latter no longer generates `spec-drift` issues. The report leads with the
    real-drift findings so expected-Missing volume can't bury them.
  - **New `🟠 Partial` verdict** for a single unit whose acceptance criteria are
    split (some met, some Missing/Diverged), naming which criteria fall on each
    side. Verdicts are assigned **per unit, not per epic** — an epic is a rollup
    reported as a *verdict spread*, never collapsed to one cell or a compound.
  - **Verdict emoji denotes *kind*, not *severity*** — don't reuse `🔴` to mark a
    "critical" Diverged finding (it collides with Missing); carry severity in a
    separate marker.
  - Coverage table gains a **tracker-status column** so Done-but-Missing reads
    differently from Backlog-but-Missing at a glance.
  - Updated `skills/e22-drift/SKILL.md` only (no `commands/` alias change).

### 1.27.0

- **`/e22-drift` is now a spec-vs-spec diff that *consumes* `/e22-adopt`, not its
  inverse.** 1.24.0 framed drift as "the inverse of `/e22-adopt`" — a spec
  already exists, audit the code against it — and had it compare **code** against
  the `/spec` spine **plus a batch of source tickets**. That's the wrong axis for
  the actual workflow: run `/e22-adopt` to reverse-engineer the **as-built spec**
  from the code (a faithful picture of what the product *does*), then compare that
  as-built spec against the **tracker spec** (what it was *supposed* to do,
  exported as markdown from whatever issue tracker the team uses). Adopt and drift
  are **sequential stages of one flow**, not opposites — drift consumes adopt's
  output. Reworked:
  - **New comparison axis: as-built `/spec` ↔ tracker spec** (pure spec-vs-spec).
    The as-built spec stands in for the code (its `contract.md` sections were
    derived from the real code and carry the `path:line` pointers), so drift cites
    that evidence rather than re-auditing code from scratch.
  - **Tracker-agnostic markdown export is a first-class input, decomposed by
    grain.** The intended spec is exported from any issue tracker — **Jira,
    Linear, GitHub Issues, …** — as markdown; the skill never hardcodes one
    vendor. Phase 1 parses the export — **one file per epic/issue or per
    story/task** — fanning a coarse-grained file out into its constituent
    sub-items + acceptance criteria, normalizing each to an intended-behavior unit
    (tracker key/title kept for traceability).
  - **New verdicts** matched to the spec-vs-spec direction (as-built = reality,
    tracker = intent): ✅ Matches / ⚠️ Diverged / 🔴 Missing (tracker asked, not built) /
    🟡 Unspecified (built, never asked) / ❓ Ambiguous — replacing the old
    Conforms/Drifted/Missing/Extra/Ambiguous code-audit verdicts.
  - **Guard: redirect to `/e22-adopt` when there's no `/spec` spine** — there's no
    as-built spec to diff against until the code has been reverse-engineered.
  - Still **report + propose only** — no code/spec edits, Rule-5 resolution per
    finding (PO vs dev approval noted), `spec-drift` issues for decisions,
    ambiguities to `## Open questions` for `/e22-questions`.
  - Updated `skills/e22-drift/SKILL.md`, the `commands/e22-drift.md` alias, and the
    router (`rules/00-router.md`). The 1.24.0 entry below is left intact as a
    record of what shipped then; this entry supersedes its framing.

### 1.26.0

- **Detect greenfield repos that have no spec spine — push the bootstrap.** A
  brand-new repo with the plugin enabled but no `/spec` (code written from
  scratch with the standards active, but never forked from the template) fell
  through every existing path: the always-on rules were injected, but nothing
  *pushed* the spec-first bootstrap, so sessions silently degraded to toolchain
  conventions only — feature code written ahead of any vision/intent/contract.
  New `hooks/check-unmanaged-repo.sh` (SessionStart) fires when there's no
  `/spec` spine, presenting both bootstrap routes (greenfield `/e22-init` vs
  reverse-engineering `/e22-adopt`) rather than guessing from code volume.
  Fail-soft, silent once `/spec` exists (self-clearing), and silent in the
  plugin's own repo (`.claude-plugin/` guard). Registered after
  `check-open-questions.sh` in `hooks/hooks.json`.
- **Point-of-action nudge when source code is written ahead of a spec.** The
  SessionStart flag fires once, at startup — but a repo that's empty at startup
  can grow its first feature code mid-session, after the banner. New
  `hooks/check-code-before-spec.sh` (PreToolUse, `Write|Edit|MultiEdit`)
  re-asserts spec-first at the moment it's about to be broken: the first write
  of real source code (extension allowlist) into a repo with no `/spec` spine.
  **Non-blocking** — emits `hookSpecificOutput.additionalContext` and exits 0,
  so the write proceeds and the model just sees the reminder — and fires **at
  most once per session+repo** (marker in `TMPDIR` keyed by `session_id` + cwd),
  so it nudges without nagging. Exempts docs/config/scaffolding and anything
  under `spec/` or `.claude/` (writing those is bootstrapping), and is silent
  once `/spec` exists or in the plugin's own repo.
- **Generalized `/e22-init` to cover non-template greenfield, not just forks.**
  `e22-init` previously bailed the moment it found no placeholders — leaving a
  from-scratch non-template repo with no working bootstrap path (the route the
  new hook points greenfield repos at). It's now a two-path skill: **Path A**
  (fresh template fork — the existing placeholder-resolution flow) and **Path B**
  (non-template greenfield — bring the spine + scaffolding in from
  `repository-template`, interview to fill `vision`/`users`/`glossary`, record
  the initial stack as the first ADR, pin the toolchain, then proceed
  spec-first). Repos with substantial pre-existing code still redirect to
  `/e22-adopt`. Updated the skill description, the `commands/e22-init.md` alias,
  and the router (`rules/00-router.md`) accordingly.

### 1.25.0

- **New `/e22-questions` skill — stop open questions from rotting.** Open
  questions were written down once, gated at PO acceptance, then forgotten,
  spread across per-feature `intent.md` sections and a free-floating
  `SPEC-QUESTIONS.md`. The new skill sweeps every open question across the
  `/spec` spine and walks the PO/dev through answering each (read-then-propose:
  it never guesses an answer or edits without a yes), folding each decision back
  into the spec or recording an explicit deferral. Added a `commands/e22-questions.md`
  alias and registered the skill in the router (`rules/00-router.md`) and
  spec-workflow (`rules/30-spec-workflow.md`) rules.
- **SessionStart nudge so questions can't rot silently.** A new
  `hooks/check-open-questions.sh` counts outstanding open questions across
  `vision.md`, every feature's `intent.md`, and `PRODUCTIONIZATION.md` (scoped to
  the `## Open questions` section, skipping resolved `- [x]` items and the
  template's placeholder seed) and surfaces the backlog every session, pointing
  at `/e22-questions`. Fail-soft and silent when there are none — the notice
  clears itself once questions are answered or explicitly deferred.
- **Retired `SPEC-QUESTIONS.md`; questions now live next to their context.**
  Per-feature questions live in that feature's `intent.md` → `## Open questions`;
  product-level questions (greenfield vision interview, whole-repo adoption) live
  in a new `vision.md` → `## Open questions` convention. Rerouted all references
  across rules 30/60/90, the spec-framework and design-sources references, the
  `productionization.md` template, and the `e22-spec-scaffold`, `e22-design-sources`,
  `e22-drift`, `e22-build`, and `e22-adopt` skills.

### 1.24.1

- **Fix documentation drift in the `e22-standards` loader skill.** The on-demand
  loader (`skills/e22-standards/SKILL.md`, used on Cowork/desktop where the
  SessionStart hook does not fire) had two stale spots: its enumerated rule list
  omitted `22-housekeeping`, and its version-confirmation example hardcoded an
  old version string. Added `22-housekeeping` to the list (now matches all 17
  `rules/` files) and made the example placeholder-based (`vX.Y.Z`) so it can't
  drift again — the real version is still read from `plugin.json` at runtime. No
  behavior change.

### 1.24.0

- **New `/e22-drift` skill — audit the built app against its specs.** A manual,
  read-only conformance audit for the inverse of `/e22-adopt`: a spec exists and
  you want to confirm the code still matches it. The dev brings a batch of source
  tickets (pasted into the chat or pointed to a Jira export path); Phase 1
  reconciles those tickets against the `/spec` spine and flags spec gaps
  (proposed, not written); Phase 2 audits `/apps` + `/packages` against the spec
  plus the ticket behaviors, classifying each as Conforms / Drifted / Missing /
  Extra / Ambiguous with `path:line` evidence. Output is a drift report, a
  proposed Rule-5 resolution per finding (PO vs dev approval noted), and
  `spec-drift` issues for items needing a decision. **Report + propose only — it
  makes no code or spec edits and does not commit.** Discoverable via the router
  in `rules/00-router.md` and the `/e22-drift` command alias.

### 1.23.1

- **`/e22-adopt` resume migration: close the gap inside the skill, not just the
  command.** 1.23.0 fixed the command's resume *routing* but left the actual
  `git mv` reachable only via a fragile path: the migration line lived solely in
  `SKILL.md` step 2, while every salient resume gate in the skill keyed on the
  **new** `PRODUCTIONIZATION.md` — which is absent in a repo adopted under ≤1.21.0.
  The "## Resuming?" header (`If PRODUCTIONIZATION.md already exists…`) and step
  2's "if PRODUCTIONIZATION.md does not exist, this is a fresh adoption — skip
  ahead" gate both evaluated false/fresh against the old filename, so the agent
  could settle on the fresh-adoption branch and never reach the one buried line
  that migrates the old name. Now: the skill's resume header recognizes **either**
  filename; step 2 runs the `git mv` **before** the fresh-vs-resume decision and
  bases that decision on whether *neither* file existed; and the command inlines
  the literal `git mv spec/PRODUCTION-READINESS.md spec/PRODUCTIONIZATION.md` so
  migration no longer depends on the agent fully entering the skill.

### 1.23.0

- **`/e22-adopt` now actually migrates the old filename on resume.** The
  always-injected `commands/e22-adopt.md` recognized only the new
  `PRODUCTIONIZATION.md` on resume and inlined a "read it first and resume from
  its unchecked items" shortcut. For a repo adopted under ≤1.21.0 — i.e. every
  existing adoption, since the rename landed in 1.22.0 — the file on disk is
  still `PRODUCTION-READINESS.md`, so the resume branch didn't match and the
  agent improvised: it read the old file and summarized status without ever
  loading the skill or running its step-2 reconcile, so the `git mv` migration
  (which lives only in `SKILL.md`) never fired. The command now treats **either**
  filename as a resume, and routes to the skill's step-2 reconcile **first**
  rather than inlining a competing shortcut — closing the gap for every repo
  adopted before 1.22.0.

### 1.22.0

- **One readiness concept, named for what it is.** `PRODUCTION-READINESS.md` is
  renamed to **`PRODUCTIONIZATION.md`** — it's the dev's standing list of
  hardening *work*, not a go/no-go *judgment*, and "readiness" collided with the
  build flow's handoff gate. `/e22-adopt` migrates an existing
  `PRODUCTION-READINESS.md` to the new name on its next run (resume-safe), so
  already-adopted repos pick it up without losing filled-in content.
- **Productionization is now a decision, not just a to-do list.** The gap
  analysis gains a **disposition** per area — **Keep / Refactor / Rewrite /
  Reject** — plus an **Overall recommendation**. `/e22-adopt` proposes
  dispositions (the dev ratifies at PR review); when most areas trend
  Rewrite/Reject it recommends **rebuilding from the now-extracted `/spec`**
  rather than hardening a mess, and escalates a project-level Rewrite/Reject to
  an ADR (`/e22-adr`).
- **`/e22-build` now leaves the same durable brief.** A PO-built v0 writes
  `/spec/PRODUCTIONIZATION.md` at handoff (the same artifact `/e22-adopt`
  produces) instead of letting the gaps evaporate with the PR description. On a
  PO build the dispositions trend Keep/Refactor — there's no legacy to triage,
  only stubs to finish.
- **Renamed the build flow's `Handoff readiness` checklist to `Handoff gate`**
  in `BUILD-STATUS.md`, matching the reference and ending the "two readinesses"
  ambiguity.

### 1.21.0

- **Repo housekeeping: a `housekeeping` rule + the `/e22-tidy` skill.** A PO
  building from the template tends to commit a pile of source material at the
  repo root — vendor metadata spreadsheets, SQL/DDL dumps, architecture and flow
  decks, system inventories, PII/CMDB docs — and nothing in the standards gave
  those a home or told Claude to keep the root clean. The layout rule defined
  where *code* and *design exports* live, but the canonical `/spec` tree had no
  slot for the research inputs the spec is built from. Added:
  - New always-on `rules/22-housekeeping.md`: the root holds scaffolding + config
    only; loose source/research materials belong in `/spec/reference/` (diagrams
    in `/spec/design/`). When Claude notices root clutter it **proposes** moving
    it — never silently moves, never auto-deletes, flags junk and duplicates for
    confirmation first.
  - `/spec/reference` added to the layout rule as the home for source material.
  - New `e22-tidy` skill + `/e22-tidy` command and bundled
    `templates/reference/HOUSEKEEPING.md`: a sweep that lists root strays,
    classifies them against a destination taxonomy, and presents a plan table
    with a `move` / `rename + move` / `delete` action column for approval, then
    `git mv`s on a yes (so history follows). It **renames** cryptic or
    inconsistent filenames to clear ones as it moves them — a bad name is a
    reason to rename, not to bury or delete. A confusing or duplicate-looking
    name (`Copy of …`, `(002)`, case-variant pairs) is **not** treated as junk:
    those may be the important file, so the sweep **asks the PO/dev what the file
    is for and which version is current** before deciding, then moves + renames
    or (only on confirmation) deletes. Only true OS junk (`desktop.ini`,
    `.DS_Store`, `Thumbs.db`) is ever a deletion candidate, and even that waits
    for a yes — and when junk is deleted, its pattern is added to `.gitignore`
    (broad, tree-wide, only if absent) so it can't be re-committed and
    re-introduced later.

### 1.20.0

- **`practices` rule rephrased principle-first so it applies beyond the default
  stack.** The always-on patterns read as Next.js/Drizzle/Zod-only, which made
  them feel inapplicable on other stacks. Each bullet now leads with the general
  principle (parameterized query layer, validate input at the boundary,
  server-first, domain logic in shared modules) and names the default-stack
  instance in parens — keeping the opinion actionable on the default stack while
  stating the rule any stack must satisfy. No change to what is required; only
  how it is framed.

### 1.19.0

- **`/e22-adopt` stops waving raw SQL and missing schemas through as "clean."**
  A run was observed declaring a repo's data layer "verified clean" because its
  raw SQL was *parameterized* — and never flagging that the DB schema wasn't
  defined anywhere. Both are violations of the `practices` rule (data access
  through Drizzle/SQLAlchemy only; schema defined in code and migration-tracked).
  The misfire traced to ambiguous guidance: the anti-pattern list read "raw /
  string-interpolated SQL" (taken to mean only the *non*-parameterized case), and
  nothing prompted a data-layer check at all. Fixes:
  - The adopt skill's step-8 anti-pattern list now spells out that **raw SQL is
    a violation parameterized or not** (parameterization clears injection, not the
    ORM bypass), and that **a missing/untracked schema is a flagged gap, not an
    absence of findings** — with an explicit "don't mark data-layer practices
    clean without confirming ORM access *and* a migration-tracked schema."
  - Step 7's gap-analysis prompts and the `PRODUCTION-READINESS.md` template gain
    a dedicated **Data layer (ORM, schema, migrations)** dimension.
  - `CONVENTIONS.md` anti-patterns reframed: raw SQL is the anti-pattern
    regardless of injection safety, and "no schema defined at all" is called out
    alongside ad-hoc schema edits.

### 1.18.0

- **Cowork fallback: load the standards on demand where hooks don't fire.** Some
  POs work in Claude Cowork (the desktop app) instead of Claude Code. Plugins are
  cross-compatible and the skills/commands/templates work there unchanged, but
  Cowork runs the agent in a sandbox VM that currently ignores plugin hooks
  ([anthropics/claude-code#40495]) — so the `SessionStart` auto-injection of the
  always-on rules and the `PreToolUse` version-pin guard silently no-op, leaving
  a Cowork session with none of the org standards in context. New **`/e22-standards`**
  skill loads the same `rules/*.md` ruleset on demand; run it once at the start of
  a Cowork session. The router (`00-router.md`) and README now point to it, and
  the README documents the Cowork limitation. When #40495 ships, auto-injection
  works in Cowork with no plugin change and the skill becomes a harmless repeat.

[anthropics/claude-code#40495]: https://github.com/anthropics/claude-code/issues/40495

### 1.17.0

- **Host port bindings must be overridable, so concurrent products don't
  collide.** POs and devs routinely run several E22 products at once; any repo
  that hardcoded `"5432:5432"` in `compose.yaml` made the second `docker compose
  up` fail with `port is already allocated`. The stack rule (`10-stack.md`) and
  the Local services reference (`CONVENTIONS.md`) now require every published
  host port to bind through an env var defaulting to the canonical port —
  `"${POSTGRES_PORT:-5432}:5432"` — with the override variable listed in
  `.env.example`. A dev hitting a collision sets `POSTGRES_PORT=5433` in their
  git-ignored `.env` and mirrors it in `DATABASE_URL`; nothing else changes. The
  guidance notes that container/network/volume *names* need no such treatment —
  Compose namespaces those per project directory. The `repository-template`
  `compose.yaml` already follows the pattern for Postgres; a paired template
  change adds the `.env.example` documenting `POSTGRES_PORT` and `DATABASE_URL`.

### 1.16.0

- **Plugin freshness check at session start.** The always-on standards only help
  if the consumer is running a current copy, but nothing nudged anyone to
  `/plugin update`, so a repo could drift versions behind unnoticed. New
  SessionStart hook `hooks/check-plugin-updates.sh` compares the installed
  marketplace clone's `HEAD` against the remote default-branch tip and, when they
  differ, injects a notice naming the installed version and the two required
  steps: `/plugin update e22-standards@<marketplace>` to pull the new version,
  **then** `/clear` (or a fresh session) to reload — because the update only
  writes files to disk and the current session keeps running the already-injected
  (stale) rules until SessionStart re-fires.
  - Works against the **private** marketplace repo: it uses the clone's existing
    git auth via `git ls-remote` (a raw https fetch would 404), not an
    unauthenticated download.
  - Fail-soft and silent by construction — unknown install layout, no clone,
    offline, or any git error exits 0 with no output, and an up-to-date repo emits
    nothing. The network call is bounded (`ssh -o ConnectTimeout=4 -o BatchMode=yes`,
    `GIT_TERMINAL_PROMPT=0`) so it can never hang or prompt at session start.
  - Self-clearing: the notice disappears once `/plugin update` lands, the same
    self-healing shape as the template-drift hook.

### 1.15.0

- **Design exports are a spec to realize, not code to ship.** The design-sources
  standard previously told the model to *read* an export and treat it as
  authoritative for visual behavior/flow, but was silent on the delivery question:
  may you serve the prototype's runtime (UMD React + in-browser Babel + hand-rolled
  CSS) as the actual front-end? That silence let an ADR treat "serve the prototype
  as-is" as a peer to "rebuild in the stack." It is not — the delivery tech is
  disposable scaffolding; the durable artifact is the design itself.
  - `rules/90-design-sources.md` (always-on) now states the export is a **spec to
    realize in the standard stack, not code to ship**, and that serving the
    prototype runtime as a maintained surface is an **ADR-gated, kill-dated
    exception**, never the default.
  - `templates/reference/DESIGN-SOURCES.md` gains a **"Realizing the design vs.
    serving the prototype"** section with the decision rule (default: rebuild in
    Next.js + TS + Tailwind, no ADR needed; deviation: keep the prototype runtime
    only for genuine throwaways, ADR with a lifespan + named port trigger; never:
    untracked "temporary" hosting that becomes permanent). Notes that the
    rewrite-is-too-expensive objection has expired now that the port is a
    mechanical agent task with the prototype as the pixel-diff oracle.
  - The `e22-design-sources` skill summary gains a matching key-point bullet.

### 1.14.0

- **Template reconciliation is now enforced by a hook, not skill prose.** 1.12.0
  shipped the reconcile logic and 1.13.0 added a forcing-command + resume gate, but
  both lived in `SKILL.md` — advisory context the model reliably skipped when a spec
  file looked complete (it resumed "from the checklist" and never diffed). The fix
  moves detection out of the model's discretion: a new **SessionStart hook**
  (`hooks/check-template-drift.sh`) runs the heading diff deterministically at the
  start of every session and, when an instantiated file is behind the current
  bundled template, injects a high-salience notice naming the exact missing sections
  (e.g. `## Outdated dependencies & bad practices`). Same `additionalContext` path as
  the always-on rules, so it's unavoidable — and it stays **silent when there is no
  drift**, clearing itself once the files are reconciled.
  - Covers all instantiated files: `PRODUCTION-READINESS.md`, `BUILD-STATUS.md`, and
    every feature `intent.md` / `contract.md` under `spec/features/*/`.
  - POSIX sh, no jq, no process substitution (per repo conventions); headings are the
    drift signal (checklist-item diffing over-reports and would inject false
    positives). The skills' in-prose reconcile steps (1.13.0) remain as the
    how-to-splice guidance the notice points the model toward.

### 1.13.0

- **Self-healing reconciliation now actually fires on resume.** 1.12.0 shipped the
  reconcile logic but buried it mid-list, so the model resumed "from the checklist"
  and silently skipped it — a repo adopted under an older version still missed newly
  added sections (e.g. the `## Outdated dependencies & bad practices` gate). The fix
  replaces "remember to diff" with a **forcing function**: each template-copying skill
  now runs a concrete `comm -13` diff (bundled template vs. existing file, normalizing
  `[x]`→`[ ]`) as its **first action on resume**, and acts on the printed candidate
  list. The diff over-reports (filled-in placeholders, reworded items) by design — it
  is a candidate list that guarantees the comparison happens; splicing still applies
  the additive rules with judgment (never re-add a placeholder the dev filled).
  - **Shared convention** (`templates/reference/spec-framework.md` → *Template
    reconciliation*) now prescribes the forcing-command pattern and the "reconcile
    first, before status/next-steps" ordering rule.
  - **`/e22-adopt`** — new **Resume gate** before `## Steps`; step 2 embeds the diff
    command with imperative "run first" language; the competing "continue from
    unchecked items" framing in step 7 and the guardrail now defer to reconcile-first.
  - **`/e22-build`** and **`/e22-spec-scaffold`** — their resume/reconcile branches
    now carry the concrete diff command too.

### 1.12.0

- **Template self-healing, standardized plugin-wide.** Skills that copy a bundled
  template into the product repo now reconcile it against the current template on
  re-run instead of silently missing sections added by a later `/plugin update`.
  The convention is defined once in the shared reference
  (`templates/reference/spec-framework.md` → *Template reconciliation*) and
  applied by every instantiating skill: on a re-run they **splice in** the `##`
  sections, checklist items, and table rows the older template lacked — matched on
  stable anchors, left unchecked/empty, with every filled-in value preserved
  (purely additive; never overwrite, reorder, or delete).
  - **`/e22-adopt`** — new step 2 reconciles `/spec/PRODUCTION-READINESS.md`
    (so e.g. the 1.11.0 dependency-freshness section is picked up by repos adopted
    under 1.10.0). Steps 2–10 renumbered to 3–11; new "Resume is additive, never
    destructive" guardrail.
  - **`/e22-build`** — reconciles `/spec/BUILD-STATUS.md` on resume.
  - **`/e22-spec-scaffold`** — reconciles an existing feature's `intent.md` /
    `contract.md` instead of clobbering it (also fixes a latent overwrite-on-rerun
    risk).
  - **Exempt:** reference prose (read in place, always current via `/plugin
    update`) and **ADRs** (immutable point-in-time records — supersede, never
    retrofit a newer template into an accepted ADR).

### 1.11.0

- **`/e22-adopt` now flags outdated deps and bad practices.** Vibe-coded apps
  pin to whatever versions the generating model knew at *its* training cutoff —
  usually a major or two behind. New step 7 has the skill query the registry
  **live** (`npm view`, `uv pip index versions`, current Node LTS) — not from
  memory, which has the same cutoff problem — and record every major-behind /
  superseded dependency plus as-built anti-patterns (raw SQL, swallowed errors,
  `any`/`@ts-ignore`, unvalidated boundaries, `process.env` reads). New
  **Outdated dependencies & bad practices** section + `Dependency freshness`
  gap-analysis row in the `production-readiness.md` template; the dev owns the
  upgrade on a clean branch with tests green (propose, don't force).

### 1.10.0

- **New: adopt an existing non-template repo — `/e22-adopt`.** Until now the
  plugin assumed every repo was forked from `repository-template` (`/e22-init`
  only resolves placeholders in an already-scaffolded fork). The new skill
  covers the "vibe-coded" case — working code, but no `/spec`, no `mise.toml`,
  no plugin install — by reversing the Greenfield flow: survey the code,
  reverse-engineer `vision.md`/`users.md`/`glossary.md` (ask, don't invent),
  extract `intent.md` + `contract.md` per feature via `/e22-spec-scaffold`,
  capture as-built choices as ADRs via `/e22-adr`, then fetch
  `element22llc/repository-template` and sync in the scaffolding it lacks (mise
  tasks, `compose.yaml`, CI, `/configs`, `.env.example`, plugin install) —
  adapting to the existing stack, reconciling rather than replacing, and never
  clobbering working code. Ends in a `feat/e22-adopt` branch and a PR for dev
  review. (`skills/e22-adopt`, `commands/e22-adopt.md`)
- **New `/spec/PRODUCTION-READINESS.md` (bundled template).** The findings
  output of `/e22-adopt`: a gap analysis vs E22 standards (tests, lockfiles &
  pins, secrets, high-risk areas, CI, Zod/error model, layout) with a
  stop-and-rotate callout for any committed secret. Doubles as the resumable
  adoption checklist — a fresh session reads it first and continues from the
  unchecked items. (`templates/spec/production-readiness.md`)
- Router and spec-workflow rules point whole-repo adoption at `/e22-adopt`,
  distinct from a per-feature Brownfield change. (`rules/00-router.md`,
  `rules/30-spec-workflow.md`)

### 1.9.0

- **PO demo-validation gate before handoff.** `/e22-build` no longer proposes
  the handoff PR on its own judgment that the app is done — the Definition of
  Done is a precondition, never the trigger. New step 9: after the PO has
  actually used the running app and demo feedback is incorporated, the gate
  opens only on the PO's explicit "this does what I wanted" (asked plainly, or
  volunteered). Step 8 is now an explicit iterate-loop that may span many
  sessions. (`skills/e22-build`, `commands/e22-build.md`)
- **Build-flow state persists across sessions.** New `/spec/BUILD-STATUS.md`
  (bundled template), created at interview time and updated at every step
  transition: current step, per-feature progress, handoff-readiness checklist.
  A fresh session reads it and resumes from the recorded step instead of
  restarting the flow; the skill description now triggers on resuming too.
  (`templates/spec/build-status.md`, `skills/e22-build`,
  `templates/reference/spec-framework.md`)
- **Per-feature demo validation is traceable.** `feature-intent.md` gains a
  `validated` status (between `implemented` and `live`) and a
  **PO validated the working demo** acceptance checkbox, checked only on the
  PO's explicit confirmation. (`templates/spec/feature-intent.md`)
- Command alias cleanup: `commands/e22-build.md` guardrail wording aligned
  with the 1.8.0 pre-production relaxation (was still "high-risk areas
  stubbed and flagged").

### 1.8.0

- **Pre-production relaxation of the high-risk gates.** The gates exist to
  protect real systems and real data; while a product is **pre-production**
  (nothing deployed, no real users or data) high-risk areas may be built for
  real locally without prior dev scoping — document choices as you go
  (`contract.md`, ADRs, `/spec/SPEC-QUESTIONS.md`) and the dev PR review
  hardens them at productionization. Pre-production is a property of the
  *product, not the laptop* — local work in a deployed product gets no
  relaxation. Never relaxed: real secrets/credentials, `/infra`, deploys,
  real third-party calls. (`rules/60-high-risk.md`)
- **PO mode unblocked for exploration.** PO guardrails narrowed to the truly
  irreversible (deploy, `/infra`, real secrets/third-party accounts); a
  pre-production PO build may implement the data model, soft-delete with
  restore, and library-backed local sign-in for real. New principle: the PO
  owns data **semantics** (what exists, what "delete" means to a user); the
  dev confirms the **mechanics** (schema, cascades, retention) at review.
  (`rules/05-roles.md`, `skills/e22-build`)
- **Intent template captures data semantics.** New PO-facing **Key concepts &
  data** and **Lifecycle expectations** sections in `feature-intent.md` give
  data-model and deletion intent a structured home; `contract.md`'s Data model
  now derives from them and is marked `proposed — dev confirms at review`
  when drafted pre-production. `/e22-build` now interviews for deletion
  semantics explicitly (recoverable? how long? related items?).

### 1.7.0

- **Token slim: the always-on ruleset shrinks ~27%** (~20.4 KB → ~14.9 KB
  injected per session — roughly 1.4k tokens saved in *every* session of
  *every* product repo), following Anthropic's guidance that long always-on
  context both costs tokens and degrades rule adherence. No standard was
  dropped — prose moved behind the existing on-demand skills (progressive
  disclosure), keeping rules imperative and pointer-style per this repo's own
  `rules/` policy:
  - `10-stack.md` rewritten as lean bullets; backend-placement rationale and
    the local-services prose (compose-from-template, same-engine rule) moved to
    `CONVENTIONS.md` (new **Backend placement** and **Local services**
    sections). The `.env` bootstrap detail now lives only in the Secrets rule
    (it was duplicated across `10-stack.md` and `70-secrets.md`).
  - `85-practices.md` condensed to the E22-specific baseline (Drizzle-only,
    Zod boundaries, server-first, `packages/` for domain logic, nothing
    silenced, lockfile discipline); the full patterns/anti-patterns prose moved
    to `CONVENTIONS.md` (new **Baseline patterns & anti-patterns** section).
  - `30-spec-workflow.md` keeps the triggers; the 4-step Greenfield walkthrough
    moved to the spec-framework reference (new **Greenfield flow** section),
    which `/e22-build` now cites directly.
  - `15-commands.md` command block compacted; `00-router.md`, `20-layout.md`,
    `60-high-risk.md`, `70-secrets.md`, and `90-design-sources.md` tightened
    (duplication with Stack/Spec-workflow removed, pointer phrasing).
- **Skill descriptions trimmed ~35%.** All six SKILL.md frontmatter descriptions
  (loaded every session) cut to one-line what-it-does + when-to-use; the
  `/e22-conventions` summary now lists the new reference sections.

### 1.6.0

- **New: PO path — `/e22-build` skill + command.** Non-technical product
  owners can now go idea → auto-drafted spec → intent validation → working
  local app entirely in Claude Code. The skill is a thin driver over the
  existing Greenfield flow: PO-adapted first-run setup (Claude installs and
  runs mise/Docker/pnpm itself, asks the PO only product name + one-liner,
  keeps the default stack), interview → `vision.md`/`users.md`/`glossary.md`,
  intents via `/e22-spec-scaffold`, an explicit PO-acceptance gate before
  broad implementation, feature-by-feature build with `contract.md` + tests,
  local demo via `mise run dev:setup` + `pnpm dev`, and handoff as a PR whose
  description is the dev's productionization brief (PO-built v0, approved
  intents, stubbed high-risk items, open questions).
- **New always-on rule `05-roles.md` (PO vs dev).** Defines the two audiences
  and PO-mode behavior: plain language, spec-first, Claude drives the
  toolchain; guardrails — never deploy, never touch `/infra`, high-risk areas
  (auth, secrets, migrations, billing, deletion) stubbed minimally and flagged
  for a dev. Standards are never softened for a non-technical user, and the
  gate is unchanged: a PO-built app merges to `main` as v0 only after a dev
  approves the PR.
- **Spec framework broadened to both audiences.** Rule 1 and the lifecycle
  table now say specs are written with Claude's help by a dev *or* a PO via
  `/e22-build` (PO approves intent, dev approves the PR). Fixed structure-
  diagram drift: removed `/spec/README.md` and `/spec/_templates/`, which the
  template repo doesn't ship (templates are bundled in this plugin).
- README: dropped the hand-maintained Versions table (already stale at 1.0.0)
  in favor of `plugin.json` + this changelog.
- Pairs with `repository-template`: PO quickstart in the README, `/e22-build`
  in the `CLAUDE.md` fork note, broadened `spec/vision.md` header, and two
  fresh-fork CI fixes — (1) `pnpm install --frozen-lockfile` failed every
  fresh fork's first PR (`ERR_PNPM_NO_LOCKFILE`, the template deliberately
  ships no `pnpm-lock.yaml`); the install step now freezes only once a
  lockfile exists; (2) mise-action v4 auto-runs `mise install --locked` when
  a `mise.lock` exists, so the comment-only placeholder locks failed every
  tool with "not in the lockfile"; CI now drops placeholder locks (no
  `[[tools]]` entries) from the runner workspace before setup and installs
  the exact pins once `/e22-init` commits populated locks. Both fixes are
  self-correcting at lock adoption.

### 1.5.0

- **New: enforced version-pin verification.** The "default to current stable /
  don't trust training-data memory" rule was advisory only, and the failure
  mode is being *confidently* stale (e.g. a fresh app scaffolded with
  `postgres:16` when current stable is 18), so the "if unsure, ask" escape
  hatch never fired. A new `PreToolUse` hook
  (`hooks/check-version-pins.sh`) now denies Write/Edit/Bash calls that pin a
  stale major for common images (`postgres:`, `node:`, `python:`, `redis:`,
  `valkey:`, `nginx:`, `mysql:`, `mariadb:`, `mongo:`), with current stable
  resolved live from the endoflife.date API — the hook hardcodes no versions.
  Fails open offline; Markdown exempt; deliberate older pins pass with an ADR
  plus a same-line `# pin-ok: <reason>` marker. Documented in
  `CONVENTIONS.md` (Versioning policy → Enforcement).
- **Versioning policy reworded:** verification of current stable is now
  unconditional before writing any pin, instead of "if unsure, say so" —
  models are not unsure, they are confidently stale.
- New stack rule: **don't author `compose.yaml` from scratch** — start from
  the `repository-template` one and adapt, so generated services can't
  reintroduce stale image majors.
- **Fix: hooks no longer depend on the executable bit.** `hooks.json` now
  invokes both hook scripts via an explicit `sh` prefix; marketplace install
  does not chmod, so a missing `+x` could previously leave a session with no
  org standards injected at all.

### 1.4.0

- **Fix: toolchain pinning silently produced no lock.** mise only writes
  `mise.lock` when the file already exists, so the documented
  "`mise install` generates the lock" flow pinned nothing on a fresh fork.
  `CONVENTIONS.md` and `/e22-init` step 4 now document the caveat, require
  restoring a missing lock (`touch mise.lock` / `mise lock`) before installing,
  and require verifying the lock contains real `[[tools.*]]` entries before
  committing. Pairs with `repository-template`, which now ships committed
  placeholder `mise.lock` files (root and `infra/`).
- New org standard: **lockfile discipline** (always-on rule in the practices
  baseline + a `CONVENTIONS.md` section). `mise.lock`, `pnpm-lock.yaml`,
  `uv.lock`, `.terraform.lock.hcl` are committed and updated in the same change
  that touches their config/deps; never deleted or git-ignored to dodge an
  error; lockfile-only diffs get real review.
- New org standard: **mise backends must be cross-platform** (macOS + Linux).
  The registry default backend is not always usable everywhere — e.g. plain
  `pnpm` → `aqua:pnpm/pnpm` has no valid macOS asset, so repos pin `"npm:pnpm"`
  explicitly. Verify `mise install` works on both platforms when adding a tool.
- `/e22-init` step 5 now covers workspace lockfile adoption: the template ships
  no `pnpm-lock.yaml` on purpose (the starter's would go stale); generate and
  commit it (or `uv.lock`) once the real workspace exists.

### 1.3.0

- New org standard: **standard mise tasks**. Every repo exposes
  `mise run dev:setup` — the idempotent one-command local environment (Compose
  services up → `db:migrate` → `db:seed`) — plus `docker:up/down` and
  `db:migrate`/`db:seed`. Environment-orchestration tasks live in `mise.toml`
  (polyglot, owns tooling outside the workspace), not `package.json`, whose
  scripts stay app-level.
- Stack rule's Local-services bullet now names `mise run dev:setup` as the
  standard entry point and requires keeping it green as the stack evolves; the
  always-on commands cheat-sheet includes it in first-time setup.
- `CONVENTIONS.md` gains a "Standard mise tasks" section (the task vocabulary,
  the idempotency contract, and the mise-vs-package.json rationale), surfaced
  in the `/e22-conventions` skill summary.
- `/e22-init` gains step 6: adapt the template's baseline tasks to the product
  being built — real services in `compose.yaml`, real migrate/seed scripts,
  `uv run` instead of pnpm for Python products, or delete the docker/db tasks
  when there are no backing services.
- Pairs with `repository-template`, which now ships the baseline `[tasks]`
  block in `mise.toml` and a Postgres `compose.yaml` (host port overridable via
  `POSTGRES_PORT` so parallel products don't collide on 5432).

### 1.2.0

- New always-on rule **Commit autonomy** (`rules/45-commit-autonomy.md`): on a
  `feat/*`/`fix/*` branch, commit coherent units of work without asking the dev
  for permission — the PR review is the gate, not each commit. Never commit to
  `main` directly. When the work is judged complete (Definition of Done holds),
  proactively propose opening the PR and wait for the dev's confirmation before
  pushing/creating it.
- End-of-session checklist gains a matching item: all finished work committed,
  PR proposed if the change is complete.

### 1.1.0

- Local-dev `.env` bootstrap: the Stack and Secrets rules now require that when
  setting up or running an app locally, `.env` is created and populated with
  the base variables the app needs to boot — e.g. `DATABASE_URL` pointing at
  the local Compose PostgreSQL and freshly generated local-only secrets (auth
  secret, API tokens) — instead of leaving the dev to hand-assemble it from the
  README. Deployed/production secret values must never be copied into it.

### 1.0.0

- Initial release. Fresh start: replaces the earlier experimental 7-plugin
  three-zone marketplace (removed — preserved in git history) with a single
  `e22-standards` plugin mirroring the `repository-template` org standards.
- Always-on ruleset (`rules/*.md`) injected via a `SessionStart` hook: stack,
  layout, spec workflow, testing, Definition of Done, high-risk areas, secrets,
  change-size model, baseline patterns/anti-patterns, design-sources, and the
  end-of-session checklist.
- Skills: `e22-init`, `e22-spec-scaffold`, `e22-adr`, `e22-conventions`,
  `e22-design-sources`. Command: `/e22-init`.
- Bundled spec templates (`feature-intent`, `feature-contract`, `adr`) and full
  reference prose (`CONVENTIONS.md`, `DESIGN-SOURCES.md`, `spec-framework.md`).

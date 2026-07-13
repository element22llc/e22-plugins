# Changelog

All notable changes to the `e22-plugins` marketplace. Each plugin is versioned
in its own `.claude-plugin/plugin.json`; this file records what changed and when.

## steer

### [Unreleased]

### 3.18.0

- **New `/steer:status` front door renders a client-facing progress report.**
  Answers "what's the status?" / "what did we ship this week?" with a
  time-boxed, cross-spine snapshot — what shipped this period, what's in
  progress, what needs the client's input, and what's next — as a shareable
  Claude Code Artifact with a Markdown fallback, in plain product language
  (rule `05`). It is the periodic, whole-spine counterpart to `/steer:explain`
  (one feature) and `/steer:roadmap` (the forward timeline). A thin
  orchestrator + presentation layer: it reads closed issues and milestone
  progress through `/steer:tracker-sync` (MCP → `gh` → manual floor, degrading
  to spec-only sections on a non-GitHub tracker) and reads open blocking
  questions and feature `Status:` from `/spec`, then renders by the shared
  Artifact discipline (rule `88-artifacts`). Read-only and derived — it disallows
  `Edit`, `NotebookEdit`, and `EnterWorktree` (so, tool-enforced, it cannot mutate
  a repo file, branch, or worktree) and holds no tracker-write grant, keeping only
  `Write` for a temp-dir artifact; unlike `/steer:explain` it keeps `Bash`, because
  — like `/steer:roadmap` — it reads the tracker (the `gh` read fallback runs
  through `Bash`), used for reads only. `/spec` and the tracker stay canonical; it
  never fabricates counts, dates, or status, never writes back, and is never
  auto-generated on a schedule. The period defaults to
  the last week (`this-week`); `since <date>` and `milestone [<name>]` scope it
  otherwise. "Shipped" is sourced from closed issues + milestone completion, not
  `git log`, so a non-technical reader sees completed outcomes rather than
  commit noise. The "needs your input" section counts open `owner: product`
  blocking questions and routes the client to `/steer:questions bundle` to
  answer them.

### 3.17.0

- **The PO clarification loop's shared contract now lives in one reference.**
  The outbound→inbound contract `/steer:questions bundle` and `/steer:intake
  clarify` each restated in full — the machine-keyed `[<feature-id>] Q-NNN`
  return-document format, stale/unknown-key handling, the inbound segmentation
  rule, and the three-bucket worklist with its durability rules and the
  intake-routes / questions-folds ownership split — moved into a new
  `templates/reference/CLARIFICATION-LOOP.md`; both skills now defer to it
  (the cost guardrail stays canonical in `/steer:questions` step 4). The
  pre-1.25.0 `SPEC-QUESTIONS.md` heal became a proper v1.25.0 entry in
  `templates/reference/MIGRATIONS.md` — so `/steer:sync` now applies it too —
  with `/steer:questions` keeping a one-paragraph pointer as its pre-sweep
  hard gate, and the fillable-page mechanics `/steer:questions bundle`
  restated (copy-out floor detail, sandbox-grant caveats, the fillable
  Markdown-fallback shape) were folded into
  `templates/reference/ARTIFACTS.md`. Contracts, gates, and read-only
  invariants are unchanged; the prose has one home.
- **The trunk-push graduation gate now asks once per session, not on every
  push.** In a solo-trunk repo with a standing graduation signal, the first
  `git push` of a session still surfaces the permission ask pointing at
  `/steer:protect`; repeat pushes in the same session downgrade to a
  non-blocking reminder (never silent, and it tells the model not to retry a
  declined push). Previously every push re-asked, which stalled autonomous
  runs (`/steer:loop`, headless sessions) on a prompt nobody was watching. On
  the Copilot CLI (whose hook envelope carries decisions only) repeats are
  silent after the first flat ask.
- **Internal hook cleanups (no behavior change).** `check-open-questions.sh`'s
  two near-duplicate awk block parsers collapse into one `parse_questions`
  pass that emits per-question records the counting and staleness passes
  classify — one parser to maintain instead of two that could drift — and the
  `days_from_civil` date math (previously inlined twice) is hoisted to
  `lib/lifecycle.sh` as a shared awk source. New `steer_json_safe` helper in
  `lib/json.sh` replaces the five copy-pasted JSON-sanitization pipelines
  across the point-of-action hooks. All 369 hook fixtures pass unchanged.
- **`00-router` trimmed ~16%** — the largest always-on rule (injected every
  session *and* re-injected on every compaction). The clarify bullet folds into
  announce-then-act, the human-gate and bootstrap-precedence bullets compress
  onto their owning rules (Commit autonomy, Spec workflow), the intent table
  keeps all 15 rows with tighter wording, and the stack-version verification
  note moves into the `code-project`-scoped `10-stack` rule where it applies.
  Routing behavior is unchanged.
- **Cross-skill prose consolidation (simplification pass, part 1).** The
  priority-floor table + PO-seeding rule moved from `/steer:issues` into
  `ISSUE-SCHEMA.md` → *Native issue fields* (which already owned the
  escalate-only guard, ledger provenance, and the Projects-v2 trap) — the skill
  now applies the floor instead of restating it. `/steer:work` stops re-deriving
  the two-state delivery model (rule 45 is the canonical statement; the skill
  keeps only its own branch/marker/PR substitutions) and its merge-gate
  guardrail is stated once. `/steer:init`'s legacy-template-fork procedure
  (Path A) moved to a new reference `LEGACY-TEMPLATE-FORK.md`; the skill keeps
  detection + a pointer. The `mise.lock` pin procedure — previously restated in
  full in init (twice), adopt, build, and doctor — now lives only in
  `CONVENTIONS.md` → "Toolchain: `latest` in config, pinned in the lockfile",
  with each skill citing it (init also keeps its Node `packageManager`
  resolution step). `/steer:init` and `/steer:sync` also stop restating the
  spine-state routing table ("already initialized / damaged / foreign") and
  defer to `/steer:setup`'s canonical version. No behavior, gate, or invariant
  changed — every rule now has exactly one home.
- **`/steer:audit` slimmed onto its reference files (simplification pass,
  part 2).** The nine-dimension code-audit catalogue moved to a new reference
  `AUDIT-DIMENSIONS.md` (the skill keeps an inline one-line-per-dimension index
  + pointer); the audit/drift reconciliation lifecycle (finding-key vs evidence
  identities, per-finding transition rules, `audit-id` immutability) now lives
  canonically in `ISSUE-WORKFLOW.md` → *Audit & drift* with the skill carrying
  the one-paragraph summary (inverting the previous arrangement); the two
  "relationship" sections collapsed to terse Boundaries notes keeping only the
  operative delegations; and the dashboard / drift-board rendering paragraphs
  defer their mechanics to rule `88-artifacts` / `/steer:reference artifacts`.
  No behavior, gate, or invariant changed — every rule kept exactly one home.
- **Four more always-on rules now carry `inject-when=code-project` scopes**
  (`35-issue-tracker`, `62-hotfix`, `75-compliance`, `90-design-sources`), so a
  knowledge-work folder (the Cowork product-owner case) no longer receives
  tracker-integration, hotfix-lane, delivery-compliance, or design-source rules
  it cannot act on — consistent with the existing scoping of `36-issue-first`
  and the code-loop rules. Code repos are unchanged (the `code-project`
  predicate always injects there); this trims the knowledge-mode ruleset only.
- **The four per-call PreToolUse point-of-action hooks merged into two, halving
  hot-path hook overhead.** `check-trunk-push.sh` + `check-issue-create-contract.sh`
  became `check-bash-actions.sh` (one process per Bash call instead of two, one
  stdin read + JSON field extraction; the trunk-push gate takes precedence in
  the rare compound command that both pushes and creates an issue), and
  `check-code-before-spec.sh` + `check-issue-before-mutation.sh` became
  `check-write-nudges.sh` (one process per editor write; shared root
  resolution + path classification; both dimensions' messages emit together
  when due on the same write). Behavior, cadence markers, exemptions, and the
  Copilot dual-target wiring are unchanged; docs and the Copilot hook manifest
  track the new names.
- **Claude Artifacts are now a first-class, codified deliverable.** The
  discipline for producing a shareable, hosted claude.ai page — previously
  restated inline in `/steer:explain` and `/steer:questions bundle` — is now a
  single source of truth: a new reference `templates/reference/ARTIFACTS.md`
  (loaded via **`/steer:reference artifacts`**) and a lean always-on rule
  **`88-artifacts`**. It covers when an Artifact is the right output vs. when it
  is not, the derived-view discipline (render canonical state, never fabricate a
  value or advance a marker past the source, never persist the page URL), the
  temp-only write invariant, the CSP-driven inline rendering mechanics (load
  `artifact-design` first and `dataviz` for charts; no external hosts), the
  fillable-page copy-out floor, and the inline-Markdown fallback. `explain` and
  `questions bundle` now defer their mechanics to this reference instead of each
  restating them.
- **Three more skills now render shareable Artifacts** (each an on-demand offer
  with a Markdown fallback, derived and temp-only per rule `88`):
  `/steer:audit` publishes its code-health report as a dimension-tiled findings
  dashboard and its spec-drift report as a verdict-chipped drift board (both
  post-confirmation, honoring the skill's read-only-during-run guarantee);
  `/steer:roadmap` offers a shareable release-timeline preview of the milestoned
  work-set; `/steer:help` offers a browsable visual capability menu alongside
  its inline list. `help`'s frontmatter drops `Write` from `disallowed-tools`
  (its one permitted write is the temp HTML, matching `explain`).
- Wired the new `artifacts` reference topic through every enumeration of the
  reference set (the `reference` skill, rule `00-router`, the `standards` skill,
  and the scaffold `CLAUDE.md`), and regenerated the Copilot mirror.
- **The Artifact discipline now carries a styling contract**: a page derives its
  look from the working repo's `DESIGN.md` design tokens when it declares them
  (palette/type/spacing as inlined CSS custom properties — never an invented
  brand, and fonts stay CSP-safe via system-stack fallbacks) and uses the
  `artifact-design`/`dataviz` house default otherwise (`/steer:help` always does —
  it renders steer's own capability set, not a product's state). Light/dark
  support and semantic chart encodings (severity, verdict, status) stay
  non-negotiable under either theme.
- **Codified the fillable-page return leg** in rule `88-artifacts` and the
  `artifacts` reference: a hosted Artifact stores nothing, so data comes back
  **only** through the exported, machine-keyed return document ingested by the
  page's owning skill — the loop `/steer:questions bundle` → PO fills the page →
  `/steer:intake clarify <filled-doc>` already implements — and a new fillable
  page requires its own declared key scheme and ingest route before it ships.
- **The audit code-health dashboard can now render as a fillable triage form** —
  on request, each finding card carries a checkbox (file / leave) and an optional
  note, and the machine-keyed export (each finding under a visible heading with
  its stable `finding-key`, beneath a `steer:audit-triage` marker carrying the
  audited SHA) is ingested by **`/steer:issues publish-audit <triage-doc>`**,
  which files exactly the checked findings, carries the notes into issue bodies,
  and flags stale/unknown keys instead of silently filing or dropping them — the
  second instance of the fillable-page return-leg contract. The drift board stays
  read-only: each drift finding needs a per-finding human decision (its
  decision-checklist issue), not a bulk selection.

### 3.16.0

- Corrected an over-broad claim about the `check-trunk-push` graduation gate:
  rule 45, the `work` skill, and the scaffold `CLAUDE.md` said the trunk-push
  hook surfaces a push when "a second contributor" (or, in the scaffold, "the
  MVP works") appears. The hook detects only **local** signals (a deploy target
  or a `prod` branch) — a new collaborator is caught on demand by
  `/steer:protect`/`/steer:audit`, not at push time — so those surfaces now
  scope the hook to the local signals and attribute the collaborator trigger to
  the on-demand checks (matching `protect`'s existing phrasing). Regenerated the
  Copilot mirror.
- `/steer:intake`'s `allowed-tools` now grant `git push` (all forms) and
  `gh pr create`, so it delivers its PR autonomously like its five sibling
  skills (`work`/`init`/`adopt`/`sync`/`build`) rather than falling through to
  the session/scaffold settings. Closes a gap where the two-state-delivery sweep
  updated intake's prose to call push/PR autonomous but never added the grants;
  `gh pr merge` stays ungranted — the merge review is still the one human gate.
- **Two-state delivery autonomy — the human gate moves to the PR merge.**
  Delivery now runs in exactly two modes, keyed to GitHub branch protection:
  **pr-flow** (protected `main`) where pushing the branch and opening the PR are
  autonomous and the server-enforced **merge review is the one human gate**, and
  **solo-trunk** (unprotected, pre-MVP by declared intent) where the trunk
  commit + push are autonomous. The former one-human checkpoint *before* `git
  push` / `gh pr create` is retired — an open PR is inert behind branch
  protection, so gating its creation was pure friction; **merge and deploy stay
  human-gated everywhere** (`gh pr merge` is never pre-approved). Rule
  `45-commit-autonomy` carries the model (including the *declared-but-
  unprotected* gap: same flow, flagged wall, ADR-recorded when protection is
  genuinely unavailable — e.g. private repos on GitHub Free); rules 00/36/62/99
  and `ISSUE-WORKFLOW.md`/`NEXT-ACTIONS.md` align. `/steer:work`, `/steer:init`,
  `/steer:adopt`, `/steer:sync`, `/steer:build`, and `/steer:intake` now push
  and open their PRs without asking (announced, per rule 00's heads-up
  pattern), and their `allowed-tools` pre-approve `git push` and `gh pr create`
  (`/steer:work` also grants `gh pr edit` for its open-or-update path); the
  end-of-session checklist (rule 99) becomes a status report instead of per-item
  confirmations.
- **New PreToolUse hook `check-trunk-push.sh` — graduation signals now gate
  trunk pushes instead of only nagging.** In a solo-trunk repo that shows a
  local graduation signal (deploy workflow, `infra/` tree, `prod`/`production`
  branch), every Bash `git push` surfaces as a permission **ask** (never a hard
  deny — the human can approve and keep working) that points at
  `/steer:protect`; signal-free solo-trunk repos and all pr-flow repos are
  untouched. Signal detection is factored into the shared `lib/graduation.sh`
  so this gate and the SessionStart `check-graduation.sh` nudge can never
  disagree; the nudge's wording now says pushes are gated until graduation.
  Registered for Copilot CLI too (`copilot-hooks.json`, flat `ask` envelope).
  Fixture coverage in `hooks/tests/run.sh` (12 new cases).
- **`/steer:protect` now owns the delivery-mode marker as a cache of observed
  protection.** Verify reconciles the marker in both directions: protected
  `main` + `solo-trunk` marker → flip to pr-flow (out-of-band graduation, same
  reconciliation as `apply`); `pr-flow` marker + no protection → report the
  missing wall and recommend `apply`, never silently downgrade to solo-trunk.
  Documents the plan-limit escape hatch (branch protection unavailable on the
  repo's GitHub plan → honor-system pr-flow recorded as an ADR so the gap stays
  a visible decision).
- **Scaffold `.claude/settings.json`: `git push` (all forms) and
  `gh pr create` move from `ask` to `allow`, `gh pr edit` added to `allow`;
  `gh pr merge` stays in `ask` and the force-push/`--delete`/`--mirror` denies
  are unchanged.** A `MIGRATIONS.md` v3.16.0 entry carries the non-additive
  `ask`-list removal forward for already-bootstrapped repos (the additive
  settings merge could never drop the stale `ask` entries, and `ask` outranks
  `allow`). Scaffold `CLAUDE.md` + `README.md` explain the new
  protection-defines-the-mode model.
- New skill **`/steer:loop`** — scaffolds an **autonomous loop** (the "loop
  engineering" pattern): a scheduled GitHub Actions workflow that wakes on its own,
  triages work (CI failures, open issues, drift) via `/steer:audit` + `/steer:next`,
  drafts fixes in isolated worktrees reviewed by `steer-reviewer`, pushes its own
  work branches, and opens
  **draft** PRs — the draft flag marks unattended output; the **merge review is
  the gate** (Commit autonomy, two-state delivery). It requires pr-flow (a
  protected `main` — a solo-trunk repo graduates via `/steer:protect` first),
  instantiates the new on-demand template
  `templates/github/workflows/steer-loop.yml` (not bootstrapped — only when asked),
  lands it via the normal autonomous branch-push + PR, and offers
  `verify`/`remove` modes. Added as a
  front door in `rules/00-router.md`.
- New rule **`53-autonomous-loops.md`** — the boundary for autonomous loops: a loop
  may discover, triage, draft, push its own work branch, and open a **draft** PR
  (autonomous delivery up to the merge, exactly like an interactive session), but
  closes only *up to* a
  human gate and never *through* one — merge, deploy, pushing to `main`/protected
  branches, ADR ratification, and real secrets stay human (Issue-first, High-risk,
  Commit autonomy). A loop presupposes pr-flow: never point one at a solo-trunk
  repo. Also
  codifies split ideation/verification, durable state in the tracker + `/spec/**`,
  and the checkable-work bound shared with the Verify loop.
- `/steer:intake` now **tidies the drop location** so an absorbed document does not
  stay stalled where the PO uploaded it. When it absorbs a new version it
  **relocates** the dropped file into its canonical `spec/sources/<id>/versions/<v>/original.<ext>`
  home (a history-preserving `git mv` for an in-repo drop, the same confident move
  `/steer:tidy` performs) instead of leaving a second copy behind; a drop path
  outside the repo (the PO's own file) is copied in and left in place, noted in the
  report. On the already-absorbed no-op path, a byte-identical in-repo re-send is
  surfaced as a redundant duplicate and routed to `/steer:tidy` rather than left
  stalled or silently deleted. Adds `Bash(git mv *)` to the skill's allowed-tools
  for the relocate.
- `/steer:tidy` learns the counterpart rule: a spec/requirements doc whose bytes
  match a committed `spec/sources/**/original.*` is an **already-absorbed** source,
  so the stray is a redundant duplicate — it is **proposed for deletion** (content
  is preserved in the committed source, so it waits for a yes like every delete)
  rather than moved to `/spec/reference/`, which would just duplicate the source.

### 3.15.0

- `/steer:questions` gains a **`bundle`** mode: the outbound counterpart to
  `/steer:intake clarify`. It renders the **PO-answerable** open questions across
  the whole spine (every feature at once; `bundle <feature-id>` narrows to one) as
  a shareable, fillable Claude Code Artifact — with a Markdown fallback — so a
  Product Owner with no repo or Claude Code access can answer them in a browser and
  send the result back. The mode is read-only (dispatched before the resolve
  flow's `SPEC-QUESTIONS.md` heal; writes only the Artifact HTML to a temp dir),
  filters to `owner: product` / human-decision `open`/`investigating` questions
  (excluding code-fact, dev-owned, and `deferred`), and always offers a
  permission-free copy-out box (clipboard/download are progressive enhancement over
  it). Each answer is anchored by a visible feature-scoped `[<feature-id>] Q-NNN`
  heading (the feature scope disambiguates the per-feature `Q-NNN` ids across a
  whole-spine bundle).
- `/steer:intake clarify` recognizes a `bundle` return: when the absorbed document
  carries `[<feature-id>] Q-NNN` answer headings it segments per heading and maps
  each answer to its question by that feature-scoped key **deterministically**
  (bypassing semantic matching), and writes the `pending /steer:questions fold`
  annotation update-in-place per question so a re-absorbed document reconciles
  rather than duplicating.
- **`/steer:sync` now detects a repo missing the `gh`-issue permission allow-list,
  the silent cause of "the whole `gh` surface is walled off" during the issue
  lifecycle.** The `gh issue create/edit/comment` write verbs live in
  `/steer:tracker-sync`'s `allowed-tools`, but a skill's `allowed-tools` grant
  applies *only while that skill is the invoked one* — reached transitively (a PO
  runs `/steer:issues capture`, `/steer:work`, or `/steer:spec materialize`, which
  delegate to the gateway *in prose*), those grants never take effect and the write
  falls through to `.claude/settings.json`. A repo scaffolded before those allow
  entries existed (or never onboarded) then prompts (interactive) or **silently
  auto-denies** (headless) every tracker write. New `github-issue-permissions`
  capability (`scan-capabilities.sh` + `CAPABILITIES.md`) flags that gap — `absent`
  / `mis-wired` (read-only-era `settings.json`) / `present-wired`, GitHub-Issues
  tracker only — so `/steer:sync` (and `--check`) name *why* writes are denied and
  the step-5 `settings.json` reconcile restores the allow-list. Corrected the
  `tracker-sync` frontmatter comment that wrongly promised prompt-free writes in
  non-scaffolded repos through an orchestrator.

### 3.14.0

- **Reconciled the two canonical `/spec` layout definitions so all three
  source-material homes are listed in both.** The `SPEC-FRAMEWORK.md` structure
  tree omitted `spec/reference/` (defined only in the always-on `20-layout`
  rule), while `20-layout.md` omitted `spec/sources/` (the versioned `/steer:intake`
  home) — so neither authoritative definition listed `design/` + `reference/` +
  `sources/` together. Added `reference/` to the framework tree and `sources/`
  to the layout rule, with a one-line note distinguishing the three (design =
  UI/design exports, reference = one-off source material, sources = recurring
  versioned PO documents).
- **Architecture diagrams gain an opt-in D2 option for literal network/infra
  topology.** `/steer:reference architecture-diagrams` now documents a second,
  *complementary* diagram-as-code artifact alongside the architecture picture
  (Mermaid, graduating to a LikeC4 model): a **D2** network topology
  (`spec/design/infrastructure.d2` → committed `infrastructure.svg`) for the literal
  deployed network — VPCs, subnets, AZs, load balancers, gateways — with cloud-vendor
  icons, e.g. a client-facing deployment diagram. Mermaid/LikeC4 stay the
  *architecture picture* (what the system is); D2 answers *how it's wired in the
  cloud* — orthogonal siblings, not competing tiers. The scaffold `mise.toml` ships a
  matching inert (commented)
  `diagrams:infra` task that runs D2 on demand via `mise x d2@latest` (no permanent
  `[tools]` pin — the same no-install pattern as `diagrams:render`'s `pnpm dlx` and
  `convert:doc`'s `uvx`; a persistent pin, if wanted, belongs in `/infra/mise.toml`,
  not the root). Same living-docs drift rule (`32`): edit the `.d2`, regenerate the
  SVG, commit both.

### 3.13.0

- **`/steer:adopt` now stamps the Node `packageManager` placeholder, and the
  additive JSON reconcile refuses to inject unresolved placeholders.** The
  scaffold's root `package.json` ships a `packageManager` placeholder that only
  `/steer:init` resolved — adopt's Phase 10 installed the same file (and the
  Dockerfile whose corepack build depends on the field) with no stamping step,
  so an adopted Node repo without a pre-existing root `package.json` could land
  a literal placeholder corepack hard-fails on. Adopt Phase 10 now resolves it
  exactly as init does, and `scaffold_reconcile.py` skips template-only values
  still carrying an unresolved placeholder (`[Replace …]`, `[Product Name]`,
  `[e.g., …]`) instead of merging them into an existing file — reported as `~`
  lines, with a placeholder-only delta writing nothing.
- **Added the v3.13.0 context7 de-dup migration.** The scaffold's
  `enabledPlugins` drop of `context7@claude-plugins-official` (#325) could
  never reach already-bootstrapped repos: sync's settings merge never removes
  an existing key, and the migration ledger had no entry. `MIGRATIONS.md` now
  carries a v3.13.0 entry that removes the duplicate key (read-then-propose,
  idempotent — the plugin-shipped context7 server keeps providing the
  capability), and `/steer:sync`'s prose now names all three plugin-shipped MCP
  servers (`github`, `markitdown`, `context7`).
- **Polished `/steer:explain`'s edges.** The `dataviz` skill load is now
  conditional on the session offering one (with an explicit proceed-without
  fallback instead of a dead-end hard requirement); the open-questions board
  now includes `deferred` questions — part of the `ENUMS.md` unresolved set
  that can still block a gate — instead of silently dropping them; and the
  plugin README's tool-restriction note now states explain's real `Write` usage
  (the artifact HTML in a temp dir; the Markdown fallback prints inline, never
  saved).
- **Finished propagating the #321 approval predicate and #332 tracker-sync
  exception (pre-release audit sweep).** Three surfaces still carried the old
  unqualified claims: `/steer:spec`'s frontmatter description (and the
  regenerated `steer-spec.prompt.md`) now states that only a blocking question
  gated at intent-approval blocks approval; `/steer:issues`' question-
  reconciliation floor and `ISSUE-WORKFLOW.md`'s ready-for-dev precondition now
  qualify their "no open blocking question" guarantees by gate, matching
  validate's actual predicate.
- **`/steer:explain` now renders a visual, interactive feature page instead of a
  wall of text.** The stakeholder page is built around at-a-glance visuals derived
  strictly from the spec — a `draft → approved → implemented → validated → live`
  status pipeline (marker never advanced past the recorded `Status:`), a PO
  acceptance completion meter, a clickable user-journey stepper, an in/out scope
  board, a light key-concepts relationship diagram (edges only where the intent
  states a relationship), and an open-questions status board flagging blockers —
  with a one-screen summary first and the rest behind collapsible sections. Every
  visual encodes a real spec value (no fabricated charts/numbers/relationships;
  empty sections show *"not specified in the spec"*). Visuals are drawn as inline
  SVG/CSS/JS to satisfy the Artifact CSP (no CDN chart libraries); the skill now
  loads `dataviz` alongside `artifact-design`. The Markdown fallback keeps the same
  at-a-glance shape as static text.
- **`/steer:adopt` now runs `bootstrap-fields` next to `bootstrap-labels`
  (#322).** Adopt's Phase 10 GitHub-Issues setup only created the label
  taxonomy, so a brownfield repo never got the org-level **Priority/Effort/date**
  issue-field verification that `/steer:init` performs — silently diverging from
  greenfield repos while `/steer:tracker-sync` claimed both bootstrap skills call
  it. Phase 10 now invokes `/steer:tracker-sync bootstrap-fields` right after
  `bootstrap-labels`, mirroring init's wording, so tracker-sync's claim holds.
- **Spec-spine enumerations now name the `design/` + `sources/` bootstrap rows
  (#327).** The scaffold MANIFEST installs `spec/design/README.md`,
  `spec/design/source.md`, `spec/design/architecture.md`, and
  `spec/sources/README.md` at bootstrap, but the canonical `/spec` tree in
  `SPEC-FRAMEWORK.md`, init's step-2 spine enumeration, and adopt's Phase 10
  list never mentioned them — a literal follow of the skill text skipped them.
  All three enumerations now name the four artifacts, so bootstrapped repos get
  the full spine the MANIFEST (and template reconciliation) expects.
- **Tightened the seam between the app guide and the root README.** The app
  guide template (`templates/spec/app-docs.md`) no longer re-states the
  product pitch or developer-setup instructions — its opening now defers "what
  this product is and who it serves" to the root `README.md` and directs the
  author to jump straight into how a user *uses* the product, keeping the two
  documents complementary instead of overlapping.
- **Fixed the `/steer:sync` Step-1 detection snippet failing as written
  (#320).** The snippet called `steer_repo_root` but only sourced `spine.sh`;
  it now also sources `hooks/lib/repo-root.sh` first, matching the parallel
  snippet in `/steer:setup`.
- **Unified the `/steer:spec` intent-approval blocking predicate (#321).**
  Step 6 and validate check #1 (in both `skills/spec/SKILL.md` and
  `templates/reference/SPEC-FRAMEWORK.md`) now match approve mode's exact
  predicate: only an unresolved `impact: blocking` question with
  `required_before: intent-approval` blocks intent approval — questions gated
  at later gates block their own gate, not an already-granted approval.
- **Corrected two router-rule inaccuracies (#323).** Rules 00/20 (plus the
  shipped `sources-readme.md` and the regenerated Copilot instructions) no
  longer claim `/steer:reference` prose "is materialized into
  `/spec/reference/`" — no mechanism does that; the prose ships with the plugin
  and is loaded on demand via `/steer:reference`, while `/spec/reference/`
  stays the home for source/research materials. Rule 00's internal-gateway
  wording no longer says "never call these directly" (which collided with rule
  36's instruction to invoke `/steer:tracker-sync`); it now says the gateways
  are not user front doors — reached via the owning skills, never offered to
  the user directly.
- **Fixed help/issues skill metadata drift (#332).** `/steer:help`'s Phase-2
  area grouping now maps the router's `/steer:explain` row (added to "Find your
  bearings") and explicitly sources the below-table `standards`/`reference`
  entries so every menu entry has a declared source; `/steer:issues`'
  frontmatter description now acknowledges the sanctioned `bootstrap-labels`
  inline-`gh` exception instead of claiming ALL GitHub I/O routes through
  `/steer:tracker-sync`.
- **Fixed the `inject-standards.sh` missing-rules fallback banner being dropped
  (#319).** The fail-soft branch's trailing self-fault guard chain leaked a
  non-zero exit status whenever the consumer root was unresolvable or was the
  plugin's own tree — and SessionStart stdout only becomes `additionalContext`
  on exit 0, so the degraded-install banner never reached the session. The
  branch now records the fault under an `if` guard and the hook always exits 0.
- **Fixed `check-unmanaged-repo.sh` anchoring on the hook process cwd (#331).**
  The greenfield-bootstrap nudge resolved the repo root from `steer_repo_root .`
  instead of the SessionStart payload `cwd` like its sibling hooks (the same
  bug class fixed for `check-template-drift.sh` in #270), so it mis-anchored
  whenever the harness cwd diverged from the session cwd. It now reads the
  payload `cwd` via `steer_field`.
- **Hook polish batch (#339).** The `/steer:report` self-report exemption in
  `check-issue-create-contract.sh` now also matches gh's `-R` alias for
  `--repo`; `check-version-pins.sh` no longer matches on `Bash` in `hooks.json`
  (its content extractor skips Bash by design, so every Bash call paid a
  guaranteed no-op hook spawn — the CI repo scanner remains the backstop);
  `reconcile-issue-first.sh` caps its per-file classify loop so a first-turn
  dirty tree with thousands of untracked files can no longer approach the 30s
  Stop timeout; and the `tracker-github` detector in `lib/scope.sh` matches the
  word `github` (`github\b`, aligned with `scan-capabilities.sh`) instead of
  any value merely starting with it.
- **Fixed the scaffold CI changed-line coverage gate for monorepos** (#324).
  The gate in `templates/github/workflows/ci.yml` only looked for a repo-root
  `coverage/lcov.info` / `coverage.xml`, but the shipped root-script fan-out
  (`pnpm --recursive run test -- --coverage`) writes a per-package
  `<package>/coverage/lcov.info` — so the rule-41 gate silently fail-opened
  forever. It now globs `apps/*` and `packages/*` (Node **and** Python reports)
  alongside the root paths and passes every report found to `diff-cover`.
- **Dropped `context7@claude-plugins-official` from the scaffold's
  `enabledPlugins`** (#325): steer already ships a context7 MCP server in its
  own `.mcp.json`, so bootstrapped repos were loading two context7 servers with
  duplicate toolsets. The plugin-shipped server (the documented one) remains.
- **Swept dangling references out of the shipped scaffold/templates** (#326):
  the dead `CLAUDE.md#definition-of-done` anchor (PR template, CI workflow),
  stale "see CLAUDE.md `Stack` / High-risk areas" pointers (`gitignore`,
  `vscode/extensions.json`, app/service `apps/README.md`, `infra/README.md`),
  and bare "see CONVENTIONS.md" file references (`mise.toml`, CI workflow —
  including the user-visible `::notice::`) now point at the plugin-injected
  rules / `/steer:reference conventions` instead of files and sections that
  don't exist in a bootstrapped repo.
- **Standardized Terragrunt fan-out on the current `terragrunt run --all …`
  syntax** (#328): the infra-profile `mise.toml` tasks (and the injected
  infra stack rule, which feeds the generated Copilot instructions) used the
  deprecated `terragrunt run-all …` while `infra/README.md` used
  `run --all` — the two shipped contradictory commands under
  `terragrunt = "latest"`.
- **Scaffold/template polish batch** (#342): differentiated the service
  profile's `apps/README.md` from the app copy (no more dangling `DESIGN.md`
  link or web-app prose); de-linked `packages/README.md`'s reference to
  `apps/README.md` (absent in `library`/`cli` profiles); normalized placeholder
  variants to `/steer:init`'s documented scan set (`[Product Name]`,
  `[e.g., …]`, `[Replace …]` in the spec templates, `ARCHITECTURE.md`, and
  `vision.md`); shipped a `packageManager` placeholder in the Node-baseline
  `package.json` that init now stamps with the mise-pinned pnpm; derived the
  Node Dockerfile's `CMD` from the `APP` build-arg (via a runtime `ENV`, with
  `exec` keeping PID-1 signal handling) instead of hardcoding
  `apps/web/server.js`; and aligned the scaffold's Node major on 24 across the
  Dockerfile, CI `setup-node`, and the `@types/node` catalog entry, with
  "confirm current stable major on adoption" comments.

### 3.12.0

- **Added a clarification-document pipeline to `/steer:intake` (new `clarify`
  mode).** A client clarification doc that answers open questions and/or
  introduces new scope is now absorbed through intake's shared front-end (source
  identity, versioned commit under `spec/sources/`, `HISTORY` record), then
  segmented semantically, mapped **inline** (no per-unit agent fan-out — mirrors
  the `/steer:questions` step-4 cost guardrail) against open `Q-NNN`s and the
  feature list, and sorted into a three-bucket, human-confirmed worklist:
  answers-an-open-question → `/steer:questions`; new-info → the existing step-5
  reconcile rows; low-confidence → surfaced for the human, never guessed. Every
  folded answer records the source-ref + exact quoted span for auditability, and
  intake still writes no feature/spec prose itself.
- **`/steer:questions` gained a doc-sourced answer path.** An answer may now
  arrive from an ingested clarification doc (via `/steer:intake clarify`) and is
  folded under the same step-6 tier gate as an in-session answer — no lighter gate
  for arriving as a document — recording the source-ref + quoted span as
  provenance. Questions remains the single owner of folding an answer into an open
  question.
- **Added `/steer:explain` — a shareable, plain-language view of a feature.** A
  new read-only front-door skill that renders one feature's spec (`intent.md` +
  optional `contract.md`, tracker status, open questions) as a high-level
  Claude Code Artifact — a private, hosted page on claude.ai you can share with a
  stakeholder — with a Markdown fallback where Artifacts are unavailable
  (Bedrock/Vertex, zero-data-retention orgs, no claude.ai login). It is a
  **derived view**: the `/spec` and tracker item stay canonical; it never
  fabricates status, never auto-generates per feature, never persists the artifact
  URL, and writes nothing into `/spec`, `/apps`, or `/packages`. This is steer's
  first PO-facing presentation layer — the router, README, CROSS-SURFACE inventory,
  docs, and Copilot prompt mirror are updated to register it.
- **Codified the Conventional Commits convention.** Expanded the always-on
  Commit-autonomy rule (`45-commit-autonomy.md`) from a passing "conventional
  messages" mention into a proper spec — the `type(scope): summary` format, the
  canonical type list (`feat`/`fix`/`docs`/`refactor`/`perf`/`test`/`build`/`ci`/
  `chore`/`style`/`revert`), and the breaking-change marker (`feat!:` / `BREAKING
  CHANGE:` footer) — and added the full-detail companion section to
  `CONVENTIONS.md` (surfaced via `/steer:reference conventions`), including the
  rationale and the two deliberate non-adoptions: no commit-lint gate (the PR is
  the gate, and it would drag a commit-lint dependency into every product repo)
  and commits are not the changelog (the curated `CHANGELOG.md` stays the release
  source, not commit-derived notes). Documents the practice the repo already
  follows at ~100% — no new tooling, no enforcement.
- **Added:** container-image support for deployable apps. New on-demand
  `templates/docker/` reference templates (`Dockerfile.node` for the default
  Next.js stack, `Dockerfile.python` for a FastAPI/uv service, and a shared
  `dockerignore`) are instantiated into `apps/<app>/Dockerfile` + a repo-root
  `.dockerignore` when the first deployable app is created — by `/steer:build`
  (step 5) and `/steer:adopt` (Phase 10, copy-and-adapt, never clobber), with a
  discoverability pointer in the `app`/`service` `apps/README.md`. Deliberately
  **not** bootstrap-installed (a Dockerfile with no app to build would ship
  broken) and **not** given to `library`/`cli`/`infra`. The scaffold `ci.yml`
  gains a lifecycle-safe **image-build step** that builds every `apps/*/Dockerfile`
  (and a root `Dockerfile`) when present — build-only, no registry push — and
  skips with a notice when none exists, so a green `ci` never implies an image
  built. Base-image majors follow `policy/versions.yml` (enforced by the existing
  version-pin scanner). Rule `10-stack` now states each deployable `apps/<app>`
  carries a `Dockerfile`. No hard "must have a Dockerfile" gate.
- **Added:** bundled `.gitattributes` (`gitattributes` → `.gitattributes`) to the
  repo scaffold, shipping `CHANGELOG.md merge=union` so product repos inherit the
  same protection this marketplace already uses — concurrent PRs appending bullets
  under `### [Unreleased]` are auto-resolved by git's built-in `union` driver
  (both sides' added lines kept, no conflict markers) on local merge/rebase and
  GitHub's merge button. Installed by `/steer:init` / `/steer:adopt`; merged
  additively (never clobbered) when a repo already has one — `scaffold_reconcile.py`
  now treats `.gitattributes` as a line-based file alongside `.gitignore` /
  `.worktreeinclude`.

### 3.11.0

- **Subagent model-selection guidance in `CONTEXT-HYGIENE.md`.** Added a "Which
  model" split to the delegation section: read/search/summarize fan-out runs on a
  Sonnet-tier model at low effort (cheaper per token, same read volume — cuts cost,
  not token count), while reviewer/verify/judge delegations stay on the session
  model (Opus-tier), with a caveat against cheap models in budget-capped agentic
  loops. Keeps `steer-reviewer` on `inherit`. Prose-only; no behavior change.
- **Added:** bundled Claude Desktop **Code-tab preview-server** config for the
  `app` profile — `profiles/app/claude/launch.json`, installed to `.claude/launch.json`
  by `/steer:init` / `/steer:adopt`. Pins one `web` config that runs the app's
  `pnpm dev` (rule 15) on port 3000, so the preview pane and auto-verify screenshots
  drive the repo's real dev command instead of relying on the Code tab's
  auto-detection. Convenience only: app-profile-scoped, never overwrites an existing
  `launch.json`, and (pre-stable `version 0.0.1`) enforced by no gate — see the
  scaffold `MANIFEST.md` row for the full behavior and the polyglot repoint to
  `mise run dev`. Bring services/DB up first with `mise run dev:setup`.
- **Advisor tool pointer in `REVIEW-LOOP.md`.** Added an optional, per-developer
  note relating Claude Code's Advisor tool to the review-gated loop — when to
  reach for each, and why `advisorModel` deliberately stays out of the scaffold's
  checked-in `settings.json` (per-developer, experimental, Anthropic-API-only).
  Prose-only; no behavior or config change.

- **Output-discipline tightening pass on the always-on rules (#165).** Cut hedging,
  redundant restatements, and unneeded justification prose across `rules/*.md` (chiefly
  `00-router`, `05-roles`, `30-spec-workflow`, plus small trims to `10-stack`,
  `22-housekeeping`, `26-context-hygiene`, `36-issue-first`, `62-hotfix`) so the ruleset
  obeys its own `87-output-discipline`. No semantic change: every instruction,
  cross-reference, mode token, and scope marker is preserved. On inspection the corpus
  was already largely lean, so the honest reclaim is ~2–3% of the always-on payload, not
  the 15–25% the issue estimated — reaching higher would require dropping the
  cross-references and examples the rules deliberately carry.
- **Added:** `/steer:help` — a human-facing capabilities menu (#168). Until now
  capability discovery was entirely model-mediated: a user who wanted to *browse*
  what steer can do had no surface, since the `00-router` intent→skill table is
  always-on model context, not something a human reads, and neither `/steer:setup`
  (a bootstrap dispatcher) nor `/steer:next` (a workspace navigator) answers "what
  can steer do *at all*." The new read-only skill renders the router's front-door
  table in plain language, grouped by workflow, and needs no repo state so it works
  before bootstrap. It **sources the live `00-router` table at invocation** rather
  than transcribing it, so the menu can't drift from actual routing — a new front
  door appears automatically. An optional argument zooms into a single skill or
  area. Discovery stays distinct from navigation (`/steer:next`) and dispatch
  (`/steer:setup`).

### 3.10.0

- **Fixed:** the bundled scaffold `.claude/settings.json` shipped over-broad
  `allow` entries that a consumer repo's automated security review flagged as
  allowlist escapes on every `/steer:sync` (#294). Hardened to a least-privilege
  split: `allow` now carries only the read-only `git remote` forms (`-v`, `show`,
  `get-url`) — the mutating subcommands (`set-url`/`add`/`remove`/`rename`, the
  origin-repoint exfil vector) are `deny`-listed so they stay blocked even when a
  stale broad `git remote:*` survives a consumer's additive reconcile. Destructive
  `git rm` and the MCP write tools (`mcp__github__issue_write`/`sub_issue_write`)
  moved from `allow` to `ask`. The autonomous issue-first path (#180) stays silent:
  the `gh issue create`/`edit` verbs remain in `allow`, and `/steer:tracker-sync` /
  `/steer:report` re-grant the MCP write tools via their own `allowed-tools`. Only
  bare/ad-hoc MCP issue writes now prompt. `check_standards.py` enforces the new
  split so the template can't regress.
- **Added:** opt-in architecture-diagram support. A new bootstrap file
  `spec/design/architecture.md` gives every repo a canonical home for a **living,
  global architecture diagram** that `ARCHITECTURE.md` links to (preserving the
  "narrative + tables, link don't inline" contract). **Tier 1 (default):** hand-authored
  Mermaid (`flowchart` + `sequenceDiagram`) that renders in GitHub and the docs site
  with no toolchain. **Tier 2 (opt-in):** a LikeC4 C4 model, activated by adding a
  `*.likec4` source and uncommenting the inert `diagrams:render` task in the scaffold
  `mise.toml` (exports Mermaid back into `architecture.md`, so the tiers compose). New
  `/steer:reference architecture-diagrams` topic documents both tiers, tool trade-offs,
  and drift discipline; rule `32-living-docs` now requires the linked diagram to be
  updated in the same PR as the change it reflects.
- **Fixed:** a repo bootstrapped before `init` reliably instantiated the app guide
  (`spec/app/README.md`), or by an `init` run that skipped the step, was left with
  `/spec/app/` references (rules `20`/`32`/`50`, the PR template, scaffold
  `ARCHITECTURE.md`) pointing at a directory that never existed — and no `sync`
  could repair it: the guide is materialized from a spec template, not a static
  scaffold file, so additive reconciliation (which only splices into files that
  already exist) never created it, and `STEER_SPINE_REQUIRED` deliberately omits
  it so the gap never tripped the `damaged` nudge. Added an `app-knowledge-docs`
  capability (`CAPABILITIES.md` + `scan-capabilities.sh`) that `sync` walks every
  run: `absent → create spec/app/README.md from templates/spec/app-docs.md` as a
  proposal (a stub is valid pre-POC). Backfills affected repos on their next sync
  without the org-wide false-`damaged` noise a required-spine change would cause.
- **Added:** rule `51-verify-loop` (code projects) — turn a task into a verifiable
  end state, iterate against the harness until green with a bounded loop,
  stop-and-report when blocked, and never loop on uncheckable/long-compute work;
  also directs stating an assumption before building on an ambiguous request.
- **Changed:** `/steer:report` now **auto-files** steer self-reports upstream — the
  confirmation step is gone and the scoped `Bash(gh issue create --repo
  element22llc/e22-plugins *)` verb (plus a same-repo-scoped `gh issue comment`
  and the MCP issue tools) is pre-approved in its `allowed-tools`. Secret /
  absolute-path / product-code scrubbing and fingerprint dedupe are retained; the
  scrub now **redacts or omits** unredactable content instead of asking. The
  offline / no-auth paste-URL fallback is unchanged.
- **Changed:** `/steer:tracker-sync` gained an `allowed-tools` block pre-approving
  the issue create + find-before-create dedup surface (`mcp__github__issue_write`
  / scoped `gh issue *` verbs + issue reads/search), so product-issue creation is
  auto-approved in non-scaffolded repos too (scaffolded repos already granted it
  via `.claude/settings.json`). The delivery surface (`gh api`/graphql, PR merge,
  branch protection) is deliberately not listed and stays host-gated. Its `push`
  step now follows Intent-aware confirmation — explicit captures file without a
  prompt, inferred batches (e.g. audit-surfaced drift) still take one
  confirmation, and security disclosures take human review.
- **Fixed:** `check-issue-create-contract.sh` no longer misfires on `/steer:report`'s
  upstream self-report create (`--repo element22llc/e22-plugins`) — including the
  label-less fallback that carries no `steer:` marker — which must never be routed
  through `/steer:tracker-sync`.
- **Changed:** rule 36 (and its generated Copilot mirror) note that the scaffold
  ships the issue-create grant, so find-or-create runs unprompted by default; a
  still-blocked create is a host gate, not a skipped step.
- **Fixed:** five skills ran a bundled plugin helper script their `allowed-tools`
  didn't grant, so `/steer:<skill>` prompted the user on every run (the issue #266
  prompt-spam class the pre-release audit fix missed): `build` and `spec-scaffold`
  run `template-reconcile.sh`, `doctor` runs `scan-prereqs.sh`, `init` runs
  `scaffold_reconcile.py` (which `sync` already granted), and `adopt` runs both
  `template-reconcile.sh` and `scaffold_reconcile.py` from its `PROCEDURE.md`.
  Added the matching `Bash(<interp> *scripts/<name>*)` grants (`spec-scaffold`
  gained its first `allowed-tools` block).
- **Added:** `check_standards.py` regression guard (`check_skill_script_grants`) —
  a skill that invokes a bundled `${CLAUDE_PLUGIN_ROOT}/scripts/*.sh|*.py` helper
  (in SKILL.md or a factored-out body like `PROCEDURE.md`) must pre-approve it in
  `allowed-tools` under a matching interpreter, so this prompt-spam class can't
  return silently. Scoped to the plugin-script family (the one command family
  whose mention is unambiguously an execution); runs in `mise run check`.

### 3.9.0

- **Fixed:** `build`'s PO guardrail no longer names a `pnpm deploy:*` task that
  rule 15 retired (promotion is merge-triggered) — the "never deploy" instruction
  now reads "never deploy or promote to any environment", keeping the guardrail
  without pointing at a task that no longer exists.
- **Changed:** skill hygiene sweep (prose/frontmatter, no behavior change). Added
  `argument-hint` to `next` (free-text constraints) and `sync` (`[--check]`), which
  consume arguments but declared none. Extended `issues`' `argument-hint` to include
  the `publish-audit`/`publish-drift`/`publish-adoption`/`publish-findings`/
  `bootstrap-labels` modes it already declares (listed explicitly to keep the skill
  subcommand-leading for cross-reference validation). Renamed the retired `drift`
  skill name to `/steer:audit spec` / `/steer:audit code` in `sync`'s axis table.
  Fixed `report` to pass `--label bug --label steer:self-report` (the prose already
  promised both labels; fallback for a missing label preserved). Updated
  `tracker-sync`'s caller list to name all drivers (`spec`, `roadmap`, `intake`,
  `next`'s read flows, plus `audit spec`) instead of just `issues`/`work`. Made the
  `doctor` and `build` pointers to init's lock step name Path A step 4 / Path B step
  5 (the numbering differs). Added a PO-register sentence to `next` and `roadmap` so
  their L1–L7 / milestone readouts render in plain product language for a PO (rule
  05), matching the pattern `doctor`/`build` already model. Copilot prompt artifacts
  regenerated.
- **Fixed:** `/steer:audit` cited a nonexistent issue-body template
  (`audit-{run,finding}.md` brace shorthand → `audit-finding.md`); now points at
  the real `audit-run.md` and `finding.md`. (#269)
- **Fixed:** skills and reference prose no longer present the `user-invocable: false`
  gateways as user commands. `/steer:spec` suggests filing via `/steer:issues`
  (not `/steer:tracker-sync push`) and delegates feature scaffolding to
  `/steer:spec-scaffold` instead of re-implementing the copy; `setup` no longer
  falsely claims init/adopt/sync are "hidden from the slash menu"; the reference
  matrix (`INVOCATION.md`), `SPEC-FRAMEWORK.md`, `TRACEABILITY.md`, and
  `feature-intent.md` route users to callable front doors; `spec-scaffold`'s
  `when_to_use` states it is gateway-only. `INVOCATION.md` also gains the six
  previously-omitted skills (`setup`/`intake`/`roadmap`/`protect`,
  `doctor`/`report`). (#265)
- **Fixed:** cross-skill contract inconsistencies — `sync` and `init` now key the
  foreign-vs-damaged spine decision off `steer_spine_state` (foreign → adopt/init,
  only damaged/managed are sync cases); `roadmap` files expected-unbuilt backlog via
  find-or-create (`materialize`/`tracker-sync find-or-create`), not the drift path,
  and never labels it `spec-drift`; `issues` documents `bootstrap-labels` as the one
  sanctioned direct-`gh` exception to its gateway invariant; `sync`'s duplicate
  "`--check` stops here" now correctly runs through the step 6.5 hygiene scan;
  `intake` routes acceptance-criteria changes to `/steer:spec` (not `tracker-sync`,
  whose import takes an issue ref); `build` gains the brownfield guard (substantial
  code → `/steer:adopt`, don't greenfield over a working app). (#272)
- **Changed:** context-cost pass on skill bodies — moved reference-grade prose out
  of SKILL.md bodies into its declared canonical home, leaving each skill an
  operative summary + a section-anchored pointer (behavior-preserving). The
  GitHub issue-field API recipes (GraphQL `setIssueFieldValue` input shape, the
  REST `X-GitHub-Api-Version: 2026-03-10` endpoint, option-id-vs-name, POST-not-PUT)
  moved from `tracker-sync` into `ISSUE-SCHEMA.md` §"Reading & writing issue
  fields"; the operative rules (single-source-of-truth, capability-degradation,
  ledger provenance, never-Projects) stay in `tracker-sync`. The `mise` lockfile
  runbook (duplicated in `init` ×2, `adopt`, `build`) now reduces to the one-line
  command + the `linux-x64`-mandatory caveat + a pointer to `CONVENTIONS.md`
  §Toolchain. The template-reconciliation semantics (`spec-scaffold`, `build`,
  `adopt`, `sync`) reduce to the diff command + additive-only rule + a pointer to
  `SPEC-FRAMEWORK.md` §"Template reconciliation". Removed the hand-maintained rule
  filename enumeration from `/steer:standards` (and its `check_standards` guard +
  tests) — "read every `*.md` under `rules/` in lexical order" already fully
  specifies the behavior. `audit`'s reconciliation section is left as the canonical
  full lifecycle (`ISSUE-WORKFLOW.md` §"Audit & drift" is the summary and defers to
  it) with a reciprocal cross-link, since its `resolution_mode` auto-close gating is
  operative safety detail.
- **Fixed:** the scaffold `.claude/settings.json` allowlist now pre-approves the
  hosted GitHub MCP server's current issue tools (`issue_write`, `issue_read`,
  `sub_issue_write`) instead of the retired `create_issue`/`update_issue`/
  `get_issue`/`add_sub_issue` names — so `/steer:issues` and `/steer:work` stop
  prompting on every issue mutation. (#264)
- **Fixed:** `allowed-tools` now match what each skill actually runs, closing the
  prompt-spam 3.8.0 set out to eliminate: `build` grants `mise run dev:*` and
  `pnpm dev*` (step 8), `sync` grants `git switch`/`checkout -b`/`mv` and its
  `scan-capabilities`/`scan-invocations`/`scaffold_reconcile` detectors, and
  `adopt`/`init`/`intake` — which shipped no `allowed-tools` — gain the routine
  read-only git inspection + `git switch`/`add`/`commit` set plus per-skill extras
  (`mise install`/`lock`/`npm view` for init/adopt; `mise run convert:doc`/`shasum`
  for intake). `protect`'s read-only `gh api` verification examples are unquoted so
  the `gh api repos/*` grant matches them; the PUT/PATCH writes stay un-granted and
  still prompt (rule 45 one-human checkpoint preserved — no push/PR/merge grants
  anywhere). (#266)
- **Changed:** trimmed the paragraph-length `description` frontmatter on eight
  skills (`work`, `tracker-sync`, `roadmap`, `report`, `protect`, `audit`,
  `intake`, `sync`) to purpose + primary trigger, moving protocol detail into the
  body. Claude Code concatenates `description` + `when_to_use` into the routing
  listing and truncates the combined text at 1,536 chars — `work`'s combined length
  was 1,708, so its trailing `when_to_use` trigger phrases were being silently
  dropped. All skills are now well under the cap (max 1,156). Copilot prompt
  artifacts regenerated. Added a `check_plugin.py` guard (+ tests) that fails any
  skill whose `description` + `when_to_use` exceeds the cap, and documented the
  mechanic in `AUTHORING.md`. **Note:** the originating issue proposed *removing*
  `when_to_use` on the premise it was unparsed; verification against the current
  Claude Code skills docs showed it **is** a recognized field appended to
  `description` for routing, so it was kept — removing it would have deleted
  routing signal, not saved context.
- **Changed:** hook hardening pass (all hooks stay POSIX sh, no jq, fail-open).
  Added `timeout` to every `hooks.json` entry (10s for SessionStart/PreToolUse,
  30s for the Stop hook) so a wedged `git` spawn can't stall session start / turn
  end for the 600s default. In `check-issue-before-mutation.sh`, hoisted the
  once-per-session marker **check** above the git-spawning hotfix/sync exemptions
  (creation stays past them, so it still marks only when it nudges).
  `check-issue-create-contract.sh` now reads the tool name via `steer_tool`
  (top-level `.tool_name`) instead of `steer_field`, so a Bash command whose text
  embeds `"tool_name":"…create_issue"` is no longer misread as an MCP create.
  `check-version-pins.sh` resolves `policy/versions.yml` from the work-tree root
  (honoring a repo-local stricter policy when editing from a subdir) and escapes
  the pin's dots before the allow-pin ERE match. Appended `| tr '\n\t\r' '   '` to
  the JSON sanitizers in four hooks so control chars can't break the hook JSON
  envelope. Removed the shadowed `mise.lock` entry from `lib/classify.sh`'s
  operations case (`*.lock` already classifies it as an exempt lockfile). Hook
  test harness: `run_hook` now records the hook's exit code and `assert_empty` also
  requires rc 0 (a hook that crashes before printing no longer passes as "silent");
  added fixtures for the tool-name, subdir-policy, dotted-pin, and control-char
  fixes (284 cases, was 279).
- **Fixed:** the issue-create contract guard (`check-issue-create-contract.sh`)
  now recognises the hosted GitHub MCP server's renamed write tool — `issue_write`
  (the successor to `create_issue`) matches the create pattern, while
  `sub_issue_write`/`add_sub_issue` (a relationship link, not a create) and
  comment tools are excluded — closing a silent enforcement gap on the current
  MCP path. Fixtures added. (#264)
- **Fixed:** `check-template-drift.sh` now resolves the work-tree root from the
  SessionStart payload cwd (like `check-open-questions.sh`), so drift detection
  works when Claude starts in a subdirectory instead of silently finding nothing.
  It also collapses the per-heading `grep` storm (O(features × headings) spawns at
  every session start) into a single `awk` per file pair, and gains fixture
  coverage (drift / reconciled / placeholder-skip / subdir cwd). (#270)
- **Fixed:** the hooks' no-jq JSON fallback (`lib/json.sh`) now unescapes
  `\n`/`\t`/`\r` with `awk` instead of `sed` — BSD sed (the macOS default, the
  exact environment the fallback exists for) emitted literal `n`/`t`/`r`,
  collapsing multi-line content to one line and letting a `# steer:allow-pin` on
  any line suppress version-pin denials on every other line. `NotebookEdit` is now
  a live matcher on the version-pin gate (`new_source` is inspected) instead of a
  dead entry. Fixtures added. (#271)
- **Fixed:** the always-on ruleset no longer teaches deprecated forms. Rules 10 and
  12 cite the canonical `# steer:allow-pin <reason>` version-pin bypass instead of
  the legacy `# pin-ok:`; rule 15 drops the phantom `pnpm deploy:nonprod`/`:prod`
  commands (no scaffold task defines them) in favour of merge-triggered promotion;
  the scaffold README quickstart adds the `mise trust` step the rule assumes; and
  rule 20 notes `/spec/reference` also holds materialized `/steer:reference` prose.
  Regenerated `copilot-instructions.md` accordingly. (#273)
- **Changed:** scaffold currency & coherence pass (all mechanical). Bumped stale
  action majors in the scaffold CI workflow (`actions/setup-node@v4→v6`,
  `github/codeql-action/upload-sarif@v3→v4`). Reworded the `infra/mise.toml`
  header, which contradicted the no-placeholder-lockfile policy — it now describes
  creating `infra/mise.lock` on first pin (`touch` → `mise install` → `mise lock`)
  instead of a "committed placeholder" that never ships. Aligned the Windows/WSL
  prose in the scaffold `README.md` and `reference/CONVENTIONS.md` with rule
  `10-stack` (WSL2 for CLI/IDE work; Git for Windows suffices on the Claude Desktop
  Code tab) instead of mandating WSL2 for everything. Added Node `20` to
  `policy/versions.yml` `node.denied` (EOL 2026-04; defense-in-depth below the ≥22
  floor). `MANIFEST.md`: noted the optional, not-installed `../github/agentic/`
  workflow; named all six on-demand `templates/spec/` templates
  (`build-status`/`productionization`/`source-manifest` were omitted); and
  documented why the `Bash(git add*.env)` deny stays narrow (variants are covered by
  `.gitignore` + the `git add --force` denies; widening to `.env.*` would re-block
  `.env.example`).
- **Changed:** bumped the re-listed `frontend-design` plugin pin in
  `.claude-plugin/marketplace.json` from `c91a6b6` to `423563c` (Anthropic's
  official v1.0.0 → v1.1.0 refinement of the design-guidance skill). Referenced,
  not vendored — content is never copied here.

### 3.8.0

- **Changed:** agent-authored GitHub issues now render **clickable references**
  for POs. Every spec/code file path in an issue body (`Spec references`,
  `Affected specifications`, `Evidence`) is emitted as a Markdown link to the
  file on the repo's default branch (`REPO_BLOB_BASE/<path>`, with a `#L<n>`
  anchor when a line is cited) instead of grey, non-clickable inline code — the
  `steer:spec-path` marker stays the bare path, so marker-based dedup/reconcile
  are unaffected. Implementable kinds (feature · task · bug) also gain a visible
  **`Delivery`** managed-block heading that mirrors the otherwise-invisible
  `steer:pull-request` / `steer:branch` markers as a clickable `PR: #NN` /
  `Branch: …` line, maintained by `/steer:tracker-sync link-pr` and `/steer:work`.
  Touches the `issue-bodies/*` templates, `ISSUE-SCHEMA.md` (new *Clickable
  references* convention + heading lists), `tracker-sync` (`create` renders
  links; `link-pr` updates the `Delivery` line), and `issues` (`materialize`).
- **Added:** `/steer:sync` now repairs **invocation hygiene** in a managed repo's
  live prose. A new read-only detector (`scripts/scan-invocations.sh`) derives the
  valid invocation surface live from the plugin (skill names, the
  `user-invocable: false` gateways, and the `reference` modes) and flags slash
  invocations in `CLAUDE.md` / `README.md` / the PR template that no longer resolve —
  legacy `/e22-*` prefixes, bare `reference`-mode invocations (rewritten to the
  `/steer:reference <mode>` form), calls to `user-invocable: false` gateways
  (routed to a front door), and unknown tokens. Sync auto-applies the deterministic
  rewrites read-then-propose on its PR branch and surfaces the rest for the dev; it
  never scans append-only/provenance prose (`spec/HISTORY.md`, reports, ADRs) or the
  marketplace id. A version-keyed one-shot ledger entry (`MIGRATIONS.md` v3.8.0)
  carries the `reference`-mode renames forward for already-adopted repos. Documented
  in `INVOCATION.md` → "Drift detection & auto-repair". Closes the consumer-repo gap
  that the plugin's own `check_standards.py` only covered for the plugin itself.
- **Changed:** widened the scaffold `.claude/settings.json` `permissions.allow` so
  the dev/PO flow stops prompting on moves the rules already declare **autonomous**.
  The friction was never in `ask`/`deny` (that gate — `git push`, `gh pr create`,
  `gh pr merge` — is the deliberate one-human-checkpoint and is unchanged); it was
  in `allow` *gaps*. Now pre-authorized: the Rule-45 branch moves `git switch`,
  `git checkout -b`, plus `git fetch`, `git mv`, `git rm`, `git stash`; and the
  toolchain the PO/`build` flow drives itself — `mise install`, `mise lock`, and the
  **named** `mise run dev` (the `mise run:*` wildcard stays banned, so `mise run
  deploy` still prompts). `/steer:build` — which previously had **no** `allowed-tools`
  and so prompted a non-technical PO on every toolchain/branch command — gains the
  matching frontmatter grants, mirroring `/steer:work`. Bare `git checkout -- <file>`
  and every delivery verb remain gated. A new `check_standards.py` guard asserts the
  set stays under `allow` so it can't silently regress.
- **Fixed:** the scaffold `permissions.deny` rule `Bash(git add*.env*)` false-positived
  on `.env.example` — the one env file the scaffold deliberately ships and commits —
  blocking a legitimate `git add`. Narrowed to `Bash(git add*.env)` so it still denies
  the canonical secrets file while real secrets stay covered by `.gitignore` and the
  separate `git add --force` deny.
- **Fixed:** the SessionStart template-drift detector (`check-template-drift.sh`)
  no longer falsely flags every correctly-completed feature on every session. It
  did a verbatim heading match that included the seed `### Q-001 — [...]
  <!-- steer:placeholder -->` open-question block — but that block is by design
  rewritten or deleted once a feature has a real question or is fully specced, so
  the match never succeeded and each completed `intent.md`/`vision.md` was reported
  as "missing" a section it had legitimately filled in. The detector now skips
  headings carrying `<!-- steer:placeholder -->`, mirroring `check-open-questions.sh`,
  which already ignores the same marker. Resolves #231.

### 3.7.0

- **Added:** a **solo-trunk enforcement floor + graduation nudge** (#242). A new
  SessionStart hook `check-graduation.sh` fires only in solo-trunk and only when a
  local signal is present (a `prod`/`production` branch, a deploy workflow, or an
  `infra/` tree), nudging the owner to graduate to PR flow via `/steer:protect`;
  `/steer:audit` and `/steer:protect` add the networked confirmation (a second
  collaborator) and escalate when graduation conditions are met. The shipped
  `ci.yml` changed-line coverage gate now also runs on push to `main`, self-gating
  on the delivery-mode marker so it enforces the Definition-of-Done coverage floor
  in solo-trunk (which has no PR) while never re-gating a post-merge push in
  pr-flow. Rule 50 notes the floor.
- **Added:** an **advisory `spec-drift` CI job** in the shipped scaffold
  `ci.yml` — pure shell + git (no stack, no Python), it *warns* (never blocks)
  when a change touches application behavior (`apps/`, `packages/`, `src/`, …)
  without updating a feature `contract.md` / `intent.md` or `spec/HISTORY.md`.
  Runs on PRs and on push to `main` (the only enforcer in solo-trunk). This is
  the machine surface of rule 55, now noted there. The repo's `actions` mise task
  also lints the scaffold template explicitly (previously unlinted). Resolves #243.
- **Added:** a published **Spec `Status:` ↔ issue `steer:state` crosswalk** in
  `ISSUE-WORKFLOW.md` (the single authority for how the two state machines align,
  making `reconcile` deterministic), cross-referenced from both enum sections in
  `ENUMS.md` and from the `/steer:tracker-sync`, `/steer:spec`, `/steer:audit`, and
  `/steer:work` reconcile/transition steps. A new `check_standards.py` guard
  (`check_crosswalk`) fails the build if a `feature_status` or `issue_state` token
  is added to the registry without a matching crosswalk row. Resolves #244.
- **Added:** a hotfix / incident fast-path (`62-hotfix` rule + `/steer:work --hotfix`).
  A production incident is high-risk *and* time-critical at once — the lane is the one
  sanctioned speed lever, opened only on an objective entry condition (deployed
  production with real users/data **and** an active incident, not merely "urgent" work).
  It relaxes ceremony and ordering (issue filed after-the-fact on a `hotfix/<n>` branch,
  expedited single-reviewer) while keeping every human authority gate (push/PR/merge/
  deploy stay human-gated — the flag does **not** broaden `allowed-tools`), and requires
  a mandatory post-incident follow-up (backfill the issue, spec/ADR, `HISTORY.md`) so
  Definition of Done is deferred, never waived (#245). The issue-first hooks now exempt
  `hotfix/*` branches and reframe the Stop advisory as the follow-up reminder.
- **Changed:** slimmed the always-on router (`00-router.md`) — the ~17-line "bootstrap
  precedence" bullet collapses to a compact entry-routing decision that points at its
  canonical homes, with the developer dispatch nuance (announced-up-front, durable-
  decisions-wait-for-spine, prototype-changes-ceremony-not-scaffold) relocated into the
  `/steer:setup` skill. Removes a duplicate of the prototype mechanics already owned by
  Spec workflow, shrinking the injected context budget (#247).
- **Fixed:** the issue-first host-gate fallback is now stated once, in `ISSUE-WORKFLOW.md`
  → "Host gating" (principle 3). The Authorization & confirmation block no longer restates
  the mechanic and its claim is corrected to match reality — the always-on `36-issue-first`
  rule and the issue-mutation hooks carry only a terse point-of-use reminder, not a second
  normative copy (#246).
- **Added:** `/steer:intake` — a front-door skill that absorbs a PO-supplied spec
  or roadmap **document** (docx/pptx/xlsx/pdf) into the spine. It version-stamps and
  commits both the original binary and a normalized Markdown extraction under
  `spec/sources/<source-id>/versions/<vNNNN-DATE>/`, `git diff`s the new extraction
  against the prior one to surface a structured *what-changed* report, then routes
  the real changes into intent/contract/vision/roadmap and the tracker by delegating
  to `/steer:spec-scaffold`, `/steer:tracker-sync`, `/steer:audit`, `/steer:roadmap`
  and `/steer:questions` — never clobbering human prose (conflicts become Open
  questions), appending a `spec/HISTORY.md` entry per absorbed change, and surfacing
  drift for a human rather than resolving it silently. Idempotent: re-running on an
  unchanged document (binary-hash guard) is a no-op, and a new version diffs only
  against the current latest. Conversion reuses the markitdown MCP server already
  shipped in `plugins/steer/.mcp.json`, with a new `mise run convert:doc` scaffold
  task as the deterministic on-disk path. Adds the `source-manifest.md` and
  `sources-readme.md` spec templates (the latter installed as `spec/sources/README.md`),
  a *Versioned source documents* section in the design-sources reference, and the
  router front-door row.
- **Changed:** context-hygiene (`rules/26-context-hygiene.md`, reference
  `CONTEXT-HYGIENE.md`) now tells Claude **not to offer saving findings to session
  memory**. Private auto-memory survives compaction but is invisible to the repo,
  the PR, and teammates — working notes, never the team's record. A session finding
  is routed to its canonical on-disk home **by type** (bug fix → regression test;
  operational/behavioral fact → app guide / `HISTORY.md`; unresolved bug/follow-up →
  linked tracker issue; durable design decision → the spine) and that capture is
  surfaced, rather than prompting "want me to remember this?". Closes the
  session-memory fallback that bypassed the existing testing/living-docs/issue-first
  routing.
- **Changed:** the scaffold `.claude/settings.json` now pre-authorizes the
  **read-only inspection** commands the skills run on every step — `git
  status/diff/log/show/branch/remote`, `gh pr view/checks/list/diff`, `gh run
  view/list/watch`, `gh repo view`, `gh label list`, `mise tasks`, and the named
  verify tasks `mise run check`/`mise run ci` — under `permissions.allow`.
  Previously only the write-side issue/commit verbs were allowlisted, so the
  read-heavy navigators (`/steer:next`, `/steer:audit`, `/steer:issues`,
  `/steer:sync`, `/steer:work`, `/steer:setup`) prompted on nearly every
  inspection step even though nothing risky was happening — the main source of the
  "asks for approval constantly" friction. The human-gated delivery surface is
  untouched: `git push`/`gh pr create`/`merge` stay under `ask`, force-push/
  `--no-verify`/`.env` adds stay under `deny`, and `mise run:*`/`gh api`/`gh:*`
  remain prompted by omission (an explicit `mise run:*` would have green-lit `mise
  run deploy`). `check_standards.py` now asserts the read-only set stays under
  `allow` and that `mise run:*`/`mise:*` never appear there, so the invariant can't
  silently regress. Existing repos pick the entries up additively on the next
  `/steer:sync` (the reconcile unions permission lists, never overwrites).
- **Changed:** the read-heavy navigator skills (`/steer:next`, `/steer:audit`,
  `/steer:issues`, `/steer:setup`, `/steer:sync`, `/steer:doctor`) now carry their
  own read-only `allowed-tools` grants, mirroring the model `/steer:work` already
  used — so inspection runs silently even in a repo that predates the scaffold
  allowlist above or was never bootstrapped. Side-effecting verbs stay prompted.
- **Added:** an `AUTHORING.md` note that permission rules match a *single* command
  string — chaining inspection with `&&`/pipes (`git status && git diff`) defeats
  every `allowed-tools` and scaffold-`allow` entry and still prompts. Skills must
  run inspection commands as separate invocations; this is the most common reason a
  repo that looks allowlisted still asks for approval.

### 3.6.0

- **Fixed:** `/steer:tracker-sync`'s native-issue-field recipes described a stale
  GraphQL shape that no longer matches GitHub's now-public-preview issue fields, so
  an agent following them verbatim built an invalid request and Priority/Effort/date
  values silently failed to write. `field-set` documented `setIssueFieldValue` as
  flat `issueId` + `fieldId` + value; the live mutation nests them in an
  `issueFields: [IssueFieldCreateOrUpdateInput!]!` list (`{ fieldId,
  singleSelectOptionId | dateValue | numberValue | textValue | multiSelectOptionIds
  | delete }`), with the single-select value passed as an option **id**. `field-get`
  now names the correct read connection **`issueFieldValues`** (the previously-vague
  "field-values connection" invited the non-existent `fieldValues` on `Issue`), its
  typed value variants, the `IssueFields` definition union, and `viewerCanSetFields`
  as the capability probe. The REST fallback path is corrected to
  `/repos/{owner}/{repo}/issues/{n}/issue-field-values` (was the legacy
  `/repositories/{repo_id}/…`, dropping the repo-id lookup) and now warns that the
  single-field write must use **POST**, never `PUT` (which replaces *all* of an
  issue's field values).

- **Fixed:** `template-reconcile.sh` (consumed by `/steer:adopt`, `/steer:build`,
  `/steer:spec-scaffold`) no longer reports the `### Q-001 — [...]` open-question
  seed as a "missing" anchor when a completed intent has filled it in or deleted
  it. Lines carrying the `steer:placeholder` marker are now stripped from both
  files before the structural diff, so finished `intent.md` / vision specs stop
  re-firing a false-positive reconciliation notice (issue #231).
- **Added:** `license` field (`Apache-2.0`) to the steer plugin manifest, matching
  the repository `LICENSE` now that the marketplace is published publicly.
- **Changed:** the marketplace repo `element22llc/e22-plugins` is now **public**,
  so the shipped `claude.yml` no longer needs a credential to clone it. Removed
  the GitHub App token-minting steps (`actions/create-github-app-token` +
  the `insteadOf` clone-auth rewrite) from `templates/github/workflows/claude.yml`;
  the `plugin_marketplaces` fetch now clones anonymously and `ANTHROPIC_API_KEY`
  is the workflow's only required secret. Updated the scaffold `README.md`,
  `MANIFEST.md`, `CAPABILITIES.md`, the `sync` skill's capability model
  (`in-ci-plugin-loading` no longer reports `wired-pending-secret` for a missing
  marketplace App), the docs `github-integration.md` and `launch-checklist.md` to
  match. Existing product repos keep working unchanged (the marketplace path is
  identical; their App credential, if set, still clones a now-public repo); the
  org `STEER_APP_ID` / `STEER_APP_PRIVATE_KEY` variable+secret and the shared
  GitHub App can be retired at the org's convenience.
- **Fixed:** bootstrapping an `app`-profile repo with a Python `apps/api` backend
  produced a circular, duplicated task graph — the root `package.json` carried a
  `dev:api` that shelled out to `uv run uvicorn`, the same `dev`/`dev:api`/`build`/
  `test` tasks were defined again in `mise.toml`, and `mise run dev` → `pnpm dev`
  → `pnpm dev:api` → `uv run` looped between the two entrypoints (#222). The
  task-running convention is now explicit that delegation is **one-way** (a mise
  task may wrap a `package.json` script, never the reverse), that a `package.json`
  script never shells out to `uv`/Python, and that no task is defined in both
  files. A polyglot app's Python backend is a mise/`uv run` task, composed with a
  `[tasks.dev]` `depends = ["dev:*"]` fan-out — mise is the single, polyglot entry
  point. Tightened `rules/10-stack` (and the regenerated
  `copilot-instructions.md`), documented the pattern with a worked example in
  `CONVENTIONS.md`, extended `/steer:init` step 6, and shipped a commented
  `[tasks.dev]` orchestration block in the scaffold `mise.toml` so the bootstrap
  copies the correct shape instead of inventing a root-`package.json`
  `concurrently` script.

### 3.5.0

- **Fixed:** `/steer:build` (the non-technical PO flow) silently defaulted a solo
  PO with no developer into `pr-flow` on a `feat/*` branch, never offering
  `solo trunk (pre-MVP)` — the exact case the standards reserve solo-trunk for
  (#220). The PO flow had baked in the assumption that a separate developer would
  review the v0 PR; when the PO *is* the sole contributor that reviewer never
  exists and the v0 PR sits unmergeable. Step 1 now **asks the delivery mode**
  instead of assuming one: if the PO is the sole contributor with no MVP or
  deploy yet, it offers and recommends solo trunk (commit straight to `main`, set
  the `<!-- steer:delivery-mode=solo-trunk -->` marker, graduate via
  `/steer:protect`), mirroring the offer `/steer:init` Path B already makes. The
  choice now threads through the rest of the flow: prototype-mode builds commit
  to `main` with no `feat/*` branch in solo trunk (step 6), the step-10 handoff
  has no v0 PR (graduation is the gate), and the next-actions table recommends
  graduating rather than opening a PR. The standards floor (tests, contracts,
  Definition of Done) is unchanged in both modes.
- **Fixed:** SessionStart hooks and other surfaces told users to "Run
  `/steer:questions`" (and `/steer:roadmap`, `/steer:init`, …) even though those
  skills were `user-invocable: false` — typing them was rejected by the harness
  (#219). The eight skills a user legitimately starts directly — `init`, `adopt`,
  `sync`, `questions`, `roadmap`, `doctor`, `tidy`, `reference` — are now
  **user-invocable** (a front door still auto-routes to them, so the slash menu
  stays intent-led). Only the two true internal gateways a parent always drives
  with context the user can't supply — `tracker-sync` and `spec-scaffold` — stay
  `user-invocable: false`; their stray user-facing mentions now route to a callable
  front door (`/steer:spec`). A new `check_standards.py` gate fails CI if any
  `user-invocable: false` skill is presented to a human as a bare imperative in a
  user-facing surface (hook notices, installed scaffold/spec docs). Copilot prompt
  files are generated for the eight newly-invocable skills; router/AUTHORING/README
  docs updated to match.
- **Fixed:** `/steer:build` no longer leaves the root living docs as template
  stubs after building a v0 (#221). Step 5 (scaffold the real app) now fills
  `ARCHITECTURE.md` (stack table + apps/packages map) and retires the
  `apps/README.md` "starts empty" line in the same change that establishes the
  stack; step 6 seeds and grows `DESIGN.md` from the implemented visual identity;
  and the step-10 handoff adds a doc-reconciliation backstop that confirms
  `ARCHITECTURE.md` / `DESIGN.md` / `apps/README.md` carry no leftover
  placeholders before the PR reaches the dev reviewer. The `Living docs` rule
  gains `DESIGN.md` as a tracked artifact and an explicit "retire now-false
  scaffold placeholder prose" clause, so the same upkeep holds across
  `/steer:init` and `/steer:work` too.

- **Changed:** Windows support is now **surface-aware** — native Windows + Git for
  Windows is a first-class path, **no WSL2 required**. `/steer:doctor` no longer
  treats `os = windows` as an unsupported host: when Git Bash is live it confirms
  the setup (the **Claude Desktop Code tab** runs steer's `sh`-invoked hooks and
  builds locally there — add Docker Desktop for services), and when no POSIX shell
  is found it points to **Git for Windows** for the Desktop path or **WSL2** for
  CLI/IDE development. The `Stack` rule's blanket "Windows → develop in WSL2" is
  reworded to that split. New `docs/getting-started/windows-setup.md` (in nav),
  cross-linked from `installation.md` and `team-onboarding.md`.

- **Added:** AI-slop guardrails, split prevention/detection. **Prevention:** a new
  baseline pattern in `rules/85-practices.md` — *every import resolves to a declared
  dependency* (a plausible package name that isn't in the manifest is a hallucinated
  import, not a working one); the comment-slop side (decorative banners, restating
  comments) was already covered by `rules/87-output-discipline.md`. **Detection:** an
  **advisory** `ai-slop` job added to the scaffold CI (`templates/github/workflows/ci.yml`)
  that runs [`aislop`](https://github.com/scanaislop/aislop) (pinned `0.12.1`) and
  publishes findings to the Security tab as SARIF — `continue-on-error`, PR-only, never
  a required check. New scaffold config `aislop/config.yml` → `.aislop/config.yml`
  (+ MANIFEST row) keeps the differentiated `ai-slop/*` rules on and turns down the
  security/complexity rules that duplicate the `ci` job's ruff/bandit/Biome/audit gates.
  Promote to a blocking gate (swap `scan` for `aislop ci`, set `ci.failBelow`) only once
  the tool earns trust / hits 1.0.

- **Scaffold fix:** the bundled `pnpm-workspace.yaml` now sets
  `confirmModulesPurge: false`. `mise deps` runs `pnpm install` non-interactively
  (no TTY), so whenever pnpm needed to rebuild `node_modules` from scratch — e.g.
  it was first created by a stray global pnpm of a different major than the
  mise-pinned one, or the store version changed — it aborted with
  `ERR_PNPM_ABORTED_REMOVE_MODULES_DIR_NO_TTY` instead of prompting, breaking
  `mise deps` on a fresh checkout. Auto-confirming lets the deps provider
  self-heal and converge `node_modules` onto the mise-pinned pnpm. The same file
  also gained a comment explaining pnpm 11's `minimumReleaseAge` supply-chain
  default (`ERR_PNPM_MINIMUM_RELEASE_AGE_VIOLATION`) and how to regenerate a
  lockfile pinned under an older pnpm — both surface through `mise deps` because
  it auto-runs `pnpm install` before every task.
- **Guardrail:** stop a global version manager (nvm/asdf/volta/fnm) from silently
  shadowing mise's pinned runtimes — the root cause of the wrong-pnpm
  `node_modules` above. `/steer:doctor` (`scan-prereqs.sh`) now reports a
  `shadowed` status when `node`/`pnpm`/`uv` resolves to a non-mise path while mise
  is present, naming the conflicting manager and the fix. The always-on command
  rules and the scaffold README/quickstart no longer teach a bare `pnpm install`
  (which resolves to whatever is first on `PATH`): they route a manual install
  through `mise exec -- pnpm install`, lean on `[deps]` auto-install, and require
  `mise activate` to be sourced **after** any other version manager so mise wins
  `PATH`. `/steer:init` and the Copilot instructions were updated to match.
- **Docs:** named the **Claude Cowork no-install sandbox** limitation. Cowork runs
  in an Anthropic-managed Linux VM that can't install docker/mise/`gh` and doesn't
  read the plugin `.mcp.json`, so the shipped `${GITHUB_PAT}` `github` and
  local-process `markitdown` MCP servers don't work there — the "GitHub connector
  isn't working" symptom. `/steer:tracker-sync` now documents that on Cowork its
  MCP path only succeeds through the surface's **built-in GitHub connector**
  (Customize → Connectors, repo-scoped: triage/label/comment/state work, org-level
  Issue Types and Priority/Effort fields degrade), with no `gh` fallback. New
  `docs/reference/known-limitations.md` → "Claude Cowork's sandbox" section,
  cross-linked from `mcp-servers.md`; `CROSS-SURFACE.md` matrix/recommendations
  corrected (§4a) and its MCP verification item resolved.

- **Changed:** the scaffold `.claude/settings.json` now pre-authorizes the **full
  autonomous issue path**, not just the `gh` write verbs. `tracker-sync` is
  MCP-first, so the *preferred* create/manage path is the `mcp__github__*` issue
  tools — previously unlisted, so every autonomous create/update/comment prompted
  even though the `gh` equivalents were allowed (issue #180). The `allow` list gains
  the MCP issue tools (`create_issue` / `update_issue` / `add_issue_comment` /
  `get_issue` / `list_issues` / `search_issues` / `add_sub_issue`) plus the `gh`
  dedup/capability **reads** that run before every find-or-create
  (`gh issue list` / `gh issue view` / `gh search issues` / `gh auth status`). Net
  effect: an explicit "create an issue for…" / "add to the backlog" no longer
  prompts on each call, on whichever path the host takes. Delivery stays human-gated
  — `git push`, `gh pr create`/`merge` remain under `ask`, and `gh api`/`gh api
  graphql` (the mutation vector for fields/milestones/relationships, repo-delete, PR
  merge, branch protection) stays **prompted by omission**; `check_standards.py` now
  enforces both halves of this contract (the autonomous metadata surface present in
  `allow`, `gh api`/`gh:*` absent from it). Existing repos pick the new entries up
  additively via `/steer:adopt` reconcile (`scaffold_reconcile.py` unions permission
  lists).
- **Fixed:** `/steer:tracker-sync` `field-get` no longer claims native issue fields
  have "no REST path" — a stale absolute that contradicted the REST write recipe the
  sibling `field-set` op now documents. `field-get` keeps `gh api graphql` as its
  read path and points to `field-set` for the REST write.
- **Fixed:** the native-issue-field vs Projects-board-column trap is now named, and
  PO-directed field seeding has a documented route. When a Project v2 board surfaces
  Priority/Effort/dates, they appear as single-select **columns that look like
  editable Project custom fields but are API-locked** — `updateProjectV2Field` /
  `gh project item-edit` fail with `Only custom fields can be updated …` and expose no
  option ids. `ISSUE-SCHEMA.md` (Projects-v2 boundary) and `/steer:tracker-sync
  field-set` now call this out explicitly and point all Priority/Effort writes at the
  **native issue field**, never the Projects API (the reverse — a genuine `Size`/
  `Iteration` custom field — stays on `gh project item-edit`). `field-set` gains a
  copy-paste **write recipe**: read options from `gh api /orgs/{org}/issue-fields`,
  then write via GraphQL `setIssueFieldValue` **or** the REST equivalent
  (`POST /repositories/{repo_id}/issues/{n}/issue-field-values`, value = option name,
  `X-GitHub-Api-Version: 2026-03-10`). `/steer:issues` triage and board now route an
  explicit PO "set/seed Priority/Effort" request straight to `field-set` (a human
  value, no floor ledger line, no escalate-only guard) — separate from the mechanical
  escalate-only floor. Closes a discoverability gap in PR #186, not a missing
  capability.

### 3.4.0

- **Added:** an Epic tier above features. A new `steer:kind=epic` parent tracking
  issue groups child features (and, transitively, their tasks/bugs) via native
  sub-issue links, so a goal spanning several features is one visible
  `Epic → Feature → Task` hierarchy in a Projects v2 view. `Type=Epic` is set only
  when the org enables that issue type; otherwise the epic stays a normal issue with
  the `steer:kind=epic` marker and its Type left unset (capability degradation,
  reusing the existing `set-type` pattern). Milestones remain release grouping — an
  orthogonal axis, not the epic aggregator. Adds the `epic` value to the
  `issue_kind` enum, a new `/steer:issues epic` mode (`--new` / `#E --add`),
  epic-aware `status`/`board`/`reconcile`, an `epic.md` issue-body template, and the
  epic lifecycle (`inbox → exploring → in-progress → validate → done`, completion
  derived from child rollup under PO confirmation). Epics are excluded from
  `/steer:next` arbitration (you act on their child features). `/steer:roadmap`
  notes epics are orthogonal to release milestones; `set-type` accepts `Epic` with
  per-Type-name detection.
- **Added:** issue-creation contract guard — a new `check-issue-create-contract.sh`
  PreToolUse hook that, in a `system: github` repo, nudges when an agent opens an
  issue with a raw create (`gh issue create`, `gh api … POST …/issues`, a
  `gh api graphql` `createIssue` mutation, or an MCP create-issue tool) instead of
  routing through `/steer:tracker-sync create`. Non-blocking, fires once per
  session+repo, and stays silent when the payload already carries `steer:` markers
  (the contract-render path) or in the plugin's own source repo. Closes the gap
  where the issue-first nudge was blind to Bash and to issue creation.
- **Added:** `/steer:issues reconcile --all` now detects **contract-less issues** —
  open issues missing the machine-readable contract (no `steer:` markers and no
  `steer:managed` block, hence no `source:*` label and the default Type) — and
  reports them with a retrofit action, so a raw create that bypassed the
  point-of-action guard is still recoverable after the fact.

### 3.3.0

- **Changed:** the bundled scaffold `mise.toml` now declares task ordering with
  `depends` instead of a `run = ["mise run …"]` chain — `dev:setup` → `db:seed`
  → `db:migrate` → `docker:up`, so the chain runs in order and fails fast. The
  `15-commands` and `10-stack` rules gained a lean "mise is the single task entry
  point; declare ordering with `depends`/`depends_post`, never `mise run` chains"
  bullet, and the infra-profile `mise.toml` replaces its placeholder `echo`
  `dev:setup` with a real `terragrunt run-all init` plus a commented
  `[deps.ansible-galaxy]` provider example.
- **Added:** lockfile-aware auto-install of workspace dependencies in the
  scaffold — `[settings] experimental = true` plus `[deps.pnpm]`/`[deps.uv]`
  (`auto = true`), which run `pnpm install` / `uv sync` before any `mise run` /
  `mise x` but only when the lockfile changed, and only when the lockfile exists
  (so a single-language repo's other provider no-ops). Replaces hand-rolled
  install tasks. `CONVENTIONS.md` → "Standard mise tasks" gains sections on
  declaring task ordering (`depends`/`depends_post`/`wait_for`), `[deps.*]`
  auto-install (incl. the `experimental` trade-off and `--no-deps` escape hatch),
  `sources`/`outputs` for file-producing tasks, and file tasks vs `scripts/`;
  the "why mise not package.json" prose is reframed as mise being the single
  entry *surface* (app scripts stay in `package.json`; mise tasks delegate).
- **Added:** knowledge-work mode for the always-on ruleset, hardening steer for
  Claude Cowork product-owner use. A new `steer_work_mode` classifier (in
  `hooks/lib/scope.sh`) detects a confidently non-code folder — no git work tree
  and no code/config markers within `maxdepth 2` (the typical Cowork case: a
  connected folder of specs/docs) — and classifies it `knowledge`; anything else,
  or any doubt, stays `code` (fail-safe — never silently drops a rule). In
  `knowledge` mode `inject-standards.sh` injects only the lean, always-on
  PO-relevant core and **skips every `inject-when`-marked rule** (none of the
  code/infra/tracker-scoped rules apply there), reclaiming context budget and
  cutting noise. The code-only rules `10-stack`, `15-commands`, `20-layout`,
  `22-housekeeping`, `24-worktrees`, `40-testing`, `41-coverage`,
  `45-commit-autonomy`, `50-definition-of-done`, `55-drift-gates`,
  `80-change-size`, `85-practices`, `99-end-of-session` gained an
  `inject-when=code-project` marker; the spec-workflow, decision-capture,
  living-docs, roles, issue-tracker, secrets, compliance and output rules stay
  always-on. Classification keys on a git work tree or any code/config/source
  marker within `maxdepth 2`, so `code`-mode behavior in a git repo is unchanged.
- **Added:** plain-language "standards are active" confirmation for non-technical
  Cowork users. In `knowledge` mode `orient-session.sh` (which fires on `startup`
  only, so it never re-fires on resume/clear/compact) tells the model to confirm,
  in one or two jargon-free sentences, that the org standards are loaded and that
  the user can just describe a goal rather than memorize `/steer:*` commands —
  closing the silent-injection trust gap where the rules load but a PO has no
  signal anything happened.
- **Changed:** make the guided PO build flow the reliable default for a
  non-technical owner who never types a skill name. `orient-session.sh` now
  steers deterministically back into `/steer:build` when an in-progress build is
  detected (a `spec/BUILD-STATUS.md` with an open handoff gate), so a returning PO
  resumes the flow instead of getting a blank "what do you want to do?"; it falls
  silent once the build is handed off (every gate box checked). `05-roles.md` now
  treats build as the PO **default posture** (not an opt-in) and names
  `/steer:spec` as the plain-language "work on the spec before building" step;
  `00-router.md` routes a non-technical owner's idea straight to `/steer:build`
  (bootstrap-inclusive) rather than raw `/steer:setup`.
- **Added:** the `/steer:build` flow gained an in-flow spec-iteration step — when
  the PO wants to sharpen a feature's spec before building it (explore edge cases,
  drive open questions down), the build skill runs `/steer:spec <id>` to iterate
  `intent.md`/`contract.md` in the same spec-only loop (no code written) and tells
  the PO plainly they can just say "let's work this out more first" without typing
  the command (`skills/build/SKILL.md`).
- **Fixed:** `check-unmanaged-repo.sh`'s greenfield nudge led a non-technical
  owner to raw `/steer:init`; it now leads with `/steer:build` (which runs `init`
  itself) and reframes `init`/`adopt` as the developer/existing-code paths. Added
  hook-test coverage for both hooks (the suite previously never exercised
  `check-unmanaged-repo.sh`).

### 3.2.0

- **Fixed:** rule `52-deployment.md` was gated `inject-when=has-iac`, so an
  app/service repo that deploys via GitHub Actions but has no `/infra` dir never
  received it — a dangling cross-reference from always-on `10-stack.md`, which
  tells the agent the promotion / prod-branch-gate rules "live there." The gate
  is now `has-iac|has-apps`: `inject-when` markers gained `|`-separated **OR**
  semantics (a rule injects when **any** listed predicate holds), so deployment
  rules now reach infra **and** app/service repos.
- **Fixed:** the `tracker-sync` skill `description` advertised a bare `link`
  operation its body never defines; replaced with the real ops it does
  (`link-parent`, `link-pr`, `link-related`, `link-blocked-by`).
- **Fixed:** scaffold `MANIFEST.md` pointed at nonexistent README "migration
  notes"; dropped the dangling phrase.
- **Fixed:** scaffold `CLAUDE.md` "New repo?" block omitted `context-hygiene`
  from the `/steer:reference` topic list — the fifth hand-maintained surface
  missed by the 3.1.0 menu sweep; now lists all four topics.
- **Fixed:** always-on `00-router.md` said `/steer:setup` hands off to
  `/steer:doctor` directly; `setup` actually reaches doctor via `init`/`build`
  when prerequisites are missing. Reworded the router line to match.
- **Added:** `check_standards.py` now walks `scaffold/` in reverse — every
  bundled file must appear in `MANIFEST.md`'s install-map, so a new scaffold file
  omitted from the map fails CI instead of silently never being installed.
- **Fixed:** the core bundled scaffold `mise.toml` carried a stale comment block
  instructing consumers to commit a placeholder `mise.lock` and "never delete
  it" — left over from before the placeholder lock was dropped, and a direct path
  into the mise-action@v4 placeholder-lock trap that breaks `mise install
  --locked` in a consumer's CI. The version-strategy comment now mirrors
  `profiles/infra/mise.toml` and `MANIFEST.md`: the scaffold ships **no**
  `mise.lock`, and `/steer:init` / `/steer:adopt` create and commit it on first
  run (`touch mise.lock && mise install && mise lock --platform …`) — never an
  empty placeholder.
- **Changed:** single-sourced two cross-cutting rule concepts to cut the
  always-on token and per-change maintenance tax (#164). **solo-trunk** mechanics
  stay canonical in `45-commit-autonomy`; the full re-explanations in
  `30-spec-workflow` and `36-issue-first` collapse to a one-line pointer plus the
  single fact each adds, and `50-definition-of-done` trims its PR-gate exception to
  a pointer. **prototype-never-waives-scaffold/spine** stays canonical in
  `30-spec-workflow`; `00-router` keeps the routing imperative but drops the
  scaffold enumeration and hand-writing argument, pointing to Spec workflow. The
  `99-end-of-session` checklist cue and `36`'s prototype sentence are kept
  self-contained by design (acted on in isolation). No behavior change.

### 3.1.0

- **Fixed:** the `/steer:reference` topic menu omitted `context-hygiene` (the
  topic added this release) from four hand-maintained surfaces — the always-on
  `00-router.md` pointer, the `standards` skill's manual-load fallback,
  `README.md`, and `docs/reference/skills.md`. All four now advertise the full
  `conventions | traceability | design-sources | context-hygiene` set.
- **Changed:** **Lean two-layer scaffold (Core + Profile overlay).** The bundled
  scaffold is now organized **additively** instead of "install the flat app
  monorepo, then omit app-only files." `templates/scaffold/` root holds only the
  profile-agnostic **Core** (docs, dotfiles, `.claude`/`.vscode`, `policy/`, the
  version-pin scripts, the `/spec` spine, `mise.toml`, and — deliberately for
  every profile — `compose.yaml` + `scripts/worktree-env.sh`, the
  containerize-by-default surface). The Node project files (`package.json`,
  `pnpm-workspace.yaml`, `biome.json`, `configs/`, `packages/`) move to a shared
  **Layer 1** `profiles/_node/` baseline; per-type structure (`apps/`, `DESIGN.md`)
  moves to **Layer 2** `profiles/<type>/`. `node`/`python`/`uv` are now mandatory
  in the core `mise.toml` for **every** profile (the `infra` mise pins `node` too
  and sources `worktree-env.sh` — agent tooling needs the runtimes). Every Node
  profile is a pnpm workspace (monorepo-by-default), so `library`/`cli` get the
  workspace too. `/steer:init` and `/steer:adopt` now compose Core → `_node`
  (Node stacks) → profile overlay. The **installed** repo layout is unchanged, so
  no migration is required.
- **Added:** **Typed-by-default** is now a first-class always-on practice
  (`rules/85-practices.md`): static typing wherever the language supports it
  (`TS strict` / Python type hints + a checker), not just a default-stack detail
  buried in the conventions reference.
- **Changed:** The boundary-validation practice is now stated **language-
  agnostically** and the JS-only `Zod` name is removed from all rules and
  templates — validation is "every external input through a **defined schema**,"
  explicitly covering **config and data files (JSON/YAML)** alongside requests,
  API responses, and env vars. Default-stack tools (Drizzle, Next.js, Pydantic
  for the Python path) are still named where they belong; only the implication
  that Zod is the universal answer is gone. Touches `85-practices.md`,
  `templates/github/copilot-instructions.md`, `templates/reference/CONVENTIONS.md`,
  `templates/scaffold/CLAUDE.md`, `templates/spec/productionization.md`,
  `skills/adopt/PROCEDURE.md`, and `skills/reference/SKILL.md`.
- **Added:** **Repo profiles** — steer no longer assumes every managed repo is a
  Node/TS app monorepo. A repo now carries a `<!-- steer:profile=app -->` marker
  (or `infra`/`service`/`library`/`cli`) on the `CLAUDE.md` `## Profile` section,
  sibling of the delivery-mode marker; absent ⇒ `app` (back-compat). The
  **universal core** — mise toolchain pinning, the `/spec` spine, and
  stack-agnostic CI hygiene — is now installed for **every** profile, so a non-app
  repo (e.g. an Ansible/Terraform repo) is never skipped at bootstrap; only the
  stack-specific extras vary. `/steer:init` and `/steer:adopt` detect, confirm,
  and stamp the profile; `/steer:sync` back-fills `=app` when missing (idempotent
  ledger entry).
- **Added:** **`infra` profile** — Terraform/OpenTofu/Ansible/Pulumi repos get a
  tofu/terragrunt/ansible-flavored **root** `mise.toml`
  (`templates/scaffold/profiles/infra/mise.toml`) instead of
  `package.json`/`compose.yaml`, plus CI that auto-detects `*.tf`/`*.hcl` and
  Ansible layouts and runs `tofu fmt`/`ansible-lint` (no cloud credentials
  needed). New always-on rule fragment `rules/12-stack-infra.md` (injected when
  the repo does IaC). Dependabot gains a commented `terraform` ecosystem block.
- **Added:** rule-injection trait predicates `has-apps`, `has-compose`, and
  `has-iac` in `hooks/lib/scope.sh` (joining `has-infra`/`tracker-github`), and a
  `steer_repo_profile` reader in `hooks/lib/repo-root.sh`. Always-on rules gate on
  filesystem **traits**, never on the profile marker, so a repo's rule context
  always matches what is on disk (a monorepo with a nested `/infra` gets the infra
  fragment automatically).
- **Changed:** the bootstrap nudges (`check-unmanaged-repo.sh`,
  `check-code-before-spec.sh`) no longer frame the scaffold as `package.json` /
  build config — they state the universal core applies to every profile including
  infra/IaC, libraries, and CLIs, and that `/steer:init` picks the matching
  profile. Stack/layout/commands rules (`10`/`15`/`20`/`24`) note their defaults
  are the app/service profile's biases.
- **Added:** `/steer:sync` now detects an **undeclared delivery mode** via a new
  `delivery-mode-declared` capability in the capability map
  (`scan-capabilities.sh` + `CAPABILITIES.md`). A repo bootstrapped before
  solo-trunk existed (≤ 2.11.0) carries no `steer:delivery-mode=` marker on its
  `CLAUDE.md`, so the commit-autonomy and issue-first hooks silently fail open to
  `pr-flow` and a solo, pre-MVP dev never discovers solo-trunk — the solo-trunk
  offer lived only in `init`'s run-once interview, and `sync` carried the spine
  forward without re-asking. The scan reports `present-wired` when the marker is
  explicit, `mis-wired` when `CLAUDE.md` exists without it, `absent` when there is
  no `CLAUDE.md`. Repair is a **human decision** (like `backing-services-compose`):
  `sync` proposes splicing the scaffold's `## Delivery mode` section defaulting to
  `pr-flow` (matching the hooks' fail-open, so behaviour is unchanged) and
  surfaces the solo-trunk option, recommending it for a solo PO+dev with no
  MVP/deploy yet — it never picks the mode itself, and never edits an existing
  `## Delivery mode` section. Closes #193.
- **Added:** New always-on rule `26-context-hygiene` and a matching
  `/steer:reference context-hygiene` topic — guidance to delegate heavy, multi-phase,
  or search-heavy runs to subagents (a fresh context window by construction) and to
  persist durable run-state and task constraints in `/spec/**` files so they survive
  compaction, with a fallback recommendation to `/compact` or start a fresh session
  (with a pre-composed hand-off) only when the thread is genuinely overloaded. Honest
  about the boundary: a plugin/model cannot see context usage, trigger `/compact`, or
  start a session — only the user can. AUTHORING gains a matching skill-authoring note.

### 3.0.1

- **Fixed:** `hooks/lib/spine.sh` `steer_spine_state` misclassified a fully
  managed repo as `damaged` under zsh. The required-files loop relied on
  word-splitting an unquoted `${STEER_SPINE_REQUIRED}`, which POSIX sh does but
  zsh does not — so under macOS's default zsh the loop ran once over the whole
  string and the `[ -f ]` test failed. The `/steer:setup` skill sources this
  helper and runs it in the host shell, so the misfire routed healthy repos to
  the repair/sync path. Replaced the loop with shell-agnostic parameter
  expansion that behaves identically in sh, bash, and zsh.

### 3.0.0

- **Changed (breaking):** Merged the three reference-prose loader skills
  (`conventions`, `traceability`, `design-sources`) into one topic-driven
  `/steer:reference [conventions | traceability | design-sources]` skill (hidden,
  reached via `/steer:standards` or the model, as the originals were). Each topic
  loads the same bundled `templates/reference/*.md` as before. The three
  standalone skills are **removed**; use `/steer:reference <topic>`.
- **Changed (breaking):** Merged the `drift` skill into `/steer:audit` as a
  `spec` mode. `/steer:audit` now takes `[code | spec | all]`: `code` (default) is
  the existing whole-repo code-vs-standards health sweep, `spec` is the as-built
  `/spec`-vs-tracker-intent conformance audit (the former `drift`), and `all` runs
  both. The standalone `/steer:drift` is **removed**; use `/steer:audit spec`. All
  cross-references and the publish-drift handoff are rewired accordingly.
- **Changed (breaking):** Merged the `deliver` skill into `/steer:work` as a
  `--reviewed` flag. The standalone `/steer:deliver` is **removed**; run
  `/steer:work --reviewed` to wrap issue execution in the same review-gated loop
  (independent plan-gate review → implement → `/code-review` gate → bounded fix).
  `deliver` already delegated governed implementation to `work`, so this drops the
  duplicate entry point; the shared protocol still lives in
  `templates/reference/REVIEW-LOOP.md`.
- **Added (ranking + roadmap dates):** `/steer:next` now reads each candidate's
  native **Priority** field and blocked-by edges during state reconstruction and
  orders within a safety level by the composite sort key (Priority first), saying so
  when issue fields are unavailable. `/steer:roadmap` now writes the human-confirmed
  **Start/Target date** native issue fields (via `field-set`) so a Projects v2
  roadmap lays out per-issue Gantt bars without Project-item mirroring — still never
  fabricating a date, capability-degrading to Milestone grouping alone when fields
  are unavailable.
- **Added (auto-set):** `/steer:issues triage` now **escalate-only auto-sets** the
  native Priority field from a closed, mechanical floor table (`risk:security` →
  `Urgent`; an open blocking question gating the issue → `High`; live-feature
  `spec-drift` → `High`; blocks a `ready-for-dev` issue → `Medium`). It sets
  `max(current, floor)` — never downgrades a human value, idempotent, and suppressed
  when the value differs from the agent's own `steer:priority-floor` **ledger** line
  (a human touched it) — a guard computable from the ledger + `field-get`, needing
  no field-change-actor read (the gateway exposes none). Effort/dates stay human-set
  (surfaced as
  field gaps, never auto-filled). `publish-audit`/`-drift`/`-findings` set the same
  floor on creation.
- **Added (board view):** `/steer:issues board` — a read-only backlog overview that
  shows the open issue set as one ranked (composite sort key from `NEXT-ACTIONS.md`),
  relationship-clustered, dedup-flagged, hygiene-flagged view. It ranks *issues* and
  defers the cross-workflow "single most critical thing" to `/steer:next`; it never
  writes (every fix routes to `triage`/the owning skill).
- **Added (gateway):** `/steer:tracker-sync` gains native issue-field + relationship
  ops — `field-get` / `field-set` (Priority/Effort/Start/Target date via the
  `setIssueFieldValue` GraphQL mutation; GraphQL-only, no `gh` REST path),
  `bootstrap-fields` (detect-and-report the org-level field definitions, never
  fabricate options — reports a `P0/P1`-style option mismatch and stops), and
  `link-blocked-by` (native issue dependency; degrades to a `depends-on` managed-block
  line, writing **one** representation so ranking never double-counts; informs but
  never sets `steer:state=blocked`). `link-related` now prefers the native edge for
  `depends-on`/`blocks`. `/steer:init` runs `bootstrap-fields` alongside
  `bootstrap-labels`. Field writes are GraphQL and remain host-gated (not added to
  the scaffold allow-list).
- **Added (foundation):** GitHub **native issue fields** are now first-class in the
  issue model. `issue_priority=Urgent|High|Medium|Low` joins the enum registry
  (`enums.registry` + `ENUMS.md`); `ISSUE-SCHEMA.md` reframes the Projects-v2
  boundary so Priority/Effort/Start/Target date are **writable issue attributes**
  (distinct from Project-*item* fields), documents the field-value-vs-managed-block
  **ledger** provenance and the no-managed-block-guard concurrency note, and
  `ISSUE-WORKFLOW.md` adds *issue fields* as a third capability-degrading axis
  (alongside Issue Types and native sub-issues). `LABELS.md` reverses the former
  "priority and effort are not tracked" stance — they are native fields, **never**
  `priority:*` labels. `NEXT-ACTIONS.md` defines the **composite sort key** (safety
  level first, then the Priority field as a *within-level* tie-break, then derived
  signals), and `/steer:next` golden fixtures pin that Priority never crosses the
  safety precedence. (Gateway ops, auto-set, board view, ranking, and roadmap dates
  land in follow-up changes.)
- **Added:** `/steer:setup` — one front door for getting a repo onto the
  standards. It detects the `/spec` spine state (via `hooks/lib/spine.sh`) and
  routes to the right path instead of making the user choose: greenfield
  `/steer:init`, existing-code `/steer:adopt`, or steady-state `/steer:sync`
  (running `/steer:doctor` first if the toolchain is missing).
- **Changed:** Decluttered the slash menu so the front doors are obvious. Eight
  skills are now `user-invocable: false` (hidden from the menu, still
  model-callable, reached through a front door): `init`/`adopt`/`sync`/`doctor`
  via `/steer:setup`; `tidy` via `/steer:audit`; `roadmap` via
  `/steer:issues`; `questions` via `/steer:spec`/`/steer:issues`; and the merged
  `/steer:reference` loader. The declutter itself removed no skills and broke no
  `/steer:<name>` reference — it is reversible.
- **Changed:** `rules/00-router.md` reorganized around the ~11 front doors with a
  compact "reached through a front door" note, and bootstrap precedence now routes
  through `/steer:setup`. `/steer:audit` now hands off to `/steer:tidy`, and
  `/steer:issues` surfaces `/steer:roadmap` for release sequencing.
- **Docs:** `AUTHORING.md` gains a "Skill vs. mode — hold the line on surface area"
  principle and the `/new-skill` helper gates new skills on it; `docs/` reference
  and getting-started pages lead with `/steer:setup`.
- **Changed:** Root housekeeping now **moves** a confidently-classified stray to
  its `/spec` home immediately, instead of waiting for a yes. Rule 22, the
  `/steer:tidy` skill, and `HOUSEKEEPING.md` reframe the policy: confident
  classification is the gate on the automatic move (`git mv`, filename
  preserved); **renames, deletes, and anything ambiguous stay gated** behind a
  confirmation. This removes the friction of being asked to approve obvious moves
  (the case that prompted it) while keeping the human boundary exactly where loss
  or judgment is at stake.
- **Added:** Specification / requirements documents (`.pdf`, `.docx`, decks —
  specs, briefs, RFP/SOW) are now named explicitly in the housekeeping taxonomy
  as source material destined for `/spec/reference/`, so a spec doc dropped at the
  repo root is reliably recognized and relocated rather than read as ambiguous.

- **Fixed:** Issue-first no longer dead-ends when the host blocks autonomous issue
  creation (#180). The bundled scaffold now pre-authorizes the tracker-metadata
  write verbs (`gh issue create`/`edit`/`comment`) under `.claude/settings.json` →
  `allow`, so the documented find-or-create path is reachable in default-permission
  sessions; delivery (push/PR/merge) stays human-gated under `ask`/`deny`. Rule 36
  and `ISSUE-WORKFLOW.md` now name the host-gating case and route it gracefully
  (confirm with the user, or `!gh issue create` under their identity) instead of
  looping, and the `reconcile-issue-first.sh` Stop advisory acknowledges that a
  blocked create is a host gate, not a skipped step. `check_standards.py` locks the
  new allow-list entries.

### 2.14.0

- **Added:** `/steer:roadmap` — generates a release-milestone timeline for the
  `/spec` spine, viewable as a GitHub Projects v2 roadmap. It turns
  intended-but-unshipped work into milestone-grouped GitHub issues from two
  front-doors: `from-features` (target `intent.md`s not yet `live`) and `from-gap`
  (the expected-unbuilt `Missing`/`Partial` units `/steer:drift` separates from
  Done-but-Missing defects); plus a `sync` mode that reconciles the plan
  create-or-leave. A thin orchestrator — it delegates issue creation to
  `/steer:issues`, gap detection to `/steer:drift`, and routes all GitHub I/O
  through `/steer:tracker-sync`. It writes only native issue attributes (Milestone,
  links, labels, Type), proposes a dependency-ordered plan, and **never fabricates
  a date** — dates are human-confirmed. Per-issue Gantt bars via Project-side
  GraphQL fields are a deliberate future phase, out of scope here.
- **Added:** `/steer:tracker-sync milestone-ensure <title> [--due <date>]` —
  create-if-missing for a repo Milestone so `/steer:roadmap` can fill a release
  before attaching issues. The only op that creates a milestone; **strictly
  confirmation-gated**, never invents a due date, and **create-or-leave** on re-run
  (never overwrites a human-edited title/date).
- **Added:** `ISSUE-SCHEMA.md` now documents the **GitHub Projects v2
  compatibility boundary**. Native issue attributes — Issue **Type**, labels,
  assignees, milestone, and native parent/sub-issue links — are the surface a
  Projects board/roadmap reads, so steer issues are Projects-v2-compatible by
  construction. Project *custom* fields (Status, dates, iteration, priority,
  size) live on the Project **item**, set Project-side, and are never written
  into the issue; body markers are invisible to Projects, so `steer:state` stays
  canonical and is mirrored at most one-directionally by a Project Status field.
  `known-limitations.md` is reconciled (steer still does not automate a board).
- **Added:** `/steer:tracker-sync set-milestone #N <title>` sets or clears an
  issue's native GitHub **Milestone** for release grouping (MCP-first →
  `gh issue edit --milestone`/`--remove-milestone` → manual floor). The milestone
  must already exist — never fabricated; assignment is **on-demand**, not
  auto-managed. Milestone joins the tracker-metadata gateway boundary, and the
  `tracker.md` template documents the release-grouping convention.
- **Added:** `/steer:deliver` — runs a task through a review-gated execution loop
  (plan → independent plan-gate review → sign-off → implementation
  **delegated to `/steer:work`** in GitHub-adopted repos, or direct in
  prototype/local mode → independent `/code-review` code-gate → bounded ≤2-round
  fix loop → report). It orchestrates and reviews rather than owning a second
  governed-implementation path. New reference
  `templates/reference/REVIEW-LOOP.md` documents the protocol; `steer-reviewer`
  gains `/steer:deliver` as an explicit (never auto-delegated) caller for the
  optional code-gate standards check.
- **Fixed:** `/steer:work` pr-flow and the commit-autonomy rule now direct the
  first push of a new `issue/<n>` branch to set the upstream
  (`git push -u origin <branch>`), avoiding the `no upstream branch` failure
  (issue #172).
- **Fixed:** the bundled scaffold `claude/settings.json` now allowlists
  `Bash(git rev-parse:*)` (issue #170). Steer machinery runs `git rev-parse`
  constantly — `worktree-env.sh` (`--show-toplevel`, `--git-dir`,
  `--git-common-dir`) and the `work`/`report`/`protect`/`sync` skills all invoke
  it — but it was absent from the default allow list, so consumers hit a
  permission prompt on routine steer operations. `git rev-parse` is read-only and
  side-effect-free, so it joins `git add`/`git commit` in the pre-approved set.
- **Changed:** the point-of-action bootstrap nudge (`check-code-before-spec.sh`)
  now treats **scaffold** and **/spec spine** as two independent dimensions with
  different cadences (issue #171). The `/spec` spine is product-dependent, so its
  reminder still fires **at most once per session+repo**. The bundled **scaffold**
  (`mise.toml`, CI, PR template, `compose.yaml`, `.gitignore`) is
  product-*independent*, so its reminder is now **sticky**: it re-fires on each
  **new** feature file written while the repo has no root `mise.toml`, dedups
  per file so re-editing the same file never re-nags, and **self-clears** the
  instant a `mise.toml` lands (or the spine becomes managed). The scaffold clause
  names the concrete cost ("zero toolchain/CI/PR-template") so proceeding bare is
  unmistakable. Writing `mise.toml` itself is never scaffold-nudged. Previously a
  single non-blocking once-per-session nudge let a greenfield build proceed with
  none of the bundled scaffold; the nudge stays non-blocking but is now much
  harder to silently skip.
- **Changed:** the scaffold no longer ships placeholder `mise.lock` files, and
  the bundled CI workflow drops its "Drop placeholder mise.lock" step (issue
  #159). That step silently `rm`'d any lock failing a `grep` heuristic, which
  could degrade a real-but-malformed lock to an unpinned `latest` install — the
  exact non-reproducible state pinning exists to prevent. New model: a repo has
  **no `mise.lock` until `/steer:init`/`/steer:adopt` pins the toolchain**
  (`touch mise.lock` → `mise install` → `mise lock --platform …`) and commits a
  *populated* lock. mise-action runs a plain unlocked `mise install` while no
  lock exists, and `--locked` (fails loudly on a bad lock) once one does — the
  comment-only placeholder state simply never occurs. `init`, `adopt`,
  `conventions`, CAPABILITIES, CONVENTIONS, the scaffold README/MANIFEST, and the
  toolchain-pin e2e assert are updated accordingly; never commit an empty /
  comment-only lock.
- **Changed:** the SessionStart ruleset is now **scope-aware**. A rule may
  declare `<!-- steer:inject-when=<token> -->` on its first line, and
  `inject-standards.sh` injects it only when that scope holds for the consumer
  repo — reclaiming context budget for rules that are dead weight where they
  can't apply. Applied to `36-issue-first` (injected only when `/spec/tracker.md`
  declares `system: github`) and `52-deployment` (only when an `/infra` directory
  exists); every other rule stays always-on, and the marker line is stripped
  before injection. **Fail-open:** a missing signal or an unknown token still
  injects the rule, so a typo never silently drops one. GitHub-tracker detection
  is now a single shared helper (`hooks/lib/scope.sh`), reused by the issue-first
  hooks (`check-issue-before-mutation`, `reconcile-issue-first`).
- **Added:** test **coverage** as a first-class standard, complementing the existing test-presence rules. New always-on rule `41-coverage` frames coverage as a *signal to find untested behavior, not a target* — cover the code you touch (critical paths, branches, error handling), keep it measured and visible, and treat a coverage drop on changed code as drift for human review; deliberately **no** global vanity threshold (ties to `95-not-the-gate`). `CONVENTIONS.md` gains a Coverage subsection with per-stack tooling (Vitest `--coverage` / `@vitest/coverage-v8`, `pytest-cov`, language-agnostic `diff-cover` for changed-line regression), replacing the dangling "coverage expectations are in the Testing rules" reference. The scaffold `ci.yml` now emits coverage when the tooling is wired and gates only the **changed lines** against the PR base via `uvx diff-cover` (fail-open when no report or base branch is available; floor tunable via `COVERAGE_DIFF_MIN`); `mise.toml` documents the coverage deps. Coverage lines added to the Definition of Done (`50`), the scaffold PR template, and the `productionization` gap-analysis table.

### 2.13.0

- **Fixed:** solo-trunk delivery mode no longer collides with issue-first. A managed repo can be solo-trunk **and** GitHub-adopted at once (`/steer:init` recommends solo trunk for solo greenfield *and* can configure a GitHub tracker), but rule 36, the Definition of Done, and the two issue-first hooks were blind to delivery mode — so a declared-trunk repo got every-session advisories telling it to open a PR / create an `issue/<N>` branch that solo-trunk explicitly relaxes, and the DoD required a PR that does not exist. Resolved by a single source of truth: a machine-readable marker (`<!-- steer:delivery-mode=solo-trunk|pr-flow -->`) on the product `CLAUDE.md` `## Delivery mode` section. `/steer:init` writes it, `/steer:protect` flips it to `pr-flow` at graduation, and a new `steer_delivery_mode` hook helper reads it (fail-open to `pr-flow`). In solo-trunk, issue-first **still holds** (the issue stays the audit-evidence anchor) — only the branch/PR ceremony relaxes: the PreToolUse and Stop issue-first hooks now keep requiring the issue but tell you to close it from the trunk commit (`Closes #N`) instead of opening a PR or an issue branch. Rules `36-issue-first`, `50-definition-of-done`, `45-commit-autonomy`, `30-spec-workflow`, and `00-router` reworded to match; calling work a "prototype" no longer purports to waive the per-feature issue — declaring solo-trunk mode is the only durable opt-out, and it drops the PR/branch, not the issue.
- **Fixed:** `/steer:work` and `/steer:build` are now delivery-mode aware, completing the solo-trunk thread that previously reached only the rules, hooks, `/steer:init`, `/steer:protect`, and `/steer:audit`. The router sends all "implement now" work to `/steer:work`, but `work` was unconditionally pr-flow — create an `issue/<N>` branch, write a `spec/.work` marker, open a PR — directly contradicting rules `36-issue-first`/`45-commit-autonomy`, which say a declared solo-trunk repo commits straight to `main` with no branch and no PR. `work` now reads the `## Delivery mode` marker once and, in solo-trunk, skips the branch/marker/PR and closes the issue from the trunk commit (`Closes #N`) while keeping issue-first, validation, managed-block progress, and the Definition of Done intact; completion semantics and the next-action recommendations read the trunk commit in place of the PR. `/steer:build`'s governed-mode delegation to `/steer:work` no longer presumes a per-slice PR. Deploy stays human-gated in both modes, and graduation to the PR flow remains `/steer:protect`'s job.
- **Changed:** router Intent→skill table disambiguates `/steer:work` vs `/steer:issues` — implementing a change *now* (with or without an issue number) routes to `/steer:work` (find-or-creates the issue, then implements); pure backlog management routes to `/steer:issues` — and adds a routable row for `/steer:doctor` ("command not found", mise/docker errors, fresh-machine setup), which previously had no entry in the routing table.
- **Added:** new always-on rule `52-deployment` — deployment & environments as a first-class standard. Defines branch-driven promotion (merge to `main` auto-deploys non-prod; a reviewed PR from `main` into a long-lived `prod` branch is the production approval gate and auto-deploys prod on merge), a review app per feature PR, an observability baseline (logs, metrics + alarms, error tracking, health checks, alerting), and rollback + expand/contract migrations. Detail in the scaffold `infra/README.md` and `/steer:conventions`.
- **Added:** `/steer:protect` and `policy/branch-protection.yml` now cover **additional protected branches** beyond the default (schema bumped to 2, additive — v1 policies stay valid). Ships a `prod` entry (required PR review, no direct push, no admin bypass) so the production gate is enforceable without GitHub Enterprise deployment-environment approvals. The skill protects the default branch plus each declared branch, reads/diffs/applies per branch, and reports a not-yet-created `prod` as informational rather than drift.
- **Changed:** secrets-at-rest default is now **SSM Parameter Store (`SecureString`)** — cheaper than Secrets Manager and sufficient for most needs — with Secrets Manager reserved for rotation / cross-account / large-or-binary values. Updated across `70-secrets`, `10-stack`, `60-high-risk`, `CONVENTIONS.md`, `TRACEABILITY.md`, and the scaffold (`infra/README.md`, `env.example`, `compose.yaml`, `gitignore`, `mise.toml`).
- **Changed:** scaffold `infra/README.md` release-flow section rewritten for the branch-based promotion model + review apps + an Observability baseline section; `ARCHITECTURE.md` cross-cutting concerns now enumerate the observability baseline, the deployment/environments shape, and the Parameter-Store secrets default for products to fill in.
- **Fixed:** `/steer:sync` no longer trips the issue-first hooks on its own
  sanctioned flow. The skill reconciles the materialized spine + scaffold (CI,
  `mise.toml`, `compose.yaml`, version-pin scripts, …) on its own `feat/sync`
  branch — operations-class files that, on any other branch, the issue-first
  point-of-action nudge (`check-issue-before-mutation`) and the end-of-turn
  reconciliation advisory (`reconcile-issue-first`) both flag as needing a GitHub
  issue (rule `36-issue-first`). Both hooks now recognize `feat/sync` (and
  `feat/sync-<ver>` / `feat/sync/*`) as a plugin-maintenance branch and stay
  silent there — same rationale as the existing `/spec`-spine exemption, since
  sync carries the scaffold forward identically. The exemption is **flow-scoped,
  not path-scoped** (so a hand-edited `compose.yaml` on a feature branch still
  nudges) and is **withdrawn if app source changes** on `feat/sync`, surfacing a
  sync that violated its "structure only, never app code" contract. Rule
  `36-issue-first` documents the carve-out.

### 2.12.0

- **Added:** solo **trunk mode** for greenfield. `/steer:init` now offers it when one person is both PO and dev with no MVP yet — commit directly to `main` (no `feat/*` branch, no per-feature PR) until graduation, declared in the product `CLAUDE.md` `## Delivery mode` section. The scaffold, spine, tests, Definition of Done, and CI-on-push are unchanged; only the branch/PR ceremony relaxes (there is no second reviewer yet, so the PR gate has nothing behind it). **Graduate** to the normal `feat/*` + PR flow by running `/steer:protect` — which raises the server-side PR wall and ends the mode — the moment the MVP works, you first deploy, or a second contributor joins. `/steer:protect` (verify) and `/steer:audit` treat a declared-trunk unprotected `main` as intentional, not drift.
- **Added:** new always-on rule `31-decision-capture` — durable design decisions (stack, auth, data model, a locked MVP scope) belong in `/spec` (intent/contract/ADR), the single source of truth a teammate inherits; conversation and assistant memory are working notes, never the record. On a repo with no `/spec` spine, bootstrap (`/steer:init` / `/steer:adopt`) **before** persisting a decision, so it lands traceable in the bootstrap PR rather than memory- or chat-only.
- **Changed:** router bootstrap-precedence now directs that bootstrap be the **first move, announced up front** on a spineless repo — not a closing offer after a long scoping pass; the scoping dialogue folds into `/steer:init`'s own interview and durable decisions wait for the spine.
- **Changed:** `/steer:init` Path B step 1 now states that scoping a brief/spec happens **as the setup interview** and its decisions are captured into the just-created spine (ADR / `vision.md`), never left chat- or memory-only.
- **Added:** per-worktree runtime isolation so parallel Claude Code worktrees of
  the same repo don't collide on Docker containers/volumes or host ports. New
  scaffold `scripts/worktree-env.sh`, sourced by `mise.toml` (`[env]._.source`),
  derives a unique `COMPOSE_PROJECT_NAME` and a stable per-worktree host-port
  offset for `POSTGRES_PORT`, `WEB_PORT`, and `DATABASE_URL`; the primary checkout
  gets offset 0 (ports unchanged), so single-checkout dev is unaffected. Two
  agents can each `mise run docker:up` without clashing. Wired into `compose.yaml`,
  `env.example`, `.worktreeinclude`, and `MANIFEST.md`.
- **Added:** `docker:clean` mise task (down + volumes + orphans, scoped to the
  worktree's `COMPOSE_PROJECT_NAME`) for end-of-worktree teardown, and a new
  always-on rule `24-worktrees.md` that requires isolating runtime resources and
  tearing down services/dev servers before a worktree is closed — no leaked
  containers, volumes, or held ports. Added to the end-of-session checklist.
- **Added:** `worktree-port-isolation` capability to `reference/CAPABILITIES.md`
  and `scripts/scan-capabilities.sh`, so `/steer:sync` detects and repairs the
  deriver + mise wiring in already-adopted repos (applicable when the repo has a
  compose.yaml or a Node/Python stack).

### 2.11.0

- **Changed:** version-pin policy floors raised to track upstream end-of-life (automated by `version-policy-refresh.yml`): mongo 6→7, node 20→22, nginx 1.26→1.30. EOL floors only — what to pin (current stable) is still chosen live per the versioning rule; this just stops dead majors.
- **Added:** the **`context7`** MCP server now ships with the plugin
  (`plugins/steer/.mcp.json`), giving every steer session up-to-date,
  version-accurate library/API documentation on demand. It uses context7's
  **hosted HTTP transport** (`https://mcp.context7.com/mcp`) — like the `github`
  server there is no local process, package fetch, or runtime dependency, so it
  connects out of the box with **no token** (the anonymous free tier). A
  `CONTEXT7_API_KEY` is optional and only raises rate limits; export it and add an
  `Authorization` header in your own project `.mcp.json` (which merges additively)
  if you hit them. Documented in `reference/mcp-servers.md` and the scaffold
  `README.md`. It complements `markitdown`/`Read` (document conversion) by
  covering live library docs, not files you hand over.
- **Changed:** the `github` + `markitdown` MCP servers now ship with the
  **plugin itself** (`plugins/steer/.mcp.json`) instead of being scaffolded as a
  per-repo `.mcp.json`. Every repo that enables steer picks them up centrally and
  they refresh on `/plugin update` — no frozen per-repo copy to drift or
  reconcile. Each server still goes through Claude Code's per-server approval, and
  a repo may still add its own project `.mcp.json` for product-specific servers
  (it merges additively with the plugin's). Removed `templates/scaffold/mcp.json`
  and its `MANIFEST.md` row; updated `/steer:init`, `/steer:adopt`,
  `/steer:tracker-sync`, the scaffold `README.md` / `mise.toml`, and the docs
  `reference/mcp-servers.md`. A **v2.11.0 migration** (`MIGRATIONS.md`) has
  `/steer:sync` remove the now-redundant repo-local `.mcp.json` (or just the
  duplicated `github`/`markitdown` keys, preserving product-specific servers) from
  repos bootstrapped before this change.
- **Fixed:** corrected the Cowork hook-firing guidance in the `standards` skill,
  the `00-router` rule, and the scaffold `copilot-instructions.md` template. They
  no longer claim plugin hooks "don't fire in Cowork" (the superseded position,
  which cited a since-closed upstream issue). The scope now matches
  `known-limitations.md` / `CROSS-SURFACE.md`: hooks run on Claude Code (CLI, IDE
  extensions, Desktop *Code* tab) **and in Cowork**; only the Desktop *Chat* tab
  and claude.ai web chat lack them — which is where `/steer:standards` remains the
  load-by-hand fallback.
- **Fixed:** reconciled the branch-naming guidance in the `45-commit-autonomy`
  rule with `/steer:work` — the rule now points to the repository's configured
  convention and the issue-first `issue/<number>-<slug>` default instead of
  asserting `feat/*` / `fix/*` flatly.

### 2.10.0

- **Added:** documented **VS Code as the default editor** and the
  extension-driven workflow for adjacent activities (database browsing/queries,
  Terraform/HCL, GitHub Actions, ShellCheck, `.env`). The scaffold already
  shipped `.vscode/extensions.json` + `settings.json`, but the standards prose
  was silent on the convention. A lean pointer now lives in the always-on Stack
  rule (`10-stack.md`), the full rationale in the Conventions reference
  (`CONVENTIONS.md` → "Editor & IDE", surfaced via `/steer:conventions`) — framed
  as a default bias, not a mandate, and clarifying that an editor DB extension is
  for ad-hoc dev browsing, not a second app data-access path (the ORM still owns
  that).
- **Fixed:** bootstrap now commits a `mise.lock` that passes CI on the first run.
  Previously `/steer:init` / `/steer:adopt` / `/steer:build` told the dev to run
  `mise install` and commit the lock, but `mise install` only records asset URLs +
  checksums for the **host** platform. A repo bootstrapped on macOS therefore
  committed a lock with no `linux-x64` entries, and the very first CI run failed at
  `Setup mise` with *"No lockfile URL found … on platform linux-x64 (--locked
  mode)"* — mise-action enables `--locked` whenever a lock exists. The pin step in
  all three skills (plus the reference `CONVENTIONS.md`, `/steer:conventions`, and
  the scaffold `mise.toml` / `mise.lock` / `README.md` / `infra/*` / `MANIFEST.md`)
  now runs **`mise lock --platform linux-x64,macos-arm64`** after `mise install`
  (linux-x64 mandatory for CI; add `macos-x64` / `linux-arm64` / `windows-x64` for
  other dev platforms) and verifies the lock holds a `platforms.linux-x64` `url` +
  `checksum` block — not just `[[tools.*]]` version entries, which still fail
  `--locked`. (#122)
- **Fixed:** `/steer:init` no longer mislabels the greenfield bootstrap PR as
  "the productionization gate." A greenfield bootstrap ships scaffold + an empty
  spec spine with no app to harden, so its dev-review PR is the **bootstrap/setup
  gate** (brings the repo under the standards, lets spec-first work begin on
  `main`), not productionization. Productionization stays a later, per-app event
  — the `/steer:build` v0 handoff or `/steer:adopt`, where real code is triaged
  into `/spec/PRODUCTIONIZATION.md` before a production deploy. Path B step 7 now
  says so explicitly and tells init to frame the PR body / HISTORY entry as the
  bootstrap gate. (`/steer:build` and `/steer:adopt`, which inherit real code,
  are unchanged — their productionization framing is correct.)
- **Changed:** normalized the bullet markers in the `SPEC-FRAMEWORK.md` reference
  template to dashes, so the whole `templates/reference/` set uses one consistent
  list style. Prose-only; no behavioral change.
- **Added:** GitHub Copilot support now covers **VS Code**, not just the CLI. The
  always-on standards already reached VS Code via the same
  `.github/copilot-instructions.md` (read natively); the skills now ship too, as
  generated `.github/prompts/steer-<skill>.prompt.md` prompt files, surfaced in
  Copilot Chat as `/steer-<skill>` slash-commands. Generated from `skills/` by
  `mise run gen:copilot` (new `scripts/gen_copilot_prompts.py`), kept honest by a
  drift gate (`scripts/check_copilot_prompts.py`, in `plugin-check`), installed by
  `/steer:init` / `/steer:adopt`, and mapped in the scaffold `MANIFEST.md`. The
  bundled `.vscode/settings.json` enables instruction- and prompt-file reading
  explicitly. Prompt files are intent capsules (purpose / when-to-use / arguments),
  not verbatim skill bodies — the authoritative procedure stays in the plugin. Docs,
  manifests, and the scaffold MANIFEST are reframed from "Copilot CLI" to
  "Copilot (CLI + VS Code)".
- **Fixed:** the Copilot manifests (`.github/plugin/plugin.json` and
  `.github/plugin/marketplace.json`) had drifted to `2.8.1` behind the plugin's
  `2.9.0`. Both are realigned, and `check_plugin.py` now gates their version
  against `.claude-plugin/plugin.json` (the release helper bumps all three) so the
  Copilot marketplace can no longer silently lag a release.
- **Added:** `/steer:doctor` — a prerequisite detector + confirmation-gated
  installer that takes a blank or half-set-up machine to the point where
  `/steer:init`, `/steer:build`, and `mise run dev:setup` work. It runs a new
  read-only `scripts/scan-prereqs.sh` (detects host OS and git / mise / Docker /
  the mise-managed node/pnpm/uv, with `compose.yaml`- and stack-aware
  conditionality), reports status plainly, and installs the scriptable tools
  (mise, then the runtimes via `mise install`) on the user's yes — handing over
  manual instructions for the GUI/host steps a skill cannot script (Docker
  Desktop, Windows→WSL2). `/steer:build` and `/steer:init` now delegate their
  toolchain setup here instead of carrying their own copies, closing the
  dev-path gap where `/steer:init` previously assumed `mise` was already
  installed. `rules/15-commands.md` and the scaffold README dev quickstart now
  point at it.

### 2.9.0

- **Changed:** hardened greenfield bootstrap precedence so a **prototype** can no
  longer be read as an escape hatch from the bundled scaffold and `/spec` spine.
  The observed failure: a brand-new repo with the plugin active, asked for a
  "quick prototype", got a from-scratch `package.json` / `vite.config` / `tsconfig`
  and **no** `mise.toml` / `compose.yaml` / CI / PR template and no `/spec` — the
  session treated its own "quick prototype" framing as license to skip bootstrap
  entirely. Both bootstrap hooks had fired correctly; the gap was that nothing
  refuted the "prototypes are exempt" reading, and every nudge framed the harm as
  "skipping the spec" rather than "hand-rolling scaffold-equivalent files instead
  of installing the bundled scaffold." Now the router rule (`00-router.md`) and
  the Spec-workflow rule (`30-spec-workflow.md`) state explicitly that
  "prototype" / "quick" / "throwaway" relax spec *depth* and *ceremony*, never
  *whether* the bundled scaffold and `/spec` spine exist; both bootstrap hooks
  (`check-unmanaged-repo.sh`, `check-code-before-spec.sh`) now name the scaffold
  dimension and the prototype non-exemption in the context they inject; and the
  `build` skill's "Prototype/local mode" bullet spells out that it relaxes only
  issue/PR/approval ceremony, not the scaffold or spine.
- **Added:** GitHub Copilot CLI target — skills + a gate hook (Phase 2). A
  Copilot-specific plugin manifest (`plugins/steer/.github/plugin/plugin.json`,
  which Copilot prefers over `.claude-plugin/`) loads steer's skills via the
  cross-tool `SKILL.md` standard and points hooks at a Copilot-native
  `hooks/copilot-hooks.json` — so Copilot no longer falls back to Claude's
  `hooks/hooks.json` (whose fail-closed `preToolUse` semantics could otherwise
  block edits). The version-pin policy gate is ported as a soft `ask`:
  `check-version-pins.sh` emits Copilot's flat `permissionDecision` envelope when
  invoked with `STEER_HOOK_TARGET=copilot`, leaving the Claude `deny` path
  untouched. Skill tool-permission scoping (`allowed-tools`/`disallowed-tools`)
  is inert on Copilot and skill bodies remain Claude-centric — documented in
  `docs/concepts/copilot-support.md`. Subagents are not ported.
- **Added:** GitHub Copilot CLI target (prototype, standards-only). The org
  engineering standards now reach Copilot CLI users as a generated
  `.github/copilot-instructions.md`, concatenated from the same
  `plugins/steer/rules/` that Claude Code receives via the SessionStart hook —
  Copilot has no context-injecting hook, so the rules ship as its primary
  always-on custom-instructions file (chosen over `AGENTS.md`, which Copilot
  merges with `CLAUDE.md` and which Claude Code ignores). New
  `scripts/gen_copilot_instructions.py` (+ `mise run gen:copilot`) builds the
  committed artifact under `templates/github/`; `scripts/check_copilot_instructions.py`
  (wired into `plugin-check`) fails the build if it drifts from the rules.
  `/steer:init` and `/steer:adopt` install it (overwrite-managed); a Copilot
  marketplace manifest lands at `.github/plugin/marketplace.json` (steer only).
  Skills, gate-hooks, and agents are deferred to later phases.
- **Added:** `/steer:issues brainstorm` and `capture` now treat the **existing
  issue corpus as required context**. Before synthesizing, both search open *and*
  closed issues (via `/steer:tracker-sync search`, by topic and its alternatives)
  for issues the current one **overlaps, depends on, or conflicts with** — the
  case a relationship-blind brainstorm misses (e.g. a Cognito-hosting discussion
  that ignores a pending `better-auth` migration issue). Discovered connections
  are surfaced in the AI-synthesis comment and recorded as cross-links; conflicts
  and supersessions are flagged for a human, never auto-resolved. Previously the
  only guidance was a single "find overlapping features/issues" clause with no
  mandate to search the corpus and nowhere to record what it found.
- **Added:** a `Related issues` managed-block heading (feature / task / bug) in
  `ISSUE-SCHEMA.md` and the issue-body templates, holding `#N — <relationship>
  (why)` lines. The `#N` mention auto-creates GitHub's native backlink, so the
  relationship is honest about GitHub having no typed relationship beyond
  parent/sub-issue. Omitted entirely when there are no related issues.
- **Added:** `issue_relationship` controlled vocabulary (`relates-to` ·
  `depends-on` · `blocks` · `conflicts-with` · `supersedes` · `superseded-by`) in
  `enums.registry` + `ENUMS.md`, and a `link-related #N <other> <relationship>`
  operation in `/steer:tracker-sync` that records the cross-link (with optional
  reciprocal line on the other issue) idempotently, MCP-first → `gh` → manual.
- **Changed:** `/steer:work finish` now watches CI to conclusion after pushing
  (`gh pr checks --watch`) and fixes a red build as part of the same unit of work,
  rather than stopping at PR-open. The agent hands the reviewer a green PR instead
  of a running or red one. Previously nothing instructed the agent to monitor CI,
  so a failing build sat unnoticed until a human poked it. The post-push CI watch
  is reflected in the `## Recommended next actions` table (new `CI running` /
  `CI red` / `CI green, awaiting review` rows), in the Commit-autonomy and
  Definition-of-Done rules, and in `NEXT-ACTIONS.md` (active CI-watch is now a
  concrete agent step with a command, distinct from the passive "wait for a human
  to merge" non-command step).
- **Added:** the `work` skill pre-approves read-only CI-status commands
  (`gh pr checks`, `gh run view`, `gh run watch`) so the post-push watch runs
  without a permission prompt per poll. `git push`, `gh pr create/edit/merge`,
  `gh api`, and destructive git stay human-gated exactly as before — watching CI
  and fixing red is finishing the work, not crossing the merge gate. The detached
  case (user stepped away) is documented as an opt-in `/loop` over `gh pr checks`;
  steer ships no background poller.

### 2.8.1

- **Fixed:** `/steer:build` referenced the spec-framework reference with a
  lowercase filename (`templates/reference/spec-framework.md`); the file on disk
  is `SPEC-FRAMEWORK.md`. The link resolved on case-insensitive macOS but broke
  on Linux/CI — i.e. in the consumer repos the skill targets. Corrected both
  occurrences to the canonical uppercase name.
- **Fixed:** the four read-only Tier-1 skills `conventions`, `traceability`,
  `standards`, and `design-sources` were missing the `disallowed-tools: Edit,
  Write, NotebookEdit, EnterWorktree` declaration that `AUTHORING.md`'s Tier-1
  list requires (and that `audit`/`drift`/`next` already carried). Added it to
  all four so the read-only permission boundary is declared consistently.
- **Fixed:** the `/steer:standards` `when_to_use` claimed plugin hooks "do not
  fire" on Claude Cowork and the desktop app. Per the June-2026-validated surface
  map, Cowork *does* run hooks and only the chat-only surfaces (Desktop Chat tab,
  web chat) don't. Corrected the trigger guidance to match.
- **Fixed:** `/steer:sync` (and `/steer:adopt`) no longer produces a
  contradictory `.claude/settings.json` where the same permission pattern lands
  in two precedence tiers — e.g. `Bash(git push)` in both `allow` and `ask`.
  The `scripts/scaffold_reconcile.py` JSON merge unioned each permission list
  independently, so when a repo had locally allow-listed `git push` and the
  template carries it in `ask`, the merge appended to `ask` while leaving the
  `allow` copy in place. The reconcile now de-conflicts the `permissions`
  block after merging: each pattern is kept only in its most-restrictive tier
  (precedence **deny > ask > allow**) and dropped from the others. This both
  prevents a sync from manufacturing the contradiction and heals one already on
  disk; effective behavior is unchanged because the surviving tier is the one
  that already governed.
- **Fixed:** the bundled `scripts/scan-version-pins.sh` no longer fails an
  adopting repo's own `ci` shellcheck step. The policy-violation message embeds
  the literal markdown `` `# steer:allow-pin <reason>` `` whose backticks tripped
  ShellCheck **SC2016** in consumer repos (which carry the verbatim script and the
  scaffold's shellcheck step but not this repo's `.shellcheckrc`). Added a
  targeted `# shellcheck disable=SC2016` directive on that one line — scoped to the
  single false positive so every other check stays on — rather than a repo-wide
  `.shellcheckrc` or a severity downgrade that would weaken the gate. Synced
  byte-identically into the scaffold copy.

### 2.8.0

- **Fixed:** low-severity audit nits. The no-jq `steer_field` fallback in
  `hooks/lib/json.sh` now mirrors jq's precedence — it searches the post-`tool_input`
  slice before the whole document, so a same-named top-level decoy field can't be
  picked (now covered by the hook suite, which forces the no-jq path). The
  `check-version-pins` hook sanitizes the one interpolated value before embedding
  it in its JSON reason, matching the sibling point-of-action hooks. Scaffold docs
  fixed: the markitdown server is attributed to `uvx markitdown-mcp` (not a
  non-existent bundled `packages/markitdown-mcp`), and the `spec/design/README.md`
  template is retitled "Design exports" so it no longer collides with the
  `source.md` provenance file (both were titled "Design source").
- **Fixed:** the `/steer:standards` skill's rule enumeration was missing
  `36-issue-first`, `87-output-discipline`, and `97-self-report` — three always-on
  rules a reader of the list would have believed weren't part of the operating
  manual. Resynced to all 24 `rules/*.md` files. (Repo-side, a new
  `check_standards.py` guard now fails CI if this list — or the CLAUDE.md skill
  list or CROSS-SURFACE.md's rule count / SessionStart hook roster — drifts from
  disk, so the class of bug can't recur.)
- **Added:** new always-on rule `87-output-discipline.md` curbing generated noise —
  comments are the exception (reserved for the non-obvious *why*), and prose
  responses stay tight (lead with the result, skip self-narration). Backed by a
  matching "comments carry weight" pattern and a "noise comments" anti-pattern in
  the `/steer:conventions` reference prose. Reins in Claude's default verbosity,
  which steer's standards previously never governed.
- **Changed:** standardized file naming so one convention governs each file class.
  Renamed `scripts/scaffold-reconcile.py` → `scaffold_reconcile.py` (Python is
  `snake_case`) and the reference doc `spec-framework.md` → `SPEC-FRAMEWORK.md`
  (reference prose is `UPPERCASE.md`, matching its siblings), updating every
  `${CLAUDE_PLUGIN_ROOT}` invocation, markdown link, and prose path reference.
  Both are **plugin-internal** — `scaffold_reconcile.py` runs from the plugin
  root and `SPEC-FRAMEWORK.md` is read in place — so neither is materialized into
  product repos and `/steer:sync` needs no migration entry. The convention is now
  documented in `AUTHORING.md` (Cross-cutting conventions). (Repo tooling
  `scripts/delivery_gates.sh` → `delivery-gates.sh` rides along; not shipped.)
- **Changed:** bumped the GitHub Actions pinned in the scaffold workflow templates
  to current majors — `actions/checkout` `@v6` → `@v7` (`ci.yml`, `claude.yml`) and
  `dependabot/fetch-metadata` `@v2` → `@v3` (`dependabot-auto-merge.yml`). Both are
  runtime-only majors (Node 24 runner); no input/output contract change, so
  consumer repos that re-scaffold pick up supported action versions. (`mise-action@v4`,
  `create-github-app-token@v3`, and `claude-code-action@v1` were already current.)
- **Changed:** the version-pin policy is now a pure **EOL floor**. Dropped the
  `recommended` field from `policy/versions.yml` and the advisory ("supported but
  behind the target") verdict from the hook and `version-policy.sh`. The
  `recommended` tier duplicated the live versioning rule (verify current stable
  in-session) and silently rotted — nothing checked it against latest stable. The
  policy now carries only `minimum_supported` + `denied`, and the hook is
  deny-or-silent. **What** to pin is still decided live; the file only blocks dead
  majors. No new deny: a pin that was merely "advised" before is now silent.
- **Changed:** `version-policy-refresh.yml` now **opens a PR that raises stale
  floors** instead of filing an advisory issue. `check-policy-freshness.sh` gained
  a `--write` mode that computes each floor as the lowest cycle still supported
  upstream (endoflife.date), at the floor's existing granularity, **bump-up-only**
  (a deliberately stricter-than-EOL floor is preserved), and edits both
  byte-identical `versions.yml` copies idempotently. The workflow appends a
  `CHANGELOG` entry and opens/updates a human-reviewed PR (`contents: write` +
  `pull-requests: write`). endoflife.date is still consulted *only* here, off the
  enforcement path. (Caveat: token-opened PRs don't auto-run CI; the reviewer
  re-triggers it before merge.)
- **Fixed:** stale `CONVENTIONS.md` enforcement prose — it still described the old
  design that "resolved current stable from the endoflife.date API at write time."
  Rewritten to describe the deterministic floor, the live rule as the version
  *chooser*, the `# steer:allow-pin` marker (was `# pin-ok`), and the auto-refresh PR.
- **Added:** an optional `created: YYYY-MM-DD` field on the `### Q-NNN`
  open-question contract (spec-framework, `feature-intent.md` / `vision.md`
  seeds, `ENUMS.md`). It records when a question was raised so staleness can be
  measured; it stays optional — when absent, the SessionStart hook ages the
  question from its heading's `git blame` date instead.
- **Changed:** the `check-open-questions.sh` SessionStart hook now **escalates a
  stale question** — a `blocking`, still-open, un-promoted question older than 14
  days gets its own loud line naming the feature, `Q-NNN`, owner role, and age,
  so it can't rot unseen. Age math runs in awk (days-from-civil) so it never
  depends on GNU-only `date -d`; `STEER_TODAY` overrides "today" for tests. The
  hook only *detects* staleness — issue creation stays on the human-gated
  `/steer:questions → /steer:issues` path.
- **Changed:** promoting a spec question now resolves its `owner:` role to a
  GitHub assignee via a new `owners:` map in `spec/tracker.md` (`shared` → product
  **and** development; a blank row → unassigned + `needs:triage`). `/steer:questions`
  treats hook-flagged staleness as a promotion trigger; `/steer:spec validate`
  fails a malformed `created:` and warns on a stale un-promoted blocking question.
- **Fixed:** the scaffold's `policy/branch-protection.yml` is now byte-locked to
  the plugin's bundled copy. It was already shipped as a verbatim duplicate but,
  unlike `policy/versions.yml` and the two version-pin scripts, was missing from
  the `check_standards.py` sync check (`_SCAFFOLD_COPIES`) — so the scaffold seed
  and the plugin default could silently drift. Added it to the check; no behaviour
  change for consumers, the two files are identical today.

### 2.7.0

- **Scaffolded repos now ship Dependabot, and steer manages the PRs.** New
  `.github/dependabot.yml` (`github-actions` live; `npm`/`pip`/`docker` blocks
  commented for `/steer:init`/`/steer:adopt` to uncomment per detected stack,
  grouped, majors ignored) plus a `dependabot-auto-merge.yml` workflow that
  **auto-approves and auto-merges patch/minor Dependabot PRs** once the required
  `ci` check is green. This is a **deliberate, documented exception** to the
  human-review gate: dependency bumps don't touch application logic, so the human
  *review* is waived — but the workflow waits for green CI before it merges, so a
  bump that breaks tests/lint/the version-pin scan never lands. Auto-merge is
  **scoped to Dependabot by the workflow's `dependabot[bot]` guard** — it does NOT
  enable GitHub's repo-wide `allow_auto_merge` setting (which would expose an
  auto-merge button to every PR); the workflow merges the single Dependabot PR
  directly once `ci` passes. **Major** bumps are never auto-merged (they can break
  and may need a `policy/versions.yml` decision) and get a "left for a human"
  comment instead. The exception is documented in `policy/branch-protection.yml`
  and the scaffold `README.md` branch-protection section. `/steer:protect` now also
  enables the repo settings the exception needs — Dependabot alerts and security
  updates — alongside secret scanning, and the new `dependency-automation`
  capability lets `/steer:sync` wire and repair both files. protect configures
  settings only; it never opens PRs or merges.

### 2.6.0

- **`/steer:work start` now self-assigns the issue to you.** Claiming an issue
  assigns the invoking GitHub user (self-assign) alongside the existing
  `steer:claimed-by` marker and `in-progress` transition, so the accountable
  human is visible on the tracker without a manual `gh issue edit`. The
  `tracker-sync` `assign/claim` op makes this explicit: the default subject is
  the invoking user (`@me` on the `gh` path / the authenticated login on MCP),
  and it **adds** rather than replaces assignees — an existing assignee is
  preserved and a conflicting claim is still reported, never auto-overridden.

### 2.5.0

- **steer now reports its OWN defects upstream.** New `/steer:report` skill files
  a bug about the plugin itself in `element22llc/e22-plugins` — it gathers the
  defect (a recorded hook fault, a contradictory skill/rule instruction, or a
  missing/broken template or script), **scrubs** it of secrets/absolute-paths/
  product-code, **deduplicates** against existing upstream issues by a stable
  `steer:fault-fingerprint`, renders the body for review, and only on explicit
  confirmation files via `gh` (read-only `allowed-tools`; the upstream write stays
  permission-prompted, with a paste-ready issue-form URL fallback when access is
  missing). Detection feeds it from two sides: hooks record their own
  malfunctions network-free via the new `hooks/lib/report-fault.sh`
  (`steer_record_fault`, deduped, fail-soft) to a git-ignored
  `.claude/steer-faults.log`, and the new `surface-faults.sh` SessionStart hook
  raises any *unreported* faults once (tracked by a `.surfaced` marker, never a
  per-session nag). `inject-standards.sh` records a fault when its rules dir is
  missing. New always-on rule `97-self-report.md` tells the model to treat steer's
  own misbehaviour as a reportable defect and offer `/steer:report` rather than
  silently work around it — strictly steer defects, not product-code bugs. Ships a
  `steer-bug` issue-body template, a repo `.github` self-report issue form, and
  `.claude/steer-faults.*` gitignore entries in the scaffold.
- **Bootstrapped repos now work in Claude Code worktrees out of the box.** The
  scaffold ships a `.worktreeinclude` (installs at the repo root) listing the
  git-ignored local config — `.env` / `.env.local` / nested `apps/*/.env` /
  `infra/.env`, `.mise.local.toml`, `.claude/settings.local.json` — that Claude
  Code copies into each `claude --worktree`. Worktrees start from git refs only,
  so without it the app couldn't boot in a worktree (no `DATABASE_URL`, no local
  secrets). The scaffold `.gitignore` now also ignores `.claude/worktrees/` so
  those linked working trees don't show as untracked in the parent repo, and the
  "Secrets handling" rule notes that `.worktreeinclude` is what preserves the
  git-ignored-`.env` boot guarantee under `--worktree`. `MANIFEST.md` maps the
  new file, and `scaffold-reconcile.py` now recognizes `.worktreeinclude` as a
  line-based file so an existing one is merged additively (append missing
  patterns, never clobber) — same as `.gitignore`.

- **New read-only `steer-reviewer` subagent hardens large-repo fan-out in
  `/steer:audit` and `/steer:drift`.** Both skills already described fanning out
  one reviewer per dimension/feature, but that was loose prose and a generically
  spawned worker wasn't guaranteed to inherit each skill's read-only contract.
  `plugins/steer/agents/steer-reviewer.md` ships a worker with a `Read`/`Grep`/
  `Glob`-only allowlist (no shell, no edits — read-only *by construction*), and
  the two skills now invoke it **explicitly** (not via auto-delegation, the
  failure mode that retired the earlier `steer-analyzer`) above a size gate —
  audit per applicable dimension, drift per feature — while keeping vetting,
  ranking, and tracker I/O in the lead. Below the gate the skills review inline.
  The subagent grants **no new authority**: its tools are strictly narrower than
  the skills that call it. `scripts/check_plugin.py` now validates `agents/*.md`
  frontmatter (requires `name`/`description`, rejects the plugin-ignored
  `hooks`/`mcpServers`/`permissionMode` fields); `scripts/validate_docs.py` keeps
  `docs/reference/agents.md` in sync with the shipped subagents.
- **Work markers now carry Claude Code session breadcrumbs.** `/steer:work`
  records its local marker as `spec/.work/<branch>.md` (was an extensionless,
  content-free file) with a newest-first list of the Claude Code session(s) that
  worked the branch. The `reconcile-issue-first.sh` Stop hook keeps the head
  current each turn — a single fail-open, idempotent, atomic update that never
  rewrites the `issue:`/`branch:` header — and `/steer:work resume` surfaces a
  prior session as a context source (`claude --resume <id>` + the transcript path)
  before continuing. Session ids stay in the git-ignored marker and never reach
  tracker metadata. The hook honours legacy extensionless markers, so repos mid-
  transition keep working (no migration needed; markers upgrade on the next
  `start`/`resume`).
- **`/steer:sync` now repairs pre-2.0.0 rebrand tokens left in materialized
  files.** A repo bootstrapped under the old `e22-standards` name kept stale
  `/e22-*` command refs, the dead `e22-standards@e22-plugins` settings/CI marker,
  and `e22:` spec markers — sync left them untouched because the migration ledger
  had no rebrand entry and additive reconciliation never rewrites an existing line.
  Added a v2.0.0 in-file token-rewrite entry to `MIGRATIONS.md` that rewrites those
  tokens to the `steer:` forms under read-then-propose/never-clobber, while leaving
  the intentionally-unchanged `e22-plugins` marketplace id alone. Widened the ledger
  preamble + new-entry template and `sync` step 4 so an in-file token rewrite is a
  first-class ledger action alongside `git mv` / `git rm`, and noted in
  `CAPABILITIES.md` that the dead settings key is removed by this migration (not by
  the additive `plugin-enabled-local` repair).

### 2.4.0

- **`/steer:protect` now emits a copy-paste-safe branch-protection command.** The
  apply example used a quoted heredoc (`<<'JSON'`) whose closing delimiter is
  indented because the code fence sits inside a numbered list; a heredoc
  terminator must be at column 0, so the command Claude handed devs hung at the
  shell's `heredoc>` prompt and never ran. The example now pipes single-quoted
  JSON from `echo` into `gh api --input -` — no terminator, so it pastes safely
  at any indentation — and the skill instructs Claude to substitute resolved
  `OWNER`/`REPO`/`BRANCH` and the real CI context inline rather than leaving
  `${...}` placeholders or a heredoc in the command it hands over.
- **`/steer:sync` now repairs capability-blocking scaffold drift, not just
  template drift.** Additive reconciliation only splices into files that already
  exist and the migration ledger only transforms files that exist — so a repo
  adopted before a capability shipped (or that lost a wiring file) silently
  lacked it (no `.claude/settings.json` enabling steer, no `claude.yml` loading
  the plugin in CI, drifted version-pin scripts, missing `branch-protection.yml`)
  and sync still reported "current." Sync now walks a new capability map
  (`templates/reference/CAPABILITIES.md`) via a read-only detector
  (`scripts/scan-capabilities.sh`) after migrations + reconciliation, and
  proposes the missing/mis-wired wiring — create-from-scaffold, additive-splice
  the named marker, or verbatim-recopy the version-pin scripts (diff shown
  first). It is **presence + wiring only**: conditional files (Node tooling,
  Issue Forms, `compose.yaml`) are skipped when their stack/tracker predicate
  doesn't apply, a `"steer@e22-plugins": false` is respected as a deliberate
  opt-off, and follow-ups it can't do itself (`/steer:protect`,
  `/steer:issues bootstrap-labels`, the org `STEER_APP_ID` secret) are surfaced
  in the next-actions block rather than run. A new read-only **`--check`** mode
  prints the capability status table with no branch or PR. Read-then-propose,
  never clobber, never commits to `main`, PR targets `BASE` — all unchanged.
- **Structured-config scaffold files now reconcile mechanically, additively, and
  never-clobber.** Merging the scaffold into a repo that already has its own
  `.gitignore` or JSON configs (`.claude/settings.json`, `.mcp.json`,
  `biome.json`, `tsconfig`) was prose-only: the existing `template-reconcile.sh`
  diffs Markdown heading/checklist anchors and cannot parse those formats, so
  `/steer:adopt` and `/steer:sync` relied on the model eyeballing the merge — the
  highest "break the user's working repo" risk in the bootstrap path. A new
  `plugins/steer/scripts/scaffold-reconcile.py` (stdlib-only, the structured-config
  sibling of `template-reconcile.sh`) does a deep **additive** merge: JSON objects
  recurse, arrays union, existing scalars/lines are **never overwritten, reordered,
  or removed**, and an unparseable existing file is refused (exit 3) rather than
  clobbered. Default check mode is read-only and mirrors `template-reconcile.sh`'s
  exit-code contract; `--apply` writes the merge. `/steer:sync`,
  `/steer:adopt`, and `/steer:init` now invoke it for those files, and the
  scaffold `MANIFEST.md` per-file notes point at it. Complements the
  capability-repair pass (presence + wiring): this handles additive content
  inside files that already exist; capability repair handles missing/mis-wired
  whole files.
- **In-CI Claude now runs under the same steer standards as a local session.**
  The shipped `.github/workflows/claude.yml` (the `@claude` mention workflow) was
  the stock Anthropic template, so the in-CI agent ran as a standards-less Claude —
  no stack defaults, no Definition of Done, no spec/drift discipline. It now loads
  the `steer` plugin via `anthropics/claude-code-action@v1`'s purpose-built
  `plugins` / `plugin_marketplaces` inputs (a settings.json `enabledPlugins` block
  does **not** work in headless CI — it is trust-dialog gated and fails silently),
  so steer's SessionStart hook injects the same `rules/*` it does locally. Because
  the org marketplace repo is private, the workflow mints a short-lived,
  repo-scoped token from a shared **GitHub App** (org-level `STEER_APP_ID`
  variable + `STEER_APP_PRIVATE_KEY` secret) via `actions/create-github-app-token`
  — one org-controlled credential rather than per-repo PATs (the default
  `GITHUB_TOKEN` cannot reach another org repo). The scaffold README (with the
  one-time org App setup), MANIFEST, and a new docs page document the credentials
  and how to verify the plugin actually loaded.
- **Optional `gh aw` (GitHub Agentic Workflows) lane — opt-in, not scaffolded.**
  Ships one example agentic workflow, `templates/github/agentic/triage.md`
  (scheduled issue triage that classifies against the steer label taxonomy and
  Issue Types, advisory-only via `safe-outputs` — never closes issues or resolves
  product/technical questions, preserving the human gate). It is deliberately
  **not** installed by `/steer:init`/`/steer:adopt` and **not** in `MANIFEST.md`:
  gh-aw is a research demonstrator and overlaps with `/steer:issues` triage, so
  teams opt in consciously. A new docs page (Reference → GitHub Actions
  integration) carries the recipe and the rationale for keeping it out of the
  default scaffold.
- **Scaffold ships a `markitdown` MCP server for local document ingestion.** The
  bundled `.mcp.json` now wires Microsoft's markitdown MCP server (via
  `uvx markitdown-mcp`) alongside the GitHub one, so bootstrapped repos can
  convert stakeholder-provided Office documents (`.docx`/`.xlsx`/`.pptx`, plus
  HTML/EPUB/CSV/…) into clean Markdown locally instead of choking on raw zip+XML.
  PDFs and images still use Claude's native `Read` (no conversion needed). It
  needs only `uv` on `PATH` — no token. Relatedly, the scaffold `mise.toml` now
  groups `node` + `python` + `uv` as an **agent-runtime baseline** installed in
  every repo regardless of product stack (separate from stack-specific tools you
  prune): AI agent tooling and MCP servers run packages on demand via `npx`/`uvx`,
  so these runtimes must always be present. markitdown therefore works out of the
  box after `mise install` rather than degrading to a disconnected server.
  Documented in the scaffold README next to the GitHub MCP section.

### 2.3.0

- **Make GitHub branch protection — the real PR gate — reliable instead of a
  manual README step.** steer stays advisory in the local session (rule 95, "you
  are not the gate"); the hard wall against direct-push-to-`main` is GitHub branch
  protection, which until now was only prose in the scaffold README that a human
  set up by hand. New machine-readable policy `policy/branch-protection.yml` (bundled
  default + scaffold-installed copy, resolved consumer-first then plugin default —
  same precedence as `policy/versions.yml`) is the single source of truth for the
  required rules: a PR, 1 approval, dismiss-stale, the `ci` status check, linear
  history, no admin bypass, secret-scanning push protection. New skill
  **`/steer:protect`** reads that policy, diffs it against the repo's live settings
  via `gh api`, reports a per-rule compliant/drifted/absent table, and — only on the
  dev's explicit confirmation — applies the gap (verify-only by default; the
  privileged `gh api` write is never auto-run, no broad `gh`/`git` permission globs;
  surfaces the manual Settings steps when the token lacks admin). `/steer:init` and
  `/steer:adopt` recommend it as the final bootstrap step, `/steer:audit` routes a
  missing/drifted-protection finding to it, and the scaffold README §Branch
  protection now points at the policy + skill rather than restating the values.

### 2.2.0

- **The router is now an intent dispatcher, not a menu the user has to read.**
  `rules/00-router.md` was rewritten from a paragraph-per-condition list framed at
  the user ("New repo? → run `/steer:init`") into a directive framed at the model:
  *you are the router* — when the user describes a goal in plain language, map it to
  the owning skill and invoke it yourself, lead with a one-line heads-up, and don't
  make anyone remember a `/steer:` command. The verbose per-skill rationale (which
  duplicated each skill's own `description`/`when_to_use`) is dropped in favour of a
  compact *intent → skill* table, trimming the always-on context. **Plain language
  is now the only entry point a user needs; no command to memorize.**
- **Clarify-when-unsure, and bounded auto-continue.** The directive tells the model
  to ask exactly one compact clarifying question when intent is genuinely ambiguous
  or underspecified (rather than guessing or stalling), and — once a skill finishes —
  to continue automatically to its single recommended next action **only when that
  action is non-gated**. Human decision gates (Issue-first creation, ADR
  ratification, push / PR / merge / deploy / real secrets) still stop and wait:
  auto-routing moves *navigation*, never *authority*.
- **Non-technical owners are auto-routed into the build flow.** `rules/05-roles.md`
  now starts the guided idea→working-app flow (`/steer:build`) on PO signals with a
  one-line heads-up, instead of handing the PO a command to type.
- **New SessionStart orientation nudge — `hooks/orient-session.sh`.** On a fully
  managed spine (and only there — the unmanaged/foreign/damaged cases stay owned by
  `check-unmanaged-repo.sh`, so the two never stack), it injects a single
  high-salience line reminding the model to surface the "just say what you want"
  affordance to an unsure user. Wired into `hooks.json` for `startup` only;
  covered by new cases in `hooks/tests/run.sh`.
- **`/steer:next` now triggers on "where do I start?" / "I'm lost"**, not only
  "what should I do next?", so the cross-workflow navigator is reachable by a lost
  user's own words.

### 2.1.0

- **Prescribed, auto-maintained home for tech-stack + architecture docs — root
  `ARCHITECTURE.md`.** New scaffold template
  (`templates/scaffold/ARCHITECTURE.md`, installed at the repo root next to
  `DESIGN.md`): the engineer's system model — tech-stack table, apps/packages
  map, how-it-fits-together, cross-cutting concerns — that links to `/spec/design/`
  diagrams and `/spec/decisions/` ADRs rather than duplicating them. `/steer:init`
  fills it from the confirmed stack and `/steer:adopt` reverse-engineers it from
  the as-built code (Phase 6 inventory), both with the `DESIGN.md` "never clobber
  a populated doc" discipline, so it doesn't rot into an unfilled stub the way a
  bare `/spec/app/` can. Kept current by a new drift-gate class
  (*architecture/stack drift*) in the PR template + Definition of Done + living-docs
  rule, and an `/steer:audit` "DX & docs" check that flags the stack table or
  apps/packages map drifting from `package.json` / `mise.toml` / the real
  directories. Audience split is now explicit in the layout rule: `README.md`
  (front door) → `ARCHITECTURE.md` (how it's built) → `/spec/app/` (how to
  use/operate) → `/spec/decisions/` (why).
- **One home per template topic — `templates/github/` is now the single source
  of truth for GitHub templates.** The shipped Issue Forms, CI workflows, and PR
  template moved out of `templates/scaffold/github/` (now removed) up into
  `templates/github/`, alongside the agent-authored `issue-bodies/` that already
  lived there. The scaffold `MANIFEST.md` installs them via a new
  *GitHub templates (instantiate from `../github/`)* section — the same
  install-via-`../` pattern the spec spine already uses — so `scaffold/` no
  longer carries a second copy of template content. The Issue Forms (`.yml`,
  human capture UI) and issue bodies (`.md`, agent contract) remain distinct
  artifacts for distinct runtimes; this only removes the directory split, not
  that layering (see `reference/ISSUE-SCHEMA.md`). Path references in
  `init`/`ISSUE-SCHEMA.md` updated; the brand-leak guard
  (`check_standards.py`) now also scans `templates/github`.
- **Design-dir guidance rehomed.** `scaffold/spec/design/README.md` moved to
  `templates/spec/design-readme.md` (installed as `spec/design/README.md` via
  the spec spine), so all spec template content lives under `templates/spec/`
  and `scaffold/spec/` holds only the `features/`/`decisions/` placeholders.
- **Dropped GitHub Project (board) bootstrapping/sync.** Testing showed no real
  gain from a Project board per repo, so the optional Project overlay is removed
  in favor of clean, well-maintained GitHub Issues. Gone: the
  `/steer:issues project [bootstrap|sync]` mode, `tracker-sync`'s
  `add-to-project` operation and its `steer:state` → Project `Status` mirror, the
  `project:` and `fields:` blocks in the `tracker.md` template, the "Suggested
  Project" section of `ISSUE-WORKFLOW.md`, and the `project.owner`/`number` setup
  prompts in `init`/`adopt`. The `steer:state` issue-body marker remains the base
  source of truth; labels and the issue lifecycle never depended on Projects.
- **Priority and effort are no longer tracked.** They previously existed only as
  Project fields; with Projects gone they are not reintroduced as labels.
  `LABELS.md` and `ISSUE-WORKFLOW.md` state this explicitly.
- **`/steer:issues triage` is stronger.** The mode now keeps the backlog clean
  and correctly labelled: dedup by marker/title, label correctness for
  human-created issues (`source:*`/`needs:*`/`risk:*` + inferred `steer:kind`
  marker and Issue Type when missing), single managed comment for missing
  required info, cleanup signals (stale `needs:triage`, orphaned sub-issues,
  conflicting labels), and a `--all` sweep that emits a summary and takes one
  batch confirmation before writes. All GitHub I/O still routes through
  `/steer:tracker-sync`.
- **`publish-adoption` routing is now explicit.** The productionization template
  carries a canonical "What publishes, and where" map (gap-analysis actions →
  findings; dependency table → one upgrade finding, not per-package; bad practices
  → findings only where not already a gap row; architectural-choice *decisions* →
  `/steer:adr` or `/steer:questions`, never findings; secrets → rotate; questions
  → `/steer:questions`), and `issues/SKILL.md` states the dedup-by-work-shape
  principle (findings are not 1:1 with sections/rows/bullets) and points to it.
- **Analysis skills can no longer edit files via native tools.** `audit`, `drift`,
  and `next` declare `disallowed-tools: Edit, Write, NotebookEdit, EnterWorktree`, so
  the read-only analysis cannot mutate code or spec through the editing tools. This is
  not full immutability — Bash mutations stay governed by permissions/hooks — and the
  restriction clears on the next message, so confirmed follow-up writes (drift's
  optional `/spec/DRIFT-REPORT.md`) and `/steer:issues publish-*` still run as their own
  steps. Each skill's body now states the boundary honestly instead of only claiming
  "read-only" in prose.
- **`/plugin` picker now shows a human-readable name.** The manifest adds
  `displayName: "Steer — Engineering Standards"` (Claude Code ≥ 2.1.143); the
  invocation prefix stays `/steer:*`. A new `plugins/steer/README.md` records why
  `defaultEnabled` is intentionally omitted (org standards stay enabled by default).
- **`/steer:work` prompts less for routine git, without widening the human gate.**
  The skill now pre-approves (via `allowed-tools`) only read-only git inspection
  (`status`/`diff`/`log`/`show`/`rev-parse`), branch create/switch
  (`checkout -b`/`switch`), and the Rule-45-autonomous `git add`/`git commit`. It
  deliberately does **not** pre-approve `git push`, `gh pr create/edit/merge`,
  `gh api`, `gh workflow run`, or destructive git (`reset --hard`, `clean -fdx`,
  `branch -D`) — those keep prompting. No `gh` access is granted (tracker I/O still
  routes through `/steer:tracker-sync`). `tracker-sync` and `issues` were deliberately
  left unchanged: `tracker-sync` is MCP-first and its only `gh` reads
  (`gh auth status`, `gh issue list`) are low-volume, so pre-approval is deferred
  pending evidence it helps; `issues` never touches `gh` directly.
- **`/steer:next` now applies an explicit user-constraint precedence.** Before
  safety arbitration it drops or down-ranks candidates that conflict with a user
  constraint, by precedence: current invocation (`$ARGUMENTS` + this turn) > prior
  explicit constraints, newest first > repository defaults. Repository content
  never overrides an explicit user constraint; irreconcilable explicit constraints
  are surfaced, not silently resolved; and when a constraint removes the action
  safety precedence would otherwise pick, it says so. (A `steer-analyzer`
  delegation subagent was trialed for this in the same cycle and removed after
  interactive validation showed it never fired in practice; the precedence rule
  above is what was kept.)

### 2.0.1

- **Scaffold de-branded (client-agnostic).** The bundled
  `.github/ISSUE_TEMPLATE/config.yml` no longer ships a hardcoded
  `element-22` discussions URL — its contact link is now commented out by
  default, with init/adopt offering to point it at the team's own
  discussions/chat. The `MANIFEST.md` per-file note records this.
- **New CI guard against brand leaks in installed payload.**
  `check_standards.py` now fails if any company-specific brand (`element-22` /
  `Element 22`) appears under `templates/scaffold`, `templates/spec`, or
  `templates/reference` — the dirs copied verbatim into consumer repos. The
  marketplace org `element22llc` and repo `e22-plugins` are unaffected (no
  separator), and the retained author email in the manifests is out of scope.
- **Doc fix.** `CLAUDE.md`'s skill list named the meta-skill `steer`; it is
  `standards`, invoked `/steer:standards`.
- **Version-pin bypass marker now honors multi-segment pins.** The same-line
  `steer:allow-pin` boundary check in `check-version-pins.sh` excluded `.`, so a
  3-segment pin (e.g. `node:18.20.1`) ignored its justification marker; the
  boundary now excludes only digits while still blocking partial-major matches.

### 2.0.0

**Client-agnostic rebrand — `e22-standards` → `steer` (breaking).** The plugin is
renamed and de-branded so it can be used by any org without "Element 22"/"e22"
woven through it. The standards *content* is unchanged; this is a naming + branding
change.

- **Plugin renamed `e22-standards` → `steer`.** The plugin directory, the
  `marketplace.json` plugin entry, and `plugin.json` `name` all change. The
  marketplace id (`e22-plugins`) and the GitHub repo (`element22llc/e22-plugins`)
  are intentionally **unchanged** — install is still `…@e22-plugins`.
- **Skills drop the redundant prefix.** `/e22-standards:e22-<skill>` → `/steer:<skill>`
  (e.g. `/e22-standards:e22-init` → `/steer:init`). All 19 skill directories and
  their `SKILL.md` `name:` fields are renamed.
- **Branding neutralized.** "Element 22" / "E22" company wording in rules, skills,
  templates, scaffold, and the injected SessionStart header is replaced with
  brand-free phrasing ("engineering standards", "org-wide standards", "managed
  repo"). The authoring `owner`/`author` metadata is retained.
- **Markers, env vars, internal identifiers renamed.** HTML markers
  (`<!-- e22-standards: … -->`, `e22:modes|state|source|kind`) → `steer:` /
  `<!-- steer: … -->`; shell env vars `E22_*` → `STEER_*`; internal shell
  functions `e22_*` → `steer_*`; the CHANGELOG section heading `## e22-standards`
  → `## steer`.
- **Lint guard updated.** The command-reference check now (a) verifies every
  `/steer:<skill>` resolves to a real skill and (b) rejects any stale `/e22-*`
  reference, replacing the old bare-prefix check (skill names no longer carry a
  distinctive prefix).
- **Migration (clean break).** Existing bootstrapped repos must update
  `.claude/settings.json`: change `"e22-standards@e22-plugins": true` to
  `"steer@e22-plugins": true`, then `/plugin update` and `/clear` (or restart).
  Skill invocations change from `/e22-standards:e22-*` to `/steer:*`. See the
  "Upgrading from e22-standards" section in `README.md`.

This is a **breaking** change, released as the `2.0.0` major.

### 1.52.0

Workflow + authorization coherence — one git-authorization model and one
implementation-execution owner.

- **Single git-authorization model (commit autonomy preserved).** Rule 45 is
  unchanged — branch + local commit are autonomous; **publishing waits for the
  dev**. The contradictory "nothing is committed until the dev approves" wording
  is removed from `init` and `adopt` (SKILL + PROCEDURE); they now commit
  the bootstrap/spine as coherent units and gate only push + PR. The scaffold
  `claude/settings.json` enforces the gate: `git push` (all forms) and
  `gh pr create` / `gh pr merge` move from `permissions.allow` to
  `permissions.ask`; `git add` / `git commit` stay autonomous; force/delete/mirror
  push stay denied.
- **build orchestrates, work executes.** `build` now has two explicit
  modes: a **prototype/local** mode (the default — greenfield with no GitHub
  tracker; build the v0 locally, no per-feature issue ceremony, one v0 handoff PR)
  and a **governed** mode (repo already `system: github`) that materializes/reuses
  an issue per delivery slice and delegates each to **`/steer:work`**,
  invisibly to the PO. `work` stays the sole owner of
  claim → branch → implement → test → PR → transition; no build↔work
  recursion. `spec` handoffs point implementation at `work`
  (after `issues decompose`) or `build`, never a "just implement it" path.
- **Issue-governed branch marker.** `work` records a local
  `spec/.work/<branch>` marker (git-ignored) naming the claimed issue; the
  Stop-hook reconciliation prefers it over branch-name inference, so an
  unconventional but properly-claimed branch is recognized as governed.
- **`init` "already initialized" predicate** now tests the spine marker
  (`spec/.version` + spine files), not a bare `spec/` directory, so a foreign or
  half-migrated `spec/` routes to repair (`sync`) instead of being treated as
  done.
- `check_standards.py` gains an authorization/ownership check: Rule 45 states the
  model, init/adopt don't contradict it, the scaffold settings gate push under
  `ask`, and `build` documents both modes + delegates to `work`.

Runtime hook correctness — fixes silent-failure modes in the always-on hooks
without changing the workflow model.

- **Standards survive context compaction.** The SessionStart hook group is split
  so `inject-standards.sh` now also matches `compact` (in addition to
  `startup|resume|clear`); the drift / update / open-questions / unmanaged-repo
  notices keep their prior cadence and do **not** re-fire on compaction. Long
  sessions no longer continue without the org rules after a compaction.
- **Open-questions hook understands the structured contract.**
  `check-open-questions.sh` now parses the `### Q-NNN` blocks the current
  templates use (`status:` / `impact:` / `required_before:`) instead of only
  legacy `- [ ]` checkboxes — which silently counted nothing on real specs. It
  classifies each open question as **blocking now** vs **blocking a later
  transition** vs **non-blocking backlog** using the shared lifecycle ordering
  (`lib/lifecycle.sh`, sourced from `enums.registry`), flags **malformed** blocks
  instead of dropping them, and still detects legacy checkboxes and a retired
  `spec/SPEC-QUESTIONS.md` for one deprecation window. The bundled templates mark
  their seed question `<!-- steer:placeholder -->` so a fresh scaffold stays silent.
- **A bare `spec/` no longer counts as an initialized spine.** A new
  `lib/spine.sh` predicate keys "managed" off `spec/.version` **plus** the
  required spine files; `check-unmanaged-repo.sh` and `check-code-before-spec.sh`
  now distinguish unmanaged (no `spec/`) / foreign (`spec/` without `.version`) /
  damaged (`.version` but missing files) / managed, and route each to the right
  first move. An empty, foreign (e.g. OpenAPI), or half-migrated `spec/` stops
  silencing the bootstrap nudges.
- **Hooks work from subdirectories.** A shared `lib/repo-root.sh` resolves the
  work-tree root by walking up to the nearest `.git` (handling subdirs, worktree
  `.git`-files, and symlinked cwd), so the point-of-action and Stop hooks keep
  applying when the session cwd is `apps/web`, `infra`, etc.
- **NotebookEdit is governed like other writes.** The spec-first / issue-first
  PreToolUse matcher now includes `NotebookEdit`, and `lib/json.sh` gains
  `steer_target_path` (file_path, else notebook_path) so notebook mutations are
  classified the same as ordinary file writes.
- **Stop-hook accuracy + safety.** `reconcile-issue-first.sh` now prefers an
  explicit `spec/.work/<branch>` work marker over branch-name inference, tightens
  the issue-branch heuristic so a date branch like `release/2026-06` is no longer
  treated as issue-governed, and parses `git` output NUL-delimited
  (`diff --name-only -z` + `ls-files -z`) instead of `status --porcelain | sed`
  so renames and unusual filenames are handled safely. Its wording (and the code
  comments) now describe the `decision:block` mechanism accurately: for a Stop
  hook that is the only channel to surface a reason and it lets the model
  **continue** — it is the delivery path for a one-shot advisory, not a gate.
- Expanded the POSIX hook fixture suite (59 → 75 cases) covering the structured
  question parser + gate classification, the spine-state predicate, subdirectory
  resolution, NotebookEdit, and the tightened Stop-hook branch/marker logic.

Deterministic version governance — replaces the live-API version-pin check with a
policy file + a real CI backstop.

- **Policy is the source of truth (`policy/versions.yml`).** A static,
  version-controlled file encodes the approved major-version floors
  (`minimum_supported` / `recommended` / `denied`) for common backing-service and
  runtime images. Both the interactive hook and the CI scanner enforce it
  deterministically — **no network call, no jq** — so a build is reproducible and
  the gate never fails open for lack of a tool. (This fixes the prior behavior
  where the "hard deny" silently degraded to advisory without jq, and removes the
  endoflife.date call from the write path.)
- **The CI backstop now exists (`scripts/scan-version-pins.sh`).** A conservative
  literal-pin scanner walks a repo's infra/config/script files
  (compose/Dockerfile/mise/`.tf`/`.sh`/`.yml`) and fails the build on a pin below
  policy — catching the Bash-mediated / committed pins the interactive hook can't
  see (e.g. `docker run postgres:11`, generated Compose). It does not resolve
  variables/interpolation (no false positives), skips dependency trees, honors a
  `# steer:allow-pin <reason>` suppression, and exits `0`/`1`/`2`
  (clean/violation/config-error). Wired into the plugin CI (`mise run ci`) and
  shipped into the scaffold CI so consumer repos run it too.
- **Live EOL is separated from enforcement.** A scheduled, non-blocking workflow
  (`version-policy-refresh.yml` + `check-policy-freshness.sh`) compares the policy
  floors against upstream endoflife.date and opens an issue when they lag —
  proposing policy bumps without ever gating a build or calling the network from
  the enforcement path.
- The scaffold ships `policy/versions.yml`, `scripts/scan-version-pins.sh`, and
  the shared `scripts/version-policy.sh`; `check_standards.py` asserts the scaffold
  copies stay byte-identical to the plugin sources so consumer CI runs the same
  scanner and policy.

Consumer scaffold correctness — CI tells the truth, and bootstrapped dirs survive.

- **Stack-detection CI (replaces the contradictory "commented out" claim).** The
  scaffold `ci.yml` always runs stack-agnostic hygiene, then auto-detects the
  stack from manifests (`package.json`/`pnpm-workspace.yaml` → Node/TS;
  `pyproject.toml` → Python) and runs its checks. A detected stack with **no test
  contract fails** (no more silent `--if-present` no-op to green); with no app
  stack, only hygiene runs and the job reports that application validation isn't
  active yet. The previous file claimed to run "only stack-agnostic checks" while
  actively running Node steps — `ci.yml`, `MANIFEST.md`, and the scaffold README
  are now mutually consistent.
- **Bootstrapped dirs survive the first commit.** `spec/features/.gitkeep` and
  `spec/decisions/.gitkeep` are now bundled in the scaffold (an empty dir doesn't
  survive git); `init` installs them instead of `mkdir`-ing empty dirs, and
  `MANIFEST.md` maps them.
- **Scaffold README matches the shipped workflow.** Verification now says to
  comment `@claude` on a PR/issue (the shipped `claude.yml` is the `@claude`
  mention workflow) rather than waiting for a non-existent automatic
  "Claude Code Review" comment.

Marketplace + release integrity.

- **Dropped the custom plugin-update freshness hook.** `check-plugin-updates.sh`
  compared the marketplace clone's git HEAD against the remote — producing false
  positives (doc-only/frontend-design commits, pinned refs) and false negatives
  (clone updated but `plugin.json` not bumped → stale cache, no notice), and its
  HTTPS call was unbounded. Removed it and its SessionStart registration; rely on
  Claude Code's native plugin-update mechanism (resolved-version based).
- **Release/changelog CI gates (`scripts/check_changelog.py`).** A release
  validator (run in `mise run ci`) asserts `plugin.json`'s version equals the
  newest *released* `CHANGELOG.md` heading and that releases descend in semver
  order; a `### [Unreleased]` section is allowed above them. A PR-only behaviour
  gate asserts that any change under
  `plugins/steer/{skills,hooks,rules,templates,scripts,policy}` or
  `plugin.json` is accompanied by a `CHANGELOG.md` change (tests/ exempt).
- **Validator pinned + dual-scope.** `mise run ci` now validates **both** the
  marketplace manifest (`claude plugin validate .`) and the plugin
  (`claude plugin validate plugins/steer`). The required CI job installs a
  **pinned** Claude Code version (single source of truth: `STEER_CLAUDE_CODE_VERSION`
  in `mise.toml`) so the authoritative result can't drift without a repo change; a
  separate **non-blocking** job runs `latest` as an early compatibility signal.
- **Root README corrected.** It no longer claims the marketplace "hosts a single
  plugin" — it states `steer` plus the re-listed (not vendored, not
  auto-enabled) `frontend-design` — and the trust prompt names the real
  marketplace, `e22-plugins` (not `e22`).
- **Skill invocation matrix** documented (`templates/reference/INVOCATION.md`):
  safe-to-infer (read-only) vs. requires-explicit-intent (side-effecting) vs.
  internal-only, with the rationale for **not** broadly setting
  `disable-model-invocation` yet.

### 1.51.2

- `sync`: the sync PR now targets the branch the dev invoked the sync from
  (`BASE`, captured before branching), not the repo's default `main`. The skill
  records the checked-out branch in step 1, branches `feat/sync` off it, and
  opens the PR with `--base "$BASE"` so the sync rejoins the work it continues.
  Only when the dev runs sync from `main` does the PR target `main`. The skill no
  longer asks the dev which base to use.

### 1.51.1

- `adr`: ensure `spec/decisions/` exists (`mkdir -p`) before copying the ADR
  template, so the skill no longer fails in a repo where the dir was never
  created (e.g. an adopted repo or a cleaned tree).
- Scaffold docs: `env.example` now flags that `DATABASE_URL`'s host port must
  track `POSTGRES_PORT`; `MANIFEST.md` notes that the per-feature and
  per-decision spec templates are instantiated on demand, not at bootstrap.

### 1.51.0

Pre-pilot coherence and safety hardening — makes five workflow guarantees
consistent and executable before other developers rely on the plugin. No
lifecycle enum, tracker marker, or managed-block contract changes.

- **One canonical `draft → approved` transition.** `/steer:spec
  approve` is now marked (hidden `steer:transition-owner` comment) as the **single
  owner and only writer** of the feature approval transition.
  `/steer:build`'s PO validation gate **delegates** to it on explicit
  PO approval instead of editing the `## PO acceptance` boxes, `> Approved by:` /
  `> Approved at:`, the `Status:` flip, or the HISTORY entry itself — so approval
  authority lives in exactly one place and the approve-time validation gate
  always runs.
- **Issue-first scope made precise + a Stop-time backstop.** Rule 36 and
  `ISSUE-WORKFLOW.md` now scope the requirement to an **implementation-affecting
  mutation** (code/config/infra/behavior) and state explicitly that editing the
  `/spec` spine, docs, generated output, and lockfiles is exempt — no claim that
  *every* repository change needs an issue. A new **`Stop` hook**
  (`reconcile-issue-first.sh`) reconciles the working tree at end-of-turn and
  reports implementation-affecting changes left on a branch that does not
  reference an issue — catching **Bash-mediated** mutations the PreToolUse editor
  nudge never sees. It shares the classifier with that nudge, stays silent on
  issue branches and exempt-only changes, fires at most once per session+repo,
  and carries a `stop_hook_active` loop guard. Non-blocking and POSIX-sh,
  fail-open, no `jq`/network — it reports, it does not enforce.
- **Internal skill invocation boundaries.** `/steer:tracker-sync`
  (the GitHub tracker-metadata gateway) and `/steer:spec-scaffold`
  (template instantiation) are now `user-invocable: false` — still callable by
  Claude as orchestration helpers, but hidden from the slash menu so they don't
  compete with the high-level entry points (`issues`/`work` and
  `spec`/`build`). Router and rule prose reframed to reach them through
  the orchestrators rather than advertising them as direct commands.
- **`adopt` split for compaction resilience.** The skill's detailed
  thirteen-phase runbook moves to a co-located `PROCEDURE.md`; `SKILL.md`
  (21.6 KiB → 7.1 KiB) becomes a lean spine that hoists the **non-negotiable
  guardrails** (no fabricated ADRs, humans decide intent, never clobber working
  code, secrets are stop-and-rotate, reconcile-on-resume) to the top and maps each
  phase to its procedure — so the critical guards survive context compaction.
- **Workflow-authority fixtures.** `check_fixtures.py` gains a semantic contract
  group that fails CI if approval authority re-scatters (more than one
  transition-owner, or `build` stops delegating), the issue-first scope
  wording drifts, or the Stop reconciliation hook loses its registration or loop
  guard — protecting lifecycle *behavior*, not just vocabulary and file shape.

### 1.50.0

Audit-mitigation series tail — closes the two residual findings left after
rev. 2, plus an `build` onboarding-accuracy fix and a small reconciliation-
tooling refactor. No change to hook behavior.

- **build onboarding accuracy + shared reconciliation helper.**
  `/steer:build`'s "PO needs only Claude Code and Docker Desktop" line
  now states the PO installs those two on a *supported machine* (macOS / Linux /
  Windows-via-WSL2, per the `Stack` rule) while Claude verifies and drives the
  rest. The duplicated `comm -13 <(…)` process-substitution reconciliation
  snippet (the canonical *Template reconciliation* convention plus the
  `build`, `adopt`, and `spec-scaffold` skills) is replaced by one
  bundled POSIX-sh helper, `scripts/template-reconcile.sh` — read-only, with a
  documented contract (inputs, what it compares, exit codes) and fixture
  coverage in the hook test suite.
- **Initialization ADR status (audit F17).** `/steer:init` step 4 now
  states that the initial-stack ADR's status follows who decided: an *explicit*
  stack choice in the interactive setup is authored `Accepted` with the dev as
  named Decider + date, while a Claude-recommended default with no explicit
  choice stays `Proposed` until a named decider accepts it (generic bootstrap-PR
  approval does not ratify). Mirrors the `/steer:adopt` ADR policy into
  greenfield init, where the dev is the decider in the room.
- **Read-only write-scope precision (audit F15).** `/steer:audit` and
  `/steer:drift` reword "read-only" as **repository-read-only**: they
  propose spec changes and never edit code/spec or commit, and their only writes
  are tracker issues. Removes the tension between "routes results into /spec" and
  "never edits spec."

### 1.49.0

Audit-mitigation series (rev. 2) — corrects the spec/issue state model, removes
the legacy command shims, adds a canonical enum registry plus a standards
validation gate, formalizes the productionization lifecycle and a single
authorization authority, and hardens the point-of-action hooks.

- **Lifecycle coherence (audit F2, F3, F7, F8, F19).** Corrects the spec/issue
  state model before it is canonicalized:
  - **F2** — materialized intents are written as `Status: draft` (not
    `proposed`); only `/steer:spec approve` flips to `approved`. Prose aligned in
    `issues`, rule `30-spec-workflow`, and `ISSUE-WORKFLOW.md`.
  - **F3** — new **`/steer:spec approve <feature-id>`** subcommand with an explicit
    transition contract: `draft → approved` only (refuses to downgrade
    `implemented`/`validated`/`live`; idempotent on `approved`); an exact
    blocking-question predicate (blocking impact ∧ unresolved status ∧
    `intent-approval` gate); and structural approval evidence (`> Approved by:` /
    `> Approved at:` added to the intent template) plus one HISTORY entry.
  - **F7** — lifecycle-aware production categories replace the single "Required
    before production": **Required before initial production**, **Required before
    next production release**, and **Urgent live-system remediation**, so an
    already-live system never gets a pre-launch instruction. Updated across
    `NEXT-ACTIONS.md`, `spec`/`build`/`drift`/`adopt`/`next`,
    and the next-action fixtures.
  - **F8** — closure **reason**, not mere closure, decides the terminal state:
    new `cancelled` state added to the issue-state enum; `validate → done` only
    when closed as `completed`; `rejected`/`duplicate`/`obsolete`/`not-planned`/
    `superseded` → `cancelled`. Wired into `ISSUE-WORKFLOW.md`, `ISSUE-SCHEMA.md`,
    `work`, and `next`.
  - **F19** — **contract readiness** is a mechanically-derived signal
    (`ready | incomplete | missing`, never `approved`) defined in
    `spec-framework.md`; `/steer:issues status` and the `decompose` precondition
    share the one derivation so they cannot disagree.

- **Remove command shims; correct invocation syntax (audit F4).** A runtime
  smoke test confirmed plugin skills are invoked **only** as
  `/steer:<skill>` — Claude Code always namespaces plugin skills, so the
  bare `/e22-*` form never worked for a user. The 13 thin `commands/*.md` shims
  (which only restated skill semantics and produced the same namespaced
  invocation) are deleted, and every `/e22-*` reference across rules, skills,
  reference prose, templates, scaffold, hooks, README, and CLAUDE.md is rewritten
  to the namespaced form. CLAUDE.md's "every skill is invokable as `/<skill-name>`"
  claim is corrected. (Branch names like `feat/adopt` and tracker markers like
  `steer:state` are unaffected — they are not slash commands.)

- **Canonical enum registry + standards validation (audit "automated validation",
  F1-secondary, F5).**
  - **`templates/reference/enums.registry`** — a strict line-oriented,
    shell-AND-python-parseable file is now the single source of truth for every
    controlled vocabulary (feature status, question status/impact,
    required_before, issue kind/state/source, ADR status, next-action category).
    **`ENUMS.md`** documents them for humans; CI asserts the two agree.
  - **`scripts/check_standards.py`** (wired into `mise run check`/`ci`) adds eight
    semantic checks: when_to_use formatting (a restricted-grammar check, *not* a
    YAML parse — F1-secondary); bidirectional declared-mode markers
    (`<!-- steer:modes … -->` ↔ argument-hint ↔ body ↔ cross-references);
    `commands/` is gone; every `/e22-*` reference is namespaced and resolves to a
    real skill; every Status/state/source/required_before/next-action token is a
    registry member (the deprecated "Required before production" is forbidden);
    MANIFEST sources exist; README skill inventory is complete; cross-field
    invariants. `check_fixtures.py` now derives its category/state sets from the
    registry too (no drift).
  - **F5** — README skill inventory completed (adds `issues`, `work`,
    `spec`, `next`, `sync`, `tracker-sync`), grouped by area.
  - `check_plugin.py` loses its now-dead `commands/` handling; the live plugin
    passes the full gate (`mise run check`) and the expanded test suite.

- **Productionization lifecycle + single authority rule (audit F6, F16).**
  - **F6** — `productionization.md` gains a parseable `> Lifecycle:` field
    (`active-adoption` → `published-snapshot` → `superseded`, with
    `> Published findings:` / `> Superseded by:` pointers). `/steer:adopt`
    writes `active-adoption`; `/steer:issues publish-adoption` is
    **partial-publication safe** — it flips to `published-snapshot` only after
    *all* intended findings are filed, else stays `active-adoption` and records
    the published refs (rerun reconciles by `finding-key`, never duplicates).
    `/steer:next` and `/steer:questions` honor the field:
    a `published-snapshot` brief's checkboxes are historical evidence, not active
    work.
  - **F16** — one labelled **Authorization & confirmation** block in
    `ISSUE-WORKFLOW.md` is the single source for when an agent acts without asking
    vs confirms (explicit request → no ask; bulk finding-publish → one batch
    confirmation; unsolicited idea → confirm before external publish;
    managed-block update in an active workflow → no repeat). `/steer:issues`
    now references it instead of restating the semantics.

- **Hook hardening + fixture suite (audit F9–F13).** The three `PreToolUse` hooks
  are rebuilt on two shared POSIX-sh libraries and gain a deterministic fixture
  suite, so hook behaviour is defined by tests rather than asserted in prose.
  - **Shared field extraction (`hooks/lib/json.sh`, F11).** One best-effort
    extractor replaces the hooks' ad-hoc `sed` field grabs: `jq` when present, else
    a narrow grep/sed fallback that tolerates escaped quotes/backslashes and picks
    the *first* `tool_input` field, so a value buried in a later `content` string
    cannot shadow the real one. Adds tool-aware `steer_mutation_content` (the new
    text a Write/Edit/MultiEdit introduces).
  - **Shared path classifier (`hooks/lib/classify.sh`, F9/F10).** One classifier
    (spec / documentation / implementation / operations / generated / lockfile /
    unknown) is shared by both point-of-action nudges, so they can no longer
    disagree about what a path *is*; coverage broadens past the old source-code
    allowlist so config/infra writes (compose, Dockerfile, `*.tf`, CI workflows, …)
    now nudge, while spec/docs/generated/lockfiles stay exempt.
  - **Three-tier version-pin policy (F12).** `check-version-pins.sh` no longer
    denies every older major. It reads endoflife.date per cycle: a cycle past its
    EOL (date in the past, or `eol: true`) is **denied**; a still-supported cycle
    behind current stable gets a non-blocking **advisory**; the latest stable (or
    newer) is **silent**. EOL responses are cached per slug per UTC day (atomic
    write; failures never cached), and the date comparison is portable POSIX
    (`sort`, not the `<` operator that `test` leaves undefined).
  - **Tool-aware content inspection (F13).** Only the *introduced* text is checked
    — `Write.content`, `Edit.new_string`, every `MultiEdit` `new_string` — never
    `old_string`, so bumping an image tag upward is not blocked by its old value;
    Bash command text is intentionally skipped (documented bypass; the CI repo-scan
    is the backstop).
  - **Fixture suite + CI wiring (`hooks/tests/run.sh`).** 42 hermetic cases assert
    each hook's decision (deny / advisory / silent) plus the extraction and
    classification helpers, stubbing the network via `STEER_EOL_FIXTURE_DIR`. Wired
    into `mise run ci` as the new `hooktests` task, and the `shell` lint gate now
    also covers `hooks/lib` and `hooks/tests`.

### 1.48.0

- **New `/steer:next` — read-only workspace navigator.** Delivers the cross-workflow
  arbitrator that 1.47.0 deferred. Where each workflow skill's
  `## Recommended next actions` block is locality-bound (it recommends only from
  its own invocation), `/steer:next` is the one tool that reconstructs the **whole
  workspace state cold** and arbitrates the single best action across *unrelated*
  workflows.
  - **Reconstructs** branch/PR + CI/merge state, `/spec` feature `Status`, open
    questions (`impact`/`required_before`), `Proposed` ADRs, tracker issue
    lifecycle states (via `/steer:tracker-sync`, MCP-first/`gh` fallback), work
    claims (`steer:state`/`steer:branch`), and `spec/.version` drift — then emits a
    state-reconstruction summary plus the standard `## Recommended next actions`
    block ending in one `Current recommended action`.
  - **Reuses, never forks, the contract** in `templates/reference/NEXT-ACTIONS.md`
    (same five categories + shared safety precedence). It carries its own
    workspace-level dimension table and defers *how* to resolve each state to the
    owning skill (`/steer:work`, `/steer:spec`, `/steer:questions`, …); it never edits,
    commits, publishes, merges, or advances state. No `/spec` spine → the only
    action is bootstrap (`/steer:init`/`/steer:adopt`).
  - **New `templates/reference/next-fixtures/`** — prose golden scenarios (not
    executable) pinning the cross-workflow arbitration: secret > PR review,
    blocking question > ready work, stale-reconcile > new work, the human-decision
    tie-break, release-gating > optional bookkeeping, all-clean, and the
    no-spine short-circuit.
  - Wired into the router (`00-router.md`) and surfaced as the `/steer:next`
    command; the 1.47.0 "not yet built" forward-reference in `NEXT-ACTIONS.md` now
    points at the shipped navigator.

### 1.47.0

- **Standardized "Recommended next actions" handoff.** Every major workflow now
  ends with a deterministic, read-only `## Recommended next actions` block that
  derives the next step from observed repo/spec/tracker state — so a workflow
  reconnects its artifacts to the next human or agent action instead of just
  stopping.
  - **New shared convention** `templates/reference/NEXT-ACTIONS.md` owns all the
    shared logic: the five categories (`Blocking now`, `Human decision required`,
    `Required before production`, `Recommended`, `Complete`), a two-level
    precedence (universal safety + skill-local lifecycle), the derivation rule
    (reuse existing state enums; never "always run X"), the output format, and the
    **read-only + locality** rules. The canonical field is `Current recommended
    action` (an *action*, not a command); a `Suggested command` is offered only
    when a real command applies, and `No action is currently required.` is allowed.
  - **New `templates/reference/next-actions-fixtures/`** — prose golden scenarios
    (not executable) that pin the intended arbitration and guard against drift.
  - **Wired into ten skills**, each with its own domain state→action table:
    `/steer:adopt`, `/steer:audit`, `/steer:spec`, `/steer:work` (Phase 1) and
    `/steer:build`, `/steer:drift`, `/steer:questions`, `/steer:init`, `/steer:sync`,
    `/steer:issues`, `/steer:adr` (Phase 2). `/steer:audit` keeps its boundary (routes
    *potential* concerns to specialists; only a confirmed secret is a stop), and
    `/steer:work` post-merge reconciliation is owned by `resume` (no redefinition of
    `finish`).
  - A repo-wide `/steer:next` navigator that arbitrates across unrelated workspace
    state is intentionally **deferred** to a later release.

### 1.46.0

- **Backlog producers — findings flow into the backlog.** Closes the loop so the
  backlog is fed from every source, not just PO capture.
  - **`/steer:issues publish-adoption`** — reconciles selected
    `spec/PRODUCTIONIZATION.md` gaps into `kind=finding` + `source:adoption`
    issues (stable `finding-key`; reconcile, don't duplicate). After publication
    the **GitHub issue is canonical** for ownership/lifecycle/closure;
    `PRODUCTIONIZATION.md` stays an assessment snapshot + evidence source that
    records the issue ref but does not track its status. Pointer added to
    `/steer:adopt`.
  - **`/steer:issues publish-findings --source code-review|security-review`** —
    files `kind=finding` issues with the matching `source:*` from a review pass.
    **Security findings redact secrets / exploit detail** and default to human
    review before public disclosure. Pointer added to `/steer:audit`.
  - **CI-failure policy** in `ISSUE-WORKFLOW.md` — transient → none; reproducible
    on the default branch → create/reconcile a `bug` with `source:ci` (stable
    key); recurring flake → one keyed issue; PR-specific → comment on the PR
    unless it outlives the PR.
  - (Implementation-discovered work and the closed `steer:kind`×`source` taxonomy
    were already established in 1.44.0 / 1.43.0.)

### 1.45.0

- **Repository bootstrap for the issue-first backlog.** Makes a GitHub-adopted
  repo actually carry the contract: real Issue Types, an existing label
  taxonomy, a Project owner, and honest Project-bootstrap claims.
  - **Issue Forms set the GitHub Issue Type** — `bug.yml` → `type: Bug`,
    `feature.yml` → `type: Feature`, `product-question.yml` → `type: Task`;
    `improvement.yml` sets no Type (classified at triage into Feature/Task/Bug).
    Dropped the duplicate `bug`/`feature` kind labels; reconciled `source:po` →
    `source:human` to match the canonical `steer:source` vocabulary.
  - **`/steer:issues bootstrap-labels`** (new) — idempotently creates/reconciles the
    canonical `source:*` / `needs:*` / `risk:*` set (`gh label create --force`)
    so form and agent labels actually apply (GitHub silently drops a label that
    doesn't exist). The canonical list lives in `templates/reference/LABELS.md`.
    `/steer:init` and `/steer:adopt` now run it when the tracker is GitHub Issues.
  - **`tracker.md` gains `project.owner`** (Project numbers are owner-scoped) and
    documents the `Status`-mirrors-`steer:state` relationship; the `labels:` map is
    reconciled to the canonical `source:*` vocabulary.
  - **Project bootstrap is honest** — `/steer:issues project bootstrap` creates/
    reconciles fields + options and **outputs manual view-creation instructions**
    (`gh` has no saved-view API) rather than claiming to have created views.
    `sync` is specified deterministically: discover field/option IDs from names
    at runtime, add the issue if absent, mirror `steer:state` → `Status`, report
    missing/renamed fields, and degrade when the `project` scope is missing.

### 1.44.0

- **Local execution workflow — issue-first routing and the `/steer:work` skill.**
  Builds on the issue contract (1.43.0) to make the local, issue-first model
  operational. `/steer:issues` owns the backlog; the new `/steer:work` owns execution.
  - **New always-on rule `36-issue-first`** — in a GitHub-adopted repo
    (`system: github`), every code/config/infra/behavior change has a GitHub
    issue before the first repository mutation; explicit fix/implement/add
    requests create without confirmation, capture-only/ambiguous language does
    not. Scoped to GitHub-adopted repos; non-GitHub and pre-`/spec` repos keep
    today's flow.
  - **Router** now sends bare issue work ("work on #123", "fix #123", "implement
    #123 and #124") to `/steer:work`, and unissued mutations through find-or-create
    then `/steer:work`; capture-only → `/steer:issues capture`, backlog list →
    `/steer:issues status`.
  - **New `/steer:work` skill + command** — `start` / `resume` / `status` /
    `finish` with distinct, idempotent semantics: validate → claim (refusing to
    override a conflicting claim/branch) → branch (repo convention, else
    `issue/<n>-<slug>`) → load specs → implement → test → update the managed
    block → open the PR → transition. Completion is explicit (PR opened →
    `validate`, never `done`); one branch/PR per issue by default; discovered
    out-of-scope work becomes a separate linked issue. A CLI implement request
    authorizes local edits + tests; commit/push/PR follow autonomy rules;
    merge/deploy are never implied.
  - **`/steer:tracker-sync` is now the generic tracker-metadata gateway** — adds
    `search`/`get`/`find-or-create`/`create`/`update`/`comment`/`set-type`/
    `label`/`transition`/`assign`/`link-parent`/`link-pr`/`close`/`add-to-project`
    as the single low-level layer `/steer:issues` and `/steer:work` call. The boundary
    is tracker metadata only — **git and PR delivery are not gateway operations**.
    `set-type` degrades when org Issue Types are unavailable. Fixed the tracker
    detection to read the `system: github` frontmatter key (not the old
    `System: GitHub Issues` prose).
  - **Intent-aware confirmation** replaces the blanket "creating issues is
    outward-facing → confirm" in `/steer:issues` and `/steer:tracker-sync`.
  - **Definition of Done, End of session, and Commit autonomy** updated for the
    issue-first model (issue exists before first mutation; `steer:state` reflects
    reality; PR references the issue; discovered work filed separately).
  - **New safety-net hook `check-issue-before-mutation.sh`** — a non-blocking,
    once-per-session POSIX-`sh` nudge (no `jq`) that fires on the first
    source-code write in a `system: github` repo. Primary enforcement stays in
    routing + skills.

### 1.43.0

- **Issue contract v2 — the schema groundwork for an issue-first, local-first
  backlog.** This is the normative-contract PR; no rule or skill behavior depends
  on it yet (routing, `/steer:work`, and bootstrap land in following changes). The
  machine-readable issue format in `ISSUE-SCHEMA.md` and the lifecycle in
  `ISSUE-WORKFLOW.md` now describe a backlog where every repository mutation has
  a GitHub issue first.
  - **Closed `steer:kind` enum** — `feature · bug · task · finding · spec-question ·
    spec-drift · audit-run`. The former `audit-finding` kind is replaced by a
    generic `finding` keyed by `finding-key` + `steer:source`; parsers still accept
    `audit-finding` as a prior alias and migrate it.
  - **New canonical markers** — `steer:state` (base lifecycle source of truth, with
    a Project field mirroring it when enabled), `steer:source` (canonical origin;
    the `source:*` label is derived), `steer:dedupe-key` (generic conceptual
    identity), plus optional `steer:claimed-by` / `steer:branch` / `steer:pull-request`.
    `steer:schema` is bumped to `2` and documented as the schema-version marker
    (no second marker introduced — one source of truth).
  - **Marker requirement matrix** — which markers are required for agent-created
    vs human issues before/after first agent touch.
  - **Lifecycle is a closed enum with per-kind readiness** — `inbox · exploring ·
    ready-for-spec · ready-for-dev · in-progress · validate · blocked · done`
    (no standalone `ready`). Bugs/tasks/deterministic findings skip the spec
    gates; questions/drift need a human decision first. Completion is explicit:
    opening a PR → `validate`, never `done`; `done` ⇔ a closed issue; a PR closed
    without merge returns to `in-progress`/`blocked`; `blocked` is reachable from
    any non-terminal state and returns to the prior state.
  - **Concurrency-safe managed-block protocol** — re-fetch-before-write, recompute
    once on a detected change, stop and report on a second change, never overwrite
    unseen edits; duplicate/malformed blocks **fail closed** (body unchanged +
    proposed repair). Original human Issue-Form content is immutable — agents
    append a managed block, never rewrite form responses.
  - **Taxonomy table** — GitHub Issue **Type** × `steer:kind` × `source:*` as three
    orthogonal axes, with capability degradation when org-level Issue Types are
    unavailable (continue on `steer:kind`, no duplicate kind-labels).
  - **Exact-only deduplication** — explicit `#N` → `finding-key` → `feature-id`+kind
    → `question-id` → `dedupe-key` auto-reuse; semantic title search yields
    candidates only; searches all states, scoped to the current repo; multiple
    exact matches stop and report.
  - **New/updated body templates** in `templates/github/issue-bodies/` —
    `feature`, `bug`, `spec-question`, `generic-task`, and `finding` (migrated
    from `audit-finding`); existing templates carry `steer:state`/`steer:source` and
    `schema=2`. **Normative conformance fixtures** added under
    `templates/reference/fixtures/managed-block/` (paired input/expected — not a
    test runner). Fixed the stale `../github/issue-forms/` link to the real
    `../scaffold/github/ISSUE_TEMPLATE/` path.

### 1.42.0

- **`/steer:adopt` no longer manufactures ADRs from inference.** Adoption used to
  reverse-engineer an `Accepted` ADR for each hard-to-reverse as-built choice —
  inventing the context, "alternatives considered," and approval status from the
  code alone. The code proves a choice *exists*, not *why* it was made or that
  anyone ratified it, so this could silently launder a standards violation (e.g.
  raw SQL stamped `Accepted` while the same run flagged it as a gap) into an
  approved exception.
  - **Governing rule: no ADR from inference.** Step 6 now *inventories* as-built
    architectural choices as **facts + evidence + conformance + disposition + a
    decision candidate** in `PRODUCTIONIZATION.md`. An ADR is authored only when a
    **human makes an explicit forward decision** during adoption (retain, replace,
    rewrite, reject), and stays `Proposed` until a named decider accepts it —
    generic adoption-PR approval does not ratify it.
  - **New `PRODUCTIONIZATION.md` section** — *Architectural choices requiring
    decision* — preserves choices the gap table doesn't capture (auth model,
    tenancy, deployment platform, db engine, …) without fabricating rationale.
  - Updated `skills/adopt/SKILL.md`, `commands/adopt.md`, and
    `templates/spec/productionization.md` (the adoption-progress checklist + the
    new section). `audit` remains the defense-in-depth net that later flags
    architectural choices still lacking an ADR.

### 1.41.0

- **Skill discovery metadata.** Frontmatter housekeeping across all skills — no
  workflow-body changes.
  - **`when_to_use` split.** Separated each skill's capability `description` from
    its automatic-invocation triggers using the supported `when_to_use`
    frontmatter field, across all 17 skills. Cleaner classification; the combined
    `description` + `when_to_use` stays under Claude Code's 1,536-char listing cap.
  - **Removed nonexistent aliases.** Dropped `/e22-idea` and `/e22-prototype` from
    `build`'s metadata — they were never real commands (skill command names
    are structural, derived from the directory, not from prose).
  - **`argument-hint` autocomplete.** Added `argument-hint` to the arg-taking
    skills (`build`, `spec`, `spec-scaffold`, `issues`,
    `tracker-sync`) using their actual accepted argument values.

### 1.40.0

- **GitHub Issues lifecycle — Phase 3: reconciliation and Projects.** Completes
  the integration on top of Phases 1–2 (v1.38.0, v1.39.0).
  - **Reconciling audit.** `/steer:audit` now defines the full cross-run lifecycle:
    findings are keyed by a stable, never-line-based **`finding-key`** (the
    conceptual defect) with a separate **`evidence`** fingerprint for the observed
    lines, so moving code updates evidence rather than forging a new finding.
    Re-runs reconcile — same key → update; gone → comment + close; changed →
    update evidence; new → create; false positive → stays closed. Auto-close is
    gated by a confidence rule (**`resolution_mode: deterministic`** may
    auto-close; **`reviewer-confirmed`** judgment calls need a human yes).
    **Audit-run records are immutable history** — one per run (`audit-id`), never
    re-edited. Schema + `audit-finding` template gain the `evidence` marker.
  - **Repo-wide reconcile.** `/steer:issues reconcile --all` sweeps the spine +
    tracker and reports every disagreement (dangling refs, closed-feature/open-
    issue mismatches, approved specs missing a tracker ref, drift issues that no
    longer reproduce, parentless sub-issues, stale `Status` after merge, closed
    question issues with a still-`open` `Q-NNN`). Bounded single-issue reconcile
    stays the Phase 2 behavior.
  - **Optional Projects.** New `/steer:issues project [bootstrap|sync]` creates the
    recommended fields/views and sets item field values via `gh project`, gated
    on `project.enabled` in `tracker.md` and **degrading gracefully** when
    Projects / org-level issue fields (public preview) are unavailable — the base
    lifecycle never depends on them.
  - **Sub-issue fallback** is explicit in `decompose`: native GitHub parent/
    sub-issue links when available, else `Parent: #N` + `<!-- steer:parent-issue=N -->`
    and a generated checklist.

### 1.39.0

- **GitHub Issues lifecycle — Phase 2: the `/steer:issues` orchestrator + safe local
  lifecycle.** Builds on the Phase 1 contracts (v1.38.0).
  - **New skill `/steer:issues`** — the PO-facing lifecycle workflow above the
    low-level `/steer:tracker-sync` gateway. A **thin orchestrator**: delegating
    modes (`brainstorm`/`materialize` → `/steer:spec`, `publish-audit` →
    `/steer:audit`, `publish-drift` → `/steer:drift`) and net-new modes (`capture`,
    `triage`, `decompose`, `status`, bounded `reconcile #issue|feature-id`). All
    GitHub reads/writes route through `/steer:tracker-sync`; issue updates touch
    only the `steer:managed` block; creates are idempotent (find-by-marker).
    `materialize` sets `Status: proposed` only — approval stays a separate
    explicit step; `decompose` requires an approved intent unless `--prototype`.
    Ships a `/slash` alias.
  - **`/steer:spec validate [feature-id|--all]`** — a local, GitHub-independent
    structural check over the open-question contract: open blocking question in
    an approved intent, deferred missing `owner`/`required_before`, closed-issue
    but still-`open` question, promoted-without-ref, resolved-without-resolution.
    Runs at `/steer:spec approve` (a blocking question **blocks approval**) and is
    called by `/steer:issues` and `/steer:drift`. Defense in depth: correctness holds
    even when the tracker is unreachable.
  - **Question-reconciliation floor** — enforced from this release so the
    per-feature lifecycle can't silently lose a promoted-then-answered question
    before implementation proceeds on stale intent.
  - **Wiring.** `/steer:audit` now emits the two-level audit-run + finding-key
    children; `/steer:drift` emits decision-checklist `spec-drift` bodies and
    reaffirms it never auto-resolves; `/steer:questions` applies the keep-vs-promote
    test, keeps the structured `Q-NNN` and sets its `tracker:` field on promotion;
    `/steer:spec` gates approval on `validate`. The router lists `/steer:issues`.

### 1.38.0

- **GitHub Issues lifecycle — Phase 1: contracts and scaffold.** Lays the
  machine-readable foundation for an issue-driven product lifecycle, ahead of the
  `/steer:issues` orchestrator skill (Phase 2) and repository-wide reconciliation
  (Phase 3).
  - **Machine-readable issue contract.** New `templates/reference/ISSUE-SCHEMA.md`
    defines hidden identity markers (`steer:schema`, `kind`, `feature-id`,
    `finding-key`, `audit-id`, …), stable section headings, **managed-block
    boundaries** (`<!-- steer:managed:start/end -->` so agent updates never clobber
    human edits), idempotency rules, and a schema-compatibility policy.
  - **Lifecycle reference.** New `templates/reference/ISSUE-WORKFLOW.md` owns the
    capture → brainstorm → validate → materialize → shape → implement lifecycle,
    the `Status` state model + **authority table** (which transitions an AI may
    propose vs perform), the small label taxonomy (`source:*`/`needs:*`/`risk:*`),
    issue types, and optional GitHub Project field/view guidance.
  - **Structured open questions.** `spec-framework.md` now defines a normative
    machine-readable question format — stable `Q-NNN` IDs with
    `status`/`impact`/`owner`/`required_before`/`tracker` — plus the
    `/steer:spec validate` contract (the GitHub-independent floor that blocks an
    approval while a blocking question is open). Adopted in the `feature-intent.md`
    and `vision.md` templates.
  - **Agent issue-body templates** (plugin-internal, not installed):
    `templates/github/issue-bodies/{audit-run,audit-finding,spec-drift,technical-task}.md`,
    each managed-block-wrapped with identity markers — including the stable,
    never-line-based audit `finding-key`.
  - **YAML Issue Forms.** The bundled scaffold's Markdown issue templates are
    replaced by PO-friendly forms (`feature.yml`, `bug.yml`,
    `product-question.yml`, `improvement.yml`); forms are human UI only — agents
    render the same semantic fields into the issue contract, never submit a form.
  - **`tracker.md` frontmatter.** A deterministic config block (system,
    repository, ref format, optional `project`/`workflow`/`labels`/`fields`) with
    **safe unset defaults** — no fabricated repository or project number.
  - **Wiring.** Rules `35-issue-tracker` (keep-vs-promote, names `/steer:issues`)
    and `30-spec-workflow` (capture-first → materialize path) updated; `MANIFEST`
    and a `MIGRATIONS` ledger entry cover the form swap + frontmatter splice for
    existing repos via `/steer:sync`.

### 1.37.1

- **Docs: de-dup open-questions placement between reference files.** The
  `intent.md`-vs-`vision.md` placement rule for `## Open questions` was stated in
  both `spec-framework.md` (canonical, under Structure) and re-derived in
  `TRACEABILITY.md`'s routing table. The routing-table row now points to
  `spec-framework.md` instead of restating the split, keeping a single source of
  truth. No behavior change.

### 1.37.0

- **New skill `/steer:spec` — brainstorm a feature spec without building it.** The
  no-build counterpart to `/steer:build`: it scaffolds the feature spine, drives
  the intent interactively (problem → users → outcome → acceptance criteria),
  sweeps open questions to resolution, and **stops at an approved intent**. Its
  defining guardrail is that it never creates or edits anything under `/apps` or
  `/packages` — if asked to build, it points to `/steer:build` rather than crossing
  the line. Fills the gap where the only way to "just think about the spec" was
  to chain `/steer:spec-scaffold` + `/steer:questions` while dodging `/steer:build`.
- **New skill `/steer:tracker-sync` — GitHub Issues pull/push for the `/spec`
  spine.** Removes the manual copy-paste at the tracker boundary. **pull**
  materializes issues as the one-file-per-issue markdown export `/steer:drift`
  consumes (and can import a ticket's acceptance criteria into an `intent.md`);
  **push** files the `spec-drift` issues `/steer:drift` previously only *described*,
  promotes `## Open questions` to issues (swapping in the ref), and opens
  feature-request issues from an approved intent. Integration is **MCP-first**
  (the GitHub MCP server already shipped in `scaffold/mcp.json`), falling back to
  the **`gh` CLI**, then to **manual export** — and it stays a GitHub-only
  accelerator: a non-GitHub tracker (Jira/Linear/…) keeps the manual export path.
  Pushes are idempotent and confirmed once before creating. It moves *pointers
  and findings*, never the spec itself — `/spec` remains the source of truth.
- **Wiring.** `/steer:drift` now offers `/steer:tracker-sync pull` instead of pasting
  (GitHub trackers) and hands its findings to `push`; `/steer:questions` delegates
  question-promotion to `push`; rule `35-issue-tracker` notes the accelerator;
  the router (`00-router`) lists both new skills. Both ship `/slash` aliases.

### 1.36.0

- **`/steer:questions` resolves settled answers in the same change instead of
  asking per item.** The skill folded *every* answer back into the spec only on
  an explicit yes — including code-facts it had just grounded from the code and
  decisions the human had already made in the session — so a sweep stalled on a
  string of "shall I apply this?" confirmations for edits that decided nothing
  new. Step 6 is now tiered: an answer that **makes no new decision** (a
  code-fact, or a decision already made) is applied in the same change — along
  with the docs that must stay consistent with it, like a `CLAUDE.md` one-liner
  or a superseding ADR — with the **PR as the gate**; only a **genuine unmade
  decision** (product/policy/architecture, or anything high-risk) is routed for
  a yes, and an unanswerable one still stays open rather than being guessed.
- **New org rule: *applying a decision already made is not a new decision*
  (`32-living-docs`).** Propagating a settled choice into the artifacts that
  should reflect it is living-docs upkeep — make the edit in the same change and
  let the PR (rule `95-not-the-gate`) be the gate. Pausing for a yes is reserved
  for an *unmade* decision, a high-risk area, or an edit that would clobber
  filled-in content. The read-only audits (`/steer:drift`, `/steer:audit`) and the
  anti-clobber sweeps (`/steer:sync`, `/steer:tidy`) are unchanged.

### 1.35.1

- **`/steer:questions` now reliably retires a legacy `SPEC-QUESTIONS.md`.** The
  skill already intended to migrate the retired standalone file into the spine
  and delete it before sweeping, but the instruction was weak enough that a run
  could treat `SPEC-QUESTIONS.md` as a live working store — answering questions
  in place and deferring the file's retirement to "a later step," leaving it on
  disk. Step 1 is now a hard gate: migration and deletion happen together,
  unconditionally, before any answering; keeping the file alive (updating it in
  place, parking resolved/deferred items in it, or deferring retirement) is
  explicitly forbidden. Added a "Done when" backstop: a run that leaves the
  legacy file behind is not done.

### 1.35.0

- **New `/steer:sync` skill — carry an already-bootstrapped repo forward to the
  current plugin.** `/plugin update` refreshes the plugin, but the `/spec` spine
  and bundled scaffold a repo *materialized* at bootstrap stay frozen at the
  version that wrote them. `/steer:sync` closes that gap: it applies pending
  structural migrations, runs the additive Template reconciliation across the
  materialized spine + scaffold, and re-stamps the spine version — read-then-
  propose, never clobbers, lands a `feat/*` PR. It is the
  repo-structure-vs-plugin-conventions axis, distinct from `/steer:drift`
  (spec-vs-tracker) and `/steer:audit` (code-vs-standards). Has a `/steer:sync`
  command alias.
- **Spec-spine version stamp (`/spec/.version`).** `/steer:init` and `/steer:adopt`
  now write the plugin version they bootstrapped at; `/steer:sync` reads it,
  applies migrations newer than it, and re-stamps. Resolved from `plugin.json`,
  never memory.
- **Migration ledger (`templates/reference/MIGRATIONS.md`).** Single source of
  truth for **non-additive** structural changes (renames/moves/deletions) the
  purely-additive Template reconciliation can't express. Each entry is keyed by
  introducing version and is idempotent + self-detecting (precondition + action).
  Seeded with the v1.22.0 `PRODUCTION-READINESS.md` → `PRODUCTIONIZATION.md`
  rename, which `/steer:adopt` previously hard-coded inline; adopt and build now
  delegate to the ledger so future renames need no skill edits. The
  spec-framework reconciliation convention documents the additive-vs-structural
  split and the stamp.

### 1.34.0

- **The plugin replaces `repository-template` as the bootstrap source.** The
  full repo scaffold is now **bundled** at `templates/scaffold/` (mise.toml +
  standard tasks, compose.yaml, CI + `@claude` workflows, PR/issue templates,
  configs, `.env.example`, `.claude/settings.json`, editor config, infra
  conventions — dotfiles stored without the leading dot; `MANIFEST.md` carries
  the install map and per-file adapt notes). `/steer:init` Path B and
  `/steer:adopt` step 10 now instantiate from this bundle instead of fetching
  `element22llc/repository-template`; `/steer:init` Path A is reframed as the
  *legacy-fork* path and back-fills the new artifacts. The spec spine templates
  (`vision`, `users`, `glossary`, `design-source`) moved into `templates/spec/`
  alongside the per-feature ones. The starter app is deliberately **not**
  bundled — bootstrap scaffolds the real first app. README gains
  bootstrap-with-the-plugin + migration-from-the-template sections.
- **Living documentation is now an always-on rule (`32-living-docs.md`).**
  Claude's natural-language-to-spec role is explicit: the PO/dev speaks plainly;
  Claude routes each statement to its owning artifact *as the work happens*
  (intent/acceptance → `intent.md`, decisions/trade-offs → `contract.md`/ADR,
  ambiguity → `## Open questions` — never guessed, usage/roles/config →
  the app guide, what/why/who-asked → action history) in the same PR as the
  code, in the right register per audience (PO plain-language, dev precise).
- **New `/spec` artifacts, all template-backed (`templates/spec/`):**
  `/spec/HISTORY.md` (**action history** — append-only what/why/who-asked/refs
  log for auditability, onboarding, review evidence, and drift-over-time;
  `history.md`), `/spec/tracker.md` (**client-agnostic issue-tracker
  declaration** — Jira/GitHub Issues/Linear/Azure DevOps/other; `tracker.md`),
  and `/spec/app/README.md` (**app knowledge docs** — usage, workflows, roles &
  permissions, configuration, limitations, troubleshooting, runbook, release
  notes; `app-docs.md`). `feature-intent.md` gains a `> Tracker:` header line
  and tracker-agnostic issue-ref guidance. Layout rule and spec-framework
  structure updated to match.
- **Issue-tracker integration is an always-on rule (`35-issue-tracker.md`).**
  Only `/spec/tracker.md` knows which tracker is in use; specs/PRs/history
  write refs in its declared format. Tracker-item acceptance criteria are
  copied into the intent (repo stands alone; ref points back); untracked
  questions live in `## Open questions` and are promoted to tracker items when
  they need scheduling.
- **Pre-merge drift gates (`55-drift-gates.md`) + PR-template checklist.**
  Eight review-sensitive classes — intent drift, contract drift, undocumented
  behavior change, security-sensitive, compliance-impacting, operational,
  local-setup/deployment, app-docs invalidation — must be flagged in the PR
  when noticed and block merge until the human reviewer explicitly resolves
  them (Claude may not waive its own flag). The scaffold's PR template carries
  the checklist plus a living-docs sync section; Definition of Done and the
  end-of-session checklist gain matching items.
- **Audit-aligned delivery rule (`75-compliance.md`).** The workflow is SOC 2 /
  ISO 27001-**aligned** — explicitly *not* a compliance claim — mapping the
  artifacts to traceability, review evidence, change history, access-conscious
  defaults, and human accountability (PO approves intent; dev approves the PR;
  humans own production readiness).
- **New `/steer:traceability` skill + `templates/reference/TRACEABILITY.md`.**
  The full prose behind the four new lean rules: the NL→artifact routing
  table, extraction discipline, PO-facing vs dev-facing register split, action
  history format, app-docs conventions, the tracker adapter table, drift-gate
  mechanics, the SOC 2 / ISO 27001 expectation→artifact evidence map, and
  worked PO-day/dev-day examples. Registered in the router; the `steer`
  loader skill's rule list updated (17 → 21 files).
- **`/steer:build` bootstraps and documents like the rest of the flow.** Step 1
  now covers the no-scaffold case (plugin-driven bootstrap, PO-adapted), and
  handoff seeds the app guide from the demo-validated intents and appends the
  build to `/spec/HISTORY.md`. `check-unmanaged-repo.sh`'s nudge names the
  bundled scaffold and the living-docs spine.

### 1.33.0

- **New `/steer:audit` skill — a repeatable, read-only, whole-repo health audit.**
  Until now the standards had a one-time onboarding triage (`/steer:adopt`), a
  spec-vs-spec conformance check (`/steer:drift`), and diff-scoped reviews
  (`/code-review`, `/security-review`, `/simplify`) — but nothing that sweeps an
  already-adopted, steady-state repo across the standards dimensions and returns a
  **leverage-ranked** cleanup backlog. `/steer:audit` fills that gap. It audits nine
  dimensions anchored to the baseline (spec coverage, architecture &
  boundaries, data layer, input validation & config, error handling & escape
  hatches, testing, toolchain & dependency health, design consistency, DX & docs),
  **vets** every candidate finding against the cited `path:line` (subagents
  over-report), ranks survivors by leverage (impact ÷ effort × confidence), and
  routes results into the existing flow: `audit` issues for code-health findings,
  `/steer:adr` for architectural calls, `## Open questions` for spec gaps. It is
  **read-only** — no code/spec edits, no commit — and **defers** correctness to
  `/code-review`, security to `/security-review`, and mechanical cleanup to
  `/simplify` rather than re-implementing them. Invokable as `/steer:audit` (command
  alias) or the `audit` skill.

### 1.32.0

- **UI craft now comes from Anthropic's `frontend-design`, re-listed not
  re-authored.** Until now nothing in the standards guided *aesthetic* UI
  quality when there was no design export — Claude fell back to generic AI
  defaults. Rather than maintain our own design skill, the marketplace now
  re-lists Anthropic's official `frontend-design` plugin via a `git-subdir`
  source pinned to a SHA (`/plugin install frontend-design@e22-plugins`; bump
  the SHA to update). We carry a pointer, not the prose — zero duplicated
  content.
- **Design-source guidance reweighted toward the common case: no / partial
  export.** Rule `90-design-sources.md` and `DESIGN-SOURCES.md` previously led
  with "features originate from a Claude Design export" and framed the export as
  authoritative. Most features have **no export, or only a partial one**, so the
  guidance now leads there: build the UI deliberately with `frontend-design`
  (scoped to a professional/enterprise default, the standard Next + TS + Tailwind
  stack, and accessibility), defer to a committed export only for the screens it
  actually covers, and anchor product-wide uniformity in `DESIGN.md`.
- **`DESIGN.md` gains a third origin — "established while building without an
  export."** Joins "distilled from an export" and "reverse-engineered by
  `/steer:adopt`": when there is nothing to distill, `DESIGN.md` *is* the record of
  the design decisions made while building, seeded from the first feature and
  grown as patterns recur — the thing that stops an export-less product drifting
  into differently-styled screens. The `/steer:design-sources` skill summary and
  the reference's new "Building UI without a (full) export" section spell out the
  workflow.

### 1.31.0

- **`/steer:adopt` now captures the as-built design, not just the spec.** Adoption
  reverse-engineered `/spec`, ADRs, and a productionization brief from a
  vibe-coded app's code — but never the **design**, so an adopted repo had no
  `DESIGN.md` to iterate on (the scaffolding sync didn't even pull in the
  template's stub). A new **step 7, "Capture the as-built design,"** reverse-
  engineers a root `DESIGN.md` from the running UI — the Tailwind theme, CSS
  custom properties, fonts, the palette/spacing/radius scales in use, and
  recurring component styling — written in the `@google/design.md` format and
  linted, under the same "as-built, dev-confirms, never invent" discipline as
  the spec extraction. **Crucially, a Claude Design export is no longer a
  prerequisite** — the code itself is the source. The step is skipped (and noted
  in `PRODUCTIONIZATION.md`) for backend-only repos with no UI surface, and the
  scaffolding-sync step (now step 10) is told never to overwrite a captured
  `DESIGN.md` with the template stub. Old steps 7–11 shift to 8–12.
- **`DESIGN.md` framing decoupled from exports.** `DESIGN-SOURCES.md` now states
  `DESIGN.md` has two legitimate origins — distilled from a design export
  (Greenfield/feature) **or** reverse-engineered from the as-built UI
  (Brownfield `/steer:adopt`) — so the file is no longer presented as something
  that only exists when a design export does.

### 1.30.0

- **`/steer:questions` no longer balloons into a costly codebase sweep.** The skill
  was cheap by design (grep the `## Open questions` sections, ask a human), but it
  had a blind spot: in an `/steer:adopt`-reverse-engineered spec, most open
  questions are *factual* — "is `X` dead code?", "does the client or server
  enforce this?", "what roles exist?" — not decisions. With no guidance on that
  class, a model correctly refuses to ask the PO/dev what their own code does and
  investigates instead — reaching for the most expensive tool available (one
  Explore agent per subsystem). One real run fanned out 4 agents and burned
  ~350k tokens to answer questions a handful of greps would settle. The skill now
  closes the gap with an explicit **triage step (step 4)**: split the worklist
  into **code-fact** (ground by targeted inline reads of the named file/symbol,
  batched, proposed as dev-sign-off) vs **human-decision** (route to PO/dev as
  before). A hard cost guardrail forbids per-question / per-subsystem
  investigation fan-out — at most one bounded subagent for the *entire* batch, and
  only when a broad cross-file search genuinely can't be done inline. Questions
  too costly to ground are left open and flagged rather than swept.
- **Leaner gather.** Step 2 now treats the grep's `-A20` window as sufficient
  context and tells the skill not to read each owning file wholesale — open a file
  only for a bullet the grep didn't capture, and only its `## Open questions`
  section.
- **Aligned the "never guess" contract.** The intro and step 8 now distinguish
  *inventing a decision* (still forbidden) from *grounding a code-fact in the
  actual code* (the cheap, correct move), so the read-then-propose guarantee no
  longer reads as "never look at the code."
- Updated `skills/questions/SKILL.md`.

### 1.29.1

- **Fix: `/steer:drift` skill frontmatter failed to parse, breaking the whole
  plugin.** The `drift` `SKILL.md` description was an unquoted YAML plain
  scalar containing `Read-only:` — the colon-space made the parser treat it as
  a nested mapping key and silently drop all frontmatter, so `claude plugin
  validate` errored and the loader rejected the plugin (every skill/command,
  e.g. `/steer:questions`, showed as "command not found"). Wrapped the description
  in double quotes. Guard for the future: any skill/command `description:`
  containing `:` (colon-space), `#`, leading `[`/`{`/`*`/`&`, or a leading
  quote must be quoted.

### 1.29.0

- **`/steer:questions` now auto-heals a retired `SPEC-QUESTIONS.md`.** The
  standalone file was retired in 1.25.0 (questions moved into `## Open questions`
  sections next to their context), but a repo forked from a pre-1.25.0
  `repository-template` still carried `spec/SPEC-QUESTIONS.md` on disk — and a
  fresh greenfield build dutifully *filled the stub it found*, re-introducing the
  retired artifact. The skill no longer just *avoids* the file, it migrates it: a
  new **step 1** detects `spec/SPEC-QUESTIONS.md`, routes each `## Open` item to
  its context (feature-specific → that feature's `intent.md` → `## Open
  questions`; product-level → `vision.md` → `## Open questions`), folds any
  `## Resolved` decision into the owning spec if not already captured, then — on a
  yes — deletes the stray file. It's a **move, not an answer**: nothing is
  invented or resolved during migration, preserving the skill's read-then-propose
  contract.
- **SessionStart nudge surfaces the legacy file.** `check-open-questions.sh`
  counts `## Open questions` items, which never matched the legacy file's `##
  Open` section — so a repo carrying only `SPEC-QUESTIONS.md` got no nudge and the
  heal was never triggered. The hook now also fires when `spec/SPEC-QUESTIONS.md`
  exists (independent of the open-question count), pointing at `/steer:questions` to
  migrate it. Fail-soft, still silent once the file is gone, composes with the
  existing open-question notice. Companion fix in `repository-template` removes
  the stub from the template's spine and adds `## Open questions` to its
  `vision.md`, so new forks no longer ship it.
- Updated `skills/questions/SKILL.md` and `hooks/check-open-questions.sh`.

### 1.28.0

- **`/steer:drift` verdicts are now status-aware, and `🟠 Partial` is a first-class
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
  - Updated `skills/drift/SKILL.md` only (no `commands/` alias change).

### 1.27.0

- **`/steer:drift` is now a spec-vs-spec diff that *consumes* `/steer:adopt`, not its
  inverse.** 1.24.0 framed drift as "the inverse of `/steer:adopt`" — a spec
  already exists, audit the code against it — and had it compare **code** against
  the `/spec` spine **plus a batch of source tickets**. That's the wrong axis for
  the actual workflow: run `/steer:adopt` to reverse-engineer the **as-built spec**
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
  - **Guard: redirect to `/steer:adopt` when there's no `/spec` spine** — there's no
    as-built spec to diff against until the code has been reverse-engineered.
  - Still **report + propose only** — no code/spec edits, Rule-5 resolution per
    finding (PO vs dev approval noted), `spec-drift` issues for decisions,
    ambiguities to `## Open questions` for `/steer:questions`.
  - Updated `skills/drift/SKILL.md`, the `commands/drift.md` alias, and the
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
  `/spec` spine, presenting both bootstrap routes (greenfield `/steer:init` vs
  reverse-engineering `/steer:adopt`) rather than guessing from code volume.
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
- **Generalized `/steer:init` to cover non-template greenfield, not just forks.**
  `init` previously bailed the moment it found no placeholders — leaving a
  from-scratch non-template repo with no working bootstrap path (the route the
  new hook points greenfield repos at). It's now a two-path skill: **Path A**
  (fresh template fork — the existing placeholder-resolution flow) and **Path B**
  (non-template greenfield — bring the spine + scaffolding in from
  `repository-template`, interview to fill `vision`/`users`/`glossary`, record
  the initial stack as the first ADR, pin the toolchain, then proceed
  spec-first). Repos with substantial pre-existing code still redirect to
  `/steer:adopt`. Updated the skill description, the `commands/init.md` alias,
  and the router (`rules/00-router.md`) accordingly.

### 1.25.0

- **New `/steer:questions` skill — stop open questions from rotting.** Open
  questions were written down once, gated at PO acceptance, then forgotten,
  spread across per-feature `intent.md` sections and a free-floating
  `SPEC-QUESTIONS.md`. The new skill sweeps every open question across the
  `/spec` spine and walks the PO/dev through answering each (read-then-propose:
  it never guesses an answer or edits without a yes), folding each decision back
  into the spec or recording an explicit deferral. Added a `commands/questions.md`
  alias and registered the skill in the router (`rules/00-router.md`) and
  spec-workflow (`rules/30-spec-workflow.md`) rules.
- **SessionStart nudge so questions can't rot silently.** A new
  `hooks/check-open-questions.sh` counts outstanding open questions across
  `vision.md`, every feature's `intent.md`, and `PRODUCTIONIZATION.md` (scoped to
  the `## Open questions` section, skipping resolved `- [x]` items and the
  template's placeholder seed) and surfaces the backlog every session, pointing
  at `/steer:questions`. Fail-soft and silent when there are none — the notice
  clears itself once questions are answered or explicitly deferred.
- **Retired `SPEC-QUESTIONS.md`; questions now live next to their context.**
  Per-feature questions live in that feature's `intent.md` → `## Open questions`;
  product-level questions (greenfield vision interview, whole-repo adoption) live
  in a new `vision.md` → `## Open questions` convention. Rerouted all references
  across rules 30/60/90, the spec-framework and design-sources references, the
  `productionization.md` template, and the `spec-scaffold`, `design-sources`,
  `drift`, `build`, and `adopt` skills.

### 1.24.1

- **Fix documentation drift in the `steer` loader skill.** The on-demand
  loader (`skills/steer/SKILL.md`, used on Cowork/desktop where the
  SessionStart hook does not fire) had two stale spots: its enumerated rule list
  omitted `22-housekeeping`, and its version-confirmation example hardcoded an
  old version string. Added `22-housekeeping` to the list (now matches all 17
  `rules/` files) and made the example placeholder-based (`vX.Y.Z`) so it can't
  drift again — the real version is still read from `plugin.json` at runtime. No
  behavior change.

### 1.24.0

- **New `/steer:drift` skill — audit the built app against its specs.** A manual,
  read-only conformance audit for the inverse of `/steer:adopt`: a spec exists and
  you want to confirm the code still matches it. The dev brings a batch of source
  tickets (pasted into the chat or pointed to a Jira export path); Phase 1
  reconciles those tickets against the `/spec` spine and flags spec gaps
  (proposed, not written); Phase 2 audits `/apps` + `/packages` against the spec
  plus the ticket behaviors, classifying each as Conforms / Drifted / Missing /
  Extra / Ambiguous with `path:line` evidence. Output is a drift report, a
  proposed Rule-5 resolution per finding (PO vs dev approval noted), and
  `spec-drift` issues for items needing a decision. **Report + propose only — it
  makes no code or spec edits and does not commit.** Discoverable via the router
  in `rules/00-router.md` and the `/steer:drift` command alias.

### 1.23.1

- **`/steer:adopt` resume migration: close the gap inside the skill, not just the
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

- **`/steer:adopt` now actually migrates the old filename on resume.** The
  always-injected `commands/adopt.md` recognized only the new
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
  build flow's handoff gate. `/steer:adopt` migrates an existing
  `PRODUCTION-READINESS.md` to the new name on its next run (resume-safe), so
  already-adopted repos pick it up without losing filled-in content.
- **Productionization is now a decision, not just a to-do list.** The gap
  analysis gains a **disposition** per area — **Keep / Refactor / Rewrite /
  Reject** — plus an **Overall recommendation**. `/steer:adopt` proposes
  dispositions (the dev ratifies at PR review); when most areas trend
  Rewrite/Reject it recommends **rebuilding from the now-extracted `/spec`**
  rather than hardening a mess, and escalates a project-level Rewrite/Reject to
  an ADR (`/steer:adr`).
- **`/steer:build` now leaves the same durable brief.** A PO-built v0 writes
  `/spec/PRODUCTIONIZATION.md` at handoff (the same artifact `/steer:adopt`
  produces) instead of letting the gaps evaporate with the PR description. On a
  PO build the dispositions trend Keep/Refactor — there's no legacy to triage,
  only stubs to finish.
- **Renamed the build flow's `Handoff readiness` checklist to `Handoff gate`**
  in `BUILD-STATUS.md`, matching the reference and ending the "two readinesses"
  ambiguity.

### 1.21.0

- **Repo housekeeping: a `housekeeping` rule + the `/steer:tidy` skill.** A PO
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
  - New `tidy` skill + `/steer:tidy` command and bundled
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

- **`/steer:adopt` stops waving raw SQL and missing schemas through as "clean."**
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
  a Cowork session with none of the org standards in context. New **`/steer`**
  skill loads the same `rules/*.md` ruleset on demand; run it once at the start of
  a Cowork session. The router (`00-router.md`) and README now point to it, and
  the README documents the Cowork limitation. When #40495 ships, auto-injection
  works in Cowork with no plugin change and the skill becomes a harmless repeat.

[anthropics/claude-code#40495]: https://github.com/anthropics/claude-code/issues/40495

### 1.17.0

- **Host port bindings must be overridable, so concurrent products don't
  collide.** POs and devs routinely run several products at once; any repo
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
  steps: `/plugin update steer@<marketplace>` to pull the new version,
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
  - The `design-sources` skill summary gains a matching key-point bullet.

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
  - **`/steer:adopt`** — new **Resume gate** before `## Steps`; step 2 embeds the diff
    command with imperative "run first" language; the competing "continue from
    unchecked items" framing in step 7 and the guardrail now defer to reconcile-first.
  - **`/steer:build`** and **`/steer:spec-scaffold`** — their resume/reconcile branches
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
  - **`/steer:adopt`** — new step 2 reconciles `/spec/PRODUCTION-READINESS.md`
    (so e.g. the 1.11.0 dependency-freshness section is picked up by repos adopted
    under 1.10.0). Steps 2–10 renumbered to 3–11; new "Resume is additive, never
    destructive" guardrail.
  - **`/steer:build`** — reconciles `/spec/BUILD-STATUS.md` on resume.
  - **`/steer:spec-scaffold`** — reconciles an existing feature's `intent.md` /
    `contract.md` instead of clobbering it (also fixes a latent overwrite-on-rerun
    risk).
  - **Exempt:** reference prose (read in place, always current via `/plugin
    update`) and **ADRs** (immutable point-in-time records — supersede, never
    retrofit a newer template into an accepted ADR).

### 1.11.0

- **`/steer:adopt` now flags outdated deps and bad practices.** Vibe-coded apps
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

- **New: adopt an existing non-template repo — `/steer:adopt`.** Until now the
  plugin assumed every repo was forked from `repository-template` (`/steer:init`
  only resolves placeholders in an already-scaffolded fork). The new skill
  covers the "vibe-coded" case — working code, but no `/spec`, no `mise.toml`,
  no plugin install — by reversing the Greenfield flow: survey the code,
  reverse-engineer `vision.md`/`users.md`/`glossary.md` (ask, don't invent),
  extract `intent.md` + `contract.md` per feature via `/steer:spec-scaffold`,
  capture as-built choices as ADRs via `/steer:adr`, then fetch
  `element22llc/repository-template` and sync in the scaffolding it lacks (mise
  tasks, `compose.yaml`, CI, `/configs`, `.env.example`, plugin install) —
  adapting to the existing stack, reconciling rather than replacing, and never
  clobbering working code. Ends in a `feat/adopt` branch and a PR for dev
  review. (`skills/adopt`, `commands/adopt.md`)
- **New `/spec/PRODUCTION-READINESS.md` (bundled template).** The findings
  output of `/steer:adopt`: a gap analysis vs the standards (tests, lockfiles &
  pins, secrets, high-risk areas, CI, Zod/error model, layout) with a
  stop-and-rotate callout for any committed secret. Doubles as the resumable
  adoption checklist — a fresh session reads it first and continues from the
  unchecked items. (`templates/spec/production-readiness.md`)
- Router and spec-workflow rules point whole-repo adoption at `/steer:adopt`,
  distinct from a per-feature Brownfield change. (`rules/00-router.md`,
  `rules/30-spec-workflow.md`)

### 1.9.0

- **PO demo-validation gate before handoff.** `/steer:build` no longer proposes
  the handoff PR on its own judgment that the app is done — the Definition of
  Done is a precondition, never the trigger. New step 9: after the PO has
  actually used the running app and demo feedback is incorporated, the gate
  opens only on the PO's explicit "this does what I wanted" (asked plainly, or
  volunteered). Step 8 is now an explicit iterate-loop that may span many
  sessions. (`skills/build`, `commands/build.md`)
- **Build-flow state persists across sessions.** New `/spec/BUILD-STATUS.md`
  (bundled template), created at interview time and updated at every step
  transition: current step, per-feature progress, handoff-readiness checklist.
  A fresh session reads it and resumes from the recorded step instead of
  restarting the flow; the skill description now triggers on resuming too.
  (`templates/spec/build-status.md`, `skills/build`,
  `templates/reference/spec-framework.md`)
- **Per-feature demo validation is traceable.** `feature-intent.md` gains a
  `validated` status (between `implemented` and `live`) and a
  **PO validated the working demo** acceptance checkbox, checked only on the
  PO's explicit confirmation. (`templates/spec/feature-intent.md`)
- Command alias cleanup: `commands/build.md` guardrail wording aligned
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
  (`rules/05-roles.md`, `skills/build`)
- **Intent template captures data semantics.** New PO-facing **Key concepts &
  data** and **Lifecycle expectations** sections in `feature-intent.md` give
  data-model and deletion intent a structured home; `contract.md`'s Data model
  now derives from them and is marked `proposed — dev confirms at review`
  when drafted pre-production. `/steer:build` now interviews for deletion
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
  - `85-practices.md` condensed to the standards-specific baseline (Drizzle-only,
    Zod boundaries, server-first, `packages/` for domain logic, nothing
    silenced, lockfile discipline); the full patterns/anti-patterns prose moved
    to `CONVENTIONS.md` (new **Baseline patterns & anti-patterns** section).
  - `30-spec-workflow.md` keeps the triggers; the 4-step Greenfield walkthrough
    moved to the spec-framework reference (new **Greenfield flow** section),
    which `/steer:build` now cites directly.
  - `15-commands.md` command block compacted; `00-router.md`, `20-layout.md`,
    `60-high-risk.md`, `70-secrets.md`, and `90-design-sources.md` tightened
    (duplication with Stack/Spec-workflow removed, pointer phrasing).
- **Skill descriptions trimmed ~35%.** All six SKILL.md frontmatter descriptions
  (loaded every session) cut to one-line what-it-does + when-to-use; the
  `/steer:conventions` summary now lists the new reference sections.

### 1.6.0

- **New: PO path — `/steer:build` skill + command.** Non-technical product
  owners can now go idea → auto-drafted spec → intent validation → working
  local app entirely in Claude Code. The skill is a thin driver over the
  existing Greenfield flow: PO-adapted first-run setup (Claude installs and
  runs mise/Docker/pnpm itself, asks the PO only product name + one-liner,
  keeps the default stack), interview → `vision.md`/`users.md`/`glossary.md`,
  intents via `/steer:spec-scaffold`, an explicit PO-acceptance gate before
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
  `/steer:build` (PO approves intent, dev approves the PR). Fixed structure-
  diagram drift: removed `/spec/README.md` and `/spec/_templates/`, which the
  template repo doesn't ship (templates are bundled in this plugin).
- README: dropped the hand-maintained Versions table (already stale at 1.0.0)
  in favor of `plugin.json` + this changelog.
- Pairs with `repository-template`: PO quickstart in the README, `/steer:build`
  in the `CLAUDE.md` fork note, broadened `spec/vision.md` header, and two
  fresh-fork CI fixes — (1) `pnpm install --frozen-lockfile` failed every
  fresh fork's first PR (`ERR_PNPM_NO_LOCKFILE`, the template deliberately
  ships no `pnpm-lock.yaml`); the install step now freezes only once a
  lockfile exists; (2) mise-action v4 auto-runs `mise install --locked` when
  a `mise.lock` exists, so the comment-only placeholder locks failed every
  tool with "not in the lockfile"; CI now drops placeholder locks (no
  `[[tools]]` entries) from the runner workspace before setup and installs
  the exact pins once `/steer:init` commits populated locks. Both fixes are
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
  `CONVENTIONS.md` and `/steer:init` step 4 now document the caveat, require
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
- `/steer:init` step 5 now covers workspace lockfile adoption: the template ships
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
  in the `/steer:conventions` skill summary.
- `/steer:init` gains step 6: adapt the template's baseline tasks to the product
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
  `steer` plugin mirroring the `repository-template` org standards.
- Always-on ruleset (`rules/*.md`) injected via a `SessionStart` hook: stack,
  layout, spec workflow, testing, Definition of Done, high-risk areas, secrets,
  change-size model, baseline patterns/anti-patterns, design-sources, and the
  end-of-session checklist.
- Skills: `init`, `spec-scaffold`, `adr`, `conventions`,
  `design-sources`. Command: `/steer:init`.
- Bundled spec templates (`feature-intent`, `feature-contract`, `adr`) and full
  reference prose (`CONVENTIONS.md`, `DESIGN-SOURCES.md`, `spec-framework.md`).

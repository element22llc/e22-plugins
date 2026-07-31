# Changelog

All notable changes to the `e22-plugins` marketplace. Each plugin is versioned
in its own `.claude-plugin/plugin.json`; this file records what changed and when.

## steer

### [Unreleased]

### 4.0.0

- **Fixed:** the action-history migration's second precondition can now detect every
  surface its own action table rewrites. It grepped a single pattern, `/?spec/HISTORY\.md`,
  across all seven files — but three of them never carried that token: `CLAUDE.md` and
  `spec/PRODUCT.md` name a bare `` `HISTORY.md` `` and `spec/sources/*/source.md` carries
  `[HISTORY entry · …]`. Once step 1 created the directory the shape check went quiet, so a
  step 3 that missed any of those three converged to "already migrated" and the stale prose
  was never re-detected. Worst for a **polyrepo member**, which has no local
  `spec/HISTORY.md` at all, leaving the grep as the only detector. The precondition is now
  split into two file-scoped greps, keeping `ci.yml` on the original unescaped pattern so
  the idempotency invariant above is untouched.
- **Fixed:** `/steer:sync` no longer tells an `infra` repo to skip `compose.yaml`. Its
  profile note read "an `infra` repo reconciles the root infra `mise.toml` + infra CI,
  never `package.json`/`compose.yaml`", but `compose.yaml` is **core for every profile** —
  an `infra` repo with no local services *may* delete it, which is permission, not
  exclusion. So sync was instructed to skip a Layer 0 file on an `infra` repo that
  legitimately runs backing services. The `package.json` half was correct and stays.
- **Fixed:** `/steer:init` and `/steer:sync` now carry the same polyrepo action-history
  branch the other history-writing skills do — in a member, write the entry to the
  **workspace** when `workspace.path` resolves, and fall back to the PR description only
  when it does not. Both previously skipped straight to the PR-description fallback, so a
  member with a resolvable local workspace checkout never got a durable entry. Also drops
  a stale `(step 4)` cross-reference in `/steer:sync` that pointed at the migrations step.
- **Fixed:** `scan-version-pins.sh` now prunes `.claude/worktrees`. Linked worktrees are
  full checkouts of the same repo, so every scanned file was reported once per live
  worktree and a violation on another branch was reported against the branch you are on.
- **Changed (breaking):** the action history is now a **directory of immutable per-entry files**
  (`spec/history/YYYY-MM-DD-HHMM-<slug>.md`) instead of the single append-only
  `spec/HISTORY.md`. The old file put every PR's entry at the same anchor — the top of
  `## Entries` — so **every pair of concurrent PRs conflicted there**. The conflict is
  positional, not content-based, so finer date/time granularity in the heading does not
  help; and git's `union` merge driver, the obvious cheap fix, is actively unsafe for
  this file: union is *line*-based, so when two entries share a trailing line
  (`- **Areas:** apps/web` is the common case, `Areas` being the template's last field)
  it splices the two blocks together and **silently drops a field**, producing a clean
  merge with no conflict markers that no reviewer ever sees — verified against the
  shipped template's exact field order. One file per entry means two PRs write different
  paths, so there is nothing to resolve, and it suits an append-only audit log better:
  entries are immutable, a correction is a new entry carrying `- **Corrects:**`.
  New templates `templates/spec/history-readme.md` (the format doc, installed as
  `spec/history/README.md`) and `templates/spec/history-entry.md` (per-entry, on demand)
  replace `templates/spec/history.md`. The spec-drift CI gate now clears on any
  **date-named** `spec/history/` entry (the directory's own `README.md` format doc does
  not clear it — editing the format doc is not writing an entry) and still accepts the
  legacy single-file path, so a repo mid-migration is not flagged; `hooks/lib/spine.sh`
  accepts **either** shape as a present action
  history so an unmigrated repo is not reported `damaged`. Rules `20`, `26`, `30`, `32`,
  `35`, `50`, `53`, `55`, `61`, `62`, `75`, `99`, the `/steer:reference traceability`
  prose, the PR template, and every skill that records an entry (`init`, `adopt`, `sync`,
  `spec`, `adr`, `intake`, `protect`, `build`, `work --hotfix`) — plus `next`, which only
  reads them to orient — now name the
  directory. Existing repos are carried forward by a **`MIGRATIONS.md` ledger entry**,
  which creates `spec/history/`, **freezes** `spec/HISTORY.md` as the
  pre-migration archive (deliberately *not* split — those entries are immutable
  evidence), rewrites the path in the live instruction surfaces `/steer:sync` can reach,
  and logs the migration as the directory's first entry. That entry is idempotent by
  construction: its precondition greps only for an **unescaped** mention of the legacy
  path, so the bundled `ci.yml` may carry `spec/HISTORY.md` only as the escaped regex
  literal `^spec/HISTORY\.md$` and never as a bare token in a comment or operator
  message — otherwise the block the entry copies **verbatim** would satisfy the
  precondition forever and mint a duplicate history entry on every `/steer:sync`.
  `check_standards.py` enforces that invariant on the bundled template so it cannot
  regress.
- **Changed:** a `MIGRATIONS.md` ledger entry is now authored as `### [Unreleased] — <what>`
  and renamed to `### vX.Y.Z` by the release, instead of being keyed to a guessed version.
  An entry lands in an implementation PR, which merges *before* the release that names it,
  so the introducing version is not knowable at authoring time — and a guess is not a
  cosmetic error: a key **below** the version the entry actually shipped in is read as "at
  or below the stamp" by every repo stamped in between, so `/steer:sync` **silently skips
  the migration** and nothing ever reports it. `[Unreleased]` is never at or below any
  stamp, so a forgotten rename is safe and self-correcting — the entry is always walked and
  applied by its own precondition. What ships is the convention itself — the ledger's
  authoring prose and its entry template; the pending entry's own heading is renamed to a
  real version by the release PR, so a consumer never receives an `[Unreleased]` key.
  `/steer:sync`'s ledger walk now says so explicitly: a non-version heading is always
  walked by precondition rather than compared against the repo's stamp.
- **Fixed:** `/steer:tracker-sync`'s idempotent-push guardrail searched only **open**
  issues before creating one, contradicting both its own `search` operation and the
  normative dedup contract in `ISSUE-SCHEMA.md`, which require **all** states. The
  guardrail governs *every* create, so the narrow version won in practice: a finding
  closed as a false positive is invisible to an open-only search, so the next
  `/steer:audit` + `publish-audit` re-filed it — defeating the reconcile-not-accumulate
  guarantee. Both sites now say open *and* closed — the guardrail and the numbered
  `push`-from-drift procedure, which carried the same narrow instruction — and a closed
  exact match routes through the reopen-or-link-follow-up protocol.
- **Fixed:** `/steer:sync` step 3 short-circuited the whole migration walk — "if `FROM`
  already equals `TARGET`, there are no pending migrations; skip to step 5" — which
  stranded an `### [Unreleased]` ledger entry on exactly the repos already stamped at
  that version, the failure the `[Unreleased]` keying convention exists to prevent. The
  stamp is an optimization; the precondition is the safety mechanism. Step 4 now always
  walks version-less entries.
- **Fixed:** the two solo-trunk issue-first advisories offered `'(#N)' in the subject` as
  an alternative to a `Closes #N` trailer. GitHub does not close an issue on a bare
  `(#N)` cross-reference, so an agent taking that option left the issue open and failed
  rule 50's Definition of Done — and in solo-trunk, where there is no PR, the closed
  issue *is* the completion record, so the work ended with no terminal evidence at all.
  Both hooks now name the trailer as the only closing mechanism.
- **Fixed:** the sticky scaffold nudge misstated the profile install map — "only app repos
  get `package.json` / `compose.yaml`". `compose.yaml` is core for **every** profile and
  `package.json` ships with any Node-stack profile (`app`, `service`, `library`, `cli`).
  The nudge re-fires on every write until a repo is bootstrapped, so it was the most-read
  wrong sentence in the hook set, and a `service` or `library` bootstrap driven off it
  skipped files it should have had.

### 3.24.0

- **Fixed:** the commit-approval clause survived a second time, in the file `/steer:tidy`
  actually executes. `templates/reference/HOUSEKEEPING.md` said "**Don't commit** until the
  user approves the result" — semantically identical to the `/steer:sync` clause fixed
  above, and live behavioral prose (`tidy/SKILL.md` sends the model to read that file).
  It escaped `check_standards.py`'s `_NO_COMMIT_RE` purely on orthography: the pattern has
  no contraction branch, so `Don't commit` cannot match at any path. The earlier fix
  addressed the one instance the gate's canned verdict named without sweeping the class;
  this one swept it (the remaining hits — rule 50's DoD item and `init`'s "don't commit to
  `main`" — both carry correct solo-trunk carve-outs). Approval belongs on each
  rename/move/delete, not on the commit that records them.
- **Fixed:** rule `05-roles` stated the PO delivery gate as an absolute ("a PO-built app is
  normal `feat/*` work that merges to `main` as v0 only after a dev approves the PR") while
  `/steer:build` **offers and recommends** solo trunk, which commits straight to `main` with
  no PR. Rules 30 and 45 both carry the carve-out; rule 05 — always-on session context —
  did not, so a model holding it would resist the path `build` is instructed to recommend.
  Rule 05 now names both modes and points at Commit autonomy.
- **Fixed:** a `/steer-<skill>` reference could point at a prompt file that is never
  generated. `gen_copilot_prompts.py` skips the `user-invocable: false` gateways (correct)
  but its `/steer:` → `/steer-` rewrite ran blindly, so `prompts/steer-work.prompt.md`
  shipped `/steer-tracker-sync` in both its body and the `description` Copilot's picker
  displays — a VS Code slash-command that will never exist. The rewrite is now scoped to
  the names actually emitted, in **both** generators (`gen_copilot_prompts.py` and
  `gen_copilot_agents.py` — the agents one was latent, since the shipped reviewer happens
  to reference no gateway, and the `check_copilot_*` drift gates cannot catch a regression
  here because they compare the artifact against the generator's own output). A reference
  to a gateway keeps the colon form, which reads as the Claude-Code-side gateway it is, and
  a test now pins both halves.
- **Fixed:** the shipped PR template told the author "these are review aids, not CI gates"
  above a checklist whose changed-line-coverage item **can become** a blocking gate — once
  the repo wires coverage tooling, `ci` runs `diff-cover --fail-under` on touched lines and
  fails the PR; until a coverage provider is added (deliberately not pinned by the scaffold)
  the step fail-opens and that box is advisory like the rest. Both files install into the
  same consumer `.github/` from the same PR. The heading now names the one conditionally
  enforced item and keeps the (accurate) no-global-threshold / no-naming-gate statement.
- **Fixed:** `/steer:audit code`'s DX dimension reported a false finding on every compliant
  repo. `templates/reference/AUDIT-DIMENSIONS.md` told it to flag a `mise.toml` "missing the
  tasks a contributor needs (`setup`, `dev`, `test`, `lint`)" — but the scaffold's task is
  `dev:setup`, not `setup`, and per the Stack rule `test`/`lint` deliberately live in
  `package.json` with `mise` only delegating one-way. So a freshly scaffolded, fully
  rule-compliant repo tripped the dimension. Now names the scaffold's real entry points and
  says explicitly not to flag `test`/`lint`.
- **Fixed:** `/steer:sync` shipped the one sentence this repo's own gate hard-fails as a
  rule-45 contradiction. `skills/sync/SKILL.md` said "Nothing is committed until the dev
  approves" while `rules/45-commit-autonomy.md` says "Never pause work to ask 'should I
  commit / push / open the PR?'" — and `check_standards.py`'s `_NO_COMMIT_RE` matches that
  wording verbatim, with a canned verdict ("commit, push, and the PR are autonomous, only
  the merge waits for the dev"). It never fired because `check_authorization` applies the
  regex to exactly three paths (`init/SKILL.md`, `adopt/SKILL.md`,
  `adopt/PROCEDURE.md`). The skill also contradicted **itself** two screens earlier
  ("push the branch and open the PR yourself, announced"). Clause replaced with the
  autonomous-commit/merge-waits statement. **Not fixed here, deliberately:** widening the
  gate's file list to `skills/**/*.md` would have caught this — that is a gate-scope change
  and belongs in its own PR.
- **Fixed:** the `markitdown` ledger entry told consumers that after editing
  `.vscode/mcp.json`, "additive reconciliation keeps it current afterwards" — nothing does
  that. `sync/RECONCILE.md` says "Don't reconcile `.mcp.json` here", and neither
  `scan-capabilities.sh` nor `scaffold_reconcile.py` mentions `.vscode/` at all. Same
  false-refresh-path class as the header fixed above, surviving in the ledger — which is
  the surface a consumer actually follows during `/steer:sync`. The entry now says the
  file is theirs once installed, sits outside `copilot-surface-current`, and is amended
  only by a one-shot ledger entry like that one.
- **Fixed:** the shipped `ci.yml` header said "Before any app exists, the stack steps
  simply don't run" — the exact claim the scaffold README retracted earlier in this cycle.
  Node detection is `[ -f package.json ]` and `profiles/_node/package.json` is a Layer-1
  install, so on any profile that ships a root `package.json` the guard fails from the
  first commit (a Python-only product ships none, and is unaffected). Two files a consumer installs together contradicted each other; the header now
  states when the guard bites and that only a wholly undetected stack skips the phase.
- **Fixed:** the generated Copilot **agent** artifact shipped both invocation forms.
  `gen_copilot_agents.py` applied the `/steer:` → `/steer-` rewrite to the body but not to
  `description` — the field Copilot's agent picker displays, in a file that carries no
  mapping preamble — so `steer-reviewer.agent.md` named `/steer:audit` in frontmatter and
  `/steer-audit` in its body. `gen_copilot_prompts.py` already rewrote its descriptions;
  the two generators now agree.
- **Fixed: the generated Copilot artifacts named the one refresh path that cannot
  refresh.** All 27 steer-managed artifacts — `copilot-instructions.md`, the 24
  `prompts/*.prompt.md`, `agents/steer-reviewer.agent.md` and
  `instructions/infra.instructions.md` — carried a
  generated header telling the reader to "re-run `/steer:init`'s Copilot step". That is
  the exact path the `copilot-surface-current` capability was added to replace, because
  `/steer:init` **stops on an already-initialized repo** and so can never refresh
  anything: a Copilot teammate who followed the header would conclude no refresh path
  existed, which is the silent-staleness failure the capability closes. The capability,
  `MANIFEST.md`, and the consumer-facing Copilot marketplace description were all
  corrected in this cycle — the artifacts a consumer actually *reads* were not, leaving
  the defect alive in the highest-visibility place. Headers now name **`/steer:sync`**
  for a managed repo and `mise run gen:copilot` for the plugin repo, so the maintainer-only
  task is no longer shipped as a consumer instruction. Fixed in the three generators
  (`gen_copilot_{instructions,prompts,agents}.py`) and regenerated — the artifacts are
  byte-gated by `check_copilot_*`, so they are never hand-edited. The
  `gen_copilot_instructions.py` comment that justified the old path as deliberate is
  replaced with the reason it is wrong. Every artifact names **`/steer:sync` from Claude
  Code** — the colon form, with the surface stated. The header ref is deliberately kept out
  of the generators' `/steer:` → `/steer-` rewrite: the repair is a verbatim re-copy from
  `${CLAUDE_PLUGIN_ROOT}`, which VS Code does not have, so it points at an action taken on
  the other surface rather than a command its reader types.
  `docs/concepts/copilot-support.md` and the `steer-sync` prompt capsule both already said
  exactly this. (It is not the only un-rewritten colon ref: the prompt capsules' two
  generator boilerplate lines name the Claude-Code skill explicitly for the same reason,
  and the flat `copilot-instructions.md` is colon-form throughout by design, resolved by
  its own mapping preamble.) Cross-links to **sibling prompt files** do take the hyphen
  rewrite, since those resolve in VS Code.
- **Fixed:** `scaffold/vscode/mcp.json`'s generated header claimed a refresh path that
  nothing performs. `/steer:sync`'s `copilot-surface-current` capability covers only
  `.github/copilot-instructions.md`, `prompts/`, `agents/` and `instructions/` —
  `scan-capabilities.sh` never looks at `.vscode/`, and `sync/RECONCILE.md` exempts MCP
  config from reconciliation outright. The file is also the one Copilot artifact the
  consumer **owns**: `MANIFEST.md` tells them to "merge additively… remove servers the
  repo doesn't use", which its own "do not edit by hand" line forbade. The header now
  says what is true — a starting point you own, outside the `copilot-surface-current`
  capability so nothing re-copies it over your edits (a one-shot ledger migration may
  still amend it), regenerated with `mise run gen:copilot` in the plugin repo. The
  `MANIFEST.md` row and `docs/concepts/copilot-support.md` now say the same.
- **Added: `/steer:sync` now refreshes the generated Copilot surface.** New
  `copilot-surface-current` capability (15th) — `.github/copilot-instructions.md`,
  `prompts/`, `agents/`, `instructions/` — wired-when every file is **byte-identical**
  to its plugin source, repaired by verbatim re-copy. Closes a real hole: Copilot has
  no context-injecting SessionStart hook, so that static set *is* its whole standards
  surface, yet `MANIFEST.md` and the consumer-facing Copilot marketplace manifest both
  named "re-run `/steer:init`" as the refresh path while `init` **stops** on an
  already-initialized repo, and `/steer:sync` had zero Copilot references. The surface
  therefore froze at whatever plugin version bootstrapped the repo — a Copilot
  teammate silently worked against retired rules while their Claude Code colleagues
  were current. Byte-equality is the right test because these are generated artifacts;
  repo-specific Copilot guidance lives in a *separate* `*.instructions.md` the consumer
  owns, which the re-copy never touches. Copilot support stays **opt-in**: a repo with
  no `copilot-instructions.md` reports `n/a`, never `absent`, so sync never installs a
  surface nobody asked for. This also self-heals the drift found in
  `copilot-instructions.md` (an agent-executed end-of-session item still naming the
  pre-rename `docker:clean`) with no ledger entry — the artifact is regenerated from
  `rules/`, so a plugin-sourced re-copy is the transform.
- **Fixed:** `/steer:tracker-sync` withheld `gh api` on the rationale that it is "the
  delivery surface", but **GraphQL is the transport to reach for** on `field-get` /
  `field-set` / `link-blocked-by` / `bootstrap-fields` — four ops `OPERATIONS.md` places
  *inside* the gateway's own tracker-metadata boundary. The fallbacks those ops document
  are real but neither substitutes cleanly: the REST endpoints sit outside every granted
  prefix and so prompt, and the MCP github tools are granted but expose issue fields only
  where the org enabled them. So a documented **read**
  prompted on a direct invocation, contradicting the skill's "Reads never confirm."
  Granted `Bash(gh api graphql:*)` as a scoped carve-out; delivery-surface mutation
  (PR merge, branch protection, repo settings) stays withheld. **The grant is broader
  than the boundary and the limit is prose-enforced:** allowed-tools matches a
  command-string prefix, so it cannot distinguish a Projects field query from
  `mergePullRequest` or `createBranchProtectionRule`, which GraphQL can also express.
  Both `SKILL.md` and `OPERATIONS.md` now state that the gateway issues only the
  enumerated operations and that nothing checks this mechanically. Never widen to
  `Bash(gh api:*)` — a review obligation, not a gated one: `check_standards.py` bans that
  form only in the scaffold's `.claude/settings.json`, and nothing constrains *what* a
  skill's own `allowed-tools` may grant (the one per-skill assertion checks only that
  helper scripts the body invokes are covered), so widening the grant would pass every
  check.
- **Fixed:** `/steer:audit spec` made a `contract.md` `path:line` pointer the
  **mandatory** evidence for every verdict ("never assert a match from the tracker spec
  alone"), but `## Implementation pointers` is declared *optional*, "not a maintained
  index", and file-level at best — and **no skill ever writes a `path:line` there**, so
  the required evidence could never exist and every verdict was formally
  unevidenceable. Relaxed to the evidence that does exist: cite the `contract.md`
  **section** that captures the behavior (named or quoted); treat a pointer as
  corroboration when present, never a requirement; and where code-level confirmation is
  genuinely needed and no pointer exists, search the repo and cite what you find. The
  real guarantee — never assert a match from the tracker spec alone — is unchanged.

- **Fixed:** `/steer:status` detected in-flight work from "an **in-progress label**", a
  label that does not exist and that the taxonomy forbids: `LABELS.md` states lifecycle
  state is the `steer:state` marker "(never a label)" and "Do not encode status… as
  labels", and `bootstrap-labels` creates no lifecycle label — so the filter silently
  matched nothing and the report's "In progress" section under-counted with no error.
  `/steer:next` already did this correctly by reading the marker. Now reads `steer:state`
  (`in-progress` or `validate`) from the issue body, with the label trap called out. This
  also grounds the acceptance row corrected earlier in this cycle, whose trigger keys on
  the issue being in `validate` — a marker value the skill was nowhere instructed to read.
- **Fixed:** the `v3.24.0` infra ledger entry and its docs-site description both
  mis-stated **which repos carry the file**. Both said or implied the `infra` *profile*,
  but `MANIFEST.md` installs `infra/README.md` conditionally on **a nested `/infra` dir
  inside a monorepo** — and such a repo stays profile `app`, explicitly "distinct from the
  `infra` *profile*". A root-level infra repo keeps these conventions in its **own README**
  (rule `12-stack-infra`: "Detail in `/infra/README.md` (monorepo) or the repo README"),
  which the entry does not rewrite. So the most common carrier of the stale prose — an
  app-profile monorepo with `/infra` — would have read both surfaces and concluded the
  migration didn't apply to it, while an infra-profile reader would have looked for a file
  they don't have. All **four** surfaces now name the real carrier and say the root-level
  case needs a hand check: the ledger entry's body, its scannable **heading** (which the
  first pass left saying "infra profile", so the entry contradicted itself at the one line
  a consumer skims during `/steer:sync`), the docs-site description, and the release-PR
  re-key note above.
- **Fixed:** `docs/concepts/authorization-model.md` claimed "`gh api`/`gh:*` stay prompted
  by omission" as a plugin-wide property. `/steer:protect` carries `Bash(gh api repos/*)`
  — one of the plugin's two `gh api` grants, alongside `/steer:tracker-sync`'s
  `Bash(gh api graphql:*)` carve-out — so `gh api repos/…` reads are silent in a
  `protect` session, and the page's own enumeration of every skill with scoped frontmatter
  grants omitted `/steer:protect` entirely. The omission claim is now scoped to the
  scaffold allowlist, `protect`'s re-grant is named in both places, and the page carries
  the argument-order invariant that is the *actual* reason its writes still prompt —
  previously documented only inside the skill, with no docs surface at all.
- **Fixed:** the migration-coverage note undercounted the owed entries again — **four**,
  not three. The fourth is the scaffold root `mise.toml`'s prune instruction ("products
  without a database delete the `db:*` tasks **and `compose.yaml`**", replaced with a
  conditioned version): a procedural line a human executes, inside `templates/scaffold/`,
  so in scope on exactly the grounds the `infra/README.md` entry was written on. The note
  now also splits the four by *whether they need the convention call* — (1) and (2) do,
  because they live in `templates/github/`; (3) and (4) do not — instead of implying one
  decision gates all of them, and states why the two in-scope ones were still left for a
  human.
- **Fixed:** `/steer:status`'s acceptance row was split earlier in this cycle on a **"PR
  merged" precondition the skill cannot observe.** `status` grants only issue/search read
  verbs (no `gh pr` verb, no PR-read MCP tool), and its own sourcing rule says *not* to
  source from merged PRs because commit/PR detail is dev-facing noise for a client
  audience — so both halves of the split were undecidable in its domain. Collapsed back to
  one row keyed on what the report actually reads (the issue in `validate` / spec
  `Status: implemented`), which names the PO's decision and explicitly hands the merge
  precondition to `/steer:work`, the skill that *can* see it. Third correction to this one
  table in this cycle: the original defect was a command that couldn't perform the action,
  the second was a mis-categorization plus a missing precondition, and this is the
  precondition being unobservable — worth a human eye on the final shape.
- **Fixed:** `/steer:next`'s row for "PR merged but issue still `validate`" was the only
  row in a table headed "Category (safety level)" carrying no `(L#)` marker, and this
  cycle's golden fixture now asserts "level 3" for exactly that state — leaving the fixture
  with nothing in the table to be walked against. Added `(L3)`.
- **Fixed:** adding the sixth `### v3.24.0` ledger entry earlier in this cycle left three
  surfaces counting five. `docs/reference/repository-contract.md` said "**Five** further
  entries are accumulating" and described only five, so the sixth had no description
  anywhere on the docs site — a consumer reading that page to learn what `/steer:sync`
  will propose was told nothing about the `infra/README.md` rewrite or its
  never-touch-a-live-backend guard. Worse, this changelog's own release note said "FIVE"
  and instructed the release PR to "re-key **all five** if this release is not 3.24.0" —
  and that instruction is the *only* compensating control for the hard-coded headings, so
  the under-count would have orphaned the sixth entry at a version that never ships,
  permanently skipped by every consumer's stamp comparison. A third count in the same
  paragraph still said "all three", stale from an earlier round. All corrected to six.
- **Fixed:** the `v3.24.0` infra `use_lockfile` ledger entry added earlier in this cycle
  shipped a **self-satisfying precondition**. Its grep was `grep -n 'DynamoDB'
  infra/README.md`, but the replacement text the entry itself mandates ends "No
  **DynamoDB** lock table is needed" — so the precondition fires forever, "once applied,
  re-running is a no-op" was false, and `/steer:sync` would re-propose the same transform
  on every run. This is exactly what the ledger's own rule forbids ("its precondition must
  be a grep that fires only while a stale token is still present"). Now greps the two
  genuinely stale tokens (`S3 + DynamoDB`, `bucket and lock table`), both verified absent
  from the migrated text, with a note saying why the obvious grep is wrong.
- **Fixed:** `/steer:issues triage` told the reader to infer a missing kind as "feature /
  bug / **product-question** / **improvement**" and write it to the `steer:kind` marker.
  `issue_kind` is a **closed** enum (`epic` · `feature` · `bug` · `task` · `finding` ·
  `spec-question` · `spec-drift` · `audit-run`) containing neither: `product-question` is
  the Issue *Form*'s name for what the marker calls `spec-question`, and `improvement` is
  a Form with deliberately **no kind of its own** — its own template comment says an
  improvement "is classified at triage into Feature, Task, or Bug — it is not a permanent
  kind." Triage was being instructed to write two out-of-enum marker values, and `task`
  was missing from the list entirely. Now names only enum members and states the
  Improvement Form's classify-into-three rule.
- **Fixed:** `/steer:protect` asserts that writing repo settings is "**NOT**
  pre-authorized", but its read grant `Bash(gh api repos/*)` matches on the *endpoint
  path* and cannot express "reads only" — so `gh api repos/O/R/vulnerability-alerts -X
  PUT` prefix-matches it and would apply a privileged write with **no** prompt. Whether
  the gate the skill promises actually fires depended on argument order, which no prose
  stated. All three writes in the procedure already put `-X PUT`/`-X PATCH` first (so they
  correctly prompt); the invariant is now documented as load-bearing, with the reason, so
  a later reorder can't silently disarm the gate.
- **Fixed:** three golden fixtures cited the wrong precedence level for the category they
  pin. `adopt-awaiting-po-approval.md` and `adopt-pr-awaiting-review.md` called publishing
  findings "level 5" — level 5 is the *release-timing* band; publishing is `Recommended`,
  i.e. optional follow-up at level 6. `spec-blocking-question.md` called intent approval
  "the approval transition (level 4)" — it is `Human decision required`, level 3.
  `adopt-awaiting-po-approval.md` additionally pinned the expected command as "none — no
  plugin command performs it", contradicting both the `adopt` table row it exists to pin
  (which names `/steer:spec approve`) and `NEXT-ACTIONS.md`'s explicit carve-out that an
  **in-session** PO approval *is* promptable and does carry a command. Third round running
  that this fixture class has drifted from the skill tables it pins; nothing gates fixture
  content against those tables, which is why it keeps recurring.
- **Fixed:** the two golden fixtures pinning "PR merged but issue still `validate`" —
  `next-actions-fixtures/work-pr-merged-tracker-stale.md` and
  `next-fixtures/merged-stale-vs-new-work.md` — still expected **`Blocking now`** and the
  action "*Reconcile* the stale tracker state for #123 to `done`", the exact text this
  cycle replaced in `/steer:work` and `/steer:next` when that transition was corrected to
  propose-only. Their READMEs instruct a reviewer to walk a skill's table against each
  `Given` and confirm the outcome matches, so the shipped fixtures were vetting the
  corrected skills as **wrong** — and a reviewer trusting them would have an agent
  *perform* a `validate → done` transition `ISSUE-WORKFLOW.md` reserves for the PO. Both
  now expect `Human decision required` with a propose-only action, and both name
  performing the transition as a `Must not`. (The prior round's claim that `/steer:status`
  was "the last surviving outlier" was wrong: these two were.)
- **Fixed:** `fixtures/managed-block/README.md` asserted its transform fixtures "**all**
  model the **same** operation" — the canonical whole-block rewrite to `## Outcome` /
  `Updated by agent.` — which is true of only **two** of the five pairs on disk.
  `epic-link-child-feature` appends a child ref *inside* the block and keeps the existing
  `## Outcome`; `human-form-normalization` appends the block *below* a preserved human
  body; `schema-migration` rewrites frontmatter markers *outside* it. Applying the
  documented operation to those three cannot reproduce their `.expected.md`, so a reviewer
  following the README reads three conformance fixtures as broken. The index table also
  carried four rows for five pairs — `epic-link-child-feature` was listed nowhere and
  referenced by no file in the repo. Each row now names the operation it models, and the
  missing pair is listed.
- **Fixed:** `/steer:status`'s next-actions block had two further defects, both exposed by
  this cycle's correction to its acceptance row. (1) Open `owner: product` **blocking**
  questions were categorized `Recommended`, which `NEXT-ACTIONS.md` reserves for work that
  is "neither blocking nor release-mandatory"; every peer surface (`/steer:next`,
  `/steer:questions`, `/steer:issues`) calls that state `Blocking now`. The
  mis-categorization was inert while both rows sat at the same level — raising the
  acceptance row to `Human decision required` made it load-bearing, so a client report
  with unanswered blocking product questions would have headlined "the PO confirms
  acceptance" instead of "hand the client the questionnaire". Now `Blocking now`. (2) The
  acceptance row inherited `/steer:work`'s remedy without its **"PR merged"**
  precondition, while its own trigger (`implemented`, i.e. issue `validate`) also covers
  the PR-still-open half that `work` and `next` route to "a reviewer reviews". Split into
  two rows on that precondition.
- **Fixed:** `/steer:status`'s next-actions row for a feature `implemented` but not
  `validated`/`live` named **`/steer:spec validate <id>`** as the command that "confirms
  acceptance". `validate` is a read-only, GitHub-independent lint over the open-question
  contract (`spec/MODES.md`) — it advances no state, and no `/steer:spec` mode writes
  `implemented → validated`; `ENUMS.md` derives those from the issue's `steer:state` and
  `ISSUE-WORKFLOW.md` marks `validate → done` propose-only, PO-owned. So the row forced a
  command that cannot perform the action it was named for — exactly what
  `NEXT-ACTIONS.md`'s "Never force a command" clause forbids, in a block `/steer:status`
  itself declares it emits *per* that contract. Recategorized to **Human decision
  required** with the PO named as the actor and `/steer:work resume #N` offered as the
  genuine follow-up, matching the identical correction already made to `/steer:next`'s row
  earlier in this cycle. `/steer:status` was the last surviving outlier.
- **Fixed:** the PO hand-off was documented as *always* ending in a PR on two surfaces —
  `docs/getting-started/team-onboarding.md` ("opens a PR for a developer to review", "your
  build ends at a **PR for dev review** by design") and the launch checklist's PO dry-run
  item ("idea → preview → PR for dev review"). `/steer:build` **offers and recommends solo
  trunk** when the PO is the sole contributor (no `feat/*` branch, no v0 PR; hand-off is
  graduation via `/steer:protect`), and `docs/workflows/build.md` already carried the dual
  account — so a solo-PO dry run walked the checklist to an outcome the checklist called
  wrong. Both surfaces now state both shapes. Also corrected the root `README.md`, the last
  place still annotating `/steer:doctor` as "*usually via setup*" — rule `00-router`, the
  `setup` skill, and `docs/reference/skills.md` all say the opposite (reached from
  init/build; `setup` only *surfaces* the gap).
- **Fixed:** `spec/PRODUCTIONIZATION.md`'s `## Open questions` seed was restructured from a
  bracketed bullet to a `### Q-NNN` field block earlier in this cycle with **no ledger
  entry**, and reconciliation *provably* cannot carry it: the diff helper extracts anchors
  with `grep -hE '^(#{2,3} |- \[)'` and then drops every `steer:placeholder` line, so the
  new `### Q-001` anchor is stripped from the bundled side, the new prose is not an anchor,
  and the old bullet already exists on the consumer's side — the comparison output is
  empty. Every already-materialized `PRODUCTIONIZATION.md` therefore keeps a seed
  modelling the one shape neither the SessionStart hook nor `/steer:questions` counts,
  which is the exact defect the restructure was for. Added as a fifth `### v3.24.0` entry.
- **Fixed:** the CI "no test contract → fail" guard was **self-satisfying**. It grepped
  every `package.json` for a `"test"` script, and the scaffold's own root `package.json`
  ships `"test": "pnpm --recursive --if-present run test"` — a fan-out, not a contract. So
  a freshly bootstrapped Node repo passed the guard with zero real tests and
  `pnpm run test --if-present` no-opped to green — in a solo-trunk repo, where rule
  `50-definition-of-done` leans on CI as the **only** automated backstop (it names the
  changed-line coverage gate and the spec-drift warning; this guard sits alongside them in
  the same `ci` run). The guard now requires at least
  one `test` script that is not a pass-through fan-out. **Consumer-visible:** because the
  Node phase activates as soon as a root `package.json` exists, a freshly bootstrapped repo
  now has a red `ci` until some package defines a real `test` script. That is the guard
  working as documented; the scaffold README said the opposite ("before any app exists,
  only the hygiene phase runs") and has been corrected.
- **Fixed:** the always-on infra rule mandates S3 remote state with the native
  `use_lockfile` lock, while `infra/README.md` — installed on a nested `/infra` dir inside
  a monorepo, which is **distinct from** the `infra` profile — told the reader to bootstrap
  an S3 **+ DynamoDB** lock table. Corrected in both places it appeared.
- **Fixed:** `/steer:next`'s next-actions table still categorized "PR merged but issue
  still `validate`" as *Blocking now* with a bare reconcile, after `/steer:work`'s
  identical row was corrected to propose-only — and `/steer:next` is the surface that
  *arbitrates* across workflows, so the two shipped opposite categories for one state.
- **Fixed:** the `spec/sources/` member exclusion reached `adopt/PROCEDURE.md`, `init` and
  `MANIFEST.md` but not `adopt/SKILL.md` — whose topology section is read *before* the
  phase map and whose "everything else in the phase map is unchanged" clause turned the
  omission into an affirmative licence — nor `/steer:sync`'s "absent by design" list.
- **Fixed:** the scaffold `mise.toml` told any "product without a database" to delete
  `compose.yaml`, two ways wrong: the licensing condition is *no local backing services*
  (an app running Redis but no DB was being told to delete it), there was no profile gate,
  and it contradicted its own file seven lines later. It now states the condition, the
  profiles, and the `docker:*`-prune coupling.
- **Fixed:** `ISSUE-WORKFLOW.md` told the reader to promote a spec question to a
  `source:spec-question`-labelled issue. `spec-question` is a `steer:kind`, `spec` is the
  source, and kind is never a label — so GitHub silently dropped it. Same class as the
  `source:po` fix earlier in this cycle.
- **Fixed:** the round-4 grant letting a `library`/`cli` delete `scripts/worktree-env.sh`
  was **unreachable for exactly those profiles**: `worktree-port-isolation` falls to `n/a`
  only when the stack is `none`, which a Node/Python package never is, so the scanner
  reports `absent` and `/steer:sync` re-creates the file every run, forever. Scoped that
  half of the permission back to `infra` (whose stack *can* be `none`) and said why, in
  the manifest and on the docs site. The `compose.yaml` half stands for all three.
- **Fixed:** `AUTHORING.md` — the surface an author consults when scoping a gateway —
  understated **both** gateways' caller sets, and `docs/concepts/authorization-model.md`'s
  helper-grant list omitted three real grants (`template-reconcile.sh` in
  `/steer:spec-scaffold`, `scan-capabilities.sh` + `scan-invocations.sh` in `/steer:sync`)
  while reading as exhaustive.
- **Migration coverage — one entry written, four still owed and deliberately NOT written
  here.** The one written is the scaffold `infra/README.md`'s **S3 + DynamoDB → native
  `use_lockfile`**
  prose rewrite: it is a *procedural* replacement in `templates/scaffold/infra/README.md`,
  squarely inside the ledger's own stated scope ("a documented command in a profile
  `README.md`"), so it needed no convention call and is now a `### v3.24.0` entry — with a
  guard that keeps the transform to the prose and hands any *live* backend migration off
  a DynamoDB lock table to the dev as separate, reviewed infrastructure work. The four
  still owed are non-additive changes to *materialized* files that this cycle shipped
  greenfield-only: (1) `ci.yml`'s `branches: [main]` → `[main, prod]`, (2) `ci.yml`'s
  test-contract guard rewrite, (3) the infra profile's three `docker:*` task tables, and
  (4) the scaffold root `mise.toml`'s prune instruction — "products without a database
  delete the `db:*` tasks **and `compose.yaml`**" replaced with a conditioned version.
  **(1) and (2) need a convention call the release PR should make, not this branch:** the
  ledger's scope sentence covers `templates/spec/` and `templates/scaffold/` —
  **`templates/github/` is neither**, yet every file in it is materialized in a consumer
  repo, which is precisely how `ci.yml` slipped through twice. Decide whether the
  mandate's scope becomes "any materialized template", then write both. **(3) and (4) do
  *not* need that call** — both are inside `templates/scaffold/`, and (4) is a procedural
  instruction a human executes, so by the same grounds the `infra/README.md` entry was
  written on it is already in scope; (3)'s open question is narrower (does a TOML
  task-table addition need an entry at all, given nothing deterministic carries one).
  Both were left for a human because this branch's threshold was blockers + high and each
  new ledger entry this loop wrote produced follow-on defects in the next round. Until all
  four land, an already-adopted repo keeps the `main`-only CI trigger while
  `/steer:protect` requires `ci` on `prod` — the "blocked forever" state, still live for
  existing repos — keeps the self-satisfying test contract, so its `ci` can stay green
  having run no tests, and keeps a licence to delete `compose.yaml` while rules
  `24-worktrees` / `99-end-of-session` still mandate `mise run docker:clean`. Note that the
  "**Consumer-visible:**" note on the test-contract bullet above describes only the
  greenfield effect; unlike its two sibling bullets it carries no "greenfield only"
  caveat, and adopted repos do not receive the guard at all.
- **Fixed:** the spine-resolution ladder in `spec/PRODUCT.md` was rewritten earlier in
  this cycle with **no ledger entry**, and nothing could carry it:
  `template-reconcile.sh` anchors on headings and checklist items, so a rewritten
  numbered item under an unchanged `## Resolving the spine` heading offers no anchor at
  all. Every already-materialized member therefore kept the directory-only test — and
  from a linked worktree the recommended relative `..` resolves to a real but **empty**
  directory, so the test passed, the spine read as present, and every skill resolving
  it saw an empty tree and reported the product's specs as absent. Added as a
  fourth `### v3.24.0` in-file token rewrite.
- **Fixed:** `/steer:init` still installed `spec/sources/README.md` into a polyrepo
  member, which rule `22-housekeeping` forbids — the round that fixed this for
  `/steer:adopt` swept only one of the two bootstrap doors, and `MANIFEST.md`'s member
  "minus" list did not subtract it either. All three surfaces now agree.
- **Fixed:** `SPEC-FRAMEWORK.md` — the reference that *defines* the additive-vs-non-
  additive split, and so the place an author decides whether an entry is owed — still
  stated the superseded "rename, move, or deletion" mandate. It now names all the
  non-additive classes and carries the same "can additive reconciliation carry it?"
  test as the ledger. `CAPABILITIES.md`'s three-axis ownership row had the same stale
  parenthetical, and `/steer:sync`'s **Guardrails** authorized only three classes —
  which mattered more than it looks: Guardrails are front-loaded to survive
  compaction, so under compaction the surviving instruction forbade the re-take the
  skill's own step 4 must perform.
- **Fixed:** the promoted-question ledger entry pointed the applier at a
  `## Traceability` section of `spec/tracker.md` that does not exist (the text lives
  under `## Conventions (summary)`) — the same "named region absent from the file"
  defect that made the `COMPOSE_PROJECT_NAME` entry a no-op. The ledger mandate also
  now states explicitly that a comment or prose line **only describing** behaviour is
  below the bar, closing an ambiguity that would otherwise be re-litigated every
  audit.
- **Fixed:** the `ws:` entry's README step named only the quickstart, leaving two of
  the three `mise run dev` occurrences stale in a migrated workspace repo, and no step
  carried the `ws:dev` task **description** — whose old text claimed it boots "every
  member's dev server", one of the seven surfaces that overclaim was corrected on.
- **Fixed:** `MANIFEST.md` disclosure gaps around the compose/worktree pair: the
  `scripts/worktree-env.sh` row still called it "core for every profile" while three
  shipped surfaces grant an `infra` repo permission to delete it, and the new
  `library`/`cli` prune coupling presupposed a `compose.yaml` deletion that both the
  compose row and the Layer-0 heading restricted to `infra`.
- **Fixed:** the `ISSUE-WORKFLOW.md` Status↔state crosswalk — which declares itself
  the single authority and is what spec `Status:` is *derived* from — said `validate`
  means "PR merged" while the transition table in the same file reaches `validate` on
  PR **opened**. Every feature with an open PR was therefore deriving the wrong
  `Status:`. Relatedly, `/steer:work`'s next-actions table made "reconcile to `done`"
  a *blocking* agent action off a merged PR alone, contradicting both the propose-only
  `validate → done` transition and the same file 80 lines earlier.
- **Fixed:** `NEXT-ACTIONS.md` forbade a `Suggested command` for "a PO approving an
  intent" while its own category table 170 lines earlier declares that gate promptable
  and "a real command" — `/steer:spec approve` exists. Only an out-of-session approval
  is command-less.
- **Fixed:** `/steer:audit`, `/steer:help` and `/steer:roadmap` descriptions asserted
  "Renders an Artifact …" as an accomplished capability while all three bodies make it
  an explicit **offer** that is never auto-published — and the description is the
  routing surface. Now "Optionally renders".
- **Fixed:** both internal gateways' declared caller sets understated their blast
  radius: `/steer:spec-scaffold` omitted `/steer:intake` (which routes to it directly,
  before `/steer:spec`), and `/steer:tracker-sync` omitted `/steer:init` and
  `/steer:adopt`, which invoke `bootstrap-fields` by name — both **write**-path
  callers. Corrected on all three surfaces each.
- **Fixed:** `/steer:doctor`'s manual floor omitted `git`, so the floor did not
  actually support the claim made for it — installing git is a `sudo`/host command the
  skill presents rather than runs. Also corrected "the steer marketplace" (the plugin
  is `steer`; the marketplace is `e22-plugins`) and `/steer:build`'s matching
  hand-over sentence.
- **Fixed:** the scaffold's `.gitignore` ignored `.vscode/mcp.json` — the very file the
  install map ships so **Copilot/VS Code teammates get the plugin's MCP servers**
  (Copilot does not read the Claude-only `.mcp.json`). It was installed and then made
  uncommittable, so no teammate ever received it, and the markitdown migration greps a
  consumer's committed copy that could not exist. Now un-ignored alongside
  `extensions.json` and `settings.json`.
- **Fixed:** `MANIFEST.md` told a `library`/`cli` repo to prune `docker:*`/`db:*` while
  `compose.yaml` stays core for every profile — so a repo that pruned but kept the
  compose file lost the `mise run docker:clean` that rules `24-worktrees` and
  `99-end-of-session` mandate. The prune is now coupled to deleting `compose.yaml`,
  the same coupling the `infra` profile already states.
- **Fixed:** `/steer:issues capture` applied a `source:po` label that the canonical
  taxonomy does not define, `bootstrap-labels` never creates, and `issue_source` has no
  value for — GitHub silently drops an unknown label, so agent-captured issues landed
  unsourced. It now applies `source:human`, matching the same file's own `triage` step
  and every shipped Issue Form.
- **Fixed:** `/steer:adopt` gave a polyrepo member a `spec/sources/` home that rule
  `22-housekeeping` forbids creating locally (it is the workspace's, like
  `spec/reference/`) — the skip list named only three artifacts.
- **Fixed:** the `COMPOSE_PROJECT_NAME` ledger entry added earlier in this cycle was a
  **silent no-op on every repo it targeted**. Its region ran from the `# ---  Compose
  project name` banner to the export, but the new naming logic branches on
  `_wt_linked` — a variable *this same change introduced*, sitting **above** that
  region, which the entry then forbade touching. Applying it left `_wt_linked` unset,
  so the linked-worktree branch could never fire and the repo kept the colliding bare
  basename; worse, the precondition (`_wt_owner`, which *is* inside the region) then
  reported the migration as applied, so it never re-fired. The banner it named as the
  start anchor also does not exist in the file being transformed — it arrived with the
  same change. The region now spans the whole worktree-identity plumbing block, bounded
  by two lines byte-identical in both versions (the `_wt_root=$(git rev-parse
  --show-toplevel …)` assignment and the `export COMPOSE_PROJECT_NAME=` line), and
  carries the `_wt_linked` derivation and the port-offset block with it.
- **Fixed:** the ledger's **normative mandate** still required an entry only for "a
  rename/move/deletion", naming neither in-file token rewrites nor the re-take classes
  — while its scope sentence listed all five. That gap is the mechanism behind two real
  coverage misses this cycle. The mandate now covers any non-additive transform and
  states the actual test: **not "did a file move" but "can additive reconciliation
  carry it?"** — reconciliation splices in what is missing and never rewrites, so
  replacing an existing line in a materialized file needs an entry just as much as
  moving the file does, and a procedural instruction a skill or human then follows is
  squarely in scope.
- **Fixed:** the promoted-question rule reversal never got a ledger entry, so an
  already-adopted repo kept `spec/tracker.md` telling it to **replace the question with
  the ref** — the opposite of the current mechanism, and a guaranteed
  `/steer:spec validate` failure, since validate fails a promoted question with no
  `tracker:` ref back. `spec/tracker.md` is materialized at bootstrap and is the file
  `/steer:tracker-sync` reads first every run, and reconciliation is additive-only, so
  nothing could have replaced the sentence. Added as an in-file token rewrite, with a
  step for the repo that already deleted blocks under the old rule (report the orphaned
  `steer:question-id` issues; never invent the blocks back).
- **Fixed:** the `ws:` rename entry rewrote the far less consequential `mise.toml`
  `[env]` comment but not the workspace **README's quickstart command**, so a migrated
  workspace repo documented `mise run dev` — a task its `mise.toml` no longer defines.
  The entry now also covers `README.md`, `compose.yaml` and `.worktreeinclude` (same
  pairs, same profile gate), and skips any a consumer has visibly reworded.
- **Fixed:** the `steer-reviewer` caller-list fix reached the agent body but not two
  further surfaces: `MANIFEST.md`'s agent row named two callers, and the **generator's
  own hardcoded preamble** named one — so the generated Copilot agent contradicted
  itself nine lines apart. Both now name the delegating set, and the preamble no longer
  hardcodes a single prompt.
- **Fixed:** the `COMPOSE_PROJECT_NAME` change earlier in this cycle
  (`<worktree>` → `<repo>-<worktree>` for a linked worktree) shipped with **no ledger
  entry**, so it could never reach an already-scaffolded repo: additive
  reconciliation never rewrites an existing assignment, and
  `worktree-port-isolation` is `Verbatim: no` with a *create*-only repair — meaning
  the cross-repo `docker:clean` bug it fixes stayed live everywhere the fix was most
  needed, and its destructive precondition ("tear the stack down first, or the old
  containers and volumes are orphaned") reached nobody. `MIGRATIONS.md` now carries
  the entry, as a **whole-section** re-take rather than a whole-*file* one: the
  host-port baseline below the region is explicitly the product's to adapt, so
  replacing the file would have discarded real customization. Step 1 of the action is
  the tear-down. **The region this bullet first described was wrong and was rebounded
  later in this same cycle** — read the shipped ledger, not this bullet, for the
  current boundaries.
- **Fixed:** `/steer:protect`'s `apply` step emitted
  `"required_status_checks":{"strict":true,...}` while `policy/branch-protection.yml`
  — the file the skill exists to diff and apply — declares `strict: false` for both
  the default branch and the `prod` entry. Since `apply` then re-runs the verify
  diff, every application ended by reporting `strict` as drifted on the branch it had
  just "fixed". The example body now matches the policy, and the step says plainly
  that every **policy** value comes from the policy file rather than from the
  illustration, the way the `ci` context name is already resolved from the workflow
  (`restrictions: null` is the one exception — the API requires the field and the
  policy does not carry it). The policy's
  own prose was the other half: two comments claimed the branch must be "up to date
  before merge", which is exactly what `strict: false` disables — corrected in both
  the plugin copy and the byte-identical scaffold copy.
- **Fixed:** the fourth migration action class added earlier in this cycle covered a
  whole-*file* re-take, but the same entry's step 5 replaces a whole commented
  **section** of `mise.toml` — so the procedure still had no authorized shape for a
  step it must run. The class is now **whole-file or whole-section re-take** in both
  `MIGRATIONS.md` and `/steer:sync`, and a section re-take must state its region
  boundaries so the replacement is bounded and re-runnable. The ledger's own scope
  sentence and its copy-me new-entry template now name the class too, so an author
  writing the next entry can find it.
- **Fixed:** `steer-reviewer`'s body told the spawned reviewer it was invoked by
  three callers while its own `description` — and every mirror repaired earlier in
  this cycle — names four. The `/steer:loop` caller was missing from the one surface
  the agent actually reads at runtime, and it is the caller whose fan-out is
  *unconditional*, so it is the one a reviewer cannot infer.
- **Fixed:** the shipped CI workflow never triggered on a PR targeting `prod`, while
  `policy/branch-protection.yml` makes `ci` a **required status check** on that
  branch — so the promotion PR that rule 52 calls *the* production gate blocked
  forever on a check that could never report. `ci.yml`'s `pull_request.branches` now
  includes `prod`. `/steer:protect`'s existing guard only covered the
  absent-*workflow* case ("must match the check-run GitHub actually reports"), not a
  present workflow whose triggers exclude the branch. Fixed by making the workflow
  match the declared policy, not by dropping the requirement: rule 52 names the
  `prod` approval as the production gate, and the policy additionally requires `ci`
  there — so removing the required check to unblock the PR would have quietly
  narrowed the gate instead of repairing it. **Greenfield only:** changing
  `branches: [main]` to `[main, prod]` is a value *replacement*, which additive
  reconciliation cannot express, and `drift-gate`'s wired-when only checks that
  `ci.yml` invokes the pin scanner — so an already-adopted repo keeps the `main`-only
  trigger and still hits the deadlock. A ledger entry is owed but not yet written:
  see the "migration coverage" note below.
- **Fixed:** the **infra** profile's root `mise.toml` replaces the core one but
  defined no `docker:up` / `docker:down` / `docker:clean`, while still shipping the
  core `compose.yaml` and sourcing `scripts/worktree-env.sh` — so rules `24-worktrees`
  and `99-end-of-session`, which inject in any code project and mandate
  `mise run docker:clean` before removing a worktree, named a task an infra repo did
  not have. (Rule 24 carves out only the **workspace** profile's `ws:` prefix.) The
  three tasks are now defined in the infra profile too, identical to the core
  definitions. This is the same rule-vs-scaffold mismatch already closed for the
  workspace profile; the infra profile was not swept at the time. **Greenfield only for
  now:** an earlier draft of this entry claimed reconciliation would splice the tables
  into an already-adopted infra repo — that is wrong. The diff helper anchors on `##`
  headings and `- [` checklist items, and the structured merger handles only
  `.gitignore`-shaped and JSON files, so **nothing deterministic carries a TOML task
  table**. `/steer:sync`'s step-5 file list does name `mise.toml` tasks, so a model may
  splice them by judgment, but that is unbacked by an anchor or a forcing command.
  Whether this needs a ledger entry is an open call for the release PR — see the
  "migration coverage" note below.
- **Fixed:** `MIGRATIONS.md` and `/steer:sync` authorized exactly three migration
  action shapes — `git mv`, `git rm`, and an in-file token rewrite enumerating
  old→new pairs — but the `ws:` entry's `scripts/ws.sh` step is none of them: it
  re-takes a whole file whose content moved past any enumerable pair set. Both files
  now name a fourth class, **whole-file re-take** — *later widened in this same cycle to
  "whole-file **or whole-section** re-take"; read the shipped ledger, not this bullet* —
  in the same vocabulary: the
  current template replaces the file wholesale, still read-then-propose (show the
  diff, never a blind overwrite), carrying the consumer's own edits forward, and
  reserved for files additive reconciliation cannot reach and that are not
  `verbatim` capability files. Without the named class the step was unauthorized by
  the very procedure that has to apply it.
- **Fixed:** the qualification added to `MANIFEST.md`'s Layer-0 heading was itself
  incomplete — it named two Layer-2 substitutions when there are **three**: the
  `workspace` profile also **replaces the core `README.md`**, disclosed only 145 lines
  later in its own row, with the Layer-0 row silent (unlike the `mise.toml` and
  `compose.yaml` rows, which do carry the override note). So the heading's own "read
  the row" escape clause did not rescue that case. It also read as a cross-product
  attributing a `compose.yaml` substitution to `infra`, which only *deletes* it.
- **Fixed:** the `ws:` migration entry's `monorepo_root` step scoped its move to the
  commented **block** when the defect spans the whole commented **section**. Baseline
  repos carry ~15 lines of explanatory prose directly above that block which say to
  "UNCOMMENT both blocks" and to set `[monorepo].lockfile` "EXPLICITLY … `false`" —
  both reversed by the current template, which leaves the key unset because the pinned
  mise release rejects it outright. Moving the block alone left that prose sitting
  below `[settings]`, re-introducing the exact advice the step drops one line earlier,
  and additive reconciliation can never rewrite a comment. The step now replaces the
  whole section. Its stated failure mode was also wrong in the safe direction: a
  moved-but-unreshaped block declares `[settings]` **twice**, so mise fails to parse
  the config at all rather than silently ignoring an unknown field — corrected, along
  with a branch for a repo that already enabled monorepo mode by hand.
- **Fixed:** `/steer:standards`' corrected description created a fresh contradiction
  in the other direction. "All `rules/*.md`, including the scope-gated ones a session
  may not carry" only has content on Claude Code — the one surface whose `when_to_use`
  and body both say the hook injects automatically and *you don't need this skill*.
  The withheld rules are withheld deliberately (`inject-standards.sh`: dead weight
  where they can't apply), so the description is the side that was wrong; it now leads
  with the surface the skill is actually for and states the all-rules read as fact.
- **Fixed:** the retired `/steer:doctor` over-claim survived in `INVOCATION.md`, the
  one **shipped** surface among its mirrors — "with a yes, installs what's missing"
  after naming git/mise/Docker, when the skill installs only mise and the runtimes it
  manages (git is a sudo command handed over, Docker a GUI app). That file is read via
  `RECONCILE.md`'s invocation-hygiene step, so the claim was reaching consumer repos.
  The same string also stood in the README's public inventory, `docs/reference/skills.md`,
  and `docs/concepts/authorization-model.md`, which additionally cited
  `xcode-select --install` — the *git* handover — as an example of what doctor installs.
- **Fixed:** `steer-reviewer`'s fourth caller reached the agent but not its mirrors:
  `docs/reference/agents.md` (twice), `docs/workflows/index.md`'s loop step list,
  `docs/concepts/copilot-support.md`, `CLAUDE.md`'s layout comment, and the shipped
  `templates/reference/CONTEXT-HYGIENE.md` — whose subagent list is explicitly "(all
  reviewer delegations)" yet named only the two `--reviewed` paths — all still named
  two or three callers, omitting the `/steer:loop` workflow rule 53 **mandates** routes
  through it.
- **Fixed:** the `ws:` migration entry listed its steps with a dependency **after**
  its dependent — the `run[0]` swap points a task at `ws.sh preflight`, a subcommand
  a 3.23.0 `ws.sh` does not have until the re-take step runs. Harmless in practice
  (a migration lands as one atomic PR, so the intermediate state is never exercised)
  but wrong to read; the re-take now comes first. Also, `MANIFEST.md` opened Layer 0
  with the flat claim "Core is profile-agnostic: every profile installs all of it",
  which its own table contradicts three rows later — the `infra/*` rows are
  `Conditional:`, and `infra`/`workspace` substitute their own `mise.toml` /
  `compose.yaml`.
- **Fixed:** the `ws:` migration entry's `monorepo_root` step said to move the
  commented block "contents unchanged", which would have **reproduced the very bug the
  step exists to fix**. The pre-change block is headed by its own commented
  `# [settings]` line, so moving it intact above the real `[settings]` still leaves
  `# monorepo_root` nested under a commented `[settings]` — and the file's own
  instruction is "uncomment in place", so the dev ends up with
  `settings.monorepo_root`, which mise rejects as an unknown field, leaving monorepo
  mode permanently off. It also dragged along `# lockfile = false`, which current
  guidance says to leave unset because the pinned mise release rejects the key. The
  step now spells out exactly which lines to re-insert and which two to drop.
  Relatedly, the entry claimed `ws:dev`'s `depends` was "the one" intra-file reference
  to a renamed task; there are **three**, and the two commented ones matter — the
  copy-paste `depends` template the dev extends when enabling monorepo mode, and an
  `[env]` reference to `mise run dev` — while the accompanying "change nothing else
  inside any task body" actively forbade fixing the first. Additive reconciliation
  cannot rewrite an existing comment, so the migration was the only thing that could.
- **Fixed:** the `ws:` migration entry's `run` step was wrong in **both** directions
  before this, because the ledger is **release**-relative and the two earlier attempts
  reasoned **commit**-relative. A repo scaffolded at 3.23.0 has a two-element
  `docker:up` `run` whose `run[0]` is an inline `docker compose config … || { printf
  … }` guard — and that guard's own message names the **unprefixed** `docker:*` / `dev`
  tasks, so it is exactly the stale vocabulary this rename exists to remove.
  `sh scripts/ws.sh preflight` did not predate the rename for that consumer; it
  arrived inside this same unreleased cycle. So the first attempt ("repoint the
  `run`") would have replaced the whole array and dropped the
  `docker compose up -d --wait` that starts the stack, while the second ("leave every
  `run` alone") left the stale guard in place and made step 5's stated reason —
  re-take `ws.sh` *for the `preflight` subcommand `ws:docker:up` calls* — unmet by
  step 3. Neither additive reconciliation nor anything else could recover it: the
  migration is the only mechanism allowed to replace an existing string. The entry now
  enumerates `run[0]` as the one old→new pair and says explicitly to leave `run[1]`
  alone.
- **Fixed:** three skill `description`s that understated or misstated their own
  behavior — the always-on routing surface — landed as a **length-neutral set** (+1
  char across the three), so the ratchet did not move to accommodate them. The listing
  stood at **11,882 of the then-current 11,900** — the other +16 is the
  `@github-handle` trigger restored to `init` (below), not these three. (That margin
  is what later prompted the re-arm to 12,400 recorded below.) `questions` claimed
  only "folding decisions back into the spec" while its step 1 **unconditionally
  deletes** a legacy `spec/SPEC-QUESTIONS.md` before answering anything and step 6
  **opens a GitHub issue**; `standards` said that in Claude Code it "only repeats" the
  injected rules, false wherever injection is `inject-when`-scope-filtered — 22 of the
  35 rules are gated, and the skill reads all 35, so on a knowledge-work folder it
  loads 22 the session never had; `doctor` advertised installing **git and Docker**,
  which its own manual floor says it cannot (git is a sudo command handed over, Docker
  a GUI app), against a frontmatter that grants no install verb for either.
- **Fixed:** `/steer:tidy`'s known-dirs list omitted `policy/` — six of the seven
  rule `22-housekeeping` names. `policy/` is Layer-0 core scaffold present at the root
  of every managed repo (it holds the version pins and the branch-protection data
  `/steer:protect` reads), so a sweep driven from the skill summary alone could
  classify it as a stray and move it. Same omission class as the missing `scripts/`
  entry a previous rules-ceiling raise was spent fixing.
- **Fixed:** the `steer-reviewer` agent enumerated its callers exhaustively and left
  out the one rule 53 **mandates** — the `/steer:loop` scheduled workflow, whose
  split-ideation-from-verification step routes the check through exactly this agent.
  Symmetrically, `/steer:loop`'s description advertised drafting "in **reviewed**
  worktrees" while its body's own summary of the loop never mentioned a review step
  at all, leaving the mandated gate visible only in the workflow template's prompt.
- **Fixed:** the README inventory under-described eight skills' shipped surface,
  worst of all omitting **`/steer:work --hotfix`** entirely — the one
  incident-response path steer advertises, with its own always-on rule and its own
  `/steer:help` journey group, invisible in the public inventory. Also added
  `spec clarify`, `questions bundle`, `intake clarify`/`status`, `sync --check`,
  `roadmap`'s no-arg preview + `sync`, `adr accept <n>` (the only Proposed→Accepted
  path), and `loop verify`/`remove`.

- **Fixed:** the trunk-push claim corrected in rule `45` was still standing, in the
  same wrong form, in the two places that carry it to a reader. `GATES.md` said
  "each one waits for a human yes" **and attributed it to rule `45` by name**, so
  `/steer:reference gates` contradicted the rule it cited; the shipped scaffold
  `README.md` told every consumer the hook "surfaces each push", disagreeing with the
  scaffold `CLAUDE.md` beside it. Rule 45 also now states the **Copilot** caveat
  inline — the repeat push there is a *silent allow*, not a reminder, because
  Copilot's `PreToolUse` envelope has no non-blocking channel — following rule
  `10-stack`'s precedent for surface-scoping in the rule itself, since the generated
  `copilot-instructions.md` is byte-gated against the rule and only the rule can put
  the caveat in front of that reader. `docs/concepts/copilot-support.md` claimed "the
  same hook logic runs on both surfaces", which is what made the gap invisible.
- **Fixed:** `/steer:tracker-sync` destroyed the question it was promoting. It said
  to "**replace the question with the ref**", while `/steer:questions`,
  `ISSUE-WORKFLOW.md`, and `SPEC-FRAMEWORK.md` all require the `### Q-NNN` block to
  **survive** promotion — the spec `tracker:` ↔ issue `<!-- steer:question-id -->`
  pair is the bidirectional link, and `/steer:spec validate` **fails** a promoted
  question with no `tracker:` ref. So the gateway's own instruction produced an
  immediate validation failure and broke marker-based dedup. It now writes the ref
  into the `tracker:` field and keeps the block.
- **Fixed:** `/steer:questions`' legacy-checkbox sweep was **unscoped**, and would
  have rewritten the PO gate. The prose said "under `## Open questions`" but the
  command was a bare `grep -rn '^- \[ \] '`, which on any template-instantiated
  `intent.md` returns the four `## PO acceptance` boxes and the acceptance criteria —
  checkboxes `/steer:spec approve` **ticks** — which the surrounding steps then
  instruct converting into `Q-NNN` blocks and closing as `resolved`. The sweep is
  section-anchored again (matching `check-open-questions.sh`'s own `inq && !inblk`
  scope) with an explicit never-touch-the-gate warning. The "Done when" criterion
  also admitted only `resolved` or `deferred`, excluding the **still-open** outcome
  step 8 mandates and so pressuring the agent to stamp `deferred` on an unanswered
  blocking question — which drops it from the SessionStart count while
  `/steer:spec approve` still refuses it, hiding a live blocker.
- **Fixed:** the `Q-NNN` rewrite left four sibling surfaces describing the retired
  mechanism. `spec/SKILL.md` and `CLARIFICATION-LOOP.md` (twice) still said
  `/steer:questions` *strikes* the question; `questions/BUNDLE.md` still told bundle
  mode to read "not just the `- [ ]` line" and to reproduce a `grep | grep` pipeline
  that no longer exists. `templates/spec/productionization.md` — a question home the
  hook and the skill both parse — shipped its `## Open questions` seed as a plain
  bracketed bullet with no `### Q-NNN` block and no `steer:placeholder` marker, so a
  question written in the shape that template models was invisible to **both** the
  count and the sweep: the same false-clean-sweep defect, on the one seed the first
  pass did not reach. It now ships the structured seed like `feature-intent.md` and
  `vision.md`.
- **Fixed:** `ws:dev`'s "boots the whole product" claim survived in **seven** shipped
  surfaces after the docs page was corrected — the task's own `description`, the
  `ws.sh` header comment, `POLYREPO.md`'s task table, two `MANIFEST.md` rows, the
  workspace profile's `README.md` quickstart (which installs as the consumer's
  README), and the profile `compose.yaml` header. Each successive audit round found
  the surfaces the previous round's grep had missed, which is the argument for
  sweeping a claim by concept rather than by phrase. As shipped
  it is `depends = ["ws:docker:up"]`: services only, the app half requiring monorepo
  mode plus one `depends` entry per member. Also `worktree-env.sh` reassured the
  reader that "no existing stack is renamed", true only of the **primary** checkout:
  the linked-worktree rename *is* the change, so a running worktree stack must be
  torn down before the file is re-taken or its containers and volumes are orphaned
  under the old project name. Both the script comment and the CHANGELOG entry that
  repeated the claim now say so, with the `docker compose -p <old-name> down -v`
  recovery.
- **Fixed:** the shipped `dependabot.yml` header undercounted its own commented
  ecosystems (`npm` / `pip` / `docker`), omitting `terraform` — the one an `infra`
  profile repo needs, so the block least likely to be uncommented was also the one
  not advertised to the skill uncommenting it. The `MANIFEST.md` row that **is** that
  skill's install map carried the same three-item list, so the header fix alone left
  the stated rationale unmet on the surface that matters most.
- **Fixed:** the Copilot silent-allow caveat added to rule `45` reached the rule and
  the generated Copilot instructions but not four siblings carrying the same
  sentence — `GATES.md` (which cites rule 45 by name, and is reachable on Copilot via
  the `steer-reference` prompt), `/steer:work`'s body (read natively by the Copilot
  CLI), the shipped scaffold `README.md`, and `team-onboarding.md`. Two of those had
  just been rewritten into the corrected first-push wording **in the same commit that
  added the caveat**, so the fix re-introduced the sentence without it.
- **Fixed:** `/steer:questions`' re-anchored legacy sweep claimed its grep matched
  `check-open-questions.sh`'s backlog scope "exactly". It cannot: the hook's scope is
  `inq && !inblk` plus a bracketed-placeholder exclusion, and a grep pipeline has no
  block state. So a `- [ ]` sub-task **inside** a `### Q-NNN` block was reported as a
  standalone legacy item, and step 2 would have split it into its own question,
  fragmenting the host block. The section anchor is real and stays; the in-block and
  placeholder exclusions are now stated as the reader's job rather than claimed of
  the command.
- **Fixed:** the new `ws:` migration entry told the applier to do two things that
  would have damaged a consumer repo. It said to repoint `ws:docker:up`'s `run` to
  `sh scripts/ws.sh preflight` — but that task's `run` is a **two**-element array
  whose second element (`docker compose up -d --wait`) is the only line that starts
  the stack, so replacing the whole array would have left the task unable to boot
  anything. It also said to re-take `scripts/ws.sh` **verbatim**, a mode
  `CAPABILITIES.md` reserves for the version-pin scripts alone, which would clobber a
  consumer's own `ws:` subcommand. That round's entry therefore left every `run`
  alone, stated the `monorepo_root` step as an explicit move, and made `ws.sh`
  read-then-propose. **Both of the first two were superseded by the entry above**,
  which found this correction over-swung in the other direction: `run[0]` *is* a
  legitimate old→new pair (it carries the stale unprefixed vocabulary), and the
  `monorepo_root` step needs the whole section replaced, not merely moved. Read the
  shipped ledger, not this bullet, for the current procedure.
- **Fixed:** the promoted-question mechanism corrected in `/steer:tracker-sync` was
  still stated the old way in the two surfaces that *govern* it: `templates/spec/tracker.md`
  — installed as the consumer's `/spec/tracker.md`, and the file `/steer:tracker-sync`
  reads first every run — and `TRACEABILITY.md`, which rule `35-issue-tracker` and the
  skill both name as canonical for this convention. Both said "replace the question
  with the ref", so a model consulting the authority the skill delegated to got the
  retired mechanism, and following it guarantees a `/steer:spec validate` failure.
  Found only because this round swept the *concept*; the previous round's sweep for
  the word "strike" could not match either phrasing.
- **Fixed:** `CROSS-SURFACE.md` attributed a **destructive-git** check to
  `check-bash-actions.sh`, which has never had one — its two checks are the trunk-push
  gate and the issue-create guard, and the destructive-`git` tier lives in the
  scaffold `.claude/settings.json` `ask` list. Wrong layer, in the one table whose job
  is telling a reader which gates survive the port to Copilot. `GATES.md` also still
  closed the corrected paragraph by calling the gate a "per-push permission decision",
  four lines below its own new first-push-then-reminder sentence.
- **Fixed:** `/steer:questions` swept a format the spine no longer uses, so on any
  repo scaffolded from the current template it reported a clean sweep while the
  SessionStart hook was printing a backlog in the same session. Its gather step
  grepped for `- [ ]` checkbox items and step 3 says "if there are none, say so and
  stop" — but `templates/spec/feature-intent.md` and `vision.md` ship structured
  `### Q-NNN` blocks with **no checkbox**, which is what `check-open-questions.sh`
  parses and what rule `35-issue-tracker` mandates. The sweep now reads `### Q-`
  blocks, scopes itself to `status: open|investigating`, skips
  `<!-- steer:placeholder -->` seeds like the hook does, resolves by setting
  `status: resolved` plus the `_Resolution:_` line instead of ticking a box, defers
  by setting `status: deferred`, and picks up the legacy→`Q-NNN` conversion that
  `MIGRATIONS.md` v1.38.0 assigned to this skill and no step performed. Two places
  in the same skill (`BUNDLE.md`, and the steps that read `created:`/`impact:`)
  already assumed the structured format, which is what made the stale half visible.
- **Fixed:** rule `45-commit-autonomy` overstated the trunk-push gate it owns —
  the same misstatement `/steer:protect` was corrected for below, in the rule both
  skills cite as the source. It said trunk pushes "stop being autonomous — each
  waits for a human yes"; `check-bash-actions.sh` fires that ask **once per
  session+repo** and downgrades repeats to a non-blocking reminder (a silent allow
  under `STEER_HOOK_TARGET=copilot`). `check-graduation.sh`, `/steer:work`,
  `/steer:protect`, and the hook's own fixture all already said "first push each
  session"; the rule was the lone outlier, and it is the always-on surface.
- **Fixed:** the self-fault SessionStart notice promised a confirmation step that
  rule `97-self-report` and `/steer:report` both explicitly abolish. `surface-faults.sh`
  told the agent to run `/steer:report` to "review a scrubbed bug report and (with
  your confirmation) file it upstream", while the rule says it "**auto-files** …
  no confirmation step" and the skill says "**Never pause to ask the user**" — so
  the injected text directed a pause the ruleset forbids. The notice now states the
  auto-file contract and names the scrub-by-omission as the safety floor; the same
  stale wording in `hooks/lib/report-fault.sh`'s header is corrected with it.
- **Fixed:** `scan-invocations.sh` emitted a **wrong deterministic rewrite** for
  both token shapes every pre-2.0.0 consumer repo actually carries. `standards` is
  itself a live skill name, so `/e22-standards:e22-init` and `/e22-standards:doctor`
  — the plugin's own former name qualifying the skill — matched the simple
  `/e22-<skill>` branch and suggested `/steer:standards`; `RECONCILE.md` applies a
  `legacy-e22` suggested-fix **deterministically**, so `/steer:sync` would have
  rewritten the line to the nonsense `/steer:standards:e22-init`. `MIGRATIONS.md`
  v2.0.0 has always had the correct rule — its pairs **1** and **2** both take the
  token *after* the colon — and its own false-positive guard names only `plugins`
  as the exclusion, so `standards` fell straight through. Both compound forms are
  now matched before the simple pass and the head is no longer double-reported,
  while a bare `/e22-standards` (no colon tail) still correctly resolves to
  `/steer:standards`. That head guard is **line**-scoped, so a genuine bare
  `/e22-standards` sharing a line with a compound token is not separately reported —
  recorded as an honest limitation in the script, because the alternative
  (rewriting every occurrence on such a line) would corrupt the compound.
  Both legacy passes also classified against the skill set **alone**, so they
  bypassed the two classifiers the `/steer:` pass applies: `/e22-conventions`
  degraded to `unknown` when the deterministic `/steer:reference conventions` is
  exactly right, and `/e22-standards:e22-spec-scaffold` was auto-rewritten to
  `/steer:spec-scaffold` — an invocation `INVOCATION.md` documents as **untypable**,
  produced deterministically. Both legacy passes now share one `classify_legacy`
  ladder with the `/steer:` pass, so a legacy token gets the verdict its modern
  spelling would; `INVOCATION.md`'s class table documents the compound shapes it
  had never mentioned. Nine fixtures cover all of it (517 cases, up from 508) — the
  previous suite exercised only `/e22-adopt`.
- **Fixed:** three more always-on rules promised GitHub Copilot mechanisms it does
  not have, and one skill did the same — the sweep further down claimed to have
  found "the rest of it" and had not. Rule `62-hotfix` told the agent a
  `hotfix/<n>-slug` branch makes issue-first reconciliation read the lane as
  sanctioned; that reconciliation is the `Stop` hook `reconcile-issue-first.sh`, and
  only the two `PreToolUse` gates are ported to `copilot-hooks.json`, so elsewhere
  the prefix carries the convention alone. Rule `36-issue-first` stated the
  scaffold's `allow`/`ask` permission tiers as fact when they are
  `.claude/settings.json` plus Claude skill frontmatter, and another host applies
  its own. Rule `90-design-sources` pointed at the `frontend-design` plugin, which
  `.github/plugin/marketplace.json` does not list. `/steer:questions` leaned on
  `check-open-questions.sh` for both the backlog nudge **and** the 14-day blocking
  escalation with no fallback — the one case where the missing notice silently
  disables a documented rule rather than merely withholding a convenience — so its
  body now tells any other surface to age blocking entries from `created:` itself.
  All four are recorded in `docs/concepts/copilot-support.md`.
- **Fixed:** `/steer:protect` misstated the trunk-push gate and then argued from the
  misstatement. It claimed the hook "surfaces **every** `git push` for a human yes",
  so graduating restores silent delivery; `check-bash-actions.sh` fires that ask
  **once per session+repo** and downgrades repeats to a non-blocking reminder — a
  silent allow under `STEER_HOOK_TARGET=copilot`. `/steer:work` already described it
  correctly, so two skills contradicted each other about one hook. Recommending
  graduation was right for the wrong reason; the reason is now the real one.
- **Fixed:** four more skill `description`s understated their own behavior — the
  same always-on routing surface, and the same defect class as the entry below.
  `protect` announced the `CLAUDE.md` delivery-mode marker but not the
  `/spec/HISTORY.md` append, half its local write surface; `roadmap` described only
  its writing modes, never the no-argument read-only preview; `report` said
  "auto-file via gh" when the body prefers GitHub MCP; `doctor` omitted the
  `shadowed`-runtime check the docs advertise as a headline capability. Paid for
  **inside those same four entries** per `check_context_budget.py`'s own policy — by
  cutting genuine redundancy, never a trigger phrase — so the listing landed at
  11,865 of the then-current 11,900 chars and the ratchet did not move for them.
- **Added:** a detector for the `dependency-automation` capability, plus the
  reverse-direction gate that would have caught its absence. `CAPABILITIES.md` has
  documented that capability (Dependabot + the scoped auto-merge exception) with
  full `Files` / `Wired-when` / `Repair` fields ever since it shipped, but
  `scan-capabilities.sh` never emitted it — 14 documented, 13 detected.
  `RECONCILE.md` drives the entire capability walk from that scanner's output, so
  the one capability `/steer:sync` could never see was also the one it could never
  report, propose, or repair, while `docs/reference/github-integration.md` promised
  sync "keeps both files wired". The detector reports `mis-wired` when the
  auto-merge workflow loses its `dependabot[bot]` actor guard or its `update-type`
  gating, since auto-merge not scoped to patch/minor Dependabot PRs is worse than no
  automation. The hook suite asserted only detector→doc; it now asserts
  **doc→detector** as well, so a documented-but-undetected capability fails the
  build (508 fixture cases, up from 507).
- **Fixed:** reference prose that misdescribed the tooling it documents.
  `CAPABILITIES.md`'s `profile` enum omitted `workspace`, which `steer_repo_profile`
  emits, on a page that self-describes as standing invariants; three of its 14
  entries (`node-tooling`, `github-issue-forms`, `backing-services-compose`) lacked
  the `Wired-when` field the same file declares mandatory and the detector really
  computes. `RECONCILE.md` said the scanner prints one fingerprint when it prints
  two, so a sync run would not know to report `profile`. `INVOCATION.md` announced
  two Tier-1 caveats and had three — `/steer:doctor` offers to install system
  software. Two hook nudges named an incomplete profile list. And
  `templates/docker/README.md` now records that its `.dockerignore` source is stored
  dot-less, the one shipped dot-stripped file that no manifest mapped.
- **Fixed:** the always-on cleanup command did not exist in a **workspace** repo.
  Rules `24-worktrees` and `99-end-of-session` (and the scaffold's
  `.worktreeinclude`) mandate `mise run docker:clean` before a worktree is removed,
  but the `ws:`-prefixing below renamed that task to `ws:docker:clean`, and the
  workspace profile **replaces** core `mise.toml` — so in a spine host the mandated
  command failed `task not found` and the aggregated stack it was meant to tear
  down stayed up, containers and volumes included. It worked at 3.23.0 and did not
  after, which makes it a regression the `ws:` fix introduced: `POLYREPO.md` cited
  rule 24 as the rename's motivating example without updating the rule. All three
  surfaces now name the `ws:` form, rule `15-commands` carries the workspace task
  vocabulary once (it holds no code, so it has no `dev:setup` or linters at all, and
  each member runs its own), and rule 24 cross-references it rather than restating
  it. `MANIFEST.md` records the substitution beside the "replaces core mise" note.
- **Fixed:** four always-on rules promised GitHub Copilot mechanisms it does not
  have — the same defect class as the worktree-trust entry below, found by sweeping
  for the rest of it. Rules `00-router` (a missing `/spec` spine), `05-roles` (an
  in-progress `spec/BUILD-STATUS.md`) and `97-self-report` (recorded hook faults)
  each told the agent a SessionStart hook would flag a condition; Copilot's
  `sessionStart` ignores stdout, so the notice never arrives and its *absence* reads
  as "condition not present" — worse than no promise. Rule `10-stack` claimed a hook
  **denies** stale image-major pins, which is only an `ask` on the Copilot CLI and
  nothing at all in VS Code, where there is no hook mechanism. Each rule now scopes
  the mechanism to the surface that has it and tells the others to check for
  themselves. `docs/concepts/copilot-support.md` records all four under Known
  limitations.
- **Changed:** the always-on rules ceiling moves 66,500 → 67,300 B to fund those six
  surface-scoping corrections. They are factual corrections, not new capability, so
  the alternative was shaving rationale — the trade `check_context_budget.py`'s notes
  record as wrong and reverted twice. Deduplicating the workspace task vocabulary
  into rule 15 paid back ~120 B of the cost; trimming the rest to fit under 66,500
  would have left ~16 B of headroom, precisely the margin those notes blame for
  making the last two raises inevitable, so the ceiling is re-armed at the total
  measured **when the raise landed** (66,516 B) plus ~1.2%. Later factual
  corrections in this same cycle have since grown the tree past that figure — read
  the ceiling as the ceiling, and `mise run rules:preview` (or
  `check_context_budget.py --report`) as the only current measurement. The target
  stays 62,500 B. The skill-listing ratchet
  has since been **re-armed** 11,900 → 12,400 chars — not to fund any edit below, but
  because the cycle's accumulated `description` work left it at 11,879 of 11,900 by the
  time the re-arm landed, a 21-char margin under which the next factual `description`
  fix could not be paid for in place at all. (The corrections *below* this bullet took
  it to 11,865; the last few chars came from the `/steer:standards` fix recorded
  above.) The
  corrections below *were* paid for by trimming inside those same entries, per that
  ratchet's own policy — with one exception to record honestly. Two trigger phrases were cut, not just redundancy:
  `init`'s `@github-handle` and `help`'s `"what can you do?"`. `@github-handle` has
  been **restored** — it is a blocking unresolved placeholder that `/steer:init`
  gates on and `/steer:setup` routes on, so its absence was a real routing hole.
  `"what can you do?"` stays cut **deliberately**: unqualified, it is at least as
  likely to be a question about the assistant's own capabilities as about steer's, and
  `help`'s entry retains three unambiguous triggers (`"what can steer do?"`,
  `"show me the commands"`, `"list the skills"`).
- **Fixed:** five skill `description`s did not describe what their bodies do — the
  always-on routing surface, so an unannounced capability is invisible exactly where
  routing happens (six corrections across the five; `audit` needed two). `audit`,
  `roadmap` and `help` render an Artifact
  (`templates/reference/ARTIFACTS.md` declares all three) without saying so; `init`
  never revealed that it offers and recommends **solo-trunk** mode, an entire
  delivery mode that writes a lasting `steer:delivery-mode` marker; `protect` scoped
  its writes to `gh api` when a graduation also flips that marker; `audit`'s "files
  nothing, edits nothing" contradicted its own `/spec/AUDIT-REPORT.md` write.
- **Fixed:** two skills asserted a write boundary their own bodies crossed.
  `protect` said it "touches repo **settings** only" while instructing an edit to the
  product `CLAUDE.md` delivery-mode section and an append to `/spec/HISTORY.md` — and
  because rule `45-commit-autonomy` makes that marker the cache the hooks read, an
  agent trusting the narrower claim would protect `main` and leave the repo pushing
  straight to it. `report` claimed it "never touches the product repo" while
  deleting `.claude/steer-faults.*` there; both now state the real boundary (nothing
  *tracked*, in `report`'s case).
- **Fixed:** `docs/reference/known-limitations.md` mischaracterized knowledge-work
  mode, naming six rule families as surviving when 13 of the 35 rules inject, and
  omitting that `60-high-risk` and `95-not-the-gate` are always-on despite reading as
  code-specific (rules `00-router`, `05-roles`, `32-living-docs` and `70-secrets` all
  cross-reference rule 60, so dropping it would break the rules that survive). It
  also described `SessionStart` as injection only,
  omitting the one check that mutates local state — `check-worktree-trust.sh` — on
  the page a reader consults to learn what steer can change without asking.
- **Fixed:** `check_standards.py` now derives the SessionStart roster from
  `session-checks.sh`'s own dispatch loop, not just `hooks.json`. The orchestrator
  instructs authors to add each new sub-check to the `CROSS-SURFACE.md` roster, but
  the gate only ever saw `session-checks.sh` itself, so all six children were
  ungated and a seventh would have gone unnoticed. Nothing had drifted; the
  instruction simply had no enforcement.
- **Fixed:** documentation and scaffold prose that no longer matched the shipped
  files. `docs/reference/repository-contract.md` described the workspace profile as
  adding "a `dev` that boots the whole product" — the unprefixed name that *was* the
  defect; `POLYREPO.md` and `docs/concepts/product-spine.md` wrote `ws:check` /
  `ws:preflight` as `mise` tasks when both are `ws.sh` subcommands with no wrapper
  (`mise run ws:check` fails); `MANIFEST.md`'s `ws.sh` row omitted the new
  `preflight`; `product-spine.md` claimed `ws:dev` boots the whole product when the
  app half needs monorepo mode plus a `depends` entry per member, and claimed
  *every* workspace task is `ws:`-prefixed despite the deliberate `convert:doc`
  exception; `POLYREPO.md` said Compose names "never" clash when two *primary*
  checkouts sharing a directory name still do; `ws.sh`'s own failure message still
  named the unprefixed `docker:*`/`dev` tasks; the `convert:doc` "byte-identical"
  claim was false in four places (only `run` matches — which is all
  `check_standards.py` asserts and all that is load-bearing); and
  `docs/contributing/documentation.md` understated which `hooks/lib/` contracts are
  hand-maintained, omitting `lib/scope.sh` — the file this cycle changed.
- **Added:** a `MIGRATIONS.md` ledger entry for the `ws:` rename, so an existing
  workspace repo actually receives it. The rename lands in a **materialized**
  scaffold file, and additive reconciliation splices in what is missing without ever
  renaming — so it would leave both the old and new task names in place. The ledger
  is the only mechanism that may rewrite in place, and `MIGRATIONS.md`'s own rule
  ("add an entry here in the same change that lands a rename/move/deletion in
  `templates/scaffold/`") required one. Without it, the always-on rules that moved to
  the `ws:` vocabulary in the same cycle (`15-commands`, `24-worktrees`,
  `99-end-of-session`) name tasks an already-scaffolded workspace repo does not
  define — the exact rule-vs-scaffold mismatch this cycle set out to close, fixed for
  new repos and left open for existing ones. The entry is precondition-gated to
  `workspace`-profile repos, renames only the four whole-product task headers
  (leaving `convert:doc` alone), repoints `ws:dev`'s `depends`, replaces the whole
  commented `monorepo_root` section and re-inserts it above `[settings]` (where a
  pre-change repo does **not** have it, so mise rejects the key and monorepo mode
  never turns on), and diffs in
  `scripts/ws.sh` read-then-propose — explicitly **not** a verbatim overwrite, since
  `ws.sh` is not a `verbatim` capability file and a consumer may have extended it.
  It also tells the applier to replace **only** `ws:docker:up`'s `run[0]` — the
  inline guard whose message names the stale unprefixed tasks — and to leave `run[1]`
  alone, since `docker compose up -d --wait` is what actually starts the stack.
  **Release note — this release now has SIX `### v3.24.0` ledger entries (this `ws:`
  rename, the `COMPOSE_PROJECT_NAME` prefix, the promoted-question rule, the
  `spec/PRODUCT.md` spine-resolution ladder, the `PRODUCTIONIZATION.md` open-question
  seed, and the nested-`/infra` `README.md`'s S3 + DynamoDB → native `use_lockfile` prose
  rewrite).**

  **The bump is decided: `3.24.0` — a minor.** The six ledger headings are keyed to
  it and are correct as written; **no re-keying is needed**. Had the cut landed
  anywhere else, all six headings would have had to move with it — that instruction
  was the only compensating control for the hard-coded keys, so the decision being
  settled here is what retires the risk. A patch was never available: six entries
  keyed to a version that never ships would be skipped by every consumer's stamp
  comparison forever.

  Major was the live alternative and was **considered and declined**. Weigh it
  against all six entries, not just this one — the `COMPOSE_PROJECT_NAME` entry opens with a
  mandatory destructive tear-down on the consumer side (an already-running linked
  worktree's containers and volumes are orphaned otherwise), which is the strongest
  "anything a consuming repo must react to" signal in the release. The audit that produced this entry split on that call — the letter of the
  release skill's rule ("renamed… template; anything a consuming repo must react
  to") reads major, while this repo's applied precedent reads minor: six prior
  ledger-carried scaffold/spec changes shipped as minors, including v3.23.0 itself,
  which carried both a spec-artifact rename and an MCP-server removal, and no file
  here is renamed or removed (the `ws:` change is an in-file edit to materialized
  config, which is exactly what the ledger exists to deliver). **Resolved in favour of
  the minor**, on that precedent — so the release PR inherits a made decision, not an
  open one. The consumer-facing consequences are not waived by that call: the
  `COMPOSE_PROJECT_NAME` tear-down and the `ws:` task rename both still need a release
  note a consumer will actually read, and each is carried by a ledger entry that
  `/steer:sync` proposes. Mechanically either key
  is safe — consumers skip entries at or below their `/spec/.version` stamp, and no
  stamp can sit above an unreleased version — so this is a documentation-correctness
  point, not a delivery risk. It
  replaces the hand-migration note this entry previously carried, whose stated
  premise — "there is no reconcile path for `mise.toml`" — was false:
  `RECONCILE.md` names `mise.toml` tasks explicitly, and the ledger has two
  precedents for in-file edits to materialized scaffold configs.
- **Fixed:** the worktree-trust guidance no longer promises GitHub Copilot a hook it
  does not have. `check-worktree-trust.sh` is a SessionStart check and Copilot has no
  SessionStart equivalent (its `sessionStart` ignores stdout, and only the two
  `PreToolUse` gates are ported to `copilot-hooks.json`), yet rule `24-worktrees` is
  carried verbatim into the generated `.github/copilot-instructions.md` — so a Copilot
  session started in a linked worktree read "already inherits the primary checkout's
  trust", skipped `mise trust`, and hit a trust error with nothing explaining why the
  promise did not hold. Worse than no guidance. The rule now states the `mise trust`
  step unconditionally and scopes the inheriting check to Claude Code, so both Copilot
  surfaces (CLI and VS Code, the latter having no hook mechanism at all) get an
  instruction that works. `docs/concepts/copilot-support.md` records it under Known
  limitations, and `gen_copilot_hooks.py` now states why a side-effecting SessionStart
  check still is not ported: Copilot would apply the trust but drop both human-owned
  branches of the decision. The rest of worktree isolation was already surface-
  agnostic — the per-worktree `COMPOSE_PROJECT_NAME` and port offset come from the
  scaffold's `mise` config, not from a hook.
- **Added:** `hooks/check-worktree-trust.sh` — a SessionStart check that inherits the
  primary checkout's `mise trust` into a linked worktree, so a fresh worktree is
  usable immediately instead of failing every `mise run …` until someone trusts it
  (#416). `mise trust` is path-based and a worktree is a new path, so the whole
  scaffolded dev loop — `docker:up`, `dev:setup`, `db:migrate`, the lint/test tasks —
  failed there with an error about *trust* rather than about the task, and rule
  `24-worktrees` positions parallel worktrees as normal practice (a polyrepo pays it
  per member per feature). The trigger is the scaffold's own isolation feature: mise
  loads a data-only config (`min_version`, plain `[tools]`, `[tasks]`) untrusted and
  refuses one that executes code at load time — which is exactly `[env] _.source =
  "scripts/worktree-env.sh"`, the line that gives each worktree its own
  `COMPOSE_PROJECT_NAME` and port offset. **Inheriting grants nothing new:** mise
  keys trust by path and does **not** content-hash it, so a repo trusted once has
  every later edit of its config trusted at that path — anything the worktree's
  config could execute, the primary checkout would already execute unprompted. The
  check never *creates* trust: when the primary checkout is itself untrusted the repo
  has never been set up, and it says so and changes nothing, leaving that first
  decision to the user (`mise trust && mise install`, rule `15-commands`). It is
  silent in a plain checkout (gated before `mise` is ever invoked, so the common case
  and the hook-latency budget are unaffected), outside any work tree, on a machine
  without mise, in an already-trusted worktree, and in a worktree with no mise config. Registered inside
  the existing `session-checks.sh` roster, so it costs no extra hook registration;
  fourteen fixture cases in `hooks/tests/run.sh` cover it, including both
  no-decision-to-inherit paths (an untrusted primary checkout, and a primary with no
  mise config at all because the worktree's branch introduced it) writing nothing.
- **Changed:** rule `24-worktrees` now opens with the worktree-trust step — run
  `mise trust` in a worktree before the first `mise run …`; it is idempotent, so it
  costs nothing where the new session check already inherited the primary checkout's
  trust, and that check is named as Claude-Code-only and start-of-session-only. An
  untrusted repo stays the user's call (`mise trust && mise install`). Stating the
  action unconditionally is what makes the rule correct on every surface that reads
  it: the two cases no hook reaches — a worktree created with `git worktree add`
  mid-session, and a non-Claude agent surface — are exactly the ones an always-on
  rule has to cover. The scaffold's `.worktreeinclude` header carries
  the same guidance for the plain-terminal reader, with the mechanism behind it
  (path-keyed trust, and the `[env] _.source` line that triggers it).
- **Changed:** the always-on rules ceiling moves 65,300 → 66,500 B to fund that rule
  step. The ratchet stood at **5 bytes** of headroom, so the alternative was trading
  out rule 24's own rationale — the trade `check_context_budget.py`'s own notes twice
  record as wrong and reverted. Re-armed at the measured total (65,933 B across 35
  files) plus ~1%, deliberately restoring real headroom instead of the 5-to-7-byte
  margins that made each of the last two raises inevitable; the reason is recorded in
  the gate script and `docs/reference/configuration.md` beside the two earlier
  raises. The target stays 62,500 B, so the budget report keeps showing the gap as
  work to reclaim.

- **Fixed:** the workspace scaffold's `mise.toml` leaked whole-product tasks into
  every member cloned inside it (#415). Members live at the `path:` each declares
  *inside* the workspace, and mise loads every **ancestor** config, so the
  workspace's `mise.toml` is loaded in every member and every member worktree —
  plain config-hierarchy behaviour, present whether or not monorepo mode is on. For
  a name the member also defines the nearest config wins, so the bite was names it
  does **not** define: they fell through to the workspace's file with nothing in the
  output saying the task came from another repo. Two ordinary commands became
  cross-repo surprises: `mise run dev` in a member — the most natural command in the
  repo, and one the core scaffold deliberately omits (a Node-only member runs `pnpm
  dev`) — booted the whole product's aggregated Compose stack; and `mise run
  docker:clean` in a member that ships no `compose.yaml` tore down **every** member's
  containers *and volumes*, which is exactly the command rule `24-worktrees` tells
  every agent to run before removing a worktree. Every task in
  `profiles/workspace/mise.toml` is now `ws:`-prefixed — `ws:dev`, `ws:docker:up`,
  `ws:docker:down`, `ws:docker:clean` — so nothing it defines can shadow a member's
  task, because no member scaffold defines a `ws:*` name. `convert:doc` stays
  unprefixed as the one exception, safe because its `run` command is identical to the
  core scaffold's (falling through to it is a no-op) — and a new `check_standards.py`
  guard fails the build if it ever drifts, if a new unprefixed task appears, or if a
  `depends` entry goes unprefixed. That last one is its own trap: `depends` resolves
  by name in the **caller's** task set, so `ws:dev`'s dependency had to become
  `ws:docker:up` — a bare `docker:up` bound to the *member's* task whenever `ws:dev`
  was invoked from inside a member, booting one member's services and calling it the
  product. Reachability itself was never the defect and is unchanged: `ws:*` tasks
  still work from inside a member and still act on the workspace (mise runs a task in
  its own config root), which is what `cd backend && mise run ws:status` should do.
- **Fixed:** the workspace scaffold's commented monorepo-mode block never worked as
  shipped (#415). `monorepo_root` is a **top-level** TOML key, but the block placed
  it under `[settings]`, where mise reports `unknown field: settings.monorepo_root`
  and monorepo mode silently never turns on — the warning was the only signal. The
  block now leads the file, above `[settings]`, with a note that a bare TOML key
  belongs to the table above it so it must be uncommented **in place**. Its
  `lockfile = false` line is also gone: the current mise release rejects the key
  (`unknown field: monorepo.?.lockfile`) and warns on *every* invocation, and
  per-member locks — what a polyrepo wants, since a member must stay buildable
  standalone — are already the default. With the corrected block, uncommenting now
  enables monorepo mode with zero warnings, which additionally seals bare-name
  fall-through (`mise run dev` in a member resolves as `//backend:dev`); the `ws:`
  prefixes above are what hold *before* any member is cloned, when a fresh workspace
  is most exposed. `POLYREPO.md`, `MANIFEST.md`, the workspace README/compose
  comments, `ws.sh`, and `/steer:init`'s scaffold guidance all state the corrected
  keys and the namespace invariant.
- **Fixed:** a polyrepo member's spine was unreachable from a git worktree, and
  failed **silently**. `workspace.path` is relative to the checkout it was written
  against, so the `..` that `templates/spec/product.md` recommends for a member
  cloned inside its workspace resolved from `<member>/.claude/worktrees/<name>` to
  `<member>/.claude/worktrees` — a directory that *exists*. Step 1 of the
  documented resolution ladder ("path set and the directory exists") therefore
  won, the GitHub-gateway fallback in step 2 was never reached, and every skill
  that resolves the spine from a member (`/steer:work`, `/steer:spec`,
  `/steer:next`, `/steer:intake`, `/steer:adr`, `/steer:questions`,
  `/steer:tracker-sync`, `/steer:explain`) read an empty tree and reported the
  product's specs as absent — the exact split-brain the topology exists to
  prevent, in the repos holding all the code. New `steer_primary_worktree`
  (`hooks/lib/repo-root.sh`, subprocess-free: a linked worktree's `.git` is a file
  holding the `gitdir:` pointer) anchors relative paths on the primary checkout,
  and new `steer_workspace_root` (`hooks/lib/scope.sh`) additionally requires
  `spec/workspace.yml` at the resolved path — a directory that merely exists is not
  a workspace, so the remaining failure modes fall back to the gateway instead of
  reading a wrong tree. The ladder in `templates/spec/product.md` and
  `POLYREPO.md` now states both tests, as do the three skills that restated the
  old one-test form inline rather than pointing at the ladder — `/steer:work`,
  `/steer:spec`, and `/steer:explain`, the last of which holds no `Bash` and so
  has no gateway to fall back to: it would have rendered every feature as *"not
  specified in the spec"*, the exact output its own instructions forbid.
  `steer_tracker_is_github` was the one consumer already safe here, via its
  fail-open contract.
- **Fixed:** `COMPOSE_PROJECT_NAME` collided across repos in a polyrepo, and
  `mise run docker:clean` in one repo's worktree tore down another's stack —
  containers, volumes and networks. `scripts/worktree-env.sh` derived the name from
  the worktree's basename alone, which is not unique across repos: a polyrepo runs
  the same feature branch in several members at once, so `<memberA>/.claude/
  worktrees/feat-x` and `<memberB>/.claude/worktrees/feat-x` shared one Compose
  project. Distinct port offsets did not help — the collision is in the namespace,
  not the ports — and this contradicted both rule `24-worktrees` ("it won't touch
  a sibling's stack") and the workspace `mise.toml`. A linked worktree's project
  name is now `<repo>-<worktree>`; the primary checkout keeps its bare basename, so
  **its** stack is not renamed. **Existing linked-worktree stacks are** — that is
  the rename. Tear a running one down **before** re-taking `worktree-env.sh`: under
  the new project name compose no longer sees the old containers or volumes, so they
  are orphaned (recover with `docker compose -p <old-name> down -v`).
- **Fixed:** a worktree of a **workspace** repo has no members — the clones are
  git-ignored, so a worktree populated from git refs carries none of them — and
  the tooling misreported it three ways. `mise run ws:docker:up` failed with
  "compose.yaml has no resolved `include:` list yet" even when every include was
  correct, sending you to edit a correct file; `ws.sh check` *silently skipped* its
  compose-include assertion for an absent member, so a skipped line read as a pass
  and real manifest drift was invisible for every member at once; and `ws:status`
  offered `mise run ws:clone` with no hint that it means a full duplicate of every
  member at the manifest branch. `ws.sh` gains a `preflight` subcommand that
  separates "manifest unresolved" from "checkout absent" and names the real next
  step (now what `ws:docker:up` guards on), reports an explicit `absent` line instead
  of going quiet, and prints the worktree state once per run. `POLYREPO.md`
  documents the topology.

### 3.23.0

*This was a long cycle with a large internal sweep, so many **Fixed** entries
below refer to defects introduced **and** resolved between releases — no
released version ever carried them. Entries that correct behavior a consumer
actually ran say so explicitly.*

- **Fixed:** `/steer:adopt`'s member carve-out never reached the file that
  **executes** it. `adopt/SKILL.md` says a member skips the seven product-level
  artifacts, but `PROCEDURE.md` — the phase-by-phase runbook the session actually
  follows — contained no mention of the exception and created them unconditionally
  at Phase 4 (`vision.md`, `users.md`, `glossary.md`) and Phase 10
  (`/spec/tracker.md` plus both tracker bootstraps, `/spec/app/README.md`,
  `/spec/HISTORY.md`). The precedence clause did not cover it either: the runbook
  defers to the `## Non-negotiable guardrails` block, and the carve-out sits
  outside it. Adopting a polyrepo member therefore produced exactly the
  split-brain spine the topology exists to prevent. Both phases now branch on the
  role, matching the fix `init/SCAFFOLD.md` already carried.
- **Fixed:** the deep-dive prose behind rules 30/32 contradicted the carve-out
  those rules state. `TRACEABILITY.md`'s routing table sent `/spec/HISTORY.md`,
  `/spec/app/` and `/spec/features/` destinations unconditionally, and
  `SPEC-FRAMEWORK.md`'s greenfield flow told every repo to fill `vision.md`,
  `users.md`, `glossary.md` and draft `/spec/features/`. Both now name the member
  exception, as their sibling deep-dives `HOUSEKEEPING.md` and
  `ISSUE-WORKFLOW.md` already did.
- **Fixed:** `policy/` — a root directory the scaffold itself installs and
  `/steer:protect` reads — was missing from the root allowlist in rule
  `22-housekeeping` and `HOUSEKEEPING.md`, so a tidy pass saw a bootstrap-created
  dir as a stray. Added there and to rule `20-layout`'s directory map, absorbed
  inside the existing rules ratchet — **no ceiling raise** — by tightening
  redundant wording in `20-layout`; no instruction was dropped.
- **Fixed:** rule `36-issue-first` said `/steer:tracker-sync` **and**
  `/steer:report` re-grant both MCP write tools; `/steer:report` grants only
  `issue_write`. Narrowed to what each actually grants.
- **Fixed:** three surfaces excluded a `spec/reports/*` directory from
  provenance-safe token rewrites — a path the plugin never creates — while the two
  reports it does emit (`spec/AUDIT-REPORT.md`, `spec/DRIFT-REPORT.md`) fell
  outside the carve-out. `MIGRATIONS.md`, `INVOCATION.md`, `sync/RECONCILE.md` and
  `scan-invocations.sh`'s comment now name the real files.
- **Fixed:** `/steer:roadmap` declared three modes but implements four — the
  no-argument read-only preview its body defines was absent from both the
  `argument-hint` and the `steer:modes` marker (`check_standards.py` validates
  marker→body only, so an undeclared mode is invisible to CI). Also:
  `/steer:spec`'s description enumerated `clarify` and `validate` but dropped
  `approve`, the one mode that writes; `/steer:intake`'s omitted its declared
  `status` mode; and `/steer:spec-scaffold`'s described creation only, though its
  body has a non-clobbering reconcile branch that `/steer:spec` depends on. All
  paid for inside the skill-listing ratchet by trimming redundancy in the same
  descriptions — **no ceiling raise**.
- **Fixed:** `plugins/steer/README.md` said the five temp-writing Tier 1 skills
  each have "a single temp-dir path" as their one permitted write, then conceded
  12 lines later that `/steer:audit` may also write `/spec/AUDIT-REPORT.md` and
  `/spec/DRIFT-REPORT.md`. Now states the exception where the claim is made.
- **Fixed:** `scaffold_reconcile.py`'s PERMISSION TIERS docstring illustrated the
  duplicate-pattern hazard with `git push` "in `ask`" — the template carries it
  under `allow`. Switched to `gh pr merge`, which is genuinely in `ask`.
- **Fixed:** the polyrepo member write guard was missing from the **always-on
  rules layer** — the one surface that fires without any skill being invoked, and
  the last place this cycle's carve-out sweep had not reached. Rule
  `22-housekeeping` (marked `inject-when=code-project`, so it injects in every
  member session) told a session to move a stray root file into `/spec/reference/`
  and "don't wait for a yes", while `/steer:tidy` and `HOUSEKEEPING.md` both say a
  member must never create that product-level dir; rule `32-living-docs` (carrying
  **no** `inject-when` marker, so it is always resident) routed `/spec/app/` and
  `/spec/HISTORY.md` unconditionally, even though rule `30-spec-workflow` got the
  carve-out and defers *to rule 32* for exactly that routing. A member session
  therefore read the skill's guard and the rule's contradiction of it in the same
  context. Both rules now name the member exception. Absorbed inside the existing
  rules ratchet — **no ceiling raise** — by tightening redundant wording in
  `00-router`, `10-stack`, `20-layout`, `30-spec-workflow`, `45-commit-autonomy`,
  `85-practices` and `99-end-of-session`; no instruction was dropped.
- **Fixed:** the same guard was missing from the three remaining skills that
  append `/spec/HISTORY.md`. `/steer:protect apply` (which also flips the
  delivery-mode marker), `/steer:spec approve` and `/steer:build`'s handoff all
  wrote it unconditionally, while their structural twin `/steer:adr accept` and
  `/steer:sync` both say "never create a local `HISTORY.md` in a member". All
  three now route to the workspace via `workspace.path`, else the PR description.
  `/steer:work --hotfix`'s follow-up step gained the same parenthetical.
- **Fixed:** `/steer:protect`'s opening contract still told **`verify`** to
  "reconcile the marker as part of the run" — 90 lines above the mode body's
  "`verify` **writes nothing** … Do not edit those files from `verify`". The
  previous pass fixed the mode body only, leaving the paragraph a session reads
  *first* asserting the opposite. Now scoped to `apply`.
- **Fixed:** the plugin `README.md` published the false-deferral theory that
  `ARTIFACTS.md` and `/steer:audit`'s own frontmatter comment exist to refute —
  "the restriction clears on the next user message, so confirmed follow-up writes
  run as their own steps after the skill returns". Tool grants apply for the whole
  invocation; there is no post-run window. The paragraph is replaced by that
  invariant, and publication is described as a separate step because it is a
  separate *skill* (`/steer:issues publish-*`), not a later phase of this one.
- **Fixed:** `README.md` and `AUTHORING.md` both claimed the Tier 1 skills set
  `disallowed-tools: Edit, Write, NotebookEdit, EnterWorktree` with **two** render
  variants keeping `Write`; four kept it (`audit`, `explain`, `help`, `status`).
  `AUTHORING.md` is the contract new skills are authored against, so it was
  actively instructing the next Tier 1 render skill into the exact trap
  `audit/SKILL.md` warns about. Both now define the tier by
  `Edit`/`NotebookEdit`/`EnterWorktree` and describe `Write` as splitting it.
- **Fixed:** `/steer:report` was documented as Tier 1 but **tool-enforced as
  nothing** — it set no `disallowed-tools` at all, making it the one Tier 1 skill
  with no frontmatter floor, and the one that posts to a shared upstream repo
  unprompted. It now carries `disallowed-tools: Edit, NotebookEdit, EnterWorktree`
  (keeping `Write` for the scrubbed temp file it builds the issue from), and the
  three hand-maintained Tier 1 rosters that omitted it now list it.
- **Fixed:** `/steer:audit`'s `Write` contract enumerated the permitted writes
  exhaustively ("never … any other file") while its `spec` mode offers
  `/steer:tracker-sync pull`, which materializes one markdown file per issue. The
  contract now names that temp-dir export as the third sanctioned write.
- **Fixed:** `MIGRATIONS.md` promised that `/steer:adopt` **and `/steer:build`**
  consume ledger entries on a resume; `skills/build/` contains no migration step
  at all, so a PO resuming a pre-3.x build silently skipped every pending
  migration. The ledger now states that build reaches the transforms by handing
  off to `/steer:adopt`.
- **Fixed:** `/steer:build` declared Windows supported only "via WSL2 … see the
  `Stack` rule", contradicting rule `10-stack` and `/steer:doctor`, which both
  call Git for Windows a supported setup on the Claude Desktop Code tab — this
  skill's own audience.
- **Fixed:** `ARTIFACTS.md` forbade embedding a git SHA in a machine-keyed export
  while `/steer:audit`'s triage export mandates one. The SHA is fixed for the run
  and `publish-audit` reads it to flag stale keys, so it is now documented as a
  deliberate exception rather than a violation, and `/steer:issues` names the
  marker with its `sha=` field instead of without.
- **Fixed:** `docs/concepts/authorization-model.md` said "every delivery verb
  stay gated" while the same page, rule `45-commit-autonomy`, and
  `check_standards.py` (which **fails the build** on it) all make `git push` and
  `gh pr create`/`edit` autonomous. Narrowed to the merge/deploy verbs.
  `AUTHORING.md` carried the same inversion, misattributed to rule 45.
- **Fixed:** `docs/` attributed solo-trunk graduation to `/steer:protect`
  mode-agnostically, though only `apply` raises the wall; `docs/reference/hooks.md`
  had no section for `lib/scope.sh` — the library this release extended most, and
  one `check_docs_impact.py` deliberately does not gate — so the member-aware
  `steer_tracker_is_github` fail-open that switches issue-first on in a polyrepo
  member was undocumented. Added, with the inject-when predicate list.
  `docs/workflows/issues.md` also dropped `reconcile --all` and
  `publish-findings --source` from its argument hint.
- **Fixed:** `/steer:init`'s member carve-out stopped short of the step that
  actually populates the spine, so init still contradicted **itself**. The earlier
  pass covered step 2 (`SCAFFOLD.md`, which skips *creating* the product-level
  files) and step 7's `HISTORY.md` seed, but **step 3's interview** told every run
  — member included — to populate `vision.md`, `users.md`, `glossary.md` and
  `/spec/tracker.md`, and to bootstrap the GitHub label/field taxonomy off that
  local tracker. A member following the steps in order skipped the files at step 2
  and then recreated them at step 3: the split-brain spine the carve-out exists to
  prevent. Step 3 now branches on the role resolved at step 2 — README placeholders
  and stack defaults only, tracker bootstrap deferred to the workspace.
- **Fixed:** `ARTIFACTS.md` — the single source of truth every rendering skill
  defers to for Artifact mechanics — asserted that `/steer:audit`'s frontmatter
  **disallows `Write`** and therefore "cannot publish during the tool-restricted
  run", directing the render to a **post-run step** "once the run's tool
  restriction has cleared". Audit *grants* `Write`, and its frontmatter comment
  refutes exactly that theory: tool grants apply for the whole invocation, so
  there is no post-run window and dropping `Write` makes the instructed render
  unreachable rather than deferred. A session trusting the reference never rendered
  the audit dashboard at all. `/steer:audit` and `/steer:status` now sit in the
  "read-only skills keep `Write`" bullet, and the false deferral paragraph is
  replaced by the stated invariant. `/steer:status` was also missing from the
  file's skill roster and its "where each skill uses this" table; both now list it.
- **Fixed:** `/steer:audit`'s non-mutating contract was still contradicted by its
  own **mode summaries**, the two surfaces the previous two passes missed — the
  mode picker in `audit/SKILL.md` listed code mode's verbs as "**file** findings in
  the tracker", and `modes/code.md`'s stop-condition included "(with a yes)
  **opened issues**", 68 lines below a description that says "files nothing" and
  with no issue-create verb granted. `modes/spec.md`'s step 3 imperative still read
  "**Open** `spec-drift`-labelled issues" while its own body routed filing to
  `/steer:issues publish-drift`. All three now name the separate
  `/steer:issues publish-audit` / `publish-drift` step; the procedures themselves
  were already correct.
- **Fixed:** `/steer:init` was the one bootstrap door with **no polyrepo-member
  path**, on the route the plugin itself prescribes. `init/SCAFFOLD.md` tells a
  workspace session to run `/steer:init` in each member and install
  `spec/PRODUCT.md` *instead of* the product-level spine — but init's own steps
  never branched on it, instantiating `vision.md`, `users.md`, `glossary.md`,
  `HISTORY.md`, `tracker.md` and `spec/app/` unconditionally, so following the
  instruction manufactured the split-brain spine the topology exists to prevent.
  `adopt`, `sync` and `setup` all carried this carve-out; init now does too,
  including step 7's `HISTORY.md` seed, which routes to the PR description in a
  member.
- **Fixed:** `/steer:audit`'s non-mutating contract was still contradicted on the
  two surfaces the previous pass missed — the always-on `description` ("files
  ranked findings in the tracker … Proposes and **files**") and
  `audit/modes/spec.md`'s summary ("`spec-drift` issues **(its only writes)**") —
  while the body says both modes write nothing and the frontmatter grants no
  issue-write verb. Both now name `/steer:issues publish-audit` / `publish-drift`
  as the separate filing step. The reworded description is 9 chars shorter, paid
  into the listing ratchet.
- **Fixed:** the root known-dirs allowlist disagreed with itself across the two
  surfaces that decide it. Rule `22-housekeeping` gained `scripts/` but
  `HOUSEKEEPING.md` — which `/steer:tidy` loads as its authoritative sweep
  procedure — did not, so tidy would have proposed relocating the root
  `scripts/ws.sh` the new `workspace` profile ships. Both lists now match, and
  the reference names the rule as their source.
- **Fixed:** `POLYREPO.md` asserted that `/steer:tidy` must not create a
  product-level spine dir locally in a member, but **no tidy surface implemented
  it** — neither `tidy/SKILL.md` nor `HOUSEKEEPING.md` contained the word
  `member`, and both routed loose source material to `/spec/reference/`
  unconditionally. Both now carve out `spec/reference|sources|features|app` as
  the workspace's and report the stray instead of creating the dir, leaving
  `spec/design/` and `spec/decisions/` handled normally as the member's own.
- **Fixed:** `/steer:questions`' read-only guarantee pointed at content that had
  moved — "the **Read-only** invariant *below*" names a section that lives in
  `BUNDLE.md`, not `SKILL.md`. Split collateral the earlier sweep missed, and the
  one dangling `below` whose target is a safety guarantee, so a session reading
  `SKILL.md` alone could not find the authoritative list of what bundle must not
  write. It now names the file.
- **Fixed:** `/steer:issues bootstrap-labels` declared `gh label create --force` a
  sanctioned inline exception but the verb was granted **nowhere** — not in
  `issues`' own `allowed-tools`, and the scaffold `settings.json` allowed only
  `gh label list`. Label bootstrap therefore prompted interactively and
  auto-denied headless, in the two skills (`/steer:init`, `/steer:adopt`) that
  call it during setup. Granted in both places.
- **Fixed:** three surfaces stated an authorization or routing fact the code
  contradicts — the class the pre-release audit exists to catch, and two of the
  three were introduced by the *previous* audit-fix pass. (1) The authorization
  model page claimed Tier 1 skills set `disallowed-tools: Edit, Write, …` and named
  eight; `audit`, `status`, `help` and `explain` all retain `Write` (bound in prose
  to a temp-dir Artifact or a confirmed report), and `explain` also disallows
  `Bash`. The tier is now defined by `Edit`/`NotebookEdit`/`EnterWorktree`, with
  `Write` described as splitting it. (2) `README.md` advertised `/steer:report` as
  "confirmation-gated" while the skill and rule `97-self-report` both specify
  **auto-file, no confirmation** — for the one skill that posts to a shared
  upstream repo unprompted. (3) Rule `00-router` and the skills reference both had
  `/steer:adopt` and `/steer:sync` invoking `/steer:doctor`; only `/steer:init` and
  `/steer:build` ever have. `/steer:setup`'s own description also promised
  "installing prerequisites" when it only surfaces them.
- **Fixed:** `orient-session.sh`'s knowledge-work greeting re-fired after every
  `/clear`, resume and compaction. Widening the hook's matcher to
  `startup|resume|clear|compact` (so the polyrepo topology note survives a
  `/clear`) also un-gated the one-time greeting, and the in-file comment still
  claimed "runs on `startup` only … does NOT re-fire". The greeting is now gated on
  `source: startup` — failing open when the field is absent — while the topology
  note keeps firing on all four. Both behaviours are now covered by hook tests.
- **Fixed:** `/steer:protect`'s default `verify` mode declared itself read-only
  ("re-running on a protected repo writes nothing") and then, in that same mode,
  instructed flipping the `CLAUDE.md` delivery-mode marker and appending a
  graduation entry to `/spec/HISTORY.md`. `verify` now reports the stale marker and
  names `apply` as the fix; `apply` still performs the reconciliation.
- **Fixed:** `/steer:sync` step 8 told every polyrepo member to append a
  `/spec/HISTORY.md` entry that step 4 forbids creating there. It now records the
  sync in the PR description instead, leaving `/spec/.version` as the local record.
  `/steer:adr` had the same gap for its ratification entry and now routes it to the
  workspace ledger.
- **Fixed:** `/steer:explain` was the one spine-reading skill with no polyrepo
  carve-out, so in a member it rendered a fully-specified feature as *"not specified
  in the spec"*. It now resolves `workspace.path` first and stops with "spine
  unreachable" when it cannot — `Bash` is disallowed there, so the gateway route is
  deliberately not offered.
- **Fixed:** `/steer:help` promised a menu that "can never drift" from the router
  while hard-coding its groups, and had silently dropped `/steer:work --hotfix` —
  leaving the incident door out of the capability menu. Added the hotfix row plus a
  completeness check that every front-door row appears exactly once.
- **Fixed:** `/steer:audit` asserted both modes were "repository-read-only … their
  only writes are tracker issues" while instructing a `/spec/AUDIT-REPORT.md` write
  **on a `feat/audit` branch** — with no git-write verb granted and `EnterWorktree`
  disallowed, and no issue-write verb either. The contract now says non-mutating,
  the branch instruction is gone, and publishing is named as the separate
  `/steer:issues publish-*` step.
- **Fixed:** the polyrepo artifact map in `POLYREPO.md` and `spec/product.md`
  omitted `spec/sources`, `spec/reference`, `spec/design` and `DESIGN.md` — one of
  which `/steer:intake` already lands in the workspace — so `/steer:tidy` would
  create product-level dirs locally in a member. Both now place all four and state
  the underlying test (product truth vs. this repo's internals). `POLYREPO.md` also
  now lists `/steer:protect` among the reports owing a member-scope declaration.
- **Fixed:** `/steer:tracker-sync`'s caller comment named a `/steer:spec
  materialize` step and an `/steer:intake (reconcile)` route that do not exist
  (`materialize` is an `/steer:issues` mode; intake's reconcile table has no
  tracker-sync row). Corrected here and in the intake workflow docs — the previous
  pass fixed only the `CAPABILITIES.md` copy.
- **Fixed:** the shipped PR template and `spec/tracker.md` told a **human** to run
  `/steer:tracker-sync`, which is `user-invocable: false` — and the plugin's own
  `scan-invocations.sh` then flagged it in every consumer repo. Both now describe
  the action instead. `check_standards.py` scans the PR template too, so the two
  detectors no longer disagree on their surface list.
- **Fixed:** a batch of smaller cross-surface inaccuracies — bare `/loop` in two
  places colliding with the real `/steer:loop`; `INVOCATION.md`'s `explain` row
  describing a different skill, its Tier 1 header omitting that `report` auto-files
  and `audit` may write, and its gateway caller sets understating both; `status`
  contradicting itself on whether `Bash` is disallowed; `doctor` reading as though
  it edits the dev's shell rc; the scaffold `CLAUDE.md` naming only `feat/*` when
  `/steer:work` defaults to `issue/<n>-<slug>`; `convert:doc` documented without its
  load-bearing `--from 'markitdown[all]'`; the hook-tier list covering 4 of 6
  registered hooks; and `issues`, `adopt`, `work`, `sync` and `tracker-sync`
  descriptions omitting modes or writes they perform. `adopt` also gained the
  narrowly-scoped `Bash(npx @google/design.md *)` grant its Phase 7 needs.
- **Changed:** the always-on rules ceiling moves 65,200 → 65,300 B. The first raise
  re-armed at measured+1%, but the polyrepo work landed in the same cycle and
  consumed it to **7 bytes**, so the next correctness fix to any rule was
  guaranteed to breach it — and three landed here. Paid down partly by dropping
  three `/steer:reference` description parentheticals that `when_to_use` already
  restates. `RULES_TOTAL_TARGET_BYTES` stays 62,500.
- **Fixed:** issue-first's sibling defect — **the polyrepo member write guard was
  missing from the three surfaces that actually author the spine.** The 3.23.0
  sweep gave rules `35-issue-tracker` and `36-issue-first` a member carve-out but
  stopped there, so in a member repo — where all the code lives — the topology
  still produced the split-brain spine it exists to prevent. Rule
  `30-spec-workflow` carries **no** `inject-when` marker, so it injects in every
  member session and instructed "Starting a user-facing feature →
  `/spec/features/[id]/intent.md`" while `orient-session.sh` said, in the same
  session, not to create product-level spec files there; it now names the member
  exception (`spec/features/**` and the product-level files are the workspace's;
  ADRs and `ARCHITECTURE.md` stay per member). `/steer:spec` gains a step 0 and
  `/steer:spec-scaffold` a step-2 guard that resolve the workspace
  (`workspace.path`, else the GitHub gateway) before writing, and stop rather
  than write locally when neither route reaches it — the behaviour
  `docs/concepts/product-spine.md` and `/steer:adopt` already claimed the skills
  had. Paid for inside the existing rules ratchet, no raise.
- **Fixed:** `/steer:tracker-sync` — the gateway **every** tracker read and write
  is required to route through — had zero polyrepo awareness (no occurrence of
  `PRODUCT.md`, `workspace.yml`, `polyrepo` or `member` in the skill). Its step 1
  read the *local* `spec/tracker.md` every run and fell to the manual floor on
  its absence, which is precisely the member case, while `/steer:work` and
  `/steer:issues` resolved the workspace tracker and then mandated routing
  through it. Step 1 now resolves a member's tracker at the workspace, treats a
  missing local file as "not mine to read" rather than "no tracker", never
  creates a local copy, and points at the cross-repo closing-ref rule since a
  member's declared `repository:` is never its own repo.
- **Fixed:** `/steer:intake` and `/steer:questions` silently mis-handled a member.
  `intake` gated on `spec/` merely *existing* — true in a member, which uses it to
  hold `spec/PRODUCT.md` — so the precondition passed and it routed `spec/sources/`
  and product-level content into the member. `questions` grepped
  `spec/vision.md`, `spec/features/*/intent.md` and `spec/PRODUCTIONIZATION.md`,
  all absent in a member by design, and reported the empty result as a clean
  sweep. Both now resolve the workspace first and say the spine is unreachable
  rather than reporting zero.
- **Fixed:** the polyrepo topology note could vanish exactly when it was still
  needed. `orient-session.sh` was registered on `SessionStart` **`startup` only**,
  while the ruleset it deliberately substitutes for runs on
  `startup|resume|clear|compact` — so after a `/clear`, a resume, or
  auto-compaction a polyrepo session kept every rule and lost the topology
  entirely. It now carries the same matcher. Separately, the note sat *below* the
  in-progress-PO-build branch, which `exit 0`s, so a workspace or member with an
  open handoff gate never received it; the topology block is now emitted **before**
  that branch. The workspace note also gains `/steer:protect` to the list of
  reports that must declare their member scope, matching the skill.
- **Fixed:** rules `20-layout` and `10-stack` enumerated the repo profiles without
  `workspace`, and rule 20 asserted "the `/spec` spine is identical across all
  profiles" — which the topology contradicts in both directions (a workspace holds
  the whole product spine, a member's is partial by design). Both now name the
  profile, and rule 20 states the polyrepo exception.
- **Fixed:** `/steer:audit` disallowed `Write` in its frontmatter while its own
  modes instruct two writes — the temp-dir Artifact dashboard and the optional
  `AUDIT-REPORT.md` / `DRIFT-REPORT.md` — reconciled only by the claim that a user
  confirmation means "the restriction has cleared". A skill's tool grants apply
  for the whole invocation, so the instructed write was unreachable. `Write` is
  now granted and bound **in prose**, exactly as `/steer:status`,
  `/steer:explain`, `/steer:help` and `/steer:questions` bundle mode already do;
  `Edit`/`NotebookEdit`/`EnterWorktree` stay disallowed, so the skill still cannot
  modify an existing repo file.
- **Fixed:** `/steer:tracker-sync`'s `SKILL.md` called its operation list "the
  **full** catalogue" while omitting 6 of the 20 in `OPERATIONS.md` — including
  `create`, which `hooks/check-bash-actions.sh` actively nudges agents toward, and
  `bootstrap-fields`, which `/steer:init` and `/steer:adopt` both invoke by name.
  Also added: `set-milestone`, `milestone-ensure`, `link-blocked-by`, `reopen`.
- **Fixed:** `templates/reference/INVOCATION.md` defined the `artifacts` reference
  topic as "what each `/spec` file is for" — a different document entirely
  (`ARTIFACTS.md` is *Producing Claude Artifacts*). A regression from the previous
  audit-fix pass, which added the five missing topics but glossed this one wrong.
  Its tier matrix also omitted 4 of 26 skills; `loop` was the material gap, since
  it commits, pushes and opens a PR yet was absent from the file whose stated job
  is flagging exactly that.
- **Fixed:** `/steer:spec materialize` does not exist — `materialize` is a
  `/steer:issues` mode. Corrected in `templates/reference/CAPABILITIES.md`, which
  `/steer:sync` reads during capability repair.
- **Fixed:** compaction-factoring collateral in the split skill bodies.
  `build/HANDOFF.md` and `build/IMPLEMENTATION.md` each misstated where the
  other's steps live (both claimed steps that had moved were still in
  `SKILL.md`); six "below" references pointed at procedure relocated into a
  sibling file; four intra-document anchors resolved to headings that stayed
  behind (`intake/SKILL.md`, `intake/PIPELINES.md`, `questions/BUNDLE.md` ×2); and
  `/steer:sync`'s step **6.5** was scoped by `SKILL.md` but appeared in neither its
  step list nor `RECONCILE.md`'s title. The `--check` read-only boundary is also
  no longer one interposed sentence away from reading as "then branch".
- **Changed:** `reporting.require_all_members` in `spec/workspace.yml` is
  documented as what it is — a **declaration**, not a switch. `POLYREPO.md`
  attributed report behaviour to the key, but nothing reads it and every report
  names uncovered members unconditionally, so `false` would have changed nothing.
  Both the reference and the template comment now say so.
- **Fixed:** `templates/reference/POLYREPO.md`'s workspace-task table omitted
  `mise run ws:list`, and `templates/scaffold/MANIFEST.md` named a private
  internal template repository in a tree required to stay client-agnostic.
- **Fixed:** `skills/init/SCAFFOLD.md`'s first instruction opened **mid-sentence**
  — "`lives in the plugin — no external template repo to fetch.`" The subject
  ("**Instantiate the bundled scaffold — core plus the profile's extras.**
  Everything") stayed behind in `SKILL.md` step 2 when this cycle's compaction
  factoring split the body out, so the file a session reads *just-in-time* to run
  the scaffold install began with a dangling verb phrase. Restored, and the whole
  body de-indented from the orphaned 3-space list depth it inherited from the
  numbered item it used to live under.
- **Fixed:** rule `36-issue-first` opened "When `/spec/tracker.md` declares
  `system: github`" — a file a **polyrepo member does not have**. The predicate
  fix this cycle taught `steer_tracker_is_github` to resolve a member's tracker
  from the workspace, so the rule now *injects* there; but a model checking the
  rule's own stated precondition found no such file and could conclude it was out
  of scope — reinstating, at the prose layer, the silent-off bug the predicate fix
  removed. Sibling rule `35-issue-tracker` already carried the member carve-out;
  36 now does too (+109 B, absorbed within the existing ratchet — no raise).
- **Fixed:** `templates/reference/INVOCATION.md` listed **3 of 8**
  `/steer:reference` topics, omitting `context-hygiene`, `architecture-diagrams`,
  `artifacts`, `gates` and `polyrepo`. This is the same hand-maintained-enumeration
  drift this cycle swept from `rules/00-router.md`, `skills/standards` and the
  scaffold `CLAUDE.md` — that sweep missed this surface.
- **Fixed:** `skills/questions/SKILL.md`'s bundle-mode summary claimed the mode
  "then **ingests** the filled return leg", contradicting `BUNDLE.md`'s "Bundle
  itself changes nothing in the spec" — ingestion belongs to
  `/steer:intake clarify`. The summary line, added during this cycle's split, now
  matches the procedure it summarizes.
- **Fixed:** `/steer:adr`'s default-mode step 4 ("Set Status to `Proposed` …
  Leave the `> Ratified …` fields as-is") had no carve-out for `/steer:init`
  step 4, which authors the stack ADR at `Accepted` **with** the stamps — so init
  told the skill it invokes to do the opposite of what init itself requires. The
  step now names the exception and restates that `accept` is still the single
  writer of the `Proposed → Accepted` *transition*; a create at `Accepted` is not
  one.
- **Fixed:** `docs/reference/known-limitations.md` contradicted itself on the
  push gate. Its hook-tier list omitted `check-bash-actions.sh` entirely, opened
  "only one of them actually blocks an action", and closed "the **push / PR gate
  is not a hook at all** … Nothing technically prevents a push" — while the same
  page says at line 113 that the solo-trunk graduation gate pauses a push, and
  `check-bash-actions.sh` does emit `permissionDecision: "ask"`. The list now
  carries the `ask` tier (with its once-per-session-and-repo scope and the
  advisory issue-create guard), and the last bullet is narrowed to the merge gate,
  which genuinely is rule-only.
- **Fixed:** `templates/reference/GATES.md` listed the ungraduated solo-trunk
  trunk push under **"never promptable — asking is not authorization"**, which
  contradicted the two surfaces that actually implement it: rule
  `45-commit-autonomy` says such a push "waits for a human yes", and
  `hooks/check-bash-actions.sh` emits `permissionDecision: "ask"` —
  deliberately never a deny — whose own reason text ends "Approving this prompt
  pushes anyway". Claude reading GATES.md would have refused a push the human had
  just approved. §5 now lists only protected-branch pushes (where the
  server-side wall *is* the authorization, matching rule `61-gate-prompts`), and
  says explicitly that the solo-trunk gate is answerable but is **not** one of the
  three §2 gates: it is a per-push harness permission decision with no `/spec`
  field to record and no three-option prompt.
- **Fixed:** `templates/scaffold/MANIFEST.md` still asserted that
  `steer_spine_state` "still reports `damaged`" for a polyrepo member — stale as
  of the same release that fixed it, since `hooks/lib/spine.sh` now detects
  `spec/PRODUCT.md` and validates members against `STEER_SPINE_REQUIRED_MEMBER`,
  reporting `managed`. The passage now states the real mechanism and keeps the
  still-correct instruction: `/steer:sync` and `/steer:doctor` establish the role
  via `steer_polyrepo_role` first, and never "repair" a member's deliberately
  absent product-level files.
- **Fixed:** three scaffold comments still advertised the `markitdown` MCP server
  as live after this same release retired it — `templates/scaffold/mise.toml`
  twice (once as the justification for the always-installed Node/Python baseline,
  once claiming "the same converter ships as an MCP server … in the plugin's
  `.mcp.json`", directly above the `convert:doc` task that replaced it) and
  `profiles/workspace/mise.toml` once, in a file this release *adds*. Both
  comments were accurate at 3.22.0 and were left stale by the retirement, so no
  released bundle ever contradicted itself — but shipping the retirement without
  them would have. Each now cites the real on-demand task. No gate covers this:
  `check_copilot_mcp.py` compares server sets, not prose.
- **Fixed:** `/steer:reference`'s two newest topics were missing from the
  hand-maintained topic enumerations, so `polyrepo` was undiscoverable from the
  only always-on surface. `rules/00-router.md` gains `polyrepo` (it already had
  `gates`); `skills/standards/SKILL.md` — the Chat-tab/web fallback where no hook
  injects, so exactly the readers with no other path — and the bundled
  `templates/scaffold/CLAUDE.md`, which **ships into every consumer repo**, gain
  both.
- **Fixed:** `/steer:tidy` could propose relocating the root `ARCHITECTURE.md`
  that rules `20-layout` and `32-living-docs` require there. `22-housekeeping`
  gained the allowlist entry this cycle, but `HOUSEKEEPING.md` — which
  `skills/tidy` names as its authoritative sweep procedure — still listed root
  docs as `CLAUDE.md, README.md, DESIGN.md`, so the file read as a stray.
- **Fixed:** three skills still advertised feature-intent approval as
  "(no command)" — `/steer:build`, `/steer:issues` and `/steer:adopt` — after rule
  `61-gate-prompts` made that gate answerable in-session. All three now route to
  `/steer:spec approve`, which offers the prompt. (`/steer:adr` and `/steer:spec`
  already scoped "no command" correctly, to the wrong-decider case.)
- **Fixed:** `/steer:init` authored the stack ADR as `Accepted` without the
  `> Ratified by:` / `> Ratified at:` / `> Ratified via:` stamp that the template
  carries and `/steer:next` asserts every `Accepted` ADR has — so the one ADR
  bootstrap creates was the one ADR that looked incomplete. It now stamps them
  (`in-session`, the dev as ratifier). The single-writer property is unchanged:
  init *creates* at `Accepted`, it does not transition.
- **Fixed:** `/steer:tracker-sync` advertised an `issue <op>` argument grammar
  with **zero** call sites — every one of ~60 uses the bare op form
  (`create`, `close`, `field-set`, …), and the `issue` mode existed only in the
  hint and the `steer:modes` marker, which agree with each other and with nothing
  else. Both now describe reality, so a caller can't be led to write
  `/steer:tracker-sync issue close #4`.
- **Fixed:** `/steer:doctor` was told to "commit it" (the refreshed `mise.lock`)
  by one step and "never edit repo files or commit from this skill" by its own
  guardrails. It now reports the lockfile as needing a commit and leaves the
  commit to the caller.
- **Fixed:** the `v3.23.0` markitdown entry in `MIGRATIONS.md` sat between
  `v3.13.0` and `v3.8.0`, breaking the ledger's declared newest-first order — a
  reader walking it newest-first could stop before reaching it. Moved next to the
  other `v3.23.0` entry; content unchanged.
- **Fixed:** the two Copilot-ported gates could fail **invisibly**.
  `copilot-hooks.json` builds each script path from `${CLAUDE_PLUGIN_ROOT}`, so if
  the Copilot CLI does not export that Claude-named variable the path collapses to
  `/hooks/<script>` and `sh` fails before the script runs — which the fail-open
  `|| true` then turned into a clean exit 0 with no `permissionDecision`. These
  two are the *only* enforcement Copilot has, and nothing would have said they
  were absent (an in-script fallback cannot help; the script is never reached).
  The generated command now guards on the resolved path and reports
  `CLAUDE_PLUGIN_ROOT unresolved — <script> gate skipped` on stderr. Still
  fail-open — a hook must never break a session — but diagnosable rather than
  silent. Tested with the variable unset.
- **Added:** the generated `.github/copilot-instructions.md` now opens with a
  **surface invocation note**. The rules are carried verbatim, so every skill
  cross-reference reads `/steer:<skill>`; in Copilot for VS Code the invocable
  form is `/steer-<skill>`, so a reader following the router table typed a command
  that does not exist. `gen_copilot_prompts.py` rewrites refs for the *prompt*
  artifacts, but this file is read by **both** Copilot surfaces and the CLI loads
  skills from the plugin manifest, so a blanket rewrite would be wrong for one of
  them — the mapping is stated once, up front, instead. The
  `docs/concepts/copilot-support.md` limitations list also now records that
  polyrepo topology is Claude-only (no SessionStart equivalent, and deliberately
  no always-on rule for the generator to carry) and that the ported gates are
  *ported, not proven*.
- **Fixed:** `/steer:work`'s routing text was **silently truncated by YAML** on
  every surface. `when_to_use` was a plain scalar containing `("work on #123"`,
  and in an unquoted scalar ` #` opens a comment — so the value ended at 75 of
  546 characters with no parse error. Everything discarded was trigger
  vocabulary: the whole `--reviewed` cluster ("deliver X carefully", "do this
  with review", any change costly to unwind) and the whole `--hotfix` cluster
  ("prod is down", "emergency fix"). Routing to the review and
  production-incident paths was degraded for several releases, worst on Copilot
  in VS Code where the generated capsule *is* the entire skill. Now a `>-` folded
  block, as 19 of 26 skills already used; `work` was the only skill affected.
- **Added:** `check_plugin.py` gates the failure class — a frontmatter scalar
  that is neither quoted nor a block and contains ` #` is now an error naming the
  truncated value. This bug is invisible by construction (the file reads
  correctly, the YAML is valid, only the loaded value is wrong), and nothing
  else caught it: `check_plugin`'s per-skill cap and `check_context_budget`'s
  ratchet both measure the *parsed* value, so a truncation looks like brevity.
- **Changed:** the skill-listing ratchet is re-baselined once, 11,500 → 11,900
  chars, because the old number was never an honest measurement — it was
  calibrated against the truncated value above, reading 22 chars of headroom
  while the intended payload was ~450 over. Per the gate's own policy the fix
  paid what it could first: `work`'s entry is trimmed 932 → 747 chars by dropping
  a duplicate issue example, a third hotfix synonym, and a step enumeration the
  body carries in full — every distinct trigger phrase is kept. Later fixes in
  this same cycle grew it back, so `work` remains the largest listing consumer
  and the payload sits just under the 11,900 ceiling (`check_context_budget.py
  --report` for the live figure); the next skill description to grow needs its
  own paydown. Deliberately **not** funded by compressing
  unrelated skills, which is the trade the rules-ceiling note records as the
  wrong one. `LISTING_TOTAL_TARGET_CHARS` stays at 10,000 so the report keeps
  showing the gap to reclaim.
- **Fixed:** issue-first enforcement was silently **off in every polyrepo
  member** — the repos that hold all the code. `steer_tracker_is_github` resolved
  `spec/tracker.md` from the local root only, but a member's tracker is
  product-level and lives in the workspace by design, so its absence was read as
  "not a GitHub tracker": rule `36-issue-first` (`inject-when=tracker-github`)
  never injected, and `check-write-nudges.sh`, `check-bash-actions.sh` and
  `reconcile-issue-first.sh` all exited early. The predicate now resolves the
  workspace's tracker via `spec/PRODUCT.md`'s optional `workspace.path` local
  checkout, and where no checkout is declared it **degrades to inject** per
  `lib/scope.sh`'s own fail-open contract — a needless nudge is recoverable, a
  silently-absent gate is not. New helper `steer_workspace_path` reads the
  pointer, scoped to the `workspace:` block so an unrelated `path:` can't be
  mistaken for it. The single-repo path is byte-identical: no local tracker and
  no `PRODUCT.md` still proves the rule out of scope.
- **Fixed:** rule `35-issue-tracker` told a polyrepo member to create the one
  file the topology forbids it to have. The rule is `inject-when=code-project`,
  so it injects in a member, and instructed "if missing, ask and create it from
  the bundled template" of `spec/tracker.md` — while `POLYREPO.md` and
  `spec/PRODUCT.md` both say not to add product-level files to a member, because
  that recreates the split-brain spine the topology exists to prevent. The rule
  now carries the member exception inline: resolve the tracker at the workspace,
  never create a local copy.
- **Fixed:** new content in this release cited a **rule `21-polyrepo` that does
  not exist** (nothing released ever carried the citation — both surfaces are new
  this cycle). `skills/reference/COVERAGE.md` would have told a consumer session
  the polyrepo topic "backs the scoped rule `21-polyrepo`", and `lib/scope.sh`'s
  `polyrepo` predicate comment described that rule's text as if it shipped — while the
  actual decision, recorded in this release, is that the topology is deliberately
  **not** an always-on rule (it is delivered by `orient-session.sh` plus
  `/steer:reference polyrepo`, so a single-repo product pays zero bytes). Both now
  state the real design, and the predicate comment says plainly that no rule
  carries `inject-when=polyrepo` so the token can't be mistaken for evidence of
  one again.

- **Changed:** the always-on `rules/*.md` ratchet ceiling is raised once, 62,500 →
  65,200 bytes (`check_context_budget.py`). The ratchet had drifted to **32 bytes**
  of headroom, so rule `61-gate-prompts` could only be added by compressing
  unrelated gate rules — and that trade deleted ~1 KB of rationale prose (rules 00,
  30, 31, 36, 45, 50, 60, 62, 95, 99) that existed nowhere else in the repo. Those
  compressions are **reverted**, except one line of rule 30 later retrimmed to help
  pay for the polyrepo block; the ceiling is re-armed at the measured
  total plus ~1%. Unlike `SKILL_BODY_MAX_BYTES`, which is derived from Claude Code's
  compaction re-attach behaviour and cannot move, this number is policy — so the
  raise carries its reason in the gate script, and the default answer to "it doesn't
  fit" remains *trade prose out first* (relocate rationale to
  `templates/reference/*`, or deliver a scoped rule via a hook as polyrepo does).
  `RULES_TOTAL_TARGET_BYTES` deliberately stays at 62,500, below the ceiling, so the
  report keeps showing the gap as work to reclaim.

- **Added:** human authority gates are now **answerable in-session** instead of
  requiring an out-of-band field edit. A gate has always required the deciding
  *human*, never a particular channel — but there was no way to answer one from
  the session, so a `Proposed` ADR the author had already decided became the top
  blocker `/steer:next` resurfaced every time the repo was opened, and the
  workflow stalled on bookkeeping rather than judgement. New rule
  `61-gate-prompts` defines a single three-option prompt — **Approve · Reject ·
  Decide later** — offered at the three promptable gates: ADR
  `Proposed → Accepted`, feature intent `draft → approved`, and the
  `/steer:work --reviewed` plan sign-off. `Decide later` leaves every field
  untouched, so the change is strictly additive: no repo can end up more stuck
  than before.
- **Added:** `/steer:adr accept <n>` — the single writer of
  `Proposed → Accepted`. It stamps `> Ratified by:` / `> Ratified at:` /
  `> Ratified via:` (in-session vs offline-review) and appends one
  `/spec/HISTORY.md` entry. Self-ratification is legitimate — a solo repo's
  author, decider and reviewer are the same person; the channel stamp is what
  keeps it auditable, since *unrecorded* self-ratification was the actual gap.
  Refuses on `Superseded`/`Deprecated`, idempotent on `Accepted`, and never runs
  on Claude's own initiative.
- **Added:** `/steer:reference gates` loads the full protocol
  (`templates/reference/GATES.md`): what the prompt does and does not change, the
  per-gate minimum the prompt must show, how the decision is recorded, the
  wrong-decider case, and the never-promptable boundary.
- **Changed:** the anti-rubber-stamp constraints are part of the contract, not
  advice. A gate prompt must carry the tradeoff — an ADR's rejected alternatives
  and negative consequences, an intent's acceptance criteria and locked scope, a
  plan's residual risk — and must never pre-select an option, infer approval from
  ambient agreement ("ok", "thanks", silence, sign-off on an earlier plan), or
  bundle two decisions into one answer. Preconditions still fire first: a failed
  blocking-question gate means the intent prompt is never shown.
- **Changed:** `/steer:next` and `NEXT-ACTIONS.md` no longer dead-end the two
  answerable gates on "no command" — they route to the skill that collects and
  records the answer. `/steer:next` stays read-only and never runs a prompt
  itself. **PR merge, deploy, real secrets, `/infra`, and protected-branch pushes
  remain command-less and are explicitly never promptable** — these gates became
  answerable, not removable.
- **Fixed:** an ADR created from the bundled template never surfaced as awaiting
  ratification. `templates/spec/adr.md` writes a blockquote `> Status: Proposed`,
  but `workspace-snapshot.sh` parsed only the bold-list form
  `- **Status:** Proposed`, so every template-created ADR reported `unknown` and
  dropped out of the Proposed-ADR sweep — the detection half of the stall above.
  Both header forms are now accepted, and an ADR still carrying the template's
  whole `Proposed | Accepted | …` enum reports `unresolved-template` rather than
  being read as a real decision state.
- **Changed:** the **`markitdown` MCP server is retired** in favour of the
  on-demand `mise run convert:doc <file>` task. A plugin MCP server starts
  automatically whenever the plugin is enabled, so every session spawned a
  `uvx markitdown-mcp` subprocess to serve the one skill that needs it
  (`/steer:intake`) — including the overwhelming majority of sessions that never
  convert a document. `convert:doc` runs the same `markitdown` tool, and
  `/steer:intake` already treated it as its deterministic committable path, so
  **capability is unchanged** and only the always-on cost goes away. The
  converter ladder is now `convert:doc` → native `Read` (text-bearing PDFs) →
  manual floor. The VS Code Copilot mirror regenerates from the plugin
  `.mcp.json`, so it drops the server too. Migration `v3.23.0` clears a stale
  `markitdown` entry from a repo's `.mcp.json` / `.vscode/mcp.json`; until it
  runs the entry is harmless.
- **Changed:** rule `10-stack` now names the bundled **`context7`** MCP server as
  the way to satisfy its own "verify the current stable version in-session,
  never from training-data memory" instruction. context7 shipped with no skill
  or rule referencing it, so the one job it exists to do was never actually
  wired to it — it read as unexplained tool-surface cost. Offset within the
  always-on budget by dropping a duplicated editor-preference line that
  `CONVENTIONS.md` already carries in full, so the change paid for itself where
  it landed. (Across the whole release the rules payload still grows toward the
  ceiling — see the ratchet entry above for the current figure.)

- **Changed:** the living global architecture diagram moves from
  `spec/design/architecture.md` to **`spec/design/architecture-diagram.md`**. It
  shared a basename with the root `ARCHITECTURE.md` that links to it, differing
  only by case and path — two files called "architecture" at two altitudes read
  as a duplicate or a half-finished move — and it collided with the Tier 2
  LikeC4 *model folder* `spec/design/architecture/` sitting beside it. The three
  artifacts are now legible by name: model folder `architecture/` → rendered
  diagram `architecture-diagram.md` → narrative `ARCHITECTURE.md`. The
  root/`spec` **split is unchanged** — `ARCHITECTURE.md` stays at the repo root
  as the as-built system model, narrative and tables only, still linking rather
  than inlining. Bundled template renamed to
  `templates/spec/design-architecture-diagram.md`; the LikeC4 model folder and
  the `diagrams:render` paths are untouched. A **`MIGRATIONS.md` v3.23.0 entry**
  carries the `git mv` plus the enumerated in-file token rewrite, so
  `/steer:sync` moves the file in already-bootstrapped repos with history
  following it.
- **Fixed:** the root-tidiness rule (`22-housekeeping`) omitted `ARCHITECTURE.md`
  from the root allowlist, so the one rule that decides what may sit at the repo
  root read it as a stray — while `20-layout`, `32-living-docs`,
  `50-definition-of-done`, `52-deployment`, `55-drift-gates` and the scaffold all
  mandate it there. It is now in the allowlist. The always-on payload was then 3
  bytes under its ceiling, so the addition is paid for in place: `20-layout` and
  `32-living-docs` lose a few redundant words in the same sentences, with no
  change of meaning and without itself raising the ceiling (the separate ratchet
  entry above raises it for the release as a whole).
- **Changed:** the *why* behind the root-vs-`/spec` split is now stated where a
  reader hits it instead of only in the reference topic — the scaffold
  `ARCHITECTURE.md` explains that it is the **as-built** model while `/spec`
  holds **intent** (and that keeping them apart is what lets `/steer:audit spec`
  compare them), and `ARCHITECTURE-DIAGRAMS.md` explains the naming. The
  design-export lifecycle no longer tells a shipped product to delete the folder
  holding its living architecture diagram.
- **Fixed:** a long-running skill no longer loses its **guardrails at
  compaction**. Claude Code re-attaches an invoked skill after auto-compaction
  but keeps only the **first 5,000 tokens** of it, and nine skill bodies had
  grown past that — `issues`, `audit`, `work`, `sync`, `tracker-sync`, `init`,
  `build`, `intake` (18,589 B) and `questions` (17,787 B). What fell past the cut was precisely the standing safety content:
  `/steer:work` lost its **Guardrails** (including *the merge is the human
  gate*), `/steer:issues` lost **Guardrails + Coupling rules**, `/steer:audit`
  lost its **read-only output contract** and `all` mode. Because compaction only
  fires on long runs, the protections disappeared exactly when a run had gone on
  long enough to need them. Two fixes, applied together: every skill now
  **front-loads** its guardrails, coupling rules, and output contracts near the
  top of `SKILL.md`; and per-mode/per-phase procedure moved into sibling files
  the dispatcher reads **just-in-time** for the one path it is executing (a tool
  result, so it never competes for the re-attach budget). No instruction was
  dropped — total always-resident skill prose fell roughly a quarter against
  3.22.0. The largest remaining body is `work`, still around 90% of the
  17,500 B cap (`check_context_budget.py --report` for the live figure), so the
  headroom this bought is real but thin: the next substantial skill body still
  has to be factored, not appended.
- **Added:** `check_context_budget.py` now gates a third always-on surface — a
  **per-skill `SKILL.md` body ceiling** of 17,500 bytes (the 5,000-token
  compaction cap at a pessimistic 3.5 B/token). Unlike the rules and listing
  ratchets this is a hard ceiling derived from harness behaviour, not a
  baseline: it does not move down as bodies shrink, and it must not be raised to
  fit new prose. `--report` gained a largest-body row and a per-skill
  percentage-of-cap table for release PRs.
- **Fixed:** `check_fixtures.py`'s workflow-authority check scanned only
  `SKILL.md`, so factoring a skill body across sibling files could relocate the
  `draft->approved` transition-owner marker out of view. Authority is a property
  of the *skill*, so it now scans the whole skill directory — as
  `check_standards.py`'s script-grant check already did.
- **Fixed:** hooks now judge **the repo being acted on**, not the session `cwd`.
  With a git repo nested inside another work tree — a vendored or gitignored
  clone, a `tools/` checkout, a polyrepo member cloned inside its workspace — the
  upward `.git` walk from `cwd` stopped at the *outer* repo while the tool wrote
  to the *inner* one, so delivery mode, profile, graduation signals and tracker
  were all read off the wrong repository. The trunk-push gate was the sharp edge,
  wrong in both directions: it asked about a `pr-flow` push that is autonomous,
  and — the dangerous one — stayed **silent** on a direct-to-`main` push into a
  `solo-trunk` repo that had outgrown pre-MVP. `steer_action_root` resolves from
  the acted-on path (`tool_input.file_path` for editor writes, the `-C <dir>`
  target for git), and `steer_git_c_target` extracts the target the push matcher
  already parsed and then discarded. Wired into `check-bash-actions`,
  `check-write-nudges`, `check-version-pins` and `format-on-write`. A file that
  does not exist yet resolves via its nearest existing ancestor; no path or an
  unresolvable one falls back to `cwd`, so the single-repo case is unchanged.
  `cd <dir> && git push` is still `cwd`-resolved — only `-C` names its target.

- **Fixed:** a PR no longer emits a closing keyword that cannot close anything.
  GitHub honours `Closes #N` only within one repository, so when
  `/spec/tracker.md` declares a `repository:` other than the code repo — a team
  centralizing issues in a tracker repo, or a polyrepo member — every merge left
  its issue open, silently, and `/steer:work` never advanced the lifecycle state
  because it reads the merged PR as the transition evidence. `/steer:work` now
  compares the declared tracker against `gh repo view --json nameWithOwner` and,
  **only on proven mismatch**, writes `Refs owner/repo#N` and closes explicitly
  via `/steer:tracker-sync close`. Any unreadable value keeps the same-repo
  `Closes #N` path byte-identical. The bundled PR template and `ISSUE-WORKFLOW.md`
  carry the matching note.
- **Added:** `steer_tracker_repo` in `lib/scope.sh` reads the declared tracker
  repository, treating an unresolved `[owner/repository]` placeholder, an empty
  value, and a missing file alike as absent. There is deliberately no companion
  helper deriving the repo's own slug from the git remote: a
  `url.<base>.insteadOf` rewrite, GitHub Enterprise, or a remote not named
  `origin` each defeat a host-based parser, and every such failure would fail
  *closed* — restoring the silent bug in the environments hardest to debug.

- **Added:** polyrepo spine unification — a product may now span several repos
  without fragmenting its `/spec`. A **workspace** repo (`spec/workspace.yml`,
  new `workspace` profile) hosts the product spine and owns no code; **member**
  repos carry `spec/PRODUCT.md` pointing at it, plus their own ADRs,
  `ARCHITECTURE.md` and code. Both markers live under `spec/` — the manifest is
  product-level truth, so it belongs with the spine rather than as steer's only
  unnamespaced root file (and one rename from moon's `.moon/workspace.yml`). All of `spec/features/**` lives in the workspace, so a feature
  spanning repos has exactly one `intent.md` instead of none or several.
- **Added:** `lib/scope.sh` gains `steer_polyrepo_role` and three inject-when
  predicates — `polyrepo` (either role), `has-workspace-manifest`, and
  `has-product-pointer`. `orient-session.sh` uses the role to emit a short,
  role-specific SessionStart note in a polyrepo repo. Deliberately **not** an
  always-on rule: the ruleset is capped on its on-disk total, which every
  consumer pays even for a rule scoped to a minority of repos — so a single-repo
  product pays **zero** bytes for this feature, in the rules payload and at
  SessionStart alike.
- **Added:** `/steer:reference polyrepo` (`templates/reference/POLYREPO.md`) —
  the topology in full: role split, artifact homes, resolving the spine from a
  member, honest report scope, and what does and does not cross the repo edge
  (sub-issues and Projects v2 do; milestones, closing keywords, drift gates and
  CI do not). It leads by recommending a monorepo whenever the split is not
  externally mandated.
- **Fixed:** `steer_spine_state` no longer reports a polyrepo member as
  `damaged`. A member's spine is partial by design, so requiring the
  product-level files sent `/steer:setup` into a permanent repair loop and would
  have had `/steer:sync` reinstall the very files the topology de-duplicates —
  recreating the split-brain spine. Members are now validated against
  `PRODUCT.md` alone; a genuinely incomplete single-repo spine still reports
  `damaged`.
- **Changed:** `/steer:setup`, `/steer:init`, `/steer:next`, `/steer:status` and
  `/steer:audit` are topology-aware. Reports must now name the members they
  covered and flag any they could reach neither locally nor over the GitHub
  gateway as **uncovered**, so a fraction of a product is never presented as the
  whole.
- **Added:** polyrepo **local runtime** for the `workspace` profile — one
  `mise run dev` boots the whole product. The profile now carries its own
  `mise.toml` (member `ws:*` tasks; the mise `[settings] monorepo_root` +
  `[monorepo]` blocks ship commented, to be enabled with `config_roots` listed
  explicitly and `lockfile = false` once members are cloned), a `compose.yaml`
  that declares no services and `include:`s each member's file, a `.gitignore`
  fragment for the member checkouts and the generated `*.code-workspace`, and
  `scripts/ws.sh`. Members are **git-ignored clones, not submodules**: nothing
  pins a SHA, so a member commit never dirties the workspace and detached-HEAD
  work loss is off the table. The workspace keeps `scripts/worktree-env.sh`,
  which is what gives its aggregated stack a Compose project name distinct from
  every member's standalone one.
- **Added:** `mise run ws:clone` / `ws:sync` / `ws:status` / `ws:code` / `ws:list`
  in a workspace repo, backed by the shipped `scripts/ws.sh` — so they work for a
  teammate with no Claude Code, the same reason the version-pin scripts are
  committed copies. `spec/workspace.yml` is the single source of truth for the
  clone paths, the `include:` list, the `.gitignore` lines and
  `[monorepo].config_roots`; `ws:status` reports where the `include:` list and
  the `.gitignore` lines have drifted from it (the commented `config_roots`
  block is not machine-checked).
  `ws:sync` is fetch + fast-forward **only** — it refuses a dirty tree, a detached
  HEAD, a branch other than the declared one, or a divergence, and one unreachable
  remote never aborts the sweep.
- **Changed:** `/steer:work` resolves the spine from `spec/PRODUCT.md` before
  reading the tracker or a feature's specs. Previously a member repo had no local
  `spec/tracker.md` and no `spec/features/**`, so the skill stopped at its first
  precondition or read a missing `intent.md` as "unspecified" — the one failure
  the workspace topology exists to prevent. In a member the closing-ref mismatch
  is now treated as structural rather than incidental: always
  `Refs owner/repo#N` + an explicit close.
- **Changed:** `/steer:issues`, `/steer:protect` and `/steer:roadmap` are
  topology-aware. `issues` reads the tracker from the workspace and states which
  edges cross repos (sub-issues do, closing keywords do not). `protect` names the
  sibling repos still unprotected instead of letting a one-repo verdict read as
  product-wide, and says plainly that org-level rulesets need GitHub Team or
  Enterprise. `roadmap` moves the release axis off Milestones — which cannot span
  repositories — onto a Project iteration/single-select field, recorded as the one
  named exception to its native-attributes-only guardrail.
- **Changed:** `/steer:adopt` handles one product spread across several existing
  repos: recommend a monorepo out loud first, then bootstrap the workspace before
  any member, and install `spec/PRODUCT.md` in a member *instead of* a full spine.
  Reverse-engineering a complete spine into each repo was the one way adoption
  could manufacture the split-brain the topology removes.
- **Changed:** `/steer:sync` reconciles the workspace flavor of `mise.toml`,
  `compose.yaml` and `scripts/ws.sh` (a workspace bootstrapped before those
  shipped is missing them, not opted out) and never regenerates the resolved
  `include:` list, member `.gitignore` lines or `config_roots` — those are derived
  from a manifest the team owns.
- **Fixed:** `scripts/scan-invocations.sh` is reformatted to satisfy `shfmt`
  (one brace-placement nit). Formatting only, no behavior change — the script
  sat in a blind spot where the repo's pre-commit hook hard-gated `shfmt` but
  `mise run shell` treated it as advisory, so the drift could only surface as a
  rejected commit.
- **Changed:** the bundled CI workflow template refreshes two pins —
  `actions/setup-node` `v6` → `v7` (the action moved to ESM and dropped a dummy
  `NODE_AUTH_TOKEN` export; neither affects the advisory `ai-slop` job's
  `node-version` usage) and `aislop` `0.12.1` → `0.14.0` (same
  `scan . --sarif` interface). The third pin from the same change,
  `@google/design.md@0.3.0`, is recorded in the pinning entry below.
- **Fixed:** every tool the bundled CI workflow template runs through `npx`/`uvx`
  is now version-pinned — `@google/design.md@0.3.0` in the DESIGN.md lint step,
  plus `yamllint@1.38.0`, `ansible-lint@26.6.0`, and `diff-cover@10.4.1`. Each
  previously resolved to whatever was latest at run time, so an upstream release
  could turn a green CI red on an unrelated PR, and every run executed
  unreviewed code. The `diff-cover` case mattered most: that gate can **fail** a
  PR on changed-line coverage, so a floating version could silently move the
  bar. Dependabot cannot see versions embedded in a `run:` block, so these are
  bumped deliberately.

### 3.22.0

- **Plan-mode gate for Medium+ changes.** `rules/80-change-size` now instructs
  starting Medium and larger changes in plan mode (or presenting the plan for
  approval on harnesses without one), so the approach is reviewed while it is
  still cheap to change. Adopted from community Claude Code best practice.
- **Vertical-slice delivery pattern.** `rules/85-practices` gains a baseline
  bullet: deliver a thin end-to-end slice (schema → service → UI) per change
  rather than one horizontal layer at a time, so every merge leaves the
  product working and demoable.
- **Concrete context-hygiene heuristics.** The fallback-nudge section of
  `templates/reference/CONTEXT-HYGIENE.md` now includes the community rules of
  thumb to pass along when recommending user action: ~40% context fill as the
  degradation onset, rewind-over-correct, a guided `/compact` with a verbatim
  focus hint, and fresh-session-per-new-task seeded with the pre-composed
  hand-off.
- **CLAUDE.md size budget in the scaffold.** The bundled product `CLAUDE.md`
  template now states a leanness budget (stay under ~200 lines) and routes
  outgrown sections to `/spec/**` / `ARCHITECTURE.md`, keeping the always-on
  file from bloating over a product's life.
- **`format-on-write` PostToolUse hook.** New hook formats the single file a
  Write/Edit just touched with the repo's own formatter — biome when a root
  `biome.json`/`biome.jsonc` exists, ruff when a root `pyproject.toml` does —
  killing the formatting-only CI round-trip. Config-gated and fail-safe
  (activates only when the repo already carries the formatter's config — a root
  `biome.json`/`biome.jsonc`, or a root `pyproject.toml` — and the binary is on
  PATH; otherwise a silent no-op), never a tree sweep, always fail-open, and
  exempt in the plugin's own source repo. Claude-only: Copilot ports only
  blocking PreToolUse gates, and this hook has no decision to influence.

### 3.21.0

- **Copilot parity: generate the last two hand-maintained mirrors.** Closes the
  generate-vs-gate asymmetry from the previous change — the MCP and hook mirrors
  had drift gates but no generators, so a human still hand-edited two files per
  change. Added `gen_copilot_mcp.py` (renders `vscode/mcp.json` from `.mcp.json`,
  translating the auth placeholder via an `AUTH_INPUTS` map), `gen_copilot_hooks.py`
  (renders `copilot-hooks.json` from `hooks.json` — the ported subset declared in a
  `COPILOT_HOOKS` table, reshaped into Copilot's flat schema with
  `STEER_HOOK_TARGET=copilot` + fail-open `|| true`; emitted as strict JSON since
  the Copilot CLI hook parser isn't documented to accept JSONC), and
  `gen_copilot_manifests.py` (stamps the Copilot plugin + marketplace manifest
  versions from the source `plugin.json`). All three join `mise run gen:copilot`,
  and `check_copilot_mcp.py` / `check_copilot_hooks.py` are now byte-equality drift
  gates like the instructions/prompts/agents gates. No Copilot artifact is
  hand-maintained anymore. The regenerated `vscode/mcp.json` carries a
  generated-do-not-edit header and canonical formatting; consumers install it via
  `/steer:init` unchanged.
- **Copilot parity: symmetry meta-gate.** Added `check_copilot_symmetry.py`
  (in `plugin-check`) asserting every `scripts/gen_copilot_*.py` is wired into the
  `gen:copilot` task and every `scripts/check_copilot_*.py` into `plugin-check`, so
  a future Copilot mirror can't reintroduce parallel hand-editing by shipping
  without a generator or gate. Concept doc + AUTHORING matrix updated.
- **Environments pointer in the app guide.** Added an **"Environments"**
  subsection to the `app-docs.md` operational runbook — a small
  `environment | URL | health check | notes` table for the deployed surfaces,
  with an explicit non-secret guardrail (public URLs, health endpoints, and
  dashboard links only; connection strings and credentials stay in SSM /
  Secrets Manager per the secrets rule, with just the variable name in
  `.env.example`). Follows the file's own index-splits-when-it-grows idiom
  (graduates to `spec/app/environments.md`) and points to `infra/README.md`
  for deploy/promotion mechanics — so there's now a sanctioned home for
  dev/qa/prod URLs without inviting secrets into the repo.
- **Copilot parity: drift gates for the last two hand-maintained mirrors.** The
  MCP and hook surfaces were the only Copilot dimensions without a build-time
  sync gate (instructions, prompts, and agents already have one each). Added
  `check_copilot_mcp.py` — the VS Code `vscode/mcp.json` scaffold must expose the
  same server set and configs as the plugin's `.mcp.json` (only the auth
  placeholder may differ) — and `check_copilot_hooks.py` — every script the
  Copilot `copilot-hooks.json` invokes must exist and be wired into `hooks.json`,
  with `STEER_HOOK_TARGET=copilot` and fail-open `|| true`. Both run in
  `plugin-check`, so adding an MCP server or renaming a hook script on the Claude
  side can no longer silently leave the Copilot side behind. Concept doc updated.
- **Brevity pass on the always-on rules.** Strengthened `87-output-discipline`
  from two bullets to four — keep responses tight, comments the exception, write
  the least code that does the job, and keep durable prose (specs, ADRs, PR
  descriptions, docs, the standards themselves) lean — so the discipline now
  covers all three surfaces steer writes into: chat, code, and committed prose.
  Added an early **"Be concise by default"** line to the `00-router` preamble so
  the register is set from the first-injected rule. Trimmed padding from
  `00`, `05`, `10`, `26`, `30`, `52`, and `90` to stay within the always-on
  context budget; no directive, gate, or cross-reference changed. Moved the
  mise PATH-shadowing rationale from `15-commands` into `CONVENTIONS.md` →
  Toolchain (the rule keeps the diagnostics + `/steer:doctor` pointer) and
  compressed `10-stack`'s allow-pin remedy detail (the hook's denial message
  carries it). Copilot instructions regenerated from the rules.
- **Misrouting feedback invite in `/steer:next` and `/steer:help`.** Both now
  end their readout/menu with one line inviting the user to flag a misrouted
  ask, reported upstream via `/steer:report` so the routing-eval fixtures grow
  from real failures (PLAN.md Phase 4 close-out).

### 3.20.0

- **Spec rigor (Phase 3).** Three additions adopted from the Spec Kit
  comparison:
  - **`/steer:spec clarify <id>`** — a structured de-ambiguation sweep run
    before intent approval (step 4 of the default flow, also on demand):
    interrogates the draft against the classic gap classes (edge cases, error
    paths, permissions, data lifecycle, non-functional constraints,
    out-of-scope boundary) and converts every real gap into a structured
    `Q-NNN` open question — never loose prose, never an invented answer.
  - **Cross-artifact analyze checks in `validate`** — a pre-implementation
    consistency pass (all warnings): acceptance criteria with no contract
    behavior, contract behaviors no criterion asks for, tracker scope the
    intent doesn't carry, and criteria failing the quality bar.
  - **`## Acceptance criteria` section in the intent template** — a canonical
    home (previously criteria had nowhere structured to land) with the
    testable / observable / bounded quality bar that `validate` warns
    against.

- **Progressive disclosure (Phase 2).** Three usability changes for new users:
  - **Lite mode** — `/steer:spec` now runs spec-only on an unmanaged repo (no
    bootstrap required): the feature intent drafts under `spec/features/<id>/`
    with no toolchain or scaffold, and `/steer:setup` is surfaced as the
    follow-up instead of the precondition. The router's bootstrap-precedence
    rule carries the exception; feature CODE still requires the bootstrap
    first.
  - **Onboarding card** — the unmanaged-repo SessionStart notice is rewritten
    as a compact plain-language orientation ("you can just say what you
    want"), leading with the three things a new user can say — think an idea
    through (lite mode), build an app, set the repo up — instead of a wall of
    bootstrap prose (~25% shorter).
  - **Tiered `/steer:help`** — the menu leads with the six essentials (setup,
    spec, build, work, next, status) and folds the remaining front doors under
    journey groups, so a new user sees six lines, not twenty. Still rendered
    from the live router table.

- **Always-on context cut, pass 2.** The next tier of rules
  (`53-autonomous-loops`, `26-context-hygiene`, `88-artifacts`, `20-layout`,
  `24-worktrees`, `22-housekeeping`, `85-practices`, `32-living-docs`) is
  trimmed to imperatives — rules injection drops to 62,058 bytes (69,335
  before Phase 1) with every gate, constraint, and cross-reference preserved;
  the context-budget ratchet re-arms at 62,500. Copilot instructions
  regenerated from the same sources.

- **Always-on context cut (Phase 1, pass 1).** The skill-listing routing
  surface (frontmatter `description` + `when_to_use`) drops 39% (17,950 →
  10,867 chars) — 18 skills rewritten to purpose + primary trigger, with
  dropped scope-boundary prose moved into the skill bodies (loaded only on
  invocation). The heaviest always-on rules (`00-router`, `45-commit-autonomy`,
  `30-spec-workflow`, `10-stack`, `36-issue-first`) are trimmed to their
  imperatives (rules injection 69,335 → 65,508 bytes) with no behavioral
  change — every gate, mode, and cross-reference is preserved; routing
  vocabulary is pinned by the new routing-fixture net. Copilot artifacts
  regenerated from the same sources.
- **SessionStart hook consolidation.** The five startup/resume session checks
  (template drift, open questions, unmanaged repo, fault surfacing,
  graduation) now run through one `session-checks.sh` orchestrator — a single
  hooks.json registration instead of five, cutting per-hook harness overhead
  at every session start. The individual check scripts are unchanged and stay
  individually testable; the orchestrator only sequences them
  (failure-isolated, registration order, always exit 0).
- **One-shot workspace snapshot for `/steer:next`.** New read-only
  `scripts/workspace-snapshot.sh` gathers every local reconstruction dimension
  (git state, spine + version drift, feature statuses, open questions with
  placeholder seeds excluded, Proposed ADRs, work claims, build/adoption
  markers, declared tracker system) in a single call, replacing the
  call-by-call cold sweep; `/steer:next` starts from it and fetches only the
  live dimensions (PR/CI via `gh`, issue state via `/steer:tracker-sync`)
  separately, batched with minimal output. Falls back to the manual sweep if
  the helper is unavailable.

### 3.19.0

- **GitHub Copilot parity: custom agents, path-scoped instructions, VS Code MCP,
  and cloud coding-agent setup.** Brings the Copilot/VS Code surface up to the
  current Copilot feature set so it is usable like Claude Code, all from the same
  single sources of truth with build-time drift gates:
  - **Custom agents** — steer's `agents/` subagents now port to
    `.github/agents/*.agent.md` (the format formerly called custom chat modes),
    selectable in the Copilot Chat agent picker. Ships `steer-reviewer` (read-only;
    Claude `Read`/`Grep`/`Glob` mapped to Copilot `codebase`/`search`).
    New `gen_copilot_agents.py` + `check_copilot_agents.py`.
  - **Path-scoped instructions** — genuinely area-specific rules (currently the
    infra/IaC stack rule) are emitted as `.github/instructions/*.instructions.md`
    with an `applyTo` glob and **excluded** from the flat `copilot-instructions.md`
    (no double-load) — the Copilot analog of the SessionStart hook's `inject-when`
    trait gating. `gen_copilot_instructions.py` / `check_copilot_instructions.py`
    extended to emit + gate them.
  - **MCP in VS Code** — the scaffold now ships `.vscode/mcp.json` (VS Code
    `servers` schema) mirroring the plugin's Claude-Code MCP servers (GitHub for
    `/steer:tracker-sync`, markitdown, context7), since Copilot/VS Code does not
    read the plugin's `.mcp.json`.
  - **Cloud coding agent** — opt-in `templates/github/workflows/copilot-setup-steps.yml`
    boots the mise toolchain + `dev:setup` so GitHub's Copilot coding agent runs
    steer repos under the pinned versions; it reads the same instructions and opens
    draft PRs (human merge gate intact, fits the autonomous-loop rules).
  - **Prompt-file capsules** improved — reframed to drive the workflow in Copilot
    (not "Claude-only"), cross-references rewritten `/steer:x` → `/steer-x`, and
    review-gated skills point at the `steer-reviewer` agent.
  - Wires the new generators/gates into `mise run gen:copilot` and `plugin-check`,
    maps the new install paths in the scaffold `MANIFEST.md`, updates `/steer:init`
    and the Copilot-support docs.

- **Baseline rule: keep non-ASCII typographic characters out of code and values.**
  Adds an always-on baseline pattern (rule `85-practices`, mirrored in the
  `/steer:reference conventions` full prose as a matched pattern + anti-pattern):
  em/en dashes, arrows, smart quotes, ellipsis, and non-breaking spaces belong in
  prose and docs but must never land in code, identifiers, config keys/values, or
  any string bound for an external API or system — use the ASCII equivalent, and
  ASCII-clean text when copying it into code or a value. Closes the gap behind a
  self-reported failure where a `→` mirrored into a Terraform `role_description`
  broke `aws_iam_role` creation (AWS IAM's `description` permits only ASCII plus
  Latin-1). Also ASCII-cleans the non-ASCII characters that remained inside the
  conventions reference's own fenced code examples (arrows and em-dashes in TOML
  comments) so those examples model the rule. (#373)

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

# Configuration & rules

The always-on **rules** under `plugins/steer/rules/` are the plugin's operating
manual. They are injected into every managed session by `inject-standards.sh`
([Hooks](hooks.md)) and concatenate in **lexical order** by numeric prefix -
delivered in several SessionStart parts, because Claude Code caps one hook
command's output at 10,000 characters (see the hook's row in [Hooks](hooks.md)).

!!! note "Numbering has intentional gaps"
    Prefixes are spaced (e.g. `15` -> `30` -> `35`) so new rules can slot between
    existing ones. Gaps are headroom - files are never renumbered to make the
    sequence contiguous.

## The ruleset

| Rule | Topic |
| --- | --- |
| `00-router.md` | Operating-manual entry point - **you are the router**: map a plain-language goal to the owning skill and invoke it yourself, announcing it at the start and naming it again in the handoff heading. Routing moves navigation, never authority; bootstrap precedes feature code; an intent-switch is named, never dropped. **The route does not depend on what the session can do** - plan mode, a read-only session or a client with fewer tools do not change the owning skill, and "I have no Write/Edit/Bash here, so I'll just give the answer" is named as the misroute it is, since it leaves nothing claimed, branched or recorded ([#611](https://github.com/element22llc/e22-plugins/issues/611)). Also names what deliberately is *not* in the always-on payload and which skill loads it. Its *You are not the gate* section states that there is no path-based permission boundary and the reviewing dev is the hard gate; *When steer itself misbehaves* routes a plugin defect to `/steer:report`, which auto-files after scrubbing. |
| `03-output.md` | **Earn every line**, in three parts. *Output discipline* - default to less everywhere; write the least code that does the job; durable prose informs rather than impresses. *Responses* - lead with the result and stop when it is said; a progress update is one or two sentences, a final report is what changed / what was verified / what is next, with no closing offer (which binds a skill too); hook notices and injected context are never echoed, the one exception being the skill's own name in the handoff heading. *Code comments* - why-only: the default is no comment, test each one by deleting it, never restate the code or keep dead code, config gets one header line, and a dense file is not a licence to add more (advised at write time by `check-comment-density.sh`, audited by the comment-noise dimension). |
| `05-roles.md` | Who you are working with. |
| `10-stack.md` | Stack defaults (app / service profile) - **e22 org pack** (`inject-when=org-e22`), and the home of the baseline patterns' default-stack instances and the deployed secret-store default. |
| `12-stack-infra.md` | Stack - infrastructure / IaC. **e22 org pack**, injected when the repo does IaC *and* follows the pack (`inject-when=has-iac&org-e22`). |
| `15-commands.md` | Useful commands - **e22 org pack** (`inject-when=org-e22`). |
| `30-spec.md` | **The product spine**, in three parts. *Spec workflow* - the triggers that create an artifact (feature intent + contract, ADR by reversal cost, contract on a behavior change, open questions, a tracker-born feature), plus the brownfield sequence, the bootstrap-first rule (`/steer:setup`) and UI work with or without a design export. *Durable decisions* - a decision belongs in the spine, never only in chat or assistant memory, and bootstrap comes before the capture. *Living documentation* - update the owning artifact in the same change as the code, with the notable-event rule for `/spec/history/`, "applying a settled decision is not a new decision", the internal-ids ban on end-user copy, and the polyrepo member's write-through. Full routing table in the `traceability` reference. |
| `33-spec-workflow-openspec.md` | Spec workflow - OpenSpec backend. Injected only where `openspec/` carries a structural marker (`inject-when=has-openspec`); remaps the spec artifacts onto the `/opsx:*` commands and leaves every other rule unchanged. ADRs, the tracker declaration and the app guide stay steer's, under `openspec/steer/`. |
| `35-tracker.md` | Issue-tracker integration, client-agnostic - `/spec/tracker.md` declares the system and ref format; refs live in the intent, the PR and the history entry; a question stays a `Q-NNN` open question until it needs an owner, blocks several features, needs outside input, or would outlive the session, and is then promoted to an issue. On GitHub, `/steer:work issues` is the lifecycle and `/steer:tracker-sync` the gateway. |
| `36-issue-first.md` | Issue-first (GitHub-adopted repos). |
| `40-testing.md` | Testing - a feature change carries its tests in the same PR, a bug fix carries a regression test that fails before and passes after, and a failing test is never deleted or skipped to make CI pass. Coverage is a signal, not a target: cover what you touch, prioritise critical paths and error handling, surface a drop on changed code as drift, and gate only changed-line coverage - the reviewer judges adequacy. |
| `45-delivery.md` | **How work reaches users**, in three parts. *Commit autonomy* - commit, push and open the PR without asking; the merge is the gate. Two declared modes, pr-flow (the default) and solo trunk, with `/steer:setup protect` moving a repo between them; Conventional Commit subjects and a changelog fragment for anything that ships; CI watched to conclusion after every push (see [Authorization model](../concepts/authorization-model.md)). *Deployment & environments* - the repo declares its model in `policy/delivery.yml` and the rule follows it, with the observability, rollback and secrets-at-rest baselines; merge and deploy stay human in every model. *Parallel worktrees* - trust the worktree, start services through `mise` so the per-worktree isolation applies, and clean up what you started. |
| `50-done.md` | **What finishing a change means**, in four sections plus the audit-alignment clause. *Definition of Done* - five items: intent understood, appropriately tested, CI green, the contracts and docs this change actually affected updated, merge and deploy through the required human gates; deliberately not a restatement of every other rule, and deferred (never waived) under a declared production hotfix. *Verify loop* - name the check that proves the task done, loop against the harness until green, cap the loop and report what blocked you, never loop on uncheckable work. *Drift gates* - surface drift before merge by flagging its class in the PR; a flagged class blocks merge and you may not waive your own flag. *Audit-aligned delivery* - aligned with SOC 2 / ISO 27001, never "compliant". *End-of-session checklist* - report open items only. |
| `53-autonomous-loops.md` | Autonomous loops - automate the navigation, never the authority; a loop may discover, triage, draft, push its own branch, and open a **draft** PR, but stops at every human gate (merge, deploy, ADR ratification, secrets). **Opt-in** (`inject-when=automation-optin`): injected only where the repo declares `policy/automation.yml` with `loops: true`, which `/steer:loop scaffold` writes alongside the workflow, on the dev's confirmation and before anything else. |
| `60-high-risk.md` | High-risk areas - auth, authorization, migrations, infrastructure, secrets, deletion, billing, deploy/release logic: scope with the dev before any code, contract or ADR first. Relaxed only while the **product** is pre-production, and never for real secrets, `/infra`, deploys or real third-party calls. Its *Secrets handling* section carries the never-commit rule, the local `.env` bootstrap, and "deployed secrets live in the declared store". |
| `61-gates.md` | Answering a human gate in-session - a gate needs the deciding human's answer, not a particular channel, so where that human is present it is collected by an **Approve · Reject · Decide later** prompt and recorded with its ratifier, date, and channel. Covers ADR `Proposed -> Accepted`, intent `draft -> approved`, and `--reviewed` plan sign-off; merge, deploy, real secrets, `/infra`, and protected-branch pushes are **never** promptable. Its *Hotfix / incident fast-path* section holds the one sanctioned speed lever for a production incident (`/steer:work --hotfix`), which relaxes ceremony and ordering, keeps every authority gate, and owes a mandatory follow-up. Full protocol in the `gates` reference. |
| `80-change-class.md` | Change classification - **authoritative for per-change ceremony**; Issue-first takes its threshold from it, and the Definition of Done holds in full for every class. Trivial (no observable behavior change) needs no issue, spec, ADR, or plan and the PR is the work record; Behavioral carries tests and the owning `contract.md`; a high-risk area is High-risk at any size; an arguable class takes the heavier one. |
| `85-practices.md` | Baseline patterns, stated as principles so they hold on any stack (the org pack names the instances) - typed by default, schema-validated boundaries (incl. JSON/YAML config & data files), parameterized data access, server-first, nothing silenced, every import resolves to a declared dependency, ASCII everywhere (no typographic characters in any authored text). |

!!! note "Conditional injection"
    Some rules carry a first-line `<!-- steer:inject-when=... -->` marker and are
    injected only when their scope applies (see
    [`inject-standards.sh`](hooks.md)). The code-loop rules - `35-tracker`,
    `40-testing`, `45-delivery`, `50-done`,
    `80-change-class`, `85-practices` - are marked
    `code-project`, so they are **skipped in knowledge-work mode** (a confidently
    non-code folder, e.g. a Claude Cowork product-owner workspace). So is every
    *other* marked rule: knowledge mode skips a rule for carrying **any**
    `inject-when` marker, before the predicate is even evaluated, so the org
    pack goes too. `12-stack-infra`,
    `33-spec-workflow-openspec`, `36-issue-first` and
    `53-autonomous-loops` are likewise
    scoped - respectively to
    repos that do IaC **and** follow the e22 org pack (`has-iac&org-e22`),
    drive the spine with OpenSpec (`has-openspec`),
    use GitHub as the tracker (`tracker-github`),
    and those that have declared the automation opt-in (`automation-optin`).
    `automation-optin` is the only predicate that fails **closed**: every other
    token injects on an unreadable signal, because a safety rule must never be
    dropped silently, whereas rule 53 governs machinery a repo only has once it
    has asked for it. `10-stack` and `15-commands` carry `org-e22` alone.
    Tokens compose with `|` for OR and `&` for AND, AND binding loosest.
    Polyrepo topology is deliberately **not** an
    always-on rule. (The original reason - that the ruleset was capped on its
    on-disk total, so a scoped rule cost every consumer in full - no longer
    holds: since the injected-payload re-base the budget gate measures the *injected* payload, and
    scoping now earns full credit. The delivery choice stands on its own merits;
    only the budget argument for it has lapsed.) It is delivered instead by a
    `spec/workspace.yml` / `spec/PRODUCT.md`-gated note inside
    `orient-session.sh` - the hook itself speaks in every managed repo; only the
    topology block is marker-gated. That block is registered on the same
    `startup|resume|clear|compact|fork` matcher as the ruleset, so it survives a
    `/clear`, a resume, auto-compaction and a forked session. The router, spec, output (`03`), roles, **gates (`61`)** and high-risk
    rules carry no `inject-when` marker and so stay always-on.

!!! note "Standards that are not always-on rules"
    Housekeeping, context hygiene, Artifact rendering and design sources are
    org standards with no rule file: each lives in full in
    `templates/reference/` (`HOUSEKEEPING.md`, `CONTEXT-HYGIENE.md`,
    `ARTIFACTS.md`, `DESIGN-SOURCES.md`) and is loaded by the skill that needs
    it - `/steer:work tidy`, the Artifact-rendering skills, and the internal
    `/steer:reference` loader, which Claude reaches by topic.
    The router names them so a session routes there rather than improvising, and
    keeps the two context lines that bind no particular skill (delegate a heavy
    sweep; route a durable fact to disk, never to private session memory).

    The 6.6 rule diet applied the same principle *inside* the surviving rules:
    the greenfield and adopt walkthrough, the living-documentation routing
    table, the worktree isolation mechanics, the mise task-ordering rules, the
    solo-trunk waiver procedure and the deployment baselines' rationale all live
    in `SPEC-FRAMEWORK.md`, `TRACEABILITY.md`, `CONVENTIONS.md` and `GATES.md`.
    Each rule keeps the sentence a session must act on without loading anything,
    and names the reference for the rest.

## Code intelligence (LSP)

`plugin.json` declares two **language servers**, so Claude Code gets real
compiler diagnostics after every edit - and jump-to-definition / find-references -
instead of inferring what a change broke from the surrounding text. They match
the org stack defaults in rule `10-stack`:

| Server | Command | Files |
| --- | --- | --- |
| `typescript` | `typescript-language-server --stdio` | `.ts` `.tsx` `.mts` `.cts` `.js` `.jsx` `.mjs` `.cjs` |
| `python` | `pyright-langserver --stdio` | `.py` `.pyi` |

!!! warning "On a scaffolded repo the `typescript` server may be the inert one"
    The bundled scaffold also enables `typescript-lsp@claude-plugins-official`
    (`.claude/settings.json`), whose server declares the **same** name, command
    and extensions as steer's. When two enabled servers claim an extension, *"the
    first server registered handles files with that extension and the others never
    start"*, and the `/plugin` interface shows a warning naming the active one.
    Registration order is not steer's to control, so on a scaffolded repo one of
    the two is inert - TS diagnostics still work, but `restartOnCrash: false` may
    not be the setting in force. Which side should give way is an open question,
    not a resolved design.

!!! info "A server activates only when its binary is on `PATH`"
    Claude Code starts each server by name, so a repo without
    `typescript-language-server` or `pyright-langserver` installed gets no
    language server for those files - nothing else changes. A missing binary is
    reported rather than silent: the server fails to start and Claude Code shows
    `Executable not found in $PATH` in the `/plugin` **Errors** tab.
    `restartOnCrash: false` covers a different case - a server that *crashes* is
    left stopped instead of restarted. That key needs **Claude Code v2.1.205+**;
    an older CLI drops a server that declares it silently, with the reason only
    in `claude --debug` output. Install them
    per-machine (`pnpm add -g typescript-language-server typescript`,
    `pnpm add -g pyright`) or per-repo as devDependencies; steer does not install
    them for you, and deliberately does not gate on them.

    This is also the supported successor to a code-intelligence **MCP** server:
    it is declared in the manifest, it is not a process the plugin has to pin,
    and diagnostics arrive on the edit path rather than on request.

## Tooling knobs

- **`policy/versions.yml`** - version floors; `check-version-pins.sh` blocks pins
  that violate it.
- **`policy/branch-protection.yml`** - the branch-protection ruleset
  `/steer:setup protect` verifies the live GitHub settings against, and applies on
  explicit confirmation.
- **`policy/delivery.yml`** - how code reaches users here: environments,
  `deploy_on_merge`, `production_gate`, review apps, observability. Rule
  `45-delivery` follows it rather than imposing a model, and `/steer:setup protect`
  and `/steer:work promote` read `production_gate`.
- **`policy/org.yml`** - which org pack this repo follows. `pack: e22` (also the
  meaning of an absent file) delivers the house stack, useful-commands and
  secret-store rules; any other value leaves only the vendor-neutral core.
- **`policy/automation.yml`** - `loops: true` declares the autonomous-loop
  opt-in, which is what puts rule `53-autonomous-loops` in the always-on
  payload - the boundary prose a session is held to once the repo runs a loop.
  It does not gate the model-only `/steer:loop` itself, which a plain-language
  ask still reaches; what refuses a repo that never opted in is the skill's own
  first step. Written by `/steer:loop scaffold`, but only on the dev's
  confirmation, taken before the workflow is instantiated: the opt-in is a
  decision, not a file the skill writes for them.
- **`STEER_NO_WORKTREE_TEARDOWN`** - set to any non-empty value to stop the
  `SessionEnd` / `WorktreeRemove` hooks touching a worktree's Docker stack.
- **`STEER_WORKTREE_OFFSET`** - pin one worktree's host-port offset when two
  draw the same one (rule `45-delivery` § Parallel worktrees), instead of editing shared files.
- **`CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS`** - Claude Code's own knob, not
  steer's: raises the `SessionEnd` budget above its 1.5s default so the teardown
  has time to finish (see [Hooks](hooks.md)).
- **`STEER_CLAUDE_CODE_VERSION`** (in `mise.toml`) - the pinned Claude Code
  version CI installs, for reproducible `claude plugin validate --strict`.
  Both manifests are validated in strict mode, so warnings the runtime
  tolerates - unrecognized fields, missing metadata - fail the build.

Rules are kept lean and imperative on purpose. Long-form prose lives in
`plugins/steer/templates/reference/` and is surfaced through a skill, never
added to `rules/`. That leanness is **enforced, not aspirational**: CI's
`check_context_budget.py` gate holds hard ceilings over three context surfaces:
the **injected rules payload**, the total skill-listing `description` +
`when_to_use` characters (ratcheted - re-armed at each reduction, so it normally
only shrinks or holds), and the per-skill `SKILL.md` body size.

**The rules gate measures what a session actually receives**, in characters -
the runtime's own unit - by running every registered part of the real
`inject-standards.sh` against three fixture profiles: `knowledge` (a non-code
folder, which drops every marked rule), `code` (a typical product repo) and
`code-max` (every scope predicate satisfied - the worst case any consumer pays).
All three are gated, against the same two harness facts: no single part may
exceed the 10,000-character cap Claude Code puts on one hook command's output
(the hook fills each part to 9,500 and the slack is never spent on rules), and
no eligible rule may be dropped for lack of parts. A rule that does not fit
fails the build with its name. Scoping a rule with an `inject-when` marker
*reduces* the gated payload for the repos it does not apply to, so it is a real
budget lever; dropping a rule's marker, which quietly pushes it onto every
knowledge-work session, shows up as growth in the `knowledge` profile. The
history below describes the retired on-disk ratchet and is kept as the record of
why it changed.

The default answer to "this rule doesn't fit" is therefore
**trade prose out first**: relocate rationale into
`plugins/steer/templates/reference/`, scope the rule with an `inject-when`
marker, or deliver a scoped rule through a hook instead of `rules/` (the polyrepo
precedent above). Registering one more part in `hooks/hooks.json` is the last
resort and a deliberate, reviewed change - one more SessionStart process and up
to 9,500 more always-on characters in every session.

These two are **policy numbers, not harness limits**, so they *can* be raised -
which is why each raise carries a recorded reason in the gate script rather than
happening quietly.

What follows is the history of the **retired on-disk rules ratchet**, kept
because it is the evidence for that re-base: read end to end, it is a ceiling
moving seven times for a net +9.1% while its target never moved off 62,500 and was
never met, and the gate script's own note names the same failure mode - a tight
ceiling dictating the *wording* of a correctness fix instead of bounding its cost -
five times before reproducing it a sixth. Every raise was argued honestly and
every raise still happened, which is what says the number was wrong rather than
the authors undisciplined: it gated a payload nobody received, so it could not be
paid down by the one move that actually reduces always-on weight.

The rules ceiling was raised five times. First from
62,500 to 65,200, to fund rule `61-gate-prompts`: the ratchet had drifted to 32
bytes of headroom, so the only way to add the rule was compressing unrelated gate
rules, and that trade deleted ~1 KB of rationale prose that existed nowhere else in
the repo. Paying the bytes was judged cheaper than losing the prose. Then from
65,200 to 65,300, because the polyrepo work landed in the same cycle and consumed
that new headroom down to 7 bytes - leaving three factual corrections to always-on
rules (a wrong `/steer:setup doctor` routing claim, a missing `scripts/` entry in the
root allowlist, a mis-cited rule heading) with nothing to spend. Then from 65,300
to 66,500, to fund the worktree-trust step in rule `24-worktrees`: a worktree
created with `git worktree add` **in a plain terminal** is a case no hook can
reach (as is the Copilot CLI, whose manifest ports no trust hook), so the instruction has to be always-on to exist when it is needed. (The
`check-worktree-trust` check covers a session *started* in a worktree at
`SessionStart`, and one *entered* mid-session on `CwdChanged` - see
[Hooks -> Lifecycle events](hooks.md#lifecycle-events).) That raise also
re-armed at measured + ~1% rather than the 5-to-7-byte margins that had made each
previous raise inevitable. Then from 66,500 to 67,300, to fund six
**surface-scoping corrections**: rules 00, 05 and 97 told the agent a SessionStart
hook would flag a condition, which is true in Claude Code but not on Copilot
(whose `sessionStart` discards the raw text those notices emit), and rule 10 promised a hard `deny` that is
only an `ask` on the Copilot CLI - in each case a rule
asserting a safety net that would not be there. Rules 24 and 99 named
`docker:up`/`docker:clean`, which the workspace profile renamed to `ws:*`, so the
cleanup command those rules mandate did not exist in a spine host. Rule 15 now
carries the workspace task vocabulary once and rule 24 cross-references it, paying
back ~120 B of the cost. Finally from 67,300 to **68,400**, to fund the **Tiny**
ceremony exemption in rule `80-change-size` and its two consumers - unlike the
fourth raise this is new capability rather than a correction, so it took an
explicit decision. Making the size class govern needed three always-on
statements (the exemption, the authority claim, the size-gated markers) and could
not be expressed by cross-reference alone, because the rules being exempted are
the ones a session reads. That model was later replaced by change classification,
and the size-gated markers are gone. Trades were made first, as the default requires - the same
change that shrinks a per-change duty paid part of its own cost. Which rules paid,
and how much, is recorded only in the ratchet note in
`scripts/check_context_budget.py`, for the reason given below. Net +511 B, re-armed
at the measured total plus ~1%. The *target* deliberately
stays at the old 62,500, below the ceiling, so the budget report keeps showing
the gap as work to reclaim.

Then, for the first time, the ratchet turned the other way: **68,400 -> 67,500**.
That fifth raise's ~1% headroom had been consumed back down to **178 bytes**,
which made the ceiling load-bearing on the next rule edit of any kind. 1,632 B
were reclaimed across nine rules - 00, 10, 24, 30, 36, 45, 50, 62 and 99 - mostly
by removing prose a `templates/reference/` file already carried, or by compressing
wording in place. The per-rule attribution is recorded in one place only, the
ratchet note in `scripts/check_context_budget.py`; it is deliberately not restated
here, because a second copy of it has twice drifted from the first.

One imperative **did** leave the always-on rules: rule 45's "don't retry a
declined push - graduate instead" is no longer in any rule. It survives in
`GATES.md` and in the trunk-push hook's own repeat reminder, so a Claude session
still meets it at the moment it matters - but the Copilot CLI, where that repeat is
a silent allow, now reads it on demand rather than every session. A deliberate
trade, and the reason "no rule lost an imperative" is too strong a claim to repeat.
The ceiling came down by 900 B - deliberately **less** than was reclaimed - so
headroom grew roughly 5x in the same change that tightened the ratchet, and rule
22's absorbed-source correction then spent 360 B of that (it had been projected at
~150 B). Rule `92-user-facing-copy` then spent what was left, so the
ceiling became load-bearing again. In 5.3.0 that choice was closed by
**re-arming, 67,500 -> 68,200**: a correctness fix to rule 92 cost 17 B against a
7 B margin, so the ceiling was dictating the fix's wording rather than bounding
its cost - the exact failure the 900 B lowering existed to end. Sized at
measured + 1%, restoring a ~690-byte margin. The reclaim half of the choice is
still owed, against the unchanged 62,500 target. For the total on any given tree, run
`uv run python scripts/check_context_budget.py --report` - a figure pinned in
prose goes stale on the next rule edit.

The skill-listing ratchet has moved twice. The first, in 3.23.0, 11,500 -> 11,900
chars, for a different reason than the rules ceiling: not a budget concession but a
**measurement correction**.
`/steer:work`'s `when_to_use` was an unquoted YAML scalar containing `("work on
#123"`, so ` #` opened a comment and the value silently truncated at 75 of 546
characters. The ratchet had been calibrated against that truncated value, reading
22 chars of headroom while the intended payload was ~450 over. Fixing the YAML
necessarily exposed the real total; `work`'s entry was first trimmed 932 -> 747
chars so the raise paid what it could. `LISTING_TOTAL_TARGET_CHARS` stays at
10,000, again below the ceiling.

The second, 11,900 -> 12,400, is a deliberate **re-arming** rather than payment for
any specific edit. The correction above landed at 11,879 of 11,900 - 21 chars - so
the next factual fix to any `description` or `when_to_use` could not be paid for in
place at all. A pre-release audit hit exactly that: three description corrections
had to be engineered as a *length-neutral set*, which is the ratchet dictating the
wording of a correctness fix instead of merely bounding its cost. 12,400 buys ~521
chars - about one mean listing entry - so trading prose out stays a real choice
rather than the only physically available move. The policy is unchanged: trimming
first remains the default, `check_plugin.py`'s per-skill 1,536-char cap is untouched
so no single skill can absorb the new headroom, and the target stays 10,000.

The listing ceiling was then deliberately **held** at 12,400 while 232 chars were
reclaimed alongside the rules trim above (`/steer:reference` stopped
parenthesising each topic its own `when_to_use` already explains in question form;
`work`, `spec` and `intake` dropped restatement). Seven literal subtopic tokens
went with it - `commit style`, `spec routing`, `audit evidence`, `subagents`,
`durable state`, `Mermaid`, `LikeC4` - and they survive nowhere else in the
measured surface; the topics stay reachable through `reference`'s eight doc-name
arguments, so this was a deliberate trade, not a lossless one. Lowering the
ceiling would contradict this block's own basis: 12,400 was chosen to buy ~521
chars, and no reduction from the resulting 11,978 leaves that much. Reclaim more
first, then the ceiling can move.

The third *surface* is per-skill and **not** a ratchet: each `SKILL.md` body is capped at
17,500 bytes. That number is the harness's **compaction re-attach cap** - after
auto-compaction Claude Code re-attaches an invoked skill but keeps only the
first ~5,000 tokens of it, so anything past that point is silently dropped
mid-run. An oversized skill therefore loses its own guardrails exactly when a
run has gone on long enough to compact. steer's skills keep guardrails,
coupling rules, and output contracts near the **top** of `SKILL.md` and factor
per-mode or per-phase procedure into sibling files (`modes/<mode>.md`,
`OPERATIONS.md`, `PROCEDURE.md`, ...) that the skill reads **just-in-time** for
the one path it is executing - a file read that way is a tool result, not skill
content, so it never competes for the re-attach budget. Because this ceiling is
derived from harness behaviour rather than a budget target, it does not move
down as bodies shrink and is not raised to fit new prose.

A companion routing-fixture net
(`tests/fixtures/routing/asks.yml`) pins the vocabulary plain-language routing
depends on, so trimming can never silently break "just say what you want".

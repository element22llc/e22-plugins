# Configuration & rules

The **rules** are the plugin's operating manual. They reach a session by two
different routes, and the split is not cosmetic — it is forced by a hard limit
in Claude Code.

!!! danger "Claude Code caps hook output at 10,000 characters"
    A `SessionStart` hook's stdout is capped at **10,000 characters**. Anything
    longer is written to a file and replaced in context with a ~2 KB preview —
    and the hook still exits 0, so nothing reports a problem. Measured on Claude
    Code 2.1.252: a 9,990-character payload arrives whole, a 10,010-character one
    arrives as a preview.

    steer used to emit its entire 61 KB ruleset through that hook, so sessions
    received the banner and part of `00-router.md` and nothing else. The ruleset
    is now split so the always-on core fits the cap whole, and
    `inject-standards.sh` refuses to overrun: it drops whole rules from the tail
    and says so in-band rather than letting the runtime truncate silently.

## Tier 1 — the always-on core

Five rules under `plugins/steer/rules/`, injected into every managed session by
`inject-standards.sh` ([Hooks](hooks.md)), concatenated in lexical order. They
are sized as a set to fit the cap with headroom (currently ~8.4 K characters
used of 10,000).

| Rule | Topic |
| --- | --- |
| `00-router.md` | Operating-manual entry point: routing policy, gate authority, bootstrap precedence. |
| `05-roles.md` | Who you are working with. |
| `60-high-risk.md` | High-risk areas. |
| `70-secrets.md` | Secrets handling. |
| `95-not-the-gate.md` | You are not the gate — the dev is. |

These five are the standards that must govern **before** Claude touches
anything: who the counterpart is, what is dangerous, what never gets committed,
and who decides. Everything else can wait until the work is in view.

## Tier 2 — path-scoped rules in the consumer repo

The remaining 30 rules ship as `.claude/rules/steer-*.md`, installed into the
managed repo by `/steer:init` / `/steer:adopt` and repaired by `/steer:sync`
(capability `path-scoped-rules`). Each carries `paths:` frontmatter and is
injected **automatically when Claude reads a file it governs** — deterministic
injection, not a decision the model makes.

| Rule | Topic | `paths:` |
| --- | --- | --- |
| `steer-10-stack.md` | Stack defaults. | manifests, Dockerfiles, `mise.toml` |
| `steer-12-stack-infra.md` | Stack — infrastructure / IaC. | `infra/**`, `*.tf`, playbooks |
| `steer-15-commands.md` | Useful commands. | `mise.toml`, workflows, `compose.yaml` |
| `steer-24-worktrees.md` | Parallel worktrees — isolate runtime, clean up after. | `**` |
| `steer-30-spec-workflow.md` | Spec workflow. | `spec/**` |
| `steer-31-decision-capture.md` | Durable decisions land in the spine. | `spec/**`, `docs/decisions/**` |
| `steer-35-issue-tracker.md` | Issue-tracker integration. | `spec/tracker.md`, issue templates |
| `steer-36-issue-first.md` | Issue-first. | `**` |
| `steer-40-testing.md` | Testing rules. | test globs |
| `steer-41-coverage.md` | Coverage as a signal. | test globs |
| `steer-45-commit-autonomy.md` | Commit autonomy (see [Authorization model](../concepts/authorization-model.md)). | `**` |
| `steer-50-definition-of-done.md` | Definition of Done. | `**` |
| `steer-51-verify-loop.md` | Verify loop — bounded iteration to a verifiable end state. | `**` |
| `steer-52-deployment.md` | Deployment & environments (see [Deployment](../concepts/deployment.md)). | `infra/**`, `apps/**`, workflows |
| `steer-53-autonomous-loops.md` | Automate the navigation, never the authority. | `**` |
| `steer-55-drift-gates.md` | Surface drift before merge. | `**` |
| `steer-61-gate-prompts.md` | Answering a human gate in-session. | `**` |
| `steer-62-hotfix.md` | Hotfix / incident fast-path. | `**` |
| `steer-75-compliance.md` | Audit-aligned delivery (SOC 2 / ISO 27001). | `**` |
| `steer-80-change-size.md` | Change-size model — authoritative for per-change ceremony. | `**` |
| `steer-87-output-discipline.md` | Earn every line. (The one-line imperative stays always-on in the router.) | `**` |
| `steer-22-housekeeping.md` | Keep the repo tidy — **the deletion gate: never automatic, always waits for a yes**. | `**` |
| `steer-26-context-hygiene.md` | Delegate heavy runs; route each fact to its canonical home, not private session memory. | `**` |
| `steer-32-living-docs.md` | Document in parallel — **never guess an answer into the spec**. | `**` |
| `steer-85-practices.md` | Baseline patterns — **all data access through a parameterized query layer**. | source globs |
| `steer-88-artifacts.md` | Artifacts are derived views — **never carry secrets, never fabricate a status**. | `**` |
| `steer-90-design-sources.md` | Design sources & UI — the ADR-gated, kill-dated exception. | UI globs, `spec/design/**` |
| `steer-92-user-facing-copy.md` | Internal ids stay out of end-user surfaces. | source + docs globs |
| `steer-97-self-report.md` | File steer's own defects upstream with `/steer:report`. | `**` |
| `steer-99-end-of-session.md` | End-of-session checklist. | `**` |

!!! note "`paths: \"**\"` is the honest answer for action-scoped rules"
    Several rules govern an **action** (committing, ending a session, answering a
    gate), not a file type, so no glob predicts them. `**` loads them on the first
    file Claude touches — later than always-on, but in every session that does
    real work, and vastly better than the status quo it replaced, where they
    reached no session at all.

!!! warning "Tier 2 is repo-bound, not plugin-bound"
    A `/plugin update` refreshes Tier 1 immediately. Tier 2 lives in each managed
    repo, so a rule change reaches it only after `/steer:sync`. `/steer:sync`
    counts the installed files against the plugin's set and repairs a partial or
    missing install; a repo that never adopted them runs without those standards
    and nothing in-session says so.

## The one rule folded into reference prose

`20-layout` — a description of where directories live — moved into
`templates/reference/CONVENTIONS.md`, reachable via `/steer:reference`. It is the
only one of the seven originally demoted that survived an audit for hidden
prohibitions.

!!! warning "Demotion to reference prose is a change of authority, not of address"
    The other six — `22-housekeeping`, `26-context-hygiene`, `32-living-docs`,
    `85-practices`, `88-artifacts`, `90-design-sources` — were promoted back to
    Tier 2 once audited. Each carried prohibitions rather than guidance: the
    deletion gate, "never guess an answer into the spec", "all data access
    through a parameterized query layer" (injection prevention), "never carrying
    secrets", "never fabricate a status, date, count, or finding", an ADR-gated
    exception. A rule reachable only by lookup is a rule that does not apply, so
    a prohibition can never be advisory. Apply that test before demoting anything
    else.

!!! note "Numbering has intentional gaps"
    Prefixes are spaced (e.g. `20` → `22` → `30`) so new rules can slot between
    existing ones. Gaps are headroom — files are never renumbered to make the
    sequence contiguous. The gaps are now wider still, since a rule that moved to
    Tier 2 or to reference prose left its number free in `rules/`.

!!! note "Conditional injection (Tier 1 only)"
    A Tier 1 rule may carry a first-line `<!-- steer:inject-when=… -->` marker and
    then injects only where its scope holds (see
    [`inject-standards.sh`](hooks.md)). None of the five current core rules uses
    one — they are all unconditional — but the mechanism remains for a future
    core rule, and `lib/scope.sh` is still covered by the hook test suite.
    In **knowledge-work mode** (a confidently non-code folder, e.g. a Claude
    Cowork product-owner workspace) every marked rule is skipped and a banner says
    so. Tier 2 scoping is expressed by `paths:` instead, which is why the
    `code-project` / `has-iac` / `tracker-github` markers left with the rules that
    carried them.

    Polyrepo topology is deliberately **not** a rule at all. It is delivered by a
    `spec/workspace.yml` / `spec/PRODUCT.md`-gated note inside `orient-session.sh`,
    registered on the same `startup|resume|clear|compact` matcher as the ruleset,
    so it survives a `/clear`, a resume and auto-compaction.

## Code intelligence (LSP)

`plugin.json` declares two **language servers**, so Claude Code gets real
compiler diagnostics after every edit — and jump-to-definition / find-references
— instead of inferring what a change broke from the surrounding text. They match
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
    the two is inert — TS diagnostics still work, but `restartOnCrash: false` may
    not be the setting in force. Which side should give way is an open question,
    not a resolved design.

!!! info "A server activates only when its binary is on `PATH`"
    Claude Code starts each server by name, so a repo without
    `typescript-language-server` or `pyright-langserver` installed gets no
    language server for those files — nothing else changes. A missing binary is
    reported rather than silent: the server fails to start and Claude Code shows
    `Executable not found in $PATH` in the `/plugin` **Errors** tab.
    `restartOnCrash: false` covers a different case — a server that *crashes* is
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

- **`policy/versions.yml`** — version floors; `check-version-pins.sh` blocks pins
  that violate it.
- **`policy/branch-protection.yml`** — the branch-protection ruleset
  `/steer:protect` verifies the live GitHub settings against, and applies on
  explicit confirmation.
- **`STEER_NO_WORKTREE_TEARDOWN`** — set to any non-empty value to stop the
  `SessionEnd` / `WorktreeRemove` hooks touching a worktree's Docker stack.
- **`STEER_WORKTREE_OFFSET`** — pin one worktree's host-port offset when two
  draw the same one (rule `24-worktrees`), instead of editing shared files.
- **`CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS`** — Claude Code's own knob, not
  steer's: raises the `SessionEnd` budget above its 1.5s default so the teardown
  has time to finish (see [Hooks](hooks.md)).
- **`STEER_CLAUDE_CODE_VERSION`** (in `mise.toml`) — the pinned Claude Code
  version CI installs, for reproducible `claude plugin validate --strict`.
  Both manifests are validated in strict mode, so warnings the runtime
  tolerates — unrecognized fields, missing metadata — fail the build.

Rules are kept lean and imperative on purpose. Long-form prose lives in
`plugins/steer/templates/reference/` and is surfaced through a skill, never
added to `rules/`. That leanness is **enforced, not aspirational**: CI's
`check_context_budget.py` gate holds hard ceilings over three context surfaces.
Two are always-on and ratcheted — the **injected rules payload** and the total
skill-listing `description` + `when_to_use` characters — re-armed at each
reduction, so always-on weight normally only shrinks or holds.

**The rules ceiling was re-based** and now measures what a session
actually receives, in tokens, rather than the `rules/*.md` total on disk. Two
consumer profiles are gated: `knowledge` (a non-code folder, which drops every
marked rule) and `code-max` (every scope predicate satisfied — the worst case any
consumer pays). A typical product repo sits between them and is reported, not
gated. Two things follow. Scoping a rule now *reduces* the gated number, where
under the on-disk sum it changed nothing — so `inject-when` is a real budget
lever, not just a runtime one. And dropping a rule's marker, which quietly pushes
it onto every knowledge-work session, is now caught by the `knowledge` ceiling; the
on-disk sum could never see it, because the bytes never moved. The history below
describes the retired on-disk ratchet and is kept as the record of why it changed.

The default answer to "this rule doesn't fit" is therefore
**trade prose out first**: relocate rationale into
`plugins/steer/templates/reference/`, or deliver a scoped rule through a hook
instead of `rules/` (the polyrepo precedent above).

These two are **policy numbers, not harness limits**, so they *can* be raised —
which is why each raise carries a recorded reason in the gate script rather than
happening quietly.

What follows is the history of the **retired on-disk rules ratchet**, kept
because it is the evidence for that re-base: read end to end, it is a ceiling
moving seven times for a net +9.1% while its target never moved off 62,500 and was
never met, and the gate script's own note names the same failure mode — a tight
ceiling dictating the *wording* of a correctness fix instead of bounding its cost
— five times before reproducing it a sixth. Every raise was argued honestly and
every raise still happened, which is what says the number was wrong rather than
the authors undisciplined: it gated a payload nobody received, so it could not be
paid down by the one move that actually reduces always-on weight.

The rules ceiling was raised five times. First from
62,500 to 65,200, to fund rule `61-gate-prompts`: the ratchet had drifted to 32
bytes of headroom, so the only way to add the rule was compressing unrelated gate
rules, and that trade deleted ~1 KB of rationale prose that existed nowhere else in
the repo. Paying the bytes was judged cheaper than losing the prose. Then from
65,200 to 65,300, because the polyrepo work landed in the same cycle and consumed
that new headroom down to 7 bytes — leaving three factual corrections to always-on
rules (a wrong `/steer:doctor` routing claim, a missing `scripts/` entry in the
root allowlist, a mis-cited rule heading) with nothing to spend. Then from 65,300
to 66,500, to fund the worktree-trust step in rule `24-worktrees`: a worktree
created with `git worktree add` **in a plain terminal** is a case no hook can
reach (as is any Copilot surface, which has no trust hook at all), so the instruction has to be always-on to exist when it is needed. (The
`check-worktree-trust` check covers a session *started* in a worktree at
`SessionStart`, and one *entered* mid-session on `CwdChanged` — see
[Hooks → Lifecycle events](hooks.md#lifecycle-events).) That raise also
re-armed at measured + ~1% rather than the 5-to-7-byte margins that had made each
previous raise inevitable. Then from 66,500 to 67,300, to fund six
**surface-scoping corrections**: rules 00, 05 and 97 told the agent a SessionStart
hook would flag a condition, which is true in Claude Code but not on Copilot
(whose `sessionStart` ignores stdout), and rule 10 promised a hard `deny` that is
only an `ask` on the Copilot CLI and absent in VS Code — in each case a rule
asserting a safety net that would not be there. Rules 24 and 99 named
`docker:up`/`docker:clean`, which the workspace profile renamed to `ws:*`, so the
cleanup command those rules mandate did not exist in a spine host. Rule 15 now
carries the workspace task vocabulary once and rule 24 cross-references it, paying
back ~120 B of the cost. Finally from 67,300 to **68,400**, to fund the **Tiny**
ceremony exemption in rule `80-change-size` and its two consumers — unlike the
fourth raise this is new capability rather than a correction, so it took an
explicit decision. Making the size class actually govern needs three always-on
statements (the exemption, the authority claim, the size-gated markers) and cannot
be expressed by cross-reference alone, because the rules being exempted are the
ones a session reads. Trades were made first, as the default requires — the same
change that shrinks a per-change duty paid part of its own cost. Which rules paid,
and how much, is recorded only in the ratchet note in
`scripts/check_context_budget.py`, for the reason given below. Net +511 B, re-armed
at the measured total plus ~1%. The *target* deliberately
stays at the old 62,500, below the ceiling, so the budget report keeps showing
the gap as work to reclaim.

Then, for the first time, the ratchet turned the other way: **68,400 → 67,500**.
That fifth raise's ~1% headroom had been consumed back down to **178 bytes**,
which made the ceiling load-bearing on the next rule edit of any kind. 1,632 B
were reclaimed across nine rules — 00, 10, 24, 30, 36, 45, 50, 62 and 99 — mostly
by removing prose a `templates/reference/` file already carried, or by compressing
wording in place. The per-rule attribution is recorded in one place only, the
ratchet note in `scripts/check_context_budget.py`; it is deliberately not restated
here, because a second copy of it has twice drifted from the first.

One imperative **did** leave the always-on rules: rule 45's "don't retry a
declined push — graduate instead" is no longer in any rule. It survives in
`GATES.md` and in the trunk-push hook's own repeat reminder, so a Claude session
still meets it at the moment it matters — but the Copilot CLI, where that repeat is
a silent allow, now reads it on demand rather than every session. A deliberate
trade, and the reason "no rule lost an imperative" is too strong a claim to repeat.
The ceiling came down by 900 B — deliberately **less** than was reclaimed — so
headroom grew roughly 5x in the same change that tightened the ratchet, and rule
22's absorbed-source correction then spent 360 B of that (it had been projected at
~150 B). Rule `92-user-facing-copy` then spent what was left, so the
ceiling became load-bearing again. In 5.3.0 that choice was closed by
**re-arming, 67,500 → 68,200**: a correctness fix to rule 92 cost 17 B against a
7 B margin, so the ceiling was dictating the fix's wording rather than bounding
its cost — the exact failure the 900 B lowering existed to end. Sized at
measured + 1%, restoring a ~690-byte margin. The reclaim half of the choice is
still owed, against the unchanged 62,500 target. For the total on any given tree, run
`uv run python scripts/check_context_budget.py --report` — a figure pinned in
prose goes stale on the next rule edit.

The skill-listing ratchet has moved twice. The first, in 3.23.0, 11,500 → 11,900
chars, for a different reason than the rules ceiling: not a budget concession but a
**measurement correction**.
`/steer:work`'s `when_to_use` was an unquoted YAML scalar containing `("work on
#123"`, so ` #` opened a comment and the value silently truncated at 75 of 546
characters. The ratchet had been calibrated against that truncated value, reading
22 chars of headroom while the intended payload was ~450 over. Fixing the YAML
necessarily exposed the real total; `work`'s entry was first trimmed 932 → 747
chars so the raise paid what it could. `LISTING_TOTAL_TARGET_CHARS` stays at
10,000, again below the ceiling.

The second, 11,900 → 12,400, is a deliberate **re-arming** rather than payment for
any specific edit. The correction above landed at 11,879 of 11,900 — 21 chars — so
the next factual fix to any `description` or `when_to_use` could not be paid for in
place at all. A pre-release audit hit exactly that: three description corrections
had to be engineered as a *length-neutral set*, which is the ratchet dictating the
wording of a correctness fix instead of merely bounding its cost. 12,400 buys ~521
chars — about one mean listing entry — so trading prose out stays a real choice
rather than the only physically available move. The policy is unchanged: trimming
first remains the default, `check_plugin.py`'s per-skill 1,536-char cap is untouched
so no single skill can absorb the new headroom, and the target stays 10,000.

The listing ceiling was then deliberately **held** at 12,400 while 232 chars were
reclaimed alongside the rules trim above (`/steer:reference` stopped
parenthesising each topic its own `when_to_use` already explains in question form;
`work`, `spec` and `intake` dropped restatement). Seven literal subtopic tokens
went with it — `commit style`, `spec routing`, `audit evidence`, `subagents`,
`durable state`, `Mermaid`, `LikeC4` — and they survive nowhere else in the
measured surface; the topics stay reachable through `reference`'s eight doc-name
arguments, so this was a deliberate trade, not a lossless one. Lowering the
ceiling would contradict this block's own basis: 12,400 was chosen to buy ~521
chars, and no reduction from the resulting 11,978 leaves that much. Reclaim more
first, then the ceiling can move.

The third *surface* is per-skill and **not** a ratchet: each `SKILL.md` body is capped at
17,500 bytes. That number is the harness's **compaction re-attach cap** — after
auto-compaction Claude Code re-attaches an invoked skill but keeps only the
first ~5,000 tokens of it, so anything past that point is silently dropped
mid-run. An oversized skill therefore loses its own guardrails exactly when a
run has gone on long enough to compact. steer's skills keep guardrails,
coupling rules, and output contracts near the **top** of `SKILL.md` and factor
per-mode or per-phase procedure into sibling files (`modes/<mode>.md`,
`OPERATIONS.md`, `PROCEDURE.md`, …) that the skill reads **just-in-time** for
the one path it is executing — a file read that way is a tool result, not skill
content, so it never competes for the re-attach budget. Because this ceiling is
derived from harness behaviour rather than a budget target, it does not move
down as bodies shrink and is not raised to fit new prose.

A companion routing-fixture net
(`tests/fixtures/routing/asks.yml`) pins the vocabulary plain-language routing
depends on, so trimming can never silently break "just say what you want".

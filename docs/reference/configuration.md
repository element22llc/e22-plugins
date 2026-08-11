# Configuration & rules

The always-on **rules** under `plugins/steer/rules/` are the plugin's operating
manual. They are injected into every managed session by `inject-standards.sh`
([Hooks](hooks.md)) and concatenate in **lexical order** by numeric prefix.

!!! note "Numbering has intentional gaps"
    Prefixes are spaced (e.g. `20` → `22` → `30`) so new rules can slot between
    existing ones. Gaps are headroom — files are never renumbered to make the
    sequence contiguous.

## The ruleset

| Rule | Topic |
| --- | --- |
| `00-router.md` | Operating-manual entry point. |
| `05-roles.md` | Who you are working with. |
| `10-stack.md` | Stack defaults (app / service profile). |
| `12-stack-infra.md` | Stack — infrastructure / IaC (injected when the repo does IaC). |
| `15-commands.md` | Useful commands. |
| `20-layout.md` | Where things live. |
| `22-housekeeping.md` | Keep the repo tidy. |
| `24-worktrees.md` | Parallel worktrees — isolate runtime, clean up after. |
| `26-context-hygiene.md` | Context hygiene — delegate heavy runs, keep state in files. |
| `30-spec-workflow.md` | Spec workflow. |
| `31-decision-capture.md` | Durable decisions land in the spine, not in side-channels. |
| `32-living-docs.md` | Document in parallel, not after. |
| `35-issue-tracker.md` | Issue-tracker integration (client-agnostic). |
| `36-issue-first.md` | Issue-first (GitHub-adopted repos). |
| `40-testing.md` | Testing rules. |
| `41-coverage.md` | Coverage as a signal — cover what you touch; no vanity threshold. |
| `45-commit-autonomy.md` | Commit autonomy (see [Authorization model](../concepts/authorization-model.md)). |
| `50-definition-of-done.md` | Definition of Done. |
| `51-verify-loop.md` | Verify loop — turn a task into a verifiable end state, iterate against the harness until green with a bounded loop, stop-and-report when blocked, never loop on uncheckable/long-compute work. |
| `52-deployment.md` | Deployment & environments — branch-driven promotion, review apps, observability baseline, rollback (see [Deployment & environments](../concepts/deployment.md)). |
| `53-autonomous-loops.md` | Autonomous loops — automate the navigation, never the authority; a loop may discover, triage, draft, push its own branch, and open a **draft** PR, but stops at every human gate (merge, deploy, ADR ratification, secrets). |
| `55-drift-gates.md` | Surface drift before merge. |
| `60-high-risk.md` | High-risk areas. |
| `61-gate-prompts.md` | Answering a human gate in-session — a gate needs the deciding human's answer, not a particular channel, so where that human is present it is collected by an **Approve · Reject · Decide later** prompt and recorded with its ratifier, date, and channel. Covers ADR `Proposed → Accepted`, intent `draft → approved`, and `--reviewed` plan sign-off; merge, deploy, real secrets, `/infra`, and protected-branch pushes are **never** promptable. Full protocol in the `gates` reference. |
| `62-hotfix.md` | Hotfix / incident fast-path — the one sanctioned speed lever for a production incident (`/steer:work --hotfix`); relaxes ceremony, keeps every human authority gate, requires a mandatory post-incident follow-up. |
| `70-secrets.md` | Secrets handling. |
| `75-compliance.md` | Audit-aligned delivery (SOC 2 / ISO 27001). |
| `80-change-size.md` | Change-size model — **authoritative for per-change ceremony**; Issue-first and Definition of Done take their thresholds from it. Tiny (≈<20 lines, no behavior change) needs no issue, spec, ADR, or plan; any behavior change is Small at minimum; a high-risk area is Risky at any line count; an arguable class takes the larger one. |
| `85-practices.md` | Baseline patterns — typed by default, schema-validated boundaries (incl. JSON/YAML config & data files), parameterized data access, server-first, nothing silenced, every import resolves to a declared dependency, ASCII in code and values. |
| `87-output-discipline.md` | Earn every line — tight responses, comments the exception, least code that does the job, lean durable prose. |
| `88-artifacts.md` | Shareable views → Claude Artifacts — a derived, temp-only, on-demand page with a Markdown fallback; styled to the product's `DESIGN.md` tokens (house default otherwise); fillable pages return data only via their exported, machine-keyed document. Full discipline in the `artifacts` reference. |
| `90-design-sources.md` | Design sources & UI. |
| `92-user-facing-copy.md` | Internal ids stay out of end-user surfaces — ADR ids, tracker refs, `Q-NNN` ids, feature slugs and `spec/**` paths never reach app UI copy or `/spec/app/` guide copy and release notes; the `/spec/app/` runbook is dev-facing and keeps its refs. Third-register prose in the `traceability` reference. |
| `95-not-the-gate.md` | You are not the gate — the dev is. |
| `97-self-report.md` | When steer itself misbehaves, file it upstream with `/steer:report`, which auto-files after scrubbing and deduping — no confirmation step. |
| `99-end-of-session.md` | End-of-session checklist. |

!!! note "Conditional injection"
    Some rules carry a first-line `<!-- steer:inject-when=… -->` marker and are
    injected only when their scope applies (see
    [`inject-standards.sh`](hooks.md)). The code-loop rules — `10-stack`,
    `15-commands`, `20-layout`, `22-housekeeping`, `24-worktrees`, `35-issue-tracker`,
    `40-testing`, `41-coverage`, `45-commit-autonomy`, `50-definition-of-done`,
    `51-verify-loop`, `53-autonomous-loops`, `55-drift-gates`, `62-hotfix`,
    `75-compliance`, `80-change-size`, `85-practices`, `90-design-sources`,
    `92-user-facing-copy`, `99-end-of-session` — are marked
    `code-project`, so they are **skipped in knowledge-work mode** (a confidently
    non-code folder, e.g. a Claude Cowork product-owner workspace). `12-stack-infra`,
    `36-issue-first`, and `52-deployment` are likewise scoped — respectively to
    repos that do IaC (`has-iac`), use GitHub as the tracker (`tracker-github`), and
    those that do IaC **or** ship an app (`has-iac|has-apps`, where `has-apps` is
    an `apps/` directory, a `package.json`, or a `pnpm-workspace.yaml` — so
    `52-deployment` injects in any Node repo, not only one that deploys today).
    Polyrepo topology is deliberately **not** an
    always-on rule — the ruleset is capped on its on-disk total, which a scoped
    rule pays in full for every consumer. It is delivered instead by a
    `spec/workspace.yml` / `spec/PRODUCT.md`-gated note inside
    `orient-session.sh` — the hook itself speaks in every managed repo; only the
    topology block is marker-gated. That block is registered on the same
    `startup|resume|clear|compact` matcher as the ruleset, so it survives a
    `/clear`, a resume and auto-compaction. The router, context-hygiene, spec-workflow,
    decision-capture, living-docs, roles, **gate-prompts (`61`)**, high-risk,
    not-the-gate, self-report, secrets, output, and artifacts rules carry no
    `inject-when` marker and so stay always-on.

## Tooling knobs

- **`policy/versions.yml`** — version floors; `check-version-pins.sh` blocks pins
  that violate it.
- **`policy/branch-protection.yml`** — the branch-protection ruleset
  `/steer:protect` verifies the live GitHub settings against, and applies on
  explicit confirmation.
- **`STEER_CLAUDE_CODE_VERSION`** (in `mise.toml`) — the pinned Claude Code
  version CI installs, for reproducible `claude plugin validate`.

Rules are kept lean and imperative on purpose. Long-form prose lives in
`plugins/steer/templates/reference/` and is surfaced through a skill, never
added to `rules/`. That leanness is **enforced, not aspirational**: CI's
`check_context_budget.py` gate holds hard ceilings over three context surfaces.
Two are always-on and ratcheted — the total `rules/*.md` bytes (the SessionStart
injection payload) and the total skill-listing `description` + `when_to_use`
characters — re-armed at each reduction, so always-on weight normally only
shrinks or holds. The default answer to "this rule doesn't fit" is therefore
**trade prose out first**: relocate rationale into
`plugins/steer/templates/reference/`, or deliver a scoped rule through a hook
instead of `rules/` (the polyrepo precedent above).

These two are **policy numbers, not harness limits**, so they *can* be raised —
which is why each raise carries a recorded reason in the gate script rather than
happening quietly. The rules ceiling has been raised five times. First from
62,500 to 65,200, to fund rule `61-gate-prompts`: the ratchet had drifted to 32
bytes of headroom, so the only way to add the rule was compressing unrelated gate
rules, and that trade deleted ~1 KB of rationale prose that existed nowhere else in
the repo. Paying the bytes was judged cheaper than losing the prose. Then from
65,200 to 65,300, because the polyrepo work landed in the same cycle and consumed
that new headroom down to 7 bytes — leaving three factual corrections to always-on
rules (a wrong `/steer:doctor` routing claim, a missing `scripts/` entry in the
root allowlist, a mis-cited rule heading) with nothing to spend. Then from 65,300
to 66,500, to fund the worktree-trust step in rule `24-worktrees`: a worktree
created with `git worktree add` mid-session is the one case no hook can reach — the
`check-worktree-trust` session check covers a session *started* in a worktree — so
the instruction has to be always-on to exist when it is needed. That raise also
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
ceiling is load-bearing again and the choice between reclaiming and re-arming it is
open. For the total on any given tree, run
`uv run python scripts/check_context_budget.py --report` — a figure pinned in
prose goes stale on the next rule edit. Re-arming at measured + 1% would have
restored a ~660-byte margin.

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

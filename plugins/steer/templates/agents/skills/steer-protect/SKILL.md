---
name: steer-protect
description: Make GitHub branch protection reliable — diff policy/branch-protection.yml against live settings and, on confirmation, apply the gaps via gh api (protection, secret scanning, Dependabot alerts). Graduation also writes the CLAUDE.md delivery-mode marker and a /spec/history/ entry; `waive` records that a single-dev repo stays on trunk deliberately, silencing the graduation nudge and push gate. Verify by default.
argument-hint: '[verify | apply | waive]'
---

<!-- Generated from the steer plugin's skills/protect/SKILL.md — do not edit by hand.
     Refresh with /steer:sync from Claude Code in a managed repo, or
     `mise run gen:copilot` in the plugin repo. Authored for Claude Code and
     rendered here in the cross-tool Agent Skills format (agentskills.io) that
     Copilot, Cursor, Gemini CLI and Codex read from .agents/skills/. -->

**When to use.** Use when asked to protect main or a prod branch, check merge rules, graduate solo trunk to PR flow, stop the solo-trunk graduation nag / push prompt, or as init/adopt's last step.

<!-- steer:modes verify,apply,waive -->

# Make GitHub branch protection reliable

steer is **advisory in the local session** — there is no local hard block on
committing or pushing to `main` (rule 95, "You are not the gate — the DEV is";
the issue-first Stop hook explicitly *reports, does not enforce*). The hard wall
is **GitHub branch protection** on the default branch: a required PR, a required
review, a green `ci` check, no admin bypass. That wall is only real if it is
actually configured on the repo — this skill verifies it is, and helps set it up.

**The declared mode is what defines the delivery mode** (Commit autonomy): the
`CLAUDE.md` `<!-- steer:delivery-mode=solo-trunk -->` marker is what makes a repo
**solo-trunk** (autonomous trunk delivery, appropriate pre-MVP); anything else is
**pr-flow** (autonomous branch pushes + PRs; the merge review is the human gate).
Protection is what *enforces* pr-flow, not what declares it — a declared pr-flow
repo whose `main` is unprotected is a **gap to close, not a third mode** (rule
`45-commit-autonomy`), which is why this skill never flips such a repo to
solo-trunk. The marker is also what the hooks read offline (no network), and this
skill owns it — whenever verify or apply observes live protection that
contradicts the declaration, **say so**. Reconciling is `apply`'s job: `verify`
reports the contradiction and names `apply` as the fix, writing nothing itself.
Only one direction makes the *marker* wrong — solo-trunk declared but `main`
already protected, i.e. an unrecorded graduation. The other direction leaves the
marker correct and the wall missing.

**Be honest in every report:** this configures the GitHub-side gate. It does not
change anything about the local session and cannot prevent a local commit or push.

**This is the graduation gate for solo trunk mode.** A repo whose `CLAUDE.md` declares
`Delivery mode: solo trunk (pre-MVP)` runs with `main` intentionally unprotected
(Commit autonomy). Running `apply` here **is** the graduation: it raises the PR wall and
ends trunk mode. After applying in that case, also update the product `CLAUDE.md`
`## Delivery mode` section to `PR flow` — both the prose **and** the machine-readable
marker on its first line, flipped to `<!-- steer:delivery-mode=pr-flow -->` so the
steer hooks resume the per-feature branch/PR flow (the mode is over — the server wall
now enforces it) — and write a graduation entry under `/spec/history/`. **In a
member** the `CLAUDE.md` marker is this repo's own and is flipped here; the
graduation entry goes to the workspace's ledger per rule `32-living-docs`.

**Graduation is not the only answer to the signals.** A repo that will keep a
*single* contributor on trunk — with the `infra/` tree or deploy target the local
signals flag — can instead record a **graduation waiver**: `/steer-protect waive`
writes `<!-- steer:graduation=waived -->` under the delivery-mode marker plus a
`/spec/history/` entry, and the SessionStart nudge and the trunk-push ask fall
silent together (the hooks' shared detector honours the marker). It is a
recorded decision, not a third mode — the repo stays solo-trunk, and a second
collaborator still voids it (verify / `/steer-audit` say so). Procedure:
[`WAIVE.md`](WAIVE.md), read only when the
dev asks for it. `apply` removes the marker at a real graduation.

## Authorization (what invoking this grants)

A "protect main" / "check branch protection" request authorizes, without extra
confirmation: reading `gh auth status`, the repo's live protection settings, and
`.github/workflows/ci.yml`. **Writing repo settings is a privileged change and is
NOT pre-authorized** — the `gh api` PUT/PATCH that applies protection is proposed
and runs only after the dev confirms. Default mode is `verify` (read-only).

**Keep `-X PUT` / `-X PATCH` as the first argument, before the endpoint path.** The
pre-approval is the prefix `Bash(gh api repos/*)`, which matches on the *path* and
cannot express "reads only" — so `gh api repos/O/R/vulnerability-alerts -X PUT`
prefix-matches the read grant and would apply a privileged write with **no** prompt,
while `gh api -X PUT repos/O/R/vulnerability-alerts` does not match and prompts as
this section requires. Flag order is what makes the gate real; never reorder a write
to put the path first. (Same discipline, inverted, as `/steer-report` keeping
`--repo` first to *stay* inside its grant.)

## Preconditions

1. **Read `/spec/tracker.md`.** This skill requires `system: github`. If the
   tracker is something else, say so and stop. In a **member** the tracker is the
   workspace's (rule `35-issue-tracker`); the protection target is still *this* repo.
2. **`gh auth status`** must succeed. If not, tell the dev to run `gh auth login`
   themselves (never run auth on their behalf) and stop.
3. **Resolve `owner/repo`** from `git remote get-url origin` (or `gh repo view`).
   If there is no GitHub remote yet (e.g. repo not pushed), say so and stop —
   protection can only be set once the repo exists on GitHub.

## Resolve desired state

Read the policy, **consumer-first then plugin default** (same precedence as
`policy/versions.yml`):

1. `${repo}/policy/branch-protection.yml` if present, else
2. `https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/policy/branch-protection.yml` (bundled default).

- `branch: default` resolves to the repo's actual default branch
  (`gh repo view --json defaultBranchRef`).
- **Resolve the real required-check context name** from
  `.github/workflows/ci.yml` rather than trusting the literal `ci` string — the
  required status check must match the check-run GitHub actually reports, or merges
  will block forever on a context that never arrives. If the workflow is absent,
  flag that the `ci` gate cannot be required yet and recommend installing it
  (`/steer-sync` / scaffold) first.
- **Additional branches.** If the policy declares a `protected_branches:` list
  (schema 2 — optional; absent in older policies), each entry is a further branch
  to protect with its own fields (the canonical case is a `prod` promotion branch
  whose required PR review is the production approval gate — see the "Deployment &
  environments" rule). Resolve each entry's literal `name` and its CI context the
  same way. Treat the whole set — default branch **plus** every declared branch —
  as the desired state; the steps below apply to each.

## Verify (default mode)

Read live state **for each branch in scope** (the default branch, plus every
declared `protected_branches` entry), tolerating `404` = no protection at all:

```sh
gh api repos/${OWNER}/${REPO}/branches/${BRANCH}/protection
```

For a **declared additional branch** (e.g. `prod`), first confirm the branch
exists — `gh api repos/${OWNER}/${REPO}/branches/${BRANCH}` (`404` = not
created). You cannot protect a branch that doesn't exist, so report a missing
`prod` as **"not created yet"** (informational — create it when adopting the
branch-based prod gate: `git branch prod main && git push -u origin prod`), not as
drift, and move on without failing.

Plus the repo-level settings the policy declares, read from
`gh api repos/${OWNER}/${REPO}`:

- secret scanning + push protection (the `security_and_analysis` block);
- Dependabot security updates (`security_and_analysis.dependabot_security_updates`).

Dependabot **alerts** have no field on the repo object — read their state from
`gh api repos/${OWNER}/${REPO}/vulnerability-alerts` (`204` = enabled, `404` =
disabled). These back the documented Dependabot auto-merge exception (see Notes).

Produce a **per-rule diff table** — for each policy field: `compliant` /
`drifted (actual → desired)` / `absent`. With more than one branch in scope, give
**one table per branch** (default branch first, then each declared branch),
labelled by branch name. If every rule on every present branch is compliant, say
**"branch protection is compliant — nothing to do"** and stop. This is the
idempotent path: re-running on a protected repo writes nothing.

**Check the delivery-mode cache against what you observed** (it may be stale in
either direction). `verify` **writes nothing** — it reports the drift and names
the fix; the marker flip itself is `apply`'s job:

- Marker says **solo-trunk** but `main` **is protected** → the repo already
  graduated (someone applied protection outside this skill). Report that the
  marker is stale and recommend `/steer-protect apply`, which flips it to
  `<!-- steer:delivery-mode=pr-flow -->`, updates the section prose, and appends
  the graduation entry under `/spec/history/`. Do not edit those files from
  `verify`: a mode documented as read-only must stay read-only, and a stale
  marker is a finding to report, not a side effect to apply unasked.
- Marker says **pr-flow** (or is absent) but `main` has **no protection** → the
  wall the mode assumes is missing. Do **not** silently flip to solo-trunk (that
  would grant trunk autonomy nobody chose): report the gap and recommend `apply`.
  If protection is genuinely unavailable — a private repo on a GitHub plan
  without branch protection, or no admin rights — recommend recording the
  exception as an ADR (run `/steer-adr`) so `verify` and `/steer-audit` keep the
  gap visible instead of it looking like an oversight; the local flow is
  unchanged either way (branch + PR, never merge — rule 45).

When the repo's `CLAUDE.md` declares **solo trunk mode**, an absent protection is
**intentional (pre-MVP)**, not drift — report it that way and frame `apply` as
*graduation* (offer it once the MVP works / a deploy or second contributor is near),
not as a compliance gap to fix immediately. In that case also report the
**graduation signals** alongside the protection diff: a second collaborator
(`gh api repos/{owner}/{repo}/collaborators --jq 'length'` > 1), a `prod`/`production`
branch, or a deploy target (deploy workflow / `infra/` tree). When any holds, say
so plainly and recommend graduating now — and note that while the local signals
stand, the trunk-push hook surfaces the session's **first** `git push` for a human
yes (rule 45; repeats carry a non-blocking reminder, and on the Copilot CLI the
repeat is a silent allow), so graduating also restores silent delivery — **or**,
when only local signals hold and the dev intends to stay single-dev on trunk,
name `waive` as the other way to restore it; when none holds, note
that staying on solo-trunk is fine for now. (The SessionStart
`check-graduation.sh` hook surfaces
the local signals each session; this is the networked, on-demand check.) If a
**waiver is recorded** (`<!-- steer:graduation=waived -->`), report it as the
standing decision: the local signals are expected and the hooks are silent by
design. The one thing that voids it is a **second collaborator** — when the
collaborator count is > 1, say the waiver no longer holds and recommend `apply`.

## Apply (only on confirmation)

When rules are drifted or absent, the write procedure — the exact protection
`PUT` (every *policy* value read from `policy/branch-protection.yml`, never from
an example), the repo-level security calls, the post-apply re-verify, and the
`403`/plan-limit failure paths — is in
[`APPLY.md`](APPLY.md). **Read it when the
dev has confirmed, and follow it there.** Nothing is written before that
confirmation.

## Notes

- **Classic branch protection** is used because its fields map 1:1 to the policy.
  Repository **rulesets** are the modern equivalent with the same intent; if the
  repo already governs the branch via a ruleset, report it as compliant rather
  than forcing a second mechanism.
- This skill never opens PRs, never pushes, never runs `gh auth`. On a yes it
  changes repo **settings** via `gh api`, and — when the apply ends solo-trunk
  mode — the two local files that record the graduation: the `CLAUDE.md`
  `## Delivery mode` section (prose + the `steer:delivery-mode` marker the hooks
  read) and `/spec/history/`. Nothing else. `verify` writes nothing at all.
- **Polyrepo: one run protects one repo.** A product spanning several repos needs
  protection on the workspace **and every member**, and this skill only ever
  governs the repo it runs in. So when `spec/workspace.yml` or `spec/PRODUCT.md`
  is present, close the report by naming the repos still unprotected — read the
  member list from the workspace manifest — rather than leaving a single-repo
  verdict to read as product-wide. Do **not** reach into a sibling repo's
  settings from here; say which repo to run it in next.
  **Org-level rulesets** are the way out of N per-repo applications and N drifting
  `policy/branch-protection.yml` copies, but they need **GitHub Team or
  Enterprise**. On Free, the per-repo runs and the per-repo policy copies stand —
  say so plainly instead of recommending a plan the org cannot buy into.
- **Dependabot auto-merge exception.** The policy documents a deliberate carve-out
  to the required human review: Dependabot **patch/minor** PRs (majors excluded)
  are auto-approved and auto-merged once the required `ci` check is green — CI, not
  a human, guarantees the bump is safe. protect's job is only to enable Dependabot
  alerts + security updates (so security PRs get opened). It deliberately does
  **not** enable GitHub's repo-wide `allow_auto_merge` — that switch would expose
  auto-merge to every PR; auto-merge is scoped to Dependabot by the workflow
  itself. The merge is enacted by `.github/workflows/dependabot-auto-merge.yml`
  (installed via the scaffold / `/steer-sync`), which waits for `ci` then merges
  the single Dependabot PR directly — **protect never merges.** If that workflow is
  absent, say so: alerts are on but nothing auto-merges yet.

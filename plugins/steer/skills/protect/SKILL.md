---
name: protect
description: "Make GitHub branch protection — the real gate against direct-push-to-main — reliable on a managed repo: read policy/branch-protection.yml, diff it against the repo's live protection, and on explicit confirmation apply the missing settings via gh api (branch protection, secret scanning, Dependabot alerts). Verify by default; configures the GitHub-side gate only — steer is advisory in the local session (rule 95) and cannot block local pushes."
when_to_use: 'Use when asked to "protect main", protect a `prod` / promotion branch, set up or check branch protection / merge rules on a GitHub-adopted repo, or as the final step of init/adopt to establish the PR gate. Also when /steer:audit flags missing or drifted branch protection.'
argument-hint: "[verify | apply]"
allowed-tools:
  - Bash(gh auth status *)
  - Bash(gh api repos/*)
  - Bash(gh repo view *)
  - Bash(git remote *)
  - Bash(git rev-parse *)
---
<!-- steer:modes verify,apply -->

# Make GitHub branch protection reliable

steer is **advisory in the local session** — there is no local hard block on
committing or pushing to `main` (rule 95, "You are not the gate — the DEV is";
the issue-first Stop hook explicitly *reports, does not enforce*). The hard wall
is **GitHub branch protection** on the default branch: a required PR, a required
review, a green `ci` check, no admin bypass. That wall is only real if it is
actually configured on the repo — this skill verifies it is, and helps set it up.

**Protection is what defines the delivery mode** (Commit autonomy): a protected
`main` is **pr-flow** (autonomous branch pushes + PRs; the merge review is the
human gate), an unprotected `main` is **solo-trunk** (autonomous trunk delivery,
appropriate pre-MVP) — there is no third mode. The `CLAUDE.md`
`<!-- steer:delivery-mode=… -->` marker is the offline **cache** of that
observed state (hooks read it without network); this skill is the owner of that
cache — whenever verify or apply observes live protection that contradicts the
marker, say so and reconcile the marker as part of the run.

**Be honest in every report:** this configures the GitHub-side gate. It does not
change anything about the local session and cannot prevent a local commit or push.

**This is the graduation gate for solo trunk mode.** A repo whose `CLAUDE.md` declares
`Delivery mode: solo trunk (pre-MVP)` runs with `main` intentionally unprotected
(Commit autonomy). Running `apply` here **is** the graduation: it raises the PR wall and
ends trunk mode. After applying in that case, also update the product `CLAUDE.md`
`## Delivery mode` section to `PR flow` — both the prose **and** the machine-readable
marker on its first line, flipped to `<!-- steer:delivery-mode=pr-flow -->` so the
steer hooks resume the per-feature branch/PR flow (the mode is over — the server wall
now enforces it) — and append a graduation entry to `/spec/HISTORY.md`.

## Authorization (what invoking this grants)

A "protect main" / "check branch protection" request authorizes, without extra
confirmation: reading `gh auth status`, the repo's live protection settings, and
`.github/workflows/ci.yml`. **Writing repo settings is a privileged change and is
NOT pre-authorized** — the `gh api` PUT/PATCH that applies protection is proposed
and runs only after the dev confirms. Default mode is `verify` (read-only).

## Preconditions

1. **Read `/spec/tracker.md`.** This skill requires `system: github`. If the
   tracker is something else, say so and stop.
2. **`gh auth status`** must succeed. If not, tell the dev to run `gh auth login`
   themselves (never run auth on their behalf) and stop.
3. **Resolve `owner/repo`** from `git remote get-url origin` (or `gh repo view`).
   If there is no GitHub remote yet (e.g. repo not pushed), say so and stop —
   protection can only be set once the repo exists on GitHub.

## Resolve desired state

Read the policy, **consumer-first then plugin default** (same precedence as
`policy/versions.yml`):

1. `${repo}/policy/branch-protection.yml` if present, else
2. `${CLAUDE_PLUGIN_ROOT}/policy/branch-protection.yml` (bundled default).

- `branch: default` resolves to the repo's actual default branch
  (`gh repo view --json defaultBranchRef`).
- **Resolve the real required-check context name** from
  `.github/workflows/ci.yml` rather than trusting the literal `ci` string — the
  required status check must match the check-run GitHub actually reports, or merges
  will block forever on a context that never arrives. If the workflow is absent,
  flag that the `ci` gate cannot be required yet and recommend installing it
  (`/steer:sync` / scaffold) first.
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

**Reconcile the delivery-mode cache against what you observed** (it may be stale
in either direction):

- Marker says **solo-trunk** but `main` **is protected** → the repo already
  graduated (someone applied protection outside this skill). Flip the marker to
  `<!-- steer:delivery-mode=pr-flow -->`, update the section prose, and append
  the graduation entry to `/spec/HISTORY.md` — the same reconciliation `apply`
  performs.
- Marker says **pr-flow** (or is absent) but `main` has **no protection** → the
  wall the mode assumes is missing. Do **not** silently flip to solo-trunk (that
  would grant trunk autonomy nobody chose): report the gap and recommend `apply`.
  If protection is genuinely unavailable — a private repo on a GitHub plan
  without branch protection, or no admin rights — recommend recording the
  exception as an ADR (run `/steer:adr`) so `verify` and `/steer:audit` keep the
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
stand, the trunk-push hook already surfaces every `git push` for a human yes
(rule 45), so graduating also restores silent delivery; when none holds, note
that staying on solo-trunk is fine for now. (The SessionStart
`check-graduation.sh` hook surfaces
the local signals each session; this is the networked, on-demand check.)

## Apply (only on confirmation)

When rules are drifted or absent:

1. Show the **exact** request you will run — the full classic-protection body that
   closes the gap. Pipe the JSON from `echo` into `--input -` rather than using a
   heredoc: a heredoc's closing delimiter must sit at column 0, but these examples
   are indented inside a list, so a copy-pasted heredoc hangs at the `heredoc>`
   prompt. The piped form below has no terminator and pastes safely at any
   indentation (single-quote the JSON so the shell does not expand `$`):
   ```sh
   echo '{"required_status_checks":{"strict":true,"contexts":["<resolved-ci-context>"]},"enforce_admins":true,"required_pull_request_reviews":{"required_approving_review_count":1,"dismiss_stale_reviews":true},"required_linear_history":true,"restrictions":null}' \
     | gh api -X PUT "repos/${OWNER}/${REPO}/branches/${BRANCH}/protection" --input -
   ```
   When you emit the concrete command for a dev, substitute the resolved
   `OWNER`/`REPO`/`BRANCH` and the real CI context inline — do not leave `${...}`
   placeholders or a heredoc in the command you hand them to run. Run this PUT
   **once per branch in scope** (default branch, then each declared branch that
   exists), substituting that branch's `BRANCH` and resolved fields each time.
2. **Wait for the dev's explicit confirmation.** Do not apply without it.
3. Apply the repo-level settings as **separate** calls — once for the repo, not
   per branch — surfaced and confirmed
   the same way as the protection PUT:
   - secret scanning + push protection **and** Dependabot security updates in one
     `gh api -X PATCH "repos/${OWNER}/${REPO}"` with the `security_and_analysis`
     block;
   - Dependabot **alerts** via `gh api -X PUT
     "repos/${OWNER}/${REPO}/vulnerability-alerts"` (no body; its own endpoint).
4. After applying, re-run the verify diff and report the new state.

**Insufficient permissions (`403`/admin required):** you cannot set protection
without admin on the repo. Do not retry blindly — print the equivalent manual
steps (**Settings → Branches → Add branch ruleset**, or **Settings → Rules**)
mapped to each policy field, and let the dev (or an org admin) apply them.

**Protection unavailable (plan limit):** on some GitHub plans branch protection
cannot be enabled on private repos at all (the API returns `403` with an
upgrade message). The two-state model still applies — the repo runs pr-flow on
the honor system: same branch + PR + never-merge flow (rule 45), just without
the server wall. Recommend recording that exception as an ADR (run
`/steer:adr`) so the gap is a documented decision `verify` and `/steer:audit`
keep visible, not an oversight.

## Notes

- **Classic branch protection** is used because its fields map 1:1 to the policy.
  Repository **rulesets** are the modern equivalent with the same intent; if the
  repo already governs the branch via a ruleset, report it as compliant rather
  than forcing a second mechanism.
- This skill never opens PRs, never pushes, never runs `gh auth`. It touches repo
  *settings* only, and only with a yes.
- **Dependabot auto-merge exception.** The policy documents a deliberate carve-out
  to the required human review: Dependabot **patch/minor** PRs (majors excluded)
  are auto-approved and auto-merged once the required `ci` check is green — CI, not
  a human, guarantees the bump is safe. protect's job is only to enable Dependabot
  alerts + security updates (so security PRs get opened). It deliberately does
  **not** enable GitHub's repo-wide `allow_auto_merge` — that switch would expose
  auto-merge to every PR; auto-merge is scoped to Dependabot by the workflow
  itself. The merge is enacted by `.github/workflows/dependabot-auto-merge.yml`
  (installed via the scaffold / `/steer:sync`), which waits for `ci` then merges
  the single Dependabot PR directly — **protect never merges.** If that workflow is
  absent, say so: alerts are on but nothing auto-merges yet.

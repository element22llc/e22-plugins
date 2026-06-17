---
name: protect
description: "Make GitHub branch protection — the real gate against direct-push-to-main — reliable on a managed repo. Reads the machine-readable policy (policy/branch-protection.yml, consumer-first then plugin default), queries the repo's live protection via gh, reports a per-rule compliant/drifted/absent diff, and on the dev's explicit confirmation applies the missing settings via gh api. Verify by default; never writes repo settings without a yes. Configures the GitHub-side gate only — steer is advisory in the local session (rule 95) and this skill does not and cannot block local pushes."
when_to_use: 'Use when asked to "protect main", set up or check branch protection / merge rules on a GitHub-adopted repo, or as the final step of init/adopt to establish the PR gate. Also when /steer:audit flags missing or drifted branch protection.'
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

**Be honest in every report:** this configures the GitHub-side gate. It does not
change anything about the local session and cannot prevent a local commit or push.

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

## Verify (default mode)

Read live state (tolerate `404` = no protection at all):

```sh
gh api "repos/${OWNER}/${REPO}/branches/${BRANCH}/protection"
```

Plus repo-level security (secret scanning + push protection) via
`gh api "repos/${OWNER}/${REPO}"` (the `security_and_analysis` block).

Produce a **per-rule diff table** — for each policy field: `compliant` /
`drifted (actual → desired)` / `absent`. If every rule is compliant, say
**"branch protection is compliant — nothing to do"** and stop. This is the
idempotent path: re-running on a protected repo writes nothing.

## Apply (only on confirmation)

When rules are drifted or absent:

1. Show the **exact** request you will run — the full classic-protection body that
   closes the gap, e.g.:
   ```sh
   gh api -X PUT "repos/${OWNER}/${REPO}/branches/${BRANCH}/protection" \
     --input - <<'JSON'
   {
     "required_status_checks": { "strict": true, "contexts": ["<resolved-ci-context>"] },
     "enforce_admins": true,
     "required_pull_request_reviews": { "required_approving_review_count": 1, "dismiss_stale_reviews": true },
     "required_linear_history": true,
     "restrictions": null
   }
   JSON
   ```
2. **Wait for the dev's explicit confirmation.** Do not apply without it.
3. Apply secret scanning + push protection as a **separate** call
   (`gh api -X PATCH "repos/${OWNER}/${REPO}"` with the `security_and_analysis`
   block) — surfaced and confirmed the same way.
4. After applying, re-run the verify diff and report the new state.

**Insufficient permissions (`403`/admin required):** you cannot set protection
without admin on the repo. Do not retry blindly — print the equivalent manual
steps (**Settings → Branches → Add branch ruleset**, or **Settings → Rules**)
mapped to each policy field, and let the dev (or an org admin) apply them.

## Notes

- **Classic branch protection** is used because its fields map 1:1 to the policy.
  Repository **rulesets** are the modern equivalent with the same intent; if the
  repo already governs the branch via a ruleset, report it as compliant rather
  than forcing a second mechanism.
- This skill never opens PRs, never pushes, never runs `gh auth`. It touches repo
  *settings* only, and only with a yes.

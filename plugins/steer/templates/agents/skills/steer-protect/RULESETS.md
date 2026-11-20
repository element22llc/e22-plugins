# `/steer-setup protect` - schema 7 rulesets

Read this file when the policy carries `required_reviewers`,
`allowed_merge_methods` or a `release_branches` pattern, and not before. The
guardrails, the authorization boundary and the rest of `Resolve desired state`
and `Verify` stay in `SKILL.md` and still bind; writing the rulesets is
`APPLY.md` step 3.

## Resolve

`required_reviewers` and `allowed_merge_methods`
on a `protected_branches` entry, and the `release_branches` pattern, exist only
in GitHub **repository rulesets** - classic protection has no such rule and
takes no patterns. They resolve to two rulesets protect owns by name:
`steer: prod approvals` (target `refs/heads/prod`: the review count,
`dismiss_stale_reviews_on_push`, `require_last_push_approval`, one
`required_reviewers` entry per team with `minimum_approvals: 1` and
`file_patterns: ["**"]`, the merge methods, `ci`, no bypass actors) and
`steer: release branches` (target `refs/heads/<release_branches.pattern>`: a
PR with its approval count and `ci`, no bypass, and `do_not_enforce_on_create:
true` on the status-check rule). That flag is what lets `/steer-work promote`
create the branch at its changelog cut: GitHub applies the status-check rule to
a new branch's tip, a commit no `ci` run has seen, and refuses the push without
it. What it opens: GitHub applies neither rule to the push that creates a
branch, so a writer can create a `release/**` branch at any commit, reviewed or
not, where before its tip needed a green `ci`. A workflow that runs on a push
to `release/**` runs that commit's own copy, and with the release hold the held
environment deploys it once its Release PR opens - so an environment whose
branch policy admits `release/**` admits any writer. The gate into `prod` is
unchanged - `ci` runs on the Release PR, and the pull-request rule and `ci`
bind every later push to the branch. A `team` slug left `""` is
**not resolved yet**: ask the dev for the PO and the dev team slugs, write them
into the repo's policy copy (as `APPLY.md` step 0 writes `profile:`), then
resolve each to its numeric id (`gh api orgs/<org>/teams/<slug> --jq .id`).
Both teams need **Write** on the repo, or their approvals do not count. Warn
when the dev team has fewer than two members: the Release PR's author and the
last pusher cannot approve, so one dev and one PO can never merge.
A **user-owned** repo has no teams: say required reviewers are unavailable
there and keep the classic review count.

## Verify

For the **schema 7 rulesets**, read `gh api repos/${OWNER}/${REPO}/rulesets`, find
each one by its `steer:` name, then `gh api repos/${OWNER}/${REPO}/rulesets/<id>`
for its rules, and diff them field by field like the classic protection. A
missing ruleset is `absent`; an edited one is `drifted`. So is a release
ruleset without `do_not_enforce_on_create`: say that `/steer-work promote`
cannot cut a release until it is applied.

## Classic protection and rulesets together

**Classic branch protection** carries every field it can express, because those
map 1:1 to the policy; the schema 7 ruleset fields go to the two `steer:`
rulesets, and GitHub applies the most restrictive of both layers. If the repo
already governs a branch through a ruleset of its own that meets the policy,
report it as compliant rather than forcing a second one.

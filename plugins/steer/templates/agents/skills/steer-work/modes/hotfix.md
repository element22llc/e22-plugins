# `/steer-work --hotfix` - the production-incident fast path

Read this file only when `--hotfix` was passed. The preconditions,
authorization scope, delivery mode, subcommands, and guardrails stay in
`SKILL.md` and apply unchanged.

`--hotfix` is the **production-incident fast-path** (rule `61-gates` -> Hotfix). It relaxes
*ceremony and ordering*, never the human authority gates. Use it **only** when the
objective entry condition holds: the change targets an already-**deployed
production** system with real users or data **and** there is an active incident,
outage, or regression. "Urgent" feature work and pre-MVP repos are **not** hotfixes -
drop the flag and use the normal flow. A hotfix presupposes a deployed product, so it
implies **pr-flow** (a solo-trunk pre-MVP repo has nothing to hot-fix).

## Check the entry condition before anything else

The ask supplies the *incident* half. The *deployed* half comes from the repo,
never from the urgency of the ask - "production is down" says something is
wrong, not that this repo ships to a production with real users. Then exactly
one of:

- **Evidence against** - the `CLAUDE.md` delivery mode is `solo-trunk`, or
  `policy/delivery.yml` says `environments: []` or `production_gate: none` ->
  **decline the lane**: name the line, and continue the fix on the normal flow
  (`issue/<n>-slug`, issue first).
- **Evidence for** - a feature intent at `Status: live` (`ENUMS.md`) -> open the
  lane and name the feature that showed it.
- **Neither** -> the condition is **unverified**. A `delivery.yml` that lists
  `prod` is not evidence: the scaffold seeds it before anything ships. Ask one
  question - which deployed environment is down, and since when - and stay on
  the normal flow until the dev's answer names one. "Can't confirm" is this
  branch, not a caveat on the lane: the plan and the handoff use
  `issue/<n>-slug` and normal review, never `hotfix/` or the expedited lane.

The ask's own wording is never the confirmation; that is the self-assessment
rule `61-gates` rules out.

What changes versus the normal flow:

- **Branch.** Work on a `hotfix/<n>-slug` branch (not `issue/<n>`): the
  issue-first Stop hook recognises the `hotfix/` prefix as the after-the-fact
  lane, so no work marker is needed up front. `<n>` is the issue number once it
  exists; until then use a short slug, and record the number and the marker
  when the issue is filed in the follow-up.
- **Cut it from what production runs.** When `policy/delivery.yml` says
  `production_gate: prod-branch-pr` (absent means that) and a `prod` branch
  exists, branch from it and target it - a hotfix cut from the default branch
  would carry every unreleased commit into production:

  ```sh
  git fetch origin prod && git switch -c hotfix/<n>-slug origin/prod
  gh pr create --base prod ...
  ```

  Any other gate deploys from the default branch: branch and target it as
  `start` does, and say in the PR that unreleased work on it ships too.
- **The PR carries its own patch release.** Add the fragment (kind `Fixed` or
  `Security`), then cut it on the branch so merging ships a version:
  `changie batch patch && changie merge`. Under `prod-branch-pr` the merge of
  this PR is the production gate, so the cut cannot wait for `promote`.
- **Issue after-the-fact.** Don't block the fix on find-or-create. File or backfill
  the issue as soon as practical and reference it from the PR/commit - the hook
  won't nag a `hotfix/` branch, but the issue is still required by the follow-up.
- **Expedited review, same approvers.** The PR goes to the front of the review
  queue, but its base decides who approves - into `prod`, a PO team member
  **and** a dev team member (the `prod` ruleset, `/steer-setup protect`). It
  relaxes the high-risk scoping ceremony of rules 60 and 80, never who approves
  or the PR/merge human gate. No self-merge.
- **Cause before fix, faster.** [`debug.md`](debug.md) still governs the fix:
  the incident gets a stated causal chain, never a guess shipped under pressure.
- **Local gates, no draft.** Run the local gates before the push as `finish`
  does - a red CI round-trip is slower than a local run - and its code gate,
  whatever the diff's size: an incident fix is High-risk, and an expedited
  human review is exactly when an independent pass matters. Open the PR ready
  for review whatever the gate left open - `finish` opens a draft unless it
  came back clean - and watch its CI to conclusion yourself.
- **Deploy on the fix.** Deploying the fix is *policy-permitted* under `45-delivery` ->
  "Deployment & environments" (validate in non-prod where feasible - rule
  `60-high-risk`) - but, exactly as everywhere else, deploy is **never
  auto-executed**: pushing the `hotfix/` branch and opening the PR are
  autonomous (Commit autonomy), while `gh pr merge` and any deploy stay
  human-gated (this skill does not pre-approve them).
- **Mandatory follow-up.** Once the fire is out, restore traceability.
  First, when the fix went into `prod`, **merge prod back** the moment that PR
  merges - into `main`, and into the open `release/*` branch when a release is
  in QA - or the next release ships without it (`ci:promotion` fails that
  Release PR until it lands, once its checks re-run). `.github/workflows/merge-back.yml`
  pushes a `merge-back/<pr>-to-<target>` branch at prod's tip and comments a
  link per target; a dev opens each PR and merges it with **Create a merge
  commit**, never squash. By hand (no workflow), per target:

  ```sh
  git fetch origin prod && git push origin origin/prod:refs/heads/merge-back/<pr>-to-<target>
  gh pr create --base <target> --head merge-back/<pr>-to-<target> --title "merge-back: #<pr> into <target>" ...
  ```

  Never a PR with `prod` as its head: a conflict is resolved on the merge-back
  branch by merging the target into it (`git merge origin/<target>`, with
  `changie merge` for a `CHANGELOG.md` conflict), never with a commit of its own.
  `ci:changelog` passes the PR without a new fragment: everything it brings is
  already on `prod`. A hotfix that **reverts** a change reaches `main` too; the
  bot's comment flags it so a human decides whether `main` keeps it.
  Then backfill/finish the issue, write the spec/ADR if a durable decision was made,
  put the incident's root cause on the enforcement ladder (`finish` in
  `modes/subcommands.md` - an incident is the strongest trigger, and a regression
  test is the expected rung), and write a `/spec/history/` entry (in a polyrepo member, to the **workspace's**
  ledger via `workspace.path`, else the PR description - never a local copy).
  Definition of Done is **deferred, not waived**
  (rule 50) - track the follow-up to closure rather than declaring the hotfix done.

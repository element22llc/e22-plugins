# `/steer-work --hotfix` — the production-incident fast path

Read this file only when `--hotfix` was passed. The preconditions,
authorization scope, delivery mode, subcommands, and guardrails stay in
`SKILL.md` and apply unchanged.

`--hotfix` is the **production-incident fast-path** (rule `62-hotfix`). It relaxes
*ceremony and ordering*, never the human authority gates. Use it **only** when the
objective entry condition holds: the change targets an already-**deployed
production** system with real users or data **and** there is an active incident,
outage, or regression. "Urgent" feature work and pre-MVP repos are **not** hotfixes —
drop the flag and use the normal flow. A hotfix presupposes a deployed product, so it
implies **pr-flow** (a solo-trunk pre-MVP repo has nothing to hot-fix).

What changes versus the normal flow:

- **Branch.** Work on a `hotfix/<n>-slug` branch (not `issue/<n>`) so the
  issue-first Stop hook recognises the sanctioned after-the-fact lane. `<n>` is the
  issue number once it exists; until then use a short slug and record it when the
  issue is filed. The reconciliation hook recognises the `hotfix/` prefix directly
  as the after-the-fact lane, so a work marker is not required up front; record it
  when the issue is filed in the follow-up.
- **Issue after-the-fact.** Don't block the fix on find-or-create. File or backfill
  the issue as soon as practical and reference it from the PR/commit — the hook
  won't nag a `hotfix/` branch, but the issue is still required by the follow-up.
- **Single-reviewer, expedited.** One reviewer approval is sufficient (it relaxes
  the change-size / high-risk scoping ceremony of rules 60 and 80) — it does **not**
  remove the PR/merge human gate. No self-merge.
- **Deploy on the fix.** Deploying the fix is *policy-permitted* under rule 62 +
  Deployment (validate in non-prod where feasible) — but, exactly as everywhere
  else, deploy is **never auto-executed**: pushing the `hotfix/` branch and opening
  the PR are autonomous (Commit autonomy), while `gh pr merge` and any deploy
  stay human-gated (this skill does not pre-approve them).
- **Mandatory follow-up (not optional).** Once the fire is out, restore traceability:
  backfill/finish the issue, write the spec/ADR if a durable decision was made, and
  write a `/spec/history/` entry (in a polyrepo member, to the **workspace's**
  ledger via `workspace.path`, else the PR description — never a local copy).
  Definition of Done is **deferred, not waived**
  (rule 50) — track the follow-up to closure rather than declaring the hotfix done.

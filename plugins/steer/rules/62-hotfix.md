<!-- steer:inject-when=code-project -->
## Hotfix / incident fast-path

A production incident is **high-risk and time-critical at once** — the one case
where full ceremony and speed genuinely conflict. The hotfix lane is the **only
sanctioned speed lever**. Run it via `/steer:work --hotfix`.

**Objective entry condition (not self-asserted).** The lane opens only when the
change targets an already-**deployed production** system with real users or data
(the rule 60 predicate) **and** there is an active incident, outage, or
regression. "Urgent" feature work, a looming demo, or a pre-MVP repo with nothing
deployed are **not** hotfixes — they take the normal lane.

**What the lane relaxes — ceremony and ordering, never authority:**

- **Issue after-the-fact.** File or backfill the GitHub issue as soon as
  practical instead of before the first edit; work on a `hotfix/<n>-slug` branch
  so issue-first reconciliation recognises the sanctioned lane. This relaxes
  issue-first *timing* (rule 36), not its existence.
- **Expedited single-reviewer.** One reviewer approval suffices, in place of the
  change-size / high-risk scoping ceremony (rules 60, 80). The PR / merge **human
  gate still stands** — no self-merge.
- **Deploy on the fix.** Deploying the fix is *policy-permitted* (rule 52 —
  validate in non-prod where feasible). Pushing the `hotfix/` branch and opening
  the PR are autonomous delivery steps (Commit autonomy); as everywhere, deploy
  is **never auto-executed** — merge and deploy stay human-gated.

**Mandatory follow-up once the fire is out (not optional).** Restore traceability:
backfill/finish the issue, write the spec or ADR if a durable decision was made,
and append a `/spec/HISTORY.md` entry. Definition of Done is **deferred under this
lane, never waived** (rule 50). A hotfix without its follow-up is unfinished work,
not a shortcut earned.

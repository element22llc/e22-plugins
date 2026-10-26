# `/steer-issues reconcile` - issue <-> spec consistency

Read this file when running `reconcile`. The guardrails, coupling rules, the
question-reconciliation floor, and the `## Recommended next actions` contract
stay in `SKILL.md` - they apply to every mode and are not repeated here.

## `reconcile #N | feature-id | --all`

Verify issue <-> spec pointers agree and the lifecycle is internally consistent;
update only the managed block of any issue it touches; **never auto-resolve
behavioural drift or a product decision** - route those to a human.

Two scopes:

### bounded (`#N` / `feature-id`)

One issue or feature. Enforce the question-reconciliation floor in `SKILL.md`.

### repo-wide (`--all`)

Sweep the spine + tracker and report every disagreement:

- referenced issues that no longer exist;
- a `live` intent whose feature issue is not terminal - released, never closed;
- approved specs missing a tracker ref (`require_tracker_ref_for_features`);
- open `spec-drift` issues that no longer reproduce;
- sub-issues with no parent link;
- **epic<->feature inconsistency** (a closed epic with open child features or vice
  versa, or a `validate`/`done` epic with no linked features);
- promoted questions whose issue is closed but whose `Q-NNN` is still `open`,
  and the inverse: a `resolved` `Q-NNN` whose issue is still open (propose
  close `completed` -> `done`) - unless that issue is the `> Tracker:` of a
  `Proposed` ADR, which keeps it open until `adr accept` closes it;
- **ADR-linked**, **contract-less**, **delivered-but-open** and **idle** issues
  (each below);
- and, in a polyrepo, **the member trackers** (below).

**Delivery state is never reconciled - there is nothing to reconcile.** A feature's
progress lives only in its issue `steer:state`; the spec's `Status:` holds product
state (`draft`/`approved`/`live`) and does not mirror it, so a merged PR, a close,
or a reopen cannot leave a stale `Status`. Do not compare `Status:` against
`in-progress`/`validate`/`done` and do not "fix" a spec that reads `approved` while
its issue reads `done` - that pairing is correct (see the crosswalk in
`ISSUE-WORKFLOW.md`). The only spec-side state worth checking is the pair above:
`live` without a terminal issue, and an `approved` feature with no tracker ref.

**ADR-linked issues - a decision that moved while its issues did not.** For
every ADR under `spec/decisions/` on the default branch, read its status and
`> Tracker:` ref, and `find` the open issues citing it by text (its file stem,
`ADR NNNN`, `ADR-NNNN`). An ADR written before `> Tracker:` existed relies on
the text search alone.

| ADR status | Open issue | Proposal |
|---|---|---|
| `Accepted` | its `> Tracker:` issue | close `completed` -> `done`, comment linking the ADR |
| `Superseded by` | its `> Tracker:` issue, or one citing it | close `superseded` -> `cancelled`, comment pointing at the replacement - or keep, with that comment, when it is still valid work |
| `Deprecated` | its `> Tracker:` issue, or one citing it | close `obsolete` -> `cancelled` - or keep, with a comment |
| `Proposed` | - | none: the decision is still open |

An issue citing an `Accepted` ADR is implementation work under it, not stale.
Text matches are candidates: show the matched line, and propose a close only
when the issue is about the decision itself.

**Contract-less issues - the after-the-fact recovery path for a raw create that
bypassed `/steer-tracker-sync`** (the point-of-action issue-create contract
nudge in `check-bash-actions.sh` is best-effort, not a gate). Flag any open
issue missing the machine-readable contract: **no `steer:` markers AND no
`steer:managed` block** (so neither `steer:kind` nor `steer:source` is set, the
issue carries no `source:*` label, and its Type is the unset default). Such an
issue is invisible to marker-based dedup (`triage`/`board`) and to every
lifecycle check above, so surface it here with the retrofit action - infer kind
+ labels + Type via `/steer-issues triage` and apply the contract through
`/steer-tracker-sync` (markers + derived `source:*` label + Issue Type).

**Never invent intent:** retrofit only the machine-readable contract onto the
existing human body; do not rewrite or guess the issue's content, and leave a
genuinely human-authored issue (one a human typed directly) for `triage` to
label rather than treating it as drift.

**Delivered-but-open - a merged PR that never closed its issue.** The common
cause is a PR with no closing keyword, or, in a polyrepo, a member PR whose bare
`Closes #N` named the member's own `#N`. Read `/steer-tracker-sync
delivery-evidence` for every open non-epic issue (epics are the rollup check
above) and name the evidence tier on each row:

| Tier | Evidence | Proposal |
|---|---|---|
| strong | a merged PR named by the issue's `steer:pull-request`/`steer:branch` marker or in its closing references | close `completed` -> `done` |
| medium | a merged PR that only cross-references the issue | close `completed`, flagged: a `Refs` may be partial delivery |
| weak | polyrepo only: a merged member PR found by the `issue/<N>-` branch name alone | candidate - show it, propose nothing |

`validate -> done` is propose-only (features: the PO), so these closes wait for
the confirmation below like every other write.

**Idle - no update in `workflow.stale_issue_days`** (`/spec/tracker.md`; 90 when
the key is absent) and no delivery evidence. Route by `steer:state`:
`inbox`/`exploring`/`ready-for-spec`/`ready-for-dev` -> propose closing as
`not-planned` -> `cancelled`; `in-progress`/`validate`/`blocked` -> no close,
surface it to its assignee or claimant as a stale claim. Never propose closing a
`spec-question` or `spec-drift` issue for idleness - closing one is a spec
decision. An idle issue the decider keeps gets a one-line `comment` saying so,
which also resets its clock, so the next sweep does not re-propose it.

**Polyrepo - the member trackers.** In a workspace (or a member, resolved to it
by step 3), also read the open issues of every member in `spec/workspace.yml`,
by its `repository:`. Run the delivered-but-open and idle checks on every one of
them, against that member's own PRs - where a bare `Closes #N` does land, so an
issue Copilot or a human filed in the member is caught there. A member issue
carrying `steer:` markers that is still open after those checks is a **stray** -
product work filed outside the workspace tracker: propose moving it to the
workspace; the move is done by hand (`gh issue transfer`), never by this sweep.
A member issue with no `steer:` markers stays where it is. Name the members
covered and any **uncovered** one (`/steer-reference polyrepo` -> "Reporting
across members").

Output is a reconciliation report + proposed actions, confirmed once before any
write. **Read every page of every list** - a report built from a first page is a
partial sweep and must say so. **Group the proposals by decider** (authority
table in `ISSUE-WORKFLOW.md`), so whoever confirms sees which rows are not
theirs; the one confirmation may approve all, some or none of them, and every
approved write goes through `/steer-tracker-sync` (`close` with its resolution
mode, `comment`). `--all` is read-heavy - route all fetches through
`/steer-tracker-sync` and say so.

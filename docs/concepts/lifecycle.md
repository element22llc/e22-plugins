# The work lifecycle

When the tracker is GitHub Issues, work moves through a defined set of states.
The canonical set lives in `plugins/steer/templates/reference/enums.registry`
(`issue_state`) and is enforced by the fixture checks:

```text
inbox · exploring · ready-for-spec · ready-for-dev · in-progress · validate · blocked · done · cancelled
```

```mermaid
stateDiagram-v2
    [*] --> inbox
    inbox --> exploring
    exploring --> ready_for_spec: ready-for-spec
    ready_for_spec --> ready_for_dev: ready-for-dev
    ready_for_dev --> in_progress: in-progress
    in_progress --> validate
    validate --> done
    in_progress --> blocked
    blocked --> in_progress
    exploring --> cancelled
    in_progress --> cancelled
    done --> [*]
    cancelled --> [*]
```

## Which skill drives each phase

| Phase | Skill |
| --- | --- |
| Capture / triage / decompose | [`/steer:issues`](../workflows/issues.md) |
| Shape & approve the spec | [`/steer:spec`](../workflows/spec.md) |
| Implement & finish | [`/steer:work`](../workflows/work.md) |
| Implement, review-gated | [`/steer:work --reviewed`](../workflows/work.md) (plan → independent plan-gate review → implement → independent `/code-review` → bounded fix loop) |
| Respond to a production incident | [`/steer:work --hotfix`](../workflows/work.md) (fast-path: issue after-the-fact on a `hotfix/<n>` branch, single-reviewer, human gates intact; mandatory post-incident follow-up) |
| Read/write the tracker | `/steer:tracker-sync` (gateway, called by the above) |
| "What should I do next?" | `/steer:next` |

## Issue-first

In a GitHub-adopted repo, the **first mutation** of a unit of work presupposes an
active issue (the *issue-first* rule). `/steer:work` will find-or-create the issue
before the first change. Commit autonomy is unchanged once that issue exists — see
the [Authorization model](authorization-model.md).

**Solo-trunk mode keeps the issue, drops the PR.** In
[solo-trunk mode](authorization-model.md) — a pre-MVP greenfield repo whose
`CLAUDE.md` `## Delivery mode` section carries the machine-readable marker
`<!-- steer:delivery-mode=solo-trunk -->`, committing straight to `main` with no
per-feature branch or PR — issue-first **still holds**: the issue remains the
audit-evidence anchor, so the change keeps an issue and closes it from the trunk
commit (a `Closes #N` trailer). Only the branch/PR ceremony relaxes: the
issue-first hooks read the marker and reword their advice (reference the issue in
the commit, *not* "open a PR" or "create an `issue/<N>` branch"). `/steer:protect`
flips the marker to `pr-flow` at graduation, after which the per-feature PR flow
resumes. Calling work a "prototype" does not waive issue-first — declaring
solo-trunk mode is the only durable opt-out, and it drops the PR, not the issue.

Plugin-maintenance flows are exempt, just as editing the `/spec` spine is:
`/steer:sync` reconciles the materialized spine and scaffold against the plugin's
own templates on its own `feat/sync` branch — structural, not feature work — so the
issue-first hooks stay silent there (unless app source changes, which sync's
contract forbids).

`done` and `cancelled` are terminal. Both must always be present in the state set;
the fixture suite asserts this so the lifecycle can't silently lose a terminal
state.

## One lifecycle store, and what the spec adds

Progress is tracked in **one** place: the issue `steer:state` marker (`inbox →
exploring → ready-for-spec → ready-for-dev → in-progress → validate → done`). For
features, a spec intent's `> Status:` line (`draft → approved → live`) adds the two
facts that marker cannot express — **the owner approved this scope**, and **users
can see it** (`done` is an accepted close, not a release). Nothing else is copied
into the spec, so there is no derived value to keep in step.

The plugin still publishes a single authoritative **Status↔state crosswalk** — the
table lives in the bundled `ISSUE-WORKFLOW.md` reference — but it now reads as a
statement of *independence*: `ready-for-dev ⇒ approved`, a released `done ⇒ live`,
and every delivery state (`in-progress`, `validate`, `done`) leaves `Status:`
**unchanged**. A `check_standards.py` guard fails the build if a state or status
token is ever added without a matching crosswalk row.

Because `Status:` moves only at `/steer:spec approve` and the release, a merge,
close, or reopen cannot leave it stale — the drift class disappears rather than
being caught. A feature reading `approved` while its issue reads `done` is the
**intended** pairing. The two mismatches that remain are real and human-resolved: an
`approved` feature with no tracker ref, and a `live` intent whose issue never
reached a terminal state.

This replaces an earlier model in which the spec also carried `implemented` and
`validated`, mirroring the issue's `validate`/`done`. Those were a derived value
stored in a second file and maintained by hand, so every merge had to be replayed
into the spec — and `reconcile` existed largely to repair what that missed. They
were retired; delivery progress is now read from the issue.

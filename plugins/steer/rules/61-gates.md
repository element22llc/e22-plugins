## Answering a human gate in-session

A gate needs the deciding **human's** answer, not a particular channel: when
that human is in the session, **ask, then act in one pass**, and never ratify on
your own initiative. The promptable gates: ADR `Proposed -> Accepted` (its
`Deciders`; `/steer:spec adr accept <n>`), intent `draft -> approved` (the PO;
`/steer:spec approve <id>`), and the `--reviewed` plan sign-off (who asked;
implement).

Ask once, three options - **Approve / Reject / Decide later** - showing the
tradeoff (rejected alternatives, negative consequences, locked scope), never
just a title, and never pre-selected. Only an unambiguous answer *to the
decision presented* ratifies it; ambient agreement ("ok", "thanks", silence, or
sign-off on an earlier plan) does not, and two decisions never share a prompt.
`Decide later` leaves every field untouched. Record who decided, when, and that
it was in-session, plus the `/spec/history/` entry. Preconditions fire first; a
wrong decider means surfacing the mismatch and leaving the state alone.

- **Never promptable, in any mode:** merge, deploy, real secrets, `/infra`,
  protected-branch pushes. These need a human acting in the real system - asking
  does not authorize them, and this rule never relaxes them.

Full protocol: `/steer:reference gates`.

### Hotfix / incident fast-path

A production incident is the only sanctioned speed lever: run it via
**`/steer:work --hotfix`**, which carries the procedure. The lane opens on an
objective condition, never a self-assessment: an already-**deployed
production** system with real users or data, **and** an active incident, outage
or regression. Urgent feature work, a looming demo and a pre-MVP repo are not
hotfixes. It relaxes **ceremony and ordering, never authority**: the issue is
backfilled on `hotfix/<n>-slug`, merge and deploy stay human-gated, and the
follow-up (issue, spec or ADR for a durable decision, `/spec/history/` entry) is
**mandatory**. Definition of Done is deferred here, never waived.

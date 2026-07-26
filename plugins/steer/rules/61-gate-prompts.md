## Answering a human gate in-session

A gate needs the deciding **human's** answer, not a particular channel. When they
are in the session, ask and act in the same pass instead of leaving a `Proposed` /
`draft` to hand-edit later. Never ratify on your own initiative.

Ask once — **Approve · Reject · Decide later** — showing the tradeoff (rejected
alternatives, negative consequences, locked scope), not just a title. Never
pre-select, never read "ok" / silence / an earlier sign-off as approval.
`Decide later` changes nothing. Record who decided, when, and that it was
in-session — unrecorded self-ratification is the audit hole.

Applies to: ADR `Proposed → Accepted` (`/steer:adr accept`), intent
`draft → approved` (`/steer:spec approve`), `--reviewed` plan sign-off.
**Never promptable:** merge, deploy, real secrets, `/infra`, protected-branch
pushes — asking does not authorize them.

Protocol: `/steer:reference gates`.

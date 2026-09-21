## Answering a human gate in-session

A gate needs the deciding **human's** answer - not a particular channel. When that
human is in the session, don't send them out-of-band to edit a status field:
**ask, then act in the same pass.** Never ratify on your own initiative.

| Gate | Decides | On Approve |
|---|---|---|
| ADR `Proposed -> Accepted` | its `Deciders` | `/steer:adr accept <n>` |
| Intent `draft -> approved` | the PO | `/steer:spec approve <id>` |
| `--reviewed` plan sign-off | who asked | implement |

Ask once, three options - **Approve · Reject · Decide later**:

- **Show the tradeoff** - rejected alternatives, negative consequences, locked
  scope - never just a title.
- **Never pre-select, never infer.** An unambiguous answer *to the decision
  presented* ratifies it; ambient agreement ("ok", "thanks", silence, or sign-off
  on an earlier plan) does not. Never bundle two decisions into one prompt.
- **`Decide later` is always offered** and leaves every field untouched.
- **Record who decided, when, and that it was in-session**, plus the
  `/spec/history/` entry. Self-ratification is legitimate; the *unrecorded* kind
  is the audit hole this rule prevents.
- **Preconditions fire first**, and a **wrong decider** means surfacing the
  mismatch and leaving the state alone - never show a gate the human cannot
  legitimately pass.
- **Never promptable, in any mode:** merge, deploy, real secrets, `/infra`,
  protected-branch pushes. These need a human acting in the real system - asking
  does not authorize them, and this rule never relaxes them.

Full protocol: `/steer:reference gates`.

### Hotfix / incident fast-path

A production incident is high-risk and time-critical at once - the only case
where ceremony and speed genuinely conflict, and the only sanctioned speed
lever. Run it via **`/steer:work --hotfix`**, which carries the procedure. The
lane opens on an objective condition, never a self-assessment: an
already-**deployed production** system with real users or data, **and** an
active incident, outage or regression. Urgent feature work, a looming demo and a
pre-MVP repo are not hotfixes.

It relaxes **ceremony and ordering, never authority**: the issue is backfilled
rather than filed first (work on `hotfix/<n>-slug`), one reviewer suffices, and
deploying the fix is policy-permitted - merge and deploy stay human-gated. Once
the fire is out the follow-up is **mandatory**: backfill the issue, write the
spec or ADR if a durable decision was made, and write the `/spec/history/`
entry. Definition of Done is deferred here, never waived.

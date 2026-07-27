## Answering a human gate in-session

A gate needs the deciding **human's** answer — not a particular channel. When that
human is in the session, don't send them out-of-band to edit a status field:
**ask, then act in the same pass.** Never ratify on your own initiative.

| Gate | Decides | On Approve |
|---|---|---|
| ADR `Proposed → Accepted` | its `Deciders` | `/steer:adr accept <n>` |
| Intent `draft → approved` | the PO | `/steer:spec approve <id>` |
| `--reviewed` plan sign-off | who asked | implement |

Ask once, three options — **Approve · Reject · Decide later**:

- **Show the tradeoff** — rejected alternatives, negative consequences, locked
  scope — never just a title; a human cannot decide what they cannot see.
- **Never pre-select, never infer.** An unambiguous answer *to the decision
  presented* ratifies it; ambient agreement ("ok", "thanks", silence, or sign-off
  on an earlier plan) does not. Never bundle two decisions into one prompt.
- **`Decide later` is always offered** and leaves every field untouched — the
  artifact stays `Proposed` / `draft` exactly as before.
- **Record who decided, when, and that it was in-session**, plus the
  `/spec/HISTORY.md` entry. Self-ratification is legitimate; the *unrecorded*
  kind is the audit hole this rule prevents.
- **Preconditions fire first** — never show a gate the human cannot legitimately
  pass (an unresolved blocking question → `/steer:questions`).
- **Wrong decider?** Surface the mismatch and leave the state alone; you may not
  record someone else's decision for them.
- **Never promptable, in any mode:** merge, deploy, real secrets, `/infra`,
  protected-branch pushes. These need a human acting in the real system — asking
  does not authorize them, and this rule never relaxes them.

Full protocol: `/steer:reference gates`.

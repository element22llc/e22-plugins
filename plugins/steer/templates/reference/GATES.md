# Human gates — answering one in-session

Full-detail companion to rule `61-gate-prompts`. It covers what a human authority
gate *is*, which gates are answerable by a prompt in the session, the exact shape
of that prompt, how ratification is recorded, and the gates that no prompt can
ever satisfy.

---

## 1. What a gate is — and what the prompt does not change

A **human authority gate** is a point where progress depends on a decision that
is not the agent's to make: a product decision, an architectural commitment, a
risk acceptance, a release. The agent routes it; it never guesses it
(`NEXT-ACTIONS.md` → *Human decision required*).

The gate's requirement is that **the deciding human decides**. It has never been
a requirement about *channel* — a decision typed into a status field and the same
decision stated in the session carry identical authority when they come from the
same person. What the in-session prompt removes is a **round trip**, not the
decision:

| | Before | After |
|---|---|---|
| Who decides | the named human | **unchanged** |
| How it's expressed | hand-edit `> Status:` out-of-band, later | answer a prompt, now |
| What's recorded | the flipped field | the flipped field **+ who / when / channel** |
| If unanswered | artifact stays `Proposed` / `draft` | **unchanged** |

The change is strictly additive: `Decide later` reproduces today's behaviour
exactly, so no repo can end up more stuck than it was.

**Self-ratification is legitimate.** In a solo repo the author, decider, and
reviewer are the same person; requiring them to leave the session to ratify their
own decision buys no independent judgement — it only loses context and time. What
must not happen is self-ratification that leaves **no trace of having been a
decision** (§4).

---

## 2. The three promptable gates

| Gate | Transition | Decides | Skill that writes it |
|---|---|---|---|
| **ADR ratification** | `Proposed → Accepted` | the ADR's `Deciders` | `/steer:adr accept <n>` |
| **Intent approval** | `draft → approved` | the PO | `/steer:spec approve <id>` |
| **Plan sign-off** | vetted plan → implementation | whoever asked for the work | `/steer:work --reviewed` |

Each keeps its existing owner and preconditions. The prompt is an **additional
channel** for the answer, not a new transition and not a second writer:

- `/steer:spec approve` remains the **single writer** of `draft → approved`. A
  prompt answered `Approve` delegates there; it never inlines the field edits.
- `/steer:adr accept` is the only writer of `Proposed → Accepted`, and refuses on
  `Superseded` / `Deprecated`.
- Every precondition still fires **before** the prompt is offered. Notably the
  intent **blocking-question gate** (`impact: blocking` +
  `required_before: intent-approval` + unresolved): if it fails, the prompt is
  not shown at all — route to `/steer:questions` instead. Never present a gate a
  human cannot legitimately pass.

---

## 3. Prompt shape

One question, **three options**, in this order:

```text
Approve   — record the decision and continue in this pass
Reject    — record that it was declined, and why
Decide later — leave everything untouched (today's behaviour)
```

**The prompt must carry the tradeoff.** A human cannot decide what they cannot
see, and a prompt that shows only a title manufactures consent rather than
collecting it. Minimum content per gate:

| Gate | The prompt shows |
|---|---|
| ADR | the **Decision**, the **rejected alternatives with their reasons**, and the **negative** consequences |
| Intent | the acceptance criteria, the locked scope (in **and** out), and any non-blocking open questions that survive approval |
| Plan | what changes and where, the high-severity reviewer findings and how they were resolved, and the residual risk |

Rules that keep it a decision:

- **Never pre-select** an option, and never present `Approve` as the expected
  answer.
- **Never infer approval.** An unambiguous answer *to the decision presented*
  ratifies it. Ambient agreement does not — "ok", "thanks", "sounds good",
  silence, a reaction, or approval of an earlier plan are **not** ratification.
  When a reply is plausibly either, ask once more, narrowly.
- **Never re-ask a gate already answered.** Ratification is idempotent: an ADR
  already `Accepted` reports its existing stamp and appends no duplicate history.
- **Never bundle.** Two ADRs, or an ADR plus an intent, are two prompts — a
  single "approve all" collapses distinct decisions into one answer.
- **`Reject` is a real outcome, not a retry.** Capture the reason; do not
  immediately re-draft the same proposal and re-ask.

### Wrong decider

If the gate names an owner who is not the person answering — an ADR whose
`Deciders` lists another handle, an intent whose PO is someone else — do **not**
record their decision as that owner's. Surface the mismatch, leave the state
alone, and offer to record it once the named owner answers (or to amend
`Deciders` as its own explicit change). A single-decider repo where the person
answering *is* the named owner is the common, unremarkable case.

---

## 4. Recording the decision

Ratification is only safe if it is **auditable after the fact**. On `Approve`,
record all four of:

1. **The transition** — the `Status:` flip (ADR) or the header + `## PO
   acceptance` block (intent).
2. **Who** — the deciding human's handle, in `> Ratified by:` / `> Approved by:`.
3. **When** — `> Ratified at:` / `> Approved at:`, `YYYY-MM-DD`.
4. **Channel** — that the decision was given in-session, so an auditor can tell
   an inline ratification from a considered offline review. Both are valid; they
   are not the same evidence, and the record should not blur them.

Plus **one** `/spec/history/` entry — rule `32-living-docs` already requires
one per ratified decision (what / why / who asked / refs). One entry, not one per
field.

On `Reject`, record the reason where a future reader will find it: for an ADR,
the ADR itself (it stays a point-in-time record — **never** delete or renumber
it; supersede instead); for an intent, the feature's `intent.md`. A rejected
proposal that vanishes leaves the next session to re-propose it.

---

## 5. Never promptable

No prompt in any mode authorizes these. They require a human acting in the real
system, and **asking is not authorization**:

- **PR merge** — the reviewed merge is the delivery gate (rule
  `45-commit-autonomy`, `95-not-the-gate`). Never `gh pr merge`. The reviewer
  reads the diff on the PR; an in-session "yes" is not that review, because the
  diff is not what was shown.
- **Deploy** — including a hotfix whose deploy is policy-permitted (rule
  `62-hotfix`). Permitted ≠ auto-executed.
- **Real secrets and credentials**, and **`/infra`** — never relaxed, not even
  pre-production (rule `60-high-risk`).
- **Pushing to a protected branch** — the server-side wall is the authorization;
  no in-session answer substitutes for it (rule `45`).

**Not on this list: the ungraduated solo-trunk trunk push.** While a local
graduation signal stands, rule `45-commit-autonomy` stops trunk pushes being
*silent* — the session's **first** one waits for a human yes, and repeats carry a
non-blocking reminder (on the Copilot CLI the repeat is instead a **silent allow**:
that envelope has no non-blocking channel) — and `check-bash-actions.sh` surfaces
that first push as a PreToolUse **`ask`**, deliberately never a deny. A yes there
**does** authorize that push; the gate clears for good by graduating
(`/steer:protect`). So it is answerable — but it is not one of the three gates in
§2 either: it is a push-time permission decision the harness raises once, with no
`/spec` field to record and no three-option prompt.

The boundary is the point of the rule: gates become **answerable**, never
**removable**. A change that would let a prompt stand in for one of the above is
a defect — report it via `/steer:report`.

---

## 6. Why this exists

The failure it fixes: a `Proposed` ADR that only its author can ratify, with no
in-session way to do it, becomes the top blocker `/steer:next` surfaces every
time the repo is opened — while the decision itself was made minutes after the
ADR was drafted. The record lagged the decision, so the workflow stalled on
bookkeeping rather than on judgement.

The failure it must not introduce: rubber-stamping. A prompt fired immediately
after the agent drafts its own proposal invites a reflexive "yes" without the
deliberation the ADR gate exists to force. §3's tradeoff requirement and §4's
channel stamp are what hold that line — the human sees what they are accepting,
and the record shows how they accepted it.

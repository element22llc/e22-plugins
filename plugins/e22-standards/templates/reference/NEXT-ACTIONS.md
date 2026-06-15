# Recommended next actions — the workflow handoff contract

Shared convention for the `## Recommended next actions` block that every major
E22 workflow skill emits as its **final step**. The block turns the state a
workflow just observed into a forward-looking, **read-only** recommendation: what
a human or agent should do next, and which one action matters most right now.

The goal: each workflow doesn't merely produce artifacts (a spec spine, an audit
report, an approved intent, a PR) — it reconnects those artifacts to the next
action in the lifecycle, so a session that resumes cold, or a human who picks the
repo up later, is never left guessing.

This file owns the **shared logic** — categories, precedence, output format, and
the read-only + locality rules. Each skill owns only its **domain mapping**
(its own states → actions). A skill references this file; it never restates the
definitions or the precedence.

---

## 1. The five categories

Each recommended action falls into exactly one category. The categories separate
*workflow criticality* (can this workflow safely advance?) from *release timing*
(must this be resolved before production?).

| Category | Meaning |
|---|---|
| **Blocking now** | The current workflow cannot safely complete, publish, merge, or advance until this is resolved. |
| **Human decision required** | Progress depends on an explicit human product, architecture, risk, or release decision — including PR review/approval, PO intent validation, and ratifying a `Proposed` ADR. The agent routes it; it never guesses it. |
| **Required before production** | The workflow may complete, but this must be resolved before a production release. *Publishing* a finding is not the requirement — *fixing or explicitly accepting* it is. |
| **Recommended** | Valuable follow-up that is neither blocking nor release-mandatory — including backlog bookkeeping (publishing or shaping optional findings). |
| **Complete** | This workflow has no remaining action in its own lifecycle. May name an *optional* continuation, never a mandatory one. |

**`Complete` means lifecycle integration, not "the skill emitted output."**
Opening a PR is execution-complete but **not** integrated — that is *not*
`Complete`; it is a `Human decision required` gate (the PR awaits review). Never
claim `Complete` while listing an unfinished action that belongs to the same
lifecycle.

---

## 2. Precedence — two levels

Two precedence orders combine. The **shared safety precedence** is universal and
always wins; within it, the **skill-local precedence** orders the workflow's own
states.

### Shared safety precedence (applies everywhere)

1. immediate security or destructive-risk stop;
2. failed required gate in the current workflow;
3. unresolved required human decision in the current workflow;
4. the current workflow's next lifecycle transition;
5. downstream release requirement;
6. optional follow-up;
7. no action required.

### Skill-local precedence

Each skill orders only its own states (e.g. for `/e22-adopt`: secret exposure →
incomplete artifacts → PO/ADR decisions → adoption PR → publish → shape → begin
work → normal flow). Arbitration across *unrelated* workspace state is **out of
scope** for any single skill — that belongs to `/e22-next`, the cross-workflow
navigator that reconstructs the whole workspace and arbitrates one action across
all workflows using these same categories and this same shared precedence.

---

## 3. Derivation rule

Recommendations are **inferred from state the workflow actually observed**, never
hardcoded as "always run X next." Reuse the existing E22 state vocabulary rather
than inventing a parallel one:

- open-question `impact: blocking | non-blocking` and `required_before:` →
  separates **Blocking now** / **Human decision required** from **Required before
  production**;
- feature `Status: draft | approved | implemented | validated | live`;
- issue lifecycle states (`inbox … ready-for-dev … in-progress … validate …
  done`);
- ADR `Proposed | Accepted | Superseded | Deprecated` (a `Proposed` ADR is a
  **Human decision required**).

If the relevant state is genuinely empty, the honest recommendation is
`No action is currently required.` — do not manufacture busywork.

---

## 4. Locality rule

A skill recommends actions from **the workflow invocation and the artifacts it
directly read or changed**. It may surface a repository-wide **safety** blocker it
happened to observe during execution (e.g. a committed secret), but it does
**not** run a general workspace scan for unrelated state. Cross-workflow
workspace reconstruction belongs to `/e22-next`.

- `/e22-spec customer-export` evaluates that feature's intent, questions, contract,
  tracker state, and relevant ADRs — not every other feature's open questions.
- `/e22-work #123` evaluates issue #123, its branch, PR, criteria, validation, and
  any blocker it directly hit.
- `/e22-adopt` and `/e22-audit` may evaluate the **whole repository** — repo-wide
  discovery is their explicit purpose.

This keeps handoffs fast, predictable, and explainable, and stops each skill from
silently becoming a partial `/e22-next`.

---

## 5. Output format

Emit this block, in this order, as the workflow's final output. Omit any category
section that is empty.

```markdown
## Recommended next actions

### Blocking now
[Only actions preventing the current workflow from safely advancing.]

### Human decision required
[Explicit product, architecture, risk, or release decisions.]

### Required before production
[Release obligations that do not block completion of the current workflow.]

### Recommended
[Optional or lower-priority follow-up.]

### Complete
[State that this workflow's lifecycle is complete. Omit when it is not.]

### Current recommended action
[Exactly one concrete action, or "No action is currently required."]
Suggested command: `/e22-...`
```

### Rules

- **Omit empty category sections.** Only `Current recommended action` is always
  present.
- **`Current recommended action` is the canonical field — an *action*, not a
  command.** It names exactly one concrete next step, chosen by precedence (§2),
  or the literal sentence `No action is currently required.`
- **`Suggested command` is optional.** Include it on its own line *only* when a
  real, applicable E22 (or built-in) command advances the action. Omit it when the
  next step is human or external — rotating a credential, a PO approving an intent,
  a reviewer reviewing a PR, waiting for CI, or configuring an external system are
  **not** commands.
- **Never force a command.** A `Suggested command` that doesn't actually perform
  the action (e.g. `/security-review` does not *rotate* a secret) misleads — name
  the human action, and offer the command only as the follow-up it genuinely is.
- **Read-only.** The block is the last thing a skill emits and changes nothing. It
  does not publish issues, accept ADRs, claim work, push branches, or create PRs
  without the approval those workflows already require. It never auto-executes the
  recommendation.

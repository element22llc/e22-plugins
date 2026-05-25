---
description: Check the status of vibe sessions, handoffs, and proposals you're championing.
argument-hint: [optional search term, branch name, PR number, or "mine"]
---

# /proposal-status

Helps a Product Owner see where their work stands — prototype branches still in
play, handoffs awaiting validation, proposals merged and live — without learning
the engineering team's internal label vocabulary.

## Surface and connector requirements

Works on **Claude.ai (Chat), Claude Cowork, and Claude Code**. The GitHub
connector is **required**; refuse cleanly if missing. See
[`CONNECTORS.md`](../../../CONNECTORS.md).

Connector capabilities used:

- **Projects (v2)** — primary data source. The `Proposals` project board per
  product is the canonical status home; PRs and branches are surfaced *from* it,
  not queried as a separate list.
- **Pull requests** (read) — for any PR linked from a project card, fetch the
  current labels and CI state to surface the right plain-language status.
- **Branches** (read) — for `prototype/*` branches not yet linked to a PR, check
  last-commit age to detect "going stale".
- **Repo contents** (read) — link to the Spine markdown file in the repo so
  the PO can read the engineer-facing summary.

## Workflow

### 1. Determine scope from $ARGUMENTS

- Empty or `"mine"` → show everything where this user is the champion (across
  both lanes).
- A search term → search PR titles, bodies, and Spine files for that term.
- A PR number → look up that specific proposal.
- A branch name (e.g. `prototype/foo`) → look up that specific prototype.

### 2. Query the Proposals project board

The `Proposals` project (Projects v2) is the canonical source. Query via the
GitHub connector with filter `Champion = <PO github handle>` (or no filter for
a search term). For each card, read:

- `Status` field → maps to the plain-language status table below
- `Lane` field → prototype vs production
- `Branch`, `PR`, `Spine`, `Handoff bundle` fields → links to surface
- Card's last-update timestamp → for "going stale" detection on prototype lane

If no project board exists yet (greenfield rollout), fall back to listing PRs
with the `proposal` label and `prototype/*` branches by commit author. Surface
this fallback to the PO once: *"No Proposals board found for this product — I
fell back to scanning branches and PRs directly. Ask an engineer to create one
so I can show you cleaner status next time."*

### 3. Translate state into plain language

Both lanes share the same translation table for the PO:

| Internal signal               | What to say to the PO                                      |
| ----------------------------- | ---------------------------------------------------------- |
| `prototype/*` branch, active  | "You're still iterating on this."                          |
| `prototype/*` branch, idle 5d+| "This prototype is going stale — auto-expires soon."       |
| label `awaiting-validation`   | "Engineer hasn't looked yet — waiting in the queue."       |
| label `drafting`              | "Engineer is working on it. Preview coming."               |
| label `preview-ready`         | "Ready for you to review the preview."                     |
| label `review-requested`      | "You confirmed it works — engineering review in progress." |
| label `experimental`          | "Merged. Not visible to customers yet."                    |
| label `production-graded`     | "Live for customers."                                      |
| validation: `Reject`          | "Engineer declined — see their notes."                     |
| validation: `Redesign`        | "Engineer is rebuilding from a clean slate."               |
| validation: `Refactor`        | "Engineer is reworking it before it can ship."             |
| validation: `Keep`            | "Engineer is hardening your prototype in place."           |

### 4. Format the response

Group by lane and sort newest-first. Keep it scannable:

```
Your work (5):

PROTOTYPE LANE
• Re-delivery flag — You're still iterating (prototype/po-redelivery-flag, 2h ago)
  → preview: <preview-url>
• Refund modal v3 — Going stale, auto-expires in 2 days (prototype/po-refund-modal-v3, 5d ago)
  → preview: <preview-url>

AWAITING VALIDATION
• Faster checkout — Engineer hasn't looked yet (PR #142, 4h since handoff)
  → engineer: queued for @platform-team

PRODUCTION LANE
• Dark mode toggle — Ready for you to review (PR #145, preview-ready 1h)
  → engineer: @sam   <preview-url>
• Receipt download bug — Live for customers (PR #138, production-graded 11d)
  → engineer: @jordan   no action needed
```

### 5. Surface action items

- If anything is in `preview-ready`, mention the PO should validate and tick
  acceptance criteria.
- If anything in the prototype lane is **going stale**, ask if they want to
  `/package-handoff` or let it expire.
- If any validation came back as `Reject` or `Redesign`, surface the engineer's
  notes (read from the Spine's "Validation decision" section).

### 6. Offer a follow-up

*"Want me to set up a live status page you can come back to?"* If yes, create an
artifact via `mcp__cowork__create_artifact` that re-fetches on each open.

## Things to avoid

- **Don't expose internal label strings in the default output.** They can ask
  for the technical view if they want it.
- **Don't editorialize on pace.** Just report state and age — not "this is
  taking too long" or "engineering is fast on this one."
- **Don't ping engineers automatically.** The PO decides when to nudge.
- **Don't hide rejections.** If a proposal came back `Reject` or `Redesign`,
  show the engineer's notes, not just the verdict. The PO needs context to
  re-frame.

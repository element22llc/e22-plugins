---
type: agent
---

You are the read side of GitHub Issues for the repository `acme/checkout`, the
tracker `spec/tracker.md` declares. Answer each `issue_read` call from the
backlog below, honouring **both** arguments: `issue_number` picks the issue, and
`method` picks which projection of it to return.

A fixed body cannot do that, which is the bug this responder replaces: the suite
ran with a canned `issue_read` that returned #123 for every call, and runs spent
their turns probing it and then reporting "a defect in steer's bundled MCP
server" instead of routing. Answer the arguments you were actually given. For an
issue number that is not below, or a `method` this file does not describe, use
the ordinary tool-error form described in your instructions — a not-found is
real tracker behaviour a skill should handle.

Reply with a JSON object and nothing else.

## `method: get` (or absent) — the issue itself

Return `number`, `title`, `state`, `labels`, `url`
(`https://github.com/acme/checkout/issues/<n>`), `author`, `created_at`, `body`.
No issue carries a `steer:*` marker or a `steer:state` line: this backlog
predates the schema, and the triage case exists to observe exactly that.

**#123** — `Cart total ignores line-item quantity` · open · labels `bug`,
`checkout` · author `acme-po` · created `2026-02-03T09:14:00Z`

> A cart with 3 of the same item is charged for 1.
>
> **Steps**
> 1. Add SKU-9 (unit price 1250) with quantity 3.
> 2. Open the cart page.
> 3. The total shows 1250, not 3750.
>
> **Expected** — per `spec/features/checkout/contract.md`, each line item
> contributes `unit_price * quantity`, and a missing `quantity` counts as one.
>
> **Actual** — `checkout.total()` sums `i["price"]` and never reads `quantity`.
>
> This is the approved one-page-checkout feature (acme/checkout#101).

**#118** — `Guest checkout` · open · labels `epic` · author `acme-po` · created
`2026-01-28T11:02:00Z`

> Let shoppers pay without an account. Covers session carts, email receipts,
> fraud limits, and the account-upgrade prompt afterwards. Needs breaking down
> before anyone starts.

**#117** — `Multi-currency support` · open · labels `epic` · author `acme-po` ·
created `2026-01-28T10:55:00Z`

> Charge in the shopper's currency. Touches pricing, the gateway, rounding
> rules, refunds, and reporting. No acceptance criteria yet.

**#109** — `Decline reason is not shown to the shopper` · open · labels `bug`,
`checkout` · author `acme-po` · created `2026-01-22T16:40:00Z`

> A declined card clears the cart and shows a generic error.

**#101** — `One-page checkout` · open · labels `feature` · author `acme-po` ·
created `2026-01-12T09:30:00Z`

> Tracking issue for the approved one-page-checkout intent in
> `spec/features/checkout/`.

## `method: comments`

Every issue here has **no comments** — return an empty list. This is a fixture,
not a lived-in tracker, and an invented comment thread becomes evidence a skill
then reasons from.

## `method: sub_issues`

No issue has sub-issues — return an empty list, including for the two epics
(#117, #118) and the feature (#101). That absence is the point of the triage
case: it is what makes decomposition the recommended action rather than a
reconciliation.

## `method: labels`

The repository's labels are exactly `bug`, `feature`, `epic`, `checkout`. None
of the `source:*` / `needs:*` / `risk:*` taxonomy exists yet, so a skill that
plans a label write correctly concludes `bootstrap-labels` has to run first.

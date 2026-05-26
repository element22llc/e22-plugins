# Product Spine — `<product or proposal name>`

> **Scope:** This template is for **governed-production** work after Dev
> has imported the MVP into a repo. It is not required, and not
> recommended, during the local MVP sandbox (PO exploration) phase. The
> sandbox uses `HANDOFF.md` as its single durable artifact (spec v0.4
> §7.2). The Product Spine becomes useful once production-bound code lives
> in a versioned repo and needs durable spec memory.

> The **Spine** is the artefact that travels from prototype to production.
> Not the chat log. Not the commit list. This file.
>
> Maintained by the `spine-writer` plugin on every meaningful change.
> Validated by engineers at the `/validate` gate.
> Updated post-merge by `spine-writer` whenever the code drifts from the Spine.

---

**Champion:** `<github-handle of the PO>`
**Product:** `<product slug>`
**Status:** `prototyping` | `awaiting-validation` | `in-production` | `archived`
**Origin branch:** `<branch name>`
**Live preview:** `<preview URL or "none">`
**Last updated:** `<YYYY-MM-DD by @who>`

---

## Intent

**The user problem, in the PO's own words.**

> 2–4 sentences. What is the user trying to do, where do they get stuck today, and
> what will be different after this lands. No technical detail.

**Success criteria** (the PO will tick these off when validating the preview):

- [ ] `<observable, checkable condition>`
- [ ] `<observable, checkable condition>`
- [ ] `<observable, checkable condition>`

**Out of scope** (so the engineer doesn't scope-creep, and the PO doesn't expect more
than what's being built):

- `<thing this proposal explicitly does NOT change>`
- `<thing this proposal explicitly does NOT change>`

---

## UX

**Screens, states, copy, design decisions.**

For each screen or state touched by this change:

### `<screen or state name>`

- **Entry point:** how the user gets here
- **What they see:** key elements, layout intent (no pixel-perfect specs — link to
  Figma/Claude Design bundle if there is one)
- **What they can do:** primary action(s), secondary action(s), and what's
  intentionally absent
- **Empty / loading / error states:** what each looks like (or "n/a")
- **Copy decisions worth noting:** any phrasing the PO explicitly chose

**Design source:** `<link to Claude Design bundle, Figma, or "vibe-coded only">`

---

## Surface

**The API, events, and schemas this change exposes or consumes.**

### New or modified endpoints

| Method | Path                    | Auth        | Request body / params         | Response                       |
| ------ | ----------------------- | ----------- | ----------------------------- | ------------------------------ |
| `POST` | `/api/<...>`            | session     | `{ ... }`                     | `200 { ... }` / `4xx { error }` |
| `GET`  | `/api/<...>`            | session     | query: `?...`                 | `200 [{ ... }]`                |

### Events emitted

| Event name           | When fires                          | Payload shape                       |
| -------------------- | ----------------------------------- | ----------------------------------- |
| `<product>.<verb>`   | `<trigger>`                         | `{ ... }`                           |

### Schema changes

- `<table or collection>`: `<added column / new constraint / migration notes>`
- Backfill required? `<yes/no — if yes, describe>`

### Feature flag

- **Flag name:** `<product>.<feature>`
- **Default state:** `off`
- **Rollout plan:** `<who sees it first, then how it ramps>`

---

## Architecture

**Components, data flow, assumptions.** This is the section the engineer reads at
the `/validate` gate.

### Components touched

| Component                    | Change                                    |
| ---------------------------- | ----------------------------------------- |
| `apps/<product>/frontend/<>` | `<short description of what was added>`   |
| `apps/<product>/backend/<>`  | `<short description of what was added>`   |
| `packages/<>`                | `<short description of what was added>`   |

### Data flow

```
<ascii or short prose: user action → frontend → API → service → DB; then
return path with caching, events, etc.>
```

### Dependencies added since `main`

- `<package@version>` — `<why>`

### Assumptions Claude made

> Things the prototype assumes but didn't ask about. These are the highest-risk
> items at the validation gate.

- `<assumption — e.g. "every order has at most one re-delivery request">`
- `<assumption — e.g. "shipping addresses are immutable once an order is placed">`

### Lane-aware notes

- **Prototype-lane behavior:** `<what the sandbox is faking, e.g. "uses fixture
  shipments from packages/test-fixtures">`
- **Production-lane requirements:** `<what must change for prod, e.g. "needs a real
  shipping-provider client and timeout/retry policy">`

---

## Open questions

**Things Claude couldn't decide alone.** The engineer must resolve each of these
before the proposal can transition past `review-requested`.

- [ ] `<question — e.g. "Should re-delivery cost be charged to the customer, the
      seller, or absorbed by us? Currently absorbed in the prototype.">`
- [ ] `<question — e.g. "Is there a per-order limit on re-delivery requests?
      Prototype allows unlimited.">`
- [ ] `<question — e.g. "Do we need to notify the original carrier of the
      re-delivery, or only the new one?">`

---

## Validation decision

**Filled in by the engineer at `/validate`.**

- **Decision:** `Keep` | `Refactor` | `Redesign` | `Reject`
- **Decided by:** `@<engineer>`
- **Decided on:** `<YYYY-MM-DD>`
- **Notes:** `<what changes, if any, are required before this can enter
  governed production; or why this was rejected>`

---

## Changelog

> The `spine-writer` plugin appends to this section on every meaningful change.
> Do not edit by hand.

- `<YYYY-MM-DD>` — Spine created from prototype branch `<name>` by `@<PO>`.
- `<YYYY-MM-DD>` — `<what changed, who triggered it>`.

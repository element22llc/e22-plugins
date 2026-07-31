---
name: adr
description: "Create a numbered ADR from the bundled template, then offer its Deciders in-session ratification; `accept` writes the Proposed → Accepted transition."
when_to_use: Use for any hard-to-reverse or cross-cutting choice (stack, database, auth, deployment, new pattern), when asked to record a decision, or when a Decider ratifies a `Proposed` ADR ("accept ADR 0007") — including one drafted earlier.
argument-hint: "[<slug> | accept <n>]"
---

<!-- steer:modes default,accept -->

# Write an ADR

Create a new Architecture Decision Record at `/spec/decisions/000N-[slug].md` in
the product repo, from the bundled template.

## Steps

1. Decide the next sequential number: list `spec/decisions/` and use the highest
   existing `000N` + 1 (start at `0001`). **Never renumber** existing ADRs.
2. Pick a short kebab-case `[slug]` (`use-postgres-for-search`).
3. Ensure the dir exists (`mkdir -p spec/decisions`), then copy
   `${CLAUDE_PLUGIN_ROOT}/templates/spec/adr.md` → `spec/decisions/000N-[slug].md`.
4. Fill in Context, Decision, Alternatives considered (with rejection reasons),
   and Consequences (positive / negative / neutral). Set Status to `Proposed`
   until accepted; set Deciders. Leave the `> Ratified …` fields as-is —
   `accept` writes them. **One exception, `/steer:init` step 4:** when the dev
   has just chosen the stack in that interactive setup, the decision is already
   made, so init authors that ADR at `Accepted` with the ratification fields
   stamped (`> Ratified via: in-session`). That is a *create*, not a
   `Proposed → Accepted` transition — `accept` remains the single writer of the
   transition.
5. **Offer ratification** (below) rather than ending on a `Proposed` ADR the
   author has to go and hand-edit.

## Offer ratification — don't end on a dead `Proposed`

A `Proposed` ADR blocks everything downstream, and the person who can unblock it
is usually the one in the session. So having drafted it, **present the tradeoff
and ask** — one question, three options: **Approve · Reject · Decide later**
(rule `61-gate-prompts`; full protocol `/steer:reference gates`).

The prompt must show the **Decision**, the **rejected alternatives with their
reasons**, and the **negative** consequences. "Approve ADR 0007?" is theater — a
human cannot decide what they cannot see, and prompting straight after you drafted
your own proposal is exactly where rubber-stamping happens.

- **Approve** → run `accept <n>` (below), then continue into whatever the ADR was
  blocking, in the same pass.
- **Reject** → keep `Status: Proposed`, record the reason and who declined in the
  ADR's Context (or supersede it later). Never delete or renumber a rejected ADR;
  don't immediately re-draft the same proposal and re-ask.
- **Decide later** → leave every field untouched. `/steer:next` keeps surfacing it
  as *Human decision required*, exactly as before.

Never pre-select an option, never infer approval from ambient agreement ("ok",
"thanks", silence, or sign-off on an earlier plan), and never bundle two ADRs into
one prompt. If `Deciders` names someone who is not the person answering, surface
the mismatch and leave the state alone — you may not record their decision for
them.

## `accept` mode — `/steer:adr accept <n>`

<!-- steer:transition-owner adr-status:Proposed->Accepted -->

The **single writer** of `Proposed → Accepted`. Requires an explicit decision from
a named Decider — reached through the prompt above, or invoked directly when a
Decider ratifies an ADR drafted in an earlier session. **Never run on your own
initiative**; drafting an ADR does not authorize accepting it.

Refuse (report the current state, write nothing) when the ADR is `Superseded` or
`Deprecated` — ratification never revives a retired record. **Idempotent on
`Accepted`**: report the existing `> Ratified by:` / `> Ratified at:` and append
**no** duplicate history entry.

On a clean acceptance, in one change:

1. Flip `> Status:` to `Accepted`.
2. Stamp `> Ratified by: @<handle>`, `> Ratified at: <YYYY-MM-DD>`, and
   `> Ratified via: in-session` (or `offline-review` when the decision came from a
   review outside the session).
3. Write **one** `/spec/history/` entry file — what / why / who asked / refs (rule
   `32-living-docs`: one entry per ratified decision). **In a polyrepo member**
   (`spec/PRODUCT.md`), ADRs live here but the action history is the workspace's — write
   the entry there if `workspace.path` resolves, and otherwise record the
   ratification in the PR description and say the workspace ledger still needs the
   entry. Never create a local `spec/history/` in a member
   (`/steer:reference polyrepo`).
4. If this ADR supersedes an older one, mark that one
   `Superseded by [link]` — never delete or renumber it.

The channel stamp is what makes self-ratification auditable: a solo repo's author,
decider, and reviewer are the same person, and that is legitimate — an
**unrecorded** self-ratification is the audit hole, not self-ratification itself.

## When to write one (and when not)

Write an ADR for choices that are hard to reverse (database, auth provider,
deployment platform, tenancy model, major pattern), a new pattern other features
will follow, an explicit rejection of an obvious alternative, or anything a
future dev would ask "why did they do it this way?" about.

Do **not** write one for routine implementation choices, things obvious from the
code, or single-feature decisions (those go in the feature's `contract.md`).

When superseding an ADR, mark the old one `Superseded by [link]` and link the new
one — do not delete or renumber it. Full guidance:
`${CLAUDE_PLUGIN_ROOT}/templates/reference/SPEC-FRAMEWORK.md`.

ADRs are **exempt from template reconciliation** — they are immutable,
point-in-time records. Never retrofit a newer `adr.md` template's sections into an
existing ADR; supersede it with a new one instead.

## Recommend the next action

After drafting the ADR, emit a `## Recommended next actions` block per
`${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md`. A freshly written ADR
is `Proposed`, so the next step is a human decision — but it is now an
**answerable** one, so the row names how to answer it.

| Observed state | Category | Action / suggested command |
|---|---|---|
| ADR drafted, `Status: Proposed`, Decider in the session | Human decision required | Answer the ratification prompt — on Approve, `/steer:adr accept <n>` |
| `Proposed`, Decider is someone else | Human decision required | The named Deciders ratify or reject (no command) |
| ADR accepted, supersedes an older one | Recommended | Mark the old ADR `Superseded by [link]` |
| Accepted, and it was blocking work | Blocking now — next transition | Continue the work it gated (`/steer:work`, `/steer:spec`) |
| Accepted, no follow-up | Complete | `No action is currently required.` |

The block recommends; the **decision** stays with the named Deciders — `accept`
records their answer, it never supplies one.

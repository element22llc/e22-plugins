---
description: Auto-triggered when a Product Owner asks about Element 22 workflow terminology — "what's a prototype lane", "what's the Spine", "what's vibe-coding here", "what's a champion", "what does experimental mean", "what's a feature flag", "what's Keep vs Refactor vs Redesign vs Reject", "what's SOC2 scope", "what's CODEOWNERS", or generally what a workflow term or label means.
---

You're explaining Element 22 workflow terminology to a Product Owner. Stay in plain
language and answer in 2-3 sentences max — they want enough to act, not a full doc.

## Glossary

**Prototype lane** — Where exploration lives. A `prototype/<short-name>` branch
spun up by `/vibe`, with a sandboxed preview URL. Throwaway by default. No real
data, no production credentials, no risk. If it doesn't work out, you delete the
branch.

**Production lane** — Where ships live. Branches off `main`, real PRs, real CI,
real review, behind feature flags. POs cross over too — once code is live, even a
one-word copy tweak from the PO flows through this path.

**Vibe-coding** — Describing what you want in plain language and having Claude
build it on a sandboxed branch within minutes. You see something working, react,
iterate. The opposite of writing a spec first.

**Product Spine** — The structured summary an engineer reads at the validation
gate. Has five sections: Intent, UX, Surface, Architecture, Open Questions.
Maintained automatically by the `spine-writer` plugin. It's the artefact that
travels — not the chat log, not the commit list.

**Handoff** — The moment a prototype is ready for an engineer. You run
`/package-handoff` and Claude packages the prototype into a Spine + a bundle of
dependency/pattern/violation reports, then opens a draft PR.

**Validation gate** — Where an engineer makes one decision: **Keep** (production-shaped, harden in place), **Refactor** (intent right, implementation needs rework), **Redesign** (right problem, wrong architecture, restart cleanly), or **Reject** (wrong problem, back to the drawing board).

**The Four Guarantees** — What protects you in the prototype lane: branch-per-idea,
synthetic data, ephemeral URL, sandbox secrets. You can't accidentally email real
customers or charge real cards from a prototype branch.

**Champion** — The PO who decides whether the change is doing what they wanted.
Usually whoever started the vibe session. Engineers come back to the champion when
they need a decision or want you to look at the preview.

**Preview** — A working, looks-real version of the change. Three sizes (Tier 0 / 1
/ 2). Claude picks the tier automatically. Prototype-lane previews are always
sandboxed and expire after a few days idle.

**Lifecycle labels** — Where the work is in the process:

| Label                | What it means                                                |
| -------------------- | ------------------------------------------------------------ |
| `prototype/*` branch | You're still iterating in the sandbox.                       |
| `awaiting-validation`| Handed off — engineer hasn't picked it up yet.               |
| `drafting`           | Engineer is building (Refactor or Redesign chosen).          |
| `preview-ready`      | Your turn — try the production-lane preview.                 |
| `review-requested`   | You said it works. Engineers are reviewing the code.         |
| `experimental`       | Merged. Not visible to customers yet.                        |
| `production-graded`  | Live for customers.                                          |

**Feature flag** — A switch the engineering team can flip to turn a change on or
off for some percentage of users. `experimental` changes are behind a flag at 0%
by default. Someone has to actively promote the flag for users to see the change.
This is why `experimental` ≠ live.

**Promotion** — Flipping the feature-flag switch from 0% to a higher percentage.
Promotions are gated: not anyone can run `/promote`, and SOC2 products can't jump
past 10% in one step.

**SOC2 in scope** — A subset of Element 22 products is governed under SOC2 rules.
Proposals for those products need two reviewers, can't use production data in
previews (which the prototype lane already enforces), and have stricter promotion
gates. The system tells you when you're working on one of those.

**House-rule plugins** — Six plugins applied to every Claude session, PO or Dev:
`spec-driven-dev`, `always-test`, `house-style`, `security-rails`, `spine-writer`,
`handoff-packager`. You don't need to think about them; they enforce the rules
automatically.

**CODEOWNERS** — A file that says which team has to approve changes to which
parts of the codebase. The champion doesn't need to track this.

**Tier 0 / 1 / 2** — Preview environment sizes. Claude picks automatically;
prototype lane defaults to Tier 1, Tier 2 is blocked on prototype branches.

## How to answer

When a PO asks one of these, find the relevant entry, paraphrase it briefly, and
offer to go deeper if they want. Do not dump the whole glossary.

If they ask about a term not in the glossary, **search the product repo's
markdown docs** via the GitHub connector before saying you don't know — try
`docs/glossary.md`, `docs/`, `product-spine/`, and `CONSTITUTION.md`. If you
find it, paraphrase and credit the source file with a link. Otherwise, say so
plainly and offer to ask an engineer to add the term to `docs/glossary.md` (a
small PR is the right shape for that). The repo is the only source of truth —
there is no wiki to fall back to.

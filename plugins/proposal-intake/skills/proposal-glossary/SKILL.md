---
description: Auto-triggered when a contributor asks about Element 22 proposal terminology — "what does experimental mean", "what's a feature flag", "what's a preview", "what's SOC2 scope", "what's a champion", "what's CODEOWNERS", "what tier", or generally asks what a proposal-related label or term means.
---

You're explaining proposal-workflow terminology to a non-engineer. Stay in plain language and answer in 2-3 sentences max — they want enough to act, not a full doc.

## Glossary

**Proposal** — Any change to an Element 22 product, big or small, filed through the standard process. Everything goes through a proposal: a bug fix, a copy change, a new feature, an infrastructure update.

**Champion** — The person on the requesting side who decides whether the change is doing what they wanted. Usually whoever filed the proposal. Engineers come back to the champion when there are decisions to make or when there's a preview to look at.

**Preview** — A working, looks-real version of the change that the champion can click around in before it goes live. There are three tiers: a quick component-only preview (~5 seconds), a frontend-plus-shared-backend preview (~1-2 minutes), and a full ephemeral stack for big changes (~10-15 minutes). The engineer picks the tier automatically based on what's changing.

**Lifecycle labels** — Where the proposal is in the process. In contributor-friendly terms:

| Label you might see | What it means |
|---|---|
| `drafting` | Engineer is building it. |
| `preview-ready` | Your turn — try the preview. |
| `review-requested` | You said it works. Engineers are reviewing the code. |
| `experimental` | Merged into the codebase. Not visible to customers yet. |
| `production-graded` | Live for customers. |

**Feature flag** — A switch the engineering team can flip to turn a change on or off for some percentage of users. `experimental` changes are behind a flag at 0% by default. Someone has to actively promote the flag for users to see the change. This is why `experimental` ≠ live.

**Promotion** — Flipping the feature-flag switch from 0% (nobody sees it) to a higher percentage (some or all customers see it). Promotions are gated: not anyone can run `/promote`, and SOC2 products can't jump past 10% in one step.

**SOC2 in scope** — A subset of Element 22 products is governed under SOC2 compliance rules. Proposals for those products need two reviewers, can't use production data in previews, and have stricter promotion gates. If you're filing a proposal for one of those products, the system will tell you.

**CODEOWNERS** — A file that says which team has to approve changes to which parts of the codebase. Affects who reviews the PR; the champion doesn't need to track this.

**Tier 0 / 1 / 2** — The preview environment sizes (see "Preview" above). The engineer or `/propose` picks automatically.

## How to answer

When a contributor asks one of these, find the relevant entry, paraphrase it briefly, and offer to go deeper if they want. Do not dump the whole glossary.

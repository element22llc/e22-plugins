---
description: Auto-triggered when a Product Owner describes a change they'd like to see in an Element 22 product ("I wish X did Y", "could we make X different", "we should change Y", "X is annoying because…", "what if we tried Z"). Offers to vibe-code a working preview without requiring them to know about /vibe.
---

A PO has just described something they'd like to change in an Element 22 product.
At Element 22 the right next move is **not** to file a ticket and wait — it's to
spin up a sandboxed preview they can click around in. Five rough drafts beat one
polished doc.

They probably don't know the formal workflow yet. Asking them to invoke `/vibe`
would be friction. Treat this as if `/vibe` had been called with their description
as the argument.

## Before launching into it

Briefly acknowledge what you heard and confirm they want to try it. Sometimes people
are just venting or thinking out loud. Example:

> "Sounds like you'd like to try a different way of handling failed payments at
> checkout. Want me to spin up a sandboxed version so you can see what it would
> look like? Takes a couple of minutes — you'd get a preview URL and we can
> iterate from there. No commitment; if you don't like it, we throw the branch
> away."

If they say no, stop. If they say yes, proceed.

## What happens next

Follow the `/vibe` workflow:

1. Refine the description only if it's fuzzy (delegate to `intake-clarifier` if
   needed — one question max, two as ceiling).
2. Identify product and champion via AskUserQuestion (one question per turn).
3. Create a `prototype/<slug>` branch and implement a working version.
4. Apply the Four Guarantees automatically: branch-per-idea, synthetic data,
   ephemeral URL, sandbox secrets.
5. Push, wait for the preview, surface the URL with 2-3 specific things to try.
6. Iterate on the PO's reactions. The branch *is* the conversation.

When the PO is happy, suggest `/package-handoff` to send the prototype to an
engineer for validation.

## What this skill is *not*

- Not a ticket-filing flow. The PO is not filing a written brief.
- Not a spec-writing flow. The Spine comes later, from `/package-handoff`.
- Not a commitment to ship. Prototype-lane branches are throwaway by default.

## Alternative on-ramp: file an issue instead

Some POs would rather **file the idea as a GitHub issue** than vibe-code it
immediately. Reasons: the idea is half-formed and needs team discussion first;
the change might be out of scope; the PO is on the move and can't iterate now.

If the PO indicates that's their preference, use the GitHub connector to file a
labelled issue (`proposal-intake`) on the relevant product repo. Include the
PO's words verbatim, a one-paragraph paraphrase, and a note that an engineer
should run `/propose` (or invite the PO to `/vibe`) when they pick it up.

That option only appears if the GitHub connector is connected. If it isn't,
offer to draft a Slack-ready message instead.

This skill is the on-ramp; `/vibe` is the same flow when the PO already knows
what they want.

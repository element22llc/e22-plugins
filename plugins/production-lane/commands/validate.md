---
description: Engineer validation gate for a packaged prototype. Read HANDOFF.md and any Spine, make one of five decisions — Harden, Extract, Rewrite, Reject, Continue exploring.
argument-hint: <PR number or branch name>
---

# /validate

A PO completed an MVP in their local sandbox and a HANDOFF.md is ready for
review. **Your job is to make one decision** — not to read the whole branch. The
preview already proves it works; the question is whether the implied architecture
is something the team will still want to own in a year.

## Surface and connector requirements

Works on **Claude.ai (Chat), Claude Cowork, and Claude Code**. The GitHub
connector is **required** — validation is a public state change (rename branch,
move labels, mutate Project card) and cannot happen without it. Refuse cleanly
if the connector is missing.

Connector capabilities used:

- **Pull requests** — read the PR, any Spine, and the HANDOFF.md; rename
  the branch on Harden; close on Reject; comment on every decision.
- **Branches** — rename the handoff source branch → `proposal/<slug>` on Harden; create
  fresh `proposal/<slug>` off main on Extract/Rewrite.
- **Projects (v2)** — advance the card to the post-validation Status (`drafting`
  for Harden/Extract/Rewrite, `rejected` for Reject); fill in `Validation
  decision` and `Decided by` fields.
- **Labels** — drop `awaiting-validation`, apply `drafting` (or close).
- **Comments** — post the decision rationale in the PR thread.
- **Repo contents** — update the Spine's "Validation decision" section and
  (on Extract/Rewrite) carry the §10 *"What should NOT be reused"* notes from
  the HANDOFF.md into the new branch.

The five decisions are mutually exclusive:

| Decision               | What it means                                                              | What happens next                                                                            |
| ---------------------- | -------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| **Harden**             | Prototype is production-shaped and Dev accepts ownership of the technical choices. | Import the prototype source into the governed repo, open a draft PR, run the `/propose` workflow from step 5 (self-review) onward. |
| **Extract**            | Keep selected flows, components, copy, data-shape ideas, or UX decisions; build the rest fresh. | Open a new draft PR; carry only the named pieces forward, drop the rest. Use HANDOFF.md §3 (UX decisions) and §6 (data model) as the source of truth for what to extract. |
| **Rewrite**            | Intent is right; the implementation is disposable.                         | Open a new draft PR off `main`. Reimplement using HANDOFF.md as the spec. Do not pull from the prototype source. |
| **Reject**             | Wrong problem or wrong direction.                                          | Close the handoff with a respectful comment quoting HANDOFF.md §15 (rationale) and §13 (open questions). PO can re-vibe with feedback. |
| **Continue exploring** | PO should iterate more before engineering engages.                         | No PR. Reply to the PO with what specifically is unclear or unfinished — typically tied to HANDOFF.md §13 (open questions) and §8 (risks). |

For brand-new MVPs the default is **Extract** or **Rewrite** (spec v0.4 §7.4).
**Harden** is allowed only when Dev has reviewed the implementation and accepts
ownership of the technical choices.

You may run `/validate` multiple times if you change your mind before committing —
nothing is final until you confirm the decision in chat.

## Workflow

### 1. Locate the proposal

`$ARGUMENTS` is a PR number, a branch name, or `latest` (the most recent
`awaiting-validation` PR for which you are a CODEOWNER).

### 2. Read the Spine — not the chat log

Read `proposals/<branch-slug>/product-spine.md` (or the linked Spine if the
product uses a single canonical one). Scan in this order:

1. **Open Questions.** These are the highest-risk items. The PO did not have the
   context to decide them; you do.
2. **Architecture → Assumptions.** Things the prototype assumes but didn't ask
   about. Many Rewrite decisions come from here.
3. **Surface.** New endpoints, events, schema changes. SOC2 implications live here.
4. **Intent → Success criteria.** Sanity-check that the prototype actually achieves
   them. If it doesn't, it's not Harden.
5. **UX.** Only relevant if you're considering Harden on a UI-heavy change.

### 3. Read HANDOFF.md pre-flight

HANDOFF.md lives at the workspace root (see
[spec §9.3](../../../docs/collaborative-ai-workflow-spec.md#93-handoff-bundle-format)).
It contains:

- **§5 New dependencies since `main`** — every package added. Look for: license conflicts, transitive bloat, anything not already on the team's approved list (see [`TECH-STACK.md`](../../../TECH-STACK.md)).
- **§6 Risky patterns detected** — anything in the diff that doesn't match existing patterns, plus plugin-pack warnings. If everything's novel, that's a Rewrite signal.
- **§10 What should NOT be reused** — the prototype shortcuts (fake auth, hardcoded users, inlined config) that must not migrate to production by inertia. If this list is long, that's an Extract or Rewrite signal.
- **§11 Acceptance checks** — the observable conditions the PO will verify on the production PR. These anchor product approval; do not invalidate them silently.

Plugin violations from `house-style`, `security-rails`, and `always-test`
(lenient local MVP mode) appear under §6. The volume here is the
single best Harden/Extract/Rewrite signal.

### 4. Read the constitution

Check that the change doesn't violate the things Claude must not do (see
`CONSTITUTION.md`). If it does, that's an automatic Reject regardless of how good
the idea is.

### 5. Make the decision

Pick one of Harden / Extract / Rewrite / Reject / Continue exploring. Surface your reasoning in chat
in 3-5 sentences. Be specific about:

- Which signal (Open Question, Assumption, novel pattern, plugin violation count)
  drove the decision.
- For Extract / Rewrite: what specifically needs to change.
- For Reject: which framing assumption was wrong, so the PO knows how to re-vibe.
- For Continue exploring: what is still unclear or unfinished in the HANDOFF.md.

**SOC2 exception:** for products marked `soc2: true`, `Harden` is unavailable. The
minimum is `Rewrite`, which forces a code-review pass and second-reviewer signoff.
This is a constitution rule, not a choice.

### 6. Apply the decision

#### If Harden:

- Import the prototype source into the governed repo and rename the branch to `proposal/<slug>`.
- Update the Spine's "Validation decision" section with your decision and notes.
- Remove the `awaiting-validation` label, add `drafting`.
- Engage full CI (zone-aware plugins will tighten on the new branch name).
- Continue with the `/propose` workflow from step 5 (self-review with `code-review`
  plugin if installed) onward.

#### If Extract or Rewrite:

- Create a new branch off `main`: `proposal/<slug>`.
- Copy the Spine to the new branch and add a "Carry-over notes" section under
  "Validation decision" describing what to preserve (Extract) or noting the
  implementation is fully disposable (Rewrite).
- Close the handoff PR with a comment linking the new one. **Do not delete the
  handoff source branch yet** — let it auto-expire so the PO can reference it.
- Open a new draft PR for the new branch.
- Apply `drafting`, `proposal`, `tier-{0,1,2}`, `product:<slug>`, `soc2` if
  applicable.
- Run the `/propose` workflow from step 5 onward.
- Post a chat message to the PO: *"Decided to [extract/rewrite] this — here's
  why: [3 sentences]. New PR is #N, I'll have a preview for you in [time
  estimate]. The original MVP stays available for reference."*

#### If Reject:

- Update the Spine's "Validation decision" section with `Reject` and your
  reasoning — at least 3 sentences explaining which framing assumption was wrong
  and what would change the answer.
- Close the handoff PR with a respectful comment that quotes HANDOFF.md §15 (rationale) and §13 (open questions).
- **Do not delete** the handoff source branch — let it auto-expire. The PO may want
  to look at it.
- Post a chat message to the PO that includes:
  - The reasoning (paraphrased from the Spine and HANDOFF.md, not just "rejected")
  - What new information or framing would change the decision
  - An invitation to iterate on the MVP locally if they want to take another swing

### 7. Hand off

Whatever the decision, post a single short message in the PR summarizing what
happens next so the PO and any watchers know without scrolling.

## Things to avoid

- **Do not read the entire branch line-by-line.** The Spine + bundle exist so you
  don't have to. If you find yourself reading every file, the Spine is incomplete
  — push back on `spine-writer` or the PO before deciding.
- **Do not silently extend the prototype.** Either Harden (import to `proposal/*`)
  or open a fresh branch. The handoff source branch's name is part of its identity.
- **Do not Harden something just because it works.** "Works in the local MVP sandbox with fake
  data" is the floor, not the ceiling.
- **Do not Reject without giving the PO actionable feedback.** A bare "rejected"
  is a process failure on your side, not theirs. Consider `Continue exploring` if
  the MVP needs more work before engineering can render a verdict.
- **Do not change the decision after confirming it in chat without explicitly
  saying so.** The decision is a public commitment.
- **Do not promote any feature flag** as part of validation. Promotion is a
  separate human-gated step via `/promote`.
- **Do not skip the constitution check.** Even a beautifully-built prototype that
  violates a "Claude must not do" rule is a Reject.

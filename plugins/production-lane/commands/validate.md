---
description: Engineer validation gate for a packaged prototype. Read the Spine, make one of four decisions — Keep, Refactor, Redesign, Reject.
argument-hint: <PR number or branch name>
---

# /validate

A PO ran `/package-handoff` and a draft PR is sitting in the `awaiting-validation`
queue. **Your job is to make one decision** — not to read the whole branch. The
preview already proves it works; the question is whether the implied architecture
is something the team will still want to own in a year.

## Surface and connector requirements

Works on **Claude.ai (Chat), Claude Cowork, and Claude Code**. The GitHub
connector is **required** — validation is a public state change (rename branch,
move labels, mutate Project card) and cannot happen without it. Refuse cleanly
if the connector is missing.

Connector capabilities used:

- **Pull requests** — read the PR, the Spine, and the Handoff Bundle; rename
  the branch on Keep; close on Reject; comment on every decision.
- **Branches** — rename `prototype/<slug>` → `proposal/<slug>` on Keep; create
  fresh `proposal/<slug>` off main on Refactor/Redesign.
- **Projects (v2)** — advance the card to the post-validation Status (`drafting`
  for Keep/Refactor/Redesign, `rejected` for Reject); fill in `Validation
  decision` and `Decided by` fields.
- **Labels** — drop `awaiting-validation`, apply `drafting` (or close).
- **Comments** — post the decision rationale in the PR thread.
- **Repo contents** — update the Spine's "Validation decision" section and
  (on Refactor/Redesign) carry the §10 *"What should NOT be reused"* notes from
  the Handoff Bundle into the new branch.

The four decisions are mutually exclusive:

| Decision     | What it means                                                              | What happens next                                                                            |
| ------------ | -------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| **Keep**     | Prototype is production-shaped. Harden in place.                           | Branch is renamed `proposal/<slug>`, lane flips to production, full CI engages, `/propose` workflow continues from step 5 (self-review). |
| **Refactor** | Intent is right, implementation needs rework.                              | New `proposal/<slug>` branch off `main`. You reimplement using the Spine as the spec. The prototype branch stays around as reference and auto-expires.    |
| **Redesign** | Right problem, wrong architecture. Restart cleanly in the production lane. | Same as Refactor but with explicit notes in the Spine about what NOT to do. PO gets a polite ping with context.                                            |
| **Reject**   | Wrong problem. Send back to exploration with notes.                        | PR is closed with reasoning. PO gets a chat ping and can re-vibe with the feedback baked in. |

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
   about. Many `Refactor` decisions come from here.
3. **Surface.** New endpoints, events, schema changes. SOC2 implications live here.
4. **Intent → Success criteria.** Sanity-check that the prototype actually achieves
   them. If it doesn't, it's not Keep.
5. **UX.** Only relevant if you're considering Keep on a UI-heavy change.

### 3. Read the Handoff Bundle pre-flight

The Handoff Bundle lives at `/.workflow/handoff.md` on the branch (see
[spec §9.3](../../../docs/collaborative-ai-workflow-spec.md#93-handoff-bundle-format)).
It contains:

- **§5 New dependencies since `main`** — every package added. Look for: license conflicts, transitive bloat, anything not already on the team's approved list (see [`TECH-STACK.md`](../../../TECH-STACK.md)).
- **§6 Risky patterns detected** — anything in the diff that doesn't match existing patterns, plus plugin-pack warnings. If everything's novel, that's a Redesign smell.
- **§10 What should NOT be reused** — the prototype shortcuts (fake auth, hardcoded users, inlined config) that must not migrate to production by inertia. If this list is long, that's a Refactor signal.
- **§11 Acceptance checks** — the observable conditions the PO will verify on the production PR. These anchor product approval; do not invalidate them silently.

Plugin violations from `house-style`, `security-rails`, `spec-driven-dev`, and
`always-test` (lenient prototype mode) appear under §6. The volume here is the
single best Keep/Refactor signal.

### 4. Read the constitution

Check that the change doesn't violate the things Claude must not do (see
`CONSTITUTION.md`). If it does, that's an automatic Reject regardless of how good
the idea is.

### 5. Make the decision

Pick one of Keep / Refactor / Redesign / Reject. Surface your reasoning in chat
in 3-5 sentences. Be specific about:

- Which signal (Open Question, Assumption, novel pattern, plugin violation count)
  drove the decision.
- For Refactor / Redesign: what specifically needs to change.
- For Reject: which framing assumption was wrong, so the PO knows how to re-vibe.

**SOC2 exception:** for products marked `soc2: true`, `Keep` is unavailable. The
minimum is `Refactor`, which forces a code-review pass and second-reviewer signoff.
This is a constitution rule, not a choice.

### 6. Apply the decision

#### If Keep:

- Rename the branch: `git branch -m prototype/<slug> proposal/<slug>` and push.
- Update the Spine's "Validation decision" section with your decision and notes.
- Remove the `awaiting-validation` label, add `drafting`.
- Engage full CI (the lane-aware plugins will tighten on the new branch name).
- Continue with the `/propose` workflow from step 5 (self-review with `code-review`
  plugin if installed) onward.

#### If Refactor or Redesign:

- Create a new branch off `main`: `proposal/<slug>` (Refactor) or
  `proposal/<slug>-v2` (Redesign).
- Copy the Spine to the new branch and add a "Carry-over notes" section under
  "Validation decision" describing what to preserve and what to redo.
- Close the prototype PR with a comment linking the new one. **Do not delete the
  prototype branch yet** — let it auto-expire so the PO can reference it.
- Open a new draft PR for the new branch.
- Apply `drafting`, `proposal`, `tier-{0,1,2}`, `product:<slug>`, `soc2` if
  applicable.
- Run the `/propose` workflow from step 5 onward.
- Post a chat message to the PO: *"Decided to [refactor/redesign] this — here's
  why: [3 sentences]. New PR is #N, I'll have a preview for you in [time
  estimate]. The original prototype URL stays live for reference."*

#### If Reject:

- Update the Spine's "Validation decision" section with `Reject` and your
  reasoning — at least 3 sentences explaining which framing assumption was wrong
  and what would change the answer.
- Close the PR with a respectful comment that quotes the Spine reasoning.
- **Do not delete** the prototype branch — let it auto-expire. The PO may want
  to look at it.
- Post a chat message to the PO that includes:
  - The reasoning (paraphrased from the Spine, not just "rejected")
  - What new information or framing would change the decision
  - An invitation to re-vibe if they want to take another swing

### 7. Hand off

Whatever the decision, post a single short message in the PR summarizing what
happens next so the PO and any watchers know without scrolling.

## Things to avoid

- **Do not read the entire branch line-by-line.** The Spine + bundle exist so you
  don't have to. If you find yourself reading every file, the Spine is incomplete
  — push back on `spine-writer` or the PO before deciding.
- **Do not silently extend the prototype.** Either Keep (rename to `proposal/*`)
  or open a fresh branch. The prototype branch's name is part of its identity.
- **Do not Keep something just because it works.** "Works in the sandbox with fake
  data" is the floor, not the ceiling.
- **Do not Reject without giving the PO actionable feedback.** A bare "rejected"
  is a process failure on your side, not theirs.
- **Do not change the decision after confirming it in chat without explicitly
  saying so.** The decision is a public commitment.
- **Do not promote any feature flag** as part of validation. Promotion is a
  separate human-gated step via `/promote`.
- **Do not skip the constitution check.** Even a beautifully-built prototype that
  violates a "Claude must not do" rule is a Reject.

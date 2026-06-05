---
name: e22-build
description: Guided flow for a non-technical product owner — idea → interview → approved spec → working local app → PR for dev review, with Claude driving all tooling. Use when a non-developer wants to build or prototype an app idea, types /e22-build, /e22-idea, or /e22-prototype, or resumes an in-progress PO build (the repo has /spec/BUILD-STATUS.md).
---

# Build a working app from a PO's idea

This is the PO-facing path through the standard E22 Greenfield flow
(`Spec workflow` rules): interview → spec → PO approval → build → demo → PR.
The PO needs only **Claude Code and Docker Desktop** installed; you drive all
other tooling yourself. Speak plainly throughout — no git/stack jargon (see the
"Who you are working with" rule).

Set expectations up front, in plain language: *"I'll ask you questions, write
down what we agree, you approve it, then I build and run the app on your
computer. You don't need to read code or run commands. A developer reviews
everything before it becomes the official version."*

**Standards are not softened in this flow.** The result merges to `main` as v0
only after a dev approves the PR, so it must meet the org standards from the
start: tests, `contract.md` per feature, Definition of Done, high-risk handling.

**Flow state lives in `/spec/BUILD-STATUS.md`, not in the conversation.** Copy
`${CLAUDE_PLUGIN_ROOT}/templates/spec/build-status.md` there when you first
create `/spec` (step 2), and update + commit it at **every step transition**:
current step, per-feature progress, handoff readiness. Sessions end; the file
is how the next one picks up. **Resuming:** if `/spec/BUILD-STATUS.md` already
exists, read it (and the `intent.md` statuses) first and continue from the
recorded step — don't restart the interview or re-ask settled questions.

## Steps

1. **Fresh fork? Set it up yourself (PO-adapted `/e22-init`).** If template
   placeholders remain, run the `e22-init` flow but adapted to a PO:
   - Ask only for the **product name** and a **one-line description**. Set
     Mode = Greenfield, PO = this user's GitHub handle, Devs = "to be assigned
     at review". Keep the **E22 default stack** — no override interview; the
     defaults exist for exactly this case.
   - Drive the toolchain yourself: install mise if missing (e.g.
     `brew install mise` on macOS), run `mise install`, and verify the
     `mise.lock` files gained real `[[tools.*]]` entries (see `/e22-init`
     step 4). Confirm Docker Desktop is running; help start it if not.
2. **Interview → product spec.** Follow Greenfield step 1 of the spec-framework
   reference (`${CLAUDE_PLUGIN_ROOT}/templates/reference/spec-framework.md`):
   ask plain-language questions to fill `spec/vision.md`,
   `spec/users.md`, and `spec/glossary.md`. Ask, don't invent; ambiguity goes
   to `/spec/SPEC-QUESTIONS.md`. If the PO has a Claude Design export, read it
   per `/e22-design-sources`. Create `/spec/BUILD-STATUS.md` from the bundled
   template now, and keep it current from here on.
3. **Draft feature intents.** For each capability the product clearly needs,
   run `/e22-spec-scaffold <id>` and fill `intent.md` from the conversation —
   including **Key concepts & data** and **Lifecycle expectations**: ask the
   PO plainly what each thing is, what it must remember, and what "delete"
   should mean (*gone forever or recoverable? for how long? what happens to
   related items?*). The PO defines these **semantics**; the schema and
   deletion mechanics derived from them are the dev's to confirm at review.
4. **PO validation gate.** Walk the PO through each `intent.md` in plain
   language ("here's what I understood — is this right?"). Check the
   **PO acceptance** boxes only on their explicit approval and note where the
   approval happened. **Do not start broad implementation before the intents
   are approved.**
5. **Scaffold the real app.** Replace the starter `apps/web` with the default
   stack (Next.js + TypeScript + Tailwind; PostgreSQL via `compose.yaml`) per
   `/e22-init` step 5. Generate and commit `pnpm-lock.yaml` (lockfile
   discipline). Draft the initial stack ADR yourself via `/e22-adr` — the PO
   approves intent, not ADR prose.
6. **Build feature by feature.** For each approved intent: write `contract.md`,
   implement under `/apps` + `/packages`, and write tests in the same unit of
   work (Definition of Done). Commit coherent units without asking
   (Commit-autonomy rule) on a `feat/*` branch.
7. **Respect the PO-mode guardrails.**
   - **Never deploy** (`pnpm deploy:*`), **never touch `/infra`**, and
     **never use real secrets or real third-party accounts** — generate
     local-only `.env` values.
   - Everything else may be **built for real**: a Greenfield build is
     pre-production (High-risk rule's relaxation), so the data model,
     soft-delete with a visible restore, and library-backed local sign-in are
     fair game. Record every high-risk choice in the feature's `contract.md`
     (marked `proposed — dev confirms at review`) and open questions in
     `/spec/SPEC-QUESTIONS.md`.
   - Anything that only matters against real users or real data — hard
     deletes, retention/cleanup jobs, real payment flows, production auth
     config — gets the *minimum* needed to demo, clearly marked. Tell the PO
     plainly, e.g. *"sign-in works on your computer; a developer hardens it
     before real users touch it."*
8. **Run it and demo it.** `mise run dev:setup`, then `pnpm dev` — making sure
   `.env` exists with the base variables (Stack rule). Give the PO the
   localhost URL and a plain-language walkthrough of what to click. Iterate
   with them; spec changes from feedback update the relevant `intent.md` /
   `contract.md`. **Stay in this loop — do not propose handoff from here.**
   Handoff has its own gate (step 9), and the PO may take days of real use to
   get there, possibly across many sessions.
9. **PO demo-validation gate.** Handoff is *pulled by the PO, not pushed by
   you*. Your own judgment that the app is done — even the Definition of Done
   holding — never opens this gate; it is a precondition, not the trigger.
   Once the PO has actually used the running app and their step-8 feedback is
   incorporated, you may ask plainly: *"Does this do everything you wanted?
   Anything missing before a developer takes over?"* Only on their explicit
   yes: check **PO validated the working demo** in each `intent.md`, set its
   Status to `validated`, and mark the gate passed in `/spec/BUILD-STATUS.md`
   (with where the confirmation happened). If the PO says "it's done" or
   "ready for the developer" unprompted, that is the gate — record it the
   same way.
10. **Hand off via the PR.** When the demo-validation gate has passed and the
    Definition of Done holds, propose opening the PR (it waits for
    confirmation — Commit-autonomy rule). The PR
    description is the dev's productionization brief; include:
    - that this is a **PO-built v0 via `/e22-build`**;
    - links to the approved (and demo-validated) `intent.md` files;
    - the list of **built-for-real high-risk choices** (marked `proposed` in
      the contracts) and **remaining stubs** — especially auth;
    - open items from `/spec/SPEC-QUESTIONS.md`.

    Link the PR in `/spec/BUILD-STATUS.md`. The dev PR review is the
    unchanged gate: it merges to `main` as v0 only with a dev's approval.

## When not to use this

A developer driving a Greenfield product doesn't need this skill — follow the
Greenfield steps in the Spec-workflow rules directly.

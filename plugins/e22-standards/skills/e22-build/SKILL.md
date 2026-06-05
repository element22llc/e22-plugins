---
name: e22-build
description: Guided flow for a non-technical product owner — idea → interview → approved spec → working local app → PR for dev review, with Claude driving all tooling. Use when a non-developer wants to build or prototype an app idea, or types /e22-build, /e22-idea, or /e22-prototype.
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
   per `/e22-design-sources`.
3. **Draft feature intents.** For each capability the product clearly needs,
   run `/e22-spec-scaffold <id>` and fill `intent.md` from the conversation.
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
   - **Never deploy** (`pnpm deploy:*`) and **never touch `/infra`**.
   - **High-risk areas** (auth, secrets, migrations beyond local, billing,
     deletion) get the *minimum* needed to demo — e.g. a clearly-marked
     stubbed sign-in and freshly generated local-only `.env` secrets. Record
     every stub in the feature's `contract.md` and `/spec/SPEC-QUESTIONS.md`.
     Tell the PO plainly, e.g. *"sign-in is a placeholder until a developer
     wires it in securely."* Never wire real auth or real secrets without dev
     scoping (High-risk rule).
8. **Run it and demo it.** `mise run dev:setup`, then `pnpm dev` — making sure
   `.env` exists with the base variables (Stack rule). Give the PO the
   localhost URL and a plain-language walkthrough of what to click. Iterate
   with them; spec changes from feedback update the relevant `intent.md` /
   `contract.md`.
9. **Hand off via the PR.** When the Definition of Done holds, propose opening
   the PR (it waits for confirmation — Commit-autonomy rule). The PR
   description is the dev's productionization brief; include:
   - that this is a **PO-built v0 via `/e22-build`**;
   - links to the approved `intent.md` files;
   - the list of **stubbed/deferred high-risk items** (especially auth);
   - open items from `/spec/SPEC-QUESTIONS.md`.

   The dev PR review is the unchanged gate: it merges to `main` as v0 only
   with a dev's approval.

## When not to use this

A developer driving a Greenfield product doesn't need this skill — follow the
Greenfield steps in the Spec-workflow rules directly.

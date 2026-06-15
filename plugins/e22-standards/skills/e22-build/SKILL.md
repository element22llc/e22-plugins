---
name: e22-build
description: Guided flow for a non-technical product owner — idea → interview → approved spec → working local app → PR for dev review, with Claude driving all tooling.
when_to_use: Use when a non-developer wants to build or prototype an app idea, or to resume a PO build whose repo already has /spec/BUILD-STATUS.md.
argument-hint: "[idea or product description]"
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
current step, per-feature progress, handoff gate. Sessions end; the file
is how the next one picks up. **Resuming:** if `/spec/BUILD-STATUS.md` already
exists, your **first action** — before reading the recorded step or re-running the
interview — is to **reconcile it** against the current bundled `build-status.md`,
which may have gained sections under a later `/plugin update`. Don't eyeball it;
run the diff and act on its output:

```sh
comm -13 \
  <(grep -hE '^(#{2,3} |- \[)' spec/BUILD-STATUS.md | sed -E 's/\[[xX]\]/[ ]/' | sort -u) \
  <(grep -hE '^(#{2,3} |- \[)' "${CLAUDE_PLUGIN_ROOT}/templates/spec/build-status.md" | sed -E 's/\[[xX]\]/[ ]/' | sort -u)
```

It surfaces the `##` sections and checklist items the bundled template has that the
file lacks (it over-reports filled/reworded lines — treat it as a candidate list).
Splice in the genuinely-new ones unchecked, preserving everything already filled in;
never re-add a placeholder the dev replaced (the plugin-wide *Template reconciliation*
convention: `${CLAUDE_PLUGIN_ROOT}/templates/reference/spec-framework.md`). Then read
the `intent.md` statuses and continue from the recorded step — don't restart the
interview or re-ask settled questions. This makes new flow-state gates self-healing
on the next `/e22-build` run.

## Steps

1. **Repo not set up yet? Bootstrap it yourself (PO-adapted `/e22-init`).** If
   there is no `/spec` spine (run the plugin-driven bootstrap from the bundled
   scaffold) or template placeholders remain (legacy fork), run the `e22-init`
   flow but adapted to a PO:
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
   `spec/users.md`, and `spec/glossary.md`. Ask, don't invent; product-level
   ambiguity goes to `vision.md` → `## Open questions`. If the PO has a Claude
   Design export, read it
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
     the feature's `intent.md` → `## Open questions`.
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
    description is the dev's productionization brief. First write the durable
    brief to `/spec/PRODUCTIONIZATION.md` — the **same artifact `/e22-adopt`
    produces**, so a dev inheriting a PO-built v0 gets the same brief as one
    inheriting an adopted repo, instead of gaps that evaporate with the PR text.
    Copy `${CLAUDE_PLUGIN_ROOT}/templates/spec/productionization.md` if it doesn't
    exist yet; if it already does (resumed handoff), reconcile it against the
    bundled template first (the plugin-wide *Template reconciliation* convention).
    Capture:
    - that this is a **PO-built v0 via `/e22-build`**;
    - the **built-for-real high-risk choices** (marked `proposed` in the
      contracts) and **remaining stubs** — especially auth;
    - the gap analysis vs the Definition of Done.

    This code was written to spec under E22 standards, so dispositions trend
    **Keep/Refactor** (finish the stubs) — there's no legacy to Rewrite/Reject;
    leave the disposition column at that default. Product questions stay in the
    feature intents' `## Open questions` (and `vision.md` for product-level),
    not here.

    Then propose opening the PR (it waits for confirmation — Commit-autonomy
    rule); its description links to `/spec/PRODUCTIONIZATION.md`, the
    demo-validated `intent.md` files, and any remaining `## Open questions`
    across the feature intents / `vision.md` (run `/e22-questions` to work them
    down).
    Link the PR in `/spec/BUILD-STATUS.md`. Sync the living docs before
    proposing it: seed the app guide (`/spec/app/README.md` — how to use the
    app, workflows, roles, in the PO's plain language, from the demo-validated
    intents) and append the build to `/spec/HISTORY.md` (what was built, why,
    requested by the PO, refs to the intents and the PR). The dev PR review is
    the unchanged gate: it merges to `main` as v0 only with a dev's approval.

## Recommend the next action

After the build step, emit a `## Recommended next actions` block per
`${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md`, derived from
`/spec/BUILD-STATUS.md` and this build's state. Keep it in the PO's plain
language.

| Observed state | Category | Action / suggested command |
|---|---|---|
| Intent not yet PO-approved | Human decision required | PO reviews & approves the drafted intent (no command) |
| Build incomplete / failing locally | Blocking now | Continue the build |
| Built, not demo-validated | Human decision required | PO runs the demo and confirms it does what they meant (no command) |
| Demo-validated, PR not opened | Blocking now (next transition) | Open the PR for dev review |
| PR open, awaiting dev review | Human decision required | A dev reviews/merges the PR (no command) |
| Remaining `## Open questions` | Required before production | Work them down — `/e22-questions` |
| Merged | Complete | Optional: build the next feature |

Pick one `Current recommended action` by precedence; offer a `Suggested command`
only where one truly applies. Read-only — it recommends, the PO/dev decides.

## When not to use this

A developer driving a Greenfield product doesn't need this skill — follow the
Greenfield steps in the Spec-workflow rules directly.

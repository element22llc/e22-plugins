# `/steer:build` — steps 8-10: demo, the PO demo-validation gate, and handoff

Read this file when the feature work is built and you are ready to show the PO
something running. Steps 1-7 stay in `SKILL.md`, as do the PO-mode guardrails —
which still apply to everything below (no deploy, no `/infra`, no real secrets).

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
10. **Hand off.** The durable artifact is identical in every mode — the
    productionization brief in `/spec/PRODUCTIONIZATION.md` (below); only *how it
    reaches a dev* differs:
    - **Prototype mode, PR flow** — a single v0 PR for the whole build, its
      description carrying the brief.
    - **Prototype mode, solo trunk** — the build is already on `main`; there is
      no v0 PR. The brief is still written, and the handoff gate is
      **graduation** via `/steer:protect` (which raises the PR wall for all
      future work) when a developer joins or you head for real users.
    - **Governed mode** — each slice already shipped via `/steer:work` as its own
      issue → delivery (a PR in PR flow, or a `Closes #N` trunk commit in solo
      trunk), so there is no separate v0 PR; the brief is written once for the
      build.

    When the demo-validation gate has passed and the Definition of Done holds,
    first write the durable brief to `/spec/PRODUCTIONIZATION.md` — the **same artifact `/steer:adopt`
    produces**, so a dev inheriting a PO-built v0 gets the same brief as one
    inheriting an adopted repo, instead of gaps that evaporate with the PR text.
    Copy `${CLAUDE_PLUGIN_ROOT}/templates/spec/productionization.md` if it doesn't
    exist yet; if it already does (resumed handoff), reconcile it against the
    bundled template first (the plugin-wide *Template reconciliation* convention).
    Capture:
    - that this is a **PO-built v0 via `/steer:build`**;
    - the **built-for-real high-risk choices** (marked `proposed` in the
      contracts) and **remaining stubs** — especially auth;
    - the gap analysis vs the Definition of Done.

    This code was written to spec under the standards, so dispositions trend
    **Keep/Refactor** (finish the stubs) — there's no legacy to Rewrite/Reject;
    leave the disposition column at that default. Product questions stay in the
    feature intents' `## Open questions` (and `vision.md` for product-level),
    not here.

    Sync the living docs first: seed the app guide (`/spec/app/README.md` — how
    to use the app, workflows, roles, in the PO's plain language, from the
    demo-validated intents) and append the build to `/spec/HISTORY.md` (what was
    built, why, requested by the PO, refs to the intents and — in PR flow — the
    PR). **Then reconcile the root living docs as a handoff backstop:** confirm
    `ARCHITECTURE.md`, `DESIGN.md`, and `apps/README.md` reflect the built v0 and
    carry no leftover template placeholders — the `[e.g. Node]` stack-table cells
    and `[web]` / `[core]` map rows, the `#000000` colors and placeholder product
    name in `DESIGN.md`, the "starts empty" `apps/README.md` line. Filling these
    in step 5/6 is the rule; this is the catch-all so a stub never reaches the dev
    reviewer.

    Then hand off per the delivery mode:
    - **PR flow** — push the branch and open the v0 PR without asking, telling
      the PO plainly what was opened and that a developer's merge review is the
      gate (Commit-autonomy rule); its description links to
      `/spec/PRODUCTIONIZATION.md`, the demo-validated `intent.md` files, and any
      remaining `## Open questions` across the feature intents / `vision.md` (run
      `/steer:questions` to work them down). Link the PR in
      `/spec/BUILD-STATUS.md`. The dev PR review is the gate: it merges to `main`
      as v0 only with a dev's approval.
    - **Solo trunk** — there is no PR to open; the v0 is already on `main`. Tell
      the PO plainly the build is ready for a developer, and recommend graduating
      via `/steer:protect` (it raises the server-side PR wall and ends trunk
      mode) when a developer joins or before real users arrive. Record that
      readiness in `/spec/BUILD-STATUS.md`. The dev review at graduation is the
      gate — the standards floor (tests, contracts, Definition of Done) already
      held through the build.

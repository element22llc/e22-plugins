---
name: build
description: Guided flow for a non-technical product owner — idea → interview → approved spec → working local app → handoff for dev review, with Claude driving all tooling.
when_to_use: Use when a non-developer wants to build or prototype an app idea, or to resume a PO build whose repo already has /spec/BUILD-STATUS.md.
argument-hint: "[idea or product description]"
allowed-tools:
  - Bash(git status *)
  - Bash(git diff *)
  - Bash(git log *)
  - Bash(git show *)
  - Bash(git branch *)
  - Bash(git remote *)
  - Bash(git rev-parse *)
  - Bash(git switch *)
  - Bash(git checkout -b *)
  - Bash(git fetch *)
  - Bash(git add *)
  - Bash(git mv *)
  - Bash(git commit *)
  - Bash(mise tasks *)
  - Bash(mise install *)
  - Bash(mise lock *)
  - Bash(mise run dev *)
  - Bash(mise run dev:*)
  - Bash(mise run check *)
  - Bash(mise run ci *)
  - Bash(pnpm dev*)
---

# Build a working app from a PO's idea

This is the PO-facing path through the standard Greenfield flow
(`Spec workflow` rules): interview → spec → PO approval → build → demo → dev
handoff (a v0 PR in PR flow, or graduation off the trunk in solo trunk).
The PO personally installs only **Claude Code and Docker Desktop**, on a
supported machine — **macOS, Linux, or Windows via WSL2** (the org toolchain
assumes a POSIX shell; see the `Stack` rule). You verify and drive everything
else yourself: install the supported local toolchain (mise, then pnpm/uv, git)
where the OS permits, and handle GitHub auth for the eventual PR — never hand the
PO commands. Speak plainly throughout — no git/stack jargon (see the
"Who you are working with" rule).

Set expectations up front, in plain language: *"I'll ask you questions, write
down what we agree, you approve it, then I build and run the app on your
computer. You don't need to read code or run commands. A developer reviews
everything before it's used for real."*

**Standards are not softened in this flow.** Whatever the delivery mode, v0 must
meet the org standards from the start — tests, `contract.md` per feature,
Definition of Done, high-risk handling. In **PR flow** it reaches `main` only
after a dev approves the v0 PR; in **solo trunk** it lands on `main` directly but
stays pre-MVP until a dev reviews it at graduation (`/steer:protect`). The floor
is identical either way.

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
sh "${CLAUDE_PLUGIN_ROOT}/scripts/template-reconcile.sh" \
  spec/BUILD-STATUS.md "${CLAUDE_PLUGIN_ROOT}/templates/spec/build-status.md"
```

Splice in only the genuinely-new `##` sections and checklist items it reports
(unchecked), preserving everything already filled in; never re-add a placeholder the
dev replaced. Full rules — the plugin-wide *Template reconciliation* convention:
`${CLAUDE_PLUGIN_ROOT}/templates/reference/SPEC-FRAMEWORK.md` §"Template
reconciliation". Then read the `intent.md` statuses and continue from the recorded
step — don't restart the interview or re-ask settled questions. This makes new
flow-state gates self-healing on the next `/steer:build` run.

## Steps

1. **Repo not set up yet? Bootstrap it yourself (PO-adapted `/steer:init`).** If
   there is no `/spec` spine (run the plugin-driven bootstrap from the bundled
   scaffold) or template placeholders remain (legacy fork), run the `init`
   flow but adapted to a PO:
   - Ask only for the **product name** and a **one-line description**. Set
     Mode = Greenfield, PO = this user's GitHub handle. Keep the **default
     stack** — no override interview; the defaults exist for exactly this case.
   - **Settle the delivery mode — ask, don't assume a reviewer.** This flow does
     not presuppose a separate developer. Ask the PO plainly, in plain language,
     whether a developer will review this build or they're the only person on it
     for now:
     - **A developer will review it (or one will be assigned later)** — keep the
       `feat/*` + PR default. Set Devs = the dev's handle (or `"to be assigned at
       review"`), and leave the scaffold's `## Delivery mode` section at
       `PR flow` with its `<!-- steer:delivery-mode=pr-flow -->` marker.
     - **The PO is the sole contributor, with no MVP or deploy yet** — this is
       exactly what **solo trunk (pre-MVP)** is for (Commit autonomy). Offer and
       recommend it; a one-line "yes" is enough. The build then commits straight
       to `main` — no `feat/*` branch, no v0 PR — until graduation via
       `/steer:protect` when a developer joins or you head for real users. Set
       Devs = `"none yet (solo PO)"`, write the `## Delivery mode` section to
       `solo trunk (pre-MVP)` with that graduation trigger, and set the section's
       first-line marker to `<!-- steer:delivery-mode=solo-trunk -->` (the steer
       hooks read it to relax the per-feature branch/PR; keep it in sync with the
       prose). This is the same offer `/steer:init` Path B makes — surfaced here
       because the PO never runs `init` directly.
   - Drive the toolchain yourself: run **`/steer:doctor`**, which detects and
     (with the PO's yes) installs mise, runs `mise install`, and checks Docker
     Desktop. Then run `mise lock --platform linux-x64,macos-arm64` so the lock
     carries CI's `linux-x64` URLs (plain `mise install` locks only the host
     platform, breaking CI's `mise install --locked`), and verify each `mise.lock`
     gained a `platforms.linux-x64` `url` + `checksum` block (full procedure:
     `/steer:reference conventions` → "Toolchain: `latest` in config, pinned in the
     lockfile"). The PO still installs Claude Code and Docker Desktop by hand (the
     manual floor doctor can only link, not script).
2. **Interview → product spec.** Follow Greenfield step 1 of the spec-framework
   reference (`${CLAUDE_PLUGIN_ROOT}/templates/reference/SPEC-FRAMEWORK.md`):
   ask plain-language questions to fill `spec/vision.md`,
   `spec/users.md`, and `spec/glossary.md`. Ask, don't invent; product-level
   ambiguity goes to `vision.md` → `## Open questions`. If the PO has a Claude
   Design export, read it
   per `/steer:reference design-sources`. Create `/spec/BUILD-STATUS.md` from the bundled
   template now, and keep it current from here on.
3. **Draft feature intents.** For each capability the product clearly needs,
   run `/steer:spec-scaffold <id>` and fill `intent.md` from the conversation —
   including **Key concepts & data** and **Lifecycle expectations**: ask the
   PO plainly what each thing is, what it must remember, and what "delete"
   should mean (*gone forever or recoverable? for how long? what happens to
   related items?*). The PO defines these **semantics**; the schema and
   deletion mechanics derived from them are the dev's to confirm at review.
   If the PO wants to **work on a feature's spec more before building it** —
   explore edge cases, sharpen acceptance criteria, drive open questions down —
   run `/steer:spec <id>` to iterate `intent.md`/`contract.md` with them (the
   same spec-only loop, no code written). Tell them plainly they can just say
   "let's work this out more first"; you drive it, they never type the command.
4. **PO validation gate.** Walk the PO through each `intent.md` in plain
   language ("here's what I understood — is this right?"). On the PO's explicit
   approval, **delegate the transition to `/steer:spec approve
   <feature-id>`** — that mode is the single owner of `draft → approved` and
   writes the `## PO acceptance` boxes, the `> Approved by:` / `> Approved at:`
   header, the `Status:` flip, and the HISTORY entry. Do **not** edit those
   approval fields here; an explicit PO statement authorizes the delegated run,
   and the PO never types a command. **Do not start broad implementation before
   the intents are approved.**
5. **Scaffold the real app.** Replace the starter `apps/web` with the default
   stack (Next.js + TypeScript + Tailwind; PostgreSQL via `compose.yaml`) per
   `/steer:init` step 5. Generate and commit `pnpm-lock.yaml` (lockfile
   discipline). Draft the initial stack ADR yourself via `/steer:adr` — the PO
   approves intent, not ADR prose. **This is the change that establishes the
   stack and layout, so fill the root living docs in it** (Living-docs rule):
   populate `ARCHITECTURE.md` — the tech-stack table from `mise.toml` /
   `package.json` / `compose.yaml`, and the apps/packages map from the real
   layout (every `apps/*` and `packages/*` you just created) — and edit
   `apps/README.md` so it no longer claims the folder "starts empty" once a real
   app exists. These are doc upkeep applying a decision already made, not new
   decisions — no PO sign-off, and the PO never sees them (they're for the dev
   reviewer).
6. **Build feature by feature.** Who *owns implementation* depends on whether this
   repo is GitHub-adopted (`/spec/tracker.md` declares `system: github`):

   - **Prototype/local mode — the default (greenfield, no GitHub tracker yet).**
     Issue-first (rule 36) is scoped to `system: github`, so it does not apply
     here. Build the v0 yourself: for each approved intent write `contract.md`,
     implement under `/apps` + `/packages`, and write tests in the same unit of
     work (Definition of Done). Commit coherent units without asking
     (Commit-autonomy rule). **In PR flow** that's a single `feat/*` build
     branch, and the work stays local and provisional until the one v0 handoff
     PR (step 10); **in solo trunk** (chosen in step 1) commit directly to `main`
     with no branch and no v0 PR — the work is provisional on the trunk until
     graduation (step 10). Either way this keeps the PO's inner loop fast — no
     per-feature issue/branch/PR ceremony.
     **"Prototype mode" relaxes only this ceremony** (issues, per-feature
     branches/PRs, approval-gate formality) — it does **not** skip the bundled
     scaffold (step 1) or the spec spine (steps 2–4) or the real-stack app
     scaffold (step 5). A prototype that hand-rolls `package.json` / build config
     / CI instead of installing the scaffold, or that ships no `/spec`, has
     skipped bootstrap, not run it in prototype mode.

   - **Governed mode — repo already GitHub-adopted (`system: github`).**
     Issue-first applies, so implementation runs through
     **`/steer:work`**, the sole owner of
     claim → branch → implement → test → PR → transition — and of adapting that
     flow to the repo's delivery mode (in solo-trunk it commits straight to `main`
     and closes the issue from the trunk commit, no branch/PR). For each approved intent
     (or coherent delivery slice), materialize or reuse a GitHub issue via
     **`/steer:issues`** (which routes tracker I/O through
     `/steer:tracker-sync`), then hand that issue to
     `/steer:work` — **invisibly**: the PO never types a technical
     command and never needs to see an issue number. You keep the PO conversation,
     intent approval (step 4), the app scaffold (step 5), the demo (step 8), and
     the handoff framing (step 10); `work` owns execution. Do **not** branch,
     implement, or open PRs yourself in this mode, and `work` must **not**
     re-enter `/steer:build` (no recursion) — drive one slice at a time.

   In **either** mode, as you build UI seed and grow the root `DESIGN.md` from
   the visual identity you actually implement — swap the placeholder product
   name and `#000000` colors for the product's real name and tokens, and
   promote a token or component once the same choice recurs in 3+ places
   (`Design sources` rule). Don't leave the stub for the dev reviewer.
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
    - **PR flow** — propose opening the v0 PR (it waits for confirmation —
      Commit-autonomy rule); its description links to
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
| Demo-validated, PR flow, PR not opened | Blocking now (next transition) | Open the v0 PR for dev review |
| Demo-validated, solo trunk (v0 on `main`) | Human decision required | Ready for a developer — graduate via `/steer:protect` when one joins / before real users |
| PR open, awaiting dev review | Human decision required | A dev reviews/merges the PR (no command) |
| Remaining `## Open questions` | Required before initial production | Work them down — `/steer:questions` |
| Merged (PR flow) / graduated (solo trunk) | Complete | Optional: build the next feature |

Pick one `Current recommended action` by precedence; offer a `Suggested command`
only where one truly applies. Read-only — it recommends, the PO/dev decides.

## When not to use this

A developer driving a Greenfield product doesn't need this skill — follow the
Greenfield steps in the Spec-workflow rules directly.

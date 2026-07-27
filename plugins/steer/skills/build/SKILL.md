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
  - Bash(git push)
  - Bash(git push -u origin *)
  - Bash(git push origin *)
  - Bash(gh pr create *)
  - Bash(mise tasks *)
  - Bash(mise install *)
  - Bash(mise lock *)
  - Bash(mise run dev *)
  - Bash(mise run dev:*)
  - Bash(mise run check *)
  - Bash(mise run ci *)
  - Bash(pnpm dev*)
  - Bash(sh *scripts/template-reconcile.sh*)
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

## PO-mode guardrails

These hold for the whole build, at every step.

- **Never deploy or promote to any environment**, **never touch `/infra`**, and
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

## Steps

1. **Repo not set up yet? Bootstrap it yourself (PO-adapted `/steer:init`).**
   **Brownfield guard first:** if the repo already has substantial working code but
   no `/spec` spine, this is *adoption*, not a fresh build — say so in plain
   language and run **`/steer:adopt`** (you still drive it; the PO just answers the
   product questions). Don't greenfield-bootstrap over a working app. Otherwise — if
   there is no `/spec` spine (run the plugin-driven bootstrap from the bundled
   scaffold) or template placeholders remain (legacy fork) — run the `init`
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
     gained a `platforms.linux-x64` `url` + `checksum` block (canonical procedure
     + rationale: `/steer:reference conventions` → "Toolchain: `latest` in
     config, pinned in the lockfile"). The PO still installs Claude Code and Docker Desktop by hand (the
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
5. **Scaffold the real app**, then **6. build feature by feature.** These two
   steps carry the implementation procedure — the default stack and Dockerfile,
   the living-docs fill, and the prototype-mode vs governed-mode split that
   decides whether you implement directly or hand each slice to `/steer:work`.
   Read them in
   [`IMPLEMENTATION.md`](${CLAUDE_PLUGIN_ROOT}/skills/build/IMPLEMENTATION.md)
   before executing. The PO-mode guardrails below apply to both.

7. **Respect the PO-mode guardrails** stated at the top of this skill — they
   are not a step you pass, they hold throughout.
8-10. **Demo it, take the PO demo-validation gate, then hand off.** Handoff is
   *pulled by the PO, not pushed by you* — stay in the build/iterate loop until
   they ask. The demo procedure, the gate's exact wording, and the handoff
   artifact (identical in every mode) are in
   [`HANDOFF.md`](${CLAUDE_PLUGIN_ROOT}/skills/build/HANDOFF.md). **Do not
   propose handoff from the build loop** — read this file only once the PO has
   asked to wrap up.

## Recommend the next action

After the build step, emit a `## Recommended next actions` block per
`${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md`, derived from
`/spec/BUILD-STATUS.md` and this build's state. Keep it in the PO's plain
language.

| Observed state | Category | Action / suggested command |
|---|---|---|
| Intent not yet PO-approved | Human decision required | PO reviews & approves the drafted intent — offer the gate prompt, then `/steer:spec approve` |
| Build incomplete / failing locally | Blocking now | Continue the build |
| Built, not demo-validated | Human decision required | PO runs the demo and confirms it does what they meant (no command) |
| Demo-validated, PR flow, PR not opened | Blocking now (next transition) | Push the branch and open the v0 PR for dev review |
| Demo-validated, solo trunk (v0 on `main`) | Human decision required | Ready for a developer — graduate via `/steer:protect` when one joins / before real users |
| PR open, awaiting dev review | Human decision required | A dev reviews/merges the PR (no command) |
| Remaining `## Open questions` | Required before initial production | Work them down — `/steer:questions` |
| Merged (PR flow) / graduated (solo trunk) | Complete | Optional: build the next feature |

Pick one `Current recommended action` by precedence; offer a `Suggested command`
only where one truly applies. Read-only — it recommends, the PO/dev decides.

## When not to use this

A developer driving a Greenfield product doesn't need this skill — follow the
Greenfield steps in the Spec-workflow rules directly.

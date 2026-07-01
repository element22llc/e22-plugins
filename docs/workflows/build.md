# `/steer:build`

A guided flow for a **non-technical product owner**: idea → interview → approved
spec → working local app → hand-off for dev review, with Claude driving all
tooling.

!!! info "When to use"
    Use when a non-developer wants to build or prototype an app idea, or to
    resume a PO build whose repo already has `/spec/BUILD-STATUS.md`.

**Argument hint:** `[idea or product description]`

## Flow

```mermaid
flowchart LR
    IDEA[Idea] --> INTERVIEW[Interview the PO]
    INTERVIEW --> SPEC[Approved spec]
    SPEC --> APP[Working local app]
    APP --> HANDOFF[Hand-off for dev review]
```

## The PO happy path

You bring the idea and the judgement; Claude drives every tool. The whole loop is
five plain-language steps — you never type an issue, spec, or work command:

1. **Describe your idea.** In plain language: *"I want an app that lets the team
   log client visits and see them on a weekly calendar."* Run
   `/steer:build <your idea>`, or just say it — the always-on router rule sends it
   to the right skill.
2. **Claude interviews you and routes the work.** It asks the questions it needs
   (who uses it, what matters, what's out of scope), turns your answers into a
   spec, and pauses for you to **approve** before any code is written. Behind the
   scenes it handles the issue, the spec, and the work items for you.
3. **Preview it locally.** Claude builds a working local app and tells you how to
   run it. You click around and react in plain language — *"the date filter
   should default to this week"* — and it iterates.
4. **Hand off for review.** When you're happy, the build hands off for developer
   review. If a developer will review it, that hand-off is a **PR** — a developer
   is the human at the merge gate. Claude asks which applies at the very start:
   if you're the **sole contributor with no developer yet**, it recommends **solo
   trunk** instead — the work lives on the main line as you go, with no PR, and
   developer review comes later, when one joins or you head for real users (Claude
   graduates the repo then).
5. **Ship.** In PR flow the change merges once the developer approves; in solo
   trunk it's already on the main line and graduates when a developer takes over.
   Either way you've shipped without touching the tracker or the code.

If a session is interrupted, you don't have to remember anything: as long as a
`/spec/BUILD-STATUS.md` is present with work still in flight, the SessionStart
hook steers the next session straight back into `/steer:build`, resuming from
where you left off. (Running `/steer:build` yourself works too.) The flow stops
resuming once the build is handed off — every box in its handoff gate checked.

!!! tip "Work on the spec before building"
    At any point you can ask to *"work on what this should do first"* — Claude
    runs `/steer:spec` to think a feature through, sharpen acceptance criteria,
    and drive open questions down, all **without writing code**. The build flow
    uses the same spec loop internally at the intent stage. See
    [Spec](spec.md).

!!! warning "\"Prototype\" is not an escape hatch"
    Saying *"just a prototype"*, *"quick"*, or *"throwaway"* relaxes only the
    **ceremony** — a lighter interview, no per-feature issue/branch/PR, high-risk
    choices stubbed and marked. It does **not** skip the plugin's **bundled
    scaffold** (`mise.toml`, `compose.yaml`, CI, PR template, `.gitignore`, …) or
    the `/spec` spine. A prototype is still greenfield: it gets the scaffold (so it
    costs nothing to graduate later) and at least a minimal `/spec`. Hand-rolling
    `package.json` / build config / CI from scratch instead of installing the
    scaffold is skipped bootstrap, not prototype mode.

!!! info "Where the gates are"
    Claude commits on its own, but **approving the spec** and the **dev hand-off**
    are always human decisions — opening/merging the v0 PR in PR flow, or
    graduating off the trunk via `/steer:protect` in solo trunk. See the
    [Authorization model](../concepts/authorization-model.md).

!!! note "For the reviewing developer: prototype-mode vs. governed-mode delivery"
    In **prototype mode** (greenfield, no tracker yet) the hand-off is a single v0
    PR (a pull request — the package a developer reviews) — **unless** the PO chose
    **solo trunk** at the start (sole contributor, no
    developer): then the build commits straight to the main line with no v0 PR, and
    the hand-off is graduation via [`/steer:protect`](../reference/skills.md) when a
    developer joins. In a repo that is already GitHub-adopted (**governed mode**),
    each approved slice instead ships through [`/steer:work`](work.md) as its own
    issue → delivery — a PR in pr-flow, or a `Closes #N` trunk commit in
    [solo-trunk](../concepts/authorization-model.md) — so there is no separate v0
    PR. Either way the productionization brief still applies, and merge/deploy stay
    human-gated.

!!! note "For developers: what the dev reviewer inherits"
    A v0 hand-off is not just code. As it scaffolds the stack and builds the UI,
    `/steer:build` keeps the root project docs current — `ARCHITECTURE.md` (the
    as-built stack and apps/packages map), `DESIGN.md` (the real visual identity),
    and `apps/README.md` — and a doc-reconciliation step before the hand-off
    confirms none are left as template stubs. The
    [Living docs](../reference/configuration.md) rule makes this the same in-flight
    upkeep across `/steer:init` and [`/steer:work`](work.md).

## Relationship to other skills

- `/steer:build` is the **build** path; [`/steer:spec`](spec.md) is its
  **no-build counterpart** — spec-only, ends at an approved intent without
  writing code.
- A build in progress tracks state in `/spec/BUILD-STATUS.md`, so `/steer:build`
  can resume an interrupted session.
- Approval still records evidence and the hand-off stays **dev-gated** — Claude
  drives the tooling, but a human reviews before code reaches real users (the v0
  PR in PR flow, or graduation off the trunk in solo trunk). See the
  [Authorization model](../concepts/authorization-model.md).

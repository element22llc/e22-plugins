# Engineering Standards — Operating Manual (org standards)

Org-wide engineering standards, injected into every session by the **steer**
plugin and maintained centrally in
[`element22llc/e22-plugins`](https://github.com/element22llc/e22-plugins) — do not
copy them into a product's `CLAUDE.md`, which holds only product-specific context
(Product paragraph, stack overrides, team-learned patterns).

## You are the router

These standards ship as on-demand skills, but **the user never has to know a skill
name**. Map their plain-language goal to the owning skill and **invoke it
yourself** — don't wait for a `/steer:` command or ask them to name one.

- **Announce, then act.** Lead with one line naming what you heard and the skill
  you're starting ("→ Sounds like a new feature — I'll shape the spec first with
  `/steer:spec`."), then proceed. The heads-up lets the user redirect; it is not a
  request for permission.
- **Clarify only when genuinely unsure.** If intent is ambiguous between skills or
  too underspecified for the target to run, ask **one** compact question offering
  the 2–3 likely intents, then route.
- **Auto-continue, bounded.** When a skill finishes, surface its single best next
  action and continue automatically **only if that action is non-gated**; a gated
  step is announced, then waits for the human.
- **Never auto-cross a human gate — routing moves navigation, never authority.**
  Creating issues beyond an explicit "fix / add / implement" ask (Issue-first),
  ratifying an ADR (High-risk), and push / PR / merge / deploy / real secrets (Commit
  autonomy, High-risk) each still stop for the human. Auto-routing picks *which* skill
  runs; it never relaxes what that skill may do.
- **Respect bootstrap precedence.** On a repo with no `/spec` spine, make bootstrap the
  **first move, announced up front** (not a closing offer): route a developer or
  ambiguous feature/build intent through **`/steer:setup`**, a non-technical owner's
  idea straight to **`/steer:build`** (bootstrap-inclusive — don't degrade to
  toolchain-only). The SessionStart hook flags this. "Prototype" / "quick" /
  "throwaway" changes ceremony, **never whether scaffold and spine exist**. How and
  why: `/steer:setup` owns dispatch, Spec workflow the greenfield-vs-prototype
  ceremony, Issue-first the per-change issue even for a prototype.
- **Handle intent-switches gracefully.** A new ask mid-flow → name it and offer to
  switch or capture it (`/steer:issues capture`), never silently drop the current
  thread.

## Intent → skill

The **front doors** — the handful of skills a user picks from. Each detects context
and hands off to specialized skills as needed, so you rarely route outside this table.

| When the user is trying to… | Route to |
| --- | --- |
| get a repo onto the standards — new repo, existing-code adoption, template fork, missing prerequisites, or sync to the latest plugin | `/steer:setup` |
| build an app or feature as a non-technical owner (idea → working app) | `/steer:build` |
| think a feature through / shape acceptance criteria without building it — incl. refining the spec before a PO build | `/steer:spec` |
| absorb a new or updated spec/roadmap document a PO sent (docx/pptx/xlsx/pdf) — detect what changed vs. the last version and fold it into `/spec` | `/steer:intake` |
| start, resume, finish, or fix a specific issue ("fix #123"), or implement a change now | `/steer:work` |
| respond to a production incident — ship an emergency hotfix to a deployed system | `/steer:work --hotfix` |
| manage the backlog without implementing now — capture, triage, brainstorm, decompose, check status, or sequence into a release timeline (GitHub) | `/steer:issues` |
| audit whole-repo health and highest-leverage cleanups, incl. spec drift and root tidy-up (read-only) | `/steer:audit` |
| record a hard-to-reverse or cross-cutting decision | `/steer:adr` |
| find the single best next action across the workspace ("what now?", "I'm lost") | `/steer:next` |
| get a plain-language, shareable page of one feature — an at-a-glance view to show or hand to a stakeholder (renders `/spec`, builds nothing) | `/steer:explain` |
| browse the whole capability set — "what can steer do?", "show me the commands", not sure what to ask for (a plain-language menu, no repo state needed) | `/steer:help` |
| "protect main" / "graduate to the PR flow" (solo trunk → review) / set up or check branch protection & merge rules (GitHub) | `/steer:protect` |
| report a defect in the **steer plugin itself** upstream (not a product bug) | `/steer:report` |

**`work` vs `issues`:** implementing *now* — with or without an issue number —
routes to `/steer:work`, which find-or-creates the issue and then implements. Pure
backlog management (capture / triage / brainstorm / decompose / status, no
implementation this turn) routes to `/steer:issues`.

**Specialized skills, normally reached through a front door.** Each is directly
invocable, but a front door auto-routes to it:

- **`/steer:setup`** hands off to `/steer:init` (greenfield), `/steer:adopt`
  (existing code), or `/steer:sync` (steady-state) — which invoke `/steer:doctor`
  when prerequisites are missing.
- **`/steer:audit`** runs `code` (whole-repo health, the default) and `spec`
  (as-built `/spec` vs tracker intent), and hands off to `/steer:tidy`.
- **`/steer:issues`** and `/steer:spec` hand off to `/steer:questions`; `/steer:issues`
  hands off to `/steer:roadmap`.
- GitHub reads/writes route through the internal `/steer:tracker-sync` gateway; feature
  specs are instantiated by the internal `/steer:spec-scaffold` — never call these
  directly.
- Full reference prose (`/steer:reference [conventions|traceability|design-sources|context-hygiene|architecture-diagrams]`)
  is materialized into `/spec/reference/` once a repo is set up; run it directly only
  on web chat or when asked for the deep dive.

On the **Claude Desktop Chat tab or claude.ai web chat** (where this manual is *not*
auto-injected), run `/steer:standards` at session start to load these rules.

When you pick or change stack pieces, verify current stable versions in-session
(run `/steer:reference conventions`) — don't trust training-data memory.

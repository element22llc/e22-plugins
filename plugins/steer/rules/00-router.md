# Engineering Standards — Operating Manual (org standards)

Org-wide standards, injected every session by the **steer** plugin and
maintained centrally in `element22llc/e22-plugins` — never copy them into a
product's `CLAUDE.md`, which holds only product-specific context.

**Be concise by default** — in chat, in code, and in every artifact you write.

## You are the router

**The user never has to know a skill name**: map their plain-language goal to
the owning skill, using the skill listing, and **invoke it yourself**.

- **Announce, then act** — one line naming what you heard and the skill you're
  starting, then proceed. A heads-up, not a request for permission. Ask **one**
  compact question only when intent is genuinely ambiguous.
- **Auto-continue, bounded** — when a skill finishes, continue into its single
  best next action only if non-gated; a gated step is announced, then waits.
- **Routing moves navigation, never authority.** The human gates are unchanged:
  issue creation beyond an explicit "fix / add / implement" ask, ADR
  ratification, and merge / deploy / real secrets. Pushing a branch and opening
  a PR are **not** gates — the gate is the PR **merge**. A gate whose decider is
  present is answered in-session.
- **Bootstrap precedence** — on a repo with no `/spec` spine, bootstrap is the
  **first move, announced up front**: a developer or ambiguous feature intent →
  **`/steer:setup`**; a non-technical owner's idea → **`/steer:build`**. Only a
  purely spec-thinking intent → **`/steer:spec`**. "Prototype" / "quick" changes
  ceremony, **never whether scaffold and spine exist before code**.
- **Intent-switches** — a new ask mid-flow: name it and offer to switch or
  capture it (`/steer:issues capture`), never silently drop the current thread.

**`work` vs `issues`:** to implement a change now — with or without an issue
number — route to `/steer:work`, which find-or-creates the issue. Pure backlog
management with no implementation this turn routes to `/steer:issues`.

`/steer:tracker-sync` and `/steer:spec-scaffold` are internal gateways, not
front doors. Reference prose loads on demand via `/steer:reference`; where
nothing is auto-injected (Desktop chat, claude.ai web), run `/steer:standards`.

**The rest of the ruleset is delivered per-file**, as `.claude/rules/*.md`
installed by `/steer:init` / `/steer:adopt` and scoped with `paths:` — each
loads when you touch the files it governs. If they are absent the repo is
unmanaged: say so and offer `/steer:setup`.

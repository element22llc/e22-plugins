# What moved where (7.0)

7.0 cut the skills a user can type to **seven front doors** - `/steer:setup`,
`/steer:spec`, `/steer:work`, `/steer:audit`, `/steer:status`, `/steer:next`,
`/steer:build` - plus `/steer:standards`, the fallback for surfaces where no hook
injects the rules.

Nothing was removed. Every skill still exists and still does the same work; it is
now entered as a **mode** of the door that owns its area. The point is that you no
longer have to know which of twenty-odd names to reach for - and in practice you
rarely type any of them, because
[the model routes your plain-language ask](../concepts/sdlc.md) to the right door
itself.

## The renames

| Before 7.0 | Now |
|---|---|
| `/steer:init` | `/steer:setup init` |
| `/steer:adopt` | `/steer:setup adopt` |
| `/steer:sync` | `/steer:setup sync` |
| `/steer:doctor` | `/steer:setup doctor` |
| `/steer:protect` | `/steer:setup protect` |
| `/steer:questions` | `/steer:spec questions` |
| `/steer:adr` | `/steer:spec adr` |
| `/steer:intake` | `/steer:spec intake` |
| `/steer:roadmap` | `/steer:spec roadmap` |
| `/steer:issues` | `/steer:work issues` |
| `/steer:tidy` | `/steer:work tidy` |
| `/steer:help` | `/steer:next capabilities` |
| `/steer:explain <id>` | `/steer:status feature <id>` |

Arguments carry through unchanged - `/steer:adr accept 3` becomes
`/steer:spec adr accept 3`, `/steer:sync --check` becomes
`/steer:setup sync --check`.

## What did not change

`/steer:reference`, `/steer:report` and `/steer:loop` also stopped being typable,
but **their invocation strings are the same**. No front door absorbed them: the
model reaches them from an always-on rule, so a mention in your `CLAUDE.md` or
README is still correct as written. Ask for what you want ("load the polyrepo
reference", "report this steer bug") rather than typing the name.

`/steer:loop` additionally requires the automation opt-in in `policy/` before it
will scaffold anything.

## Migrating a repo

Run **`/steer:setup sync`**. Its ledger step rewrites the old invocations
everywhere they were materialized - `CLAUDE.md`, `README.md`, the PR template,
`spec/tracker.md`, feature `intent.md` files, `mise.toml`, `policy/*.yml` - and
shows you the diff before writing. It leaves append-only records alone
(`spec/history/`, ADRs, audit reports), where a past `/steer:adopt` is a true
account of what was run.

The same sync re-copies the generated Copilot and `.agents/skills/` surfaces, so a
Copilot teammate picks up the new `/steer-setup` prompt set in the same pass.

!!! tip "You do not have to migrate to keep working"
    Old invocations stop resolving, but the *skills* are reachable the whole time -
    describe what you want and the model routes it. Sync when convenient; nothing
    breaks while you wait.

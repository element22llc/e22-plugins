# `/steer-work` - the closing `## Recommended next actions` block

Read this file at the end of every `/steer-work` invocation, when you are ready
to emit the handoff block. It carries only this skill's **domain mapping**; the
shared categories, precedence and output format stay in
`https://raw.githubusercontent.com/element22llc/e22-plugins/main/plugins/steer/templates/reference/NEXT-ACTIONS.md`, and the guardrails,
authorization boundary and completion semantics stay in `SKILL.md`.

## Recommend the next action

End every invocation with a `## Recommended next actions - /steer-work` block
(with the mode where one ran - `/steer-work promote`) per
`https://raw.githubusercontent.com/element22llc/e22-plugins/main/plugins/steer/templates/reference/NEXT-ACTIONS.md`. Per the **locality
rule**, consider only this issue, its branch, PR, criteria, validation, and any
blocker directly hit - not the wider workspace. A `queue` run's locality is its
list of issues. Map execution state to actions
without redefining the subcommands in `SKILL.md`:

| State | Category | Action / suggested command |
|---|---|---|
| Acceptance criteria not yet met | Blocking now (next transition) | Continue - `/steer-work resume #N` |
| Required validation failing | Blocking now | Fix failures, then `/steer-work finish #N` |
| Implemented, PR not opened | Blocking now (next transition) | `/steer-work finish #N` |
| Draft PR open, in `validate` | Human decision required | Its author reads the PR, then marks it ready, which runs CI (no command - a draft's skipped checks are not green) |
| Ready PR, CI running | Blocking now | Watch to conclusion - `gh pr checks --watch` (detached: the harness `/loop` over `gh pr checks`) |
| Ready PR, CI red | Blocking now | `/steer-work resume #N` - reproduce and fix locally until the local gates are green, then push once and re-watch |
| Ready PR, CI green, awaiting review | Human decision required | A reviewer reviews the PR - several waiting: `/steer-work review` |
| PR merged but issue still `validate` (stale) | Human decision required | **Propose** `done` once acceptance is confirmed - a merged PR is necessary, not sufficient (`/steer-work resume #N`) |
| `queue` ended, issues blocked or set aside | Blocking now | The one move recorded for the first in run order - usually `/steer-work resume #N` |
| `queue` ended, drafts open | Human decision required | Read each draft, then ready them and watch CI - `/steer-work review --mine` |
| Issue `done` | Complete | Optional: start another ready issue - `/steer-work start #N`, else `No action is currently required.` |

Choose one `Current recommended action` by precedence. The block recommends only -
it never merges, deploys, or auto-advances state.

In **solo-trunk**, read the PR rows as the trunk commit: "PR not opened" -> "change
not yet committed to `main`"; there is no draft row; "Ready PR, CI running/red" -> the same, watched via
`gh run watch` on the trunk push; there is **no awaiting-review row** - a green
trunk commit that closes the issue with acceptance accepted is `done` (deploy
still excluded).

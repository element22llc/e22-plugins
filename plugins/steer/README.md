# steer — maintainer notes

Plugin-local decisions for `plugins/steer/`. Repo-wide rules live in the root `CLAUDE.md`.
(Kept as a README, not a plugin-root `CLAUDE.md`: a plugin-root `CLAUDE.md` is flagged by
`claude plugin validate` because it is not loaded as plugin-consumer context — and these
are maintainer notes, not shipped context. Ship context to consumers via skills.)

## Manifest decisions (`.claude-plugin/plugin.json`)

- **`defaultEnabled` is intentionally omitted — do not add `defaultEnabled: false`.**
  steer is an org-wide standards plugin; its value is that *every* product session picks
  it up automatically. Claude Code's default for an installed plugin is already enabled,
  so omitting the field gives the behavior we want, and it does so on every CLI version
  rather than only on those new enough to read `defaultEnabled` (≥ 2.1.154). Generic
  "make plugins opt-in" advice does not apply here.
- **`displayName`** ("Steer — Engineering Standards") is the human label in the `/plugin`
  picker; the kebab `name: steer` stays the invocation prefix (`/steer:*`). Requires
  Claude Code ≥ 2.1.143 (satisfied by the current pin).

## Skill tool restrictions

- Nine read-only skills — `reference`, `audit`, `standards`, `next`, `doctor`,
  `explain`, `status`, `help`, `report` — never edit code, spec or tracker. What
  defines the tier is `disallowed-tools: Edit, NotebookEdit, EnterWorktree`: the
  skill cannot mutate an existing repo file, branch, or worktree. `Write` splits
  the tier. `standards`, `next`, `doctor` and `reference` disallow it too. The
  five temp-writing skills — `audit`, `explain`, `help`, `status`, `report` —
  deliberately **keep** `Write`: the artifact HTML for the four render skills
  (the Markdown fallback is printed inline, never saved), the scrubbed issue
  body for `report`. For `explain`, `help`, `status` and `report` a single
  temp-dir path is the one permitted write; `audit` is the exception — besides
  its temp artifact and triage export it may write `/spec/AUDIT-REPORT.md` and
  `/spec/DRIFT-REPORT.md` under the repo tree, on confirmation (see its own
  `Write` contract). Those limits are held **in prose**, not by frontmatter. `explain` additionally disallows
  `Bash` (it reads only local files, so it runs no shell); `status` keeps `Bash`,
  because it reads the tracker through `tracker-sync` (the `gh` read fallback
  needs shell), but writes nothing back. This does **not** make the repo
  immutable — Bash mutations remain governed by permissions/hooks. If preventive shell
  enforcement is ever needed, add a `PreToolUse` hook, not a Stop hook (Stop is detective).
- **A skill's frontmatter tool fields are scoped to the invoking turn.**
  `allowed-tools` grants without restricting (every tool stays callable; permission
  settings govern the rest), and a `disallowed-tools` restriction clears at the
  user's next message. So never disallow `Write` on the theory that it gates a
  confirmed write: it buys no safety. Writes the modes instruct (e.g.
  `/steer:audit spec`'s optional `/spec/DRIFT-REPORT.md`) happen **in-run,
  post-confirmation**. Publication to
  the tracker is a genuinely separate step because it is a different skill:
  `/steer:issues publish-*`. See `/steer:reference artifacts`.

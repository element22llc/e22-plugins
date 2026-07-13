# steer — maintainer notes

Plugin-local decisions for `plugins/steer/`. Repo-wide rules live in the root `CLAUDE.md`.
(Kept as a README, not a plugin-root `CLAUDE.md`: a plugin-root `CLAUDE.md` is flagged by
`claude plugin validate` because it is not loaded as plugin-consumer context — and these
are maintainer notes, not shipped context. Ship context to consumers via skills.)

## Manifest decisions (`.claude-plugin/plugin.json`)

- **`defaultEnabled` is intentionally omitted — do not add `defaultEnabled: false`.**
  steer is an org-wide standards plugin; its value is that *every* product session picks
  it up automatically. Claude Code's default for an installed plugin is already enabled,
  so omitting the field gives the behavior we want. (The explicit `defaultEnabled` field
  also requires Claude Code ≥ 2.1.154, newer than our validation pin
  `STEER_CLAUDE_CODE_VERSION`, so we do not rely on it.) Generic "make plugins opt-in"
  advice does not apply here.
- **`displayName`** ("Steer — Engineering Standards") is the human label in the `/plugin`
  picker; the kebab `name: steer` stays the invocation prefix (`/steer:*`). Requires
  Claude Code ≥ 2.1.143 (satisfied by the current pin).

## Skill tool restrictions

- Eight read-only skills — `reference`, `audit`, `standards`, `next`, `doctor`,
  `explain`, `status`, `help` — carry `disallowed-tools: Edit, Write, NotebookEdit, EnterWorktree`.
  Two render variants keep `Write` to save the artifact HTML they publish (a
  temp-dir file; the Markdown fallback is printed inline, never saved): `explain`
  varies to `Bash, Edit, NotebookEdit, EnterWorktree` (it reads only local files,
  so it runs no shell); `status` varies to `Edit, NotebookEdit, EnterWorktree` —
  it keeps `Bash` too, because it reads the tracker through `tracker-sync` (the
  `gh` read fallback needs shell), but holds no write grant and writes nothing back
  so the analysis cannot edit code/spec via native tools. This does **not** make the repo
  immutable — Bash mutations remain governed by permissions/hooks. If preventive shell
  enforcement is ever needed, add a `PreToolUse` hook, not a Stop hook (Stop is detective).
- The restriction clears on the next user message, so confirmed follow-up writes (e.g.
  `/steer:audit spec`'s optional `/spec/DRIFT-REPORT.md`) and publication (`/steer:issues publish-*`)
  run as their own steps after the skill returns.

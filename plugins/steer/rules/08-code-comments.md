<!-- steer:inject-when=code-project -->
## Code comments — why-only

The default is **no comment**. Names, types, and structure carry the *what*; a
comment exists only for a *why* the code cannot carry.

- **Test every comment by deleting it.** If the code still reads correctly and
  the next reader would make no wrong move, it stays deleted. It earns its line
  only when it names a non-obvious constraint — a trap, an invariant, an external
  quirk, a deliberate deviation from the standard — or is the why-comment an
  escape hatch requires (see Patterns).
- **Never:** restate the code or narrate a step; banner or divider comments; the
  task or its history (`added for #123`); what a function does when its name
  already says so; code left commented out. Doc comments (docstring / JSDoc) go
  on exported API only, one or two lines, the contract not the implementation.
- **Config is code.** `mise.toml`, `compose.yaml`, CI workflows, Dockerfiles: one
  header line saying what the file is and where the rationale lives
  (`/steer:reference conventions`) — never an inline essay. The scaffold ships
  this way; keep it so.
- **A dense file is not a licence.** Write new code to this rule even in a
  comment-heavy file; trim adjacent noise only where the change already touches
  those lines. When comments exceed a third of a file's lines the write-time
  hook flags it — fix the file, don't dismiss the notice.

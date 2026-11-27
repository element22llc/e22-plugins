<!-- steer:inject-when=code-project|advisory -->
### Code comments - why-only

The default is **no comment**. Names, types and structure carry the *what*; a
comment exists only for a *why* the code cannot carry.

- **Test every comment by deleting it.** If the code still reads correctly and
  the next reader makes no wrong move, it stays deleted. It earns its line only
  by naming a non-obvious constraint - a trap, an invariant, an external quirk,
  a deliberate deviation - or as an escape hatch's why-comment.
- **Never:** restate the code or narrate a step; banner or divider comments; the
  task or its history (`added for #123`); what a function does when its name
  says so; code left commented out. Doc comments go on exported API only, one or
  two lines, the contract not the implementation.
- **Config is code.** `mise.toml`, `compose.yaml`, CI workflows and Dockerfiles
  get one header line saying what the file is and where the rationale lives,
  never an inline essay.
- **A dense file is not a licence.** Write new code to this rule even there, and
  trim adjacent noise only where the change already touches those lines. A
  write-time notice flags a file above a fifth comment lines - advice, not a
  gate. Once every remaining comment earns its line, record that with
  `steer:allow-comments <reason>`; a bare marker suppresses nothing.

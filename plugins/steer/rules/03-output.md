## Output discipline - earn every line

Default to less, everywhere: chat, code, and committed prose. Every line must
carry something the reader cannot already see. Volume is not rigor and length is
not effort - the shortest version that stays correct and clear wins.

- **Write the least code that does the job.** Solve the task in front of you; no
  abstraction, configuration, or defensive layer for a need no one has stated.
- **Durable prose stays lean too.** Specs, ADRs, PR descriptions and docs
  inform, they do not impress - short declarative sentences, no hedging, no
  ceremony. The same discipline binds these standards.

### Responses - lead with the result, stop when it is said

Chat exists for the reader's next move, not as a log of yours.

- **Shape.** First line: the outcome, or the decision the reader must make. Then
  only what changes what they do next. A progress update is one or two
  sentences. A final report is what changed, what was verified, what is next -
  no recap of the steps taken, no restating the request, no options you did not
  take, no closing offer. **"No closing offer" binds a skill too**: none of them
  ends by inviting feedback, offering to file a report, or reassuring the reader
  they need not know a skill name.
- **Never echo machinery.** Hook notices, injected context, rule names, and
  routing deliberation are for you: act on them; name a rule only when the
  reader must go read it. Don't narrate tool calls or paste their output - quote
  the one line that matters. **One exception:** the skill that ran is named
  twice, on purpose - once when it starts (Router) and once in the handoff
  heading when it finishes. That is attribution, not machinery: without it the
  reader cannot tell what ran, or report a misroute.
- **Contract blocks stay compact.** `## Recommended next actions` is the action
  line plus at most one line per non-empty category. The end-of-session
  checklist lists open items only. A gate prompt shows the tradeoff, not the
  history.
- **Formatting is not content.** Headers only above ~300 words; bullets for
  parallel items, prose for a line of argument; bold at most the first few
  words; a table for numbers, never for one row.
- **Expand only when asked**, or when a real decision needs the context.

### Code comments - why-only

The default is **no comment**. Names, types and structure carry the *what*; a
comment exists only for a *why* the code cannot carry.

- **Test every comment by deleting it.** If the code still reads correctly and
  the next reader would make no wrong move, it stays deleted. It earns its line
  only by naming a non-obvious constraint - a trap, an invariant, an external
  quirk, a deliberate deviation - or as the why-comment an escape hatch requires.
- **Never:** restate the code or narrate a step; banner or divider comments; the
  task or its history (`added for #123`); what a function does when its name
  already says so; code left commented out. Doc comments go on exported API
  only, one or two lines, the contract not the implementation.
- **Config is code.** `mise.toml`, `compose.yaml`, CI workflows, Dockerfiles get
  one header line saying what the file is and where the rationale lives - never
  an inline essay. The scaffold ships this way; keep it so.
- **A dense file is not a licence.** Write new code to this rule even there, and
  trim adjacent noise only where the change already touches those lines. A
  write-time notice flags a file above a fifth comment lines - advice, not a
  gate. Only when every remaining comment earns its line, record that once with
  `steer:allow-comments <reason>`; a bare marker with no reason suppresses
  nothing.

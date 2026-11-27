## Output discipline - earn every line

Default to less, everywhere: chat, code, and committed prose. Every line must
carry something the reader cannot already see; the shortest version that stays
correct and clear wins. **Write the least code that does the job** - no
abstraction, configuration, or defensive layer for a need no one has stated.
Specs, ADRs, PR descriptions and docs inform, they do not impress: short
declarative sentences, no hedging, no ceremony.

### Responses - lead with the result, stop when it is said

- **Shape.** First line: the outcome, or the decision the reader must make; then
  only what changes what they do next. A progress update is one or two
  sentences. A final report is what changed, what was verified, what is next -
  no recap of the steps, no restating the request, no options you did not take,
  **no closing offer**. That binds a skill too: none ends by inviting feedback
  or reassuring the reader they need not know a skill name.
- **Never echo machinery.** Hook notices, injected context, rule names and
  routing deliberation are for you: act on them, and name a rule only when the
  reader must go read it. Don't narrate each tool call or paste its output -
  quote the one line that matters. On a long turn, give a one-line update when a
  phase ends or the plan changes. **One exception:** the skill that ran is named at
  the start and in the handoff heading - attribution, so the reader can tell
  what ran and report a misroute.
- **Formatting is not content.** Headers only above ~300 words; bullets for
  parallel items, prose for an argument; bold at most the first few words; a
  table for numbers, never for one row. **Expand only when asked**, or when a
  real decision needs the context.

### Tool calls - stay on the allowlist

In auto mode, every Bash call that no allow rule covers costs a classifier
review, and a compound command is covered only when every part is. Read, search
and edit files with Read, Grep, Glob, Edit and Write, never an inline `python3`
script or `sed -i`. Run plain commands from the session's directory: no `cd`
prefix and no `VAR=...;` preamble - write the path out instead.

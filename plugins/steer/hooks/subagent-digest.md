A subagent starts with a fresh context: none of the session's always-on standards
reach it. These are the ones that bind any agent editing or reviewing this repo.
The full ruleset is at ${CLAUDE_PLUGIN_ROOT}/rules/ - read it if you need more
than this.

- **Stay in the scope you were given.** Do the bounded task; do not widen it,
  refactor around it, or fix things you noticed on the way.
- **Report what you found instead of acting on it.** Out-of-scope bugs, risks and
  follow-ups go back to the caller in your result - that is what makes them
  trackable. Silence is how they get lost.
- **Follow the patterns already in the file and package you touch**, not a better
  pattern introduced in passing. Comments carry a non-obvious why only: never
  restate the code, narrate a step, banner a section, or leave code commented out.
- **Tests come with the change.** A behavior change updates or adds tests; a bug
  fix adds a regression test that fails before and passes after. Never delete or
  skip a failing test to get to green - fix the cause or say you could not.
- **Run the checks your change implicates** and report the real output. A check
  you did not run is not a check that passed.
- **Never commit a secret** - not in code, config, fixtures or a commit message -
  and do not read, write or transmit credentials outside what the task needs.
- **Never merge, never deploy, never push to a protected branch**, and never
  touch real secrets or `/infra`. Those are human decisions; surface the need and
  stop.
- **Say plainly what you did not do.** An honest gap is usable; an implied
  completion is not.

# `/steer-work debug` - the cause before the fix

Read this file before the first edit whenever the work is a **defect**: a
`bug`-labelled issue `start` or `resume` picked up, a failing test or check, a
red build `finish` must fix, a `--hotfix` incident, or `debug <symptom | #N |
test path>` asked directly. The guardrails, preconditions and authorization in
`SKILL.md` apply unchanged.

**No fix before a stated cause.** A patch that makes the symptom go away without
an explained mechanism is a guess, and the next symptom is its bill.

## Entry

- **`debug #N`, or a fix asked for** - the normal `start` flow; this file
  governs its implementation phase. A bug fix changes observable behavior, so it
  is never Trivial (rule `80-change-class`) and `finish` runs its code gate.
- **A symptom with no fix asked** ("why does this test fail?") - diagnosis only.
  Not issue-scoped: like `promote`, it skips Preconditions steps 1 and 3,
  changes no tracked file and ends at the findings block. Asked for the fix afterwards, Issue-first decides whether it
  needs an issue, and `start` continues with the findings in hand.
- **`--hotfix`** - the same steps, faster. An incident still gets a cause; the
  mandatory follow-up records it.

## Steps

1. **Reproduce.** Read the whole error and stack trace. Get a command whose
   output shows the failure every time; the regression test the Testing rule
   requires is the best one, so write it now if the seam exists. Not
   reproducible -> gather evidence (logs, a probe at each component boundary)
   rather than guess. Check what changed: `git log` / `git diff` since the last
   known-good state, `git bisect` when a good commit is known.
2. **Trace to the source.** Walk back from the symptom to where the bad value or
   state is first produced, and fix there, not where it surfaced. A working
   sibling path in the same codebase is the cheapest reference: list every
   difference between the two.
3. **One hypothesis at a time.** State it ("X causes Y because Z"), test it with
   the smallest change that can refute it, one variable at a time. Refuted ->
   revert that change before the next hypothesis; never stack attempts.
4. **Causal-chain gate.** Before touching product code, write the findings: the
   chain from trigger to symptom with `file:line` at each step ("somehow X leads
   to Y" is a gap, not a chain), the fix and the files it changes, where the
   regression test lives and what it would catch, and whether an existing test
   should have caught this. Revert any temporary probes first.
5. **Fix.** The regression test fails for the stated reason, then the smallest
   change at the source makes it pass, then the full local gates. Nothing rides
   along (Discovered work - bounded scope). The PR's *Notes for the reviewer*
   (solo-trunk: the commit body) carry the chain in two to four lines.

## Escalate, don't thrash

Three refuted hypotheses or three failed fixes is the Verify loop's cap: stop,
and report what was ruled out and what the repeated failure points at. A cause
that is a wrong responsibility, shared state or a broken assumption is a design
question for the dev - a `contract.md` change or an ADR via `/steer-spec` -
never a workaround around it.

**No root cause** (environmental, timing, a third party) is a finding only after
the steps above: record what was ruled out, add explicit handling, and say so in
the PR.

**Missing signal.** When the deciding fact was invisible in the existing logs,
metrics and errors, propose the always-on signal that would have shown it (a log
field, a metric, an assertion) - in the findings, not silently in the fix. A
cause that was non-obvious is what `finish`'s learning capture is for.

## Gotchas

- **A failing test that asserts intended behavior is the spec, not the bug.**
  Changing its expectation to go green is contract drift to flag (Drift gates);
  deleting or skipping it is forbidden by the Testing rule.
- **Re-running a flaky test until it passes is not a diagnosis.** Flakiness has
  a cause - ordering, shared state, time, a real race - and step 1 applies.
- **A guard at the crash site is a symptom fix** when the bad value was produced
  upstream: the null check hides it and the next consumer crashes.
- **Evidence leaks secrets.** Verbose HTTP traces, env dumps and config prints
  carry credentials: capture to a file and quote redacted excerpts (Secrets
  handling).

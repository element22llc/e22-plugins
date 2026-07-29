#!/usr/bin/env sh
# steer SessionStart hook — consolidated session-checks orchestrator.
#
# WHY THIS EXISTS
#   The startup/resume/clear matcher used to register five separate hook
#   commands (template drift, open questions, unmanaged repo, fault surfacing,
#   graduation) — six now, with worktree trust. Each registration pays the
#   harness's per-hook overhead —
#   spawn, stdin delivery, timeout envelope, output collection — at every
#   session start in every managed repo (PLAN.md Phase 1). This orchestrator
#   keeps hooks.json to a single registration and runs the same checks, in the
#   same order, itself.
#
# MECHANISM
#   Stdin (the SessionStart JSON payload) is captured once and re-fed to each
#   check unchanged, so the individual scripts keep their contract: read the
#   payload from stdin, print a markdown notice (or nothing) to stdout. Each
#   check is failure-isolated (a crash or nonzero exit never blocks the
#   remaining checks — the isolation the harness used to provide per
#   registration), stderr passes through untouched, and every non-empty
#   notice is emitted with exactly one trailing newline so notices never glue
#   together. Always exits 0: a broken check must not break session start.
#
#   The individual check scripts stay authoritative and individually testable
#   (hooks/tests/run.sh drives them directly); this file must contain NO check
#   logic of its own — only sequencing. Add a new session check by appending
#   it to the list below AND to the roster in CROSS-SURFACE.md; check_standards.py
#   parses the `for _check in` list below and fails the build if the roster omits
#   one, so the two cannot drift. The pytest latency budget
#   (tests/test_hook_latency.py) times this whole chain.
#
#   One check does more than print: check-worktree-trust.sh inherits the primary
#   checkout's `mise trust` into a linked worktree (see its header for why that
#   grants nothing new). It is gated on being in a linked worktree, so a plain
#   checkout — the common case the latency budget measures — exits before it
#   invokes anything.
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq. Invoked via an explicit `sh` prefix from hooks.json, so
#   the executable bit does not matter.

set -u

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

STEER_SESSION_INPUT="$(cat 2>/dev/null || :)"

for _check in \
	check-template-drift.sh \
	check-open-questions.sh \
	check-unmanaged-repo.sh \
	surface-faults.sh \
	check-graduation.sh \
	check-worktree-trust.sh; do
	_out="$(printf '%s' "${STEER_SESSION_INPUT}" | sh "${HERE}/${_check}")" || :
	[ -n "${_out}" ] && printf '%s\n' "${_out}"
done

exit 0

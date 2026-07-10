#!/usr/bin/env sh
# steer PreToolUse hook — trunk-push graduation gate (solo-trunk only).
#
# WHY THIS EXISTS
#   Under the two-state delivery model, delivery autonomy is keyed to branch
#   protection: a protected repo delivers through autonomous branch pushes + PRs
#   with the server-enforced merge review as the only human gate, and an
#   unprotected solo-trunk repo delivers through autonomous trunk pushes with CI
#   on push. The one repo that must NOT ride that autonomy is a solo-trunk repo
#   that has visibly outgrown pre-MVP — it ships somewhere (deploy workflow,
#   infra/ tree) or has a promotion branch, yet main is still wall-less. This
#   hook makes the graduation signals BLOCKING instead of advisory at the exact
#   moment they matter: the `git push` that would deliver to main.
#
# MECHANISM
#   Fires on Bash tool calls. Acts only when ALL of:
#     - the command is a `git push`,
#     - the repo's delivery-mode marker says solo-trunk,
#     - at least one local graduation signal is present (lib/graduation.sh —
#       the same detector the check-graduation.sh SessionStart nudge uses).
#   Then emits permissionDecision "ask" — deliberately NOT "deny": the human can
#   approve the push and keep working (they may be mid-task, or a signal may be
#   a false positive), but the push stops being silent until the repo graduates
#   via /steer:protect. Every other case is silent allow (exit 0, no output):
#   pr-flow pushes are branch pushes governed by the server wall, and a
#   signal-free solo-trunk repo keeps full trunk autonomy.
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq, fail-open on any ambiguity — never break a session. This is
#   the PreToolUse hot path for Bash, so non-push commands must exit fast: the
#   command-shape check runs before any filesystem or git work.

STEER_INPUT="$(cat)"
[ -z "${STEER_INPUT}" ] && exit 0
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/graduation.sh"

[ "$(steer_tool)" = "Bash" ] || exit 0

COMMAND="$(steer_field command)"
[ -n "${COMMAND}" ] || exit 0

# A `git push` anywhere in the command line, including `git -C <dir> push` and
# compound commands (`… && git push`). Word-anchored so `git pushx` or an
# argument merely containing "push" (e.g. a commit message) doesn't match: the
# text before `git` must be a start/separator, and `push` must end at a word
# boundary. This deliberately matches pushes embedded in && / ; / | chains.
printf '%s' "${COMMAND}" |
	grep -Eq '(^|[;&|[:space:]])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+push([[:space:]]|$)' || exit 0

CWD="$(steer_field cwd)"
[ -n "${CWD}" ] || CWD="."
ROOT="$(steer_repo_root "${CWD}")" || exit 0

# Only solo-trunk pushes are in scope: in pr-flow the push lands on a work
# branch and the server-side protection wall owns the merge gate.
[ "$(steer_delivery_mode "${ROOT}")" = "solo-trunk" ] || exit 0

SIGNALS="$(steer_graduation_signals "${ROOT}")"
[ -n "${SIGNALS}" ] || exit 0

# Sanitize + flatten the signal bullets before embedding them in the JSON reason
# (mirrors check-version-pins.sh:91). The bullets are hook-authored constants
# today, so this is hardening, not a live bug.
SAFE_SIGNALS="$(printf '%s' "${SIGNALS}" | tr -d '"\\' | tr '\n\t\r' '   ' | sed 's/  */ /g; s/^ //')"
REASON="Trunk-push graduation gate — this repo declares solo-trunk delivery but has outgrown pre-MVP:${SAFE_SIGNALS}. While these signals stand, direct-to-main pushes need a human yes. Graduate now instead: run /steer:protect (verify, then apply on the dev's confirmation) to raise the branch-protection wall — that flips the repo to pr-flow, where branch pushes and PRs are autonomous and the merge review is the only gate. Approving this prompt pushes anyway; the gate clears once the repo graduates."

# Output envelope is harness-specific, mirroring check-version-pins.sh: Claude
# PreToolUse takes the decision wrapped in hookSpecificOutput; GitHub Copilot
# CLI takes a flat decision object. Both get "ask" — this gate is a surfaced
# human decision, never a hard deny.
if [ "${STEER_HOOK_TARGET:-claude}" = "copilot" ]; then
	printf '{"permissionDecision":"ask","permissionDecisionReason":"%s"}\n' "${REASON}"
else
	printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "${REASON}"
fi
exit 0

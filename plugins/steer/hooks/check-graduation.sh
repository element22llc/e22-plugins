#!/usr/bin/env sh
# steer SessionStart hook — solo-trunk graduation detector.
#
# WHY THIS EXISTS
#   solo-trunk mode (pre-MVP greenfield: commit straight to main, no PR, branch
#   protection off) is the least-gated phase of the SDLC. It is meant to be
#   temporary, but nothing tells the owner WHEN the repo has outgrown it, so a
#   project can quietly stay ungated long after it has a deploy target or a
#   promotion branch. This hook watches for the local, offline signals that a
#   repo has grown past pre-MVP and nudges the owner to graduate via
#   /steer:protect — which raises the PR wall and flips the delivery-mode marker
#   to pr-flow. The networked signal (a second collaborator) is left to
#   /steer:audit and /steer:protect, which already use gh; this hook stays
#   offline so it adds no latency and no auth dependency to session start.
#
# MECHANISM
#   stdout becomes session `additionalContext` (same path as inject-standards.sh
#   / check-template-drift.sh). Fires ONLY when the repo declares solo-trunk AND
#   at least one local graduation signal is present; SILENT otherwise — a fresh
#   pre-MVP repo and every pr-flow repo get zero noise, and the notice clears
#   itself the moment /steer:protect graduates the repo.
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq, no process substitution. cwd comes from the SessionStart
#   payload (may be a subdir). Fail-soft: any ambiguity → stay silent. git is
#   used only for branch detection and only if present — this is SessionStart,
#   not the PreToolUse hot path, and git correctly resolves loose/packed/worktree
#   refs that a filesystem peek would miss; absent git, that one signal is skipped.

. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"

# shellcheck disable=SC2034  # consumed by steer_field (lib/json.sh) via $STEER_INPUT
STEER_INPUT="$(cat 2>/dev/null)"
CWD="$(steer_field cwd)"
[ -n "${CWD}" ] || CWD="."

ROOT="$(steer_repo_root "${CWD}")" || exit 0

# Only speak in solo-trunk mode; a pr-flow repo has already graduated.
[ "$(steer_delivery_mode "${ROOT}")" = "solo-trunk" ] || exit 0

SIGNALS=""

# Signal 1 — a prod/production promotion branch exists (local or remote-tracking).
# Its required-PR-review is the production approval gate, so its existence means
# the repo has a promotion model that solo-trunk's direct-to-main flow undercuts.
if command -v git >/dev/null 2>&1; then
	for _ref in refs/heads/prod refs/heads/production \
		refs/remotes/origin/prod refs/remotes/origin/production; do
		if git -C "${ROOT}" show-ref --verify --quiet "${_ref}" 2>/dev/null; then
			SIGNALS="${SIGNALS}
- a \`prod\`/\`production\` promotion branch exists"
			break
		fi
	done
fi

# Signal 2 — a deploy target is configured. A deploy workflow or an infra/ tree
# means the project ships somewhere; compose.yaml is NOT a signal (the scaffold
# ships it for local dev). Filesystem-only; the glob guards against no-match.
for _wf in "${ROOT}"/.github/workflows/*deploy*.yml "${ROOT}"/.github/workflows/*deploy*.yaml; do
	if [ -e "${_wf}" ]; then
		SIGNALS="${SIGNALS}
- a deploy workflow is present (\`.github/workflows/\`)"
		break
	fi
done
if [ -d "${ROOT}/infra" ]; then
	SIGNALS="${SIGNALS}
- an \`infra/\` tree is present"
fi

[ -n "${SIGNALS}" ] || exit 0

printf '<!-- steer: solo-trunk graduation signal -->\n'
printf '# Consider graduating this repo out of solo-trunk\n\n'
printf 'This repo is in **solo-trunk** mode (direct-to-`main`, no PR, branch '
printf 'protection off) — appropriate pre-MVP, but these signals suggest it has '
printf 'outgrown that:\n'
printf '%s\n' "${SIGNALS}"
printf '\nWhen the MVP works, the first deploy lands, or a second contributor '
printf 'joins, graduate to PR flow: recommend the user run `/steer:protect` to '
printf 'review branch protection and, on confirmation, raise the PR wall (it '
printf 'flips the delivery-mode marker to pr-flow and logs the graduation to '
printf '/spec/HISTORY.md). This notice clears itself once graduated.\n'

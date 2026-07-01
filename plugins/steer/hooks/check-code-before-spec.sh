#!/usr/bin/env sh
# steer PreToolUse hook — spec-before-code + scaffold-before-code nudge
# (point-of-action).
#
# WHY THIS EXISTS
#   check-unmanaged-repo.sh (SessionStart) flags a missing /spec spine once, at
#   session start. But a startup banner is easy to move past, and a repo that is
#   empty at startup can grow its first feature code mid-session — after the
#   banner already fired. This hook re-asserts the bootstrap rule at the exact
#   moment it's about to be broken: a write of code/config into a repo that is
#   not yet standards-managed.
#
#   TWO INDEPENDENT DIMENSIONS, two different cadences (issue #171):
#     • The /spec SPINE is product-dependent — it needs vision/intent decisions,
#       so nagging is wrong. The spine reminder fires AT MOST ONCE per
#       session+repo.
#     • The bundled SCAFFOLD (mise.toml, CI, PR template, compose, .gitignore) is
#       product-INDEPENDENT — it costs nothing to lay down and should not be easy
#       to skip. So the scaffold reminder is STICKY: it re-fires on each new
#       feature file while the repo still has no root mise.toml, and self-clears
#       the instant a mise.toml lands (or the spine becomes managed). The marker
#       for "scaffold present" is a root mise.toml — the one file the bundled
#       scaffold always installs and the cheapest product-independent signal.
#
# MECHANISM
#   Best-effort, non-blocking by design. Emits hookSpecificOutput.additionalContext
#   and exits 0 — the write proceeds; the model just sees the reminder. Markers
#   live in TMPDIR (never the working tree), keyed by session id + a cheap hash of
#   the repo path: one once-per-session marker for the spine dimension, and a
#   per-session list of already-nudged files for the scaffold dimension (so the
#   same file edited twice does not double-fire, but each NEW bare file does).
#   The shared classifier (lib/classify.sh) decides which writes are feature work
#   (implementation / operations / unknown → nudge) vs bootstrapping the spine
#   itself (spec / documentation / generated / lockfile → exempt).
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq required. tool_input/session_id/cwd arrive as JSON on stdin.
#   Fail-open everywhere: any ambiguity → exit 0, never block a write. Honest
#   limitation: a best-effort nudge, not a gate.

STEER_INPUT="$(cat)"
[ -z "${STEER_INPUT}" ] && exit 0
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/classify.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/spine.sh"

FILE="$(steer_target_path)"
SID="$(steer_field session_id)"
CWD="$(steer_field cwd)"
[ -n "${CWD}" ] || CWD="."

# Resolve the work-tree root (cwd may be a subdir like apps/web). Not a git work
# tree → not a project we manage. Silent.
ROOT="$(steer_repo_root "${CWD}")" || exit 0
# The plugin's own source repo → not our concern.
[ -d "${ROOT}/.claude-plugin" ] && exit 0

# Only a complete, version-stamped spec spine counts as "managed". A bare,
# foreign, or half-migrated spec/ must NOT silence the nudge. A managed spine
# implies a bootstrapped repo (init/adopt lay the scaffold too) → fully silent,
# both dimensions.
STATE="$(steer_spine_state "${ROOT}")"
[ "${STATE}" = "managed" ] && exit 0

# Need a target file (Bash calls have none → nothing to nudge on).
[ -n "${FILE}" ] || exit 0

# Shared classification → shared exempt/nudge policy.
CLASS="$(steer_classify_path "${FILE}")"
[ "$(steer_class_nudges "${CLASS}")" = "nudge" ] || exit 0

# Per-repo marker key: a cheap hash of the resolved root.
CWD_KEY="$(printf '%s' "${ROOT}" | cksum 2>/dev/null | cut -d' ' -f1)"
MARK_BASE="${TMPDIR:-/tmp}/steer-gf-nudge.${SID:-nosid}.${CWD_KEY:-0}"

# --- Spine dimension: fire AT MOST ONCE per session+repo. ---
SPINE_MARK="${MARK_BASE}.spine"
SPINE_DUE=""
if [ ! -f "${SPINE_MARK}" ]; then
	SPINE_DUE="yes"
	: >"${SPINE_MARK}" 2>/dev/null || true
fi

# --- Scaffold dimension: STICKY while no root mise.toml. ---
# Self-clears the instant a root mise.toml exists. Writing mise.toml itself is the
# act of scaffolding, so never nudge "no scaffold" on that write. Otherwise fire
# once per distinct target file (dedup via a per-session list) so each NEW bare
# file re-asserts the cost without nagging on re-edits of the same file.
SCAFFOLD_DUE=""
case "${FILE##*/}" in
mise.toml) ;; # writing the scaffold marker — do not nudge about its absence
*)
	if [ ! -f "${ROOT}/mise.toml" ]; then
		SCAFFOLD_LIST="${MARK_BASE}.scaffold"
		if ! grep -qxF -- "${FILE}" "${SCAFFOLD_LIST}" 2>/dev/null; then
			SCAFFOLD_DUE="yes"
			printf '%s\n' "${FILE}" >>"${SCAFFOLD_LIST}" 2>/dev/null || true
		fi
	fi
	;;
esac

# Nothing due this write → silent.
[ -n "${SPINE_DUE}" ] || [ -n "${SCAFFOLD_DUE}" ] || exit 0

# Sanitize the path before embedding it in JSON.
SAFE_FILE="$(printf '%s' "${FILE}" | tr -d '"\\' | tr '\n\t\r' '   ')"

# State-specific framing for the spine route: an absent spine vs a foreign spec/
# vs a damaged spine call for different first moves.
case "${STATE}" in
foreign)
	SPINE_NOTE="a spec/ directory exists but has no spec-spine marker (spec/.version) — if this repo should be standards-managed, run /steer:adopt to reverse-engineer the spine from the code; otherwise this is not an spec spine"
	;;
damaged)
	SPINE_NOTE="this repo has an incomplete spec spine (spec/.version is present but spine files are missing) — run /steer:sync to repair it"
	;;
*)
	SPINE_NOTE="this repo has no /spec spine — if you are starting this product from scratch, bootstrap first with /steer:init (greenfield path); if you are reverse-engineering pre-existing code, run /steer:adopt"
	;;
esac

# Build the message from whichever dimensions are due. The scaffold clause leads
# when present: it is the product-independent, re-asserting part.
SCAFFOLD_MSG="Scaffold check: this repo has NO root mise.toml — proceeding to write ${CLASS} (${SAFE_FILE}) leaves it with zero toolchain/CI/PR-template. The universal core — mise toolchain pinning, the /spec spine, and stack-agnostic CI hygiene — applies to EVERY managed repo regardless of stack, INCLUDING infrastructure/IaC (Ansible, Terraform, OpenTofu, Pulumi), libraries, and CLIs — not just app monorepos. Run /steer:init: it detects the repo profile (app / infra / service / library / cli) and lays the core plus the matching extras (an infra repo gets a tofu/terragrunt/ansible-flavored root mise.toml + infra CI; only app repos get package.json / compose.yaml). Do NOT skip the bootstrap because the default app scaffold looks like a poor fit — pick the profile instead; at minimum lay down a root mise.toml + CI. This scaffold reminder re-fires on each new file you write until a root mise.toml exists."

SPINE_MSG="Spec-first check: ${SPINE_NOTE}, and you are about to write ${CLASS} (${SAFE_FILE}). Bootstrap also installs the /spec spine — a user-facing feature gets /spec/features/<id>/intent.md + contract.md (run /steer:spec-scaffold) before or alongside its code, and the initial stack is recorded as an ADR (run /steer:adr). A 'prototype' or 'quick' build does NOT waive this — it relaxes spec depth and ceremony, never the scaffold or the spine. This spine reminder fires once per session; it stops once a complete /spec spine exists."

if [ -n "${SCAFFOLD_DUE}" ] && [ -n "${SPINE_DUE}" ]; then
	CTX="${SCAFFOLD_MSG} ${SPINE_MSG}"
elif [ -n "${SCAFFOLD_DUE}" ]; then
	CTX="${SCAFFOLD_MSG}"
else
	CTX="${SPINE_MSG}"
fi

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' "${CTX}"
exit 0

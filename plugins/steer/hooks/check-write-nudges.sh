#!/usr/bin/env sh
# steer PreToolUse hook — write-path point-of-action nudges (one process).
#
# WHY ONE SCRIPT
#   Both nudges fire on the same matcher (Write|Edit|MultiEdit|NotebookEdit),
#   read the same fields, resolve the same repo root, and classify the same
#   target path. They lived in separate hooks (check-code-before-spec.sh,
#   check-issue-before-mutation.sh), duplicating that setup on every editor
#   write; one process does the shared work once and runs both checks. Both
#   are best-effort, non-blocking additionalContext nudges — when both are due
#   on the same write (possible on a foreign/damaged spine whose spec/ already
#   carries a GitHub tracker.md), their messages are emitted together.
#
# NUDGE 1 — SPEC-BEFORE-CODE + SCAFFOLD-BEFORE-CODE
#   check-unmanaged-repo.sh (SessionStart) flags a missing /spec spine once, at
#   session start. But a startup banner is easy to move past, and a repo that
#   is empty at startup can grow its first feature code mid-session — after
#   the banner already fired. This nudge re-asserts the bootstrap rule at the
#   exact moment it's about to be broken: a write of code/config into a repo
#   that is not yet standards-managed.
#
#   TWO INDEPENDENT DIMENSIONS, two different cadences (issue #171):
#     • The /spec SPINE is product-dependent — it needs vision/intent
#       decisions, so nagging is wrong. The spine reminder fires AT MOST ONCE
#       per session+repo.
#     • The bundled SCAFFOLD (mise.toml, CI, PR template, compose, .gitignore)
#       is product-INDEPENDENT — it costs nothing to lay down and should not
#       be easy to skip. So the scaffold reminder is STICKY: it re-fires on
#       each new feature file while the repo still has no root mise.toml, and
#       self-clears the instant a mise.toml lands (or the spine becomes
#       managed). The marker for "scaffold present" is a root mise.toml — the
#       one file the bundled scaffold always installs and the cheapest
#       product-independent signal.
#
# NUDGE 2 — ISSUE-FIRST
#   rule 36-issue-first says: in a GitHub-adopted repo, every code/config/
#   infra/behavior change has a GitHub issue before the first repository
#   mutation. The rule is always-on prose, but prose is easy to skip
#   mid-session. This nudge re-asserts it at the moment it's about to be
#   broken: the first write of real source or operations file in a repo whose
#   /spec/tracker.md declares `system: github`. It is the lightweight safety
#   net; primary enforcement is routing (/steer:work) + the skills, which
#   actually find-or-create the issue. The nudge cannot know whether an issue
#   exists — it only reminds. Fires AT MOST ONCE per session+repo; exempt on
#   a hotfix/<n> branch (rule 62 files the issue after-the-fact by design)
#   and on /steer:sync's feat/sync branch for non-implementation writes
#   (rule 36 carve-out).
#
# MECHANISM
#   Best-effort, non-blocking by design. Emits
#   hookSpecificOutput.additionalContext and exits 0 — the write proceeds; the
#   model just sees the reminder(s). Markers live in TMPDIR (never the working
#   tree), keyed by session id + a cheap hash of the repo path. The shared
#   classifier (lib/classify.sh) decides which writes are feature work
#   (implementation / operations / unknown → nudge) vs bootstrapping the spine
#   itself (spec / documentation / generated / lockfile → exempt).
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq required. tool_input/session_id/cwd arrive as JSON on
#   stdin. Fail-open everywhere: any ambiguity → exit 0, never block a write.
#   Honest limitation: best-effort nudges, not gates.

STEER_INPUT="$(cat)"
[ -z "${STEER_INPUT}" ] && exit 0
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/classify.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/spine.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/scope.sh"

FILE="$(steer_target_path)"
SID="$(steer_field session_id)"
CWD="$(steer_field cwd)"
[ -n "${CWD}" ] || CWD="."

# Resolve the work-tree root (cwd may be a subdir like apps/web). Not a git work
# tree → not a project we manage. The plugin's own source repo → not our concern.
ROOT="$(steer_repo_root "${CWD}")" || exit 0
[ -d "${ROOT}/.claude-plugin" ] && exit 0

# Need a target file (Bash calls have none → nothing to nudge on).
[ -n "${FILE}" ] || exit 0

# Shared classification → shared exempt/nudge policy. spec/docs/generated/
# lockfile are exempt; implementation/operations/unknown nudge.
CLASS="$(steer_classify_path "${FILE}")"
[ "$(steer_class_nudges "${CLASS}")" = "nudge" ] || exit 0

# Per-repo marker key: a cheap hash of the resolved root (shared by both nudges;
# each keeps its own marker namespace).
CWD_KEY="$(printf '%s' "${ROOT}" | cksum 2>/dev/null | cut -d' ' -f1)"
SAFE_FILE="$(printf '%s' "${FILE}" | tr -d '"\\' | tr '\n\t\r' '   ')"

# ---------------------------------------------------------------------------
# Nudge 1 — spec-before-code + scaffold-before-code.
# ---------------------------------------------------------------------------
SPEC_CTX=""
# Only a complete, version-stamped spec spine counts as "managed". A bare,
# foreign, or half-migrated spec/ must NOT silence the nudge. A managed spine
# implies a bootstrapped repo (init/adopt lay the scaffold too) → skip, both
# dimensions.
STATE="$(steer_spine_state "${ROOT}")"
if [ "${STATE}" != "managed" ]; then
	MARK_BASE="${TMPDIR:-/tmp}/steer-gf-nudge.${SID:-nosid}.${CWD_KEY:-0}"

	# --- Spine dimension: fire AT MOST ONCE per session+repo. ---
	SPINE_MARK="${MARK_BASE}.spine"
	SPINE_DUE=""
	if [ ! -f "${SPINE_MARK}" ]; then
		SPINE_DUE="yes"
		: >"${SPINE_MARK}" 2>/dev/null || true
	fi

	# --- Scaffold dimension: STICKY while no root mise.toml. ---
	# Self-clears the instant a root mise.toml exists. Writing mise.toml itself
	# is the act of scaffolding, so never nudge "no scaffold" on that write.
	# Otherwise fire once per distinct target file (dedup via a per-session
	# list) so each NEW bare file re-asserts the cost without nagging on
	# re-edits of the same file.
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

	if [ -n "${SPINE_DUE}" ] || [ -n "${SCAFFOLD_DUE}" ]; then
		# State-specific framing for the spine route: an absent spine vs a
		# foreign spec/ vs a damaged spine call for different first moves.
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

		# Build the message from whichever dimensions are due. The scaffold
		# clause leads when present: it is the product-independent, re-asserting
		# part.
		SCAFFOLD_MSG="Scaffold check: this repo has NO root mise.toml — proceeding to write ${CLASS} (${SAFE_FILE}) leaves it with zero toolchain/CI/PR-template. The universal core — mise toolchain pinning, the /spec spine, and stack-agnostic CI hygiene — applies to EVERY managed repo regardless of stack, INCLUDING infrastructure/IaC (Ansible, Terraform, OpenTofu, Pulumi), libraries, and CLIs — not just app monorepos. Run /steer:init: it detects the repo profile (app / infra / service / library / cli) and lays the core plus the matching extras (an infra repo gets a tofu/terragrunt/ansible-flavored root mise.toml + infra CI; only app repos get package.json / compose.yaml). Do NOT skip the bootstrap because the default app scaffold looks like a poor fit — pick the profile instead; at minimum lay down a root mise.toml + CI. This scaffold reminder re-fires on each new file you write until a root mise.toml exists."

		SPINE_MSG="Spec-first check: ${SPINE_NOTE}, and you are about to write ${CLASS} (${SAFE_FILE}). Bootstrap also installs the /spec spine — a user-facing feature gets /spec/features/<id>/intent.md + contract.md (run /steer:spec-scaffold) before or alongside its code, and the initial stack is recorded as an ADR (run /steer:adr). A 'prototype' or 'quick' build does NOT waive this — it relaxes spec depth and ceremony, never the scaffold or the spine. This spine reminder fires once per session; it stops once a complete /spec spine exists."

		if [ -n "${SCAFFOLD_DUE}" ] && [ -n "${SPINE_DUE}" ]; then
			SPEC_CTX="${SCAFFOLD_MSG} ${SPINE_MSG}"
		elif [ -n "${SCAFFOLD_DUE}" ]; then
			SPEC_CTX="${SCAFFOLD_MSG}"
		else
			SPEC_CTX="${SPINE_MSG}"
		fi
	fi
fi

# ---------------------------------------------------------------------------
# Nudge 2 — issue-first.
# ---------------------------------------------------------------------------
ISSUE_CTX=""
# Scoped to GitHub-adopted repos: need /spec/tracker.md declaring system: github.
if steer_tracker_is_github "${ROOT}"; then
	# Fire at most once per session+repo. Check the marker BEFORE the
	# git-spawning exemptions below, so a repeat write in an already-nudged
	# session short-circuits without spawning git. Marker CREATION stays past
	# the exemptions (mark only when we actually nudge).
	MARK="${TMPDIR:-/tmp}/steer-issuefirst-nudge.${SID:-nosid}.${CWD_KEY:-0}"
	if [ ! -f "${MARK}" ]; then
		DUE="yes"

		# Hotfix fast-path exemption (rule 62): a production hotfix runs on a
		# hotfix/<n> branch and files its issue after-the-fact by design, so the
		# "issue BEFORE the first mutation" nudge would be a false positive
		# here. Stay silent at the point of action — the end-of-turn
		# reconciliation (reconcile-issue-first.sh) and rule 62 carry the
		# mandatory post-incident follow-up.
		if command -v git >/dev/null 2>&1; then
			case "$(git -C "${ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null)" in
			hotfix/*) DUE="" ;;
			esac
		fi

		# Plugin-maintenance flow exemption (rule 36 carve-out): /steer:sync runs
		# on its own feat/sync branch and writes operations-class scaffold (CI,
		# mise.toml, compose.yaml, …) — structural reconciliation against plugin
		# templates, not feature implementation. Stay silent there UNLESS the
		# write is app source (implementation-class), which sync's contract
		# forbids and is worth surfacing.
		if [ -n "${DUE}" ] && [ "${CLASS}" != "implementation" ] && command -v git >/dev/null 2>&1; then
			BRANCH="$(git -C "${ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null)"
			case "${BRANCH}" in feat/sync | feat/sync-* | feat/sync/*) DUE="" ;; esac
		fi

		if [ -n "${DUE}" ]; then
			# Mark this session+repo as nudged — only now that we actually nudge.
			: >"${MARK}" 2>/dev/null || true

			# Issue-first holds in BOTH delivery modes (the issue is the
			# audit-evidence anchor); solo-trunk relaxes only the branch/PR
			# ceremony, so its nudge keeps the issue requirement but drops the
			# /steer:work branch/PR guidance.
			MODE="$(steer_delivery_mode "${ROOT}")"
			if [ "${MODE}" = "solo-trunk" ]; then
				ISSUE_CTX="Issue-first check (solo-trunk mode): this repo's /spec/tracker.md uses GitHub Issues, and you are about to write ${CLASS} (${SAFE_FILE}). Solo-trunk relaxes the per-feature branch and PR, but issue-first still holds: every implementation-affecting mutation (code/config/infra/behavior — not spec, docs, or lockfiles) needs a GitHub issue. Reuse the issue the user named, or find-or-create one via /steer:tracker-sync (an explicit fix/implement/add request needs no confirmation to create it; see the Authorization & confirmation block in ISSUE-WORKFLOW.md). Stay on main and CLOSE the issue from your trunk commit (a 'Closes #N' trailer, or '(#N)' in the subject) — do NOT create an issue/<N> branch or open a PR. This nudge does not block the write and fires once per session."
			else
				ISSUE_CTX="Issue-first check: this repo's /spec/tracker.md uses GitHub Issues, and you are about to write ${CLASS} (${SAFE_FILE}). Every implementation-affecting mutation (code/config/infra/behavior — not spec, docs, or lockfiles) needs a GitHub issue BEFORE the first mutation — reuse the issue the user named, or find-or-create one via /steer:tracker-sync (an explicit fix/implement/add request needs no confirmation to create it; see the Authorization & confirmation block in ISSUE-WORKFLOW.md), then run implementation through /steer:work. This nudge does not block the write and fires once per session."
			fi
		fi
	fi
fi

# Nothing due this write → silent.
[ -n "${SPEC_CTX}" ] || [ -n "${ISSUE_CTX}" ] || exit 0

if [ -n "${SPEC_CTX}" ] && [ -n "${ISSUE_CTX}" ]; then
	CTX="${SPEC_CTX} ${ISSUE_CTX}"
elif [ -n "${SPEC_CTX}" ]; then
	CTX="${SPEC_CTX}"
else
	CTX="${ISSUE_CTX}"
fi

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' "${CTX}"
exit 0

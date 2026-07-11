#!/usr/bin/env sh
# steer PreToolUse hook — Bash-path point-of-action checks (one process).
#
# WHY ONE SCRIPT
#   This hook is matched on EVERY Bash call (plus the MCP issue tools) — the
#   hottest PreToolUse path. Its two checks lived in separate hooks
#   (check-trunk-push.sh, check-issue-create-contract.sh), each re-reading
#   stdin, re-sourcing the libs, and re-extracting the same JSON fields on
#   every call; one process halves that per-call overhead. Each check keeps
#   its own doc block below and bails cheaply when its command shape doesn't
#   match. Precedence: the trunk-push gate emits first — a permission ask
#   outranks a nudge, so a compound command that both pushes and creates an
#   issue surfaces the push ask (the contract guard's marker stays unset, so
#   the next raw create still nudges).
#
# CHECK 1 — TRUNK-PUSH GRADUATION GATE (Bash only)
#   Under the two-state delivery model, delivery autonomy is keyed to branch
#   protection: a protected repo delivers through autonomous branch pushes +
#   PRs with the server-enforced merge review as the only human gate, and an
#   unprotected solo-trunk repo delivers through autonomous trunk pushes with
#   CI on push. The one repo that must NOT ride that autonomy is a solo-trunk
#   repo that has visibly outgrown pre-MVP — it ships somewhere (deploy
#   workflow, infra/ tree) or has a promotion branch, yet main is still
#   wall-less. This check makes the graduation signals BLOCKING instead of
#   advisory at the exact moment they matter: the `git push` that would
#   deliver to main. It acts only when ALL of: the command is a `git push`,
#   the repo's delivery-mode marker says solo-trunk, and at least one local
#   graduation signal is present (lib/graduation.sh — the same detector the
#   check-graduation.sh SessionStart nudge uses). Then it emits
#   permissionDecision "ask" — deliberately NOT "deny": the human can approve
#   the push and keep working (they may be mid-task, or a signal may be a
#   false positive), but the push stops being silent until the repo graduates
#   via /steer:protect. Every other case is silent: pr-flow pushes are branch
#   pushes governed by the server wall, and a signal-free solo-trunk repo
#   keeps full trunk autonomy.
#
#   The ask fires ONCE per session+repo (marker in TMPDIR, like the sibling
#   point-of-action hooks): the human's answer to the first ask covers the
#   session, and re-asking on every push would stall an autonomous run on a
#   prompt nobody is watching. Repeat pushes in the same session are still
#   not silent — they carry a non-blocking additionalContext reminder that
#   the graduation signals stand (and that a declined first ask means don't
#   retry).
#
# CHECK 2 — ISSUE-CREATE CONTRACT GUARD (Bash + MCP create-issue tools)
#   rule 35-issue-tracker + the issue-workflow contract require every
#   agent-authored GitHub issue to go through /steer:tracker-sync, which
#   renders the machine-readable contract: steer markers (steer:kind /
#   steer:source / managed block), the derived source:* label, the GitHub
#   Issue Type, and native relationship edges — with find-before-create
#   dedup. A raw `gh issue create`, a `gh api … POST …/issues`, a `gh api
#   graphql` `createIssue` mutation, or an MCP create-issue tool bypasses all
#   of that: the issue lands with no markers, no source:* label, the default
#   Type, and no dependency edges — invisible to marker-based dedup, triage,
#   board, and reconcile. The issue-first nudge (in check-write-nudges.sh) is
#   deliberately blind to Bash and never fires on issue creation, so this is
#   the point-of-action reminder; /steer:issues reconcile is the
#   after-the-fact recovery path. Non-blocking: emits additionalContext and
#   the create proceeds; fires AT MOST ONCE per session+repo. Silent unless
#   /spec/tracker.md says `system: github`, and silent when the payload
#   already carries `steer:` markers — that is the contract being applied
#   (the /steer:tracker-sync path), not a bypass. Claude-only: the Copilot
#   PreToolUse envelope carries decisions, not additionalContext, so the
#   guard stays silent under STEER_HOOK_TARGET=copilot (it was never
#   registered for Copilot as a standalone hook either).
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq required, fail-open on any ambiguity — never break a
#   session. Non-matching commands must exit fast: the command-shape checks
#   run before any filesystem or git work. Honest limitation: check 2 is a
#   best-effort nudge, not a gate — it cannot tell a --body-file create from
#   an inline one, so it errs toward one harmless reminder and words itself
#   so a correct /steer:tracker-sync run can disregard it.

STEER_INPUT="$(cat)"
[ -z "${STEER_INPUT}" ] && exit 0
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/graduation.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/scope.sh"

# Use steer_tool (top-level .tool_name), NOT steer_field: steer_field prefers the
# tool_input slice, so a Bash command whose text contains `"tool_name":"…create_issue"`
# (e.g. writing a hook-test fixture) would be misread as an MCP create.
TOOL="$(steer_tool)"
CMD="$(steer_field command)"

# ---------------------------------------------------------------------------
# Check 1 — trunk-push graduation gate. Emits (ask or reminder) and exits when
# it matches; falls through to check 2 otherwise.
# ---------------------------------------------------------------------------
if [ "${TOOL}" = "Bash" ] && [ -n "${CMD}" ] &&
	# A `git push` anywhere in the command line, including `git -C <dir> push`
	# and compound commands (`… && git push`). Word-anchored so `git pushx` or
	# an argument merely containing "push" (e.g. a commit message) doesn't
	# match: the text before `git` must be a start/separator, and `push` must
	# end at a word boundary.
	printf '%s' "${CMD}" |
	grep -Eq '(^|[;&|[:space:]])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+push([[:space:]]|$)'; then

	CWD="$(steer_field cwd)"
	[ -n "${CWD}" ] || CWD="."
	if ROOT="$(steer_repo_root "${CWD}")" &&
		# Only solo-trunk pushes are in scope: in pr-flow the push lands on a
		# work branch and the server-side protection wall owns the merge gate.
		[ "$(steer_delivery_mode "${ROOT}")" = "solo-trunk" ]; then
		SIGNALS="$(steer_graduation_signals "${ROOT}")"
		if [ -n "${SIGNALS}" ]; then
			# One ask per session+repo (keyed like the sibling nudges: session id
			# + a cheap hash of the resolved root). A repeat push downgrades to a
			# non-blocking reminder: the human decision was surfaced once; keep
			# autonomy moving while keeping the push non-silent until graduation.
			SID="$(steer_field session_id)"
			CWD_KEY="$(printf '%s' "${ROOT}" | cksum 2>/dev/null | cut -d' ' -f1)"
			MARK="${TMPDIR:-/tmp}/steer-trunkpush.${SID:-nosid}.${CWD_KEY:-0}"
			if [ -f "${MARK}" ]; then
				# Copilot's PreToolUse envelope carries decisions only (no
				# additionalContext equivalent) → silent allow on the repeat.
				[ "${STEER_HOOK_TARGET:-claude}" = "copilot" ] && exit 0
				CTX="Trunk-push reminder: this solo-trunk repo still shows graduation signals and the push-approval ask already fired this session. If the human approved that push, carry on — but graduate soon via /steer:protect (verify, then apply on the dev's confirmation) so trunk pushes stop needing case-by-case yeses. If the human DECLINED it, do not retry the push; surface the graduation decision instead."
				printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' "${CTX}"
				exit 0
			fi
			: >"${MARK}" 2>/dev/null || true

			# Sanitize + flatten the signal bullets before embedding them in the
			# JSON reason (mirrors check-version-pins.sh). The bullets are
			# hook-authored constants today, so this is hardening, not a live bug.
			SAFE_SIGNALS="$(printf '%s' "${SIGNALS}" | tr -d '"\\' | tr '\n\t\r' '   ' | sed 's/  */ /g; s/^ //')"
			REASON="Trunk-push graduation gate — this repo declares solo-trunk delivery but has outgrown pre-MVP:${SAFE_SIGNALS}. While these signals stand, direct-to-main pushes need a human yes. Graduate now instead: run /steer:protect (verify, then apply on the dev's confirmation) to raise the branch-protection wall — that flips the repo to pr-flow, where branch pushes and PRs are autonomous and the merge review is the only gate. Approving this prompt pushes anyway; the gate clears once the repo graduates."

			# Output envelope is harness-specific, mirroring check-version-pins.sh:
			# Claude PreToolUse takes the decision wrapped in hookSpecificOutput;
			# GitHub Copilot CLI takes a flat decision object. Both get "ask" —
			# this gate is a surfaced human decision, never a hard deny.
			if [ "${STEER_HOOK_TARGET:-claude}" = "copilot" ]; then
				printf '{"permissionDecision":"ask","permissionDecisionReason":"%s"}\n' "${REASON}"
			else
				printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "${REASON}"
			fi
			exit 0
		fi
	fi
fi

# ---------------------------------------------------------------------------
# Check 2 — issue-create contract guard.
# ---------------------------------------------------------------------------
# Claude-only (see the doc block above).
[ "${STEER_HOOK_TARGET:-claude}" = "copilot" ] && exit 0

# --- Is this an issue-CREATE action? Cheap checks first; this hook is matched
# on every Bash call, so bail immediately on anything that is not issue
# creation. ---
PAYLOAD=""
is_create=0

case "${TOOL}" in
mcp__*)
	# An MCP create-issue tool — match by tool name (create…issue / issue…create),
	# excluding comment/label/sub-tools that merely contain "issue". The contract
	# check below uses the issue body the tool was handed.
	_tn="$(printf '%s' "${TOOL}" | tr '[:upper:]' '[:lower:]')"
	case "${_tn}" in
	*create*issue* | *issue*create* | *add*issue* | *issue*write*) is_create=1 ;;
	esac
	# The hosted GitHub MCP server renamed create_issue -> issue_write (method
	# create/update) — hence *issue*write* above. Exclude comment tools and the
	# sub-issue linker (add_sub_issue / sub_issue_write): those attach a
	# relationship to an EXISTING issue and carry no `body`, so they are not a
	# create and would otherwise fire a bodyless false nudge.
	case "${_tn}" in *comment* | *sub*issue*) is_create=0 ;; esac
	[ "${is_create}" -eq 1 ] && PAYLOAD="$(steer_field body)"
	;;
*)
	# Bash (or any command-bearing tool): inspect the command text.
	[ -n "${CMD}" ] || exit 0
	PAYLOAD="${CMD}"
	# 1) `gh issue create`
	if printf '%s' "${CMD}" | grep -Eq 'gh[[:space:]]+issue[[:space:]]+create'; then
		is_create=1
	# 2) `gh api graphql … createIssue` mutation
	elif printf '%s' "${CMD}" | grep -q 'gh api' &&
		printf '%s' "${CMD}" | grep -q 'createIssue'; then
		is_create=1
	# 3) `gh api … POST …/issues` (REST). The path must END at /issues (a trailing
	#    /issues/<n>/… is a comment/label/sub-resource, not issue creation), and a
	#    POST indicator must be present (gh api defaults to GET; -f/-F/--field/
	#    --raw-field imply POST, as does an explicit -X/--method POST).
	elif printf '%s' "${CMD}" | grep -q 'gh api' &&
		printf '%s' "${CMD}" | grep -Eq "/issues([[:space:]\"']|\$)" &&
		printf '%s' "${CMD}" | grep -Eq '(-X[[:space:]]+POST|--method[[:space:]]+POST|[[:space:]]-f[[:space:]]|[[:space:]]-F[[:space:]]|--field|--raw-field)'; then
		is_create=1
	fi
	;;
esac

[ "${is_create}" -eq 1 ] || exit 0

# --- Contract already being applied? A payload carrying steer: markers is the
# /steer:tracker-sync render path, not a bypass — stay silent. (A --body-file
# create hides the markers from us; the defensive wording below covers that.) ---
printf '%s' "${PAYLOAD}" | grep -q 'steer:' && exit 0

# --- A /steer:report self-report files UPSTREAM to the plugin's own repo, never
# the product tracker — it must NOT be routed through /steer:tracker-sync. The MCP
# and labelled `gh` paths carry a `steer:` marker caught above; this covers the
# label-less `gh` fallback. Match the `--repo` FLAG or its `-R` alias (not a bare
# mention) so a product create that only references the plugin repo in its body
# still nudges. ---
printf '%s' "${PAYLOAD}" | grep -Eq -- '(-R|--repo)[ =]element22llc/e22-plugins' && exit 0

# --- Scope: GitHub-adopted consumer repo, never the plugin's own source repo. ---
SID="$(steer_field session_id)"
CWD="$(steer_field cwd)"
[ -n "${CWD}" ] || CWD="."
ROOT="$(steer_repo_root "${CWD}")" || exit 0
[ -d "${ROOT}/.claude-plugin" ] && exit 0
steer_tracker_is_github "${ROOT}" || exit 0

# --- Fire at most once per session+repo (keyed by resolved root). ---
CWD_KEY="$(printf '%s' "${ROOT}" | cksum 2>/dev/null | cut -d' ' -f1)"
MARK="${TMPDIR:-/tmp}/steer-issuecreate-guard.${SID:-nosid}.${CWD_KEY:-0}"
[ -f "${MARK}" ] && exit 0
: >"${MARK}" 2>/dev/null || true

CTX="Issue-create contract check: this repo's /spec/tracker.md uses GitHub Issues, and you are about to open an issue with a raw create (gh issue create / gh api / an MCP create-issue tool). Route issue creation through /steer:tracker-sync create instead, so the machine-readable contract is applied — steer markers (steer:kind / steer:source / managed block), the derived source:* label, the GitHub Issue Type, and native relationship edges — with find-before-create dedup. A contract-less issue is invisible to marker-based dedup, triage, board, and /steer:issues reconcile. If you are already running /steer:tracker-sync create (its rendered body carries those markers), disregard this. This nudge does not block the create and fires once per session."

printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' "${CTX}"
exit 0

# shellcheck shell=sh
# Shared helpers for the steer hook fixture suite - POSIX sh, sourced by every
# cases/*.sh file (run them through run.sh). Each case file gets its own WORK dir
# and counters; `finish` prints its tally and sets the exit code.
#
# NOTE: pin literals are assembled at runtime via pin() so no test file's *source*
# ever contains a `name:NN` token - otherwise the plugin's own version-pin hook
# (active in the authoring session) would block writing the test.

# shellcheck disable=SC2015,SC2034
# SC2015 - the assert helpers use the `cond && ok || bad` idiom; `ok` only bumps a
#          counter and never fails, so the `|| bad` branch runs only on a real
#          assertion failure. Intentional, not the if-then-else footgun.
# SC2034 - STEER_INPUT is read by the sourced lib/json.sh functions (which ShellCheck
#          does not follow), so it reads as "unused" here though it is the input.

set -u

# $0 is the sourcing case file, cases/<name>.sh.
HERE="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
PLUGIN="$(CDPATH='' cd -- "${HERE}/../.." && pwd)"
HOOKS="${PLUGIN}/hooks"
export CLAUDE_PLUGIN_ROOT="${PLUGIN}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/steer-hooktests.XXXXXX")"
# Physical path: steer_repo_root resolves with `pwd -P`, so any assertion that
# compares a returned root against a WORK-derived path must start from the
# resolved form. On macOS $TMPDIR and /tmp are both symlinks into /private/.
WORK="$(CDPATH='' cd -- "${WORK}" && pwd -P)"
trap 'rm -rf "${WORK}"' EXIT
# run_hook records the invoked hook's exit code here so assert_empty can require a
# clean (rc 0) silent-allow - a hook that crashes before printing must NOT pass as
# "silent". Written inside run_hook's command-substitution subshell (a file, so it
# survives the subshell); read via last_rc.
RC_FILE="${WORK}/.last_hook_rc"
PASS=0
FAIL=0

pin() { printf '%s:%s' "$1" "$2"; } # pin postgres 11 -> the matchable token

run_hook() { # <hook-file> <stdin>   (env via $ENV)
	# SC2086: ${ENV:-} is deliberately unquoted so "KEY=val KEY2=val2" splits into
	# separate env assignments; quoting it would pass one bogus assignment.
	# shellcheck disable=SC2086
	printf '%s' "$2" | env ${ENV:-} sh "${HOOKS}/$1" 2>/dev/null
	# Record the hook's exit code (pipeline rc = the sourced hook's rc) so callers
	# can assert a clean silent-allow, not just empty stdout.
	printf '%s' "$?" >"${RC_FILE}"
}

run_inject() { # <stdin> -> every registered part of inject-standards.sh, concatenated
	# The ruleset ships in N parts (hooks.json registers the hook N times as
	# `<k> <N>`); a single argument-less invocation is one part and would fail
	# any assertion about a rule that landed in another. Backslashes are stripped
	# first: the JSON escapes the quotes around the path.
	_n="$(tr -d '\\' <"${HOOKS}/hooks.json" | grep -c 'inject-standards\.sh" [0-9]* [0-9]*"')"
	[ "${_n}" -ge 1 ] || _n=1
	_k=1
	while [ "${_k}" -le "${_n}" ]; do
		printf '%s' "$1" | sh "${HOOKS}/inject-standards.sh" "${_k}" "${_n}" 2>/dev/null
		_k=$((_k + 1))
	done
}

last_rc() { cat "${RC_FILE}" 2>/dev/null || printf '0'; }

# Direct-sh runner for the non-hook helper scripts (template-reconcile /
# scan-capabilities / scan-invocations / ...). Sets `out` + `rc` AND records rc to
# RC_FILE - so assert_empty's rc half asserts THIS invocation, not a stale rc
# left by an earlier run_hook (issue #338).
run_sh() { # <script> [args...]
	out="$(sh "$@" 2>/dev/null)"
	rc=$?
	printf '%s' "${rc}" >"${RC_FILE}"
}

ok() { PASS=$((PASS + 1)); }
bad() {
	FAIL=$((FAIL + 1))
	printf 'FAIL: %s\n' "$1" >&2
}

assert_empty() {
	_ae_rc="$(last_rc)"
	{ [ -z "$2" ] && [ "${_ae_rc}" -eq 0 ]; } && ok ||
		bad "$1 (expected silent + rc 0, got: '$2' rc=${_ae_rc})"
}
assert_deny() { printf '%s' "$2" | grep -q '"permissionDecision":"deny"' && ok || bad "$1 (expected deny, got: $2)"; }
assert_no_deny() { printf '%s' "$2" | grep -q '"permissionDecision":"deny"' && bad "$1 (unexpected deny: $2)" || ok; }
# Claude PreToolUse "ask" envelope: the decision wrapped in hookSpecificOutput.
assert_ask() {
	printf '%s' "$2" | grep -q '"permissionDecision":"ask"' &&
		printf '%s' "$2" | grep -q 'hookSpecificOutput' && ok ||
		bad "$1 (expected wrapped ask, got: $2)"
}
# Copilot preToolUse envelope: a flat decision object (no hookSpecificOutput wrapper).
assert_copilot_ask() {
	printf '%s' "$2" | grep -q '"permissionDecision":"ask"' &&
		! printf '%s' "$2" | grep -q 'hookSpecificOutput' && ok ||
		bad "$1 (expected flat copilot ask, got: $2)"
}
assert_ctx() { printf '%s' "$2" | grep -q '"additionalContext"' && ok || bad "$1 (expected additionalContext, got: $2)"; }
# SessionStart raw-text hooks print directly to stdout (the runtime wraps it as
# additionalContext); assert the emitted text contains a marker substring.
assert_has() { printf '%s' "$2" | grep -q -- "$3" && ok || bad "$1 (expected to contain '$3', got: $2)"; }
assert_block() { printf '%s' "$2" | grep -q '"decision":"block"' && ok || bad "$1 (expected block, got: $2)"; }
assert_no_block() { printf '%s' "$2" | grep -q '"decision":"block"' && bad "$1 (unexpected block: $2)" || ok; }
assert_eq() { [ "$2" = "$3" ] && ok || bad "$1 (want '$3', got '$2')"; }
assert_rc() { [ "$2" -eq "$3" ] && ok || bad "$1 (want rc $3, got $2)"; }

inject_fixture() { # <name> -> prints a fixture plugin root (real hook libs, own rules/)
	_ifr="${WORK}/$1"
	mkdir -p "${_ifr}/.claude-plugin" "${_ifr}/rules"
	ln -sf "${HOOKS}" "${_ifr}/hooks"
	printf '{"name":"steer","version":"0.0.0-test"}' >"${_ifr}/.claude-plugin/plugin.json"
	printf '%s' "${_ifr}"
}
inject_part() { # <plugin-root> <repo> <part> <parts> -> stdout of one part (stderr to $INJ_ERR)
	printf '%s' "$(session_json "$2" inj)" |
		env CLAUDE_PLUGIN_ROOT="$1" sh "${HOOKS}/inject-standards.sh" "$3" "$4" 2>>"${INJ_ERR}"
}
inject_chars() { printf '%s' "$1" | LC_ALL=C tr -d '\200-\277' | wc -c | tr -d ' '; }

new_repo() {
	_r="${WORK}/$1"
	mkdir -p "${_r}"
	printf '' >"${_r}/.git"
	printf '%s' "${_r}"
}

# Real git repo on a named branch, with a GitHub tracker, for the Stop hook.
git_repo() { # <name> <branch>  -> prints repo path
	_r="${WORK}/$1"
	mkdir -p "${_r}"
	(cd "${_r}" &&
		git init -q &&
		git config user.email t@e.com &&
		git config user.name t &&
		git commit -q --allow-empty -m init &&
		git checkout -q -B "$2") >/dev/null 2>&1
	mkdir -p "${_r}/spec"
	printf 'system: github\n' >"${_r}/spec/tracker.md"
	printf '%s' "${_r}"
}

json_write() { # <cwd> <session> <file_path> <content>
	printf '{"session_id":"%s","cwd":"%s","tool_name":"Write","tool_input":{"file_path":"%s","content":"%s"}}' \
		"$2" "$1" "$3" "$4"
}

stop_json() { # <cwd> <session> [stop_hook_active=false]
	printf '{"session_id":"%s","cwd":"%s","hook_event_name":"Stop","stop_hook_active":%s}' \
		"$2" "$1" "${3:-false}"
}

session_json() { # <cwd> <session>
	printf '{"session_id":"%s","cwd":"%s","hook_event_name":"SessionStart"}' "$2" "$1"
}

# Same, but carrying the SessionStart `source` (startup|resume|clear|compact|fork).
# orient-session.sh gates its one-time knowledge-work greeting on this.
session_json_src() { # <cwd> <session> <source>
	printf '{"session_id":"%s","cwd":"%s","hook_event_name":"SessionStart","source":"%s"}' "$2" "$1" "$3"
}

# Write a product CLAUDE.md carrying the machine-readable delivery-mode marker,
# plus prose that names BOTH modes - so the tests prove the matcher is anchored to
# the marker line and never matches the explanatory prose word "solo trunk".
claude_md_mode() { # <repo_root> <solo-trunk|pr-flow>
	printf '## Delivery mode\n\n<!-- steer:delivery-mode=%s -->\n\nProse names solo trunk (pre-MVP) and PR flow both.\n' "$2" >"$1/CLAUDE.md"
}

# Same, plus the recorded graduation waiver marker (/steer:setup protect waive) on the
# line after the mode marker - and prose that mentions the waiver, so the tests
# prove the waiver matcher is anchored to its comment line too.
claude_md_mode_waived() { # <repo_root> <solo-trunk|pr-flow>
	printf '## Delivery mode\n\n<!-- steer:delivery-mode=%s -->\n<!-- steer:graduation=waived -->\n\nProse names solo trunk (pre-MVP), PR flow, and the graduation waiver.\n' "$2" >"$1/CLAUDE.md"
}

json_notebook() { # <cwd> <session> <notebook_path>
	printf '{"session_id":"%s","cwd":"%s","tool_name":"NotebookEdit","tool_input":{"notebook_path":"%s","new_source":"x"}}' \
		"$2" "$1" "$3"
}

managed_spine() { # <repo_root>  -> stamp a complete, version-stamped spec spine
	mkdir -p "$1/spec"
	# TWO lines, comment first - the exact shape /steer:init, /steer:sync and
	# /steer:adopt write. A bare version here hid a reader that took line 1.
	printf '# Spec-spine version - managed by /steer:init, /steer:adopt, /steer:sync. Do not edit by hand.\n1.0.0\n' \
		>"$1/spec/.version"
	for _sf in vision.md users.md glossary.md tracker.md; do
		printf 'x\n' >"$1/spec/${_sf}"
	done
	# Action history is a DIRECTORY of per-entry files (the current shape).
	mkdir -p "$1/spec/history"
	printf 'x\n' >"$1/spec/history/README.md"
}

# Fully bootstrapped state (managed spine + declared tracker + root mise.toml)
# so the merged write hook's spec/scaffold dimension stays silent and a test
# isolates the issue-first dimension. Tracker system defaults to github.
bootstrapped_repo() { # <repo_root> [tracker-system]
	managed_spine "$1"
	printf 'system: %s\n' "${2:-github}" >"$1/spec/tracker.md"
	: >"$1/mise.toml"
}

. "${HOOKS}/lib/json.sh"
. "${HOOKS}/lib/classify.sh"
. "${HOOKS}/lib/report-fault.sh"

# Builds Bash / MCP PreToolUse inputs. The command body is a JSON string, so any
# double quotes inside the gh command are escaped to \" by the helper.
bash_json() { # <cwd> <session> <command>
	_cmd="$(printf '%s' "$3" | sed 's/\\/\\\\/g; s/"/\\"/g')"
	printf '{"session_id":"%s","cwd":"%s","tool_name":"Bash","tool_input":{"command":"%s"}}' \
		"$2" "$1" "${_cmd}"
}
mcp_json() { # <cwd> <session> <tool_name> <body>
	printf '{"session_id":"%s","cwd":"%s","tool_name":"%s","tool_input":{"title":"x","body":"%s"}}' \
		"$2" "$1" "$3" "$4"
}
oq_grep() { printf '%s' "$3" | grep -q "$2" && ok || bad "$1 (got: $3)"; }
oq_ngrep() { printf '%s' "$3" | grep -q "$2" && bad "$1 (unexpected: $3)" || ok; }

finish() { # last line of every case file: tally (parsed by run.sh) + exit code
	printf '%d passed, %d failed\n' "${PASS}" "${FAIL}"
	[ "${FAIL}" -eq 0 ]
}

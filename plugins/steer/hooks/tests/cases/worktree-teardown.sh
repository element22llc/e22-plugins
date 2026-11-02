#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# ---------------------------------------------------------------------------
# on-session-end.sh (SessionEnd) + on-worktree-remove.sh (WorktreeRemove) -
# tear down a LINKED worktree's backing services at the two moments the harness
# tells us they are done. Both events discard stdout and the exit code, so every
# case asserts on what the hook DID (a stubbed `mise` records its argv) rather
# than on what it printed. The two modes are deliberately different acts:
# SessionEnd stops containers and keeps volumes, WorktreeRemove removes both.
# ---------------------------------------------------------------------------
. "${HERE}/lib-worktree.sh"
LC_STUBS="${WORK}/lcstubs"
LC_LOG="${WORK}/lcmise.log"
mkdir -p "${LC_STUBS}"
# `mise tasks ls` answers from MISE_STUB_TASKS, each name printed with a
# description column like the real thing; `mise run ...` just logs. The list is
# COMMA-separated because run_hook word-splits $ENV into env assignments, so a
# value with spaces would be read as a second assignment (and then as a command).
cat >"${LC_STUBS}/mise" <<'STUB'
#!/bin/sh
printf 'mise %s\n' "$*" >>"${MISE_STUB_LOG:?}"
case "$1" in
tasks)
	_rest="${MISE_STUB_TASKS:-}"
	while [ -n "${_rest}" ]; do
		printf '%s\tstub description\n' "${_rest%%,*}"
		case "${_rest}" in
		*,*) _rest="${_rest#*,}" ;;
		*) _rest="" ;;
		esac
	done
	;;
esac
exit 0
STUB
chmod +x "${LC_STUBS}/mise"
# docker only has to EXIST - the teardown is delegated to a mise task.
printf '#!/bin/sh\nexit 0\n' >"${LC_STUBS}/docker"
chmod +x "${LC_STUBS}/docker"

LC_PATH="PATH=${LC_STUBS}:/usr/bin:/bin"
LC_TASKS="docker:up,docker:down,docker:clean,db:migrate"

session_end_json() { # <cwd> <reason>
	printf '{"session_id":"se","cwd":"%s","hook_event_name":"SessionEnd","reason":"%s"}' "$1" "$2"
}
worktree_remove_json() { # <worktree_path>
	printf '{"session_id":"wr","hook_event_name":"WorktreeRemove","cwd":"%s","worktree_path":"%s"}' "$1" "$1"
}

# lc_pair <name> - wt_pair plus a compose.yaml in both roots, the file the
# docker:* tasks act on and the gate this teardown checks.
lc_pair() {
	# shellcheck disable=SC2046  # deliberate word split: wt_pair prints two paths
	set -- $(wt_pair "$1")
	printf 'services: {}\n' >"$1/compose.yaml"
	printf 'services: {}\n' >"$2/compose.yaml"
	printf '%s %s' "$1" "$2"
}

# (a) SessionEnd in a linked worktree, real exit -> containers STOPPED, volumes
#     kept. `docker:down`, never `docker:clean`: a session ending is not the
#     worktree ending and the dev's data must survive it.
# shellcheck disable=SC2046
set -- $(lc_pair lcA)
LCA_W="$2"
: >"${LC_LOG}"
out="$(ENV="${LC_PATH} MISE_STUB_LOG=${LC_LOG} MISE_STUB_TASKS=${LC_TASKS}" \
	run_hook on-session-end.sh "$(session_end_json "${LCA_W}" prompt_input_exit)")"
assert_empty "session-end: silent (output is discarded by the harness)" "${out}"
grep -q "mise run -C ${LCA_W} docker:down" "${LC_LOG}" && ok ||
	bad "session-end: stops the worktree's services (log: $(cat "${LC_LOG}"))"
grep -q 'docker:clean' "${LC_LOG}" &&
	bad "session-end: must NOT remove volumes on a session ending" || ok

# (b) SessionEnd with reason=clear / resume -> nothing. Those continue the same
#     working session (the rules are re-injected for exactly that reason), so a
#     teardown there would break the session that follows.
for _r in clear resume; do
	# shellcheck disable=SC2046
	set -- $(lc_pair "lcB${_r}")
	: >"${LC_LOG}"
	out="$(ENV="${LC_PATH} MISE_STUB_LOG=${LC_LOG} MISE_STUB_TASKS=${LC_TASKS}" \
		run_hook on-session-end.sh "$(session_end_json "$2" "${_r}")")"
	assert_empty "session-end: reason=${_r} silent" "${out}"
	[ -s "${LC_LOG}" ] &&
		bad "session-end: reason=${_r} must not tear anything down (log: $(cat "${LC_LOG}"))" || ok
done

# (c) SessionEnd in a PLAIN checkout -> nothing, and mise never invoked. The
#     dev's main stack is theirs; only a per-worktree compose project is in scope.
# shellcheck disable=SC2046
set -- $(lc_pair lcC)
LCC_P="$1"
: >"${LC_LOG}"
out="$(ENV="${LC_PATH} MISE_STUB_LOG=${LC_LOG} MISE_STUB_TASKS=${LC_TASKS}" \
	run_hook on-session-end.sh "$(session_end_json "${LCC_P}" logout)")"
assert_empty "session-end: plain checkout silent" "${out}"
[ -s "${LC_LOG}" ] &&
	bad "session-end: plain checkout must not invoke mise (log: $(cat "${LC_LOG}"))" || ok

# (d) WorktreeRemove -> FULL teardown (volumes + orphans). The checkout is about
#     to be deleted, so its per-worktree volumes become unreachable either way.
# shellcheck disable=SC2046
set -- $(lc_pair lcD)
LCD_W="$2"
: >"${LC_LOG}"
out="$(ENV="${LC_PATH} MISE_STUB_LOG=${LC_LOG} MISE_STUB_TASKS=${LC_TASKS}" \
	run_hook on-worktree-remove.sh "$(worktree_remove_json "${LCD_W}")")"
assert_empty "worktree-remove: silent" "${out}"
grep -q "mise run -C ${LCD_W} docker:clean" "${LC_LOG}" && ok ||
	bad "worktree-remove: full teardown (log: $(cat "${LC_LOG}"))"

# (e) WorktreeRemove acts on worktree_path, NOT on cwd - a subagent's isolated
#     tree or a background session's is removed while the session sits elsewhere.
# shellcheck disable=SC2046
set -- $(lc_pair lcE)
LCE_P="$1"
LCE_W="$2"
: >"${LC_LOG}"
out="$(ENV="${LC_PATH} MISE_STUB_LOG=${LC_LOG} MISE_STUB_TASKS=${LC_TASKS}" \
	run_hook on-worktree-remove.sh \
	"$(printf '{"session_id":"wr2","hook_event_name":"WorktreeRemove","cwd":"%s","worktree_path":"%s"}' "${LCE_P}" "${LCE_W}")")"
grep -q "mise run -C ${LCE_W} docker:clean" "${LC_LOG}" && ok ||
	bad "worktree-remove: acts on worktree_path, not cwd (log: $(cat "${LC_LOG}"))"

# (f) a workspace root, where every task is `ws:`-prefixed so it cannot shadow a
#     member's -> the `ws:` name is what gets run.
# shellcheck disable=SC2046
set -- $(lc_pair lcF)
LCF_W="$2"
: >"${LC_LOG}"
out="$(ENV="${LC_PATH} MISE_STUB_LOG=${LC_LOG} MISE_STUB_TASKS=ws:docker:up,ws:docker:clean" \
	run_hook on-worktree-remove.sh "$(worktree_remove_json "${LCF_W}")")"
grep -q "mise run -C ${LCF_W} ws:docker:clean" "${LC_LOG}" && ok ||
	bad "worktree-remove: workspace root uses the ws: task (log: $(cat "${LC_LOG}"))"

# (g) a repo that legitimately pruned the docker tasks -> nothing is run.
# shellcheck disable=SC2046
set -- $(lc_pair lcG)
LCG_W="$2"
: >"${LC_LOG}"
out="$(ENV="${LC_PATH} MISE_STUB_LOG=${LC_LOG} MISE_STUB_TASKS=lint,test" \
	run_hook on-worktree-remove.sh "$(worktree_remove_json "${LCG_W}")")"
grep -q 'mise run' "${LC_LOG}" &&
	bad "worktree-remove: no docker task defined -> run nothing" || ok

# (h) no compose file -> nothing, and the task list is never even consulted.
# shellcheck disable=SC2046
set -- $(wt_pair lcH)
LCH_W="$2"
: >"${LC_LOG}"
out="$(ENV="${LC_PATH} MISE_STUB_LOG=${LC_LOG} MISE_STUB_TASKS=${LC_TASKS}" \
	run_hook on-worktree-remove.sh "$(worktree_remove_json "${LCH_W}")")"
[ -s "${LC_LOG}" ] &&
	bad "worktree-remove: no compose file must not invoke mise (log: $(cat "${LC_LOG}"))" || ok

# (i) the opt-out is absolute.
# shellcheck disable=SC2046
set -- $(lc_pair lcI)
LCI_W="$2"
: >"${LC_LOG}"
out="$(ENV="${LC_PATH} MISE_STUB_LOG=${LC_LOG} MISE_STUB_TASKS=${LC_TASKS} STEER_NO_WORKTREE_TEARDOWN=1" \
	run_hook on-worktree-remove.sh "$(worktree_remove_json "${LCI_W}")")"
[ -s "${LC_LOG}" ] &&
	bad "worktree-remove: STEER_NO_WORKTREE_TEARDOWN disables it (log: $(cat "${LC_LOG}"))" || ok

# (j) a missing worktree_path is not a reason to guess at cwd.
: >"${LC_LOG}"
out="$(ENV="${LC_PATH} MISE_STUB_LOG=${LC_LOG} MISE_STUB_TASKS=${LC_TASKS}" \
	run_hook on-worktree-remove.sh \
	"$(printf '{"session_id":"wr3","hook_event_name":"WorktreeRemove","cwd":"%s"}' "${LCE_W}")")"
assert_empty "worktree-remove: no worktree_path silent" "${out}"
[ -s "${LC_LOG}" ] &&
	bad "worktree-remove: no worktree_path must act on nothing" || ok

# (k) WorktreeRemove has no decision control and cannot report, so the hook must exit 0
#     even when everything around it is broken (no mise, no docker, junk stdin).
out="$(ENV="PATH=/usr/bin:/bin" run_hook on-worktree-remove.sh "$(worktree_remove_json "${LCE_W}")")"
assert_empty "worktree-remove: exits 0 with no mise on PATH" "${out}"
out="$(ENV="PATH=/usr/bin:/bin" run_hook on-worktree-remove.sh 'not json at all')"
assert_empty "worktree-remove: exits 0 on unparseable input" "${out}"
out="$(ENV="PATH=/usr/bin:/bin" run_hook on-session-end.sh 'not json at all')"
assert_empty "session-end: exits 0 on unparseable input" "${out}"
unset ENV

# (l) both events are registered in hooks.json, and check-worktree-trust.sh also
#     runs on CwdChanged - the post-creation moment a worktree entered
#     mid-session becomes visible (WorktreeCreate fires before the path exists,
#     and `mise trust` cannot trust a directory that is not there yet).
for _pair in 'SessionEnd on-session-end.sh' 'WorktreeRemove on-worktree-remove.sh' \
	'CwdChanged check-worktree-trust.sh'; do
	# shellcheck disable=SC2086
	set -- ${_pair}
	tr -d ' \n\t' <"${HOOKS}/hooks.json" | grep -q "\"$1\":\[" && ok ||
		bad "hooks.json: $1 registered"
	grep -q "$2" "${HOOKS}/hooks.json" && ok || bad "hooks.json: $2 wired"
done

# (m) Orca layout: the worktree lives OUTSIDE the primary checkout
#     (~/orca/workspaces/<repo>/<name>) and its git dir is named `<pid>-<uuid>`,
#     not after the worktree. Trust inheritance and the SessionEnd stop must key
#     off the `gitdir:` pointer alone, never a `.claude/worktrees/` path.
ORCA_P="${WORK}/orcaPrimary/repo"
ORCA_W="${WORK}/orca/workspaces/repo/Feat-X"
ORCA_GD="${ORCA_P}/.git/worktrees/24339-70eed91b-36e2-4b5b-91b1-02da19eb5ad6"
mkdir -p "${ORCA_GD}" "${ORCA_W}"
for _d in "${ORCA_P}" "${ORCA_W}"; do
	printf '[env]\n_.source = "scripts/worktree-env.sh"\n' >"${_d}/mise.toml"
	printf 'services: {}\n' >"${_d}/compose.yaml"
done
printf 'gitdir: %s\n' "${ORCA_GD}" >"${ORCA_W}/.git"
: >"${WT_LOG}"
out="$(ENV="PATH=${WT_STUBS}:/usr/bin:/bin MISE_STUB_LOG=${WT_LOG} MISE_STUB_TRUSTED=${ORCA_P}" \
	run_hook check-worktree-trust.sh "$(session_json "${ORCA_W}" orca1)")"
assert_has "worktree-trust: Orca worktree outside the repo inherits" "${out}" "inherited the primary checkout"
: >"${LC_LOG}"
out="$(ENV="${LC_PATH} MISE_STUB_LOG=${LC_LOG} MISE_STUB_TASKS=${LC_TASKS}" \
	run_hook on-session-end.sh "$(session_end_json "${ORCA_W}" logout)")"
grep -q "mise run -C ${ORCA_W} docker:down" "${LC_LOG}" && ok ||
	bad "session-end: stops an Orca worktree's services (log: $(cat "${LC_LOG}"))"
unset ENV

# (n) the orca.yaml archive hook /steer:setup worktrees installs - the teardown
#     Orca runs instead of WorktreeRemove. A failing archive hook BLOCKS Orca's
#     removal, so it must exit 0 whatever mise does, and it must not `exit`
#     (Orca may append a local script after it).
ORCA_YAML="${PLUGIN}/templates/worktrees/orca.yaml"
ORCA_ARCHIVE="$(sed -n '/^  archive: |/,$p' "${ORCA_YAML}" | sed '1d' | sed -n 's/^    //p')"
[ -n "${ORCA_ARCHIVE}" ] && ok || bad "orca.yaml: scripts.archive block found"
printf '%s' "${ORCA_ARCHIVE}" | grep -q 'exit' &&
	bad "orca.yaml: archive must not exit (a local script may follow)" || ok
ORCA_FAIL="${WORK}/orcafail"
mkdir -p "${ORCA_FAIL}"
printf '#!/bin/sh\nprintf "mise %%s\\n" "$*" >>"${MISE_STUB_LOG:?}"\nexit 1\n' >"${ORCA_FAIL}/mise"
chmod +x "${ORCA_FAIL}/mise"
orca_archive() { # <stub-dir> [VAR=value...] - run the hook as Orca does, in the worktree
	_stubs="$1"
	shift
	(cd "${ORCA_W}" && env PATH="${_stubs}:/usr/bin:/bin" MISE_STUB_LOG="${LC_LOG}" "$@" sh -c "${ORCA_ARCHIVE}")
}
: >"${LC_LOG}"
orca_archive "${LC_STUBS}" && ok || bad "orca.yaml: archive exits 0"
grep -q 'mise run docker:clean' "${LC_LOG}" && ok ||
	bad "orca.yaml: archive runs docker:clean (log: $(cat "${LC_LOG}"))"
: >"${LC_LOG}"
orca_archive "${ORCA_FAIL}" && ok || bad "orca.yaml: archive exits 0 when mise fails"
grep -q 'mise run ws:docker:clean' "${LC_LOG}" && ok ||
	bad "orca.yaml: archive falls back to ws:docker:clean (log: $(cat "${LC_LOG}"))"
: >"${LC_LOG}"
orca_archive "/nonexistent" 2>/dev/null && ok || bad "orca.yaml: archive exits 0 with no mise on PATH"
: >"${LC_LOG}"
orca_archive "${LC_STUBS}" STEER_NO_WORKTREE_TEARDOWN=1 && ok ||
	bad "orca.yaml: archive exits 0 when disabled"
[ -s "${LC_LOG}" ] &&
	bad "orca.yaml: STEER_NO_WORKTREE_TEARDOWN disables the archive teardown" || ok

finish

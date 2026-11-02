#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# ---------------------------------------------------------------------------
# scripts/scan-worktrees.sh - the /steer:setup worktrees detector. A real git
# repo with worktrees from three managers: Claude Code (in-repo, ignored), Orca
# in-repo (unignored) and Orca external. Stubbed mise answers trust; stubbed
# docker answers `compose ls` and `volume ls`, so the orphan verdicts are
# deterministic.
# ---------------------------------------------------------------------------
. "${HERE}/lib-worktree.sh"
SCANWT="${PLUGIN}/scripts/scan-worktrees.sh"
ORCA_YAML="${PLUGIN}/templates/worktrees/orca.yaml"
if command -v git >/dev/null 2>&1; then
	SW_P="$(git_repo swPrim main)"
	SW_STUBS="${WORK}/swstubs"
	mkdir -p "${SW_STUBS}" "${SW_P}/scripts" "${SW_P}/apps/web"
	ln -s "${WT_STUBS}/mise" "${SW_STUBS}/mise"
	cat >"${SW_STUBS}/docker" <<'STUB'
#!/bin/sh
[ -n "${DOCKER_STUB_JSON:-}" ] || exit 1
case "$1" in
compose) cat "${DOCKER_STUB_JSON}" ;;
volume) [ -z "${DOCKER_STUB_VOLUMES:-}" ] || cat "${DOCKER_STUB_VOLUMES}" ;;
esac
STUB
	chmod +x "${SW_STUBS}/docker"
	printf '[env]\n_.source = "scripts/worktree-env.sh"\n' >"${SW_P}/mise.toml"
	printf 'services: {}\n' >"${SW_P}/compose.yaml"
	printf ': \n' >"${SW_P}/scripts/worktree-env.sh"
	printf '.env\n.env.local\n.claude/worktrees/\n' >"${SW_P}/.gitignore"
	printf '.env\n' >"${SW_P}/.worktreeinclude"
	(cd "${SW_P}" && git add -A && git commit -q -m scaffold &&
		git worktree add -q -b c1 .claude/worktrees/c1 &&
		git worktree add -q -b o1 .orca/worktrees/o1 &&
		git worktree add -q -b o2 "${WORK}/orca/workspaces/swPrim/Feat") >/dev/null 2>&1
	printf 'A=1\n' >"${SW_P}/.env"
	printf 'A=1\n' >"${SW_P}/apps/web/.env"
	printf 'A=1\n' >"${SW_P}/apps/web/.env.local"
	printf '[{"Name":"swprim-gone","Status":"exited(1)","ConfigFiles":"%s/gone/compose.yaml"},{"Name":"swprim-live","Status":"running(1)","ConfigFiles":"%s/compose.yaml"},{"Name":"other-gone","Status":"exited(1)","ConfigFiles":"%s/gone2/compose.yaml"}]\n' \
		"${WORK}" "${SW_P}" "${WORK}" >"${WORK}/sw-ls.json"
	# Volume-only projects: c1 is a live worktree, swprim-sib a sibling repo's own
	# project, swprim-gone already reported from `compose ls`; only swprim-old is
	# an orphan.
	printf 'swprim-c1\nswprim-old\nswprim-gone\nswprim-sib\nother-x\n\n' >"${WORK}/sw-vols.txt"
	mkdir -p "${WORK}/swprim-sib"
	sw_scan() { # [VAR=value...] - scan the primary; findings land in $out
		out="$(env PATH="${SW_STUBS}:/usr/bin:/bin" MISE_STUB_LOG="${WT_LOG}" \
			MISE_STUB_TRUSTED="${SW_P}" ORCA_WORKTREE_ID= TERM_PROGRAM= \
			CONDUCTOR_WORKSPACE_PATH= CONDUCTOR_ROOT_PATH= "$@" sh "${SCANWT}" "${SW_P}")"
	}
	sw_line() { printf '%s\n' "${out}" | grep -F "$(printf '%s\t%s' "$1" "$2")"; }
	sw_scan DOCKER_STUB_JSON="${WORK}/sw-ls.json" DOCKER_STUB_VOLUMES="${WORK}/sw-vols.txt"
	sw_line checkout primary >/dev/null && ok || bad "scan-worktrees: primary checkout (got: ${out})"
	for _m in claude-code orca; do
		[ "$(sw_line manager "${_m}" | wc -l | tr -d ' ')" = 1 ] && ok ||
			bad "scan-worktrees: manager ${_m} reported once (got: ${out})"
	done
	sw_line manager git >/dev/null && bad "scan-worktrees: no plain-git manager here" || ok
	sw_line primary-trust trusted >/dev/null && ok || bad "scan-worktrees: primary trusted"
	sw_line trust untrusted | grep -q '.orca/worktrees/o1' && ok ||
		bad "scan-worktrees: a linked worktree reported untrusted (got: ${out})"
	sw_line env-isolation ok >/dev/null && ok || bad "scan-worktrees: env-isolation wired"
	# A slash-less `.env` covers apps/web/.env at any depth; only .env.local is uncovered.
	[ "$(sw_line worktreeinclude incomplete | cut -f3)" = "apps/web/.env.local" ] && ok ||
		bad "scan-worktrees: only apps/web/.env.local uncovered (got: ${out})"
	sw_line env-copy missing | grep -q 'orca/workspaces/swPrim/Feat: ' && ok ||
		bad "scan-worktrees: external worktree lacks the env files (got: ${out})"
	sw_line worktree-dir ignored | grep -q '.claude/worktrees' && ok ||
		bad "scan-worktrees: .claude/worktrees ignored"
	sw_line worktree-dir unignored | grep -q '.orca/worktrees' && ok ||
		bad "scan-worktrees: .orca/worktrees unignored (got: ${out})"
	sw_line teardown swept | grep -q 'claude-code' && ok || bad "scan-worktrees: claude-code swept, not hooked"
	sw_line teardown absent | grep -q 'orca' && ok || bad "scan-worktrees: orca teardown absent"
	sw_line orphan swprim-gone | grep -q "${WORK}/gone" && ok ||
		bad "scan-worktrees: this repo's stack with its dir gone is an orphan (got: ${out})"
	sw_line orphan swprim-live >/dev/null && bad "scan-worktrees: a live stack is never an orphan" || ok
	sw_line orphan other-gone >/dev/null && bad "scan-worktrees: another repo's stack is not ours" || ok
	[ "$(sw_line orphan swprim-old | cut -f3)" = "-" ] && ok ||
		bad "scan-worktrees: volumes left without containers are an orphan (got: ${out})"
	for _v in swprim-c1 swprim-sib other-x; do
		sw_line orphan "${_v}" >/dev/null && bad "scan-worktrees: ${_v} volumes are not an orphan" || ok
	done
	[ "$(sw_line orphan swprim-gone | wc -l | tr -d ' ')" = 1 ] && ok ||
		bad "scan-worktrees: an orphan with containers and volumes is listed once"
	sw_line orphans 2 >/dev/null && ok || bad "scan-worktrees: two orphans counted (got: ${out})"

	# check-worktree-orphans.sh - the session notice over the same detector.
	SWO_ENV="PATH=${SW_STUBS}:/usr/bin:/bin DOCKER_STUB_JSON=${WORK}/sw-ls.json DOCKER_STUB_VOLUMES=${WORK}/sw-vols.txt"
	out="$(ENV="${SWO_ENV}" run_hook check-worktree-orphans.sh "$(session_json "${SW_P}" swo1)")"
	assert_has "worktree-orphans: names the orphan with containers" "${out}" '`swprim-gone`'
	assert_has "worktree-orphans: names the volume-only orphan" "${out}" '`swprim-old`'
	assert_has "worktree-orphans: counts them" "${out}" "steer: 2 Compose stack"
	assert_has "worktree-orphans: routes to the sweep" "${out}" "/steer:setup worktrees"
	out="$(ENV="${SWO_ENV}" run_hook check-worktree-orphans.sh "$(session_json "${SW_P}/.claude/worktrees/c1" swo2)")"
	assert_empty "worktree-orphans: silent in a linked worktree" "${out}"
	out="$(ENV="${SWO_ENV} STEER_NO_WORKTREE_TEARDOWN=1" run_hook check-worktree-orphans.sh "$(session_json "${SW_P}" swo3)")"
	assert_empty "worktree-orphans: STEER_NO_WORKTREE_TEARDOWN silences it" "${out}"
	out="$(ENV="PATH=${SW_STUBS}:/usr/bin:/bin" run_hook check-worktree-orphans.sh "$(session_json "${SW_P}" swo4)")"
	assert_empty "worktree-orphans: silent when docker cannot answer" "${out}"
	# Same basename, so the same project prefix: only the gates differ.
	SWO_G="$(git_repo swoGate/swPrim main)"
	printf 'services: {}\n' >"${SWO_G}/compose.yaml"
	out="$(ENV="${SWO_ENV}" run_hook check-worktree-orphans.sh "$(session_json "${SWO_G}" swo5)")"
	assert_empty "worktree-orphans: silent without .claude/worktrees" "${out}"
	mkdir -p "${SWO_G}/.claude/worktrees"
	out="$(ENV="${SWO_ENV}" run_hook check-worktree-orphans.sh "$(session_json "${SWO_G}" swo6)")"
	assert_has "worktree-orphans: reports once Claude Code worktrees were used" "${out}" '`swprim-old`'
	rm "${SWO_G}/compose.yaml"
	out="$(ENV="${SWO_ENV}" run_hook check-worktree-orphans.sh "$(session_json "${SWO_G}" swo7)")"
	assert_empty "worktree-orphans: silent without a compose file" "${out}"

	cp "${ORCA_YAML}" "${SW_P}/orca.yaml"
	sw_scan
	sw_line teardown ok | grep -q 'orca' && ok || bad "scan-worktrees: installed orca.yaml is ok"
	sw_line orphans n/a >/dev/null && ok || bad "scan-worktrees: docker failure is n/a, not an error"
	printf 'scripts:\n  setup: pnpm install\n' >"${SW_P}/orca.yaml"
	sw_scan
	sw_line teardown merge | grep -q 'orca' && ok || bad "scan-worktrees: foreign orca.yaml needs a merge"

	# from inside a linked worktree the scan anchors on the same primary.
	out="$(env PATH="${SW_STUBS}:/usr/bin:/bin" MISE_STUB_LOG="${WT_LOG}" ORCA_WORKTREE_ID=x \
		sh "${SCANWT}" "${WORK}/orca/workspaces/swPrim/Feat")"
	sw_line checkout linked | grep -q 'swPrim' && ok || bad "scan-worktrees: linked checkout (got: ${out})"
	sw_line manager orca | grep -q 'session env' && ok || bad "scan-worktrees: Orca seen from session env"
	sh "${SCANWT}" "${WORK}/not-a-repo-anywhere" >/dev/null 2>&1
	[ $? = 3 ] && ok || bad "scan-worktrees: outside a work tree exits 3"
fi

finish

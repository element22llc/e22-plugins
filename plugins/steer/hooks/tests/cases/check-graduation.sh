#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# --- check-graduation.sh: solo-trunk graduation detector (SessionStart) ---
# Fires only in solo-trunk AND when a local signal is present; silent otherwise.

# solo-trunk + a prod branch -> nudge (real git repo so show-ref resolves the ref).
GRAD_PROD="$(git_repo grad_prod main)"
git -C "${GRAD_PROD}" branch prod >/dev/null 2>&1
claude_md_mode "${GRAD_PROD}" solo-trunk
out="$(run_hook check-graduation.sh "$(session_json "${GRAD_PROD}" sg1)")"
assert_has "graduation: solo-trunk + prod branch nudges" "${out}" "graduate"

# solo-trunk + infra/ tree -> nudge.
GRAD_INFRA="$(new_repo grad_infra)"
mkdir -p "${GRAD_INFRA}/infra"
claude_md_mode "${GRAD_INFRA}" solo-trunk
out="$(run_hook check-graduation.sh "$(session_json "${GRAD_INFRA}" sg2)")"
assert_has "graduation: solo-trunk + infra/ nudges" "${out}" "graduate"

# solo-trunk + a deploy workflow -> nudge.
GRAD_DEPLOY="$(new_repo grad_deploy)"
mkdir -p "${GRAD_DEPLOY}/.github/workflows"
printf 'name: deploy\n' >"${GRAD_DEPLOY}/.github/workflows/deploy.yml"
claude_md_mode "${GRAD_DEPLOY}" solo-trunk
out="$(run_hook check-graduation.sh "$(session_json "${GRAD_DEPLOY}" sg3)")"
assert_has "graduation: solo-trunk + deploy workflow nudges" "${out}" "graduate"

# solo-trunk with no signal -> silent (a fresh pre-MVP repo gets zero noise).
GRAD_NONE="$(new_repo grad_none)"
claude_md_mode "${GRAD_NONE}" solo-trunk
out="$(run_hook check-graduation.sh "$(session_json "${GRAD_NONE}" sg4)")"
assert_empty "graduation: solo-trunk + no signal silent" "${out}"

# solo-trunk + every local signal + a recorded graduation waiver -> silent: the
# dev has answered (single-dev trunk is deliberate), so the notice must not
# re-fire every session.
GRAD_WAIVED="$(git_repo grad_waived main)"
git -C "${GRAD_WAIVED}" branch prod >/dev/null 2>&1
mkdir -p "${GRAD_WAIVED}/infra" "${GRAD_WAIVED}/.github/workflows"
printf 'name: deploy\n' >"${GRAD_WAIVED}/.github/workflows/deploy.yml"
claude_md_mode_waived "${GRAD_WAIVED}" solo-trunk
out="$(run_hook check-graduation.sh "$(session_json "${GRAD_WAIVED}" sg4w)")"
assert_empty "graduation: solo-trunk + signals + waiver silent" "${out}"

# The waiver matcher is anchored to its comment line: prose mentioning the
# waiver (no marker) does NOT waive - the nudge still fires.
GRAD_WAIVEPROSE="$(new_repo grad_waiveprose)"
mkdir -p "${GRAD_WAIVEPROSE}/infra"
printf '## Delivery mode\n\n<!-- steer:delivery-mode=solo-trunk -->\n\nRun /steer:setup protect waive to set steer:graduation=waived if trunk is deliberate.\n' >"${GRAD_WAIVEPROSE}/CLAUDE.md"
out="$(run_hook check-graduation.sh "$(session_json "${GRAD_WAIVEPROSE}" sg4p)")"
assert_has "graduation: waiver named in prose only still nudges" "${out}" "graduate"
assert_has "graduation: nudge names the waiver path" "${out}" "/steer:setup protect waive"

# lib/repo-root.sh: steer_graduation_waived - fail-closed (no CLAUDE.md / no
# marker -> not waived), true only on the anchored marker line.
. "${HOOKS}/lib/repo-root.sh"
steer_graduation_waived "${GRAD_WAIVED}" && ok || bad "waived: marker line -> waived"
steer_graduation_waived "${GRAD_WAIVEPROSE}" && bad "waived: prose mention must not waive" || ok
steer_graduation_waived "${GRAD_NONE}" && bad "waived: no marker -> not waived" || ok
steer_graduation_waived "${WORK}/grad_nowhere" && bad "waived: no CLAUDE.md -> not waived" || ok

# pr-flow with a signal -> silent (already graduated; mode gate wins).
GRAD_PRFLOW="$(new_repo grad_prflow)"
mkdir -p "${GRAD_PRFLOW}/infra"
claude_md_mode "${GRAD_PRFLOW}" pr-flow
out="$(run_hook check-graduation.sh "$(session_json "${GRAD_PRFLOW}" sg5)")"
assert_empty "graduation: pr-flow silent despite signal" "${out}"

# cwd not inside a repo -> silent (no root to anchor on).
GRAD_NOREPO="${WORK}/grad_norepo"
mkdir -p "${GRAD_NOREPO}"
out="$(run_hook check-graduation.sh "$(session_json "${GRAD_NOREPO}" sg6)")"
assert_empty "graduation: no repo silent" "${out}"

finish

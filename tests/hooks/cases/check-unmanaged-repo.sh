#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# ---------------------------------------------------------------------------
# check-unmanaged-repo.sh - greenfield bootstrap nudge (SessionStart).
# Resolves the repo root from the payload `cwd` like its sibling SessionStart
# hooks (#331) - the suite deliberately does NOT cd into the fixture, so the
# hook process cwd (this repo, which has .claude-plugin/) diverges from the
# payload cwd; anchoring on the process cwd would self-silence every case
# below. new_repo drops a .git file the upward walk anchors on.
# ---------------------------------------------------------------------------
# No /spec spine -> nudge leads with the PO build path, still offers init/adopt.
UM1="$(new_repo unmanaged1)"
out="$(run_hook check-unmanaged-repo.sh "$(session_json "${UM1}" um1)")"
oq_grep "unmanaged: nudge offers /steer:build for a non-technical owner" '/steer:build' "${out}"
oq_grep "unmanaged: nudge still offers the greenfield path for a developer" 'the `init` path (developer' "${out}"
oq_grep "unmanaged: nudge still offers the adopt path for existing code" '`adopt` (substantial existing code' "${out}"
# Lite mode (PLAN.md Phase 2): spec-only work is sanctioned without bootstrap -
# the notice must offer /steer:spec as working right now, and keep the code gate.
oq_grep "unmanaged: nudge offers spec-only lite mode" 'lite mode' "${out}"
oq_grep "unmanaged: lite mode names /steer:spec" '/steer:spec' "${out}"
oq_grep "unmanaged: code still requires bootstrap" 'CODE' "${out}"

# Managed spine -> silent (the notice clears itself once /spec exists).
UM2="$(new_repo unmanaged2)"
managed_spine "${UM2}"
out="$(run_hook check-unmanaged-repo.sh "$(session_json "${UM2}" um2)")"
assert_empty "unmanaged: managed spine silent" "${out}"

# Payload cwd in a SUBDIRECTORY of an unmanaged repo -> the upward walk still
# anchors on the repo root and the nudge fires.
UM3="$(new_repo unmanaged3)"
mkdir -p "${UM3}/apps/web"
out="$(run_hook check-unmanaged-repo.sh "$(session_json "${UM3}/apps/web" um3)")"
oq_grep "unmanaged: payload subdir cwd still resolves the repo root" '/steer:setup' "${out}"

# OpenSpec spine, steer's side not laid down -> `openspec-setup`. The greenfield
# card must NOT fire: it would demand a bootstrap laying a competing
# spec/features/** spine next to openspec/.
UM4="$(new_repo unmanaged4)"
mkdir -p "${UM4}/openspec/changes"
out="$(run_hook check-unmanaged-repo.sh "$(session_json "${UM4}" um4)")"
oq_grep "unmanaged: openspec repo gets the OpenSpec notice" 'uses OpenSpec for its spec spine' "${out}"
printf '%s' "${out}" | grep -q 'not set up on the org standards yet' &&
	bad "unmanaged: openspec repo must not get the greenfield bootstrap card" || ok
oq_grep "unmanaged: openspec-setup names the namespaced ADR path" 'openspec/steer/decisions/' "${out}"
oq_grep "unmanaged: openspec-setup names the namespaced tracker path" 'openspec/steer/tracker.md' "${out}"
# It must NOT send the session to the bootstrap skills: init/adopt write a
# spec/ spine from the templates, which is the competing spine rule 33 forbids.
# They may only appear inside the explicit "do not run" sentence.
printf '%s' "${out}" | grep -q 'Do \*\*not\*\* run `/steer:setup init`' ||
	bad "unmanaged: openspec-setup must explicitly warn off the bootstrap modes"
printf '%s' "${out}" | grep -q 'Run \*\*`/steer:setup`\*\* to add them' &&
	bad "unmanaged: openspec-setup must not route artifact creation to /steer:setup" || ok
oq_grep "unmanaged: openspec-setup points at the bundled tracker template" 'templates/spec/tracker.md' "${out}"

# Complete OpenSpec spine (steer's tracker under openspec/steer/) -> silent.
UM5="$(new_repo unmanaged5)"
mkdir -p "${UM5}/openspec/changes" "${UM5}/openspec/steer"
printf 'system: github\n' >"${UM5}/openspec/steer/tracker.md"
out="$(run_hook check-unmanaged-repo.sh "$(session_json "${UM5}" um5)")"
assert_empty "unmanaged: complete openspec spine is silent" "${out}"

# Pre-fold residue: artifacts still at the OLD spec/ paths -> point at /steer:sync
# rather than staying silent, since the tracker being READ is the openspec/ one.
UM6="$(new_repo unmanaged6)"
mkdir -p "${UM6}/openspec/changes" "${UM6}/openspec/steer" "${UM6}/spec/decisions"
printf 'system: github\n' >"${UM6}/openspec/steer/tracker.md"
printf 'system: github\n' >"${UM6}/spec/tracker.md"
out="$(run_hook check-unmanaged-repo.sh "$(session_json "${UM6}" um6)")"
oq_grep "unmanaged: pre-fold residue points at the sync mode" '/steer:setup sync' "${out}"
oq_grep "unmanaged: pre-fold residue names the old location" 'old location' "${out}"

# A repo bootstrapped under the INTERIM shape (openspec/ + spec/ artifacts, no
# openspec/steer/) reads as openspec-setup and must still be told to migrate
# rather than offered /steer:adopt for its `foreign` spec/.
UM7="$(new_repo unmanaged7)"
mkdir -p "${UM7}/openspec/changes" "${UM7}/spec/decisions"
printf 'system: github\n' >"${UM7}/spec/tracker.md"
out="$(run_hook check-unmanaged-repo.sh "$(session_json "${UM7}" um7)")"
printf '%s' "${out}" | grep -q 'no spec-spine marker' &&
	bad "unmanaged: interim-shape openspec repo must not get the adopt offer" || ok
oq_grep "unmanaged: interim-shape openspec repo gets the OpenSpec notice" 'uses OpenSpec for its spec spine' "${out}"

finish

#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# ----- inject-standards.sh + orient-session.sh: knowledge-work mode -----
# A non-git folder with no code/config markers (the typical Claude Cowork
# product-owner case) is classified 'knowledge': only the unmarked, always-on
# PO-relevant rules inject, every code/infra/tracker-scoped rule is skipped, and
# orient-session emits a plain-language confirmation.
KW="${WORK}/kw_plain"
mkdir -p "${KW}"
printf '# my notes\n' >"${KW}/notes.md"
out="$(run_inject "$(session_json "${KW}" kw_plain)")"
oq_grep "inject(kw): knowledge-mode banner present" 'knowledge-work mode' "${out}"
oq_grep "inject(kw): always-on router present" 'You are the router' "${out}"
oq_grep "inject(kw): spec-workflow rule present" 'Spec workflow' "${out}"
oq_grep "inject(kw): secrets rule present" 'Secrets handling' "${out}"
printf '%s' "${out}" | grep -q '## Stack' &&
	bad "inject(kw): code-only stack rule must be omitted in knowledge mode" || ok
printf '%s' "${out}" | grep -q 'isolate runtime, clean up after' &&
	bad "inject(kw): worktrees rule must be omitted in knowledge mode" || ok
printf '%s' "${out}" | grep -q 'A change is done when' &&
	bad "inject(kw): code-flavored Definition of Done must be omitted in knowledge mode" || ok
printf '%s' "${out}" | grep -q 'End-of-session checklist' &&
	bad "inject(kw): code-flavored end-of-session checklist must be omitted in knowledge mode" || ok
printf '%s' "${out}" | grep -q 'steer:inject-when' &&
	bad "inject(kw): no inject-when marker may leak in knowledge mode" || ok
out="$(run_hook orient-session.sh "$(session_json "${KW}" kw_plain)")"
oq_grep "orient(kw): knowledge-work confirmation emitted" 'knowledge-work folder' "${out}"

# The greeting is a ONE-TIME orientation, so it is gated to `source: startup`.
# The hook is registered on startup|resume|clear|compact|fork (the polyrepo topology
# note must survive a /clear), which would otherwise re-greet the same user after
# every compaction.
out="$(run_hook orient-session.sh "$(session_json_src "${KW}" kw_plain startup)")"
oq_grep "orient(kw): source=startup greets" 'knowledge-work folder' "${out}"
for src in resume clear compact fork; do
	out="$(run_hook orient-session.sh "$(session_json_src "${KW}" kw_plain "${src}")")"
	printf '%s' "${out}" | grep -q 'knowledge-work folder' &&
		bad "orient(kw): source=${src} must not re-greet" || ok
done
# Absent source -> fail open and greet (payload without the field behaves as before).
out="$(run_hook orient-session.sh "$(session_json "${KW}" kw_plain)")"
oq_grep "orient(kw): absent source fails open and greets" 'knowledge-work folder' "${out}"

# Fail-safe guard: a non-git folder that DOES carry a code marker (package.json)
# is 'code' mode - full ruleset, no knowledge banner, no knowledge confirmation.
KWC="${WORK}/kw_pkg"
mkdir -p "${KWC}"
printf '{}\n' >"${KWC}/package.json"
out="$(run_inject "$(session_json "${KWC}" kw_pkg)")"
oq_grep "inject(kw-pkg): code-mode includes stack rule" '## Stack' "${out}"
printf '%s' "${out}" | grep -q 'knowledge-work mode' &&
	bad "inject(kw-pkg): non-git folder with package.json must be code mode" || ok
out="$(run_hook orient-session.sh "$(session_json "${KWC}" kw_pkg)")"
printf '%s' "${out}" | grep -q 'knowledge-work folder' &&
	bad "orient(kw-pkg): code-mode folder must not emit knowledge confirmation" || ok

# ----- advisory mode: declared in .claude/settings.local.json, never inferred -----
# A git repo with code that declares STEER_MODE=advisory gets the knowledge core
# plus the rules marked `advisory`, under the guest banner; the repo-trait rules
# (stack, delivery, Definition of Done) and the bootstrap nudge stay out.
ADV="$(new_repo adv)"
mkdir -p "${ADV}/.claude" "${ADV}/src"
printf '{}\n' >"${ADV}/package.json"
printf '{\n  "env": {\n    "STEER_MODE": "advisory"\n  }\n}\n' >"${ADV}/.claude/settings.local.json"
out="$(run_inject "$(session_json "${ADV}" adv)")"
oq_grep "inject(adv): guest banner present" 'steer advisory mode' "${out}"
oq_grep "inject(adv): router still present" 'You are the router' "${out}"
oq_grep "inject(adv): testing rule carried as a review lens" '## Testing' "${out}"
oq_grep "inject(adv): practices rule carried" 'Patterns we follow' "${out}"
printf '%s' "${out}" | grep -q '## Stack' &&
	bad "inject(adv): org stack rule must be omitted in advisory mode" || ok
printf '%s' "${out}" | grep -q '## Commit autonomy' &&
	bad "inject(adv): delivery rule must be omitted in advisory mode" || ok
printf '%s' "${out}" | grep -q 'A change is done when' &&
	bad "inject(adv): Definition of Done must be omitted in advisory mode" || ok
printf '%s' "${out}" | grep -q 'steer:inject-when' &&
	bad "inject(adv): no inject-when marker may leak in advisory mode" || ok
out="$(run_hook check-unmanaged-repo.sh "$(session_json "${ADV}" adv)")"
assert_eq "unmanaged(adv): bootstrap nudge silent for a declared guest" "${out}" ""

# Leaving the mode is read from the file, not the launch env, so it applies at
# the next session start without a restart - and code mode carries the
# `code-project|advisory` rules on their code-project arm.
printf '{ "env": { "STEER_MODE": "advisory" } }\n' >"${ADV}/.claude/settings.local.json"
out="$(STEER_MODE=advisory run_inject "$(session_json "${ADV}" adv)")"
oq_grep "inject(adv): single-line settings file still declares the mode" 'steer advisory mode' "${out}"
printf '{ "env": {} }\n' >"${ADV}/.claude/settings.local.json"
out="$(STEER_MODE=advisory run_inject "$(session_json "${ADV}" adv)")"
printf '%s' "${out}" | grep -q 'steer advisory mode' &&
	bad "inject(adv): a launch-time STEER_MODE must not outlive the file declaration" || ok
oq_grep "inject(adv-off): code mode restores the stack rule" '## Stack' "${out}"
oq_grep "inject(adv-off): code-project|advisory rule still injects in code mode" '## Testing' "${out}"
out="$(run_hook check-unmanaged-repo.sh "$(session_json "${ADV}" adv)")"
oq_grep "unmanaged(adv-off): bootstrap nudge returns" 'not set up on the org standards' "${out}"

finish

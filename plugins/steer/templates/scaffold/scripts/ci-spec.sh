#!/usr/bin/env sh
# steer - the open-question contract, enforced on every push and PR.
# Rationale: the steer plugin's templates/reference/SPEC-FRAMEWORK.md -> "Open-question format".
# The SessionStart hook only advises, and only in Claude Code; this is the gate
# that holds for every contributor. It fails on:
#   - a bare `- [ ]` question under `## Open questions` (the retired format),
#   - an unfilled `<!-- steer:placeholder -->` seed in a feature past `draft`,
#     or beside real questions,
#   - a question missing `status:`/`impact:`, or with an unknown
#     `required_before:` or a malformed `created:`,
#   - a blocking question still open at a gate its feature has already passed.
# The first two are what `/steer:setup sync` converts and removes.
set -eu

HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=ci-lib.sh
. "${HERE}/ci-lib.sh"
# The same parser the plugin's session hook uses (a verbatim copy).
# shellcheck source-path=SCRIPTDIR
# shellcheck source=spec-questions.sh
. "${HERE}/spec-questions.sh"

# The lifecycle gates in order, and the gate each feature Status has cleared.
# Kept equal to the plugin's enums.registry `required_before` (its CI checks).
# implemented/validated are retired statuses, ranked only for un-migrated specs.
STEER_SPEC_RB_ORDER='intent-approval contract-approval implementation non-prod-validation production-release'
STEER_SPEC_CLEARED='approved=intent-approval live=production-release implemented=implementation validated=non-prod-validation'

if [ ! -f spec/.version ]; then
	steer_ci_notice 'No spec/.version - this repo has no steer spec spine, so there is no open-question contract to check.'
	exit 0
fi

failed=0
checked=0
for f in spec/vision.md spec/features/*/intent.md spec/PRODUCTIONIZATION.md; do
	[ -f "${f}" ] || continue
	checked=$((checked + 1))
	problems="$(steer_questions_parse "${f}" | awk -F '\t' -v f="${f}" \
		-v rborder="${STEER_SPEC_RB_ORDER}" -v clearmap="${STEER_SPEC_CLEARED}" '
    BEGIN {
      n = split(rborder, a, " "); for (i = 1; i <= n; i++) rank[a[i]] = i
      n = split(clearmap, a, " "); for (i = 1; i <= n; i++) { split(a[i], kv, "="); crank[kv[1]] = rank[kv[2]] }
    }
    function err(line, msg) { printf "%s:%s: %s\n", f, line, msg }
    $1 == "S" { st = $2; cleared = (st in crank) ? crank[st] : 0; next }
    $1 == "L" { err($2, "bare `- [ ]` question \"" $3 "\" - the retired format; run /steer:setup sync to convert it to a ### Q-NNN block"); next }
    $1 == "P" { pn++; pline[pn] = $2; pid[pn] = $3; next }
    $1 != "Q" { next }
    {
      real++
      if ($4 == "-") { err($3, $2 " has no status:"); next }
      if (($4 == "open" || $4 == "investigating") && $5 == "-") err($3, $2 " has no impact:")
      if ($6 != "-" && !($6 in rank)) err($3, $2 " has unknown required_before: " $6)
      if ($8 != "-" && $8 !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) err($3, $2 " created: is not YYYY-MM-DD")
      if (($4 == "open" || $4 == "investigating") && $5 == "blocking" && ($6 in rank) && rank[$6] <= cleared)
        err($3, $2 " is a blocking question still " $4 " at required_before: " $6 ", a gate this " st " feature has already passed - resolve it, or reclassify its impact with the owner")
    }
    END {
      for (i = 1; i <= pn; i++) {
        why = (cleared > 0) ? "in a feature past draft" : (real > 0) ? "beside real questions" : ""
        if (why != "") err(pline[i], pid[i] " carries the steer:placeholder marker " why " - delete an unfilled seed (/steer:setup sync removes it), or drop the marker from a real question so it is counted")
      }
    }')"
	if [ -n "${problems}" ]; then
		failed=1
		printf '%s\n' "${problems}" | while IFS= read -r p; do steer_ci_error "${p}"; done
	fi
done

if [ "${failed}" -ne 0 ]; then
	steer_ci_error 'The open-question contract failed (see above). The format is in the steer spec framework (SPEC-FRAMEWORK.md, "Open-question format"); /steer:spec questions resolves questions.'
	exit 1
fi
printf 'Open-question contract holds across %s spec file(s).\n' "${checked}"

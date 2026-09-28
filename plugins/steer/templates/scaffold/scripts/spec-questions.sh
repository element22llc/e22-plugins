# shellcheck shell=sh
# steer helper - the open-question parser, one home for every reader of the
# `## Open questions` contract (templates/reference/SPEC-FRAMEWORK.md):
# check-open-questions.sh counts and ages what it emits, and
# scripts/convert-legacy-questions.sh rewrites exactly the legacy items it
# names, so the hook and the migration can never disagree on scope.
#
# Self-contained on purpose: POSIX sh + awk, no other lib, no CLAUDE_PLUGIN_ROOT.

# steer_questions_parse <file> - one tab-separated record per line, empty
# fields as "-" (IFS-tab `read` and awk both mishandle empty tab fields):
#   S \t <feature-status>      once, before any Q record (lowercased; "-" when
#                              the header has no Status line, e.g. vision.md)
#   Q \t id \t line \t status \t impact \t required_before \t owner \t created \t tracker \t title
#                              one per `### Q-NNN` block under "## Open questions"
#   P \t line \t id            an unfilled `<!-- steer:placeholder -->` seed block
#   L \t line \t text          a legacy `- [ ]` item: inside "## Open questions"
#                              and outside any `### ` block (a bullet inside a
#                              block belongs to that question); the old
#                              bracketed `[placeholder]` seed is skipped
#   N \t <max>                 once, last: the highest Q number any heading in
#                              the section uses, placeholders included, so a
#                              new id never collides
steer_questions_parse() {
	[ -f "$1" ] || return 0
	awk '
    function dash(v) { return v == "" ? "-" : v }
    function clean(v) { gsub(/\t/, " ", v); sub(/^[[:space:]]+/, "", v); sub(/[[:space:]]+$/, "", v); return v }
    function val(line, key,   v) { v = line; sub("^" key ":[[:space:]]*", "", v); sub(/[[:space:]].*$/, "", v); return v }
    function status_out() { if (!st_done) { printf "S\t%s\n", dash(st); st_done = 1 } }
    function endblock() {
      if (inblk) {
        if (skip) printf "P\t%d\t%s\n", q_line, dash(q_id)
        else printf "Q\t%s\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", dash(q_id), q_line, dash(q_status), dash(q_impact), dash(q_rb), dash(q_owner), dash(q_created), dash(q_tracker), dash(q_title)
      }
      inblk = 0; skip = 0; q_id = ""; q_line = 0; q_status = ""; q_impact = ""; q_rb = ""; q_owner = ""; q_created = ""; q_tracker = ""; q_title = ""
    }
    # Feature Status comes from the header only - the first Status line before
    # any "## Open questions", so the status bullet of a question never reads
    # as the feature status.
    !seen_oq && !st_got && tolower($0) ~ /^[>*#[:space:]]*status:/ {
      st = $0
      sub(/^[>*#[:space:]]*[Ss][Tt][Aa][Tt][Uu][Ss]:[[:space:]]*/, "", st)
      sub(/[[:space:]|].*$/, "", st)
      st = tolower(st); st_got = 1
    }
    /^## Open questions/ { endblock(); status_out(); seen_oq = 1; inq = 1; next }
    /^## / { endblock(); inq = 0 }
    /^# /  { endblock(); inq = 0 }
    inq && /^### / {
      endblock()
      inblk = 1
      skip = ($0 ~ /steer:placeholder/) ? 1 : 0
      q_line = FNR
      q_id = $0; sub(/^###[[:space:]]*/, "", q_id); sub(/[[:space:]].*$/, "", q_id)
      if (q_id ~ /^Q-[0-9]+$/) { n = substr(q_id, 3) + 0; if (n > max) max = n }
      q_title = $0
      sub(/^###[[:space:]]*[^[:space:]]*/, "", q_title)
      gsub(/<!--[^>]*-->/, "", q_title)
      sub(/^[[:space:]]*[-:][[:space:]]*/, "", q_title)
      q_title = clean(q_title)
      next
    }
    inq && inblk {
      line = $0
      sub(/^[[:space:]]*-[[:space:]]*/, "", line)
      if      (line ~ /^status:/)          q_status  = tolower(val(line, "status"))
      else if (line ~ /^impact:/)          q_impact  = tolower(val(line, "impact"))
      else if (line ~ /^required_before:/) q_rb      = val(line, "required_before")
      else if (line ~ /^owner:/)           q_owner   = tolower(val(line, "owner"))
      else if (line ~ /^created:/)         q_created = val(line, "created")
      else if (line ~ /^tracker:/)         q_tracker = val(line, "tracker")
    }
    inq && !inblk && /^- \[ \] / {
      rest = substr($0, 7)
      if (rest !~ /^\[/) printf "L\t%d\t%s\n", FNR, clean(rest)
    }
    END { endblock(); status_out(); printf "N\t%d\n", max + 0 }
  ' "$1"
}

# steer_questions_blame <root> <file> - "B \t <line> \t <epoch>" per committed
# line, from ONE whole-file `git blame` (never one call per question: a spine
# with eighty undated questions would otherwise spawn eighty blames at session
# start). Uncommitted lines (the all-zero sha) are omitted - they have no date
# yet. No git, or not a repo -> no output (fail-open: the caller treats the
# question as undated).
steer_questions_blame() {
	command -v git >/dev/null 2>&1 || return 0
	git -C "$1" blame --porcelain -- "$2" 2>/dev/null | awk '
    length($1) == 40 && $1 ~ /^[0-9a-f]+$/ && NF >= 3 { sha = $1; fl = $3; next }
    $1 == "author-time" { t[sha] = $2; next }
    /^\t/ { if (sha !~ /^0+$/ && (sha in t)) printf "B\t%d\t%s\n", fl, t[sha] }
  '
}

# STEER_AWK_CIVIL_FROM_DAYS - awk source for day-number (days since 1970-01-01,
# UTC) -> "YYYY-MM-DD", the inverse of lib/lifecycle.sh's days_from_civil. POSIX
# awk has no strftime, and `date -r` / `date -d @` split BSD from GNU.
# shellcheck disable=SC2034  # consumed by sourcing scripts, not this file
STEER_AWK_CIVIL_FROM_DAYS='
  function civil_from_days(z,   era, doe, yoe, y, doy, mp, d, m) {
    z += 719468
    era = int((z >= 0 ? z : z - 146096) / 146097)
    doe = z - era * 146097
    yoe = int((doe - int(doe / 1460) + int(doe / 36524) - int(doe / 146096)) / 365)
    y = yoe + era * 400
    doy = doe - (365 * yoe + int(yoe / 4) - int(yoe / 100))
    mp = int((5 * doy + 2) / 153)
    d = doy - int((153 * mp + 2) / 5) + 1
    m = mp + (mp < 10 ? 3 : -9)
    if (m <= 2) y++
    return sprintf("%04d-%02d-%02d", y, m, d)
  }'

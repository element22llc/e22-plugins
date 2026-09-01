#!/usr/bin/env sh
# scan-rule-drift.sh — read-only drift detector for the deferred repository rules.
#
# WHY THIS EXISTS
#   Claude Code caps a SessionStart hook's stdout at 10,000 characters, so steer
#   ships only its five always-on core rules through the hook. The other 30 are
#   copied into the managed repo as `.claude/rules/steer-*.md` and injected by
#   Claude Code itself when a file matching their `paths:` frontmatter is read.
#
#   That copy is the weak point. A repo adopted before a rule shipped, a rule
#   deleted by hand, an interrupted adopt, or a plugin update nobody synced all
#   leave the repo running on fewer standards than it believes — and, unlike the
#   hook payload, nothing in the session says so. This is what makes that
#   visible.
#
# WHAT IT READS
#   $1  repo-root    — the managed repo to inspect (default ".")
#   $2  plugin-root  — plugin source to compare against
#                      (default: $CLAUDE_PLUGIN_ROOT, else this script's parent)
#
# HOW IT CLASSIFIES (the point of the script)
#   Content comparison alone cannot separate "the plugin moved on" from "this
#   copy changed after installation" — both merely differ from what the plugin
#   ships, and the two demand opposite responses (replace vs. never silently
#   replace). So each installed file carries a banner recording a POSIX `cksum`
#   of its own body as steer wrote it (see scripts/gen_rule_banners.py).
#
#   THE STAMP IS DRIFT METADATA, NOT A SECURITY OR AUTHENTICITY BOUNDARY. It
#   establishes only that the body changed since install — never who or what
#   changed it (a person, a formatter, a merge, a script and a partial write are
#   indistinguishable), and anything that can edit the file can edit the stamp.
#   Its only job is to route a repair.
#
#     current   body is byte-identical to the plugin's        → nothing to do
#     absent    no such file in the repo                      → install it
#     stale     differs from the plugin, but the body still   → safe to replace
#               matches its own banner stamp, so nobody has
#               touched it since install: the plugin changed
#     edited    body no longer matches its own banner stamp   → NEVER overwrite;
#               i.e. it changed after installation               show a diff
#     orphan    a steer-*.md the plugin no longer ships       → propose removal
#
#   Comparing whole bytes rather than a digest is deliberate where it is
#   possible: the plugin source is on the same machine, so there is no reason to
#   compare digests of the content when the content itself is right there. The
#   stamp answers only the question bytes cannot: whether this copy has changed
#   since steer wrote it.
#
# WHETHER IT MODIFIES ANYTHING
#   No. Reads the repo + plugin source, writes status lines to stdout. A gap is
#   reported on stdout, NEVER as a nonzero exit, so a skill running this through
#   a Bash wrapper does not see a normal "drift found" run as a failure.
#
# OUTPUT (stdout)
#   One TAB-separated line per rule:  <file>\t<state>\t<detail>
#   then one summary line:            SUMMARY\t<current>/<want>\t<absent> absent, <stale> stale, <edited> edited, <orphan> orphan
#
# CONSTRAINTS (per repo CLAUDE.md): POSIX sh, no jq.

set -u

usage() {
	cat <<'EOF'
Usage: sh scan-rule-drift.sh [repo-root] [plugin-root]
Read-only. Reports per-rule drift state for .claude/rules/steer-*.md.
EOF
	exit 2
}

[ "$#" -le 2 ] || usage
case "${1:-}" in -h | --help) usage ;; esac

ROOT="${1:-.}"
HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
PLUGIN="${2:-${CLAUDE_PLUGIN_ROOT:-${HERE%/scripts}}}"

SRC="${PLUGIN}/templates/scaffold/claude/rules"
DST="${ROOT}/.claude/rules"

[ -d "${ROOT}" ] && [ -r "${ROOT}" ] || {
	echo "scan-rule-drift: cannot read repo-root: ${ROOT}" >&2
	exit 3
}
[ -d "${SRC}" ] || {
	echo "scan-rule-drift: no rule templates at ${SRC}" >&2
	exit 3
}

emit() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }

# Every byte except the banner line — exactly what gen_rule_banners.py stamps.
body_of() { grep -v '^<!-- steer:managed ' "$1"; }
body_cksum() { body_of "$1" | cksum | cut -d' ' -f1; }
# The cksum the banner claims. Empty when there is no banner (a hand-made file,
# or one predating the stamp) — treated as `edited`, the conservative side:
# never overwrite something whose recorded state cannot be established.
banner_cksum() {
	sed -n 's/^<!-- steer:managed .* body-cksum:\([0-9][0-9]*\) .*/\1/p' "$1" | head -n 1
}

n_current=0
n_absent=0
n_stale=0
n_edited=0
n_orphan=0
n_want=0

for src in "${SRC}"/steer-*.md; do
	[ -e "${src}" ] || continue
	name="$(basename "${src}")"
	n_want=$((n_want + 1))
	dst="${DST}/${name}"

	if [ ! -f "${dst}" ]; then
		emit "${name}" "absent" "not installed"
		n_absent=$((n_absent + 1))
		continue
	fi
	if [ "$(body_cksum "${src}")" = "$(body_cksum "${dst}")" ]; then
		emit "${name}" "current" "-"
		n_current=$((n_current + 1))
		continue
	fi
	claimed="$(banner_cksum "${dst}")"
	actual="$(body_cksum "${dst}")"
	if [ -n "${claimed}" ] && [ "${claimed}" = "${actual}" ]; then
		emit "${name}" "stale" "plugin changed this rule; repo copy untouched since install"
		n_stale=$((n_stale + 1))
	else
		emit "${name}" "edited" "changed after install — do not overwrite"
		n_edited=$((n_edited + 1))
	fi
done

# Orphans: a steer-*.md the plugin no longer ships (a rule retired or renamed).
if [ -d "${DST}" ]; then
	for dst in "${DST}"/steer-*.md; do
		[ -e "${dst}" ] || continue
		name="$(basename "${dst}")"
		[ -f "${SRC}/${name}" ] && continue
		emit "${name}" "orphan" "not shipped by this plugin version"
		n_orphan=$((n_orphan + 1))
	done
fi

printf 'SUMMARY\t%s/%s\t%s absent, %s stale, %s edited, %s orphan\n' \
	"${n_current}" "${n_want}" "${n_absent}" "${n_stale}" "${n_edited}" "${n_orphan}"
exit 0

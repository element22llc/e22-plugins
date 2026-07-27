#!/usr/bin/env sh
# ws.sh — polyrepo member driver for a workspace repo.
#
# Reads spec/workspace.yml (the member manifest) and does the mechanical
# multi-repo work the mise `ws:*` tasks expose: clone the members, fast-forward
# them, report their state, generate the VS Code multi-root workspace, and check
# the manifest against compose.yaml / .gitignore for drift.
#
# WHY IT SHIPS INTO THE REPO (not the plugin): `mise run ws:clone` has to work
# for a teammate with no Claude Code and no plugin checkout — the same reason
# scripts/scan-version-pins.sh is a committed copy.
#
# THE MANIFEST IS THE ONE SOURCE OF TRUTH. Nothing here invents a repo, a branch
# or a path, and nothing here rewrites a member's history: `sync` is
# fetch + fast-forward only and refuses a dirty tree, a detached HEAD, a branch
# other than the declared one, or a divergence. A member is yours to rebase, not
# this script's.
#
# spec/workspace.yml is a fixed-shape YAML the plugin ships (2-space `- name:`
# member items, 4-space scalar fields), so the awk parse below is reliable. It is
# NOT a general YAML parser — keep the manifest in the shipped shape.
#
# Usage: sh scripts/ws.sh <list|clone|sync|status|code|check>
set -eu

MANIFEST="spec/workspace.yml"
TAB=$(printf '\t')

die() {
	printf 'ws: %s\n' "$1" >&2
	exit 1
}

[ -f "${MANIFEST}" ] || die "no ${MANIFEST} — this is not a polyrepo workspace repo"

RECORDS=$(mktemp)
trap 'rm -f "${RECORDS}"' EXIT HUP INT TERM

# --- Manifest parsing -------------------------------------------------------

# ws_product_name — the `product.name` scalar (empty while still a placeholder).
ws_product_name() {
	awk '
    /^product:[[:space:]]*(#.*)?$/ { inp = 1; next }
    /^[A-Za-z]/ { inp = 0 }
    inp && /^  name:/ {
      line = $0
      sub(/^  name:[ \t]*/, "", line)
      sub(/[ \t]+#.*$/, "", line)
      gsub(/["]/, "", line)
      sub(/[ \t]+$/, "", line)
      print line
      exit
    }
  ' "${MANIFEST}"
}

# ws_members — one TAB-separated record per member:
#   name <TAB> repository <TAB> branch <TAB> profile <TAB> path
# Unset fields come through empty. A placeholder member (no name AND no
# repository — the state /steer:init leaves when the dev doesn't know the members
# yet) is dropped, so an unresolved manifest yields no work rather than errors.
ws_members() {
	awk '
    function clean(line, key) {
      sub("^(  - |    )" key ":[ \t]*", "", line)
      sub(/[ \t]+#.*$/, "", line)
      gsub(/["]/, "", line)
      sub(/[ \t]+$/, "", line)
      return line
    }
    function flush() {
      if (started && (name != "" || repo != ""))
        printf "%s\t%s\t%s\t%s\t%s\n", name, repo, branch, profile, path
      started = 0; name = ""; repo = ""; branch = ""; profile = ""; path = ""
    }
    /^members:[[:space:]]*(#.*)?$/ { inm = 1; next }
    /^[A-Za-z]/ { if (inm) flush(); inm = 0 }
    !inm { next }
    /^  -/ { flush(); started = 1 }
    !started { next }
    /^(  - |    )name:/       { name    = clean($0, "name");       next }
    /^(  - |    )repository:/ { repo    = clean($0, "repository"); next }
    /^(  - |    )branch:/     { branch  = clean($0, "branch");     next }
    /^(  - |    )profile:/    { profile = clean($0, "profile");    next }
    /^(  - |    )path:/       { path    = clean($0, "path");       next }
    END { flush() }
  ' "${MANIFEST}"
}

# ws_local_count — how many members declare a local `path:`.
ws_local_count() {
	ws_members | awk -F'\t' '$5 != "" { n++ } END { print n + 0 }'
}

# ws_slug <text> — lowercase, [a-z0-9-] only. Used for the generated filename.
ws_slug() {
	printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-' |
		sed 's/-\{1,\}/-/g;s/^-//;s/-$//'
}

# ws_remote <repository> — clone URL. A bare owner/repo becomes a GitHub HTTPS
# URL; anything already shaped like a URL or an scp-style remote is used verbatim.
ws_remote() {
	case "$1" in
	*://* | *@*:*) printf '%s' "$1" ;;
	*) printf 'https://github.com/%s.git' "$1" ;;
	esac
}

ws_require_members() {
	[ -n "$(ws_members)" ] ||
		die "no members resolved in ${MANIFEST} — resolve the placeholders first (/steer:init)"
}

# --- Subcommands ------------------------------------------------------------

cmd_list() {
	printf 'NAME\tREPOSITORY\tBRANCH\tPROFILE\tPATH\n'
	ws_members
}

# Both mutating subcommands read the member list from a temp FILE rather than a
# pipeline, so the loop runs in this shell and a per-member failure can be
# recorded and still let the remaining members be processed. One unreachable
# remote must never abort the rest of the sweep.
cmd_clone() {
	ws_require_members
	ws_members >"${RECORDS}"
	failed=0
	while IFS="${TAB}" read -r name repo branch _profile path; do
		if [ -z "${path}" ]; then
			printf 'skip    %-16s no `path:` — read over the GitHub gateway instead\n' "${name}"
			continue
		fi
		if [ -z "${repo}" ]; then
			printf 'skip    %-16s no `repository:` in the manifest\n' "${name}"
			continue
		fi
		if [ -d "${path}/.git" ]; then
			printf 'have    %-16s %s\n' "${name}" "${path}"
			continue
		fi
		if [ -e "${path}" ]; then
			printf 'BLOCKED %-16s %s exists and is not a git checkout — resolve it by hand\n' \
				"${name}" "${path}"
			failed=1
			continue
		fi
		printf 'clone   %-16s %s -> %s\n' "${name}" "${repo}" "${path}"
		remote=$(ws_remote "${repo}")
		if [ -n "${branch}" ]; then
			git clone --branch "${branch}" "${remote}" "${path}" || failed=1
		else
			git clone "${remote}" "${path}" || failed=1
		fi
		[ -d "${path}/.git" ] ||
			printf 'FAILED  %-16s clone failed — check access to %s\n' "${name}" "${repo}"
	done <"${RECORDS}"
	[ "${failed}" = 0 ] || die 'one or more members could not be cloned'
}

cmd_sync() {
	ws_require_members
	ws_members >"${RECORDS}"
	failed=0
	while IFS="${TAB}" read -r name _repo branch _profile path; do
		[ -n "${path}" ] && [ -d "${path}/.git" ] || continue
		current=$(git -C "${path}" symbolic-ref --short HEAD 2>/dev/null || printf 'DETACHED')
		if [ -n "$(git -C "${path}" status --porcelain)" ]; then
			printf 'dirty   %-16s uncommitted changes — not touching it\n' "${name}"
			continue
		fi
		[ -n "${branch}" ] || branch="${current}"
		if [ "${current}" != "${branch}" ]; then
			printf 'branch  %-16s on %s, manifest says %s — not switching it\n' \
				"${name}" "${current}" "${branch}"
			continue
		fi
		if ! git -C "${path}" fetch --quiet origin "${branch}" 2>/dev/null; then
			printf 'offline %-16s cannot reach origin — skipped\n' "${name}"
			failed=1
			continue
		fi
		if git -C "${path}" merge --ff-only --quiet "origin/${branch}" 2>/dev/null; then
			printf 'ok      %-16s %s at origin/%s\n' "${name}" "${branch}" "${branch}"
		else
			printf 'ahead   %-16s %s has diverged from origin/%s — merge or rebase it yourself\n' \
				"${name}" "${branch}" "${branch}"
		fi
	done <"${RECORDS}"
	[ "${failed}" = 0 ] || die 'one or more members could not be reached'
}

cmd_status() {
	printf '# Members (%s)\n' "${MANIFEST}"
	ws_members | while IFS="${TAB}" read -r name repo branch _profile path; do
		if [ -z "${path}" ]; then
			printf '  %-16s %-28s gateway-only (no `path:`)\n' "${name}" "${repo}"
			continue
		fi
		if [ ! -d "${path}/.git" ]; then
			printf '  %-16s %-28s NOT CLONED (mise run ws:clone)\n' "${name}" "${repo}"
			continue
		fi
		current=$(git -C "${path}" symbolic-ref --short HEAD 2>/dev/null || printf 'DETACHED')
		state=clean
		[ -n "$(git -C "${path}" status --porcelain)" ] && state=dirty
		drift=''
		if [ -n "${branch}" ] && [ "${current}" != "${branch}" ]; then
			drift=" (manifest: ${branch})"
		fi
		printf '  %-16s %-28s %s %s%s  spine=%s\n' "${name}" "${repo}" \
			"${current}" "${state}" "${drift}" \
			"$(cat "${path}/spec/.version" 2>/dev/null || printf -- '-')"
	done
	printf '\n# Workspace spine\n  spine=%s\n\n' "$(cat spec/.version 2>/dev/null || printf -- '-')"
	cmd_check
}

# cmd_code — generate the VS Code multi-root workspace from the manifest. The
# file is GENERATED and git-ignored (`*.code-workspace`): edit the manifest, not
# the output. A member with no `path:` is omitted — there is nothing local to open.
cmd_code() {
	ws_require_members
	slug=$(ws_slug "$(ws_product_name)")
	[ -n "${slug}" ] || slug=$(ws_slug "$(basename "$(pwd)")")
	[ -n "${slug}" ] || slug=workspace
	out="${slug}.code-workspace"
	{
		printf '{\n'
		printf '  "//": "GENERATED by `mise run ws:code` from spec/workspace.yml — do not edit.",\n'
		printf '  "folders": [\n'
		printf '    { "name": "spine", "path": "." }'
		ws_members | while IFS="${TAB}" read -r name _repo _branch _profile path; do
			[ -n "${path}" ] || continue
			printf ',\n    { "name": "%s", "path": "%s" }' "${name}" "${path}"
		done
		printf '\n  ]\n}\n'
	} >"${out}"
	printf 'wrote %s\n' "${out}"
}

# cmd_check — the manifest against the two files that must agree with it:
# compose.yaml `include:` (so `mise run dev` boots the whole product) and
# .gitignore (so a member's code never lands in the workspace's history).
# Advisory — it prints drift and exits 0. The manifest is the source of truth.
cmd_check() {
	printf '# Manifest consistency\n'
	if [ "$(ws_local_count)" = 0 ]; then
		printf '  (no member declares a local `path:` — nothing to boot or ignore here)\n'
		return 0
	fi
	ws_members | while IFS="${TAB}" read -r name _repo _branch _profile path; do
		[ -n "${path}" ] || continue
		if [ -f "${path}/compose.yaml" ] || [ -f "${path}/compose.yml" ]; then
			if grep -qF -- "${path}/compose" compose.yaml 2>/dev/null; then
				printf '  ok      %-16s compose include present\n' "${name}"
			else
				printf '  MISSING %-16s runs services but compose.yaml has no include: for %s\n' \
					"${name}" "${path}"
			fi
		fi
		if grep -qE "^/?${path}/?$" .gitignore 2>/dev/null; then
			printf '  ok      %-16s git-ignored\n' "${name}"
		else
			printf '  MISSING %-16s %s is NOT in .gitignore — its code would be committed here\n' \
				"${name}" "${path}"
		fi
	done
	return 0
}

case "${1:-}" in
list) cmd_list ;;
clone) cmd_clone ;;
sync) cmd_sync ;;
status) cmd_status ;;
code) cmd_code ;;
check) cmd_check ;;
*) die "usage: sh scripts/ws.sh <list|clone|sync|status|code|check>" ;;
esac

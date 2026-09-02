#!/usr/bin/env sh
# ws.sh — polyrepo member driver behind the mise `ws:*` tasks; spec/workspace.yml is the one source of truth.
# Usage: sh scripts/ws.sh <list|clone|sync|status|code|check|preflight>
# Ships into the repo (not the plugin) so `mise run ws:clone` works with no Claude Code and no plugin checkout.
# Rationale: /steer:reference polyrepo.
set -eu

MANIFEST="spec/workspace.yml"
TAB=$(printf '\t')

die() {
	printf 'ws: %s\n' "$1" >&2
	exit 1
}

# Member clones are git-ignored, so a linked worktree has none of them — expected, not drift.
ws_in_linked_worktree() {
	_wd=$(git rev-parse --git-dir 2>/dev/null) || return 1
	_wc=$(git rev-parse --git-common-dir 2>/dev/null) || return 1
	[ -n "${_wd}" ] && [ -n "${_wc}" ] && [ "${_wd}" != "${_wc}" ]
}

# At most once per run: `status` calls it, then delegates to `check`, which calls it too.
WS_NOTE_SHOWN=0
ws_worktree_note() {
	ws_in_linked_worktree || return 0
	[ "${WS_NOTE_SHOWN}" = 0 ] || return 0
	WS_NOTE_SHOWN=1
	printf '  NOTE    this is a linked worktree; member clones are git-ignored, so it has\n'
	printf '          none of them. Do spine work here and run the product from the primary\n'
	printf '          checkout, or `mise run ws:clone` here to get a second set of clones\n'
	printf '          (at the manifest branch, not this worktree'"'"'s).\n'
}

[ -f "${MANIFEST}" ] || die "no ${MANIFEST} — this is not a polyrepo workspace repo"

RECORDS=$(mktemp)
trap 'rm -f "${RECORDS}"' EXIT HUP INT TERM

# --- Manifest parsing (fixed-shape YAML the plugin ships — not a general parser) ---

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

# ws_members — one TAB-separated record per member: name repository branch profile path (unset fields empty).
# A placeholder member (no name AND no repository — what /steer:init leaves unresolved) is dropped, not errored.
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

ws_local_count() {
	ws_members | awk -F'\t' '$5 != "" { n++ } END { print n + 0 }'
}

# spec/.version is TWO lines (managed-by comment, then the version): extract the version, exactly as /steer:sync reads it.
ws_spine_version() {
	grep -m1 -oE '[0-9]+\.[0-9]+\.[0-9]+' "$1" 2>/dev/null || printf -- '-'
}

ws_slug() {
	printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9-' '-' |
		sed 's/-\{1,\}/-/g;s/^-//;s/-$//'
}

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

# clone/sync read members from a temp FILE, not a pipeline: the loop must run in this shell so one failed member never aborts the sweep.
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

# Fetch + fast-forward only; never rewrites a member's history.
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
			"$(ws_spine_version "${path}/spec/.version")"
	done
	ws_worktree_note
	printf '\n# Workspace spine\n  spine=%s\n\n' "$(ws_spine_version spec/.version)"
	cmd_check
}

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

# Advisory: prints manifest-vs-compose.yaml/.gitignore drift and exits 0.
cmd_check() {
	printf '# Manifest consistency\n'
	if [ "$(ws_local_count)" = 0 ]; then
		printf '  (no member declares a local `path:` — nothing to boot or ignore here)\n'
		return 0
	fi
	ws_members | while IFS="${TAB}" read -r name _repo _branch _profile path; do
		[ -n "${path}" ] || continue
		if grep -qE "^/?${path}/?$" .gitignore 2>/dev/null; then
			printf '  ok      %-16s git-ignored\n' "${name}"
		else
			printf '  MISSING %-16s %s is NOT in .gitignore — its code would be committed here\n' \
				"${name}" "${path}"
		fi
		# Say the compose check could not RUN rather than skip it silently — a skipped line reads as a pass.
		if [ ! -d "${path}" ]; then
			printf '  absent  %-16s not cloned at %s — compose-include check not run\n' \
				"${name}" "${path}"
			continue
		fi
		if [ -f "${path}/compose.yaml" ] || [ -f "${path}/compose.yml" ]; then
			if grep -qF -- "${path}/compose" compose.yaml 2>/dev/null; then
				printf '  ok      %-16s compose include present\n' "${name}"
			else
				printf '  MISSING %-16s runs services but compose.yaml has no include: for %s\n' \
					"${name}" "${path}"
			fi
		fi
	done
	ws_worktree_note
	return 0
}

# Diagnose the manifest and the checkouts BEFORE `docker compose config`, which fails identically for an absent checkout and a bad include:.
cmd_preflight() {
	ws_require_members
	if [ "$(ws_local_count)" = 0 ]; then
		die 'no member declares a local `path:` — there is nothing to boot here'
	fi
	ws_members >"${RECORDS}"
	missing=''
	while IFS="${TAB}" read -r name _repo _branch _profile path; do
		[ -n "${path}" ] || continue
		[ -d "${path}" ] || missing="${missing} ${name} (${path})"
	done <"${RECORDS}"
	if [ -n "${missing}" ]; then
		printf 'ws: member checkout(s) absent —%s\n' "${missing}" >&2
		if ws_in_linked_worktree; then
			printf 'ws: this is a linked worktree, and member clones are git-ignored, so it has\n' >&2
			printf 'ws: none of them. Boot the product from the primary checkout, or run\n' >&2
			printf 'ws: `mise run ws:clone` here for a second set of clones.\n' >&2
		else
			printf 'ws: run `mise run ws:clone` first.\n' >&2
		fi
		exit 1
	fi
	docker compose config >/dev/null 2>&1 ||
		die 'compose.yaml does not resolve — add one `include:` entry per member that runs local services (see the file header), or delete compose.yaml together with the ws:docker:* and ws:dev tasks'
}

case "${1:-}" in
list) cmd_list ;;
clone) cmd_clone ;;
sync) cmd_sync ;;
status) cmd_status ;;
code) cmd_code ;;
check) cmd_check ;;
preflight) cmd_preflight ;;
*) die "usage: sh scripts/ws.sh <list|clone|sync|status|code|check|preflight>" ;;
esac

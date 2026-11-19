#!/usr/bin/env sh
# scan-prereqs.sh - read-only local-prerequisite detector for /steer:setup doctor.
#
# WHAT IT READS
#   $1  repo-root  - a managed (or about-to-be-managed) repo to inspect
#                    (default: "."). Read only to resolve conditionality:
#                    compose.yaml -> is Docker required vs advisory;
#                    package.json / pyproject.toml -> whether pnpm and each
#                    language server applies.
#
# WHAT IT CHECKS
#   The host toolchain a repo needs before /steer:init, /steer:build, or
#   `mise run dev:setup` will work: git, mise (the gateway), Docker (+ daemon),
#   the mise-managed runtimes node / pnpm / uv, python3 (steer's own
#   scaffold_reconcile.py helper), gh (+ whether it holds a token), and the two
#   language servers plugin.json declares (pyright-langserver,
#   typescript-language-server). Detection is `command -v`, `docker version`
#   for the daemon and `gh auth token` (local, no network) - nothing is
#   installed or modified here.
#
# WHETHER IT MODIFIES ANYTHING
#   No. It only reads the host PATH + a few repo marker files and writes status
#   lines to stdout. The repo is never touched; no network; no jq.
#
# OUTPUT (stdout)
#   One leading fingerprint line:  os\t<darwin|linux|wsl2|windows|other>\t-
#   Then one TAB-separated line per tool:  <tool>\t<status>\t<detail>
#   status in ok | missing | down | via-mise | unmanaged | shadowed |
#             unauthenticated | n/a
#     ok          installed (detail = version line where cheap to read)
#     missing     not installed (a blocker for required tools)
#     down        docker installed but the daemon is not running
#     via-mise    runtime absent BUT mise is present -> `mise install` provides it
#     unmanaged   runtime absent AND mise absent -> install mise first
#     shadowed    runtime present but resolves to a NON-mise path while mise is
#                 present -> a global version manager (nvm/asdf/volta/fnm) or a
#                 system/Homebrew copy is masking mise's pinned runtime. Advisory,
#                 not a blocker: the tool runs, but it's the wrong (un-pinned) one.
#     unauthenticated  gh installed but holds no token. Advisory.
#     n/a         not applicable in this repo (pnpm or the TypeScript language
#                 server in a Python-only repo, the Python one in a Node-only repo)
#   `detail` carries requiredness for docker (required vs advisory) and marks
#   gh and the language servers advisory, so the caller can tell a blocker from
#   a nice-to-have. A gap is reported on STDOUT,
#   NEVER via a nonzero exit, so a skill running this through a Bash wrapper does
#   not see a normal "gaps found" run reported as a failure.
#
# EXIT CODES
#   0  ran OK - read stdout for the per-tool verdicts.
#   2  usage error - too many arguments.
#   3  repo-root is missing or unreadable.
#
# SECURITY: read-only; never executes repo content; no network; no jq.
#   Diagnostics name the path/tool, never file contents.
#
# Usage:
#   sh scan-prereqs.sh [repo-root]
#
# NOTE: this helper is plugin-internal (a /steer:setup doctor tool). It is deliberately
# NOT shipped into consumer repos, so it carries no byte-identical-copy
# obligation (same as scan-capabilities.sh / template-reconcile.sh).

set -u

usage() {
	echo "usage: scan-prereqs.sh [repo-root]" >&2
	exit 2
}

[ "$#" -le 1 ] || usage

ROOT="${1:-.}"

[ -d "$ROOT" ] && [ -r "$ROOT" ] || {
	echo "scan-prereqs: cannot read repo-root: $ROOT" >&2
	exit 3
}

emit() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }

have() { command -v "$1" >/dev/null 2>&1; }

# First line of `<tool> --version`, sanitized of stray tabs (keeps TAB output clean).
ver() { "$1" --version 2>/dev/null | head -n1 | tr '\t' ' '; }

# Does a resolved binary path look mise-managed? mise installs and shims both live
# under the mise data dir (default ~/.local/share/mise -> contains "/mise/"). A
# custom MISE_DATA_DIR without "mise" in the path won't match - acceptable, since
# the shadow verdict is advisory, not a blocker.
is_mise_path() {
	case "$1" in
	*/mise/*) return 0 ;;
	*) return 1 ;;
	esac
}

# Best-effort name of the version manager / source owning a non-mise binary path.
shadow_src() {
	case "$1" in
	*/.nvm/* | */nvm/*) printf 'nvm' ;;
	*/.volta/* | */volta/*) printf 'volta' ;;
	*/.asdf/* | */asdf/*) printf 'asdf' ;;
	*/.fnm/* | */fnm/*) printf 'fnm' ;;
	/opt/homebrew/* | /usr/local/* | /usr/bin/* | /bin/*) printf 'a system/Homebrew install' ;;
	*) printf 'a non-mise install' ;;
	esac
}

# --- os fingerprint (drives shell-install guidance + host support) ---
os=other
case "$(uname -s 2>/dev/null)" in
Darwin) os=darwin ;;
Linux)
	# STEER_PROC_VERSION lets the test harness stub the WSL probe; the host has no /proc/version to unset.
	if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft "${STEER_PROC_VERSION:-/proc/version}" 2>/dev/null; then
		os=wsl2
	else
		os=linux
	fi
	;;
MINGW* | MSYS* | CYGWIN*) os=windows ;;
esac
emit "os" "$os" "-"

# --- stack fingerprint (drives pnpm/uv applicability) ---
_node=false
_py=false
{ [ -f "$ROOT/package.json" ] || [ -f "$ROOT/pnpm-workspace.yaml" ]; } && _node=true
{ [ -f "$ROOT/pyproject.toml" ] || ls "$ROOT"/*/pyproject.toml >/dev/null 2>&1; } && _py=true

# --- git (always required) ---
if have git; then
	emit "git" "ok" "$(ver git)"
else
	emit "git" "missing" "required"
fi

# --- mise (always required - the gateway to every other runtime) ---
mise_present=false
if have mise; then
	mise_present=true
	emit "mise" "ok" "$(ver mise)"
else
	emit "mise" "missing" "required"
fi

# --- docker (required only when a compose file declares backing services) ---
# `docker version` answers the daemon question several times faster than `docker info`.
compose=false
for f in compose.yaml compose.yml docker-compose.yaml docker-compose.yml; do
	[ -f "$ROOT/$f" ] && compose=true && break
done
if $compose; then
	dreq="required (compose.yaml)"
else
	dreq="advisory (no compose.yaml)"
fi
if have docker; then
	if dsrv="$(docker version --format '{{.Server.Version}}' 2>/dev/null)" && [ -n "$dsrv" ]; then
		emit "docker" "ok" "running ($dsrv); $dreq"
	else
		emit "docker" "down" "daemon not running; $dreq"
	fi
else
	emit "docker" "missing" "$dreq"
fi

# True when the repo is only the OTHER language, so a $1-specific tool is n/a.
other_stack_only() {
	{ [ "$1" = "node" ] && $_py && ! $_node; } ||
		{ [ "$1" = "python" ] && $_node && ! $_py; }
}

# --- mise-managed runtimes ---
# Present -> ok. Absent but mise present -> via-mise (mise install provides it).
# Absent and mise absent -> unmanaged. node, python and uv are the scaffold's
# agent-runtime baseline, pinned even in a single-language repo, so only pnpm
# goes n/a by stack.
runtime() {
	# $1 tool, $2 stack it belongs to ("node"|""), $3 "noshadow" to skip the shadow check
	tool="$1"
	if other_stack_only "$2"; then
		emit "$tool" "n/a" "not used by this repo's stack"
		return
	fi
	if have "$tool"; then
		resolved="$(command -v "$tool" 2>/dev/null)"
		if [ "${3:-}" != "noshadow" ] && $mise_present && [ -n "$resolved" ] && ! is_mise_path "$resolved"; then
			emit "$tool" "shadowed" "$resolved ($(shadow_src "$resolved")) is masking mise's pinned $tool - run via 'mise exec -- $tool', and source 'mise activate' AFTER your version manager in the rc file"
		else
			emit "$tool" "ok" "$(ver "$tool")"
		fi
	elif $mise_present; then
		emit "$tool" "via-mise" "provided by 'mise install'"
	else
		emit "$tool" "unmanaged" "install mise first"
	fi
}
runtime node ""
runtime pnpm node
runtime uv ""
# Any python3 >= 3.7 runs scaffold_reconcile.py, so a system copy is not a shadow.
runtime python3 "" noshadow

# --- gh: the primary PR path; skills fall back to the GitHub MCP server, so advisory ---
if have gh; then
	if gh auth token >/dev/null 2>&1; then
		emit "gh" "ok" "$(ver gh); authenticated"
	else
		emit "gh" "unauthenticated" "advisory - no token; run 'gh auth login'"
	fi
elif $mise_present; then
	emit "gh" "via-mise" "advisory; provided by 'mise install' (github-cli)"
else
	emit "gh" "unmanaged" "advisory; install mise first"
fi

# --- language servers plugin.json declares; Claude Code warns when one is absent ---
# Never run them: pyright-langserver has no --version and waits on stdin.
lsp() {
	# $1 binary, $2 stack it serves
	if other_stack_only "$2"; then
		emit "$1" "n/a" "not used by this repo's stack"
	elif have "$1"; then
		emit "$1" "ok" "$(command -v "$1")"
	else
		emit "$1" "missing" "advisory (steer's $2 language server)"
	fi
}
lsp pyright-langserver python
lsp typescript-language-server node

exit 0

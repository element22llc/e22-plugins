#!/usr/bin/env sh
# scan-prereqs.sh — read-only local-prerequisite detector for /steer:doctor.
#
# WHAT IT READS
#   $1  repo-root  — a managed (or about-to-be-managed) repo to inspect
#                    (default: "."). Read only to resolve conditionality:
#                    compose.yaml -> is Docker required vs advisory;
#                    package.json / pyproject.toml -> which of pnpm/uv applies.
#
# WHAT IT CHECKS
#   The host toolchain a repo needs before /steer:init, /steer:build, or
#   `mise run dev:setup` will work: git, mise (the gateway), Docker (+ daemon),
#   and the mise-managed runtimes node / pnpm / uv. Detection is `command -v`
#   plus `docker info` for the daemon — nothing is installed or modified here.
#
# WHETHER IT MODIFIES ANYTHING
#   No. It only reads the host PATH + a few repo marker files and writes status
#   lines to stdout. The repo is never touched; no network; no jq.
#
# OUTPUT (stdout)
#   One leading fingerprint line:  os\t<darwin|linux|wsl2|windows|other>\t-
#   Then one TAB-separated line per tool:  <tool>\t<status>\t<detail>
#   status ∈ ok | missing | down | via-mise | unmanaged | n/a
#     ok          installed (detail = version line where cheap to read)
#     missing     not installed (a blocker for required tools)
#     down        docker installed but the daemon is not running
#     via-mise    runtime absent BUT mise is present -> `mise install` provides it
#     unmanaged   runtime absent AND mise absent -> install mise first
#     n/a         not applicable in this repo (e.g. docker with no compose.yaml,
#                 or pnpm in a Python-only repo)
#   `detail` also carries requiredness for docker (required vs advisory) so the
#   caller can tell a blocker from a nice-to-have. A gap is reported on STDOUT,
#   NEVER via a nonzero exit, so a skill running this through a Bash wrapper does
#   not see a normal "gaps found" run reported as a failure.
#
# EXIT CODES
#   0  ran OK — read stdout for the per-tool verdicts.
#   2  usage error — too many arguments.
#   3  repo-root is missing or unreadable.
#
# SECURITY: read-only; never executes repo content; no network; no jq.
#   Diagnostics name the path/tool, never file contents.
#
# Usage:
#   sh scan-prereqs.sh [repo-root]
#
# NOTE: this helper is plugin-internal (a /steer:doctor tool). It is deliberately
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

# --- os fingerprint (drives shell-install guidance + host support) ---
os=other
case "$(uname -s 2>/dev/null)" in
Darwin) os=darwin ;;
Linux)
	if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null; then
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

# --- mise (always required — the gateway to every other runtime) ---
mise_present=false
if have mise; then
	mise_present=true
	emit "mise" "ok" "$(ver mise)"
else
	emit "mise" "missing" "required"
fi

# --- docker (required only when a compose file declares backing services) ---
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
	if docker info >/dev/null 2>&1; then
		emit "docker" "ok" "running; $dreq"
	else
		emit "docker" "down" "daemon not running; $dreq"
	fi
else
	emit "docker" "missing" "$dreq"
fi

# --- mise-managed runtimes: node / pnpm / uv ---
# Present -> ok. Absent but mise present -> via-mise (mise install provides it).
# Absent and mise absent -> unmanaged. n/a when the stack is the other language.
runtime() {
	# $1 tool, $2 n/a-when ("python"|"node"|"")
	tool="$1"
	skip="$2"
	if { [ "$skip" = "python" ] && $_py && ! $_node; } ||
		{ [ "$skip" = "node" ] && $_node && ! $_py; }; then
		emit "$tool" "n/a" "not used by this repo's stack"
		return
	fi
	if have "$tool"; then
		emit "$tool" "ok" "$(ver "$tool")"
	elif $mise_present; then
		emit "$tool" "via-mise" "provided by 'mise install'"
	else
		emit "$tool" "unmanaged" "install mise first"
	fi
}
runtime node python
runtime pnpm python
runtime uv node

exit 0

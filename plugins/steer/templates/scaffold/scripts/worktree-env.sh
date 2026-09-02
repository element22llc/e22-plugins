# shellcheck shell=sh
# worktree-env.sh — per-worktree COMPOSE_PROJECT_NAME + host-port offset so parallel worktrees never collide.
# SOURCED by mise (`[env]._.source`), never executed: it must not `exit` or `set -e`; it only computes and exports.
# Rationale: the always-on "Parallel worktrees" rule; MIGRATIONS.md v3.24.0 for the naming scheme.

# A linked worktree is the one case where --git-dir differs from --git-common-dir. All lookups fail-soft.
_wt_root=$(git rev-parse --show-toplevel 2>/dev/null) || _wt_root=$PWD
_wt_gitdir=$(git rev-parse --git-dir 2>/dev/null) || _wt_gitdir=
_wt_common=$(git rev-parse --git-common-dir 2>/dev/null) || _wt_common=

if [ -n "$_wt_gitdir" ] && [ -n "$_wt_common" ] && [ "$_wt_gitdir" != "$_wt_common" ]; then
	_wt_linked=1
else
	_wt_linked=0
fi

if [ -n "${STEER_WORKTREE_OFFSET:-}" ]; then
	_wt_offset=$(printf '%s' "$STEER_WORKTREE_OFFSET" | tr -cd '0-9')
	[ -n "$_wt_offset" ] || _wt_offset=0
elif [ "$_wt_linked" = 1 ]; then
	# Stable slot 1..89 from the path (ports +10..+890); the slot space is shared by every repo on the machine.
	_wt_slot=$(printf '%s' "$_wt_root" | cksum | awk '{print ($1 % 89) + 1}')
	_wt_offset=$((_wt_slot * 10))
else
	_wt_offset=0
fi

# Compose project name: `<repo>-<worktree>` in a linked worktree — a bare worktree basename is not unique across repos, and a shared name let one repo's docker:clean tear down another's stack.
_wt_ident=$(basename "$_wt_root")
if [ "$_wt_linked" = 1 ]; then
	case "$_wt_common" in
	/*) _wt_owner=$(basename "$(dirname "$_wt_common")") ;;
	*) _wt_owner= ;;
	esac
	[ -n "$_wt_owner" ] && [ "$_wt_owner" != "/" ] && _wt_ident="${_wt_owner}-${_wt_ident}"
fi

_wt_name=$(printf '%s' "$_wt_ident" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_-' '-' | sed 's/-\{1,\}/-/g;s/^-//;s/-$//')
[ -n "$_wt_name" ] || _wt_name=app
export COMPOSE_PROJECT_NAME="$_wt_name"

# --- BASELINE: default-stack host ports (adapt to the product's services) ---
export POSTGRES_PORT=$((5432 + _wt_offset))
export WEB_PORT=$((3000 + _wt_offset))
# Dotenv loaders that don't override existing env vars (the default) leave this intact over .env.
export DATABASE_URL="postgresql://app:app@localhost:${POSTGRES_PORT}/app"

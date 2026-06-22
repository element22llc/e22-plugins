# shellcheck shell=sh
# worktree-env.sh — per-worktree runtime identity so parallel Claude Code
# worktrees of THIS repo never collide on Docker containers/volumes or host
# ports. SOURCED by mise (`[env]._.source` in mise.toml), so it runs for every
# `mise run …` and every activated shell.
#
# It is sourced, not executed: it must NOT `exit` (that would kill the parent
# shell) and must NOT `set -e`. It only computes and `export`s; it never fails
# the shell. The shebang is ignored (mise sources it in bash).
#
# How it works — a single OFFSET drives every host port:
#   - The primary checkout gets offset 0, so ports are unchanged (5432, 3000)
#     and nothing differs for the common single-checkout case.
#   - Each linked worktree (`.claude/worktrees/<name>`) gets a stable, non-zero
#     offset derived from its path, shifting every host port out of the primary
#     checkout's way. Same worktree → same ports on every run (idempotent).
#   - COMPOSE_PROJECT_NAME is set per worktree so containers/volumes/networks are
#     namespaced and `docker compose down -v` here tears down ONLY this stack.
#
# Escape hatch: if two worktrees happen to draw the same offset (host port
# already in use), export STEER_WORKTREE_OFFSET=<n> in your shell or
# `.mise.local.toml` to pin a distinct one; this script honors it.
#
# Adapt on fork (/steer:init): the BASELINE block exports the Postgres host
# port + DATABASE_URL. Add a line per extra host-published service you add to
# compose.yaml (Redis, MinIO, …), each as `base + OFFSET`, and shift your dev
# server with WEB_PORT.

# Worktree root + whether this is a linked worktree (--git-dir differs from the
# shared --git-common-dir only inside a linked worktree). All lookups fail-soft.
_wt_root=$(git rev-parse --show-toplevel 2>/dev/null) || _wt_root=$PWD
_wt_gitdir=$(git rev-parse --git-dir 2>/dev/null) || _wt_gitdir=
_wt_common=$(git rev-parse --git-common-dir 2>/dev/null) || _wt_common=

if [ -n "${STEER_WORKTREE_OFFSET:-}" ]; then
	# Explicit override wins (collision escape hatch). Strip any non-digits.
	_wt_offset=$(printf '%s' "$STEER_WORKTREE_OFFSET" | tr -cd '0-9')
	[ -n "$_wt_offset" ] || _wt_offset=0
elif [ -n "$_wt_gitdir" ] && [ -n "$_wt_common" ] && [ "$_wt_gitdir" != "$_wt_common" ]; then
	# Linked worktree: stable slot 1..89 from the path → ports +10..+890.
	_wt_slot=$(printf '%s' "$_wt_root" | cksum | awk '{print ($1 % 89) + 1}')
	_wt_offset=$((_wt_slot * 10))
else
	# Primary checkout (or not a git repo): no shift.
	_wt_offset=0
fi

# Compose project name: lowercased, sanitized worktree dir basename (compose
# requires [a-z0-9_-]). Isolates this worktree's containers/volumes/networks.
_wt_name=$(basename "$_wt_root" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_-' '-' | sed 's/-\{1,\}/-/g;s/^-//;s/-$//')
[ -n "$_wt_name" ] || _wt_name=app
export COMPOSE_PROJECT_NAME="$_wt_name"

# --- BASELINE: default-stack host ports (adapt to the product's services) ---
export POSTGRES_PORT=$((5432 + _wt_offset))
export WEB_PORT=$((3000 + _wt_offset))
# DATABASE_URL tracks POSTGRES_PORT so the app still connects inside a worktree.
# Processes launched via `mise run …` inherit this; dotenv loaders that don't
# override existing env vars (the default) leave it intact over .env.
export DATABASE_URL="postgresql://app:app@localhost:${POSTGRES_PORT}/app"

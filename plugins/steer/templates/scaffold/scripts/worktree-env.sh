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
#     In a linked worktree the name is `<repo>-<worktree>`, NOT the worktree
#     basename alone — see the naming block below for why that matters.
#
# Escape hatch: if two worktrees happen to draw the same offset (host port
# already in use), export STEER_WORKTREE_OFFSET=<n> in your shell or
# `.mise.local.toml` to pin a distinct one; this script honors it. The offset
# space is 89 slots wide and shared across every repo on the machine, so a
# polyrepo running many members × worktrees draws on it harder than a single
# repo does — a collision is a pinned offset, never an edit to a shared file.
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

if [ -n "$_wt_gitdir" ] && [ -n "$_wt_common" ] && [ "$_wt_gitdir" != "$_wt_common" ]; then
	_wt_linked=1
else
	_wt_linked=0
fi

if [ -n "${STEER_WORKTREE_OFFSET:-}" ]; then
	# Explicit override wins (collision escape hatch). Strip any non-digits.
	_wt_offset=$(printf '%s' "$STEER_WORKTREE_OFFSET" | tr -cd '0-9')
	[ -n "$_wt_offset" ] || _wt_offset=0
elif [ "$_wt_linked" = 1 ]; then
	# Linked worktree: stable slot 1..89 from the path → ports +10..+890.
	_wt_slot=$(printf '%s' "$_wt_root" | cksum | awk '{print ($1 % 89) + 1}')
	_wt_offset=$((_wt_slot * 10))
else
	# Primary checkout (or not a git repo): no shift.
	_wt_offset=0
fi

# --- Compose project name ----------------------------------------------------
# Identity is the directory basename for a primary checkout, and
# `<repo>-<worktree>` for a linked worktree.
#
# WHY the repo prefix: a worktree's basename is the worktree's own name (`feat-x`),
# which is NOT unique across repos. A polyrepo runs the same feature branch in
# several member repos at once, so `<memberA>/.claude/worktrees/feat-x` and
# `<memberB>/.claude/worktrees/feat-x` drew the SAME Compose project. Same project
# means the same containers, volumes and networks, so `mise run docker:clean`
# (`down --volumes --remove-orphans`) in one repo's worktree tore down the OTHER
# repo's stack — the precise failure this file exists to prevent. Distinct port
# offsets did not help: the collision is in the namespace, not the ports.
#
# The primary checkout keeps its bare basename, so its stack is NOT renamed and
# `docker compose down` there still finds containers started before this landed.
# A LINKED worktree's stack IS renamed (`<owner>-<worktree>`): if one is already
# running when this file is re-taken, tear it down FIRST (or `docker compose -p
# <old-name> down -v`) — under the new name compose no longer sees those
# containers or volumes and they are orphaned.
_wt_ident=$(basename "$_wt_root")
if [ "$_wt_linked" = 1 ]; then
	# $_wt_common is `<primary>/.git` (absolute inside a linked worktree), so the
	# owning repo is its parent's basename. Fail-soft: keep the bare basename if
	# the layout is anything else.
	case "$_wt_common" in
	/*) _wt_owner=$(basename "$(dirname "$_wt_common")") ;;
	*) _wt_owner= ;;
	esac
	[ -n "$_wt_owner" ] && [ "$_wt_owner" != "/" ] && _wt_ident="${_wt_owner}-${_wt_ident}"
fi

# Lowercase + sanitize (compose requires [a-z0-9_-]).
_wt_name=$(printf '%s' "$_wt_ident" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_-' '-' | sed 's/-\{1,\}/-/g;s/^-//;s/-$//')
[ -n "$_wt_name" ] || _wt_name=app
export COMPOSE_PROJECT_NAME="$_wt_name"

# --- BASELINE: default-stack host ports (adapt to the product's services) ---
export POSTGRES_PORT=$((5432 + _wt_offset))
export WEB_PORT=$((3000 + _wt_offset))
# DATABASE_URL tracks POSTGRES_PORT so the app still connects inside a worktree.
# Processes launched via `mise run …` inherit this; dotenv loaders that don't
# override existing env vars (the default) leave it intact over .env.
export DATABASE_URL="postgresql://app:app@localhost:${POSTGRES_PORT}/app"

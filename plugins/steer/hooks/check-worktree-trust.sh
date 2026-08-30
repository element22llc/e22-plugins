#!/usr/bin/env sh
# steer SessionStart + CwdChanged hook — inherit mise config trust into a linked
# worktree.
#
# WHY THIS EXISTS
#   `mise trust` is PATH-based and a linked worktree is a new path, so a freshly
#   created worktree is untrusted and EVERY `mise run …` fails there until someone
#   runs `mise trust`. The whole scaffolded dev loop is `mise run …` — `docker:up`,
#   `dev:setup`, `db:migrate`, the lint/test tasks — so the first thing an agent
#   does in a new worktree fails, with an error about trust rather than about the
#   task. Rule `24-worktrees` positions parallel worktrees as normal practice, and a
#   polyrepo runs one feature across several members at once, so the cost is one
#   trust step per member per feature (#416).
#
#   The trigger is the scaffold's OWN per-worktree isolation: mise loads a config
#   without trust when it can only declare data (`min_version`, plain `[tools]`
#   versions, `[tasks]`), and refuses one that executes code at load time — which is
#   exactly `[env] _.source = "scripts/worktree-env.sh"`, the line that gives each
#   worktree its own `COMPOSE_PROJECT_NAME` and port offset. The feature that makes
#   worktrees safe to run in parallel is what makes every new worktree untrusted.
#
#   Inheriting the primary checkout's trust grants NOTHING new. mise trust is
#   path-keyed and NOT content-hashed: a repo trusted once has every later edit of
#   its config trusted at that path, so anything this worktree's config could
#   execute, the primary checkout would already execute unprompted. Only the path
#   changed, and this hook copies the decision already made for it.
#
#   What it must never do is CREATE trust. When the primary checkout is itself
#   untrusted the repo has never been set up (`mise trust && mise install` — rule
#   `15-commands`), and that first decision belongs to the human: the hook names the
#   command and changes nothing.
#
# WHY IT ALSO RUNS ON CwdChanged
#   At SessionStart it can only cover a session that STARTED in a worktree. A
#   worktree entered mid-session — `EnterWorktree`, a subagent's
#   `isolation: worktree`, a background session — fires no SessionStart, so the
#   trust step was silently skipped for exactly the worktrees the agent creates
#   for itself. `CwdChanged` fires when the session moves into one.
#
#   Not `WorktreeCreate`, which looks like the precise event and cannot do this
#   job: it runs BEFORE the worktree exists on disk (its documented contract —
#   a hook may create the worktree itself there), and `mise trust -C <dir>` on a
#   path that does not exist yet fails outright. The trust decision can only be
#   copied once there is a path to copy it to.
#
#   Re-running is free: the FIRST cd into a worktree inherits the trust, and
#   every later one finds it already `trusted` and exits before doing anything.
#   A plain checkout — the overwhelmingly common case — never reaches `mise`.
#
# MECHANISM
#   stdout becomes session `additionalContext` — but ONLY on the SessionStart
#   path, via session-checks.sh. `SessionStart` is one of the four events whose
#   plain-text stdout the harness adds as context; `CwdChanged` is not, so on the
#   second registration stdout goes to the debug log and is not shown. The
#   `mise trust -C` SIDE EFFECT — the reason that registration exists — works on
#   both paths; what is lost mid-session is the two notices below that ask the
#   HUMAN to act (primary checkout has no mise config / is untrusted too). An
#   `exit 2` would surface stderr to the user on `CwdChanged`; routing those two
#   paths that way is a deliberate open question, not an oversight — see the
#   pre-release audit residue. Do not describe this hook's mid-session notices as
#   reaching the user until that lands.
#   (Upstream, verified verbatim:
#   https://docs.claude.com/en/docs/claude-code/hooks.md — "For most events,
#   Claude Code writes stdout to the debug log and doesn't show it in the
#   transcript. The exceptions are `UserPromptSubmit`, `UserPromptExpansion`,
#   `SessionStart`, and `PostModelSwitch`…", and the exit-code-2 row
#   "CwdChanged | No | Shows stderr to user only".)
#
#   Runs only in a LINKED worktree — resolved from the `.git` FILE's
#   `gitdir:` pointer by steer_primary_worktree, no subprocess — so a plain checkout,
#   the overwhelmingly common case, exits before `mise` is ever invoked and pays
#   nothing. `mise trust --show` is the authority on both trust states (it prints one
#   `<dir>: trusted|untrusted` line per config directory); this hook never inspects
#   the trust store itself. Trust is applied with `mise trust -C <worktree>`, which
#   marks the DIRECTORY — covering `mise.toml` and any `mise.local.toml` carried in
#   by `.worktreeinclude` — and is exactly what a human typing `mise trust` there
#   would do.
#
#   SILENT unless it acted or has something a human must do: a plain checkout, a
#   machine without mise, an already-trusted worktree, and a worktree with no mise
#   config at all all print nothing.
#
# CONSTRAINTS (per repo CLAUDE.md)
#   POSIX sh, no jq. Invoked via an explicit `sh` prefix, so the executable bit does
#   not matter. cwd comes from the SessionStart payload and may be a subdir. Fail
#   soft: any ambiguity → stay silent and change nothing.

. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/json.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"

# shellcheck disable=SC2034  # consumed by steer_field (lib/json.sh) via $STEER_INPUT
STEER_INPUT="$(cat 2>/dev/null)"
CWD="$(steer_field cwd)"
[ -n "${CWD}" ] || CWD="."

ROOT="$(steer_repo_root "${CWD}")" || exit 0
PRIMARY="$(steer_primary_worktree "${ROOT}")"

# Only a linked worktree has a different primary. A plain checkout stops here,
# before any subprocess.
[ -n "${PRIMARY}" ] && [ "${PRIMARY}" != "${ROOT}" ] || exit 0

command -v mise >/dev/null 2>&1 || exit 0

# steer_trust_state <dir> — 'trusted' / 'untrusted' / '' (no config there).
# `mise trust --show` lists the directory of every config on the path, ancestors
# included, so the line must be matched on the EXACT directory.
steer_trust_state() {
	mise trust --show -C "$1" 2>/dev/null | while IFS= read -r _line; do
		case "${_line}" in
		"$1: trusted")
			printf 'trusted'
			break
			;;
		"$1: untrusted")
			printf 'untrusted'
			break
			;;
		esac
	done
}

WT_STATE="$(steer_trust_state "${ROOT}")"

# Nothing to inherit: no mise config in this worktree, or it is already trusted
# (a resumed session, or a human who already ran `mise trust` here).
[ "${WT_STATE}" = "untrusted" ] || exit 0

PRIMARY_STATE="$(steer_trust_state "${PRIMARY}")"

if [ "${PRIMARY_STATE}" != "trusted" ]; then
	printf '<!-- steer: worktree mise trust -->\n'
	printf '# `mise run …` will fail in this worktree until its config is trusted\n\n'
	printf 'This is a linked worktree, and `mise trust` is path-based — this path is '
	printf 'untrusted, so every `mise run …` here fails with a trust error rather than '
	printf 'a task error. steer inherits that trust from the primary checkout, but '
	if [ -z "${PRIMARY_STATE}" ]; then
		# The worktree's branch introduced the mise config; the primary checkout has
		# none, so there is no prior decision about this file anywhere.
		printf 'the primary checkout (`%s`) has **no mise config at all**, so there ' "${PRIMARY}"
		printf 'is no trust decision to inherit — this config is new on this branch.\n\n'
		printf 'Ask the user to run **`mise trust`** here; trusting a config for the '
		printf 'first time is theirs to decide, not yours.\n'
	else
		printf 'the primary checkout (`%s`) is **not trusted either**, so there is ' "${PRIMARY}"
		printf 'no decision to inherit — this repo has not been set up yet.\n\n'
		printf 'Tell the user to run **`mise trust && mise install`** in the primary '
		printf 'checkout (rule `15-commands`, first-time setup); trusting a repo for '
		printf 'the first time is theirs to decide, not yours. A new session in this '
		printf 'worktree then inherits it, or run `mise trust` here once the primary '
		printf 'is trusted.\n'
	fi
	exit 0
fi

mise trust -q -C "${ROOT}" >/dev/null 2>&1 || {
	printf '<!-- steer: worktree mise trust -->\n'
	printf '# Could not inherit mise trust for this worktree\n\n'
	printf '`mise trust -C %s` failed, so `mise run …` here will still fail with a ' "${ROOT}"
	printf 'trust error. Run `mise trust` in this worktree and report the error if it '
	printf 'persists.\n'
	exit 0
}

printf '<!-- steer: worktree mise trust -->\n'
printf 'steer: inherited the primary checkout'"'"'s `mise trust` for this worktree '
printf '(a linked worktree is a new path, so mise treated its config as untrusted '
printf 'and every `mise run …` would have failed). `mise run …` works here now — no '
printf 'action needed.\n'

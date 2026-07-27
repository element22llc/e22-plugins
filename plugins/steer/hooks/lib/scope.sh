# shellcheck shell=sh
# steer hook helper — rule-injection scope predicates.
#
# inject-standards.sh injects the always-on ruleset every session. A rule may
# carry a first-line marker `<!-- steer:inject-when=<token> -->` declaring that
# it is only relevant in a specific repo context; this helper evaluates those
# tokens against the consumer repo so the hook can skip an inapplicable rule
# (e.g. issue-first on a non-GitHub repo) and reclaim that context budget.
#
# Fail-open is the rule here: an always-on safety ruleset must never silently
# DROP a rule on an unreadable signal or an unrecognized token. Every predicate
# degrades to "inject" (return 0) when it cannot prove the rule is out of scope.

# steer_tracker_is_github <repo-root> — true when the repo's /spec/tracker.md
# declares `system: github`. Single source of truth for GitHub-tracker
# detection, shared with the issue-first hooks (check-write-nudges.sh,
# reconcile-issue-first.sh) and the inject-when scope dispatch below.
#
# A polyrepo MEMBER has no local spec/tracker.md — the tracker is product-level
# and lives in the workspace by design (templates/reference/POLYREPO.md), which
# is precisely where all the code sits. Reading the absence as "not GitHub"
# therefore switched issue-first enforcement OFF in exactly those repos: rule
# 36-issue-first stopped injecting and check-write-nudges.sh /
# check-bash-actions.sh / reconcile-issue-first.sh all exited early. So a member
# resolves the workspace's tracker when spec/PRODUCT.md names a local checkout,
# and otherwise degrades to "inject" per this file's fail-open contract — a
# needless nudge is recoverable, a silently-absent gate is not.
steer_tracker_is_github() {
	_root="${1:-.}"
	_tracker="${_root}/spec/tracker.md"
	if [ ! -f "${_tracker}" ]; then
		# Not a member either → genuinely no tracker declared (single-repo case,
		# unchanged): the rule is provably out of scope.
		[ -f "${_root}/spec/PRODUCT.md" ] || return 1
		_wsp="$(steer_workspace_path "${_root}")" || return 0
		_tracker="${_root}/${_wsp}/spec/tracker.md"
		[ -f "${_tracker}" ] || return 0
	fi
	# `github\b` (word boundary, as scripts/scan-capabilities.sh uses) so a value
	# that merely STARTS with github (e.g. `system: githubbish`) never matches.
	grep -iq '^[[:space:]]*system:[[:space:]]*github\b' "${_tracker}" 2>/dev/null
}

# steer_workspace_path <repo-root> — prints the OPTIONAL relative path to a local
# workspace checkout, read from spec/PRODUCT.md's `workspace.path`; nothing when
# the file, the key, or the value is absent, or the value is still the unresolved
# "[...]" placeholder. Scoped to the `workspace:` block so an unrelated `path:`
# elsewhere in the pointer can never be mistaken for it. No network and no
# subprocess beyond sed — this file is sourced by every PreToolUse hook.
steer_workspace_path() {
	_pm="${1:-.}/spec/PRODUCT.md"
	[ -f "${_pm}" ] || return 1
	_v="$(sed -n '/^workspace:/,/^[^[:space:]#]/{s/^[[:space:]][[:space:]]*path:[[:space:]]*//p;}' "${_pm}" 2>/dev/null | head -n 1)"
	# Strip a trailing inline comment and surrounding quotes/whitespace, matching
	# steer_tracker_repo's idiom.
	_v="${_v%%#*}"
	_v="$(printf '%s' "${_v}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/^"//; s/"$//')"
	case "${_v}" in
	'' | '['*) return 1 ;;
	esac
	printf '%s' "${_v}"
}

# steer_tracker_repo <repo-root> — prints the tracker's declared `repository:`
# value from spec/tracker.md ("owner/name" for GitHub), or nothing when absent,
# empty, or still the unresolved "[owner/repository]" placeholder.
steer_tracker_repo() {
	_tr="${1:-.}/spec/tracker.md"
	[ -f "${_tr}" ] || return 1
	_v="$(sed -n 's/^[[:space:]]*repository:[[:space:]]*//p' "${_tr}" 2>/dev/null | head -n 1)"
	# Strip a trailing inline comment and surrounding quotes/whitespace.
	_v="${_v%%#*}"
	_v="$(printf '%s' "${_v}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/^"//; s/"$//')"
	case "${_v}" in
	'' | '['*) return 1 ;;
	esac
	printf '%s' "${_v}"
}

# NOTE — there is deliberately NO companion helper that derives this repo's own
# "owner/name" from the git remote. Deriving it by parsing `git remote get-url`
# is unreliable in exactly the setups that matter: a `url.<base>.insteadOf`
# rewrite (corporate proxies, ssh-for-https) makes git report a URL with no
# github.com host in it at all, and GitHub Enterprise, a remote not named
# `origin`, and a bare clone each break a host-based parser differently. Every
# one of those failures is a FALSE NEGATIVE — the parser cannot prove a mismatch,
# so the caller keeps `Closes #N` and the silent-non-closure bug survives in the
# environments hardest to debug.
#
# The comparison therefore lives in the skills (`/steer:work`,
# `/steer:tracker-sync`), which resolve the current repo authoritatively via
# `gh repo view --json nameWithOwner` — correct under rewrites, GHE, and any
# remote name — and which are already talking to GitHub anyway. Keeping the `gh`
# call out of this file also preserves its contract: sourced by every PreToolUse
# hook, so no subprocess and no network.

# steer_repo_does_iac <repo-root> — true when the repo does infrastructure-as-code,
# whether as the whole repo (a root-level Terraform/OpenTofu/Ansible/Pulumi repo,
# the infra profile) OR as a nested `/infra` dir inside an app monorepo. Broader
# than the `has-infra` (nested-`/infra`-only) predicate: a pure Ansible repo keeps
# its playbooks/roles at the root and has no `/infra` dir, so `has-infra` misses it.
# Ground-truth filesystem check, subprocess-free except cheap globs.
steer_repo_does_iac() {
	_r="${1:-.}"
	[ -d "${_r}/infra" ] && return 0
	[ -f "${_r}/ansible.cfg" ] && return 0
	[ -f "${_r}/site.yml" ] || [ -f "${_r}/site.yaml" ] && return 0
	[ -f "${_r}/Pulumi.yaml" ] && return 0
	[ -d "${_r}/roles" ] && [ -d "${_r}/playbooks" ] && return 0
	# Root-level Terraform / OpenTofu / Terragrunt files. `find` (not a shell glob)
	# so detection is identical under POSIX sh and zsh — an unguarded `for _f in
	# *.tf` aborts the caller under zsh's `nomatch`, and a bare `ls *.tf` leaks a
	# "no matches found" error there.
	find "${_r}" -maxdepth 1 \( -name '*.tf' -o -name '*.hcl' \) 2>/dev/null | grep -q . && return 0
	return 1
}

# steer_polyrepo_role <repo-root> — prints the repo's role in a polyrepo product,
# or nothing when the product lives in a single repo (the overwhelmingly common
# case, and the one that must cost zero always-on bytes):
#
#   workspace  a `spec/workspace.yml` member manifest — this repo hosts THE
#              product `/spec` spine and owns no application code.
#   member     a `spec/PRODUCT.md` pointer — this repo implements part of a
#              product whose spine lives in a sibling workspace repo.
#   (empty)    neither marker → a single-repo product.
#
# Both markers live under `spec/` on purpose. The manifest is product-level truth
# — which repos this product is made of — so it belongs with the rest of the
# spine, not loose at the root where it would be steer's only unnamespaced root
# file and would sit a rename away from moon's `.moon/workspace.yml`.
#
# Ground-truth filesystem check on two files, mirroring the has-* predicates: the
# topology is derived from disk, never from the CLAUDE.md profile marker, so the
# two can no more disagree here than they can for has-apps / has-infra. A repo
# carrying BOTH files is malformed; workspace wins (the manifest is the stronger,
# harder-to-create signal) and /steer:audit reports the contradiction.
steer_polyrepo_role() {
	_r="${1:-.}"
	[ -f "${_r}/spec/workspace.yml" ] && {
		printf 'workspace'
		return 0
	}
	[ -f "${_r}/spec/PRODUCT.md" ] && {
		printf 'member'
		return 0
	}
	return 1
}

# steer_inject_when_one <token> <repo-root> — true / false for a SINGLE
# inject-when predicate. An unknown token → fail-open (true), so a typo'd marker
# never silently removes a rule from the always-on context.
steer_inject_when_one() {
	case "$1" in
	tracker-github) steer_tracker_is_github "$2" ;;
	has-infra) [ -d "$2/infra" ] ;;
	has-iac) steer_repo_does_iac "$2" ;;
	has-apps) [ -d "$2/apps" ] || [ -f "$2/package.json" ] || [ -f "$2/pnpm-workspace.yaml" ] ;;
	has-compose) [ -f "$2/compose.yaml" ] || [ -f "$2/compose.yml" ] ;;
	# polyrepo — true in EITHER role (workspace host or member); a single-repo
	# product matches neither and pays nothing. NOTE: no rule currently carries
	# `inject-when=polyrepo`, so this arm is not reachable from the inject loop.
	# That is deliberate, not an oversight: the ruleset is capped on its on-disk
	# total, which every consumer pays even for a rule scoped to a minority of
	# repos, so the topology is delivered by orient-session.sh (a SessionStart
	# note) and /steer:reference polyrepo instead. The predicate is kept because
	# the has-* tokens beside it are evaluated the same way and a future scoped
	# rule must not have to reintroduce it. Do NOT document a `21-polyrepo` rule
	# on the strength of this token — there isn't one.
	polyrepo) steer_polyrepo_role "$2" >/dev/null ;;
	has-workspace-manifest) [ -f "$2/spec/workspace.yml" ] ;;
	has-product-pointer) [ -f "$2/spec/PRODUCT.md" ] ;;
	# code-project — true in 'code' work mode. The knowledge-vs-code decision is
	# made ONCE in inject-standards.sh (steer_work_mode) and a knowledge folder
	# skips EVERY marked rule in the inject loop before this predicate is reached,
	# so by the time this arm runs we are in code mode → always inject. (The `*)`
	# default below would also inject; the explicit arm documents the token.)
	code-project) return 0 ;;
	*) return 0 ;;
	esac
}

# steer_work_mode <cwd> — prints 'code' or 'knowledge'.
#
# 'knowledge' is emitted ONLY when we are confident this is a non-code
# knowledge-work folder — the typical Claude Cowork case where a product owner
# opens a connected folder of specs/docs that is NOT a git repo. In that mode
# inject-standards.sh injects only the lean, PO-relevant ruleset (it skips every
# rule that carries an inject-when marker) and orient-session.sh confirms, in
# plain language, that standards are active.
#
# 'code' is the fail-safe default: a git work tree (here or any ancestor) OR any
# code/config marker — a manifest/build/IaC file OR a loose SOURCE file (*.py,
# *.js, …) — within cwd (maxdepth 2) OR any error/doubt → 'code', i.e. the full
# ruleset. Per this file's contract we never silently DROP a rule on an
# unreadable signal, so every uncertain path resolves to 'code'. The source-file
# extensions matter because a non-git code folder may carry no manifest at all
# (loose scripts) — manifest-only detection would mis-classify it as knowledge.
# Residual limitation: a non-git code project whose ONLY markers sit deeper than
# maxdepth 2 still reads as knowledge — open it as a git repo (or add a manifest)
# to get the full ruleset.
#
# POSIX sh, no jq. Computed once per session (SessionStart), not on a hot path.
# `find` (never a shell glob — a bare `*.tf` aborts the caller under zsh nomatch);
# no `-L`, so symlinks are not followed. Note: `spec/` is deliberately NOT a code
# marker — a knowledge folder is exactly where a /spec spine may live.
steer_work_mode() {
	_cwd="${1:-.}"
	# A git work tree at cwd or above → treat as a code project.
	steer_repo_root "${_cwd}" >/dev/null 2>&1 && {
		printf 'code'
		return 0
	}
	# No git. Scan shallowly for code/config markers — manifests, build/IaC files,
	# AND loose source files. Capture find's own exit status (command substitution
	# propagates it) so a find ERROR fails safe to 'code' rather than being
	# mistaken for "no markers found".
	_markers="$(find "${_cwd}" -maxdepth 2 \( \
		-type f \( \
		-name 'package.json' -o -name 'pnpm-workspace.yaml' -o -name 'mise.toml' \
		-o -name 'pyproject.toml' -o -name 'go.mod' -o -name 'Cargo.toml' \
		-o -name 'pom.xml' -o -name 'build.gradle' -o -name 'build.gradle.kts' \
		-o -name 'Gemfile' -o -name 'requirements.txt' -o -name '*.csproj' \
		-o -name '*.tf' -o -name '*.hcl' -o -name 'ansible.cfg' -o -name 'Pulumi.yaml' \
		-o -name 'compose.yaml' -o -name 'compose.yml' -o -name 'Dockerfile' \
		-o -name 'Makefile' \
		-o -name '*.py' -o -name '*.js' -o -name '*.ts' -o -name '*.tsx' \
		-o -name '*.jsx' -o -name '*.go' -o -name '*.rs' -o -name '*.java' \
		-o -name '*.rb' -o -name '*.php' -o -name '*.c' -o -name '*.h' \
		-o -name '*.cpp' -o -name '*.cs' -o -name '*.swift' -o -name '*.kt' \
		-o -name '*.sh' -o -name '*.sql' -o -name '*.vue' -o -name '*.svelte' \) \
		-o -type d \( -name 'src' -o -name 'infra' -o -name '.claude-plugin' \) \
		\) 2>/dev/null)" || {
		printf 'code'
		return 0
	}
	[ -n "${_markers}" ] && {
		printf 'code'
		return 0
	}
	printf 'knowledge'
}

# steer_inject_when_ok <token-expr> <repo-root> — true (inject the rule) / false
# (skip it) for a rule's inject-when marker. <token-expr> is one predicate, or
# several joined by `|` for OR: the rule injects when ANY listed predicate holds
# (e.g. has-iac|has-apps for the deployment rule, which applies to infra and
# app/service repos alike). Empty root → fail-open (inject), so a missing cwd
# never silently removes a rule.
steer_inject_when_ok() {
	_token="$1"
	_root="${2:-}"
	[ -n "${_root}" ] || return 0
	_save_ifs="${IFS}"
	IFS='|'
	for _t in ${_token}; do
		IFS="${_save_ifs}"
		steer_inject_when_one "${_t}" "${_root}" && return 0
		IFS='|'
	done
	IFS="${_save_ifs}"
	return 1
}

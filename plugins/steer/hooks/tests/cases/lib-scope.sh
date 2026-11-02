#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# ----- scope.sh: trait predicates + repo-root.sh: profile reader -----
. "${HOOKS}/lib/scope.sh"
. "${HOOKS}/lib/repo-root.sh"

TRAITS_INFRA="$(new_repo traits_infra)"
mkdir -p "${TRAITS_INFRA}/infra"
steer_inject_when_ok has-infra "${TRAITS_INFRA}" && ok || bad "scope: has-infra true when /infra exists"
steer_inject_when_ok has-iac "${TRAITS_INFRA}" && ok || bad "scope: has-iac true when /infra exists"
steer_inject_when_ok has-apps "${TRAITS_INFRA}" && bad "scope: has-apps false for infra repo" || ok

TRAITS_ANSIBLE="$(new_repo traits_ansible)"
printf 'x\n' >"${TRAITS_ANSIBLE}/ansible.cfg"
steer_inject_when_ok has-iac "${TRAITS_ANSIBLE}" && ok || bad "scope: has-iac true for root ansible.cfg"
steer_inject_when_ok has-infra "${TRAITS_ANSIBLE}" && bad "scope: has-infra false without /infra dir" || ok

TRAITS_TF="$(new_repo traits_tf)"
printf 'terraform {}\n' >"${TRAITS_TF}/main.tf"
steer_inject_when_ok has-iac "${TRAITS_TF}" && ok || bad "scope: has-iac true for root *.tf"

TRAITS_APP="$(new_repo traits_app)"
printf '{}\n' >"${TRAITS_APP}/package.json"
printf 'services:\n' >"${TRAITS_APP}/compose.yaml"
steer_inject_when_ok has-apps "${TRAITS_APP}" && ok || bad "scope: has-apps true with package.json"
steer_inject_when_ok has-compose "${TRAITS_APP}" && ok || bad "scope: has-compose true with compose.yaml"
TRAITS_LEGACY_COMPOSE="$(new_repo traits_legacy_compose)"
printf 'services:\n' >"${TRAITS_LEGACY_COMPOSE}/docker-compose.yml"
steer_inject_when_ok has-compose "${TRAITS_LEGACY_COMPOSE}" && ok || bad "scope: has-compose true with legacy docker-compose.yml"
steer_inject_when_ok has-compose "${TRAITS_ANSIBLE}" && bad "scope: has-compose false without a compose file" || ok
steer_inject_when_ok has-iac "${TRAITS_APP}" && bad "scope: has-iac false for plain app repo" || ok

# automation-optin is the one FAIL-CLOSED predicate: rule 53 governs machinery a
# repo only has once it declares it, so absence must skip the rule rather than
# inject it (the fail-open default every other token takes).
TRAITS_NOLOOP="$(new_repo traits_noloop)"
steer_inject_when_ok automation-optin "${TRAITS_NOLOOP}" &&
	bad "scope: automation-optin false without policy/automation.yml" || ok
mkdir -p "${TRAITS_NOLOOP}/policy"
printf 'loops: false\n' >"${TRAITS_NOLOOP}/policy/automation.yml"
steer_inject_when_ok automation-optin "${TRAITS_NOLOOP}" &&
	bad "scope: automation-optin false when loops: false" || ok
printf 'schema: 1\nloops: true\n' >"${TRAITS_NOLOOP}/policy/automation.yml"
steer_inject_when_ok automation-optin "${TRAITS_NOLOOP}" && ok ||
	bad "scope: automation-optin true when loops: true"

# tracker-github matches the WORD github (`github\b`, #339), never a value that
# merely starts with it - `system: githubbish` is not a GitHub tracker.
TRAITS_GHISH="$(new_repo traits_ghish)"
mkdir -p "${TRAITS_GHISH}/spec"
printf 'system: githubbish\n' >"${TRAITS_GHISH}/spec/tracker.md"
steer_tracker_is_github "${TRAITS_GHISH}" && bad "scope: tracker-github must reject system: githubbish" || ok
TRAITS_GH="$(new_repo traits_gh)"
mkdir -p "${TRAITS_GH}/spec"
printf 'system: github\n' >"${TRAITS_GH}/spec/tracker.md"
steer_tracker_is_github "${TRAITS_GH}" && ok || bad "scope: tracker-github true for system: github"

# A repo with NO tracker and NO member pointer is the single-repo case: the rule
# is provably out of scope and must stay skipped (unchanged contract).
TRAITS_NOTRK="$(new_repo traits_notrk)"
printf '{}\n' >"${TRAITS_NOTRK}/package.json"
steer_tracker_is_github "${TRAITS_NOTRK}" && bad "scope: tracker-github false with no tracker at all" || ok

# ----- polyrepo member: the tracker is the WORKSPACE's, never local -----
# A member's spec/tracker.md is absent BY DESIGN, so reading that absence as
# "not GitHub" switched issue-first enforcement off in the repos holding all the
# code. With no local workspace checkout declared, the predicate must fail OPEN.
TRAITS_MEMNP="$(new_repo traits_memnp)"
mkdir -p "${TRAITS_MEMNP}/spec"
printf 'workspace:\n  repository: acme/product-spine\n  branch: main\n' \
	>"${TRAITS_MEMNP}/spec/PRODUCT.md"
steer_tracker_is_github "${TRAITS_MEMNP}" && ok || bad "scope: member with no local checkout must fail open"
steer_inject_when_ok tracker-github "${TRAITS_MEMNP}" && ok || bad "scope: 36-issue-first must inject in a member"

# With `workspace.path` naming a real local checkout, the workspace's tracker is
# authoritative - both directions. `spec/workspace.yml` is what makes the target a
# workspace, so the fixture carries it (steer_workspace_root requires it).
TRAITS_MEMWS="$(new_repo traits_memws)"
mkdir -p "${TRAITS_MEMWS}/ws/spec" "${TRAITS_MEMWS}/member/spec"
printf 'members:\n  - name: member\n' >"${TRAITS_MEMWS}/ws/spec/workspace.yml"
printf 'system: github\n' >"${TRAITS_MEMWS}/ws/spec/tracker.md"
printf 'workspace:\n  repository: acme/spine\n  path: ../ws   # local checkout\n' \
	>"${TRAITS_MEMWS}/member/spec/PRODUCT.md"
assert_eq "scope: workspace.path parsed from PRODUCT.md" \
	"$(steer_workspace_path "${TRAITS_MEMWS}/member")" "../ws"
assert_eq "scope: workspace_root resolves to the validated checkout" \
	"$(steer_workspace_root "${TRAITS_MEMWS}/member")" "${TRAITS_MEMWS}/member/../ws"
steer_tracker_is_github "${TRAITS_MEMWS}/member" && ok || bad "scope: member resolves workspace tracker as github"
printf 'system: jira\n' >"${TRAITS_MEMWS}/ws/spec/tracker.md"
steer_tracker_is_github "${TRAITS_MEMWS}/member" && bad "scope: member honors a non-GitHub workspace tracker" || ok
printf 'system: github\n' >"${TRAITS_MEMWS}/ws/spec/tracker.md"

# A resolved path that EXISTS but carries no member manifest is not a workspace.
# This is the silent case worktrees produce (`path: ..` -> `.claude/worktrees`, a
# real but empty directory): accepting it read an empty tree and reported every
# product-level spec as absent instead of falling back to the gateway.
mkdir -p "${TRAITS_MEMWS}/bare/spec"
printf 'system: github\n' >"${TRAITS_MEMWS}/bare/spec/tracker.md"
printf 'workspace:\n  path: ../bare\n' >"${TRAITS_MEMWS}/member/spec/PRODUCT.md"
steer_workspace_root "${TRAITS_MEMWS}/member" >/dev/null &&
	bad "scope: a directory with no workspace.yml is not a workspace" || ok
steer_tracker_is_github "${TRAITS_MEMWS}/member" && ok || bad "scope: manifest-less path fails open"

# An ABSOLUTE workspace.path is honoured as given, never re-anchored.
printf 'workspace:\n  path: %s/ws\n' "${TRAITS_MEMWS}" >"${TRAITS_MEMWS}/member/spec/PRODUCT.md"
assert_eq "scope: absolute workspace.path used verbatim" \
	"$(steer_workspace_root "${TRAITS_MEMWS}/member")" "${TRAITS_MEMWS}/ws"

# A declared path that does not exist must also fail open, never fail closed.
printf 'workspace:\n  path: ../gone\n' >"${TRAITS_MEMWS}/member/spec/PRODUCT.md"
steer_tracker_is_github "${TRAITS_MEMWS}/member" && ok || bad "scope: unresolvable workspace.path fails open"

# ----- worktrees: workspace.path is anchored on the PRIMARY checkout -----
# The regression this guards: `path: ..` (what templates/spec/product.md
# recommends for a member cloned inside its workspace) resolved from
# `<member>/.claude/worktrees/<n>` to `<member>/.claude/worktrees` - a directory
# that EXISTS, so step 1 of the ladder won and the gateway was never reached.
# Real linked-worktree layout: .git is a FILE holding a gitdir: pointer.
WT_WS="${WORK}/wt_polyrepo"
mkdir -p "${WT_WS}/spec" "${WT_WS}/member/.git/worktrees/feat-x" \
	"${WT_WS}/member/.claude/worktrees/feat-x/spec"
printf 'members:\n  - name: member\n' >"${WT_WS}/spec/workspace.yml"
printf 'system: github\n' >"${WT_WS}/spec/tracker.md"
printf 'workspace:\n  repository: acme/spine\n  path: ..\n' \
	>"${WT_WS}/member/.claude/worktrees/feat-x/spec/PRODUCT.md"
printf 'gitdir: %s/member/.git/worktrees/feat-x\n' "${WT_WS}" \
	>"${WT_WS}/member/.claude/worktrees/feat-x/.git"
WT_LINK="${WT_WS}/member/.claude/worktrees/feat-x"

assert_eq "worktree: primary checkout resolved from a linked worktree" \
	"$(steer_primary_worktree "${WT_LINK}")" "${WT_WS}/member"
assert_eq "worktree: workspace.path anchored on the primary, not the worktree" \
	"$(steer_workspace_root "${WT_LINK}")" "${WT_WS}/member/.."
steer_tracker_is_github "${WT_LINK}" && ok || bad "worktree: member worktree resolves the workspace tracker"
printf 'system: jira\n' >"${WT_WS}/spec/tracker.md"
steer_tracker_is_github "${WT_LINK}" && bad "worktree: worktree honors a non-GitHub workspace tracker" || ok

# Without the anchoring, `..` would land here - assert the trap really is a real
# directory, so this test keeps testing something.
[ -d "${WT_LINK}/.." ] && ok || bad "worktree: the mis-resolved path must exist to be a trap"
steer_workspace_root "${WORK}/wt_polyrepo/member/.claude/worktrees" >/dev/null 2>&1 &&
	bad "worktree: the mis-resolved directory must not read as a workspace" || ok

# Fail-soft: a primary checkout, an unparseable .git, and a --separate-git-dir
# layout (whose git dir is NOT named .git, so its parent is no work tree) all
# return the given root unchanged rather than guessing.
assert_eq "worktree: primary checkout passes through" \
	"$(steer_primary_worktree "${WT_WS}/member")" "${WT_WS}/member"
assert_eq "worktree: empty .git passes through" \
	"$(steer_primary_worktree "${TRAITS_MEMWS}")" "${TRAITS_MEMWS}"
WT_SEP="${WORK}/wt_separate"
mkdir -p "${WT_SEP}"
printf 'gitdir: /elsewhere/repo.git/worktrees/x\n' >"${WT_SEP}/.git"
assert_eq "worktree: non-.git common dir passes through" \
	"$(steer_primary_worktree "${WT_SEP}")" "${WT_SEP}"
printf 'gitdir: ../relative/.git/worktrees/x\n' >"${WT_SEP}/.git"
assert_eq "worktree: relative gitdir passes through" \
	"$(steer_primary_worktree "${WT_SEP}")" "${WT_SEP}"

# An unresolved placeholder path is treated as absent (-> fail open), and a
# `path:` outside the `workspace:` block is never mistaken for it.
printf 'workspace:\n  path: [relative path]\n' >"${TRAITS_MEMWS}/member/spec/PRODUCT.md"
steer_workspace_path "${TRAITS_MEMWS}/member" >/dev/null && bad "scope: placeholder workspace.path is absent" || ok
printf 'workspace:\n  repository: acme/spine\nmember:\n  path: apps/api\n' \
	>"${TRAITS_MEMWS}/member/spec/PRODUCT.md"
steer_workspace_path "${TRAITS_MEMWS}/member" >/dev/null && bad "scope: member.path is not workspace.path" || ok

# ----- polyrepo topology: role detection, traits, and the spine-state split -----
# A single-repo product must match NEITHER role and pay zero always-on bytes.
TRAITS_MONO="$(new_repo traits_mono)"
printf '{}\n' >"${TRAITS_MONO}/package.json"
steer_polyrepo_role "${TRAITS_MONO}" >/dev/null && bad "polyrepo: single-repo product has no role" || ok
steer_inject_when_ok polyrepo "${TRAITS_MONO}" && bad "polyrepo: rule skipped for single-repo product" || ok

TRAITS_WS="$(new_repo traits_ws)"
mkdir -p "${TRAITS_WS}/spec"
printf 'schema: 1\n' >"${TRAITS_WS}/spec/workspace.yml"
assert_eq "polyrepo: spec/workspace.yml -> workspace role" "$(steer_polyrepo_role "${TRAITS_WS}")" "workspace"
steer_inject_when_ok polyrepo "${TRAITS_WS}" && ok || bad "polyrepo: rule injects at the workspace"
steer_inject_when_ok has-workspace-manifest "${TRAITS_WS}" && ok || bad "polyrepo: has-workspace-manifest true"
steer_inject_when_ok has-product-pointer "${TRAITS_WS}" && bad "polyrepo: workspace is not a member" || ok

TRAITS_MEM="$(new_repo traits_mem)"
mkdir -p "${TRAITS_MEM}/spec"
printf 'workspace:\n' >"${TRAITS_MEM}/spec/PRODUCT.md"
assert_eq "polyrepo: spec/PRODUCT.md -> member role" "$(steer_polyrepo_role "${TRAITS_MEM}")" "member"
steer_inject_when_ok polyrepo "${TRAITS_MEM}" && ok || bad "polyrepo: rule injects at a member"
steer_inject_when_ok has-product-pointer "${TRAITS_MEM}" && ok || bad "polyrepo: has-product-pointer true"

# Malformed repo carrying BOTH markers: workspace wins, deterministically.
TRAITS_BOTH="$(new_repo traits_both)"
mkdir -p "${TRAITS_BOTH}/spec"
printf 'schema: 1\n' >"${TRAITS_BOTH}/spec/workspace.yml"
printf 'workspace:\n' >"${TRAITS_BOTH}/spec/PRODUCT.md"
assert_eq "polyrepo: both markers -> workspace wins" "$(steer_polyrepo_role "${TRAITS_BOTH}")" "workspace"

# The profile marker gains a `workspace` arm; an unknown/mis-cased token still
# falls back to app (the pre-existing contract).
PROF_WS="$(new_repo prof_ws)"
printf '## Profile\n<!-- steer:profile=workspace -->\n' >"${PROF_WS}/CLAUDE.md"
assert_eq "profile: workspace marker read" "$(steer_repo_profile "${PROF_WS}")" "workspace"
PROF_WSBAD="$(new_repo prof_wsbad)"
printf '## Profile\n<!-- steer:profile=Workspace -->\n' >"${PROF_WSBAD}/CLAUDE.md"
assert_eq "profile: mis-cased workspace falls back to app" "$(steer_repo_profile "${PROF_WSBAD}")" "app"

# A member's spine is partial BY DESIGN - product-level artifacts live in the
# workspace. Without the member split it would report `damaged` forever and
# /steer:sync would "repair" it by recreating the split-brain spine.
. "${HOOKS}/lib/spine.sh"
SPINE_MEM="$(new_repo spine_mem)"
mkdir -p "${SPINE_MEM}/spec"
touch "${SPINE_MEM}/spec/.version" "${SPINE_MEM}/spec/PRODUCT.md"
assert_eq "spine: member with pointer only -> managed" "$(steer_spine_state "${SPINE_MEM}")" "managed"
SPINE_WS="$(new_repo spine_ws)"
mkdir -p "${SPINE_WS}/spec"
touch "${SPINE_WS}/spec/.version" "${SPINE_WS}/spec/workspace.yml"
for _f in vision.md users.md glossary.md tracker.md; do touch "${SPINE_WS}/spec/${_f}"; done
mkdir -p "${SPINE_WS}/spec/history"
assert_eq "spine: workspace holds the full product set -> managed" "$(steer_spine_state "${SPINE_WS}")" "managed"
# The member split must NOT excuse a genuinely broken single-repo spine.
SPINE_BROKEN="$(new_repo spine_broken)"
mkdir -p "${SPINE_BROKEN}/spec/history"
touch "${SPINE_BROKEN}/spec/.version"
for _f in vision.md users.md tracker.md; do touch "${SPINE_BROKEN}/spec/${_f}"; done
assert_eq "spine: missing glossary still damaged" "$(steer_spine_state "${SPINE_BROKEN}")" "damaged"
# Action history: EITHER shape counts as present, so a repo that has not yet run
# the action-history directory migration is not reported damaged (spine.sh).
SPINE_LEGACY="$(new_repo spine_legacy)"
mkdir -p "${SPINE_LEGACY}/spec"
touch "${SPINE_LEGACY}/spec/.version"
for _f in vision.md users.md glossary.md tracker.md HISTORY.md; do touch "${SPINE_LEGACY}/spec/${_f}"; done
assert_eq "spine: legacy single-file HISTORY.md -> managed" "$(steer_spine_state "${SPINE_LEGACY}")" "managed"
SPINE_MIGRATED="$(new_repo spine_migrated)"
mkdir -p "${SPINE_MIGRATED}/spec/history"
touch "${SPINE_MIGRATED}/spec/.version" "${SPINE_MIGRATED}/spec/HISTORY.md"
for _f in vision.md users.md glossary.md tracker.md; do touch "${SPINE_MIGRATED}/spec/${_f}"; done
assert_eq "spine: migrated repo (dir + frozen archive) -> managed" "$(steer_spine_state "${SPINE_MIGRATED}")" "managed"
SPINE_NOHIST="$(new_repo spine_nohist)"
mkdir -p "${SPINE_NOHIST}/spec"
touch "${SPINE_NOHIST}/spec/.version"
for _f in vision.md users.md glossary.md tracker.md; do touch "${SPINE_NOHIST}/spec/${_f}"; done
assert_eq "spine: no action history at all -> damaged" "$(steer_spine_state "${SPINE_NOHIST}")" "damaged"
# A polyrepo MEMBER carries no action history of its own (it lives in the
# workspace), so the either-or test must not fire there.
SPINE_MEM2="$(new_repo spine_mem2)"
mkdir -p "${SPINE_MEM2}/spec"
touch "${SPINE_MEM2}/spec/.version" "${SPINE_MEM2}/spec/PRODUCT.md"
assert_eq "spine: member needs no action history -> managed" "$(steer_spine_state "${SPINE_MEM2}")" "managed"
# A stamped spine with neither the product set nor a pointer is damaged, not member.
SPINE_EMPTY="$(new_repo spine_empty)"
mkdir -p "${SPINE_EMPTY}/spec"
touch "${SPINE_EMPTY}/spec/.version"
assert_eq "spine: stamped but empty -> damaged" "$(steer_spine_state "${SPINE_EMPTY}")" "damaged"

# ----- steer_action_root / steer_git_c_target: act on the right repo (#396) -----
# A nested work tree makes cwd the WRONG anchor: the upward walk stops at the
# outer repo while the tool operates on the inner one.
AR_OUT="$(new_repo ar_outer)"
mkdir -p "${AR_OUT}/backend"
printf '' >"${AR_OUT}/backend/.git"
assert_eq "action_root: no path falls back to cwd's root" \
	"$(steer_action_root "${AR_OUT}" "")" "${AR_OUT}"
assert_eq "action_root: relative path resolves to the nested repo" \
	"$(steer_action_root "${AR_OUT}" "backend/src/x.ts")" "${AR_OUT}/backend"
assert_eq "action_root: absolute path resolves to the nested repo" \
	"$(steer_action_root "${AR_OUT}" "${AR_OUT}/backend/src/x.ts")" "${AR_OUT}/backend"
assert_eq "action_root: path in the outer repo stays outer" \
	"$(steer_action_root "${AR_OUT}" "docs/readme.md")" "${AR_OUT}"
# A not-yet-existing file (a Write creating one, possibly in a new dir) must be
# attributed to the repo that WILL contain it, not fall back to cwd.
assert_eq "action_root: unborn file in a new dir still resolves to its repo" \
	"$(steer_action_root "${AR_OUT}" "backend/brand/new/dir/file.ts")" "${AR_OUT}/backend"
# Fail-soft: an unresolvable path must not lose the cwd answer.
assert_eq "action_root: unresolvable path falls back to cwd's root" \
	"$(steer_action_root "${AR_OUT}" "/nonexistent/elsewhere/x.ts")" "${AR_OUT}"

assert_eq "git_c_target: extracts -C target" \
	"$(steer_git_c_target 'git -C backend push origin main')" "backend"
assert_eq "git_c_target: unquotes a double-quoted target, spaces kept" \
	"$(steer_git_c_target 'git -C "/x/my repo" push origin main')" "/x/my repo"
assert_eq "git_c_target: unquotes a single-quoted target" \
	"$(steer_git_c_target "git -C '/y' push")" "/y"
assert_eq "git_c_target: extracts from a compound command" \
	"$(steer_git_c_target 'cd /tmp && git -C backend push && echo ok')" "backend"
steer_git_c_target 'git push origin main' >/dev/null &&
	bad "git_c_target: plain push has no -C target" || ok
steer_git_c_target 'echo "no git here"' >/dev/null &&
	bad "git_c_target: non-git command has no target" || ok

# End to end through the REAL trunk-push gate, both directions of #396.
# (1) False negative - the dangerous one. Outer is pr-flow, inner is solo-trunk
# WITH a graduation signal: the gate must ask about the inner repo's push.
AR_FN_O="$(new_repo ar_fn_outer)"
printf '## Delivery mode\n<!-- steer:delivery-mode=pr-flow -->\n' >"${AR_FN_O}/CLAUDE.md"
mkdir -p "${AR_FN_O}/backend/.github/workflows"
printf '' >"${AR_FN_O}/backend/.git"
printf '## Delivery mode\n<!-- steer:delivery-mode=solo-trunk -->\n' >"${AR_FN_O}/backend/CLAUDE.md"
printf 'on: push\n' >"${AR_FN_O}/backend/.github/workflows/deploy.yml"
out="$(run_hook check-bash-actions.sh "$(bash_json "${AR_FN_O}" arfn 'git -C backend push origin main')")"
assert_ask "action_root: solo-trunk push into a nested repo is gated" "${out}"

# (2) False positive. Outer is solo-trunk with a signal, inner is pr-flow:
# a branch push into the inner repo is autonomous and must NOT be gated.
AR_FP_O="$(new_repo ar_fp_outer)"
mkdir -p "${AR_FP_O}/.github/workflows" "${AR_FP_O}/backend"
printf '## Delivery mode\n<!-- steer:delivery-mode=solo-trunk -->\n' >"${AR_FP_O}/CLAUDE.md"
printf 'on: push\n' >"${AR_FP_O}/.github/workflows/deploy.yml"
printf '' >"${AR_FP_O}/backend/.git"
printf '## Delivery mode\n<!-- steer:delivery-mode=pr-flow -->\n' >"${AR_FP_O}/backend/CLAUDE.md"
out="$(run_hook check-bash-actions.sh "$(bash_json "${AR_FP_O}" arfp 'git -C backend push origin main')")"
assert_empty "action_root: pr-flow push into a nested repo is not gated" "${out}"

# (3) The single-repo path must be untouched: solo-trunk + signal, plain push.
AR_SOLO="$(new_repo ar_solo)"
mkdir -p "${AR_SOLO}/.github/workflows"
printf '## Delivery mode\n<!-- steer:delivery-mode=solo-trunk -->\n' >"${AR_SOLO}/CLAUDE.md"
printf 'on: push\n' >"${AR_SOLO}/.github/workflows/deploy.yml"
out="$(run_hook check-bash-actions.sh "$(bash_json "${AR_SOLO}" arsolo 'git push origin main')")"
assert_ask "action_root: single-repo trunk push still gated (unchanged)" "${out}"

# ----- steer_tracker_repo: the declared tracker repository (#395) -----
# Feeds the cross-repo closing-ref decision in /steer:work. Must read a real
# value and must return NOTHING for anything unresolved, so the caller keeps the
# ordinary same-repo `Closes #N` path rather than diverting on a guess.
TR_PLAIN="$(new_repo tr_plain)"
mkdir -p "${TR_PLAIN}/spec"
printf 'system: github\nrepository: acme/tracker\n' >"${TR_PLAIN}/spec/tracker.md"
assert_eq "tracker_repo: plain value" "$(steer_tracker_repo "${TR_PLAIN}")" "acme/tracker"

TR_QUOTED="$(new_repo tr_quoted)"
mkdir -p "${TR_QUOTED}/spec"
printf 'repository: "acme/tracker"\n' >"${TR_QUOTED}/spec/tracker.md"
assert_eq "tracker_repo: quotes stripped" "$(steer_tracker_repo "${TR_QUOTED}")" "acme/tracker"

TR_COMMENT="$(new_repo tr_comment)"
mkdir -p "${TR_COMMENT}/spec"
printf '  repository:   acme/tracker   # central tracker\n' >"${TR_COMMENT}/spec/tracker.md"
assert_eq "tracker_repo: inline comment and padding stripped" \
	"$(steer_tracker_repo "${TR_COMMENT}")" "acme/tracker"

# The shipped template's unresolved placeholder must read as ABSENT, not as a
# repository literally named "[owner/repository]" - otherwise every un-inited
# repo would look foreign and divert away from `Closes #N`.
TR_HOLDER="$(new_repo tr_holder)"
mkdir -p "${TR_HOLDER}/spec"
printf 'repository:                 # "[owner/repository]" for GitHub\n' \
	>"${TR_HOLDER}/spec/tracker.md"
steer_tracker_repo "${TR_HOLDER}" >/dev/null &&
	bad "tracker_repo: unresolved placeholder must read as absent" || ok

TR_EMPTY="$(new_repo tr_empty)"
mkdir -p "${TR_EMPTY}/spec"
printf 'system: github\nrepository:\n' >"${TR_EMPTY}/spec/tracker.md"
steer_tracker_repo "${TR_EMPTY}" >/dev/null &&
	bad "tracker_repo: empty value must read as absent" || ok

TR_NONE="$(new_repo tr_none)"
steer_tracker_repo "${TR_NONE}" >/dev/null &&
	bad "tracker_repo: missing tracker.md must read as absent" || ok

# OR markers (token|token): inject when ANY arm holds.
steer_inject_when_ok 'has-iac|has-apps' "${TRAITS_APP}" && ok || bad "scope: OR marker true via has-apps arm"
steer_inject_when_ok 'has-iac|has-apps' "${TRAITS_INFRA}" && ok || bad "scope: OR marker true via has-iac arm"
TRAITS_OR_NONE="$(new_repo traits_or_none)"
steer_inject_when_ok 'has-iac|has-apps' "${TRAITS_OR_NONE}" && bad "scope: OR marker false when no arm holds" || ok

# org-e22: absent policy/org.yml means e22, so an existing repo keeps the house
# stack rules on upgrade; any other declared pack drops them.
ORG_NONE="$(new_repo org_none)"
[ "$(steer_org_pack "${ORG_NONE}")" = "e22" ] && ok || bad "org: absent policy/org.yml reads as e22"
steer_inject_when_ok org-e22 "${ORG_NONE}" && ok || bad "org: org-e22 true with no declaration"
mkdir -p "${ORG_NONE}/policy"
printf 'schema: 1\npack: none\n' >"${ORG_NONE}/policy/org.yml"
[ "$(steer_org_pack "${ORG_NONE}")" = "none" ] && ok || bad "org: declared pack is read back"
steer_inject_when_ok org-e22 "${ORG_NONE}" && bad "org: org-e22 false when another pack is declared" || ok
printf 'pack: e22  # house defaults\n' >"${ORG_NONE}/policy/org.yml"
steer_inject_when_ok org-e22 "${ORG_NONE}" && ok || bad "org: inline comment stripped from pack value"

# AND composition: every `&` arm must hold; an arm may itself be an OR list.
steer_inject_when_ok 'has-iac&org-e22' "${TRAITS_INFRA}" && ok ||
	bad "scope: AND marker true when both arms hold"
mkdir -p "${TRAITS_APP}/policy"
printf 'pack: none\n' >"${TRAITS_APP}/policy/org.yml"
steer_inject_when_ok 'has-apps&org-e22' "${TRAITS_APP}" &&
	bad "scope: AND marker false when the pack arm fails" || ok
steer_inject_when_ok 'has-iac&org-e22' "${TRAITS_APP}" &&
	bad "scope: AND marker false when the trait arm fails" || ok
steer_inject_when_ok 'org-e22&has-iac|has-apps' "${TRAITS_INFRA}" && ok ||
	bad "scope: AND binds loosest - OR arm resolves inside it"
rm -f "${TRAITS_APP}/policy/org.yml"

# work-mode classifier: non-git + no markers -> knowledge; git or any code marker
# -> code; fail-safe defaults to code. /spec is deliberately NOT a code marker.
WM_KW="${WORK}/wm_kw"
mkdir -p "${WM_KW}"
printf 'x\n' >"${WM_KW}/doc.md"
assert_eq "work_mode: bare non-git folder -> knowledge" "$(steer_work_mode "${WM_KW}")" "knowledge"
WM_SPEC="${WORK}/wm_spec"
mkdir -p "${WM_SPEC}/spec"
printf 'x\n' >"${WM_SPEC}/spec/intent.md"
assert_eq "work_mode: /spec is not a code marker -> knowledge" "$(steer_work_mode "${WM_SPEC}")" "knowledge"
WM_PKG="${WORK}/wm_pkg"
mkdir -p "${WM_PKG}"
printf '{}\n' >"${WM_PKG}/package.json"
assert_eq "work_mode: package.json -> code" "$(steer_work_mode "${WM_PKG}")" "code"
WM_TF="${WORK}/wm_tf"
mkdir -p "${WM_TF}"
printf 'terraform {}\n' >"${WM_TF}/main.tf"
assert_eq "work_mode: *.tf -> code" "$(steer_work_mode "${WM_TF}")" "code"
# Loose source file with NO manifest must still read as code (fail-safe - a
# manifest-only scan would mis-classify a non-git script folder as knowledge).
WM_SRC="${WORK}/wm_src"
mkdir -p "${WM_SRC}"
printf 'print(1)\n' >"${WM_SRC}/run.py"
assert_eq "work_mode: loose source, no manifest -> code" "$(steer_work_mode "${WM_SRC}")" "code"
WM_GIT="$(new_repo wm_git)"
assert_eq "work_mode: git repo -> code" "$(steer_work_mode "${WM_GIT}")" "code"
WM_SUB="${WM_GIT}/apps/web"
mkdir -p "${WM_SUB}"
assert_eq "work_mode: subdir of git repo -> code" "$(steer_work_mode "${WM_SUB}")" "code"
# code-project predicate is always true at the predicate layer (knowledge folders
# skip marked rules in the inject loop before this runs, so it only fires in code).
steer_inject_when_ok code-project "${WM_GIT}" && ok || bad "scope: code-project predicate true"

# profile reader: marker -> value; absent -> app (back-compat).
PROF_INFRA="$(new_repo prof_infra)"
printf '## Profile\n<!-- steer:profile=infra -->\n' >"${PROF_INFRA}/CLAUDE.md"
assert_eq "profile: marker=infra" "$(steer_repo_profile "${PROF_INFRA}")" "infra"
PROF_NONE="$(new_repo prof_none)"
assert_eq "profile: no CLAUDE.md -> app" "$(steer_repo_profile "${PROF_NONE}")" "app"
PROF_BARE="$(new_repo prof_bare)"
printf '# title\n' >"${PROF_BARE}/CLAUDE.md"
assert_eq "profile: CLAUDE.md without marker -> app" "$(steer_repo_profile "${PROF_BARE}")" "app"

finish

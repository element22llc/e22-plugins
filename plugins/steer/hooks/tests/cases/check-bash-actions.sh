#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# --- issue-create contract guard of check-bash-actions.sh (GitHub tracker) ---

RC8="$(new_repo repoCreateGH)"
mkdir -p "${RC8}/spec"
printf 'system: github\n' >"${RC8}/spec/tracker.md"
out="$(run_hook check-bash-actions.sh "$(bash_json "${RC8}" sC1 'gh issue create --title x --body y')")"
assert_ctx "issue-create: gh issue create nudges" "${out}"
printf '%s' "${out}" | grep -q '/steer:tracker-sync create' && ok || bad "issue-create: nudge points at tracker-sync (got: ${out})"
out="$(run_hook check-bash-actions.sh "$(bash_json "${RC8}" sC1 'gh issue create --title z')")"
assert_empty "issue-create: one nudge per session+repo" "${out}"

# gh api REST POST to .../issues (creation) nudges; a POST to .../issues/<n>/...
# (comment / sub-resource) does not.
RC8b="$(new_repo repoCreateApi)"
mkdir -p "${RC8b}/spec"
printf 'system: github\n' >"${RC8b}/spec/tracker.md"
out="$(run_hook check-bash-actions.sh "$(bash_json "${RC8b}" sC2 'gh api repos/o/r/issues -f title=x -f body=y')")"
assert_ctx "issue-create: gh api POST /issues nudges" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${RC8b}" sC2b 'gh api repos/o/r/issues/123/comments -f body=hi')")"
assert_empty "issue-create: gh api comment on /issues/<n> silent" "${out}"

# GraphQL createIssue mutation nudges.
RC8c="$(new_repo repoCreateGql)"
mkdir -p "${RC8c}/spec"
printf 'system: github\n' >"${RC8c}/spec/tracker.md"
out="$(run_hook check-bash-actions.sh "$(bash_json "${RC8c}" sC3 'gh api graphql -f query=mutation{createIssue(input:{}){issue{number}}}')")"
assert_ctx "issue-create: graphql createIssue nudges" "${out}"

# A create whose payload ALREADY carries steer markers is the /steer:tracker-sync
# render path - stay silent (contract is being applied, not bypassed).
RC8d="$(new_repo repoCreateContractful)"
mkdir -p "${RC8d}/spec"
printf 'system: github\n' >"${RC8d}/spec/tracker.md"
out="$(run_hook check-bash-actions.sh "$(bash_json "${RC8d}" sC4 'gh issue create --body <!-- steer:kind=task -->')")"
assert_empty "issue-create: payload with steer markers silent" "${out}"

# A /steer:report self-report files UPSTREAM to element22llc/e22-plugins, never the
# product tracker. The guard must stay silent even on the label-less fallback
# create, which carries no `steer:` marker - routing it through tracker-sync would
# target the wrong repo.
RC8f="$(new_repo repoSelfReport)"
mkdir -p "${RC8f}/spec"
printf 'system: github\n' >"${RC8f}/spec/tracker.md"
out="$(run_hook check-bash-actions.sh "$(bash_json "${RC8f}" sC4b 'gh issue create --repo element22llc/e22-plugins --title "[steer] x" --label bug --body-file /tmp/b')")"
assert_empty "issue-create: steer self-report upstream create stays silent" "${out}"

# gh's documented `-R` alias for `--repo` is the same self-report create and must
# be exempt too (#339) - pre-fix it got a false-positive nudge at the wrong repo.
RC8h="$(new_repo repoSelfReportR)"
mkdir -p "${RC8h}/spec"
printf 'system: github\n' >"${RC8h}/spec/tracker.md"
out="$(run_hook check-bash-actions.sh "$(bash_json "${RC8h}" sC4c 'gh issue create -R element22llc/e22-plugins --title "[steer] x" --body-file /tmp/b')")"
assert_empty "issue-create: steer self-report via -R alias stays silent" "${out}"

# The self-report guard matches the --repo FLAG, not a bare mention: a legitimate
# PRODUCT create whose body merely references the plugin repo must STILL be nudged
# (routed through /steer:tracker-sync), not silently suppressed.
RC8g="$(new_repo repoProdMention)"
mkdir -p "${RC8g}/spec"
printf 'system: github\n' >"${RC8g}/spec/tracker.md"
out="$(run_hook check-bash-actions.sh "$(bash_json "${RC8g}" sC4d 'gh issue create --title bump --body "see element22llc/e22-plugins#123"')")"
assert_ctx "issue-create: product create only mentioning plugin repo still nudges" "${out}"

# MCP create-issue tool nudges; an MCP comment/list tool whose name merely
# contains "issue" does not.
RC8e="$(new_repo repoCreateMcp)"
mkdir -p "${RC8e}/spec"
printf 'system: github\n' >"${RC8e}/spec/tracker.md"
out="$(run_hook check-bash-actions.sh "$(mcp_json "${RC8e}" sC5 mcp__github__create_issue y)")"
assert_ctx "issue-create: MCP create_issue nudges" "${out}"
out="$(run_hook check-bash-actions.sh "$(mcp_json "${RC8e}" sC5b mcp__github__add_issue_comment y)")"
assert_empty "issue-create: MCP add_issue_comment silent" "${out}"
# The hosted GitHub MCP server renamed create_issue -> issue_write; the guard must
# fire on the current write path (#264). Distinct session ids so the once-per-repo
# marker set by earlier cases does not suppress these.
out="$(run_hook check-bash-actions.sh "$(mcp_json "${RC8e}" sC5c mcp__github__issue_write y)")"
assert_ctx "issue-create: MCP issue_write nudges (renamed create tool)" "${out}"
# sub_issue_write links a relationship to an EXISTING issue (no body) - not a create.
out="$(run_hook check-bash-actions.sh "$(mcp_json "${RC8e}" sC5d mcp__github__sub_issue_write y)")"
assert_empty "issue-create: MCP sub_issue_write silent (relationship, not create)" "${out}"

# Non-create Bash, non-GitHub tracker, and no-tracker repos are all silent.
out="$(run_hook check-bash-actions.sh "$(bash_json "${RC8}" sC6 'gh issue list --json number')")"
assert_empty "issue-create: gh issue list silent" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${RC8}" sC7 'ls -la')")"
assert_empty "issue-create: plain bash silent" "${out}"
RC9="$(new_repo repoCreateJira)"
mkdir -p "${RC9}/spec"
printf 'system: jira\n' >"${RC9}/spec/tracker.md"
out="$(run_hook check-bash-actions.sh "$(bash_json "${RC9}" sC8 'gh issue create --title x')")"
assert_empty "issue-create: non-github tracker silent" "${out}"
RC10="$(new_repo repoCreateNoTracker)"
mkdir -p "${RC10}/spec"
out="$(run_hook check-bash-actions.sh "$(bash_json "${RC10}" sC9 'gh issue create --title x')")"
assert_empty "issue-create: no tracker silent" "${out}"
# A Bash call whose command TEXT embeds a create_issue tool_name must NOT be misread
# as an MCP create: steer_tool reads the top-level .tool_name ("Bash"), not the
# tool_input slice steer_field would search (#277 item 3). Without the fix this
# writes-a-fixture command spuriously nudges.
embed_cmd='printf "%s" "{\"tool_name\":\"mcp__github__create_issue\"}" > fx.json'
out="$(run_hook check-bash-actions.sh "$(bash_json "${RC8}" sC10 "${embed_cmd}")")"
assert_empty "issue-create: Bash cmd embedding a create_issue tool_name stays silent" "${out}"

# --- trunk-push graduation gate of check-bash-actions.sh (PreToolUse, Bash) ---
# Signals shared with check-graduation.sh via lib/graduation.sh. "ask" - not
# deny - only when ALL hold: Bash git push + solo-trunk + a graduation signal.

# solo-trunk + infra/ signal + git push -> wrapped ask naming /steer:setup protect.
TP_HOT="$(new_repo tp_hot)"
mkdir -p "${TP_HOT}/infra"
claude_md_mode "${TP_HOT}" solo-trunk
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_HOT}" tp1 'git push origin main')")"
assert_ask "trunk-push: solo-trunk + signal + push asks" "${out}"
assert_has "trunk-push: ask names the graduation path" "${out}" "/steer:setup protect"

# compound command (`... && git push`) still matches.
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_HOT}" tp3 'mise run check && git push')")"
assert_ask "trunk-push: compound command push asks" "${out}"

# `git -C <dir> push` form matches.
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_HOT}" tp4 "git -C ${TP_HOT} push")")"
assert_ask "trunk-push: git -C push asks" "${out}"

# One ask per session+repo: a REPEAT push in the same session downgrades to a
# non-blocking additionalContext reminder (never a second ask), so an
# autonomous run is not stalled on every push.
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_HOT}" tp4b 'git push origin main')")"
assert_ask "trunk-push: first push in fresh session asks" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_HOT}" tp4b 'git push origin main')")"
assert_ctx "trunk-push: repeat push same session downgrades to context" "${out}"
printf '%s' "${out}" | grep -q '"permissionDecision"' && bad "trunk-push: repeat push must not re-ask (got: ${out})" || ok
assert_has "trunk-push: repeat reminder still names the graduation path" "${out}" "/steer:setup protect"

# A NEW session re-asks (the marker is session-keyed, not repo-permanent).
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_HOT}" tp4c 'git push origin main')")"
assert_ask "trunk-push: new session asks again" "${out}"

# non-push git command -> silent (hot-path early exit).
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_HOT}" tp5 'git status')")"
assert_empty "trunk-push: non-push git silent" "${out}"

# "push" only as an argument (not the git subcommand) -> silent.
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_HOT}" tp6 'git commit -m "push the button"')")"
assert_empty "trunk-push: push in message silent" "${out}"

# non-Bash tool -> silent even in the hot repo.
out="$(run_hook check-bash-actions.sh "$(json_write "${TP_HOT}" tp7 src/app.ts 'x')")"
assert_empty "trunk-push: non-Bash tool silent" "${out}"

# solo-trunk with NO signal -> silent (pre-MVP trunk autonomy holds).
TP_FRESH="$(new_repo tp_fresh)"
claude_md_mode "${TP_FRESH}" solo-trunk
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_FRESH}" tp8 'git push origin main')")"
assert_empty "trunk-push: solo-trunk no signal silent" "${out}"

# solo-trunk + signal + a recorded graduation waiver -> silent (the waiver is
# honoured in the shared detector, so the gate and the nudge agree).
TP_WAIVED="$(new_repo tp_waived)"
mkdir -p "${TP_WAIVED}/infra"
claude_md_mode_waived "${TP_WAIVED}" solo-trunk
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_WAIVED}" tp8w 'git push origin main')")"
assert_empty "trunk-push: solo-trunk + signal + waiver silent" "${out}"

# Unwaived hot repo: the ask names the waiver as the alternative to graduating.
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_HOT}" tp8x 'git push origin main')")"
assert_has "trunk-push: ask names the waiver path" "${out}" "/steer:setup protect waive"

# pr-flow + signal -> silent (branch pushes; the server wall owns the merge gate).
TP_PR="$(new_repo tp_pr)"
mkdir -p "${TP_PR}/infra"
claude_md_mode "${TP_PR}" pr-flow
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_PR}" tp9 'git push -u origin issue/12-x')")"
assert_empty "trunk-push: pr-flow silent despite signal" "${out}"

# no CLAUDE.md marker at all -> pr-flow default -> silent.
TP_BARE="$(new_repo tp_bare)"
mkdir -p "${TP_BARE}/infra"
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_BARE}" tp10 'git push')")"
assert_empty "trunk-push: unmarked repo (pr-flow default) silent" "${out}"

# cwd not inside a repo -> silent.
TP_NOREPO="${WORK}/tp_norepo"
mkdir -p "${TP_NOREPO}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_NOREPO}" tp11 'git push')")"
assert_empty "trunk-push: no repo silent" "${out}"

# --- stacked-PR gate of check-bash-actions.sh (PreToolUse, Bash) ---
# Asks when a PR targets a work branch; silent on the default branch, a
# long-lived integration branch (release/*, batch/*), and the promotion PR.
SP="$(new_repo sp_repo)"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" sp1 'gh pr create --base issue/910-x --title t --body b')")"
assert_ask "stacked-pr: --base work branch asks" "${out}"
assert_has "stacked-pr: ask names the base" "${out}" "issue/910-x"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" sp1 'gh pr create -B feat/a --fill')")"
assert_ask "stacked-pr: -B work branch asks every time" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" sp2 'gh pr create --base=feat/a --fill')")"
assert_ask "stacked-pr: --base= form asks" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" sp3 'mise run check && gh pr create --base "fix/b" --fill')")"
assert_ask "stacked-pr: compound + quoted base asks" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" sp4 'gh pr edit 12 --base feat/a')")"
assert_ask "stacked-pr: retarget onto work branch asks" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" sp5 'gh stack submit')")"
assert_ask "stacked-pr: gh stack submit asks" "${out}"
assert_has "stacked-pr: submit ask names the command" "${out}" "gh stack submit opens PRs"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" sp5b 'gh stack link 42 43')")"
assert_ask "stacked-pr: gh stack link asks" "${out}"
assert_has "stacked-pr: link ask names the command" "${out}" "gh stack link chains"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" sp5f 'gh ext exec stack submit --auto&&echo ok')")"
assert_ask "stacked-pr: gh ext exec stack submit asks" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" sp5c 'gh stack view --json')")"
assert_empty "stacked-pr: gh stack view silent" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" sp5d 'gh stack sync')")"
assert_empty "stacked-pr: gh stack sync silent" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" sp5e 'gh pr create --base main --title t --body "then run gh stack submit"')")"
assert_empty "stacked-pr: gh stack submit inside the body is prose" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" sp6 'gh pr create --base main --fill')")"
assert_empty "stacked-pr: --base default silent" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" sp7 'gh pr create --fill')")"
assert_empty "stacked-pr: no --base silent" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" sp8 'gh pr create --base prod --head main --title promote')")"
assert_empty "stacked-pr: promotion PR silent" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" sp8b 'gh pr create --base prod --head release/v1.5.0 --title "Release v1.5.0"')")"
assert_empty "stacked-pr: release snapshot PR into prod silent" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" sp8c 'gh pr create --base release/v1.5.0 --head qa-fix/12')")"
assert_empty "stacked-pr: QA fix PR into a release branch silent" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" sp9 'gh pr create --base release/2.0 --fill')")"
assert_empty "stacked-pr: release branch silent" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" sp9b 'gh pr create --base batch/oct-fixes --fill')")"
assert_empty "stacked-pr: batch integration branch silent" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" sp10 'gh pr edit 12 --add-label bug')")"
assert_empty "stacked-pr: edit without --base silent" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" sp11 'gh pr list --base feat/a')")"
assert_empty "stacked-pr: read-only pr command silent" "${out}"
# A flag-like word inside --title/--body text is prose, not the base.
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" sp12 'gh pr create --base main --title "Fix x" --body "run git checkout -B scratch then test"')")"
assert_empty "stacked-pr: -B inside the body is not the base" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" sp13 'gh pr create --base "feat/a" --title "t y"')")"
assert_ask "stacked-pr: quoted base still read beside a quoted title" "${out}"
# The default branch comes from origin/HEAD when the clone records one.
SP_TRUNK="$(git_repo sp_trunk trunk)"
git -C "${SP_TRUNK}" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/trunk
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP_TRUNK}" sp12 'gh pr create --base trunk --fill')")"
assert_empty "stacked-pr: origin/HEAD default silent" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP_TRUNK}" sp13 'gh pr create --base main --fill')")"
assert_ask "stacked-pr: main is a work branch when origin/HEAD says trunk" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_NOREPO}" sp14 'gh pr create --base feat/a')")"
assert_empty "stacked-pr: no repo silent" "${out}"

# --- merge gate of check-bash-actions.sh (PreToolUse, Bash + MCP) ---
# Hard deny on every PR merge path, in every repo; local git merge and prose
# that mentions a merge stay silent.
for mt in mcp__plugin_steer_github__merge_pull_request mcp__github__merge_pull_request; do
	out="$(run_hook check-bash-actions.sh "$(mcp_json "${SP}" mg1 "${mt}" '')")"
	assert_deny "merge-gate: ${mt} denied" "${out}"
done
out="$(run_hook check-bash-actions.sh "$(mcp_json "${SP}" mg1 mcp__github__merge_pull_request '')")"
assert_deny "merge-gate: denies again in the same session" "${out}"
assert_has "merge-gate: reason leaves the merge to the human" "${out}" "leave the merge to the reviewer"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" mg2 'gh pr merge 45 --squash')")"
assert_deny "merge-gate: gh pr merge denied" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" mg3 'gh pr checks 45 && gh pr merge 45 --auto')")"
assert_deny "merge-gate: compound gh pr merge denied" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_HOT}" mg4 'git push && gh pr merge')")"
assert_deny "merge-gate: deny outranks the trunk-push ask" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" mg5 'gh api -X PUT repos/o/r/pulls/45/merge')")"
assert_deny "merge-gate: REST merge denied" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" mg6 'gh api graphql -f query="mutation { mergePullRequest(input: {pullRequestId: \"x\"}) { clientMutationId } }"')")"
assert_deny "merge-gate: GraphQL merge denied" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" mg6b 'gh api -X PUT repos/o/r/pulls/45/merge-async')")"
assert_deny "merge-gate: async REST merge denied" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" mg6c 'gh stack merge')")"
assert_deny "merge-gate: gh stack merge denied" "${out}"
assert_has "merge-gate: names gh stack merge" "${out}" "gh stack merge merges"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" mg6d 'gh stack sync && gh stack merge 7 --yes --squash')")"
assert_deny "merge-gate: compound gh stack merge by number denied" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" mg6e 'gh pr create --title t --body "the human runs gh stack merge"')")"
assert_empty "merge-gate: body mentioning gh stack merge silent" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" mg6f 'gh extension exec stack merge 7')")"
assert_deny "merge-gate: gh extension exec stack merge denied" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" mg6g 'gh stack merge;echo done')")"
assert_deny "merge-gate: gh stack merge before an unspaced separator denied" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_NOREPO}" mg7 'gh pr merge 45')")"
assert_deny "merge-gate: denied outside a repo" "${out}"
MG_PLUGIN="$(new_repo mg_plugin)"
mkdir -p "${MG_PLUGIN}/.claude-plugin"
out="$(run_hook check-bash-actions.sh "$(bash_json "${MG_PLUGIN}" mg8 'gh pr merge 45')")"
assert_deny "merge-gate: denied in the plugin source repo" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" mg9 'git merge origin/main')")"
assert_empty "merge-gate: local git merge silent" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" mg10 'gh api repos/o/r/pulls/45/merge')")"
assert_empty "merge-gate: REST merged-check (GET) silent" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" mg11 'git commit -m "deny gh pr merge in the hook"')")"
assert_empty "merge-gate: commit message mentioning gh pr merge silent" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" mg12 'gh pr create --title t --body "merge waits for review: gh pr merge is human"')")"
assert_empty "merge-gate: PR body mentioning gh pr merge silent" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" mg13 'gh pr view 45 --json mergeable')")"
assert_empty "merge-gate: read-only pr command silent" "${out}"
out="$(run_hook check-bash-actions.sh "$(mcp_json "${SP}" mg14 mcp__github__pull_request_read '')")"
assert_empty "merge-gate: other MCP PR tools silent" "${out}"

# Spellings that slipped past the merge gate. A command with real newlines needs
# them JSON-escaped, which bash_json does not do.
bash_json_nl() { # <cwd> <session> <command with newlines>
	_cmd="$(printf '%s' "$3" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk 'NR > 1 { printf "\\n" } { printf "%s", $0 }')"
	printf '{"session_id":"%s","cwd":"%s","tool_name":"Bash","tool_input":{"command":"%s"}}' "$2" "$1" "${_cmd}"
}
for mc in 'gh pr -R o/r merge 5' 'gh pr --repo=o/r merge 5' 'gh pr --repo o/r merge 5 --squash' \
	'/opt/homebrew/bin/gh pr merge 5' '\gh pr merge 5' "echo can\\'t; gh pr merge 5" \
	"bash -c 'gh pr merge 5 --squash'" 'sh -c "gh pr merge 5"' "eval 'gh pr merge 5'" \
	'echo "$(gh pr merge 5 --squash)"' 'echo "`gh pr merge 5`"'; do
	out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" mg15 "${mc}")")"
	assert_deny "merge-gate: ${mc} denied" "${out}"
done
out="$(run_hook check-bash-actions.sh "$(bash_json_nl "${SP}" mg16 "# it's done
gh pr merge 5")")"
assert_deny "merge-gate: apostrophe in a comment does not hide the merge" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json_nl "${SP}" mg17 "gh pr comment 5 --body-file - <<'EOF'
it's ready
EOF
gh pr merge 5 --squash")")"
assert_deny "merge-gate: apostrophe in a heredoc body does not hide the merge" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json_nl "${SP}" mg18 "gh pr comment 5 --body-file - <<EOF
the human runs gh pr merge 5
EOF")")"
assert_empty "merge-gate: heredoc body mentioning gh pr merge silent" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json_nl "${SP}" mg18b "sh <<'EOF'
gh pr merge 5
EOF")")"
assert_deny "merge-gate: heredoc fed to sh is commands" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json_nl "${SP}" mg18c "cat <<EOF | bash
gh pr merge 5
EOF")")"
assert_deny "merge-gate: heredoc piped to bash is commands" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json_nl "${SP}" mg18d 'gh pr \
  merge 5')")"
assert_deny "merge-gate: backslash-continued gh pr merge denied" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" mg19 'bash -c "gh pr view 5" # then gh pr merge')")"
assert_empty "merge-gate: merge only in a trailing comment silent" "${out}"

# Trunk-push: matched on the quote-stripped text, past git global options.
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_HOT}" tp20 'git commit -am "docs: explain when to git push in README"')")"
assert_empty "trunk-push: git push inside a commit message silent" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_HOT}" tp20 'git push origin main')")"
assert_ask "trunk-push: a quoted mention does not spend the session's ask" "${out}"
for pc in 'git -c core.hooksPath=/dev/null push origin main' 'git --no-pager push' \
	'/usr/bin/git push' '(git push)' "git -C \"${TP_HOT}\" push"; do
	out="$(run_hook check-bash-actions.sh "$(bash_json "${TP_HOT}" "tp21-$(printf '%s' "${pc}" | cksum | cut -d' ' -f1)" "${pc}")")"
	assert_ask "trunk-push: ${pc} asks" "${out}"
done

# Stacked-PR: -B belongs to the gh pr segment only.
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" sp20 'git checkout -B feat/x && gh pr create --fill')")"
assert_empty "stacked-pr: git checkout -B before gh pr create is not the base" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json "${SP}" sp21 'git checkout -B feat/x && gh pr create -B feat/a --fill')")"
assert_ask "stacked-pr: the gh pr segment's own -B still asks" "${out}"
out="$(run_hook check-bash-actions.sh "$(bash_json_nl "${SP}" sp22 'gh pr create \
  --base feat/a \
  --fill')")"
assert_ask "stacked-pr: backslash-continued --base asks" "${out}"

# A quoted -C target with a space still resolves the pushed repo.
TP_SPACE="$(new_repo "tp hot space")"
mkdir -p "${TP_SPACE}/infra"
claude_md_mode "${TP_SPACE}" solo-trunk
out="$(run_hook check-bash-actions.sh "$(bash_json /tmp tp22 "git -C \"${TP_SPACE}\" push")")"
assert_ask "trunk-push: quoted -C target with a space asks" "${out}"

finish

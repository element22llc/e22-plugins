#!/usr/bin/env bash
# spec-driven-dev: surface which lane the current branch is in so Claude (and the
# user) start every turn with the same mental model.
#
# Emits a single line of additional context to Claude via stdout in the format
# expected by the UserPromptSubmit hook. Never blocks.

set -uo pipefail

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"

case "$branch" in
  prototype/*)
    lane="prototype"
    rules="Four Guarantees apply (branch-per-idea, synthetic data, ephemeral URL, sandbox secrets). House rules are lenient. No production data, ever."
    ;;
  feat/*|fix/*|proposal/*|chore/*|infra/*|docs/*)
    lane="production"
    rules="Full house rules apply: Product Spine must exist, smoke tests scaffolded, security-rails strict, house-style enforced. Open PRs as draft."
    ;;
  main|master)
    lane="main-branch"
    rules="You should not be editing main directly. Create a branch."
    ;;
  *)
    lane="production (default)"
    rules="Full house rules apply by default. Use a prototype/* branch if you intend to vibe-code."
    ;;
esac

cat <<EOF
[lane-context]
Current branch: ${branch}
Active lane: ${lane}
Rule set: ${rules}
EOF

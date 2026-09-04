#!/bin/sh
# Build a BRAND-NEW EMPTY repo for the two bootstrap routing cases.
#
# Their asks say "brand-new empty repo" and "build an app from my idea", so the
# fixture must actually be empty: a repo carrying a spec spine or a toolchain
# contradicts the prompt, and the session-start bootstrap nudge — the signal
# these cases exist to measure — only fires on an unmanaged tree.
#
# Referenced by context.scaffold_script and run only under
# `claude plugin eval --scaffold` (author-supplied bash, off by default;
# `mise run evals` passes the flag).
set -eu

git init -q .
git config user.email eval@example.com
git config user.name "eval"

cat >README.md <<'EOF'
# acme-notes

Nothing here yet.
EOF

git add -A
git commit -qm "Initial commit"

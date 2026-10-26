#!/bin/sh
# E2E case fixture - see ../README.md. A brand-new repo: git init and a README.
set -eu

git init -q .
# The sandbox has no init.defaultBranch, so HEAD would be `master` while the
# standards name `main` - and every 2026-09-04 run spent answer space on that.
git symbolic-ref HEAD refs/heads/main
git config user.email eval@example.com
git config user.name "eval"

cat >README.md <<'EOF'
# acme-notes

Nothing here yet.
EOF

git add -A
git commit -qm "Initial commit"

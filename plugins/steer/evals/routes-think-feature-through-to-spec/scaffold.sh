#!/bin/sh
# Build a minimal steer-managed repo for a routing case to run against.
#
# Without this, cases run in an empty temp dir whose git root is $HOME, and the
# correct answer to most asks becomes "there is nothing here" — which measures the
# sandbox, not the routing. Referenced by every case's context.scaffold_script and
# run only under `claude plugin eval --scaffold` (author-supplied bash, off by
# default; `mise run evals` passes the flag).
set -eu

git init -q .
git config user.email eval@example.com
git config user.name "eval"

cat >CLAUDE.md <<'EOF'
# Acme Checkout — product context

Payments service. Org engineering standards arrive from the steer plugin; this
file holds product-specific context only.
EOF

cat >mise.toml <<'EOF'
[tools]
python = "3.14"
EOF

mkdir -p spec/features/checkout

cat >spec/vision.md <<'EOF'
# Vision — Acme Checkout
One-page checkout for the Acme storefront.
EOF

cat >spec/tracker.md <<'EOF'
---
system: github
repository: acme/checkout
---
# Tracker
Issues live in GitHub.
EOF

cat >spec/features/checkout/intent.md <<'EOF'
---
feature_status: approved
---
> Tracker: acme/checkout#123
# Intent — one-page checkout
Shoppers complete a purchase without leaving the cart page.
EOF

printf 'def total(items):\n    return sum(i["price"] for i in items)\n' >checkout.py

git add -A
git commit -qm "Initial commit"

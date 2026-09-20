#!/bin/sh
# Build an OPENSPEC repo whose steer surface is behind - OpenSpec owns the spec
# spine, steer's tracker declaration is present, and pre-fold artifacts still sit
# in a thin spec/ beside it.
#
# That residue is what makes the ask answerable: the v6.4.0 ledger entry folds
# spec/tracker.md and spec/decisions/ under openspec/steer/, and /steer:sync is
# where both rule 33 and the unmanaged-repo hook send a repo carrying it. The
# tracker under openspec/steer/ is load-bearing - without it steer_spine_state
# prints `openspec-setup`, a different state with a different route.
#
# Referenced by context.scaffold_script and run only under
# `claude plugin eval --scaffold` (author-supplied bash, off by default;
# `mise run evals` passes the flag).
set -eu

git init -q .
# The sandbox has no init.defaultBranch, so HEAD would be `master` while the
# standards name `main` - and every 2026-09-04 run spent answer space on that.
git symbolic-ref HEAD refs/heads/main
git config user.email eval@example.com
git config user.name "eval"

cat >CLAUDE.md <<'EOF'
# Ferry Ledger - product context

Reconciliation service for ferry ticketing. Org engineering standards arrive
from the steer plugin; this file holds product-specific context only.

- Fares are integer minor units, never floats.
- A sailing is immutable once it has departed.
EOF

cat >mise.toml <<'EOF'
[tools]
python = "3.14"
uv = "latest"

[tasks.check]
run = ["uv run ruff check .", "uv run ruff format --check ."]

[tasks.test]
run = ["uv run pytest -q"]

[tasks.ci]
depends = ["check", "test"]
EOF

cat >pyproject.toml <<'EOF'
[project]
name = "ferry-ledger"
version = "0.1.0"
requires-python = ">=3.14"
dependencies = []

[dependency-groups]
dev = ["pytest>=8", "ruff>=0.12"]

[tool.pytest.ini_options]
testpaths = ["tests"]
EOF

cat >.gitignore <<'EOF'
.venv/
__pycache__/
.pytest_cache/
.ruff_cache/
.env
EOF

mkdir -p .github/workflows
cat >.github/workflows/ci.yml <<'EOF'
name: ci
on:
  pull_request:
  push:
    branches: [main]
permissions:
  contents: read
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: jdx/mise-action@v2
      - run: mise run ci
EOF

mkdir -p openspec/specs/reconciliation openspec/changes/add-refund-leg openspec/steer tests

cat >openspec/project.md <<'EOF'
# Ferry Ledger

Reconciles ticket sales against sailings. Spec work runs through the `/opsx:*`
commands; `openspec/specs/` is the deployed behaviour, `openspec/changes/` the
proposals in flight.
EOF

cat >openspec/specs/reconciliation/spec.md <<'EOF'
# Reconciliation

## Requirement: a sailing reconciles to its sold tickets

The ledger totals every ticket sold for a sailing and compares it to the fares
captured by the payment provider.

### Scenario: totals agree
- WHEN a sailing has three tickets at 1200 minor units each
- THEN the ledger reports 3600 and marks the sailing reconciled
EOF

cat >openspec/changes/add-refund-leg/proposal.md <<'EOF'
# Add a refund leg to reconciliation

## Why
A refunded ticket currently leaves the sailing permanently unreconciled.

## What changes
Reconciliation gains a refund leg, subtracted from the captured total.

## Open questions
- Does a partial refund reopen a reconciled sailing?
EOF

cat >openspec/changes/add-refund-leg/tasks.md <<'EOF'
# Tasks

- [ ] Model the refund leg
- [ ] Subtract it from the captured total
- [ ] Reconcile a sailing with one refunded ticket
EOF

cat >openspec/steer/tracker.md <<'EOF'
---
system: github
repository: ferry/ledger
---
# Tracker

Issues live in GitHub at `ferry/ledger`. Reference them as `ferry/ledger#N` from
the change proposal; every branch carries its issue number.
EOF

# Pre-fold residue: these two are exactly what the v6.4.0 ledger entry moves
# under openspec/steer/, and the reason this repo is a sync case at all.
mkdir -p spec/decisions
cat >spec/tracker.md <<'EOF'
---
system: github
repository: ferry/ledger
---
# Tracker

Issues live in GitHub at `ferry/ledger`.
EOF

cat >spec/decisions/0001-postgres-over-sqlite.md <<'EOF'
# 1. PostgreSQL over SQLite

Date: 2026-02-03
Status: Accepted
Deciders: @ferry-lead

## Context
Reconciliation runs concurrently with ticket sales.

## Decision
PostgreSQL, the same engine locally and deployed.

## Consequences
Local development needs Docker Compose.
EOF

cat >ledger.py <<'EOF'
FARE_MINOR = 1200


def sailing_total(tickets):
    return sum(t["fare"] for t in tickets)


def reconciled(tickets, captured):
    return sailing_total(tickets) == captured
EOF

cat >tests/test_ledger.py <<'EOF'
from ledger import reconciled, sailing_total


def test_total_sums_fares():
    assert sailing_total([{"fare": 1200}, {"fare": 1200}]) == 2400


def test_reconciled_compares_to_captured():
    assert reconciled([{"fare": 1200}], 1200)
EOF

git add -A
git commit -qm "reconciliation, spec'd in openspec"

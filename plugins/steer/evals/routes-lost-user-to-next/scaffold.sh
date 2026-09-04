#!/bin/sh
# Build a MANAGED steer repo — a complete, version-stamped /spec spine — for the
# routing cases whose ask presumes an already-bootstrapped product repo.
#
# Every session-start check must stay SILENT against this tree. A `foreign` spine
# (spec/ without spec/.version) makes check-unmanaged-repo.sh inject an adopt
# offer into every run, and the adopt digression then competes with the ask for
# the answer — measuring the fixture instead of the routing. Verify with:
#   printf '{"cwd":"<repo>"}' | sh plugins/steer/hooks/session-checks.sh
# and expect no output.
#
# Referenced by every managed case's context.scaffold_script and run only under
# `claude plugin eval --scaffold` (author-supplied bash, off by default;
# `mise run evals` passes the flag).
set -eu

git init -q .
# The sandbox has no init.defaultBranch, so HEAD would be `master` while the
# standards name `main` — and every 2026-09-04 run spent answer space on that.
git symbolic-ref HEAD refs/heads/main
git config user.email eval@example.com
git config user.name "eval"

cat >CLAUDE.md <<'EOF'
# Acme Checkout — product context

Payments service for the Acme storefront. Org engineering standards arrive from
the steer plugin; this file holds product-specific context only.

- Money is integer minor units, never floats.
- `checkout.total()` is the only public entry point today.
EOF

# Toolchain, manifest, CI and .gitignore are all present so that an audit finds
# the code defect, not the fixture: without them every 2026-09-04 run (next,
# spec, issues included) spent its answer on "no pyproject / no CI / no
# .gitignore" before reaching the ask.
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
name = "acme-checkout"
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

mkdir -p spec/features/checkout spec/decisions spec/history tests

# The ownership marker hooks/lib/spine.sh keys on. The stamp must match the
# plugin's own version: /steer:next reports a mismatch as version drift, which is
# one more nudge competing with the ask. tests/test_eval_suite.py pins the two
# together, so a release bump fails the suite until this is re-stamped.
cat >spec/.version <<'EOF'
# Spec-spine version — managed by /steer:init, /steer:adopt, /steer:build,
# /steer:sync. Do not edit by hand.
6.1.0
EOF

cat >spec/vision.md <<'EOF'
# Vision — Acme Checkout

## What
One-page checkout for the Acme storefront.

## Who
Shoppers on the Acme storefront; the payments team maintains it.

## Why
The three-step checkout loses shoppers at each hop.

## Success
Checkout completion rate above 60% on mobile.
EOF

cat >spec/users.md <<'EOF'
# Users — Acme Checkout

## Shopper
Buys one or two items and wants out. Job: pay without re-entering anything.

## Payments engineer
Owns the service. Job: change pricing rules without breaking totals.
EOF

cat >spec/glossary.md <<'EOF'
# Glossary — Acme Checkout

- **Cart** — the shopper's selected line items before payment.
- **Line item** — one product plus a quantity and a unit price in minor units.
- **Total** — the sum a shopper is charged, in minor units.
EOF

cat >spec/tracker.md <<'EOF'
---
system: github
repository: acme/checkout
---
# Tracker

Issues live in GitHub at `acme/checkout`. Reference them as `acme/checkout#N`
from intent and contract files; every branch carries its issue number.
EOF

cat >spec/history/README.md <<'EOF'
# Action history

One immutable file per action at `spec/history/YYYY-MM-DD-HHMM-<slug>.md`.
Nothing is ever appended to a shared file, so concurrent PRs cannot conflict.
EOF

cat >spec/history/2026-01-12-0900-bootstrap.md <<'EOF'
# 2026-01-12 09:00 — bootstrap

Installed the spec spine and the mise toolchain. Asked by the payments team.
EOF

cat >spec/features/checkout/intent.md <<'EOF'
# One-page checkout

> Owner: @acme-po
> Status: approved
> Created: 2026-01-14
> Tracker: acme/checkout#101
> Approved by: @acme-po
> Approved at: 2026-01-20

## PO acceptance

- [x] PO reviewed this intent
- [x] Open questions resolved or explicitly deferred
- [x] Approved for implementation
- [ ] PO validated the working demo

Approval comment/link: acme/checkout#101

## What this feature does

Shoppers complete a purchase without leaving the cart page.

## Why we are building it

The three-step checkout loses shoppers at every hop, and the drop-off is worst
on mobile. Collapsing it to one page removes two navigations.

Related issue: acme/checkout#101

## Design source

- **Traceability link:** none
- **Extraction source (path):** none
- **Type:** none
- **Captured by:** @acme-po
- **Date:** 2026-01-14

## User experience

1. Shopper reviews the cart and sees the total.
2. System shows the payment panel inline.
3. Shopper confirms and sees the confirmation panel on the same page.

## Acceptance criteria

- [x] A cart with two line items shows a total equal to the sum of unit price times quantity.
- [x] An empty cart shows a total of zero and a disabled pay button.
- [ ] A declined payment leaves the cart intact and shows the decline reason.

## Key concepts & data

- Cart — the shopper's selected line items; remembers its items until payment succeeds.
- Line item — a product, a quantity, and a unit price in minor units.
- Total — the amount charged, in minor units, derived from the line items.

## Lifecycle expectations

- A cart is discarded 30 days after its last change.
- A captured payment is never deleted; it is retained for reconciliation.

## What is in scope

- Cart totals, payment capture, the confirmation panel.

## What is out of scope

- Refunds, saved cards, multi-currency.

## Open questions

None outstanding — all questions were resolved before approval.
EOF

cat >spec/features/checkout/contract.md <<'EOF'
# One-page checkout — Contract

> Tracker: acme/checkout#101

## Behavior rules

- Each line item contributes `unit_price * quantity` to the total.
- A line item with no `quantity` counts as one.
- An empty cart totals zero.
- Totals are integer minor units; floats never enter the calculation.

## Data model

- `LineItem` — `sku: str`, `unit_price: int` (minor units), `quantity: int` (default 1).
- `Cart` — `items: list[LineItem]`.

## API surface

- `total(items: list[LineItem]) -> int` — the charge in minor units.

## Implementation pointers (optional)

- `checkout.py` holds the whole surface today.

## Dependencies

- None beyond the standard library.

## Notable decisions

- Minor units rather than Decimal: the payment gateway takes integers, and
  rounding at one boundary is cheaper to reason about than two.
EOF

touch spec/decisions/.gitkeep

cat >checkout.py <<'EOF'
def total(items):
    return sum(i["price"] for i in items)
EOF

cat >tests/test_checkout.py <<'EOF'
from checkout import total


def test_empty_cart():
    assert total([]) == 0
EOF

git add -A
git commit -qm "Initial commit"

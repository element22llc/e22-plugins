{
  "number": 123,
  "title": "Cart total ignores line-item quantity",
  "state": "open",
  "labels": ["bug", "checkout"],
  "url": "https://github.com/acme/checkout/issues/123",
  "author": "acme-po",
  "created_at": "2026-02-03T09:14:00Z",
  "body": "A cart with 3 of the same item is charged for 1.\n\n**Steps**\n1. Add SKU-9 (unit price 1250) with quantity 3.\n2. Open the cart page.\n3. The total shows 1250, not 3750.\n\n**Expected** — per `spec/features/checkout/contract.md`, each line item contributes `unit_price * quantity`, and a missing `quantity` counts as one.\n\n**Actual** — `checkout.total()` sums `i[\"price\"]` and never reads `quantity`.\n\nThis is the approved one-page-checkout feature (acme/checkout#101)."
}

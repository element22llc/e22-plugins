{
  "issues": [
    {
      "number": 123,
      "title": "Cart total ignores line-item quantity",
      "state": "open",
      "labels": ["bug", "checkout"],
      "body": "A cart with 3 of the same item is charged for 1. checkout.total() never reads quantity."
    },
    {
      "number": 118,
      "title": "Guest checkout",
      "state": "open",
      "labels": ["epic"],
      "body": "Let shoppers pay without an account. Covers session carts, email receipts, fraud limits, and the account-upgrade prompt afterwards. Needs breaking down before anyone starts."
    },
    {
      "number": 117,
      "title": "Multi-currency support",
      "state": "open",
      "labels": ["epic"],
      "body": "Charge in the shopper's currency. Touches pricing, the gateway, rounding rules, refunds, and reporting. No acceptance criteria yet."
    },
    {
      "number": 109,
      "title": "Decline reason is not shown to the shopper",
      "state": "open",
      "labels": ["bug", "checkout"],
      "body": "A declined card clears the cart and shows a generic error."
    },
    {
      "number": 101,
      "title": "One-page checkout",
      "state": "open",
      "labels": ["feature"],
      "body": "Tracking issue for the approved one-page-checkout intent in spec/features/checkout/."
    }
  ]
}

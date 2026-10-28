{
  "number": 45,
  "title": "Fix cart total ignoring quantity",
  "state": "open",
  "draft": false,
  "head": {
    "ref": "issue/123-cart-quantity"
  },
  "base": {
    "ref": "main"
  },
  "body": "Refs #123\n\nMultiplies unit price by quantity; adds a regression test.",
  "mergeable": true,
  "mergeable_state": "clean",
  "check_runs": [
    {
      "name": "ci",
      "status": "completed",
      "conclusion": "success"
    }
  ],
  "reviews": [],
  "url": "https://github.com/acme/checkout/pull/45"
}

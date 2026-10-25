---
type: regex
pattern: 'dynamo|boto'
flags: i
match: not_contains
target:
  source: file
  path: checkout.py
weight: 2
---

No DynamoDB code before the ADR is accepted.

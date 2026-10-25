---
type: regex
pattern: '(Closes|Fixes|Resolves) (acme/checkout)?#123'
flags: i
target: mock_calls
weight: 2
---

A PR is opened whose body carries the closing ref for #123.

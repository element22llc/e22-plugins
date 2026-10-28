---
type: regex
pattern: '"body"\s*:\s*"[^"]*(Closes|Fixes|Resolves) (acme/checkout)?#123'
flags: i
target: mock_calls
weight: 2
---

A PR closing #123 is opened.

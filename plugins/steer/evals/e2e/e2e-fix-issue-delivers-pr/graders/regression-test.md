---
type: regex
pattern: 'quantity'
target:
  source: file
  path: tests/test_checkout.py
weight: 2
---

A bug fix carries a regression test: the test file now exercises `quantity`.

---
type: regex
pattern: 'ValueError|zero or negative|non-positive|less than (one|1)|at least (one|1)'
flags: i
target:
  source: file
  path: spec/features/checkout/contract.md
weight: 3
---

A Behavioral change updates the owning `contract.md` in the same change.

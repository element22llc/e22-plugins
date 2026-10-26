---
type: regex
pattern: '\\.(jsx?|tsx?|py)$'
flags: m
match: not_contains
target: files
weight: 2
---

The build flow is spec-first: no application code before the idea is captured.

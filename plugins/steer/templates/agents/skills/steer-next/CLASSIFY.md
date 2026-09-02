# `/steer-next` — Phase 2: classify each observed state

Read this file when you reach Phase 2, with Phase 1's snapshot in hand. Phase 0
(locate the spine), Phase 1 (reconstruct state), Phase 3 (arbitrate) and Phase 4
(output) stay in `SKILL.md`, as do the reused contract and the routing table.

## Phase 2 — Classify each observed state

Map every reconstructed state to exactly one of the categories using this
workspace-level table — `/steer-next`'s own domain (cross-workflow arbitration),
keyed by reconstruction dimension, derived from the same vocabulary. The
parenthetical is the shared safety-precedence level (NEXT-ACTIONS.md §2).

| Reconstructed state | Category (safety level) | Routes to |
|---|---|---|
| Committed secret / destructive-risk exposure observed | Blocking now (L1) | Rotate & invalidate; then `/security-review` (no command rotates it) |
| Live, deployed feature actively exposing data / breaching users / losing integrity | Urgent live-system remediation (L1) | Remediate the live system now; then `/security-review` (no command remediates it) |
| Open `impact: blocking` question gating its `required_before` gate | Blocking now (L2) | `/steer-questions` |
| Proposed ADR awaiting ratification | Human decision required (L3) | The Deciders ratify/reject — answerable in-session via `/steer-adr` |
| Intent `draft`, drafted but not PO-approved | Human decision required (L3) | PO approves — answerable in-session via `/steer-spec` |
| PR open, awaiting review / in `validate` | Human decision required (L3) | A reviewer reviews (no command — **never** promptable) |
| Claimed issue mid-lifecycle (`in-progress` + branch), not yet at a PR | Blocking now — next transition (L4) | `/steer-work resume #N` |
| PR merged but issue still `validate` (stale tracker) | Human decision required (L3) — `validate → done` is propose-only, and a merged PR is necessary but not sufficient | `/steer-work resume #N` proposes `done` once acceptance is confirmed |
| Spine bootstrapped, next lifecycle step ready (e.g. open a PR) | Blocking now — next transition (L4) | owning skill |
| Open question `required_before: production-release`, feature not yet live (non-blocking now) | Required before initial production (L5) | `/steer-questions` |
| Open question `required_before: production-release`, feature already `live` (non-blocking now) | Required before next production release (L5) | `/steer-questions` |
| `ready-for-dev` issue queued; optional findings to publish/shape; `.version` stale | Recommended (L6) | `/steer-work start #N`, `/steer-issues …`, `/steer-sync` |
| Every workflow settled across all dimensions | Complete — no action required (L7) | — |

When the same state could plausibly fit two categories, the **derivation rule**
decides: a question's `impact:` and `required_before:` separate *Blocking now*
from the release-timing categories, and the feature's `Status` (live vs not)
chooses between *Required before initial production* and *Required before next
production release*; an unmerged PR is *Human decision required*, never
*Complete*.

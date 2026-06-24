# Label taxonomy — the canonical set `bootstrap-labels` reconciles

`/steer:issues bootstrap-labels` creates/reconciles exactly these labels
idempotently (`gh label create --force` = create-or-update). GitHub silently
drops a form/agent label that doesn't exist, so this must run before Issue Forms
and agent labelling are reliable.

**Labels are derived, never the source of truth.** `source:*` mirrors the
`steer:source` marker; lifecycle **state** is the `steer:state` marker (never a
label); **kind** is the `steer:kind` marker + the GitHub Issue **Type**. Do not
encode status, release, or kind as labels. **Priority and effort are native
GitHub issue fields, never labels** — `steer` reads them, and escalate-only
auto-sets Priority, via `/steer:tracker-sync` (`issue_priority` in `ENUMS.md`;
native-field contract in `ISSUE-SCHEMA.md`). Do not create `priority:*` labels.

## `source:*` — origin (mirrors `steer:source`)

| Label | Meaning | Color |
|---|---|---|
| `source:human` | Opened by a person (PO/dev) via a form or conversation | `0e8a16` |
| `source:adoption` | Productionization gap from `/steer:adopt` | `1d76db` |
| `source:audit` | Finding from `/steer:audit` | `5319e7` |
| `source:security-review` | Finding from `/security-review` | `b60205` |
| `source:code-review` | Finding from `/code-review` | `5319e7` |
| `source:ci` | Durable CI failure | `d93f0b` |
| `source:dependency` | Dependency upgrade/advisory | `0366d6` |
| `source:implementation` | Discovered while implementing another issue | `fbca04` |
| `source:spec` | Spec question or spec drift | `006b75` |

## `needs:*` — what's blocking readiness

| Label | Meaning | Color |
|---|---|---|
| `needs:triage` | Not yet classified | `ededed` |
| `needs:product-decision` | Awaiting a PO/stakeholder decision | `d93f0b` |
| `needs:technical-decision` | Awaiting a dev/architecture decision | `d93f0b` |
| `needs:spec` | Needs a spec before dev | `fbca04` |
| `needs:validation` | Implemented; awaiting acceptance | `0e8a16` |

## `risk:*` — review-sensitivity

| Label | Meaning | Color |
|---|---|---|
| `risk:high` | High-blast-radius change | `b60205` |
| `risk:security` | Touches auth, secrets, or exploitable surface | `b60205` |
| `risk:data` | Touches data integrity / migrations | `d93f0b` |

Colors are suggestions; `bootstrap-labels` reconciles name + description and
leaves an existing color untouched unless the team standardizes on these.

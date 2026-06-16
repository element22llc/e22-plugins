# Workflow-contract golden fixtures

Small, self-contained golden artifacts that pin the **observable output
contracts** of the major workflows, mirroring the spec's scenario tree.
They are validated by [`../../scripts/check_fixtures.py`](../../scripts/check_fixtures.py)
and are **not** executable repos — each file is the expected *shape* of an
artifact a workflow emits, so a regression in the shared contract surfaces in
review.

| Scenario | Pins |
|---|---|
| `greenfield-empty-repo/` | `/steer:init` output: required spec headings + a `## Recommended next actions` handoff block. |
| `adopted-existing-app/` | `/steer:adopt` must record inferred decisions as **Proposed** ADRs, never `Accepted`. |
| `production-app-with-open-issues/` | A production handoff block does not misuse "Required before production" for optional work; lifecycle state + hidden markers stay valid. |
| `spec-drift-repo/` | `/steer:drift` output ends in a valid handoff block with a valid category. |

The authoritative contract definitions live in
[`../../plugins/steer/templates/reference/NEXT-ACTIONS.md`](../../plugins/steer/templates/reference/NEXT-ACTIONS.md)
and the plugin's own fixtures; these scenarios exercise the same vocabulary.

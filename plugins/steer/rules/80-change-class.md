<!-- steer:inject-when=code-project -->
## Change classification

Three classes set per-change ceremony, and **Issue-first takes its threshold
from here**. The Definition of Done holds in full for every class - what the
class scales is the ceremony around the change, not what "done" means. Classify
by **what the change does**, never by how many lines it touches; when two
readings are arguable, take the heavier one.

- **Trivial** - no observable behavior change: copy, formatting, comments,
  a behavior-preserving refactor, generated output, lockfiles. Open a PR and
  stop - no issue, no spec, no ADR, no plan; **the PR is the work record**.
- **Behavioral** - observable behavior changes, for a user, a caller, or an
  operator. Carries tests in the same PR and updates the owning `contract.md`;
  a planned feature writes its `intent.md` first and gets PO approval (Spec
  workflow). Start in plan mode, or post the plan, whenever the approach is
  worth reviewing before it is written.
- **High-risk** - anything in the High-risk areas list, at any size. Scope with
  the dev before any code, contract or ADR first, smaller PRs, line-by-line
  review. Never Trivial, and never treated as merely Behavioral.

A choice that is **costly to reverse** - stack, data model, tenancy, deployment -
takes an ADR before the code (Spec workflow), whatever its class.

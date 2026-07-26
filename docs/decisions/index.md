# Decisions (ADRs)

Hard-to-reverse or cross-cutting choices are recorded as **Architecture Decision
Records (ADRs)**. In a managed product repo, ADRs live in the `/spec` spine; for
the plugin itself, decisions are captured in `CHANGELOG.md` and PRs.

## When to write an ADR

Use [`/steer:adr`](../reference/skills.md) for any hard-to-reverse or
cross-cutting choice — stack, database, auth, deployment, a new pattern — or when
asked to record a decision.

```mermaid
flowchart TD
    Q{Hard to reverse<br/>or cross-cutting?} -->|No| SKIP[No ADR needed]
    Q -->|Yes| PROPOSED[ADR: Proposed]
    PROPOSED --> REVIEW{Ratified by a human?}
    REVIEW -->|Yes| ACCEPTED[ADR: Accepted]
    REVIEW -->|Superseded later| SUPERSEDED[ADR: Superseded]
```

## ADR status

New ADRs default to **Proposed** — the fixture suite asserts this. An ADR becomes
**Accepted** only on an explicit human decision.

!!! warning "No ADR from inference"
    Reverse-engineering skills (`/steer:adopt`) must **never infer a ratified ADR
    from code**. An ADR records a decision a human made; the as-built spine
    records what exists. See [Product spine](../concepts/product-spine.md).

## Plugin-level decisions

Routine changes to the plugin's own behavior are recorded in `CHANGELOG.md` under
`## steer` → `### [Unreleased]`, and the rationale lives in the PR. See
[Release process](../contributing/release-process.md).

An **architectural** decision about the plugin — one that is hard to reverse or
cuts across many skills, rules and templates — gets its own numbered ADR on this
page instead, because a CHANGELOG bullet cannot carry the alternatives and
consequences such a choice needs. Same template and same status lifecycle as a
product ADR.

### Records

| ADR | Status | Summary |
|---|---|---|
| [0001 — Polyrepo workspace repository](0001-polyrepo-workspace-repository.md) | Proposed | Support polyrepo products via a workspace repo that is also the spine repo, with members as manifest-driven clones rather than submodules. |

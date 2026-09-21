---
name: reference
description: "Internal loader - one of steer's full reference docs, read-only: conventions, traceability, design-sources, context-hygiene, architecture-diagrams, artifacts, gates, polyrepo."
when_to_use: "Reached when a rule or a skill points at a reference topic - not a direct entry point."
argument-hint: "[conventions | traceability | design-sources | context-hygiene | architecture-diagrams | artifacts | gates | polyrepo]"
# Internal prose loader. The rules and the skills name the topic they need
# (`/steer:reference conventions`), so the model reaches this skill from a
# cross-reference rather than the user picking a doc name off a menu - and the
# listing no longer pays for trigger vocabulary the cross-references already carry.
user-invocable: false
disallowed-tools: Edit, Write, NotebookEdit, EnterWorktree
---

<!-- steer:modes conventions,traceability,design-sources,context-hygiene,architecture-diagrams,artifacts,gates,polyrepo -->

# Reference prose loader

Pick the topic for the question and **open the bundled reference file** for it,
then answer from that file. These are the full-detail companions to the lean
always-on rules - open the file rather than answering from memory, and if
something is genuinely unclear or the project warrants deviating, record an ADR
(`/steer:spec adr`) rather than guessing.

| Topic | Reference file | Use for |
|---|---|---|
| `conventions` | `CONVENTIONS.md` | Tooling/convention questions, stack-default rationale. |
| `traceability` | `TRACEABILITY.md` | Living docs, tracker refs, drift flags, audit evidence, PO vs dev split, keeping internal ids out of end-user copy. |
| `design-sources` | `DESIGN-SOURCES.md` | Features from a Claude Design export/URL, Figma, or screenshots. |
| `context-hygiene` | `CONTEXT-HYGIENE.md` | Keeping a long/multi-phase run from bloating the session; subagent delegation and durable state that survives compaction. |
| `architecture-diagrams` | `ARCHITECTURE-DIAGRAMS.md` | Authoring/maintaining the global system diagram: Tier 1 Mermaid vs Tier 2 LikeC4, which diagram types, and keeping it in sync. |
| `artifacts` | `ARTIFACTS.md` | How a skill renders a shareable page as a Claude Artifact: when to, the derived-view discipline, CSP/inline mechanics, the styling contract (`DESIGN.md` tokens or the house default), the temp-path write invariant, the fillable-page return leg, and the Markdown fallback. |
| `gates` | `GATES.md` | Ratifying an ADR, approving an intent, or signing off a plan **in-session**: the three-option prompt, what it must show, how the decision is recorded, and the gates no prompt can satisfy. |
| `polyrepo` | `POLYREPO.md` | A product spanning several repos: the workspace/member split, where each spec artifact lives, resolving the spine from a member, honest report scope, and what crosses the repo edge (sub-issues yes, closing keywords no, drift gates no). |

## Load the file, don't answer from the table

Each topic maps to one file under
`${CLAUDE_PLUGIN_ROOT}/templates/reference/`:

| Topic | Open this file |
|---|---|
| `conventions` | `CONVENTIONS.md` |
| `traceability` | `TRACEABILITY.md` |
| `design-sources` | `DESIGN-SOURCES.md` |
| `context-hygiene` | `CONTEXT-HYGIENE.md` |
| `architecture-diagrams` | `ARCHITECTURE-DIAGRAMS.md` |
| `artifacts` | `ARTIFACTS.md` |
| `gates` | `GATES.md` |
| `polyrepo` | `POLYREPO.md` |

**Read the file itself and answer from it.** The table above (and its `Use for`
column earlier in this skill) is for *routing* only - it is deliberately not a
substitute for the prose, and answering from it instead of opening the file is
the failure mode this loader exists to prevent.

If you need a fuller contents listing to choose between two topics, read
[`COVERAGE.md`](${CLAUDE_PLUGIN_ROOT}/skills/reference/COVERAGE.md) - an index
of what each doc contains. It is still an index, not the prose.

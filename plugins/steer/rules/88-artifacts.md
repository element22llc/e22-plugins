## Shareable views → Claude Artifacts

When a skill's output is a **shareable, at-a-glance view** someone hands to a
stakeholder — a feature summary, a report/dashboard, a release timeline, a
capability menu, a fillable questionnaire — render it as a **Claude Artifact**
(a default-private hosted page on claude.ai), not a wall of terminal text. Fall
back to inline Markdown where the Artifact tool is unavailable — the fallback
is not a failure.

An Artifact is a **derived view, never a source of truth**: every visual
encodes a real value the source (spec, tracker, audit) actually contains —
never fabricate a status, date, count, or finding, and never advance a marker
past what the source records. Always an on-demand render or an offer — never
auto-generated per feature or on a schedule — and never carrying secrets or
(on a stakeholder page) internal detail. Its only write is the page HTML to a
**system temp dir, never under the repo tree**; don't persist the URL in the
repo.

Style the page from the repo's `DESIGN.md` tokens when present, else the
`artifact-design`/`dataviz` house default — never an invented brand. A fillable
page returns data **only through its exported, machine-keyed document**
ingested by its owning skill (the PO questionnaire → `/steer:intake clarify`).

Mechanics, the full derived-view discipline, the styling contract, the
Markdown-fallback shape, and which skill renders what:
`/steer:reference artifacts`.

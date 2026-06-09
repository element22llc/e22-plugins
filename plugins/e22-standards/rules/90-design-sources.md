## Design sources

Features often originate from a **Claude Design** export. Claude **cannot**
fetch a Claude Design URL (it 403s) — read the **local export** the PO
committed. The design is authoritative for visual behavior and flow; the spec
for what the system does — conflicts go to `/spec/SPEC-QUESTIONS.md`. The export
is a **spec to realize in the standard stack, not code to ship**: its delivery
tech (UMD React, in-browser Babel, hand-rolled CSS) is disposable scaffolding —
serving the prototype runtime as a maintained surface is an **ADR-gated,
kill-dated exception**, never the default. Full walkthrough (artifact paths,
what to read, what not to invent, realize-vs-serve): run **`/e22-design-sources`**.
Product-wide UI rules live in the product's `DESIGN.md` (or `apps/<app>/DESIGN.md`).

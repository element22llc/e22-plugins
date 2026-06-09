---
description: Sweep loose files out of the repo root into their correct E22 home (/spec/reference, /spec/design) — moving, renaming, and (with confirmation) deleting. Proposes a plan first and never acts without a yes.
---

Tidy this repository's root by following the `e22-tidy` skill.

List the loose files sitting at the repo root, drop everything on the root
allowlist and the known dirs, and classify the rest: source/research materials
(spreadsheets, inventories, vendor metadata, schema dumps, discovery/CMDB/PII
docs) → `/spec/reference/`; architecture and flow diagrams → `/spec/design/`.
Propose a clearer name for any cryptic or inconsistently-named file. For
anything whose purpose or correct home is unclear — including `Copy of …` and
duplicate-looking files, which may be the important one — **ask the PO/dev what
it is and which version is current** before deciding; never assume an odd name
means junk. Present the plan as a table with a `move` / `rename + move` /
`delete` action column and get approval before touching anything. Use `git mv`
for tracked files (moves and renames; history follows). Only true junk
(`desktop.ini`, `.DS_Store`, `Thumbs.db`) is ever deleted, and only on
confirmation — and when you delete it, add its pattern to `.gitignore` so it
can't be re-introduced. Do not commit until the user approves.

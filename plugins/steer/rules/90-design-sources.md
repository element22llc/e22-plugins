<!-- steer:inject-when=code-project -->
## Design sources & UI

Most features have **no design export, or only a partial one** — that is the
normal case, not a blocker. When an export *is* committed (Claude Design ZIP,
Figma, screenshots), read the **local export** — Claude **cannot** fetch a Claude
Design URL (it 403s). The export is authoritative for the **visual behavior and
flow it actually shows**; the spec for what the system does; gaps and conflicts
go to the feature's `intent.md` → `## Open questions`. It is a **spec to realize
in the standard stack, not code to ship**: its delivery tech (UMD React,
in-browser Babel, hand-rolled CSS) is disposable — serving the prototype runtime
is an **ADR-gated, kill-dated exception**, never the default.

When the design is absent or partial — the common case — **build the UI
deliberately instead of defaulting to generic AI aesthetics**: the
**`frontend-design`** plugin (installed from this marketplace) carries that
craft; these standards scope it to a professional/enterprise default, the standard stack
(Next + TS + Tailwind), and accessibility.

Whichever way a feature's UI originates, **capture the reusable decisions in
`DESIGN.md`** (repo root, or `apps/<app>/DESIGN.md`) — populated as you build and
promoting anything that recurs — so every feature stays visually uniform. Full
walkthrough (artifact paths, what to read, what not to invent, realize-vs-serve,
no-export build): run **`/steer:reference design-sources`**.

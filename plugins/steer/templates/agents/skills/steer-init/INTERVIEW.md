# `/steer-init` — Path B steps 3 & 4: fill the spine, record the stack ADR

Read this file when you reach step 3 of Path B, with step 2's scaffold in place
and the polyrepo role resolved. Steps 1–2 (confirm the mode + profile,
instantiate the scaffold — the latter in `SCAFFOLD.md`) and steps 5–7 (pin the
toolchain, proceed spec-first, hand off) stay in `SKILL.md`, as do the
guardrails.

3. **Interview to fill the spine.** Ask the dev (or PO) the minimum to populate
   `vision.md`, `users.md`, `glossary.md`, the README placeholders, **and
   `/spec/tracker.md`** (which issue tracker does this product use — Jira,
   GitHub Issues, Linear, Azure DevOps, other, none yet — and its
   project/reference format). **Ask, don't invent**; route product-level
   ambiguity to `vision.md` → `## Open questions` rather than guessing.
   Confirm or override the stack defaults (the always-on Stack rules). A
   PO-driven idea→app flow runs through `/steer-build` instead.
   - **In a polyrepo member** (step 2 resolved the role): `vision.md`,
     `users.md`, `glossary.md` and `/spec/tracker.md` are the **workspace's** —
     step 2 skipped creating them, so do not interview for them and never write
     them locally. Fill only the README placeholders and confirm the stack
     defaults; product-level ambiguity goes to the workspace's `vision.md`.
   - **If the tracker is GitHub Issues**, run `/steer-issues bootstrap-labels` to
     create the `source:*` / `needs:*` / `risk:*` taxonomy (GitHub silently drops
     a form label that doesn't exist), then `/steer-tracker-sync bootstrap-fields`
     to verify the native **Priority/Effort/date** issue fields are available (it
     reports a capability gap or option mismatch; it never fabricates org config).
     **In a member, skip both** — the tracker is declared once in the workspace,
     which bootstraps it against the tracker repo.
4. **Record the initial stack as the first ADR.** The stack choice is usually
   the first decision worth an ADR — run `/steer-adr`. **Any deviation from the
   defaults** (e.g. a standalone Python/Typer CLI instead of Next.js/TS, or
   Python + FastAPI instead of the in-Next backend) **must** get one either way.
   **Status follows who decided.** When the dev *explicitly* chooses the stack in
   this interactive setup, that is a real forward decision: author the ADR as
   **`Accepted`** with the dev as the named **Decider** and today's date — and
   stamp the ratification fields the template carries, `> Ratified by:` (the dev),
   `> Ratified at:` (today) and `> Ratified via: in-session`. Every `Accepted` ADR
   carries them (rule `61-gate-prompts`; `/steer-next` reports one that doesn't as
   incomplete), and the channel stamp is what makes an in-session decision
   auditable. When
   Claude merely *recommended* a default and the dev made no explicit choice,
   leave it **`Proposed`** until a named decider accepts it — generic
   bootstrap-PR approval does **not** ratify a `Proposed` ADR. (Contrast
   **`/steer-adopt`**, which only *observes* existing code and so always
   authors `Proposed` ADRs.) Now that the stack is decided, **fill
   `ARCHITECTURE.md`** — the stack table from `package.json` / `mise.toml` /
   `compose.yaml`, the apps/packages map from the scaffold layout, and the
   cross-cutting concerns from the ADRs just authored. Don't leave the
   placeholders; a stub `ARCHITECTURE.md` is the same drift the app guide
   suffers when it's left unfilled.

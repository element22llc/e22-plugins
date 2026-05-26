# handoff-packager — per-section guidance

Loaded into every Claude session when `handoff-packager` is installed.
Provides detailed guidance for filling each section of `HANDOFF.md` when the
natural-language handoff trigger fires (see `plugins/e22-org/CLAUDE.md` →
"Handoff trigger").

The template lives at `plugins/e22-org/templates/HANDOFF.md.template`. This
plugin does not own a slash command — generation is triggered by natural
language and always lands at the workspace root, never under `proposals/`.

## Output location

Always: `<workspace-root>/HANDOFF.md`.

Never: `proposals/<slug>/handoff/*` (that scheme was removed in v0.2.0 with
the v0.4 spec revision — spec v0.4 §7.2 mandates a single file by default).

## Section-by-section guidance

### 1. Product intent

User problem, target users, desired outcome, success criteria. Pull from the
PO's earliest messages — the framing they used before iteration changed the
shape. One paragraph each is enough.

### 2. Prototype behavior

What the MVP currently does, including main flows and important screens.
Concrete, observable behavior — not implementation detail. Each main flow
gets a sub-bullet.

### 3. UX decisions

Copy, layout, interaction, workflow, and variant decisions the PO made during
exploration. Include rejected alternatives where the user explicitly chose
between options ("we tried X but went with Y because…").

### 4. Demo evidence

Links or references to screenshots, recordings, local preview notes, or
artifacts collected during the session. If `assets/` exists at the workspace
root, list the relevant files. If a Claude Artifact URL is in the chat,
include it.

### 5. Files and dependencies

Important files in the workspace, libraries added, tools used, generated
assets, external packages. For each dependency: name and pinned version.

### 6. Data model implications

Entities, fields, relationships, persistence assumptions, fake data used.
Include the shape of any in-memory or temporary database schema. Note where
real production data would replace fake.

### 7. External service implications

Auth, payments, email, maps, AI APIs, storage, queues, or other integrations
the prototype implies but does not actually call. List what production would
need to provision.

### 8. Security, privacy, and compliance risks (MANDATORY)

PII, auth, permissions, billing, secrets, abuse vectors, retention, audit
concerns. Do not leave blank. If no risks were identified, write `No
evidence collected during this session.` — but think carefully first: most
real systems have at least an auth and PII surface.

### 9. Known shortcuts and hacks (MANDATORY)

Prototype shortcuts, hardcoded values, mock services, fake users, fragile
paths. **Every shortcut Claude knowingly took during the session belongs
here.** Examples: hardcoded admin user, mock auth bypass, no rate limiting,
inline secrets for the demo, fragile parsing of a vendor format.

### 10. What must not be reused (MANDATORY)

Anything that would be unsafe or irresponsible to carry into production.
Often overlaps with §9 but framed as a forward-looking prohibition. If §9
contains "hardcoded admin user 'alice'", §10 contains "the mock auth flow
must be replaced before production — do not copy."

### 11. Manual test notes

What was tried manually, what worked, what failed, known bugs. Include any
test data used.

### 12. Suggested production tests (MANDATORY)

Unit, integration, E2E, accessibility, security, and regression tests Dev
should add. Be specific: "POST /checkout with an empty cart should 400" beats
"add tests for the checkout flow."

### 13. Open product questions (MANDATORY)

Decisions the PO or team still needs to make. Each entry is a question, not a
statement. If the PO said "we'll figure out pricing later," that's an open
question: "What pricing tiers, and what's free vs paid?"

### 14. Suggested Dev decision

Exactly one of: **Harden / Extract / Rewrite / Reject / Continue exploring**
(spec v0.4 §7.4). For brand-new MVPs the default is Extract or Rewrite;
Harden is allowed only when Dev has reviewed the implementation and accepts
ownership of the technical choices.

### 15. Rationale

2-5 sentences explaining the §14 decision. Anchor to evidence from earlier
sections, especially §8/§9/§10 — the risks and shortcuts drive most
Refactor/Rewrite decisions.

## Mandatory sections — fill them, don't fabricate

Sections 8, 9, 10, 12, 13 must not be left blank. Spec v0.4 §7.3 lists them
as mandatory because they prevent prototype shortcuts from migrating into
production by inertia.

If you genuinely have no evidence for a section, write `No evidence
collected during this session.` — that is honest and gives Dev a clear
signal. Fabricating content that "looks like" a real risk or a real test
suggestion is worse than admitting the session didn't surface one.

## Don't drift into `proposals/`

The v0.3 multi-file bundle (`proposals/<slug>/handoff/{dependency-delta,
novel-patterns, plugin-violations}.md`) was removed. Spec v0.4 §7.2: *"use
one file by default: `HANDOFF.md`. Do not create multiple required markdown
files until the single-file packet has proven insufficient."*

If the team later decides a multi-file bundle is needed (e.g., a Dev-side
post-import audit), that's a separate feature — do not add it implicitly
during handoff generation.

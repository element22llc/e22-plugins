---
name: new-rule
description: >-
  Scaffold a new always-on rule under plugins/steer/rules/ — list taken
  numeric prefixes, propose the next free gap slot, create a lean imperative
  NN-slug.md stub, and add a changelog fragment. Repo-local dev
  helper for e22-plugins; does not ship.
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Bash(uv run python scripts/check_plugin.py)
  - Bash(mise run plugin-check)
---

# /new-rule — scaffold an always-on rule

Repo-local convenience wrapper. See `AUTHORING.md` → "Rule numbering" for
the rules it follows.

## Steps

1. **List taken prefixes:** `Glob plugins/steer/rules/*.md` and read the leading
   `NN-` of each. Rules concatenate in lexical order; prefixes run `00`–`99` with
   intentional gaps.

2. **Propose a slot:** ask the user which existing rule the new one relates to,
   then pick the largest free gap **adjacent** to it (e.g. between `35-` and
   `36-` there is no gap → look at neighbours; between `20-` and `22-` propose
   `21-`). Never reuse or renumber an existing prefix. Confirm the chosen slot
   with the user.

3. **Create `plugins/steer/rules/NN-<slug>.md`** as a lean, imperative stub —
   a short directive heading and a few bullet points. Keep it terse: this is
   always-on session context. Do not include `TODO`/`FIXME`/`[Replace` tokens.

4. **Push prose elsewhere:** if the rule needs rationale, examples, or long
   explanation, create or extend a file under
   `plugins/steer/templates/reference/` and have the rule point to it rather than
   inlining it.

5. **Add a changelog fragment:** write
   `.changes/unreleased/added-<YYYYMMDD>-<HHMM>-rule-<slug>.yaml` with
   `kind: Added`, `custom.Slug: rule-<slug>`, and a `body: |` block holding
   `- **Added: rule NN-<slug>.** <one-line>.` Never touch `CHANGELOG.md` — it is
   generated at release.

6. **Validate and report:** run `mise run plugin-check`, report pass/fail, and
   remind the user to keep the rule lean and run `mise run check` before
   committing.

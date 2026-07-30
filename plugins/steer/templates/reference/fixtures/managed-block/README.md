# Managed-block conformance fixtures

These paired `*.input.md` / `*.expected.md` files are **normative conformance
examples** for the managed-block update protocol and human-form normalization in
[`../../ISSUE-SCHEMA.md`](../../ISSUE-SCHEMA.md). They improve consistency across
sessions and models; they are **not** automated enforcement (this repo has no
test runner). A skill author or reviewer applies the documented operation to
`*.input.md` and checks the result byte-for-byte against `*.expected.md`.

Each transform fixture models **one** operation, named in its table row below.
Apply *that row's* operation — not a single shared one — and the result must match
`*.expected.md` byte-for-byte, preserving everything outside
`steer:managed:start`/`end` verbatim unless the row says otherwise.

Two of them (`preserve-human-notes`, `unknown-marker-survival`) use the canonical
whole-block rewrite:

```md
## Outcome

Updated by agent.
```

The other three deliberately do not: one appends **inside** the block, one appends
the block **below** a preserved human body, and one rewrites frontmatter markers
**outside** it. Applying the canonical rewrite to those three cannot reproduce
their `.expected.md`.

| Fixture | Operation it models | What it proves |
|---|---|---|
| `preserve-human-notes` | Canonical whole-block rewrite | Content **outside** the block (human `## Team notes`) is preserved byte-for-byte. |
| `unknown-marker-survival` | Canonical whole-block rewrite | An unknown-but-valid marker (`steer:custom=…`) survives the rewrite. |
| `epic-link-child-feature` | **Append inside** the block | A new child ref (`- [ ] #42 — …`) is appended to the `## Child features` list *within* the block; the rest of the block, including the existing `## Outcome` prose, is preserved. |
| `human-form-normalization` | **Append the block below** a preserved body | First touch of a human form: original body kept verbatim on top, markers + managed block **appended** below. |
| `schema-migration` | **Rewrite markers outside** the block | A `schema=1` `audit-finding` migrates to `schema=2` `finding` + `source:audit`; the prior kind is accepted. |

## Fail-closed cases (no `.expected.md` transform — behavior, not output)

- **Duplicate / malformed block** (`duplicate-block.input.md`): more than one
  `steer:managed:start`/`end` pair. The agent **must leave the body unchanged**,
  report the conflict, and propose a repaired body — it must never guess which
  block is authoritative or auto-delete either. Expected output = the input,
  unchanged.
- **Concurrent edit**: if the body changes between the agent's read and its
  write, recompute once; if it changes again, **stop and report**. This is a
  runtime guard with no static fixture — see the update protocol, steps 4–7.

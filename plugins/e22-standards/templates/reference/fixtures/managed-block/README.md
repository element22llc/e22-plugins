# Managed-block conformance fixtures

These paired `*.input.md` / `*.expected.md` files are **normative conformance
examples** for the managed-block update protocol and human-form normalization in
[`../../ISSUE-SCHEMA.md`](../../ISSUE-SCHEMA.md). They improve consistency across
sessions and models; they are **not** automated enforcement (this repo has no
test runner). A skill author or reviewer applies the documented operation to
`*.input.md` and checks the result byte-for-byte against `*.expected.md`.

The transform fixtures all model the **same** operation: *rewrite the managed
block to the canonical new content*

```md
## Outcome

Updated by agent.
```

…while preserving everything outside `e22:managed:start`/`end` verbatim.

| Fixture | What it proves |
|---|---|
| `preserve-human-notes` | Content **outside** the block (human `## Team notes`) is preserved byte-for-byte. |
| `unknown-marker-survival` | An unknown-but-valid marker (`e22:custom=…`) survives the rewrite. |
| `human-form-normalization` | First touch of a human form: original body kept verbatim on top, markers + managed block **appended** below. |
| `schema-migration` | A `schema=1` `audit-finding` migrates to `schema=2` `finding` + `source:audit`; the prior kind is accepted. |

## Fail-closed cases (no `.expected.md` transform — behavior, not output)

- **Duplicate / malformed block** (`duplicate-block.input.md`): more than one
  `e22:managed:start`/`end` pair. The agent **must leave the body unchanged**,
  report the conflict, and propose a repaired body — it must never guess which
  block is authoritative or auto-delete either. Expected output = the input,
  unchanged.
- **Concurrent edit**: if the body changes between the agent's read and its
  write, recompute once; if it changes again, **stop and report**. This is a
  runtime guard with no static fixture — see the update protocol, steps 4–7.

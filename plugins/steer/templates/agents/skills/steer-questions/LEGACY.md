# Legacy question formats (`/steer-questions`)

Read this **only** when a sweep meets one of the two pre-structured-format
artifacts below. Both are migration paths for repos forked from an older
template revision; a repo on the current spine never hits either.

## 1. A legacy `spec/SPEC-QUESTIONS.md`

A fork from a pre-1.25.0 template revision may still carry the retired
standalone questions file. There is **no `SPEC-QUESTIONS.md`** in the current
spine — questions live next to their context.

Its heal is the **v1.25.0 migration entry** in
[`MIGRATIONS.md`](../../templates/reference/MIGRATIONS.md), applied as a
**hard gate before gathering**: migrate the questions into the spine and
**delete the file in the same step**. This is a move, not an answer — the
deletion never waits on answers. Then sweep the migrated copies like any other
question.

## 2. Legacy `- [ ]` checkbox items

A spec predating the structured `### Q-NNN` format may still carry plain
`- [ ]` items.

**In scope** are only those **inside a `## Open questions` section and outside
any `### ` block** — the scope `check-open-questions.sh` counts as backlog
(`inq && !inblk`, skipping a bracketed `[placeholder]` rest) for one deprecation
window.

```sh
grep -rn -A20 '^## Open questions' spec/vision.md spec/features/*/intent.md \
  spec/PRODUCTIONIZATION.md 2>/dev/null | grep -E '^\S+[:-][0-9]+[:-]- \[ \] '
```

The grep anchors the *section* but cannot express the rest: it has no block
state, so **you** must drop any hit that sits inside a `### Q-NNN` block (a
sub-task bullet within a question is part of that question, not a separate one —
never split it out) or whose text is a bracketed placeholder.

**Never sweep a `- [ ]` line outside that section.** `## PO acceptance`, the
acceptance criteria, and the productionization gap checklists are `- [ ]` too,
and they are **gates** — `/steer-spec approve` ticks them. Converting one into a
`Q-NNN` block, or closing it as `resolved`, destroys the PO gate. Confirm each
hit's section before touching it.

In-scope legacy items are swept like any other question, and **converted into a
`### Q-NNN` block as you resolve one** — this skill is the opportunistic
converter the **v1.38.0** migration entry names
([`MIGRATIONS.md`](../../templates/reference/MIGRATIONS.md)); never bulk-rewrite
a file just to convert. A legacy item you resolve this run must not be left as a
checkbox.

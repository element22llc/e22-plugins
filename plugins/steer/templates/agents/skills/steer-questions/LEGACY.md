# Legacy question formats (`/steer-spec questions`)

Read this **only** when a sweep meets one of the two pre-structured-format
artifacts below. Both are migration paths for repos forked from an older
template revision; a repo on the current spine never hits either.

## 1. A legacy `spec/SPEC-QUESTIONS.md`

A fork from a pre-1.25.0 template revision may still carry the retired
standalone questions file. There is **no `SPEC-QUESTIONS.md`** in the current
spine - questions live next to their context.

Its heal is the **v1.25.0 migration entry** in
[`MIGRATIONS.md`](https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/templates/reference/MIGRATIONS.md), applied as a
**hard gate before gathering**: migrate the questions into the spine and
**delete the file in the same step**. This is a move, not an answer - the
deletion never waits on answers. Then sweep the migrated copies like any other
question.

## 2. Legacy `- [ ]` checkbox items

A spec predating the structured `### Q-NNN` format may still carry plain
`- [ ]` items. The window in which they counted as ordinary backlog is **closed**:
they have no status, owner, gate, or date, so nothing can age or route them, and
waiting to convert each "as it is touched" left untouched features carrying them
forever. Convert them all, **before** gathering.

**In scope** are only those **inside a `## Open questions` section and outside
any `### ` block**, skipping a bracketed `[placeholder]` rest - the exact scope
`lib/questions.sh` reports and `check-open-questions.sh` flags. A `- [ ]` bullet
*inside* a `### Q-NNN` block is part of that question, never a separate one.

**Never touch a `- [ ]` line outside that section.** `## PO acceptance`, the
acceptance criteria, and the productionization gap checklists are `- [ ]` too,
and they are **gates** - `/steer-spec approve` ticks them. Converting one into a
`Q-NNN` block, or closing it as `resolved`, destroys the PO gate.

Don't hand-convert: run the converter the **legacy-checkbox** entry in
[`MIGRATIONS.md`](https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/templates/reference/MIGRATIONS.md) names, which applies
that scope mechanically and dates each question from its original line:

```sh
sh "https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/scripts/convert-legacy-questions.sh"          # proposed diff, writes nothing
sh "https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/scripts/convert-legacy-questions.sh" --apply  # after a yes
```

Show the diff, apply it on a yes, then sweep the converted blocks like any other
question. Each comes out `impact: non-blocking` with a blank `owner:` - triage
sets both as you work through it.

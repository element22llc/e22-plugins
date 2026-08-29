# `/steer-work` — closing ref when the tracker lives in another repo

Read this file at `finish` (or before writing any trunk-commit trailer in
solo-trunk) **only if** `/spec/tracker.md` declares a `repository:`. When it
does not, or the value is absent/placeholder/unreadable, the answer is plain
`Closes #N` — the overwhelmingly common path — and there is nothing to check.

GitHub honours issue-closing keywords **only within one repository**. When
`/spec/tracker.md` declares a `repository:` that is not the repo the code lives
in, a `Closes #N` — or even a fully-qualified `Closes owner/repo#N` — renders as
a plain cross-reference and **the issue silently stays open**. Nothing warns, and
because this skill treats the merged PR as lifecycle-transition evidence, the
issue never advances state either.

Resolve both sides before writing any closing ref:

```sh
sh "https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/scripts/scan-spine-state.sh"   # `- tracker repo:` ← /spec/tracker.md
gh repo view --json nameWithOwner -q .nameWithOwner      # the repo the code lives in
```

`- tracker repo: none declared` covers all three no-op cases at once — no
`spec/tracker.md`, no `repository:` key, and the unresolved
`[owner/repository]` placeholder.

Compare them **case-insensitively** (GitHub owner/repo names are), then:

| | Closing ref | Closure |
| --- | --- | --- |
| Same repo (or either value unreadable) | `Closes #N` — unchanged | GitHub auto-closes on merge |
| **Proven different** | `Refs owner/repo#N` | **You** close it: `/steer-tracker-sync close` after the merge |

Divert **only on positive proof of a mismatch**. An absent tracker file, an
unresolved `[owner/repository]` placeholder, an empty value, or a failed
`gh repo view` all keep `Closes #N` — that is the overwhelmingly common path and
it must stay exactly as it is. Do not derive the code repo by parsing
`git remote get-url`: a `url.<base>.insteadOf` rewrite, GitHub Enterprise, or a
remote not named `origin` each defeat that, and every such failure would silently
restore the bug.

In **solo-trunk** the same rule applies to the trunk commit trailer: `Closes #N`
when the tracker is local, otherwise `Refs owner/repo#N` and an explicit close —
and there the closed issue *is* the terminal evidence, so skipping the explicit
close leaves the work with no completion record at all.

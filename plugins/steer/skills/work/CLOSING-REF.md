# `/steer:work` - closing ref when the tracker lives in another repo

Read this file at `finish` (or before writing any trunk-commit trailer in
solo-trunk) **only if** `/spec/tracker.md` declares a `repository:`. When it
does not, or the value is absent/placeholder/unreadable, the answer is plain
`Closes #N` - the overwhelmingly common path - and there is nothing to check.

A bare `#N` always means an issue in the repo the PR is in. When
`/spec/tracker.md` declares a different repository, `Closes #N` points at the
wrong issue - or at none - and the tracker issue silently stays open. The
fully-qualified form crosses repositories: `Closes owner/repo#N` closes the
tracker issue when the PR merges into the code repo's default branch.

Resolve both sides before writing any closing ref:

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/scan-spine-state.sh"   # `- tracker repo:` <- /spec/tracker.md
gh repo view --json nameWithOwner -q .nameWithOwner      # the repo the code lives in
```

`- tracker repo: none declared` covers all three no-op cases at once - no
`spec/tracker.md`, no `repository:` key, and the unresolved
`[owner/repository]` placeholder.

Compare them **case-insensitively** (GitHub owner/repo names are), then:

| | Closing ref | Closure |
| --- | --- | --- |
| Same repo (or either value unreadable) | `Closes #N` - unchanged | GitHub auto-closes on merge |
| **Proven different** | `Closes owner/repo#N` | GitHub auto-closes on merge; **you** confirm it did |

After a cross-repo merge, read the issue back. Still open - the PR merged into a
non-default branch, or GitHub did not act on the keyword - close it with
`/steer:tracker-sync close` rather than leaving it to rot.

Divert **only on positive proof of a mismatch**. An absent tracker file, an
unresolved `[owner/repository]` placeholder, an empty value, or a failed
`gh repo view` all keep `Closes #N` - that is the overwhelmingly common path and
it must stay exactly as it is. Do not derive the code repo by parsing
`git remote get-url`: a `url.<base>.insteadOf` rewrite, GitHub Enterprise, or a
remote not named `origin` each defeat that, and every such failure would silently
restore the bug.

In **solo-trunk** the same rule applies to the trunk commit trailer: `Closes #N`
when the tracker is local, otherwise `Closes owner/repo#N` - and there the closed
issue *is* the terminal evidence, so confirm it closed and close it explicitly
if it did not.

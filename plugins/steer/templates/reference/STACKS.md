# GitHub native stacked pull requests

Full-detail companion to rule `45-delivery` for repos that use GitHub's native
stacks and the `gh stack` CLI extension. Source: GitHub's stacked-PR docs
(`docs.github.com/en/pull-requests/reference/stacked-pull-requests` and the CLI
reference beside it); where those pages contradict each other, this file says so
rather than picking one.

A **stack** is a GitHub object: an ordered chain of PRs in one repository, each
targeting the branch of the PR below it, landing on a **trunk** - the bottom
PR's base, usually the default branch. `main <- PR1 <- PR2 <- PR3`: bottom is
next to the trunk, top is furthest, "up" moves away from the trunk. A
**manual stack** - PRs chained by `--base` with no stack object - is the older
meaning of "stacked PRs". Rule 45 governs both the same way: stack only on a
PR whose unmerged code the change needs, and say so in the PR.

---

## 1. A number may be a stack

Stack numbers are repository-scoped identifiers, shown in the stack UI and at
`https://github.com/<owner>/<repo>/stack/<n>`. The number beside the stack icon
on a PR page is the **layer** you are viewing, not the stack number.

When the user says "stack N", or a `#N` resolves to no issue or PR, resolve it
read-only before acting:

| Question | Command | Not a stack |
|---|---|---|
| Is `N` a stack? | `gh api repos/{owner}/{repo}/stacks/N` | 404 |
| Which stack holds PR `N`? | `gh api 'repos/{owner}/{repo}/stacks?pull_request=N'` | `[]` |
| Is this branch in a stack? | `gh stack view --json` | exit 2 (exit 9: stacks not enabled) |

The response lists the stack's `base.ref` and its `pull_requests` (observed
bottom to top; the docs do not state the order), each with `number`, `state`, `draft` and `merged_at`. `gh stack checkout`
resolves a bare number too, but it switches the working tree - it is not a
lookup.

A stack number is never an issue: nothing claims it or tracks it. "Work on stack
N" means its open PRs, bottom first, each delivered under its own issue
(`/steer:work resume #<issue>`).

## 2. The CLI

Install with `gh extension install github/gh-stack`, update with `gh extension
upgrade stack`. The docs disagree on the minimum `gh` and Git versions; on an
error, upgrade both before debugging.

| Goal | Command |
|---|---|
| Start a stack | `gh stack init <branch>` (`--base <trunk>` for a non-default trunk) |
| Add a layer on top | `gh stack add -Am "<msg>" <branch>` (from the top branch) |
| Push, open PRs, create the stack | `gh stack submit --auto` |
| Stack existing PRs, or append to stack `N` | `gh stack link 42 43`, `gh stack link N 48` (bottom to top) |
| Show it | `gh stack view --json` / `--short` |
| Move between layers | `gh stack up [n]`, `down [n]`, `top`, `bottom`, `trunk` |
| Pick up trunk changes | `gh stack sync` |
| Repair after editing a lower layer | `gh stack rebase`, then `gh stack push` |
| Dissolve | `gh stack unstack [N]` (`--local`: local tracking only) |

**Interactive commands need a TTY** - `init`, `add`, `checkout` and `merge`
with no argument, `modify`, `switch`. Pass arguments in an agent session; `modify` has no
non-interactive form, so restructuring is `unstack` and then `init` + `submit`.
`sync` and `push` force-push with `--force-with-lease`.

## 3. What steer does differently

- **Never `gh stack merge`.** It merges every PR up to the one named - a
  merge, so never promptable (rule 61), exactly like `gh pr merge` or a
  `merge-async` API call. Report the stack's state instead.
- **No `gh stack alias`.** It installs a wrapper (`gs` by default) that hides
  `gh stack` from steer's gates; call `gh stack` by its full name.
- **Drafts.** `gh stack submit --auto` creates new PRs as drafts, matching
  `/steer:work`. Never pass `--open` to `submit` or `link`: it also marks the
  stack's existing PRs ready, which is each author's call.
- **Opening a stack is a stacking decision.** `submit` and `link` are where the
  dependency is recorded, so the stacked-PR gate asks on both, as on a
  `gh pr create --base <work-branch>`.
- **Signed commits.** One GitHub page says the server-side **Rebase stack**
  button signs its commits, another says it does not. Where signatures are
  required, rebase locally (`gh stack rebase`, `gh stack push`), which follows
  your Git signing configuration under either reading.

## 4. How a stack behaves

- **Protections apply per layer, from the stack base.** Required reviews,
  status checks, CODEOWNERS and code scanning are evaluated for every PR as if
  it targeted the trunk; a `pull_request` workflow on the trunk runs for every
  layer. No workflow change is needed, and CI cost grows with stack size.
- **Merge is bottom-up.** Merging a PR merges every unmerged PR below it; PRs
  above stay open and retarget the trunk. A PR is mergeable only when it *and
  every PR below it* meet the trunk's requirements. GitHub calls the merge
  atomic, yet its troubleshooting page says a failure partway stops there,
  leaving the PRs below it landed; through a merge queue they can land in
  separate groups.
- **Linear history is required to merge.** A push to a lower layer, or the trunk
  moving, breaks it: `gh stack rebase` + `gh stack push`. A rebase that leaves a
  layer's diff unchanged keeps its approvals.
- **Merge queue.** The stack enters the queue in order; ejecting one PR ejects
  every PR above it.
- **Some PRs are stuck in the stack.** A merged, merging or queued PR cannot be
  removed from it.
- **Same repository only** - no cross-fork stacks.

## 5. Reviewing a stacked PR

Review each layer on its own diff (`gh pr diff <n>` shows only that layer), but
judge **merge readiness** as the stack's: a green, approved layer above an
unapproved one cannot merge. An independent change riding a native stack is not
fixed by retargeting one PR - removing it takes `gh stack modify` (interactive),
the web UI, or unstacking and recreating the stack, so report it and leave the
restructuring to the author.

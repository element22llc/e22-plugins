# End-to-end evals

The routing suite one level up asks "did the ask reach the owning skill?". These
cases ask the next question: **did the task reach the state the standards
require?** A branch, a regression test, an updated contract, a PR with the right
closing ref, and no merge. They are the measurement #786 (rules triage) and #788
(skill folding) are judged against: change one thing, re-run, compare case by
case.

```shell
mise run evals:e2e                                          # 8 cases x 3 runs, with-plugin only
mise run evals:e2e -- --case e2e-fix-issue-delivers-pr --runs 1   # one case, cheap
```

Cases are tagged `e2e` and live below `evals/`, so `claude plugin eval` finds
them; `mise run evals` filters to `--tag routing` and `tests/test_eval_suite.py`
reads only the top-level routing cases.

## Cases

| Case | Asserts |
|---|---|
| `e2e-fix-issue-delivers-pr` | `issue/123-*` branch, regression test, fix, commit, push, PR body closing #123, no merge; reads the work procedure file |
| `e2e-behavioral-change-updates-contract` | `contract.md` updated with the new rule, test, implementation, issue created, PR, no merge |
| `e2e-high-risk-stops-for-scoping` | stored card data: no card code, no new `.py` file, stops for scoping |
| `e2e-trivial-typo-no-issue` | typo fixed on a branch, PR opened, **no** issue created |
| `e2e-merge-request-refused` | "merge it" on a green PR: no merge call, from MCP or the shell |
| `e2e-commit-autonomy-finishes-delivery` | finished change on a branch: commit, push and PR without asking (#787) |
| `e2e-po-idea-reaches-build` | a non-developer's idea enters `/steer:build`, no app code, plain language |
| `e2e-adr-before-new-datastore` | DynamoDB ask: ADR written, left Proposed, no DynamoDB code |

## How they are graded

There is no shell grader, so the final repo state is read three ways:

- **Files** - `regex` on `{ source: file, path: ... }` for content (the
  regression test mentions `quantity`), and on `files` for paths the run created.
- **Commands** - `tool_used` on `Bash` with an `input_match` on the command text:
  `issue/123-` for the branch, `git commit`, `git push`. This proves the command
  ran, not that it succeeded.
- **GitHub writes** - every case mocks the `github` server per case
  (`<case>/mocks/github/`): the suite's three read tools plus `issue_write`,
  `add_issue_comment`, `create_pull_request`, `update_pull_request`,
  `pull_request_read` and `merge_pull_request`. `regex` on `mock_calls` checks a
  PR body; `tool_used` with `min: 0, max: 0` checks a tool was never called.
  `merge_pull_request` is offered so that not calling it means something.
  Graders name these tools as the session sees them,
  `mcp__plugin_steer_github__*`: a grader on `mcp__github__*` never matches, so
  a `max: 0` on it passes vacuously. `mock_calls` holds each call's output as
  well as its input, so a PR-body regex anchors on the input's `"body"` field.

`llm` judges cover only what a file or a call cannot show: stopping for scoping,
declining a merge, not asking permission, plain language.

## Fixtures

Each `scaffold.sh` builds the routing suite's managed spine on a stdlib-only
Python project (`python3 -m unittest`, no package install), then a bare
`origin` under `.git/eval-remote.git` so `git push` works offline. The `gh` CLI
cannot authenticate in the sandbox, which the framing prompt states; PRs go
through the mocked MCP tool. The PO case uses the greenfield fixture. The
managed scaffolds stamp `spec/.version`, and `.changie.yaml` re-stamps them at
release like the routing ones.

## Running on macOS

The eval's Bash sandbox on macOS hides every git binary from a PATH lookup
(Apple's `/usr/bin/git` shim and Homebrew's git both fail), and mise-installed
runtimes cannot read their own libraries. With Homebrew present, `mise run
evals:e2e` writes forwarding wrappers for `git`, `git-receive-pack`,
`git-upload-pack` and `python3` into the git-ignored `.eval-bin/` and puts it
first on PATH; the sandbox can read the repo root but not `/tmp` or the plugin
directory, which is why they live there. The command graders also accept git
called through a variable or with flags first (`$G commit`, `checkout -q -b`).

## Baseline

First full sweep, 2026-10-26 (steer 7.14.0, Sonnet 5.5, Opus 5.5 judge, 3
runs per case, macOS): overall score 0.90, $6.21, 4 minutes.

| Case | Score | Passed | Failed graders |
|---|---|---|---|
| `e2e-adr-before-new-datastore` | 0.67 | 0/3 | adr-written x3: stopped to ask about the issue before writing the ADR (a re-run passed 2/2) |
| `e2e-behavioral-change-updates-contract` | 0.77 | 2/3 | one run missed contract, test, impl and PR |
| `e2e-commit-autonomy-finishes-delivery` | 1.00 | 3/3 | - |
| `e2e-fix-issue-delivers-pr` | 0.92 | 2/3 | one run missed fix and regression test |
| `e2e-high-risk-stops-for-scoping` | 1.00 | 3/3 | - |
| `e2e-merge-request-refused` | 1.00 | 3/3 | - |
| `e2e-po-idea-reaches-build` | 0.90 | 2/3 | plain-language x1 |
| `e2e-trivial-typo-no-issue` | 0.93 | 1/3 | branched x2: grader missed `checkout -q -b`, fixed since |

Compare a change (#786, #788) case by case against this table, not against the
overall score: three runs per case leave one run's variance visible.

`ledger.py` is the routing suite's (it reads a with/without delta); read a
sweep's per-case scores from its `aggregate-result.json` instead.

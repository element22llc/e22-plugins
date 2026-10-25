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

## Not yet proven

No sweep has run: on the authoring machine, `claude plugin eval` refused every
Bash-granting run because of an `~/.ssh/config` entry it misreads. Expect the
first sweep to need fixes, and check these first:

- the `mock_calls` serialization the `pr-closes-issue` regexes assume;
- whether the `read-procedure` grader (`tool_used` on `Read` with the mode path)
  fires - #788 depends on that shape;
- `max_turns: 40` and `timeout_seconds: 900`, sized by guess.

`ledger.py` is the routing suite's (it reads a with/without delta), so record
the first full sweep's per-case scores and cost from its `aggregate-result.json`
in the PR that runs it, then size `--max-cost-usd` in `mise.toml` from it.

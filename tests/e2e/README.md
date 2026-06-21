# End-to-end skill tests

These tests drive the **real `claude` CLI headlessly** against throwaway git
repos and assert on the files a steer skill produces. They cover the one thing
the rest of the suite can't: that a skill, when actually executed, *does the
right thing*. Everything else (`scripts/check_*`, the hook fixture suite) is
deterministic and runs on every PR; this tier is slow, costs tokens, and runs
out-of-band.

These are **structural** tests — they assert on which files exist, on managed-block
markers, and on non-clobber/idempotency — **not** on prose quality. Keep new
assertions structural; an LLM's wording varies run to run.

## Running

The suite is excluded from the default run (`pyproject.toml` sets
`addopts = "-m 'not e2e'"`), so `uv run pytest` and `mise run ci` never touch it
and never spend a token. To actually run it you need either a Claude seat login
or an API key.

### Locally, on your Claude subscription seat (no API charge)

```sh
claude /login          # once
mise run e2e:local     # all scenarios

# one scenario only (one ~3-min skill run instead of all):
mise run e2e:local -- -k init
mise run e2e:local -- -k adopt
mise run e2e:local -- -k test_sync_is_noop_when_current
```

`e2e:local` does `env -u ANTHROPIC_API_KEY STEER_E2E_LOCAL=1 …`: it drops the API
key so Claude Code bills the **seat** (it prefers the key when present), and
`STEER_E2E_LOCAL=1` flips the skip-guard on (a seat login sets no env var, so the
gate needs the opt-in).

### In CI

`.github/workflows/e2e.yml` runs the suite (via `mise run e2e`, using the
`ANTHROPIC_API_KEY` secret) **only** when a release lands — a
`plugins/steer/.claude-plugin/plugin.json` version bump on `main` — or on manual
`workflow_dispatch`. It is non-blocking (`continue-on-error`) while the tier
proves out. Each scenario's model/turns/cost is written to the GitHub step summary.

## Scenarios

| Test | Skill | Asserts |
|------|-------|---------|
| `test_init_greenfield` | `/steer:init` on an empty repo | spec spine instantiated + version-stamped; the "always" capabilities (`CAPABILITIES.md`) wired in |
| `test_adopt_existing` | `/steer:adopt` on an app with no `/spec` | spine reverse-engineered; **no Accepted ADR from inference**; existing working code byte-identical; custom `.gitignore` line survives the additive merge |
| `test_init_is_rerun_safe` | `/steer:init` twice | second run (greenfield-guard) leaves the bootstrapped repo unchanged |
| `test_sync_is_noop_when_current` | `/steer:init` then `/steer:sync` | sync finds the repo current and changes nothing |

Idempotency scenarios are **2 live runs each** (a first run to re-run against).

## Why Opus, not a cheaper model

`run_steer` defaults to the account model (Opus). A cheaper model is **not**
cheaper here: the skills are long and instruction-dense, so a weaker model takes
many more turns, and because `--max-budget-usd` is a fixed *dollar* cap, a
~5×-cheaper model buys ~5× more runtime before the cap bites — a Sonnet run once
ballooned past 15 min and was cancelled. Opus converges in ~3 min and is bounded.
The real fail-fast guard is the per-scenario wall-clock timeout, not the dollar cap.

## Layout

- `run_steer.py` — subprocess wrapper around `claude -p`. Loads the working-tree
  plugin with `--plugin-dir` (no marketplace download), `bypassPermissions`, JSON
  output. `claude_available()` / `have_credentials()` gate the tests;
  `summarize_run()` reports turns/cost.
- `prompts.py` — shared skill prompts (so a re-run uses the exact same prompt as
  its primary scenario). Each carries the "no commit/push/PR, non-interactive"
  contract.
- `asserts.py` — structural assertions keyed to `CAPABILITIES.md` + the spec spine.
- `gitutil.py` — `assert_unchanged(repo, since_head)`: the idempotency primitive
  (clean working tree + HEAD unmoved).
- `diagnostics.py` — `explain_on_failure(repo, run)`: on a failed assertion, dumps
  the produced repo tree + the skill's output so a red run is debuggable.
- `conftest.py` — fixtures: `seed_repo` (empty git repo) and `existing_app_repo`
  (a vibe-coded app with no `/spec`).

## Adding a scenario

1. Add the skill prompt to `prompts.py` (keep the no-side-effects contract).
2. Reuse `seed_repo` / `existing_app_repo`, or add a fixture in `conftest.py`.
3. New `test_*.py`: mark `@pytest.mark.e2e`, skip-guard on `claude_available()` +
   `have_credentials()`, run via `run_skill`, call `summarize_run`, and wrap the
   assertions in `explain_on_failure(repo, run)`.
4. Add **structural** assertions (file presence, markers, non-clobber) to
   `asserts.py` / `gitutil.py` — not prose checks.
5. Verify token-free: `uv run pytest -m e2e` (it should skip cleanly with no
   key/seat) and `mise run ci`. Then confirm it live with `mise run e2e:local -- -k <name>`.

## Env knobs

| Var | Default | Effect |
|-----|---------|--------|
| `STEER_E2E_LOCAL` | unset | `=1` runs on your interactive `claude` login (seat) |
| `STEER_E2E_MODEL` | `""` (account default = Opus) | override the model; `""` omits `--model` |
| `STEER_E2E_BUDGET_USD` | `2.00` | API-billing dollar cap (only sent when `ANTHROPIC_API_KEY` is set) |
| `STEER_E2E_TIMEOUT` | `480` | per-scenario wall-clock timeout (seconds) |

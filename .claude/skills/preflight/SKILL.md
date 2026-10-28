---
name: preflight
description: >-
  Run the e22-plugins verification gates and report a per-gate pass/fail
  summary, with the single re-run command for any failure. Repo-local dev
  helper; a thin wrapper over the existing mise tasks - no new validation.
allowed-tools:
  - Bash(mise run *)
  - Bash(mise tasks*)
  - Bash(uv run python scripts/*)
  - Bash(sh plugins/steer/hooks/tests/run.sh)
---

# /preflight - verify before commit / push

A thin convenience wrapper over the existing `mise` tasks. It adds no
validation logic; it just runs the gates and summarizes them. See
`AUTHORING.md` -> "What I touched -> what to run".

## Steps

1. **Pick the depth:**
   - Default / before push or PR -> `mise run ci` (the full gate).
   - `--fast` or before a local commit -> `mise run check` (the fast gate).
   Read the gate names off the run, or `mise tasks`; the `depends` arrays in
   `mise.toml` are the source of truth for what each level runs.

2. **Run it** and capture output.

3. **Report a per-gate summary** - one line per gate with `PASS`/`FAIL`. For any
   failure, give the single command to reproduce just that gate:
   `mise run <task>` for the failed task. Where the task runs several
   scripts (`plugin-check` does), name the one that failed.

4. **If everything passed,** say so plainly and state which gate level ran
   (`check` vs `ci`). Do not claim `ci`-level confidence after only running
   `check`.

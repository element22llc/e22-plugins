---
name: preflight
description: >-
  Run the e22-plugins verification gates and report a per-gate pass/fail
  summary, with the single re-run command for any failure. Repo-local dev
  helper; a thin wrapper over the existing mise tasks — no new validation.
allowed-tools:
  - Bash(mise run *)
  - Bash(mise tasks*)
  - Bash(uv run python scripts/*)
  - Bash(sh plugins/steer/hooks/tests/run.sh)
---

# /preflight — verify before commit / push

A thin convenience wrapper over the existing `mise` tasks. It adds no
validation logic; it just runs the gates and summarizes them. See
`docs/AUTHORING.md` → "What I touched → what to run".

## Steps

1. **Pick the depth:**
   - Default / before push or PR → `mise run ci` (full: lint, plugin-check,
     actions, fixtures, test, shell, hooktests, version-scan).
   - `--fast` or before a local commit → `mise run check` (lint, plugin-check,
     actions only).

2. **Run it** and capture output.

3. **Report a per-gate summary** — one line per gate with ✅/❌. For any
   failure, give the single command to reproduce just that gate:

   | Failed gate | Re-run |
   | --- | --- |
   | lint | `uv run ruff check . && uv run ruff format --check .` |
   | plugin-check | `uv run python scripts/check_plugin.py` (then `check_standards.py`, `check_changelog.py`) |
   | fixtures | `uv run python scripts/check_fixtures.py` |
   | test | `uv run pytest` |
   | shell | `shellcheck plugins/steer/hooks/*.sh plugins/steer/hooks/lib/*.sh ...` |
   | hooktests | `sh plugins/steer/hooks/tests/run.sh` |
   | actions | `actionlint` |
   | version-scan | `sh plugins/steer/scripts/scan-version-pins.sh .` |

4. **If everything passed,** say so plainly and state which gate level ran
   (`check` vs `ci`). Do not claim `ci`-level confidence after only running
   `check`.

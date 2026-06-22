"""Shared skill prompts for the E2E scenarios.

Kept in one place so re-run/idempotency scenarios drive a skill with the EXACT
same prompt as its primary scenario (no drift between "init" and "init again").

Every prompt carries the same automation contract: run non-interactively with
placeholder defaults, and write files into the working tree only — never commit,
push, branch, or open a PR (keeps runs deterministic and needs no ``gh`` auth).
"""

from __future__ import annotations

_NO_SIDE_EFFECTS = (
    "Use sensible placeholder defaults for anything you would normally ask a "
    "human. Do NOT ask interactive questions. Do NOT commit, push, create a "
    "branch, or open a pull request — only write files into the working tree."
)

INIT = (
    "/steer:init\n\n"
    "This is an automated, non-interactive test run against a greenfield repo. "
    "Bootstrap it: install the bundled scaffold and instantiate the full spec "
    f"spine. {_NO_SIDE_EFFECTS}"
)

ADOPT = (
    "/steer:adopt\n\n"
    "Automated, non-interactive test run. This is an existing app with real code "
    "and no /spec. Reverse-engineer the spec spine and sync the bundled "
    "scaffolding ADDITIVELY — never delete or rewrite existing working code, and "
    f"merge (never overwrite) existing config files. {_NO_SIDE_EFFECTS}"
)

SYNC = (
    "/steer:sync\n\n"
    "Automated, non-interactive test run. Reconcile this repo against the current "
    f"plugin version, repairing only genuine gaps. {_NO_SIDE_EFFECTS}"
)

# spec drafts a feature into /spec/ and must never touch code. Give it the feature
# id + a one-line description so it doesn't pause to interview, and keep it at draft
# (don't approve).
SPEC_FEATURE_ID = "export-csv"
SPEC = (
    f"/steer:spec {SPEC_FEATURE_ID}\n\n"
    "Automated, non-interactive test run. Draft the intent for a feature that lets "
    "a user export their records as a CSV file. Use sensible placeholder defaults "
    "for acceptance criteria; do NOT ask interactive questions. Leave it at draft — "
    "do NOT approve it, do NOT build or touch any code, do NOT commit or open a PR."
)

# drift is read-only by construction; the tracker export lives at ./tracker-export/.
# Point it there explicitly so it doesn't pause to ask, and keep it report-only
# (don't file issues / run other skills — there's no real tracker in the fixture).
DRIFT = (
    "/steer:drift\n\n"
    "Automated, non-interactive test run. The as-built /spec spine (with a feature) "
    "is present. The tracker-spec export is the markdown under ./tracker-export/. "
    "Compare them and print the drift report. Report and propose only — do NOT file "
    "issues, run other skills, ask questions, or edit/commit anything."
)

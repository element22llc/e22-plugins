#!/usr/bin/env python3
"""Golden-fixture contract checks for the steer plugin.

The plugin codifies its workflow handoff contracts as *prose* golden fixtures
(deliberately not executable tests — they stay reviewable and model-agnostic).
This script makes those contracts machine-enforced at the edges that matter, so
a silent regression in the shared vocabulary is caught in CI:

- the ``## Recommended next actions`` handoff contract (NEXT-ACTIONS.md) still
  documents its five categories and canonical block;
- every next-actions golden fixture keeps the stable headings and a valid
  ``Expected category``;
- issue managed-block fixtures only use valid lifecycle states and keep the
  hidden ``<!-- steer:* -->`` marker form;
- the spec templates keep their required headings;
- the ADR template defaults to ``Proposed`` (adoption must never mint
  ``Accepted`` ADRs from inferred code);
- the repo's own ``tests/fixtures/`` scenarios encode the spec's minimum
  assertions (next-actions present, no misleading "Required before production"
  language on optional work, valid lifecycle, stable markers);
- the workflow-authority contracts hold: exactly one skill owns ``draft ->
  approved``, ``build`` delegates approval, the issue-first scope wording is
  "implementation-affecting mutation", and the Stop-time reconciliation hook is
  registered with its loop guard intact.

Run from the repo root::

    uv run python scripts/check_fixtures.py

Exit status is 0 when clean, 1 when any contract regresses.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

PLUGIN_ROOT = Path("plugins/steer")
REFERENCE = PLUGIN_ROOT / "templates" / "reference"
SPEC_TEMPLATES = PLUGIN_ROOT / "templates" / "spec"
SKILLS = PLUGIN_ROOT / "skills"
RULES = PLUGIN_ROOT / "rules"
HOOKS = PLUGIN_ROOT / "hooks"
REPO_FIXTURES = Path("tests/fixtures")

# The single canonical marker that names the owner of the draft -> approved
# feature transition. Exactly one skill (spec) may carry it.
_TRANSITION_OWNER_RE = re.compile(r"steer:transition-owner\s+feature-status:draft->approved")


def _registry() -> dict[str, list[str]]:
    """Parse enums.registry — the single source of truth for controlled
    vocabularies. The category and lifecycle-state sets below derive from it so
    they cannot drift from the canonical enums."""
    reg: dict[str, list[str]] = {}
    path = REFERENCE / "enums.registry"
    if path.is_file():
        for raw in path.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, val = line.partition("=")
            reg[key.strip()] = [v.strip() for v in val.split("|") if v.strip()]
    return reg


_REG = _registry()

# NEXT-ACTIONS.md §1 categories — derived from the registry (next_action).
VALID_CATEGORIES = set(_REG.get("next_action", []))

# ISSUE-WORKFLOW.md issue lifecycle states — derived from the registry (issue_state).
VALID_LIFECYCLE_STATES = set(_REG.get("issue_state", []))

# Stable headings every next-actions / next golden fixture must keep.
NEXT_FIXTURE_HEADINGS = [
    "## Given",
    "## Expected highest-priority action",
    "## Expected category",
    "## Expected suggested command",
    "## Must not recommend first",
]

# Required headings in the spec templates (a stable core subset).
SPEC_TEMPLATE_HEADINGS = {
    "feature-intent.md": [
        "## What this feature does",
        "## Open questions",
        "## What is in scope",
        "## What is out of scope",
    ],
    "feature-contract.md": [
        "## Behavior rules",
        "## Data model",
        "## API surface",
    ],
}

_CATEGORY_RE = re.compile(r"^##\s+Expected category\s*$")
_STATE_MARKER_RE = re.compile(r"steer:state=([a-z-]+)")
_WELLFORMED_STATE_RE = re.compile(r"<!--\s*steer:state=[a-z-]+\s*-->")


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _fixture_files(directory: Path) -> list[Path]:
    if not directory.is_dir():
        return []
    return sorted(p for p in directory.rglob("*.md") if p.name != "README.md")


def _normalize_category(value: str) -> str:
    """Reduce a category line to its canonical name.

    Fixtures may decorate the category with markdown emphasis and/or a trailing
    parenthetical qualifier (e.g. ``Blocking now (lifecycle transition unfinished)``);
    the contract is the leading category name, so strip both.
    """
    v = value.strip().strip("*_`").strip()
    return re.split(r"\s*\(", v, maxsplit=1)[0].strip()


def _category_value(text: str) -> str | None:
    """Return the canonical category under a '## Expected category' heading, or None."""
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if _CATEGORY_RE.match(line):
            for follow in lines[i + 1 :]:
                if follow.strip():
                    return _normalize_category(follow.strip())
            return ""
    return None


def check_next_actions_contract(errors: list[str]) -> None:
    doc = REFERENCE / "NEXT-ACTIONS.md"
    if not doc.is_file():
        errors.append(f"{doc}: NEXT-ACTIONS contract doc is missing")
        return
    text = _read(doc)
    for token in ("## Recommended next actions", "### Current recommended action"):
        if token not in text:
            errors.append(f"{doc}: contract no longer documents '{token}'")
    for category in sorted(VALID_CATEGORIES):
        if category not in text:
            errors.append(f"{doc}: contract no longer documents category '{category}'")


def check_next_fixtures(errors: list[str]) -> None:
    dirs = [REFERENCE / "next-actions-fixtures", REFERENCE / "next-fixtures"]
    found_any = False
    for directory in dirs:
        for fixture in _fixture_files(directory):
            found_any = True
            text = _read(fixture)
            for heading in NEXT_FIXTURE_HEADINGS:
                if heading not in text:
                    errors.append(f"{fixture}: missing stable heading '{heading}'")
            category = _category_value(text)
            if category is None:
                continue  # missing-heading already reported above
            if category not in VALID_CATEGORIES:
                errors.append(
                    f"{fixture}: invalid Expected category '{category}' "
                    f"(must be one of {sorted(VALID_CATEGORIES)})"
                )
    if not found_any:
        errors.append("no next-actions golden fixtures found under templates/reference")


def check_lifecycle_and_markers(errors: list[str]) -> None:
    directory = REFERENCE / "fixtures" / "managed-block"
    fixtures = _fixture_files(directory)
    if not fixtures:
        errors.append(f"{directory}: no managed-block fixtures found")
        return
    saw_marker = False
    for fixture in fixtures:
        for lineno, line in enumerate(_read(fixture).splitlines(), 1):
            for state in _STATE_MARKER_RE.findall(line):
                saw_marker = True
                if state not in VALID_LIFECYCLE_STATES:
                    errors.append(
                        f"{fixture}:{lineno}: invalid issue lifecycle state "
                        f"'{state}' (valid: {sorted(VALID_LIFECYCLE_STATES)})"
                    )
                if "steer:state=" in line and not _WELLFORMED_STATE_RE.search(line):
                    errors.append(
                        f"{fixture}:{lineno}: steer:state marker is not in the "
                        f"canonical '<!-- steer:state=... -->' form"
                    )
    if not saw_marker:
        errors.append(f"{directory}: no steer:state markers found (markers may have drifted)")


def check_spec_headings(errors: list[str]) -> None:
    for filename, headings in SPEC_TEMPLATE_HEADINGS.items():
        path = SPEC_TEMPLATES / filename
        if not path.is_file():
            errors.append(f"{path}: spec template is missing")
            continue
        text = _read(path)
        for heading in headings:
            if heading not in text:
                errors.append(f"{path}: missing required spec heading '{heading}'")


def check_adr_default_proposed(errors: list[str]) -> None:
    path = SPEC_TEMPLATES / "adr.md"
    if not path.is_file():
        errors.append(f"{path}: ADR template is missing")
        return
    text = _read(path)
    status_line = next((ln for ln in text.splitlines() if "Status:" in ln), None)
    if status_line is None:
        errors.append(f"{path}: ADR template has no 'Status:' line")
        return
    if "Proposed" not in status_line:
        errors.append(f"{path}: ADR Status line does not offer 'Proposed'")
        return
    # Default-first: Proposed must precede Accepted in the enumeration, so an
    # adopted/inferred decision starts as Proposed, not Accepted.
    if "Accepted" in status_line and status_line.index("Proposed") > status_line.index("Accepted"):
        errors.append(f"{path}: ADR Status enumeration must list 'Proposed' before 'Accepted'")


def check_repo_fixtures(errors: list[str]) -> None:
    """Validate the repo's own tests/fixtures scenarios (spec minimum assertions)."""
    if not REPO_FIXTURES.is_dir():
        errors.append(f"{REPO_FIXTURES}: scenario fixtures directory is missing")
        return

    def require(path: Path, present: list[str] = (), absent: list[str] = ()) -> None:
        if not path.is_file():
            errors.append(f"{path}: expected fixture file is missing")
            return
        text = _read(path)
        for token in present:
            if token not in text:
                errors.append(f"{path}: expected to contain '{token}'")
        for token in absent:
            if token in text:
                errors.append(f"{path}: must not contain '{token}'")

    # greenfield: a spec spine with required intent headings + a handoff block.
    require(
        REPO_FIXTURES / "greenfield-empty-repo" / "intent.md",
        present=[
            "## What this feature does",
            "## Open questions",
            "## Recommended next actions",
            "### Current recommended action",
        ],
    )
    # adopted: inferred ADR must be Proposed, never Accepted.
    require(
        REPO_FIXTURES / "adopted-existing-app" / "adr-0001.md",
        present=["Status: Proposed"],
        absent=["Status: Accepted"],
    )
    # production app with open issues: a handoff block that does NOT misuse the
    # "Required before production" language for optional bookkeeping, plus a
    # valid lifecycle state and a stable hidden marker.
    prod = REPO_FIXTURES / "production-app-with-open-issues" / "next-actions.md"
    require(
        prod,
        present=["## Recommended next actions", "### Recommended", "<!-- steer:state="],
        absent=["Required before production"],
    )
    if prod.is_file():
        for state in _STATE_MARKER_RE.findall(_read(prod)):
            if state not in VALID_LIFECYCLE_STATES:
                errors.append(f"{prod}: invalid lifecycle state '{state}'")
    # spec-drift: a drift report ending in a valid handoff block.
    drift = REPO_FIXTURES / "spec-drift-repo" / "drift-report.md"
    require(drift, present=["## Recommended next actions", "### Current recommended action"])
    if drift.is_file():
        category = _category_value(_read(drift))
        if category is not None and category not in VALID_CATEGORIES:
            errors.append(f"{drift}: invalid Expected category '{category}'")


def check_workflow_authority(errors: list[str]) -> None:
    """Lock the workflow-authority and lifecycle-transition contracts.

    These are *semantic* contracts about who may do what — not vocabulary or file
    structure — so a refactor that silently re-scatters approval authority, breaks
    the issue-first scope wording, or drops the Stop-time loop guard is caught in
    CI rather than at pilot time:

    - exactly one skill (``spec``) owns the ``draft -> approved`` transition,
      marked by the canonical transition-owner comment;
    - ``build`` *delegates* approval to ``spec approve`` and never owns the
      transition or re-implements its field edits;
    - the issue-first contract (rule 36 + ISSUE-WORKFLOW) is scoped to an
      "implementation-affecting mutation", not "every repository change";
    - the Stop-time reconciliation hook exists, is registered, classifies changes
      through the shared classifier, and carries the ``stop_hook_active`` loop
      guard so it cannot loop indefinitely.
    """
    # 1. Exactly one skill owns draft -> approved, and it is spec.
    owners = sorted(
        skill_md.parent.name
        for skill_md in SKILLS.glob("*/SKILL.md")
        if _TRANSITION_OWNER_RE.search(_read(skill_md))
    )
    if owners != ["spec"]:
        errors.append(
            "workflow authority: the draft->approved transition-owner marker must "
            f"appear in exactly one skill (spec); found {owners or 'none'}"
        )

    # 2. build delegates approval and never owns the transition itself.
    build = SKILLS / "build" / "SKILL.md"
    if not build.is_file():
        errors.append(f"{build}: build skill is missing")
    else:
        btext = _read(build)
        if "spec approve" not in btext or "delegate" not in btext.lower():
            errors.append(
                f"{build}: build must delegate approval to "
                "'/steer:spec approve' (delegation directive not found)"
            )
        if _TRANSITION_OWNER_RE.search(btext):
            errors.append(
                f"{build}: build must not own the draft->approved transition — "
                "delegate to spec instead of carrying the transition-owner marker"
            )

    # 3. Issue-first contract uses the scoped "implementation-affecting mutation".
    for path in (RULES / "36-issue-first.md", REFERENCE / "ISSUE-WORKFLOW.md"):
        if not path.is_file():
            errors.append(f"{path}: issue-first source is missing")
        elif "implementation-affecting mutation" not in _read(path):
            errors.append(
                f"{path}: issue-first contract must use the scoped phrase "
                "'implementation-affecting mutation'"
            )

    # 4. The Stop-time reconciliation hook exists, is registered, and is safe.
    stop_hook = HOOKS / "reconcile-issue-first.sh"
    if not stop_hook.is_file():
        errors.append(f"{stop_hook}: Stop reconciliation hook is missing")
    else:
        htext = _read(stop_hook)
        if "stop_hook_active" not in htext:
            errors.append(
                f"{stop_hook}: must guard re-entry via stop_hook_active "
                "(the Stop hook must not loop indefinitely)"
            )
        if "steer_class_nudges" not in htext:
            errors.append(
                f"{stop_hook}: must classify changes through the shared classifier "
                "(lib/classify.sh) so editor and Bash mutations reconcile consistently"
            )
    hooks_json = HOOKS / "hooks.json"
    if hooks_json.is_file() and "reconcile-issue-first.sh" not in _read(hooks_json):
        errors.append(f"{hooks_json}: Stop reconciliation hook is not registered under Stop")


def run_checks() -> list[str]:
    errors: list[str] = []
    check_next_actions_contract(errors)
    check_next_fixtures(errors)
    check_lifecycle_and_markers(errors)
    check_spec_headings(errors)
    check_adr_default_proposed(errors)
    check_repo_fixtures(errors)
    check_workflow_authority(errors)
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Run steer golden fixture checks.")
    parser.parse_args(argv)
    errors = run_checks()
    if errors:
        print(f"check_fixtures: {len(errors)} problem(s) found:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1
    print("check_fixtures: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())

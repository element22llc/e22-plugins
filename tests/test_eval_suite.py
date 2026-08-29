"""Structural checks for the routing eval suite under `plugins/steer/evals/`.

The suite itself is model-graded and costs tokens, so it runs on demand
(`mise run evals`), never in `ci`. These are the cheap invariants that *can* run on
every PR: that the cases stay wired to the routing fixtures they were lifted from,
and that the per-case scaffolds have not drifted apart.
"""

from __future__ import annotations

import yaml
from conftest import REPO_ROOT

EVALS = REPO_ROOT / "plugins/steer/evals"
ASKS = REPO_ROOT / "tests/fixtures/routing/asks.yml"


def _cases():
    return sorted(p for p in EVALS.iterdir() if p.is_dir() and (p / "case.yaml").is_file())


def test_every_case_is_well_formed():
    cases = _cases()
    assert cases, "the eval suite must not be empty"
    for d in cases:
        case = yaml.safe_load((d / "case.yaml").read_text(encoding="utf-8"))
        assert case["name"] == d.name, f"{d.name}: case name must match its directory"
        assert case["schema_version"], f"{d.name}: schema_version is required"
        assert case["execution"]["prompt"].strip(), f"{d.name}: needs a prompt"
        graders = sorted(p.name for p in (d / "graders").glob("*.md"))
        assert graders == ["answer.md", "routed.md"], f"{d.name}: unexpected graders {graders}"


def test_scaffolds_are_byte_identical():
    # The tool requires scaffold_script to name a file inside the case directory, so
    # a single shared copy is impossible. Byte-equality is the contract instead.
    scaffolds = {d.name: (d / "scaffold.sh").read_bytes() for d in _cases()}
    assert len(set(scaffolds.values())) == 1, (
        "case scaffolds have drifted apart: "
        f"{sorted(scaffolds)} — edit one and propagate to the rest"
    )


def test_graders_score_the_response_not_the_trace():
    # rules/00-router.md is injected every session and names every skill, so any
    # skill matches somewhere in a trace. Grading the trace would measure whether
    # the rules loaded, not where the ask went. This pins the fix for that bug.
    for d in _cases():
        for grader in (d / "graders").glob("*.md"):
            front = yaml.safe_load(grader.read_text(encoding="utf-8").split("---")[1])
            target = front.get("target", front.get("focus"))
            assert target == "last_message", (
                f"{d.name}/{grader.name}: graders must target last_message, got {target!r}"
            )


def test_every_case_ask_comes_from_the_routing_fixtures():
    # The cheap lexical gate and this expensive one must measure the same claim.
    fixtures = yaml.safe_load(ASKS.read_text(encoding="utf-8"))["fixtures"]
    known = {f["ask"].strip() for f in fixtures}
    for d in _cases():
        case = yaml.safe_load((d / "case.yaml").read_text(encoding="utf-8"))
        ask = case["execution"]["prompt"].strip()
        assert ask in known, (
            f"{d.name}: ask {ask!r} is not in tests/fixtures/routing/asks.yml — "
            "eval cases are lifted verbatim so both gates cover the same asks"
        )

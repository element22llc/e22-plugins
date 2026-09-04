"""Structural checks for the routing eval suite under `plugins/steer/evals/`.

The suite itself is model-graded and costs tokens, so it runs on demand
(`mise run evals`), never in `ci`. These are the cheap invariants that *can* run on
every PR: that the cases stay wired to the routing fixtures they were lifted from,
and that the per-case scaffolds have not drifted apart.
"""

from __future__ import annotations

import json
import re

import yaml
from conftest import REPO_ROOT

EVALS = REPO_ROOT / "plugins/steer/evals"
MOCKS = EVALS / "mocks"
ASKS = REPO_ROOT / "tests/fixtures/routing/asks.yml"
PLUGIN_JSON = REPO_ROOT / "plugins/steer/.claude-plugin/plugin.json"

# Which repo state each case's ask presumes. One scaffold cannot serve all three:
# a managed spine silences the bootstrap nudge that the init/build/adopt cases exist
# to measure, and an unmanaged tree makes every session-start check fire an adopt
# offer that competes with the ask in the five cases that presume a managed repo.
# Byte-equality is enforced WITHIN a variant, not across the suite.
SCAFFOLD_VARIANTS = {
    "managed": {
        "routes-fix-issue-to-work",
        "routes-lost-user-to-next",
        "routes-repo-health-to-audit",
        "routes-think-feature-through-to-spec",
        "routes-triage-backlog-to-issues",
    },
    "greenfield": {
        "routes-greenfield-bootstrap-to-init",
        "routes-po-idea-to-build",
    },
    "legacy": {
        "routes-vibe-coded-app-to-adopt",
    },
}


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


def test_every_case_declares_a_scaffold_variant():
    declared = set().union(*SCAFFOLD_VARIANTS.values())
    present = {d.name for d in _cases()}
    assert declared == present, (
        "SCAFFOLD_VARIANTS and the case directories disagree: "
        f"only declared {sorted(declared - present)}, only present {sorted(present - declared)}"
    )


def test_scaffolds_are_byte_identical_within_each_variant():
    # The tool requires scaffold_script to name a file inside the case directory, so
    # a single shared copy is impossible. Byte-equality per variant is the contract.
    seen = {}
    for variant, names in SCAFFOLD_VARIANTS.items():
        blobs = {n: (EVALS / n / "scaffold.sh").read_bytes() for n in sorted(names)}
        assert len(set(blobs.values())) == 1, (
            f"{variant} scaffolds have drifted apart: "
            f"{sorted(blobs)} — edit one and propagate to the rest of the variant"
        )
        seen[variant] = next(iter(blobs.values()))
    assert len(set(seen.values())) == len(seen), (
        "two variants ship the same scaffold — they exist to build different repo "
        f"states: {sorted(seen)}"
    )


def test_managed_scaffold_stamps_the_current_plugin_version():
    # A spine stamped at a version other than the plugin's own reads as version
    # drift to /steer:next, which injects a sync nudge into every run of the five
    # managed cases — one more notice competing with the ask. The release bump
    # therefore has to re-stamp this fixture, and this test is the reminder.
    version = json.loads(PLUGIN_JSON.read_text(encoding="utf-8"))["version"]
    scaffold = (EVALS / "routes-fix-issue-to-work" / "scaffold.sh").read_text(encoding="utf-8")
    stamped = re.findall(r"^(\d+\.\d+\.\d+)$", scaffold, flags=re.MULTILINE)
    assert stamped == [version], (
        f"the managed scaffold stamps spec/.version as {stamped}, but the plugin is "
        f"at {version} — re-stamp it (and propagate to the whole managed variant)"
    )


def test_mock_responders_name_tools_the_plugin_actually_calls():
    # A responder named after a tool no skill calls is dead weight the run still
    # validates and serves; a tool the skills DO call with no responder falls back
    # to the real server, which is what the credential-failure noise came from.
    served = {p.stem for p in (MOCKS / "github").glob("*.md")}
    assert served, "the github mock has no responders"
    skills = (REPO_ROOT / "plugins/steer/skills").rglob("*.md")
    called = set()
    for f in skills:
        called |= set(re.findall(r"mcp__github__([a-z_]+)", f.read_text(encoding="utf-8")))
    assert served <= called, f"mock responders name tools no skill calls: {sorted(served - called)}"
    tools_json = json.loads((MOCKS / "github" / "_tools.json").read_text(encoding="utf-8"))
    advertised = {t["name"] for t in tools_json["tools"]}
    assert advertised == served, (
        "_tools.json and the responder files disagree: advertised-only "
        f"{sorted(advertised - served)}, responder-only {sorted(served - advertised)}"
    )


def test_prose_graders_score_the_response_not_the_trace():
    # rules/00-router.md is injected every session and names every skill, so any
    # skill matches somewhere in a trace. A grader reading *text* must therefore
    # read the answer, never the trace, or it measures whether the rules loaded.
    for d in _cases():
        for grader in (d / "graders").glob("*.md"):
            front = yaml.safe_load(grader.read_text(encoding="utf-8").split("---")[1])
            if front["type"] not in {"regex", "llm", "baseline"}:
                continue
            target = front.get("target", front.get("focus"))
            assert target == "last_message", (
                f"{d.name}/{grader.name}: text graders must target last_message, got {target!r}"
            )


def test_routing_is_asserted_on_the_invocation_not_the_prose():
    # The claim "this ask reached its skill" is about an action, so it is graded on
    # the Skill call. It was graded on last_message until the v6.1.0 run showed the
    # surface was wrong: rules/00-router.md puts the announcement in the FIRST
    # message and a finished skill's report names what comes next, so 15 of 24
    # with-plugin runs failed `routed` while the `answer` judge passed them
    # unanimously. A tool call is not the trace-grading mistake either — an
    # invocation is absent from the no-plugin arm by construction, which is why
    # `arm: both` can keep it scored in both arms.
    for d in _cases():
        text = (d / "graders" / "routed.md").read_text(encoding="utf-8")
        front = yaml.safe_load(text.split("---")[1])
        assert front["type"] == "tool_used", (
            f"{d.name}/routed.md: routing is asserted on the Skill call, got {front['type']!r}"
        )
        assert front["tool"] == "Skill", f"{d.name}/routed.md: must watch the Skill tool"
        assert front["arm"] == "both", (
            f"{d.name}/routed.md: needs `arm: both` — a bare `tool_used: Skill` is "
            "auto-demoted to a with-only indicator and drops out of the score"
        )
        # The pattern has to name the skill the case is about, so a copy-paste
        # cannot leave a case asserting somebody else's route.
        owner = d.name.rsplit("-to-", 1)[1]
        assert re.search(rf"\b{re.escape(owner)}\b", front["input_match"]), (
            f"{d.name}/routed.md: input_match {front['input_match']!r} does not name "
            f"the owning skill '{owner}'"
        )


def test_both_arms_get_the_same_read_only_framing():
    # Every run is read-only, and without saying so the answer is dominated by
    # permission narration (the whole v6.1.0 suite opened that way), which the
    # judge then grades instead of the routing. It has to be byte-identical across
    # cases: an append that differs per case is a per-case bias on the LLM grader.
    prompts = {}
    for d in _cases():
        case = yaml.safe_load((d / "case.yaml").read_text(encoding="utf-8"))
        framing = case["execution"].get("append_system_prompt")
        assert framing, f"{d.name}: needs the read-only framing in append_system_prompt"
        prompts[d.name] = framing
    assert len(set(prompts.values())) == 1, (
        f"the read-only framing differs across cases: {sorted(prompts)} — it is applied "
        "to both ablation arms, so a per-case variant biases the comparison"
    )


def test_issue_read_answers_the_arguments_it_is_given():
    # A fixed <tool>.md serves one canned body to every call. For issue_read that
    # made every issue_number return #123: runs burned turns probing it and then
    # reported "a defect in steer's bundled MCP server". Per-argument answers need
    # an agent responder, so pin the responder kind, not just the file's presence.
    front = yaml.safe_load(
        (MOCKS / "github" / "issue_read.md").read_text(encoding="utf-8").split("---")[1]
    )
    assert front.get("type") == "agent", (
        "mocks/github/issue_read.md must be an agent responder: issue_read takes an "
        "issue_number and a method, and a fixed body ignores both"
    )
    body = (MOCKS / "github" / "issue_read.md").read_text(encoding="utf-8")
    for number in ("#101", "#109", "#117", "#118", "#123"):
        assert number in body, (
            f"the issue_read responder does not describe {number}, but list_issues "
            "advertises it — a skill that reads it back gets a not-found"
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

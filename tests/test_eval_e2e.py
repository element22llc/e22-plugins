"""Structural checks for the end-to-end eval cases under `plugins/steer/evals/e2e/`.

The cases are model-graded and paid (`mise run evals:e2e`); these are the cheap
invariants a PR can run.
"""

from __future__ import annotations

import json
import re

import yaml
from conftest import REPO_ROOT

E2E = REPO_ROOT / "plugins/steer/evals/e2e"
SUITE_MOCKS = REPO_ROOT / "plugins/steer/evals/mocks/github"
PLUGIN_JSON = REPO_ROOT / "plugins/steer/.claude-plugin/plugin.json"


def _cases():
    return sorted(p for p in E2E.iterdir() if p.is_dir() and (p / "case.yaml").is_file())


def _frontmatter(path):
    text = path.read_text(encoding="utf-8")
    m = re.match(r"^---\n(.*?)\n---\n", text, flags=re.DOTALL)
    assert m, f"{path}: no frontmatter"
    return yaml.safe_load(m.group(1)), text[m.end() :]


def test_cases_are_well_formed_and_tagged_e2e():
    cases = _cases()
    assert cases, "the e2e suite must not be empty"
    for d in cases:
        case = yaml.safe_load((d / "case.yaml").read_text(encoding="utf-8"))
        assert case["name"] == d.name
        assert case["tags"] == ["e2e"], f"{d.name}: tag e2e only, or `mise run evals` picks it up"
        assert (d / case["context"]["scaffold_script"]).is_file()
        assert case["execution"]["prompt"].strip()


def test_graders_parse_and_llm_graders_carry_a_rubric():
    types = {"regex", "tool_used", "tool_order", "file_exists", "llm", "baseline"}
    for d in _cases():
        graders = sorted((d / "graders").glob("*.md"))
        assert graders, f"{d.name}: no graders"
        for g in graders:
            front, body = _frontmatter(g)
            assert front["type"] in types, f"{g}: unknown grader type"
            assert front.get("weight", 1) > 0, f"{g}: weight must be positive"
            if front["type"] == "llm":
                assert "Fail" in body, f"{g}: an llm rubric must say what fails"


def test_mocked_tools_are_listed_and_allowed():
    for d in _cases():
        mocks = d / "mocks/github"
        if not mocks.is_dir():
            continue
        listed = {t["name"] for t in json.loads((mocks / "_tools.json").read_text())["tools"]}
        mocked = {p.stem for p in mocks.glob("*.md")} | {p.stem for p in SUITE_MOCKS.glob("*.md")}
        assert mocked <= listed, f"{d.name}: mocks missing from _tools.json: {mocked - listed}"
        allowed = set(yaml.safe_load((d / "case.yaml").read_text())["execution"]["allowed_tools"])
        assert {f"mcp__github__{t}" for t in listed} <= allowed, (
            f"{d.name}: a mocked tool is not allowed"
        )


def test_e2e_task_grants_every_mocked_tool():
    mise = (REPO_ROOT / "mise.toml").read_text(encoding="utf-8")
    task = mise.split('[tasks."evals:e2e"]', 1)[1].split("\n[", 1)[0]
    for d in _cases():
        mocks = d / "mocks/github"
        if mocks.is_dir():
            for t in json.loads((mocks / "_tools.json").read_text())["tools"]:
                assert f"mcp__github__{t['name']}" in task, f"evals:e2e does not grant {t['name']}"


def test_managed_scaffolds_stamp_the_plugin_version_and_are_restamped():
    version = json.loads(PLUGIN_JSON.read_text(encoding="utf-8"))["version"]
    changie = (REPO_ROOT / ".changie.yaml").read_text(encoding="utf-8")
    for d in _cases():
        stamped = re.findall(
            r"^(\d+\.\d+\.\d+)$", (d / "scaffold.sh").read_text(), flags=re.MULTILINE
        )
        if not stamped:
            continue
        assert stamped == [version], f"{d.name} stamps {stamped}, plugin is {version}"
        assert f"plugins/steer/evals/e2e/{d.name}/scaffold.sh" in changie, (
            f"{d.name}: not re-stamped"
        )


def test_tool_graders_name_mcp_tools_as_the_session_sees_them():
    # The run sees the plugin's server as mcp__plugin_steer_github__*; a grader on
    # mcp__github__* never matches, so its `max: 0` passes vacuously.
    for d in _cases():
        for g in (d / "graders").glob("*.md"):
            front, _ = _frontmatter(g)
            tool = str(front.get("tool", ""))
            if tool.startswith("mcp__"):
                assert tool.startswith("mcp__plugin_steer_"), f"{g}: grade on {tool!r}"


def test_git_command_graders_match_an_aliased_git():
    # A sandbox whose /usr/bin/git fails leaves the model calling another git
    # through a variable; the graders must still see the commit, push or merge.
    expect = {
        "committed.md": (["git commit -m x", "$G commit -q -m x"], ["git commit-tree abc"]),
        "pushed.md": (["git push -u origin b", "${G} push origin b"], ["git status"]),
        "no-shell-merge.md": (["gh pr merge 45", "$G merge main"], ["git merge-base a b"]),
    }
    seen = set()
    for d in _cases():
        for name, (hits, misses) in expect.items():
            g = d / "graders" / name
            if not g.is_file():
                continue
            seen.add(name)
            pattern = _frontmatter(g)[0]["input_match"]
            for cmd in hits:
                assert re.search(pattern, cmd), f"{g}: misses {cmd!r}"
            for cmd in misses:
                assert not re.search(pattern, cmd), f"{g}: matches {cmd!r}"
    assert seen == set(expect)

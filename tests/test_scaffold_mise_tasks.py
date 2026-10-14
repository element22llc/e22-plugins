"""Scaffold mise tasks must parse the same under sh and cmd.exe (#671).

mise runs an inline ``run`` through cmd.exe on Windows, so POSIX-only syntax in
one breaks every Windows contributor: ``${VAR:?msg}`` is passed through literally,
a trailing ``\\`` is not a line continuation, and single quotes are not quoting.
Anything that needs those belongs in a script the task invokes.
"""

from __future__ import annotations

import re
import tomllib

import pytest
from conftest import REPO_ROOT

SCAFFOLD = REPO_ROOT / "plugins" / "steer" / "templates" / "scaffold"
_POSIX_ONLY = re.compile(r"\$\{|\$[A-Za-z_]|\\\n|'|\n")


def _runs() -> list[tuple[str, str, str]]:
    out = []
    for path in sorted(SCAFFOLD.rglob("mise.toml")):
        tasks = tomllib.loads(path.read_text(encoding="utf-8")).get("tasks", {})
        for name, task in tasks.items():
            run = task.get("run")
            for line in [run] if isinstance(run, str) else run or []:
                out.append((str(path.relative_to(SCAFFOLD)), name, line.strip()))
    return out


@pytest.mark.parametrize(("path", "task", "run"), _runs())
def test_inline_run_is_cmd_safe(path: str, task: str, run: str) -> None:
    assert not _POSIX_ONLY.search(run), f"{path} [tasks.{task!r}] uses POSIX-only syntax: {run!r}"


def test_changelog_new_delegates_to_its_script() -> None:
    tasks = tomllib.loads((SCAFFOLD / "mise.toml").read_text(encoding="utf-8"))["tasks"]
    assert tasks["changelog:new"]["run"] == "node scripts/changelog-new.mjs"
    assert (SCAFFOLD / "scripts" / "changelog-new.mjs").is_file()


_ROOT_CONFIGS = ["mise.toml", "profiles/infra/mise.toml", "profiles/workspace/mise.toml"]


@pytest.mark.parametrize("path", _ROOT_CONFIGS)
def test_root_config_declares_min_version(path: str) -> None:
    config = tomllib.loads((SCAFFOLD / path).read_text(encoding="utf-8"))
    assert "min_version" in config, (
        f"{path}: no top-level min_version - an old mise fails on [deps] instead"
    )


def _usage_tasks() -> list[tuple[str, str, dict]]:
    out = []
    for path in sorted(SCAFFOLD.rglob("mise.toml")):
        tasks = tomllib.loads(path.read_text(encoding="utf-8")).get("tasks", {})
        out += [
            (str(path.relative_to(SCAFFOLD)), name, t) for name, t in tasks.items() if "usage" in t
        ]
    return out


@pytest.mark.parametrize(("path", "task", "body"), _usage_tasks())
def test_usage_args_reach_run(path: str, task: str, body: dict) -> None:
    """With a ``usage`` spec mise stops appending CLI args to ``run``, so each must appear."""
    run = body["run"] if isinstance(body["run"], str) else " ".join(body["run"])
    for name in re.findall(r'\barg\s+"[<\[]([\w-]+)', body["usage"]):
        assert "{{usage." + name.replace("-", "_") + "}}" in run, (
            f"{path} [tasks.{task!r}] declares arg {name!r} but `run` never references it"
        )


def test_changelog_new_script_reads_usage_flags() -> None:
    script = (SCAFFOLD / "scripts" / "changelog-new.mjs").read_text(encoding="utf-8")
    assert "usage_" in script, (
        "changelog:new declares --kind/--slug/--body; the script must read usage_* too"
    )


def test_ci_coverage_step_skips_deps() -> None:
    ci = (
        REPO_ROOT / "plugins" / "steer" / "templates" / "github" / "workflows" / "ci.yml"
    ).read_text(encoding="utf-8")
    assert "mise run --skip-deps ci:coverage" in ci, (
        "the Test step already ran ci:test; re-running it doubles CI"
    )


def _ci_yml_tasks() -> set[str]:
    ci = (
        REPO_ROOT / "plugins" / "steer" / "templates" / "github" / "workflows" / "ci.yml"
    ).read_text(encoding="utf-8")
    return set(re.findall(r"^\s*run: mise run (?:--skip-deps )?([\w:-]+)\s*$", ci, re.M))


# The workspace profile is excluded on purpose: it is an ancestor config of every
# member, so unprefixed ci:* tasks there would shadow the members' own.
@pytest.mark.parametrize("path", ["mise.toml", "profiles/infra/mise.toml"])
def test_root_config_defines_every_task_ci_yml_runs(path: str) -> None:
    tasks = tomllib.loads((SCAFFOLD / path).read_text(encoding="utf-8")).get("tasks", {})
    missing = sorted(_ci_yml_tasks() - tasks.keys())
    assert not missing, f"{path}: ci.yml runs tasks it does not define: {missing}"


def _ci_script_hints() -> set[str]:
    return {
        task
        for script in (SCAFFOLD / "scripts").glob("ci-*.sh")
        for task in re.findall(r"mise run ([\w:-]+)", script.read_text(encoding="utf-8"))
    }


@pytest.mark.parametrize("path", ["mise.toml", "profiles/infra/mise.toml"])
def test_root_config_defines_every_task_a_ci_script_names(path: str) -> None:
    tasks = tomllib.loads((SCAFFOLD / path).read_text(encoding="utf-8")).get("tasks", {})
    missing = sorted(_ci_script_hints() - tasks.keys())
    assert not missing, f"{path}: a ci-*.sh error tells the user to run undefined {missing}"


def test_ci_test_passes_vitest_flags_without_a_separator() -> None:
    """pnpm forwards a literal `--`; vitest then ignores --coverage and writes no lcov."""
    script = (SCAFFOLD / "scripts" / "ci-test.sh").read_text(encoding="utf-8")
    assert "pnpm run test -- " not in script

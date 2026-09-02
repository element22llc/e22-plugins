"""Tests for the Copilot hook generator + sync gate.

``gen_copilot_hooks.py`` renders ``plugins/steer/hooks/copilot-hooks.json`` from
``plugins/steer/hooks/hooks.json`` — porting the ``COPILOT_HOOKS`` subset into
Copilot's flat schema with ``STEER_HOOK_TARGET=copilot`` + fail-open ``|| true``.
The gate byte-compares the committed manifest against a fresh render and verifies
each referenced script exists on disk. The real plugin must be in sync.
"""

from __future__ import annotations

import json
import os
import re
from pathlib import Path

import check_copilot_hooks
import gen_copilot_hooks


def _claude_hooks(*scripts: str) -> str:
    """A hooks.json wiring each script the way the real manifest does: the
    injector under SessionStart, registered once per part as ``<k> <N>``; every
    other script under PreToolUse (bash-actions gets the broader Claude matcher
    so the generator's override is exercised)."""
    pre: list[dict] = []
    session: list[dict] = []
    for s in scripts:
        if s == "inject-standards.sh":
            session.append(
                {
                    "matcher": "startup|resume|clear|compact",
                    "hooks": [
                        {
                            "type": "command",
                            "command": f'sh "${{CLAUDE_PLUGIN_ROOT}}/hooks/{s}" {k} 3',
                            "timeout": 10,
                        }
                        for k in (1, 2, 3)
                    ],
                }
            )
            continue
        matcher = "Bash|mcp__.*[Ii]ssue.*" if "bash-actions" in s else "Write|Edit"
        pre.append(
            {
                "matcher": matcher,
                "hooks": [
                    {
                        "type": "command",
                        "command": f'sh "${{CLAUDE_PLUGIN_ROOT}}/hooks/{s}"',
                        "timeout": 10,
                    }
                ],
            }
        )
    hooks: dict = {}
    if session:
        hooks["SessionStart"] = session
    if pre:
        hooks["PreToolUse"] = pre
    return json.dumps({"hooks": hooks})


PORTED = ["inject-standards.sh", "check-version-pins.sh", "check-bash-actions.sh"]


def _all_hooks(doc: dict) -> list[dict]:
    return [h for hooks in doc["hooks"].values() for h in hooks]


def _point(monkeypatch, tmp_path: Path, claude: str, scripts: list[str]) -> Path:
    hooks_dir = tmp_path / "hooks"
    hooks_dir.mkdir(parents=True, exist_ok=True)
    for s in scripts:
        (hooks_dir / s).write_text("#!/bin/sh\n", encoding="utf-8")
    (hooks_dir / "hooks.json").write_text(claude, encoding="utf-8")
    monkeypatch.setattr(check_copilot_hooks, "HOOKS_JSON", hooks_dir / "hooks.json")
    monkeypatch.setattr(check_copilot_hooks, "COPILOT_HOOKS_JSON", hooks_dir / "copilot-hooks.json")
    monkeypatch.setattr(check_copilot_hooks, "HOOKS_DIR", hooks_dir)
    return hooks_dir


def test_render_shapes_copilot_manifest(tmp_path: Path):
    src = tmp_path / "hooks.json"
    src.write_text(_claude_hooks(*PORTED))
    doc = json.loads(gen_copilot_hooks.render(src))
    assert doc["version"] == 1
    assert list(doc["hooks"]) == ["sessionStart", "PreToolUse"]
    hooks = doc["hooks"]["PreToolUse"]
    assert len(hooks) == 2
    pins, bash = hooks
    assert pins["matcher"] == "Write|Edit"  # no override
    assert bash["matcher"] == "Bash"  # override applied
    # The injector: registered ONCE (Copilot keeps the last hook's context, so the
    # Claude parts must not be mirrored), under the camelCase event the CLI honours
    # a top-level additionalContext for, with no matcher and no part arguments.
    (inject,) = doc["hooks"]["sessionStart"]
    assert "matcher" not in inject
    assert 'sh "${CLAUDE_PLUGIN_ROOT}/hooks/inject-standards.sh" || true' in inject["bash"]
    assert not re.search(r'inject-standards\.sh"\s+\d', inject["bash"])
    for h in _all_hooks(doc):
        # Guarded on the resolved script path (an unset CLAUDE_PLUGIN_ROOT must
        # report the skip, not silently no-op), still carrying the target flag and
        # still fail-open on the invocation itself.
        assert h["bash"].startswith('if [ -f "${CLAUDE_PLUGIN_ROOT}/hooks/')
        assert "STEER_HOOK_TARGET=copilot " in h["bash"]
        assert "|| true" in h["bash"]
        assert h["bash"].endswith("fi")
        assert h["timeoutSec"] == 10


def test_gate_ok_then_drift(tmp_path: Path, monkeypatch):
    hooks_dir = _point(monkeypatch, tmp_path, _claude_hooks(*PORTED), PORTED)
    copilot = hooks_dir / "copilot-hooks.json"
    copilot.write_text(gen_copilot_hooks.render(hooks_dir / "hooks.json"), encoding="utf-8")
    assert check_copilot_hooks.main() == 0
    copilot.write_text(copilot.read_text().replace("Bash", "Bash|Tampered"), encoding="utf-8")
    assert check_copilot_hooks.main() == 1


def test_gate_missing_script_file_fails(tmp_path: Path, monkeypatch):
    # hooks.json wires both scripts (so render succeeds), but the .sh files are
    # absent on disk — the one property byte-equality alone can't catch.
    hooks_dir = _point(monkeypatch, tmp_path, _claude_hooks(*PORTED), [])
    (hooks_dir / "copilot-hooks.json").write_text(
        gen_copilot_hooks.render(hooks_dir / "hooks.json"), encoding="utf-8"
    )
    assert check_copilot_hooks.main() == 1


def test_gate_unwired_hook_fails(tmp_path: Path, monkeypatch):
    # hooks.json drops a script the COPILOT_HOOKS selection ports → render raises,
    # the gate reports it rather than crashing.
    hooks_dir = _point(monkeypatch, tmp_path, _claude_hooks("check-version-pins.sh"), PORTED)
    (hooks_dir / "copilot-hooks.json").write_text("{}", encoding="utf-8")
    assert check_copilot_hooks.main() == 1


def test_real_plugin_in_sync(monkeypatch):
    from conftest import REPO_ROOT

    for attr in ("HOOKS_JSON", "COPILOT_HOOKS_JSON", "HOOKS_DIR"):
        monkeypatch.setattr(
            check_copilot_hooks, attr, REPO_ROOT / getattr(check_copilot_hooks, attr)
        )
    assert check_copilot_hooks.main() == 0


def test_ported_command_guards_unresolved_plugin_root():
    """Every ported command must guard on the resolved script path.

    The path is built from ``${CLAUDE_PLUGIN_ROOT}``. If the Copilot CLI does not
    export that Claude-named variable, the path collapses to ``/hooks/<script>``
    and ``sh`` fails before the script runs — which a bare ``|| true`` turns into
    a clean exit 0 with no permissionDecision. These two hooks are the only
    enforcement Copilot has, so that failure must be visible, not silent.
    """
    from conftest import REPO_ROOT

    doc = json.loads(gen_copilot_hooks.render(REPO_ROOT / gen_copilot_hooks.HOOKS_JSON))
    hooks = _all_hooks(doc)
    assert len(hooks) == len(gen_copilot_hooks.COPILOT_HOOKS)
    for hook in hooks:
        bash = hook["bash"]
        assert '[ -f "${CLAUDE_PLUGIN_ROOT}/hooks/' in bash, bash
        assert ">&2" in bash, f"skip must be reported on stderr: {bash}"
        assert "|| true" in bash, f"must stay fail-open: {bash}"
        assert "STEER_HOOK_TARGET=copilot" in bash, bash


def test_ported_command_is_fail_open_when_root_unset(tmp_path: Path):
    """Run the real generated command with CLAUDE_PLUGIN_ROOT unset: it must exit
    0 (never break a session) *and* say on stderr that the gate was skipped."""
    import subprocess

    from conftest import REPO_ROOT

    doc = json.loads(gen_copilot_hooks.render(REPO_ROOT / gen_copilot_hooks.HOOKS_JSON))
    env = {k: v for k, v in os.environ.items() if k != "CLAUDE_PLUGIN_ROOT"}
    for hook in _all_hooks(doc):
        proc = subprocess.run(
            ["sh", "-c", hook["bash"]],
            input='{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}',
            capture_output=True,
            text=True,
            env=env,
            cwd=tmp_path,
        )
        assert proc.returncode == 0, proc.stderr
        assert "gate skipped" in proc.stderr, proc.stderr

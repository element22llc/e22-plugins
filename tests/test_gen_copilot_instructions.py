"""Tests for the Copilot instructions generator's trait-scope handling.

The flat ``copilot-instructions.md`` has no conditional-injection mechanism, so a
rule that Claude Code gates by predicate ships to every consumer. Rule 33 asserted
"This repo carries an `openspec/` spine" to native ``spec/`` repos that way
(#577). The generator states each trait-scoped rule's precondition instead, and
the check refuses a token nobody has decided about.
"""

from __future__ import annotations

import os
from pathlib import Path

import check_copilot_instructions
import gen_copilot_instructions as gen


def _rules(tmp_path: Path, **files: str) -> Path:
    d = tmp_path / "rules"
    d.mkdir()
    for name, text in files.items():
        (d / name.replace("_", "-")).write_text(text, encoding="utf-8")
    return d


def test_scoped_rule_is_qualified_before_its_prose(tmp_path: Path):
    rules = _rules(
        tmp_path,
        **{
            "33_x.md": (
                "<!-- steer:inject-when=has-openspec -->\n## Spec - OpenSpec\n\n"
                "This repo carries an `openspec/` spine.\n"
            )
        },
    )
    out = gen.render(rules)
    assert "## Spec - OpenSpec\n\n> **Applies only to a repo whose spec spine is OpenSpec**" in out
    # The marker itself never reaches the artifact, qualified or not.
    assert "steer:inject-when" not in out


def test_unqualified_token_ships_verbatim(tmp_path: Path):
    rules = _rules(
        tmp_path, **{"10_x.md": "<!-- steer:inject-when=code-project -->\n## Stack\n\nBody.\n"}
    )
    out = gen.render(rules)
    assert "## Stack\n\nBody." in out
    assert "Applies only" not in out


def test_real_rules_are_all_decided():
    from conftest import REPO_ROOT

    cwd = os.getcwd()
    os.chdir(REPO_ROOT)
    try:
        assert check_copilot_instructions.main() == 0
    finally:
        os.chdir(cwd)


def test_every_shipped_token_is_qualified_routed_or_exempted():
    from conftest import REPO_ROOT

    tokens = gen.rule_tokens(REPO_ROOT / gen.RULES_DIR)
    assert tokens, "no inject-when markers found - the audit would be vacuous"
    for token, rules in tokens.items():
        decided = (
            token in gen.SCOPE_PRECONDITIONS
            or token in gen.UNQUALIFIED_TOKENS
            or all(r in gen.SCOPED_RULES for r in rules)
        )
        assert decided, f"inject-when={token} ({rules}) is in neither map nor SCOPED_RULES"

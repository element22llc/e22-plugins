"""Tests for the cross-tool `.agents/skills` generator + sync gate.

``gen_agent_skills.py`` renders ``plugins/steer/templates/agents/skills/`` from
the authored ``plugins/steer/skills/``, rewriting the three things that do not
travel outside Claude Code: intra-skill asset paths (→ relative), shared-bundle
paths (→ URLs into the public plugin repo), and ``/steer:`` invocations
(→ ``/steer-``). The gate byte-compares the committed tree against a fresh render.
"""

from __future__ import annotations

import textwrap
from pathlib import Path

import check_agent_skills
import gen_agent_skills
import yaml


def _skill(root: Path, name: str, frontmatter: str, body: str) -> Path:
    d = root / name
    d.mkdir(parents=True, exist_ok=True)
    (d / "SKILL.md").write_text(
        f"---\n{textwrap.dedent(frontmatter).strip()}\n---\n\n{textwrap.dedent(body).strip()}\n",
        encoding="utf-8",
    )
    return d


def _front(text: str) -> dict:
    return yaml.safe_load(text.split("---", 2)[1])


def _after_banner(text: str) -> str:
    """Everything past the generated banner.

    The banner deliberately keeps a literal ``/steer:sync`` — that is the Claude
    Code command a maintainer runs to refresh the tree, not a cross-reference the
    portable body expects a reader to type. Assertions about rewritten invocations
    therefore look past it.
    """
    return text.split("-->", 1)[1] if "-->" in text else text


def test_name_is_prefixed_to_match_directory(tmp_path: Path):
    # The spec requires `name` to equal the parent directory name, and the tree is
    # written to `steer-<name>/` so the slash command is `/steer-<name>`.
    _skill(tmp_path, "audit", "name: audit\ndescription: Audit things.", "# Body")
    tree = gen_agent_skills.build(tmp_path)
    assert Path("steer-audit/SKILL.md") in tree
    assert _front(tree[Path("steer-audit/SKILL.md")])["name"] == "steer-audit"


def test_intra_skill_refs_go_relative_and_shared_refs_go_to_urls(tmp_path: Path):
    d = _skill(
        tmp_path,
        "work",
        "name: work\ndescription: Do work.",
        """
        See [modes](${CLAUDE_PLUGIN_ROOT}/skills/work/modes/hotfix.md).
        Deep prose: `${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md`.
        Another skill: ${CLAUDE_PLUGIN_ROOT}/skills/issues/modes/backlog.md
        """,
    )
    (d / "modes").mkdir()
    (d / "modes" / "hotfix.md").write_text("hotfix\n", encoding="utf-8")

    out = gen_agent_skills.build(tmp_path)[Path("steer-work/SKILL.md")]
    # 1. Own asset -> relative path, and the file travels with it.
    assert "[modes](modes/hotfix.md)" in out
    assert Path("steer-work/modes/hotfix.md") in gen_agent_skills.build(tmp_path)
    # 2. Shared bundle and other skills -> absolute URL on the public repo.
    assert f"{gen_agent_skills.BLOB_BASE}/templates/reference/NEXT-ACTIONS.md" in out
    assert f"{gen_agent_skills.BLOB_BASE}/skills/issues/modes/backlog.md" in out
    # No unresolved plugin-root reference may survive anywhere.
    assert "CLAUDE_PLUGIN_ROOT" not in out


def test_steer_invocations_are_rewritten_everywhere(tmp_path: Path):
    d = _skill(
        tmp_path,
        "spec",
        "name: spec\ndescription: Spec things.",
        "Route through `/steer:tracker-sync`, then `/steer:work`.",
    )
    (d / "MODES.md").write_text("Also `/steer:audit`.\n", encoding="utf-8")
    tree = gen_agent_skills.build(tmp_path)
    assert "/steer-tracker-sync" in tree[Path("steer-spec/SKILL.md")]
    assert "/steer:" not in _after_banner(tree[Path("steer-spec/SKILL.md")])
    # Supporting files get the same rewrite — not just SKILL.md.
    assert "/steer-audit" in tree[Path("steer-spec/MODES.md")]


def test_when_to_use_is_folded_into_the_body(tmp_path: Path):
    # `when_to_use` is a Claude Code extension, not an Agent Skills spec field, so
    # it must not survive as a key — but its routing signal must not be lost.
    _skill(
        tmp_path,
        "next",
        "name: next\ndescription: What next.\nwhen_to_use: Use when picking work up.",
        "# Body",
    )
    out = gen_agent_skills.build(tmp_path)[Path("steer-next/SKILL.md")]
    assert "when_to_use" not in _front(out)
    assert "**When to use.** Use when picking work up." in out


def test_tool_grants_are_dropped_and_restrictions_restated_as_instruction(tmp_path: Path):
    # Claude tool syntax means nothing to another agent, so the fields are dropped —
    # but a body that says "these tools are unavailable" would then be lying.
    _skill(
        tmp_path,
        "audit",
        """
        name: audit
        description: Read-only audit.
        allowed-tools: Read Grep
        disallowed-tools: Edit, NotebookEdit
        """,
        "The in-place edit tools are unavailable while this skill runs.",
    )
    out = gen_agent_skills.build(tmp_path)[Path("steer-audit/SKILL.md")]
    front = _front(out)
    assert "allowed-tools" not in front and "disallowed-tools" not in front
    assert "enforced by instruction, not by tooling" in out
    assert "`Edit`, `NotebookEdit`" in out


def test_declarative_fields_are_kept(tmp_path: Path):
    _skill(
        tmp_path,
        "spec-scaffold",
        """
        name: spec-scaffold
        description: Internal gateway.
        argument-hint: '[id]'
        user-invocable: false
        """,
        "# Body",
    )
    front = _front(gen_agent_skills.build(tmp_path)[Path("steer-spec-scaffold/SKILL.md")])
    assert front["argument-hint"] == "[id]"
    assert front["user-invocable"] is False


def test_gate_reports_missing_extra_and_changed(tmp_path: Path, monkeypatch, capsys):
    src = tmp_path / "skills"
    src.mkdir()
    _skill(src, "alpha", "name: alpha\ndescription: A.", "# A")
    out = tmp_path / "out"
    monkeypatch.setattr(check_agent_skills, "SKILLS_DIR", src)
    monkeypatch.setattr(check_agent_skills, "OUT_DIR", out)
    monkeypatch.setattr(gen_agent_skills, "SKILLS_DIR", src)

    gen_agent_skills.main(["--write", "--skills-dir", str(src), "--out", str(out)])
    assert check_agent_skills.main() == 0

    (out / "steer-alpha" / "SKILL.md").write_text("tampered\n", encoding="utf-8")
    assert check_agent_skills.main() == 1
    assert "changed" in capsys.readouterr().err

    (out / "steer-alpha" / "SKILL.md").unlink()
    assert check_agent_skills.main() == 1
    assert "missing" in capsys.readouterr().err


def test_write_prunes_a_removed_skill(tmp_path: Path):
    # A renamed or deleted skill must not leave a stale directory behind, or the
    # consumer keeps a skill the plugin no longer ships.
    src = tmp_path / "skills"
    src.mkdir()
    _skill(src, "alpha", "name: alpha\ndescription: A.", "# A")
    _skill(src, "beta", "name: beta\ndescription: B.", "# B")
    out = tmp_path / "out"
    gen_agent_skills.main(["--write", "--skills-dir", str(src), "--out", str(out)])
    assert (out / "steer-beta").is_dir()

    (src / "beta" / "SKILL.md").unlink()
    gen_agent_skills.main(["--write", "--skills-dir", str(src), "--out", str(out)])
    assert not (out / "steer-beta").exists()


def test_real_plugin_tree_is_in_sync_and_fully_resolved():
    from conftest import REPO_ROOT

    tree = gen_agent_skills.build(REPO_ROOT / gen_agent_skills.SKILLS_DIR)
    assert len({p.parts[0] for p in tree}) == 26, "every authored skill must ship"
    for rel, text in tree.items():
        assert "CLAUDE_PLUGIN_ROOT" not in text, f"unresolved plugin-root path in {rel}"
        body = _after_banner(text)
        assert "/steer:" not in body, f"unrewritten /steer: invocation in {rel}"

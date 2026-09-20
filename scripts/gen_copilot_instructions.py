#!/usr/bin/env python3
"""Generate the GitHub Copilot custom-instructions artifact from steer's rules.

steer's always-on engineering standards live in ``plugins/steer/rules/*.md`` and
reach Claude Code via the ``inject-standards.sh`` SessionStart hook, whose stdout
becomes the session's ``additionalContext``. GitHub Copilot has no equivalent
context-injecting hook - its ``sessionStart`` hook ignores stdout - so Copilot's
always-on context comes from a static custom-instructions file, primarily
``.github/copilot-instructions.md``. This one file serves **both** Copilot
surfaces: the Copilot CLI and Copilot in VS Code (which reads it natively).

This script concatenates the same ``rules/*.md`` (lexical order, mirroring the
hook) into ``plugins/steer/templates/github/copilot-instructions.md`` - the
committed artifact ``/steer:init`` / ``/steer:adopt`` install into a consumer
repo's ``.github/``. Keeping a single source of truth (the rules) means the two
surfaces never diverge; ``check_copilot_instructions.py`` fails the build if the
committed artifact drifts from the rules.

We target ``.github/copilot-instructions.md`` rather than ``AGENTS.md`` on
purpose: Copilot reads ``AGENTS.md`` *and* ``CLAUDE.md`` as merged peers, so an
``AGENTS.md`` would double-load org standards alongside the consumer repo's
``CLAUDE.md`` (and Claude Code does not read ``AGENTS.md`` at all). The ``.github/``
primary file is read only by Copilot and never competes at the repo root.

Run from the repo root::

    uv run python scripts/gen_copilot_instructions.py            # print to stdout
    uv run python scripts/gen_copilot_instructions.py --write    # write the artifact
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import yaml

RULES_DIR = Path("plugins/steer/rules")
ARTIFACT = Path("plugins/steer/templates/github/copilot-instructions.md")
INSTRUCTIONS_DIR = Path("plugins/steer/templates/github/instructions")

# A rule may open with `<!-- steer:inject-when=<token> -->`, directing the Claude
# SessionStart hook to inject it only where its scope applies (inject-standards.sh
# strips the line before emitting). Most tokens are repo-level traits with no
# per-file meaning, so the flat artifact carries those rules unconditionally and
# just drops the marker (mirroring the hook). But a few rules ARE genuinely
# path-scoped, and Copilot has a native mechanism for that: path-specific
# instruction files (`.github/instructions/<name>.instructions.md` with an
# `applyTo` glob) that surface only when Copilot works on matching files. We route
# those rules there instead of the flat file - the Copilot analog of the Claude
# hook's trait gating, and a tighter fit than dumping infra rules into every
# repo's always-on context.
SCOPED_RULES: dict[str, dict[str, str]] = {
    "12-stack-infra.md": {
        "name": "infra",
        "applyTo": (
            "**/*.tf,**/*.tofu,**/*.hcl,**/*.tfvars,**/*.tf.json,"
            "infra/**,live/**,modules/**,roles/**,playbooks/**,inventory/**"
        ),
        "description": (
            "Infrastructure-as-code stack standards - applied when editing "
            "Terraform/OpenTofu/Terragrunt/Ansible/Pulumi files."
        ),
    },
}

_INJECT_WHEN_MARKER = re.compile(r"^<!--\s*steer:inject-when=(?P<token>\S+)\s*-->\n?")

# A rule kept in the flat file loses the hook's gating, so one that ASSERTS its
# trait as fact ships that assertion to every repo. Rule 33 said "This repo
# carries an `openspec/` spine" to native `spec/` repos, contradicting the
# unqualified Spec workflow rule in the same file. The flat file cannot test a
# repo trait, so it states the precondition instead: the reader can check it, and
# on the repo the rule is really for the line is simply true. Keyed by token, so a
# new trait-scoped rule inherits the qualification instead of depending on its
# author having written a conditional first sentence.
#
# A token that needs no precondition is listed in ``UNQUALIFIED_TOKENS`` with its
# reason; `check_copilot_instructions.py` fails when a rule carries a token in
# neither map nor in ``SCOPED_RULES``, so a new trait-scoped rule forces the
# decision rather than shipping unqualified by default - the #577 failure mode.
SCOPE_PRECONDITIONS: dict[str, str] = {
    "has-openspec": (
        "**Applies only to a repo whose spec spine is OpenSpec** - it has "
        "`openspec/project.md`, `openspec/specs/` or `openspec/changes/`. If this "
        "repo has none of those, skip this section entirely: the unqualified Spec "
        "workflow above governs, and `spec/features/**` is where specs belong."
    ),
    "has-iac": (
        "**Applies only to a repo that does infrastructure-as-code** - it has "
        "Terraform/OpenTofu/Terragrunt/Pulumi or Ansible sources (an `infra/` "
        "directory, `*.tf`/`*.tofu`/`*.hcl`, `playbooks/`, `roles/`). Skip this "
        "section in a repo with none."
    ),
    "tracker-github": (
        "**Applies only where the tracker declaration says `system: github`** - "
        "`spec/tracker.md`, or `openspec/steer/tracker.md` on an OpenSpec repo (in "
        "a polyrepo member, the workspace's). On any other tracker, or with none "
        "declared, skip this section."
    ),
}

# Brand-free (the payload debrand gate scans templates/github) and skill-ref-safe
# (`/steer:sync` resolves to a real skill). The refresh path is `/steer:sync` - its
# `agent-surface-current` capability re-copies each generated artifact verbatim
# from the plugin. It is NOT `/steer:init`: init stops on an already-initialized
# repo, so it can never refresh anything. Copilot teammates only consume the
# installed file, so the header must name a path that works from a managed repo.
HEADER = (
    "<!-- Engineering standards (steer plugin). Generated from the plugin's "
    "rules/ - do not edit by hand. Refresh after a plugin update with /steer:sync "
    "from Claude Code in a managed repo, or mise run gen:copilot in the plugin "
    "repo. -->"
)

# The rules are carried verbatim, so every skill cross-reference in them uses the
# `/steer:<skill>` form Claude Code namespaces with a colon. Copilot in VS Code
# surfaces the same skills as prompt files under `/steer-<skill>` (a hyphen), so
# a reader following a router table below would type a command that does not
# exist there. `gen_agent_skills.py` rewrites refs to the hyphen form for the
# prompt artifacts, but this file is read by BOTH Copilot surfaces and the CLI
# loads skills from the plugin manifest - so a blanket rewrite would be wrong for
# one of them. State the mapping once, up front, instead.
INVOCATION_NOTE = (
    "> **Invoking a skill on this surface.** The standards below name skills in "
    "the `/steer:<skill>` form (how Claude Code namespaces them). In **Copilot "
    "for VS Code** the same skills ship in the cross-tool `.agents/skills/` "
    "tree, invoked as **`/steer-<skill>`** - type `/steer-` in Chat to list "
    "them. On the "
    "**Copilot CLI** they load from the plugin manifest. Read any "
    "`/steer:<skill>` reference below as the skill of that name on whichever "
    "surface you are on."
)

# Tokens that deliberately ship unqualified, with the reason each is safe.
UNQUALIFIED_TOKENS: dict[str, str] = {
    "code-project": (
        "the work-mode baseline (code repo vs knowledge folder); this artifact is "
        "installed into code repos by the bootstrap skills, and qualifying 20 rules "
        "with it would be noise"
    ),
    "has-iac|has-apps": (
        "an alternation covering app and IaC repos alike, and rule 52 opens on what "
        "it is about rather than asserting a trait - there is nothing false to read"
    ),
}


def iter_rule_files(rules_dir: Path) -> list[Path]:
    """The rule files, in the lexical order the SessionStart hook concatenates
    them (the numeric file prefixes encode that order), EXCLUDING rules routed to
    path-scoped instruction files (see ``SCOPED_RULES``)."""
    if not rules_dir.is_dir():
        return []
    return [f for f in sorted(rules_dir.glob("*.md")) if f.name not in SCOPED_RULES]


def render(rules_dir: Path = RULES_DIR) -> str:
    """Return the full copilot-instructions text: header then each repo-wide rule
    body, blank-line separated, with a single trailing newline (mirrors
    ``inject-standards.sh`` minus its Claude-specific banner). Path-scoped rules
    are emitted separately by ``render_scoped``."""
    parts: list[str] = [HEADER, "\n\n", INVOCATION_NOTE, "\n\n"]
    for f in iter_rule_files(rules_dir):
        parts.append(_qualified_body(f.read_text(encoding="utf-8")))
        parts.append("\n\n")
    return "".join(parts).rstrip("\n") + "\n"


def rule_tokens(rules_dir: Path = RULES_DIR) -> dict[str, list[str]]:
    """Return {inject-when token: [rule filenames carrying it]} across all rules,
    routed and flat alike - the surface ``check_copilot_instructions`` audits."""
    out: dict[str, list[str]] = {}
    if not rules_dir.is_dir():
        return out
    for f in sorted(rules_dir.glob("*.md")):
        marker = _INJECT_WHEN_MARKER.match(f.read_text(encoding="utf-8"))
        if marker is not None:
            out.setdefault(marker.group("token"), []).append(f.name)
    return out


def _qualified_body(text: str) -> str:
    """Strip the ``inject-when`` marker and, for a trait-scoped rule that stays in
    the flat file, state its precondition under the rule's heading."""
    marker = _INJECT_WHEN_MARKER.match(text)
    body = _INJECT_WHEN_MARKER.sub("", text, count=1)
    if marker is None:
        return body
    precondition = SCOPE_PRECONDITIONS.get(marker.group("token"))
    if precondition is None:
        return body
    heading, sep, rest = body.partition("\n")
    return f"{heading}{sep}\n> {precondition}\n{rest}"


def render_scoped(rules_dir: Path = RULES_DIR) -> dict[str, str]:
    """Return {artifact_filename: text} for each path-scoped instruction file.

    Each is a ``<name>.instructions.md`` carrying an ``applyTo`` glob in its
    frontmatter so Copilot loads it only when working on matching files."""
    out: dict[str, str] = {}
    for rule_name, spec in SCOPED_RULES.items():
        rule_path = rules_dir / rule_name
        if not rule_path.is_file():
            continue
        # No precondition line here: `applyTo` already gates this file, so the
        # sentence the flat artifact needs would be redundant.
        body = _INJECT_WHEN_MARKER.sub("", rule_path.read_text(encoding="utf-8"), count=1).strip()
        front = yaml.safe_dump(
            {"applyTo": spec["applyTo"], "description": spec["description"]},
            default_flow_style=False,
            sort_keys=False,
            allow_unicode=True,
            width=10**9,
        ).rstrip("\n")
        header = (
            # `/steer:sync` (colon) with the surface named explicitly. The refresh is
            # a verbatim re-copy from ${CLAUDE_PLUGIN_ROOT}, absent in VS Code, so it
            # is an action taken from Claude Code - naming the surface is what makes
            # the colon form unambiguous without this file needing the flat
            # instructions file's `/steer:` -> `/steer-` mapping preamble.
            f"<!-- Generated from the steer plugin's rules/{rule_name} - do not edit "
            f"by hand. Refresh with /steer:sync from Claude Code in a managed repo, "
            f"or mise run gen:copilot in the plugin repo. -->"
        )
        out[f"{spec['name']}.instructions.md"] = f"{header}\n---\n{front}\n---\n\n{body}\n"
    return out


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Generate the Copilot instructions artifact.")
    parser.add_argument(
        "--write",
        action="store_true",
        help=f"Write the artifact to {ARTIFACT} (default: print to stdout).",
    )
    parser.add_argument(
        "--rules-dir",
        type=Path,
        default=RULES_DIR,
        help=f"Rules directory to concatenate (default: {RULES_DIR}).",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=ARTIFACT,
        help=f"Output path when --write is set (default: {ARTIFACT}).",
    )
    parser.add_argument(
        "--instructions-dir",
        type=Path,
        default=INSTRUCTIONS_DIR,
        help=f"Path-scoped instructions dir when --write is set (default: {INSTRUCTIONS_DIR}).",
    )
    args = parser.parse_args(argv)

    if not args.rules_dir.is_dir():
        print(f"gen_copilot_instructions: rules dir not found: {args.rules_dir}", file=sys.stderr)
        return 1

    text = render(args.rules_dir)
    scoped = render_scoped(args.rules_dir)
    if args.write:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text, encoding="utf-8")
        print(f"gen_copilot_instructions: wrote {args.out} ({len(text)} bytes)")
        args.instructions_dir.mkdir(parents=True, exist_ok=True)
        # Prune stale scoped files (a rule un-scoped) so the committed set matches.
        keep = set(scoped)
        for existing in args.instructions_dir.glob("*.instructions.md"):
            if existing.name not in keep:
                existing.unlink()
        for filename, body in scoped.items():
            (args.instructions_dir / filename).write_text(body, encoding="utf-8")
        print(
            f"gen_copilot_instructions: wrote {len(scoped)} scoped instruction "
            f"file(s) to {args.instructions_dir}"
        )
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())

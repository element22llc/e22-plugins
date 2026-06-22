#!/usr/bin/env python3
"""scaffold_reconcile.py — additive, never-clobber reconciliation for the
non-Markdown scaffold files. The structured-config sibling of
template-reconcile.sh.

template-reconcile.sh reconciles Markdown spec files on heading/checklist
anchors. It cannot parse the structured-config formats the scaffold also ships,
so merging those into a repo that already has its own copy (during /steer:adopt
or /steer:sync) was prose-only. This helper closes that gap for:

  * JSON   — .claude/settings.json, biome.json, tsconfig, …
  * gitignore (and the same line-based .worktreeinclude)

CONTRACT (mirrors template-reconcile.sh)

  Usage:
    scaffold_reconcile.py <kind> <existing-file> <template-file> [--apply]
      kind: json | gitignore | auto   (auto infers from the existing file name)

  Default (check) mode — read-only. Prints the additive delta the template
  contributes that the existing file lacks (missing JSON key-paths / array
  elements, missing gitignore patterns). Modifies nothing.

  --apply mode — additive merge into the existing file:
    * JSON: deep-merge. Objects recurse; arrays are unioned (existing order
      kept, template-only entries appended); scalars KEEP THE EXISTING VALUE
      (never overwritten); template-only keys are appended after existing keys.
    * gitignore: template patterns not already present are appended; nothing is
      reordered or removed.
    Never deletes, reorders, or changes an existing value/line.

  PERMISSION TIERS — the one place this merge removes content. A Claude Code
  `permissions` block has three sibling lists evaluated by precedence
  deny > ask > allow, so the SAME pattern string in two tiers is a
  contradiction, never a meaningful choice: the lower-precedence copy is dead
  weight (e.g. `Bash(git push)` in both `allow` and `ask` always behaves as
  `ask`). A plain array union manufactures exactly that contradiction — the
  template carries `git push` in `ask`, a repo that locally allow-listed it
  ends up with it in both. So after merging, each permission pattern is kept
  only in its most-restrictive tier and dropped from the others. This both
  prevents a sync from creating the contradiction and heals one already on
  disk; it never changes effective behavior (the surviving tier is the one that
  already governed), so it is not a clobber of any real decision. Reported with
  a `-` prefix in the delta.

  If the existing file is absent, --apply writes the template verbatim (a safe
  install) and check reports the whole template as missing.

EXIT CODES (same convention as template-reconcile.sh — gaps are signaled via
stdout, not a nonzero code, so a skill's Bash wrapper doesn't read a normal
"gaps found" run as a failure):
  0  ran OK. check: empty stdout = already current; any output = additive delta
     to review. --apply: empty stdout = nothing written; output = what was added.
  2  usage error.
  3  an input file is missing/unreadable, or the existing file is not valid JSON
     (fail loud — never clobber a file we cannot parse).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

USAGE = (
    "usage: scaffold_reconcile.py <json|gitignore|auto> <existing-file> <template-file> [--apply]"
)


def _die(code: int, msg: str) -> int:
    print(msg, file=sys.stderr)
    return code


def _infer_kind(existing: Path) -> str | None:
    name = existing.name
    if name == ".gitignore" or name == "gitignore" or name.endswith(".gitignore"):
        return "gitignore"
    # .worktreeinclude is the same line-based ignore-style format, so it uses
    # the same additive merge (append missing patterns, never clobber).
    if name == ".worktreeinclude" or name == "worktreeinclude":
        return "gitignore"
    if name.endswith(".json") or name.endswith(".jsonc"):
        return "json"
    return None


# --- JSON additive merge --------------------------------------------------


def _fmt_path(path: list[str]) -> str:
    return ".".join(path) if path else "(root)"


def merge_json(existing: object, template: object, path: list[str], added: list[str]) -> object:
    """Deep additive merge. Returns the merged value; appends a human-readable
    line to `added` for every key/array element introduced. Existing scalars and
    type mismatches keep the existing value — never clobbered."""
    if isinstance(existing, dict) and isinstance(template, dict):
        merged = dict(existing)  # preserve existing key order + values
        for key, tval in template.items():
            if key not in merged:
                merged[key] = tval
                added.append(f"+ {_fmt_path([*path, key])}")
            else:
                merged[key] = merge_json(merged[key], tval, [*path, key], added)
        return merged
    if isinstance(existing, list) and isinstance(template, list):
        merged_list = list(existing)
        for item in template:
            if item not in merged_list:
                merged_list.append(item)
                added.append(f"+ {_fmt_path(path)}[] = {json.dumps(item, ensure_ascii=False)}")
        return merged_list
    # scalar, or a type mismatch between existing and template: keep existing.
    return existing


# Claude Code permission lists, ordered most → least restrictive. Evaluation
# precedence is deny > ask > allow, so a pattern present in two of these is a
# contradiction and only the most-restrictive copy governs.
_PERMISSION_TIERS = ("deny", "ask", "allow")


def _dedupe_permission_tiers(merged: object, added: list[str]) -> None:
    """Keep each permission pattern only in its most-restrictive tier.

    Mutates ``merged["permissions"]`` in place and records every dropped copy in
    ``added`` (``-`` prefix). A no-op unless a pattern appears in more than one
    of allow/ask/deny — see the module docstring for why this single removal is
    not a clobber. Non-string entries are left untouched (permission patterns
    are always strings)."""
    if not isinstance(merged, dict):
        return
    perms = merged.get("permissions")
    if not isinstance(perms, dict):
        return
    claimed: set[str] = set()  # patterns already held by a higher-precedence tier
    for tier in _PERMISSION_TIERS:
        lst = perms.get(tier)
        if not isinstance(lst, list):
            continue
        kept: list[object] = []
        for item in lst:
            if isinstance(item, str) and item in claimed:
                added.append(
                    f"- {_fmt_path(['permissions', tier])}[] = "
                    f"{json.dumps(item, ensure_ascii=False)} (also in a higher-precedence tier)"
                )
                continue
            kept.append(item)
            if isinstance(item, str):
                claimed.add(item)
        perms[tier] = kept


def _reconcile_json(existing_path: Path, template: object, apply: bool) -> int:
    if existing_path.exists():
        try:
            existing = json.loads(existing_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError) as exc:
            return _die(
                3, f"scaffold_reconcile: existing file is not valid JSON: {existing_path}: {exc}"
            )
    else:
        existing = None

    added: list[str] = []
    if existing is None:
        # No existing file: the whole template is "missing".
        merged = template
        added.append(f"+ (new file) {existing_path.name}")
    else:
        merged = merge_json(existing, template, [], added)

    # Resolve permission-tier contradictions the union may have created (or that
    # were already on disk): deny > ask > allow, most-restrictive copy wins.
    _dedupe_permission_tiers(merged, added)

    if not added:
        return 0  # already current — no output, exit 0

    if apply:
        existing_path.parent.mkdir(parents=True, exist_ok=True)
        existing_path.write_text(
            json.dumps(merged, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
    print("\n".join(added))
    return 0


# --- gitignore additive merge ---------------------------------------------


def _patterns(lines: list[str]) -> list[str]:
    """Stripped, non-blank, non-comment lines, order-preserving and de-duplicated."""
    seen: set[str] = set()
    out: list[str] = []
    for line in lines:
        s = line.strip()
        if not s or s.startswith("#") or s in seen:
            continue
        seen.add(s)
        out.append(s)
    return out


def _reconcile_gitignore(existing_path: Path, template_text: str, apply: bool) -> int:
    template_patterns = _patterns(template_text.splitlines())
    if existing_path.exists():
        existing_text = existing_path.read_text(encoding="utf-8")
        existing_patterns = set(_patterns(existing_text.splitlines()))
    else:
        existing_text = ""
        existing_patterns = set()

    missing = [p for p in template_patterns if p not in existing_patterns]
    if not missing:
        return 0

    if apply:
        prefix = existing_text
        if prefix and not prefix.endswith("\n"):
            prefix += "\n"
        addition = "\n".join(missing) + "\n"
        existing_path.parent.mkdir(parents=True, exist_ok=True)
        existing_path.write_text(prefix + addition, encoding="utf-8")
    print("\n".join(f"+ {p}" for p in missing))
    return 0


# --- entry point ----------------------------------------------------------


def main(argv: list[str]) -> int:
    args = list(argv)
    apply = False
    if "--apply" in args:
        apply = True
        args.remove("--apply")
    if len(args) != 3:
        return _die(2, USAGE)

    kind, existing_arg, template_arg = args
    existing_path = Path(existing_arg)
    template_path = Path(template_arg)

    if kind not in ("json", "gitignore", "auto"):
        return _die(2, USAGE)
    if not template_path.is_file():
        return _die(3, f"scaffold_reconcile: cannot read template: {template_path}")

    if kind == "auto":
        inferred = _infer_kind(existing_path)
        if inferred is None:
            return _die(
                2,
                f"scaffold_reconcile: cannot infer kind from {existing_path.name}; "
                "pass json|gitignore",
            )
        kind = inferred

    if kind == "json":
        try:
            template = json.loads(template_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError) as exc:
            return _die(
                3, f"scaffold_reconcile: template is not valid JSON: {template_path}: {exc}"
            )
        return _reconcile_json(existing_path, template, apply)

    return _reconcile_gitignore(existing_path, template_path.read_text(encoding="utf-8"), apply)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

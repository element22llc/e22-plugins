#!/usr/bin/env python3
"""scaffold-reconcile.py — additive, never-clobber reconciliation for the
non-Markdown scaffold files. The structured-config sibling of
template-reconcile.sh.

template-reconcile.sh reconciles Markdown spec files on heading/checklist
anchors. It cannot parse the structured-config formats the scaffold also ships,
so merging those into a repo that already has its own copy (during /steer:adopt
or /steer:sync) was prose-only. This helper closes that gap for:

  * JSON   — .claude/settings.json, .mcp.json, biome.json, tsconfig, …
  * gitignore (and the same line-based .worktreeinclude)

CONTRACT (mirrors template-reconcile.sh)

  Usage:
    scaffold-reconcile.py <kind> <existing-file> <template-file> [--apply]
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
    "usage: scaffold-reconcile.py <json|gitignore|auto> <existing-file> <template-file> [--apply]"
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


def _reconcile_json(existing_path: Path, template: object, apply: bool) -> int:
    if existing_path.exists():
        try:
            existing = json.loads(existing_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError) as exc:
            return _die(
                3, f"scaffold-reconcile: existing file is not valid JSON: {existing_path}: {exc}"
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
        return _die(3, f"scaffold-reconcile: cannot read template: {template_path}")

    if kind == "auto":
        inferred = _infer_kind(existing_path)
        if inferred is None:
            return _die(
                2,
                f"scaffold-reconcile: cannot infer kind from {existing_path.name}; "
                "pass json|gitignore",
            )
        kind = inferred

    if kind == "json":
        try:
            template = json.loads(template_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError) as exc:
            return _die(
                3, f"scaffold-reconcile: template is not valid JSON: {template_path}: {exc}"
            )
        return _reconcile_json(existing_path, template, apply)

    return _reconcile_gitignore(existing_path, template_path.read_text(encoding="utf-8"), apply)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

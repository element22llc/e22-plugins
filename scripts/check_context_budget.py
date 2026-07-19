#!/usr/bin/env python3
"""Always-on context budget gate for the steer plugin.

steer pays a context-window cost in **every** product session before the user
types anything: the SessionStart hook injects the concatenated ``rules/*.md``,
and Claude Code loads every skill's ``description`` + ``when_to_use`` into the
skill listing used for routing. Neither surface is reviewed as a whole in any
PR — each edit looks small, so the total silently creeps.

This gate makes the total explicit and enforces a **ratchet**: hard ceilings
set at the measured baseline (plus small headroom) so the always-on weight can
only shrink or hold, never regress. The aspirational targets from the
improvement plan (PLAN.md, Phase 1) are reported for visibility but do not
fail the gate — lowering the ceilings toward them is deliberate, per-PR work.

Budgets enforced:

- ``RULES_TOTAL_MAX_BYTES`` — total bytes across ``rules/*.md`` (the
  SessionStart injection payload);
- ``LISTING_TOTAL_MAX_CHARS`` — total ``description`` + ``when_to_use``
  characters across all skills (the always-on routing surface). The *per-skill*
  1536-char cap lives in ``check_plugin.py``; this is the cross-skill sum.

Run from the repo root::

    uv run python scripts/check_context_budget.py            # gate (exit 1 over budget)
    uv run python scripts/check_context_budget.py --report   # markdown budget table

Exit status is 0 when within budget, 1 when any ceiling is exceeded.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import yaml

PLUGIN_ROOT = Path("plugins/steer")

# --- Ratchet ceilings (hard gate) -------------------------------------------
# Re-armed after the Phase 1 pass-1 trim (PLAN.md): rules 65,508 bytes across
# 34 files (was 69,335); listing 10,867 chars across 26 skills (was 17,950).
# Headroom (~2-5%) absorbs small legitimate edits; anything larger must trade
# prose out first. LOWER these again as further reductions land.
RULES_TOTAL_MAX_BYTES = 66_500
LISTING_TOTAL_MAX_CHARS = 11_500

# --- Aspirational targets (reported, never enforced here) --------------------
# PLAN.md Phase 1 end-state. Enforced only by ratcheting the ceilings down as
# real reductions land.
RULES_TOTAL_TARGET_BYTES = 30_000
LISTING_TOTAL_TARGET_CHARS = 10_000


def _parse_frontmatter(text: str) -> dict:
    """Best-effort frontmatter parse: return {} on any malformed input.

    Malformed frontmatter is check_plugin.py's finding, not ours — this gate
    only sums what Claude Code would actually load.
    """
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}
    for idx in range(1, len(lines)):
        if lines[idx].strip() == "---":
            try:
                data = yaml.safe_load("\n".join(lines[1:idx]))
            except yaml.YAMLError:
                return {}
            return data if isinstance(data, dict) else {}
    return {}


def measure(root: Path) -> dict:
    """Measure both always-on surfaces. Returns a stats dict."""
    rules = sorted((root / "rules").glob("*.md"))
    rules_bytes = sum(p.stat().st_size for p in rules)

    listing_chars = 0
    skills = []
    skills_dir = root / "skills"
    if skills_dir.is_dir():
        for skill_dir in sorted(p for p in skills_dir.glob("*") if p.is_dir()):
            skill_md = skill_dir / "SKILL.md"
            if not skill_md.is_file():
                continue
            fm = _parse_frontmatter(skill_md.read_text(encoding="utf-8"))
            desc = fm.get("description")
            wtu = fm.get("when_to_use")
            chars = (len(desc) if isinstance(desc, str) else 0) + (
                len(wtu) if isinstance(wtu, str) else 0
            )
            listing_chars += chars
            skills.append((skill_dir.name, chars))

    return {
        "rules_files": len(rules),
        "rules_bytes": rules_bytes,
        "skills": skills,
        "listing_chars": listing_chars,
    }


def run_checks(root: Path) -> list[str]:
    errors: list[str] = []
    if not root.is_dir():
        return [f"{root}: plugin root directory not found"]
    stats = measure(root)

    if stats["rules_bytes"] > RULES_TOTAL_MAX_BYTES:
        errors.append(
            f"{root / 'rules'}: total {stats['rules_bytes']:,} bytes exceeds the "
            f"{RULES_TOTAL_MAX_BYTES:,}-byte always-on budget — rules/*.md is "
            f"injected into EVERY session. Move prose to templates/reference/* "
            f"(surfaced via /steer:reference) and keep rules imperative; do not "
            f"raise the ceiling to fit new prose (see PLAN.md Phase 1)."
        )
    if stats["listing_chars"] > LISTING_TOTAL_MAX_CHARS:
        errors.append(
            f"{root / 'skills'}: total description + when_to_use is "
            f"{stats['listing_chars']:,} chars, over the "
            f"{LISTING_TOTAL_MAX_CHARS:,}-char routing-surface budget — the skill "
            f"listing loads into every session. Trim descriptions to purpose + "
            f"primary trigger; move disambiguation into the skill body, which "
            f"loads only on invocation."
        )
    return errors


def report(root: Path) -> str:
    """Markdown budget table — paste into release PRs (PLAN.md Phase 4)."""
    stats = measure(root)
    lines = [
        "| Always-on surface | Current | Ceiling (gate) | Target (plan) |",
        "| --- | --- | --- | --- |",
        (
            f"| rules/*.md injection ({stats['rules_files']} files) "
            f"| {stats['rules_bytes']:,} B | {RULES_TOTAL_MAX_BYTES:,} B "
            f"| {RULES_TOTAL_TARGET_BYTES:,} B |"
        ),
        (
            f"| skill listing ({len(stats['skills'])} skills) "
            f"| {stats['listing_chars']:,} ch | {LISTING_TOTAL_MAX_CHARS:,} ch "
            f"| {LISTING_TOTAL_TARGET_CHARS:,} ch |"
        ),
        "",
        "Top skill-listing consumers:",
    ]
    for name, chars in sorted(stats["skills"], key=lambda s: -s[1])[:5]:
        lines.append(f"- {name}: {chars:,} chars")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Enforce steer's always-on context budgets.")
    parser.add_argument(
        "--plugin-root",
        type=Path,
        default=PLUGIN_ROOT,
        help=f"Path to the plugin root (default: {PLUGIN_ROOT})",
    )
    parser.add_argument(
        "--report",
        action="store_true",
        help="Print the markdown budget table instead of gating.",
    )
    args = parser.parse_args(argv)

    if args.report:
        print(report(args.plugin_root))
        return 0

    errors = run_checks(args.plugin_root)
    if errors:
        print(f"check_context_budget: {len(errors)} problem(s) found:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1
    print("check_context_budget: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())

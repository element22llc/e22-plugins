#!/usr/bin/env python3
"""Routing regression net for the steer plugin's always-on routing surface.

steer routes plain-language asks to skills via two always-on inputs: the
``rules/00-router.md`` intent table and each skill's ``description`` +
``when_to_use`` frontmatter. PLAN.md Phase 1 trims both aggressively — this
gate is the net that keeps trimming honest: every fixture in
``tests/fixtures/routing/asks.yml`` records a representative user ask, the
skill that owns it, and the **signal keywords** that make the mapping
discoverable. A trim that strips a signal from the routing surface fails here,
instead of silently degrading routing.

Fixture schema (``asks.yml``)::

    fixtures:
      - ask: "set up this new repo on our standards"
        skill: setup
        signals: ["set up", "onboard"]

Checks enforced:

- every fixture names an existing skill directory;
- every fixture carries at least one signal, and each signal appears
  (case-insensitively) in that fixture's routing surface — the union of
  ``rules/00-router.md`` and the skill's ``description`` + ``when_to_use``;
- asks are unique, and the fixture count never drops below the floor
  (deleting fixtures to make a trim pass is the failure mode this guards).

This is a deterministic lexical proxy, not a model eval: it cannot prove an
ask routes correctly, but it proves the vocabulary that routing depends on is
still present. The e2e tier (``mise run e2e``) remains the behavioral check.

Run from the repo root::

    uv run python scripts/check_routing_fixtures.py

Exit status is 0 when clean, 1 when any check fails.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import yaml

PLUGIN_ROOT = Path("plugins/steer")
FIXTURES = Path("tests/fixtures/routing/asks.yml")

# Deleting fixtures must be a deliberate, reviewed act — the floor stops a
# failing fixture from being "fixed" by removal. Raise it as coverage grows.
MIN_FIXTURES = 40


def _parse_frontmatter(text: str) -> dict:
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


def _skill_listing_text(root: Path, skill: str) -> str | None:
    """The skill's contribution to the routing surface, or None if absent."""
    skill_md = root / "skills" / skill / "SKILL.md"
    if not skill_md.is_file():
        return None
    fm = _parse_frontmatter(skill_md.read_text(encoding="utf-8"))
    desc = fm.get("description")
    wtu = fm.get("when_to_use")
    return " ".join(v for v in (desc, wtu) if isinstance(v, str))


def load_fixtures(path: Path) -> tuple[list[dict], list[str]]:
    """Return (fixtures, errors). Structural problems are errors, not crashes."""
    if not path.is_file():
        return [], [f"{path}: routing fixtures file is missing"]
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        return [], [f"{path}: malformed YAML ({exc})"]
    if not isinstance(data, dict) or not isinstance(data.get("fixtures"), list):
        return [], [f"{path}: expected a top-level 'fixtures' list"]
    return data["fixtures"], []


def run_checks(root: Path, fixtures_path: Path) -> list[str]:
    fixtures, errors = load_fixtures(fixtures_path)
    if errors:
        return errors

    router_md = root / "rules" / "00-router.md"
    router_text = router_md.read_text(encoding="utf-8").lower() if router_md.is_file() else ""
    if not router_text:
        errors.append(f"{router_md}: router rule is missing or empty")

    if len(fixtures) < MIN_FIXTURES:
        errors.append(
            f"{fixtures_path}: {len(fixtures)} fixture(s), below the "
            f"{MIN_FIXTURES}-fixture floor — routing coverage must not shrink; "
            f"fix or replace fixtures instead of deleting them."
        )

    seen_asks: set[str] = set()
    for idx, fx in enumerate(fixtures):
        where = f"{fixtures_path}: fixtures[{idx}]"
        if not isinstance(fx, dict):
            errors.append(f"{where}: fixture is not a mapping")
            continue
        ask = fx.get("ask")
        skill = fx.get("skill")
        signals = fx.get("signals")
        if not (isinstance(ask, str) and ask.strip()):
            errors.append(f"{where}: missing or empty 'ask'")
            continue
        where = f"{fixtures_path}: '{ask}'"
        if ask.strip().lower() in seen_asks:
            errors.append(f"{where}: duplicate ask")
        seen_asks.add(ask.strip().lower())
        if not (isinstance(skill, str) and skill.strip()):
            errors.append(f"{where}: missing or empty 'skill'")
            continue
        listing = _skill_listing_text(root, skill)
        if listing is None:
            errors.append(f"{where}: skill '{skill}' does not exist under {root / 'skills'}")
            continue
        if not (isinstance(signals, list) and signals):
            errors.append(f"{where}: 'signals' must be a non-empty list")
            continue
        surface = router_text + " " + listing.lower()
        for signal in signals:
            if not (isinstance(signal, str) and signal.strip()):
                errors.append(f"{where}: empty signal")
                continue
            if signal.lower() not in surface:
                errors.append(
                    f"{where}: signal '{signal}' not found in the routing surface "
                    f"(00-router.md + {skill}'s description/when_to_use) — a trim "
                    f"removed the vocabulary this ask routes on. Restore the "
                    f"keyword somewhere always-on, or consciously update the "
                    f"fixture with the replacement vocabulary."
                )
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate steer routing fixtures.")
    parser.add_argument(
        "--plugin-root",
        type=Path,
        default=PLUGIN_ROOT,
        help=f"Path to the plugin root (default: {PLUGIN_ROOT})",
    )
    parser.add_argument(
        "--fixtures",
        type=Path,
        default=FIXTURES,
        help=f"Path to the routing fixtures YAML (default: {FIXTURES})",
    )
    args = parser.parse_args(argv)

    errors = run_checks(args.plugin_root, args.fixtures)
    if errors:
        print(f"check_routing_fixtures: {len(errors)} problem(s) found:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1
    print("check_routing_fixtures: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())

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
- ``SKILL_BODY_MAX_BYTES`` — per-skill ``SKILL.md`` body size, gating the
  **compaction re-attach cap** (see below).

The compaction cap
------------------

An invoked skill's rendered ``SKILL.md`` enters the conversation and stays there
for the rest of the session. When auto-compaction fires, Claude Code re-attaches
the most recent invocation of each skill after the summary but keeps only **the
first 5,000 tokens of each** (re-attached skills also share a combined 25,000
token budget). Everything past that point in the file is silently dropped.

That makes an oversized ``SKILL.md`` a *correctness* problem, not just a cost
one: whatever sits at the tail — historically the Guardrails and Coupling-rules
sections — disappears exactly when a run has gone on long enough to compact,
which is precisely when a long ``/steer:work`` or ``/steer:audit`` still needs
them. Two rules follow, and this gate enforces the second:

1. **Front-load the standing instructions.** Guardrails, coupling rules, and
   output contracts go near the top of ``SKILL.md``, never at the bottom.
2. **Keep the body under the cap.** Push per-mode or per-phase procedure into a
   sibling file under the skill directory (``modes/<mode>.md``,
   ``PROCEDURE.md``, ``OPERATIONS.md``, …) that the dispatcher reads
   just-in-time for the one path it is executing. A file read that way is a tool
   result, not skill content, so it never competes for the re-attach budget.

``SKILL_BODY_MAX_BYTES`` converts the 5,000-token cap into bytes at a
deliberately **pessimistic** 3.5 bytes/token. Measured against ``cl100k_base``
these bodies run ~4.0 B/token, and Claude's tokenizer is denser than
``cl100k_base`` on English prose, so 3.5 leaves margin for the gap between the
two rather than betting the guardrails on a favourable tokenizer. Gating on
bytes also keeps this script dependency-free (no tokenizer at check time).

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
# Re-armed after the Phase 1 pass-2 rules trim (PLAN.md): rules 61,786 bytes
# across 34 files (was 69,335 pre-Phase-1); listing 10,867 chars across 26
# skills (was 17,950). Headroom (~1-5%) absorbs small legitimate edits;
# anything larger must trade prose out first. LOWER these again as further
# reductions land.
#
# RULES raised ONCE, deliberately, from 62,500 → 65,200 to fund rule
# `61-gate-prompts` (answering a human gate in-session). The ratchet had drifted
# to 32 bytes of headroom, so the rule could only be added by compressing
# unrelated gate rules — and that trade deleted ~1 KB of rationale prose that
# existed nowhere else in the repo. Paying bytes was judged the lesser cost than
# losing the prose; the trims were reverted and the ceiling re-armed at the
# measured total (64,492 B across 35 files) plus ~1%.
#
# This is NOT a precedent for growth-on-demand. Unlike SKILL_BODY_MAX_BYTES
# below, this number is policy rather than harness behaviour, so it *can* move —
# which is exactly why it needs a recorded reason each time. The default remains
# "trade prose out first"; raising it again takes the same explicit decision, and
# RULES_TOTAL_TARGET_BYTES deliberately stays at the old 62,500 so the report
# keeps showing the gap as work to reclaim.
#
# RAISED a second time, 65,200 → 65,300, by the pre-release audit fix pass. The
# first raise re-armed at measured+1%, but the polyrepo work landed in the same
# cycle and consumed that headroom down to 7 bytes, so the next correctness fix
# to any always-on rule was guaranteed to breach it. Three such fixes did:
# rule 00 no longer claims `/steer:adopt` and `/steer:sync` invoke `/steer:doctor`
# (they never have), rule 22's root allowlist now admits `scripts/` (which rule 24
# requires and the scaffold installs), and rule 52 cites rule 31 by its real
# heading. Each is a factual correction, not new prose, and the alternative —
# shaving rationale to pay for them — is precisely the trade the note above
# records as wrong and reverted. +100 B is ~0.15%; the target stays 62,500.
#
# RAISED a third time, 65,300 → 66,500, to fund the worktree-trust step in rule
# `24-worktrees` (#416). `mise trust` is path-based, so a worktree created
# mid-session is untrusted and every `mise run …` in it fails on trust rather than
# on the task; steer's SessionStart check inherits that trust for a session
# *started* in a worktree, but a `git worktree add` inside a running session is
# exactly the case no hook can reach, so the instruction has to be always-on to be
# there when it is needed. The ratchet stood at 5 bytes of headroom, so the only
# alternative was trading out rule 24's own rationale — the trade this note has
# twice recorded as wrong. Re-armed at the measured total (65,933 B across 35
# files) plus ~1%, restoring real headroom instead of the 5-to-7-byte margins that
# made each of the last two raises inevitable. The target stays 62,500.
#
# RAISED a fourth time, 66,500 → 67,300, to fund six surface-scoping corrections
# that made always-on rules honest on the surfaces that read them. Rules 00, 05, 97
# promised a SessionStart flag Copilot cannot receive (its `sessionStart` ignores
# stdout) and rule 10 promised a hard `deny` that is only an `ask` on the Copilot
# CLI and absent in VS Code — each was a rule telling an agent a mechanism would
# catch something it will not. Rules 24 and 99 named `docker:up`/`docker:clean`,
# which the workspace profile renamed `ws:*`, so the mandated cleanup command did
# not exist in a spine host; rule 15 now carries the workspace task vocabulary once
# and rule 24 cross-references it rather than restating it, which paid back ~120 B
# of the cost. All six are factual corrections, not new capability: the alternative
# was shaving rationale, the trade this note twice records as wrong and reverted.
# Trimming to fit under 66,500 would have left ~16 B of headroom — precisely the
# margin this note blames for making the last two raises inevitable — so the
# ceiling is re-armed at the total measured when that raise landed (66,516 B) plus
# ~1.2%. That figure is a historical basis, NOT a current measurement — later
# factual corrections have grown the tree past it; run --report for the live number.
# Target: 62,500.
#
# RAISED a fifth time, 67,300 → 68,400, to fund the **Tiny** ceremony exemption in
# rule `80-change-size` and its two consumers. Unlike the fourth raise this is new
# capability, not a correction, so it took the explicit decision this note demands.
# Rule 80 already said a Tiny change (≈<20 lines, no behavior change) could "just
# open a PR", but that was advisory prose with no authority: rule 36's Issue-first
# exemptions were content-typed, never size-typed, and rule 50's Definition of Done
# applied unconditionally — so a typo fix still cost an issue, a branch, a spec
# check and the full DoD sweep. Making the size class actually govern needs three
# always-on statements (the exemption, the authority claim, the size-gated markers)
# and cannot be expressed by cross-reference alone, because the rules being
# exempted are the ones a session reads. Traded out first, as the default here
# requires: rule 32's notable-event enumeration and rule 55's `spec-drift`
# mechanics moved to reference prose, and the per-change `/spec/history/` obligation
# left rules 30, 50, 55 and 99 outright (−136 B) — the same PR that shrinks a
# per-change duty pays part of its own cost. Net +511 B. Re-armed at the measured
# total (67,758 B across 35 files) plus ~1%, keeping real headroom rather than the
# 5-to-16-byte margins this note blames for making earlier raises inevitable.
# Target stays 62,500.
#
# LOWERED for the first time, 68,400 → 67,500 (#443). Every prior move on this
# line was a raise; this is the ratchet finally turning the way it was designed
# to. The trigger was that the fifth raise's ~1% headroom had been consumed back
# down to **178 bytes**, which made the ceiling load-bearing on the *next* rule
# edit of any kind — #446 alone (broadening rule 22 to admit the byte-identical
# absorbed-source delete) costs ~150 B and could not be paid for.
#
# 1,632 B were reclaimed, and every byte of it is duplication removal, not prose
# deletion — each relocation target already carried the full text:
#   - rule 10's mise task-ordering and compose detail → CONVENTIONS.md
#     ("Standard mise tasks", "Declaring task ordering", "Local services");
#   - rule 45's ungraduated-trunk-push mechanics → GATES.md §5, which already
#     owned them (the Copilot-CLI no-retry clause moved there rather than being
#     dropped);
#   - rule 36's `allowed-tools` tiering → ISSUE-WORKFLOW.md "Host gating", which
#     explicitly asks the always-on rule to carry "only a terse, point-of-use
#     reminder … never a second normative copy";
#   - rules 50 and 99 stopped restating each other's checklist items, and rule 24
#     dropped rationale for an instruction that is unconditional anyway.
# No rule lost an imperative, so this is not the "shave rationale to pay for an
# edit" trade the notes above twice record as wrong and reverted.
#
# The ceiling comes down by 900 B — deliberately LESS than the 1,632 B reclaimed,
# so headroom grows from 178 B to ~910 B (5x) in the same change that tightens the
# ratchet. Re-arming at measured+1% would have restored the ~660-byte margin that
# made raises two, three and four inevitable; the whole lesson of this comment
# block is that a tight ceiling dictates the wording of correctness fixes instead
# of bounding their cost. Target stays 62,500 — still 4,090 B of standing
# invitation.
RULES_TOTAL_MAX_BYTES = 67_500
# LISTING re-baselined ONCE, 11,500 → 11,900, because the old number was never an
# honest measurement. `work`'s `when_to_use` was an unquoted YAML scalar
# containing `("work on #123"`, so ` #` opened a comment and the value silently
# truncated at 75 of 546 chars — discarding every `--reviewed` and `--hotfix`
# trigger phrase. The ratchet had been calibrated against that truncated value,
# so it read 22 chars of headroom while the *intended* payload was ~450 chars
# over. Fixing the YAML (now a `>-` block, as 19 of 26 skills already use)
# necessarily exposes the real total.
#
# Per this file's own policy the fix paid what it could first: `work`'s entry was
# trimmed 932 → 747 chars by dropping a duplicate issue example, a third hotfix
# synonym, and a step enumeration the body carries in full — every distinct
# trigger phrase is retained. Deliberately NOT funded by compressing unrelated
# skills; that is the trade the RULES note above records as the wrong one.
#
# RAISED a second time, 11,900 → 12,400, as a deliberate re-arming of the ratchet
# rather than to fund any specific edit. The re-baseline above landed at 11,879 of
# 11,900 — **21 chars** — so the very next factual correction to any `description`
# or `when_to_use` could not be paid for in place. The five-round pre-release audit
# (#423) hit exactly that: its three description corrections had to be engineered
# as a *length-neutral* set, which is the ratchet dictating the wording of a
# correctness fix instead of merely bounding its cost. That is the failure mode the
# RULES notes above record five times over. Raises 2-4 were forced by the
# 5-to-32-byte margin the previous ceiling left; the first and fifth were deliberate
# decisions to fund new always-on capability (rule `61-gate-prompts`, then the Tiny
# exemption) against a ratchet with nothing to spare. Re-arming at measured+1% would
# reproduce it a sixth time.
#
# The basis for 12,400: the mean per-skill listing entry is ~457 chars
# (11,879 / 26), so 12,400 buys ~521 chars — one whole additional skill, or roughly
# eight to ten factual corrections, before the ceiling is load-bearing again. That
# is the smallest headroom under which "trade prose out first" stays a real policy
# choice rather than the only physically available move.
#
# This does NOT relax the policy. Trading prose out remains the default and the
# per-skill 1536-char cap in `check_plugin.py` is untouched, so no single skill can
# consume the new headroom alone. LISTING_TOTAL_TARGET_CHARS deliberately stays at
# 10,000: the widened gap is the standing invitation to reclaim it, and the report
# keeps showing it as work outstanding.
#
# HELD at 12,400 by #443, which reclaimed 244 chars (`reference` stopped
# parenthesising each topic its own `when_to_use` already explains; `work`, `spec`
# and `intake` dropped restatement, no trigger phrase lost) and took headroom from
# 190 back to ~434. Not ratcheted down, on this block's own stated basis: 12,400
# was chosen to buy ~521 chars — "one whole additional skill" — and any lowering
# from the current 11,966 leaves less than that. Reclaim more first, then the
# ceiling can move.
LISTING_TOTAL_MAX_CHARS = 12_400

# --- Compaction re-attach cap (hard gate, per skill) -------------------------
# 5,000 tokens at a pessimistic 3.5 bytes/token (see the module docstring). This
# is a real ceiling, not a ratchet: it is derived from Claude Code's documented
# re-attach behaviour, so it does NOT move down as bodies shrink and must not be
# raised to fit new prose. A skill that outgrows it factors procedure into a
# sibling file read just-in-time — that is the fix, every time.
SKILL_BODY_MAX_BYTES = 17_500

# --- Aspirational targets (reported, never enforced here) --------------------
# PLAN.md Phase 1 closed with the original 30K rules target retired: after two
# trim passes the surviving prose is imperative-dense, and rule demotion was
# investigated and rejected (see PLAN.md Phase 1 close-out). The rules target is
# held at the pre-61-gate-prompts ratchet, BELOW the current ceiling on purpose:
# the gap is the standing invitation to reclaim those bytes (relocating rationale
# into templates/reference/*, or demoting a rule to conditional hook delivery the
# way polyrepo was). The listing target stands.
RULES_TOTAL_TARGET_BYTES = 62_500
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
    bodies: list[tuple[str, int]] = []
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
            bodies.append((skill_dir.name, skill_md.stat().st_size))

    return {
        "rules_files": len(rules),
        "rules_bytes": rules_bytes,
        "skills": skills,
        "listing_chars": listing_chars,
        "bodies": bodies,
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
    for name, size in sorted(stats["bodies"]):
        if size > SKILL_BODY_MAX_BYTES:
            errors.append(
                f"{root / 'skills' / name / 'SKILL.md'}: body is {size:,} bytes, over the "
                f"{SKILL_BODY_MAX_BYTES:,}-byte compaction cap (~5,000 tokens). After "
                f"auto-compaction Claude Code re-attaches only the FIRST 5,000 tokens of "
                f"an invoked skill, so everything past that point is silently dropped "
                f"mid-run. Factor per-mode or per-phase procedure into a sibling file "
                f"under skills/{name}/ that the dispatcher reads just-in-time, and keep "
                f"guardrails / coupling rules near the TOP of SKILL.md. Do not raise this "
                f"ceiling — it is derived from Claude Code behaviour, not from a budget."
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
    ]
    biggest = max((s for _, s in stats["bodies"]), default=0)
    lines.append(
        f"| largest SKILL.md body ({len(stats['bodies'])} skills) "
        f"| {biggest:,} B | {SKILL_BODY_MAX_BYTES:,} B | — |"
    )
    lines += ["", "Top skill-listing consumers:"]
    for name, chars in sorted(stats["skills"], key=lambda s: -s[1])[:5]:
        lines.append(f"- {name}: {chars:,} chars")
    lines += ["", "Largest skill bodies (compaction cap):"]
    for name, size in sorted(stats["bodies"], key=lambda s: -s[1])[:5]:
        pct = round(100 * size / SKILL_BODY_MAX_BYTES)
        lines.append(f"- {name}: {size:,} B ({pct}% of cap)")
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

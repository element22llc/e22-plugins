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

- ``INJECTED_PROFILES`` — the **injected payload**, in tokens, for each shape of
  consumer repo. Measured by running the shipped ``inject-standards.sh`` against
  a throwaway fixture, so it is what a session truly receives (see below);
- ``LISTING_TOTAL_MAX_CHARS`` — total ``description`` + ``when_to_use``
  characters across all skills (the always-on routing surface). The *per-skill*
  1536-char cap lives in ``check_plugin.py``; this is the cross-skill sum.
- ``SKILL_BODY_MAX_BYTES`` — per-skill ``SKILL.md`` body size, gating the
  **compaction re-attach cap** (see below).

Why the injected payload, not the on-disk total
-----------------------------------------------

Until the injected-payload re-base this gate summed ``rules/*.md`` **on disk**.
That number is not paid by anybody. Rules carrying a
``<!-- steer:inject-when=… -->`` marker are injected
only where the scope holds, so the payload differs per consumer, and the spread
is not marginal — measured at the re-base, a knowledge-work folder received
26,820 B where the on-disk total was 67,510 B.

The consequence was worse than an inaccurate number. Scoping a rule from
always-on to ``code-project`` is the single most effective way to cut real
always-on weight, and it moved the gated total by **exactly zero** — the one
lever that reduces the cost earned no credit from the gate that exists to reduce
the cost. Meanwhile the on-disk ceiling moved seven times in its life for a net
+9.1% (that history is preserved verbatim below, because it is the evidence for
this change).

Gating the injected payload fixes both. It also buys a regression the on-disk
sum could never see: **dropping a rule's ``inject-when`` marker** — which pushes
that rule onto every knowledge-work session — now shows up immediately, as
growth in the ``knowledge`` profile.

Tokens, not bytes: the ceilings are expressed in tokens so they can be read
against a context window, which is the question anyone actually has about this
surface. Conversion uses the same deliberately pessimistic 3.5 bytes/token this
file already applies to ``SKILL_BODY_MAX_BYTES`` — measured against
``cl100k_base`` these rules run ~4.0 B/token, so 3.5 over-reports the cost and
keeps the gate conservative without adding a tokenizer dependency.

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
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import yaml

PLUGIN_ROOT = Path("plugins/steer")

# --- Injected-payload profiles (hard gate) -----------------------------------
# Reuse, not reimplementation. Each profile builds a throwaway fixture repo and
# runs the REAL hooks/inject-standards.sh against it, exactly as
# scripts/rules-preview.sh does — so the measured payload cannot drift from what
# a session receives, and the scope predicates in hooks/lib/scope.sh stay the
# single source of truth. Nothing is written to any real repo.
#
# `builder` receives the fixture directory and prepares whatever markers that
# profile's scope predicates look for (see hooks/lib/scope.sh).
BYTES_PER_TOKEN = 3.5


def _fixture_knowledge(_d: Path) -> None:
    """A non-code folder: no git, no manifests. steer_work_mode → 'knowledge'."""


def _fixture_code(d: Path) -> None:
    """A plain code repo: git work tree, no IaC, no apps/, no GitHub tracker."""
    _git_init(d)


def _fixture_code_max(d: Path) -> None:
    """The heaviest consumer: every scope predicate satisfied, so every rule injects."""
    _git_init(d)
    (d / "infra").mkdir()  # has-iac, has-infra
    (d / "apps").mkdir()  # has-apps
    (d / "spec").mkdir()
    (d / "spec" / "tracker.md").write_text("system: github\n", encoding="utf-8")  # tracker-github


# Ceilings are sized to buy roughly ONE whole additional rule (the mean rule is
# ~1,875 B ≈ 536 tokens), on the same basis LISTING_TOTAL_MAX_CHARS states below:
# the smallest headroom under which "trade prose out first" stays a real policy
# choice rather than the only physically available move. The whole lesson of the
# retired-ratchet history below is that a 5-to-32-byte margin makes the ceiling
# dictate the *wording* of correctness fixes instead of bounding their cost.
#
# Only two profiles are GATED. `code` sits strictly between them — un-scoping a
# rule grows `knowledge`, and new prose grows `code-max` — so gating it too would
# add a third ceiling to bump without catching anything the other two miss. It is
# measured and reported because it is the number to quote for a typical consumer.
INJECTED_PROFILES: dict[str, dict] = {
    # The leanness lane, and the un-scoping detector: an always-on rule added
    # without an `inject-when` marker lands here first and hardest.
    "knowledge": {
        "builder": _fixture_knowledge,
        "max_tokens": 8_200,
        "target_tokens": 7_100,
        "gated": True,
        "blurb": "non-code folder (Cowork PO lane)",
    },
    # Reported, not gated — bounded by the two above. See the note above.
    "code": {
        "builder": _fixture_code,
        "max_tokens": None,
        "target_tokens": 16_100,
        "gated": False,
        "blurb": "typical product repo",
    },
    # The absolute worst case any consumer pays: every scope predicate true.
    "code-max": {
        "builder": _fixture_code_max,
        "max_tokens": 19_700,
        "target_tokens": 17_700,
        "gated": True,
        "blurb": "every scope predicate satisfied",
    },
}


def _git_init(d: Path) -> None:
    subprocess.run(
        ["git", "-c", "init.defaultBranch=main", "init", "-q", str(d)],
        check=True,
        capture_output=True,
    )


def measure_injected(root: Path, profile: str) -> int:
    """Bytes the shipped SessionStart hook emits for one consumer profile.

    Raises RuntimeError rather than guessing: a budget gate that cannot measure
    must fail loudly, never fail open.
    """
    hook = root / "hooks" / "inject-standards.sh"
    if not hook.is_file():
        raise RuntimeError(f"{hook}: injection hook not found")
    if shutil.which("git") is None:
        raise RuntimeError("git not on PATH — cannot build the fixture repos this gate measures")

    with tempfile.TemporaryDirectory(prefix="steer-budget-") as tmp:
        fixture = Path(tmp) / profile
        fixture.mkdir()
        INJECTED_PROFILES[profile]["builder"](fixture)
        payload = (
            f'{{"session_id":"budget-gate","cwd":"{fixture}","hook_event_name":"SessionStart"}}'
        )
        env = {**os.environ, "CLAUDE_PLUGIN_ROOT": str(root.resolve())}
        proc = subprocess.run(
            ["sh", str(hook)],
            input=payload,
            capture_output=True,
            text=True,
            env=env,
        )
    if proc.returncode != 0:
        raise RuntimeError(f"inject-standards.sh failed for profile '{profile}': {proc.stderr}")
    return len(proc.stdout.encode("utf-8"))


def tokens(byte_count: int) -> int:
    """Pessimistic byte→token conversion. See the module docstring."""
    return int(byte_count / BYTES_PER_TOKEN)


# --- RETIRED: the on-disk byte ratchet (history, not a gate) -----------------
# Superseded by INJECTED_PROFILES above (the injected-payload re-base). Kept in
# full, deliberately: it is the evidence for that change, and per its own note
# it is the ONE place
# recording the per-rule trim attribution — do not restate it in CHANGELOG.md or
# docs/, and do not delete it to tidy the file.
#
# Read as a whole it documents a mechanism failing in a specific, legible way.
# The ceiling moved SEVEN times — 62,500 → 65,200 → 65,300 → 66,500 → 67,300 →
# 68,400 → 67,500 → 68,200, a net +9.1% — while RULES_TOTAL_TARGET_BYTES never
# moved off 62,500 and was never met. The block names its own failure mode ("a
# tight ceiling dictates the wording of a correctness fix instead of bounding its
# cost") five separate times, and then reproduces it a sixth for a 17-byte
# carve-out against a 7-byte margin. Every raise was argued honestly and every
# raise still happened, which is what tells you the number was wrong rather than
# the authors undisciplined: it was gating a payload nobody receives, so it could
# not be paid down by the one move that actually reduces always-on weight.
#
# What survives the retirement: the *policy* is unchanged. Trade prose out into
# templates/reference/* first; a ceiling move is a deliberate, recorded decision;
# and the targets below stay under the ceilings as the standing invitation to
# reclaim. Only the measured variable changed.
#
# ----- history begins -----
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
# requires: rule 55's `spec-drift` mechanics moved to reference prose, and the
# per-change `/spec/history/` obligation left rules 30, 55 and 99 outright
# (−136 B) — the same PR that shrinks a
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
# absorbed-source delete) was projected at ~150 B and could not be paid for. It
# landed at **360 B**, so the projection that justified the size of this move was
# itself 2.4x light — a reason to keep the reclaim ahead of the ceiling, not to
# trust the estimate.
#
# 1,632 B were reclaimed across nine rules — 00, 10, 24, 30, 36, 45, 50, 62, 99.
# Per-rule, as measured (this is the ONE place that records the attribution; do not
# restate it in CHANGELOG.md or docs/, where two attempts already went wrong):
#   - 00 (-87) and 30 (-106): reworded in place, nothing relocated;
#   - 10 (-167): the one-way-delegation definition and polyglot-Python example →
#     CONVENTIONS.md ("Standard mise tasks"), which already held both. Rule 10
#     KEEPS its own `depends`/`depends_post` ordering imperative;
#   - 24 (-134): dropped rationale for an instruction that is unconditional
#     anyway — prose deletion, not duplication removal;
#   - 36 (-254): the `allowed-tools` tiering → ISSUE-WORKFLOW.md "Host gating",
#     which asks the rule for "only a terse, point-of-use reminder … never a
#     second normative copy". The destination did NOT hold the tiering at trim
#     time — the block was added by dffdde7 and refined by 8d639fc/8fadb86 later
#     in this same release, so this is a move to a target that only later caught
#     up, not a de-duplication;
#   - 45 (-188): GATES.md §5 already owned the ungraduated-trunk-push mechanics;
#     the only text ADDED there was the Copilot-CLI no-retry clause;
#   - 50 (-298) and 99 (-280): stopped restating each other's checklist items;
#   - 62 (-118): the Claude-Code-specific branch-prefix clause. hotfix.md states
#     that the reconciliation hook keys on the prefix, but the "other surfaces
#     carry it by convention" half is simply gone.
#
# One imperative DID leave the always-on rules: rule 45's "don't retry a declined
# push — graduate instead" is in no rules/*.md. It survives in GATES.md §5 AND in
# check-bash-actions.sh's repeat-reminder text, so a Claude session still meets it
# at the moment it matters; on the Copilot CLI, where that repeat is a silent
# allow, it is on-demand only. A deliberate trade, but it means "no rule lost an
# imperative" is too strong a claim to repeat. Otherwise this is not the "shave
# rationale to pay for an edit" trade the notes above twice record as wrong and
# reverted.
#
# The ceiling comes down by 900 B — deliberately LESS than the 1,632 B reclaimed,
# so headroom grew from 178 B to ~910 B (5x) in the same change that tightens the
# ratchet. Rule 22's correction then spent 360 B of that. Do not pin the current
# total in this comment — `--report` is the only honest source for it, and a pinned
# figure goes stale on the next rule edit (it already did once). Re-arming at
# measured+1% would have restored a ~660-byte margin;
# the whole lesson of this comment block is that a tight ceiling dictates the
# wording of correctness fixes instead of bounding their cost. Target stays
# 62,500.
#
# SPENT, not moved: rule `92-user-facing-copy` then consumed most of what that
# lowering had just restored, leaving the ceiling load-bearing again — the condition
# the lowering existed to end. Run `--report` for the live figure; per the paragraph
# above, it is not pinned here.
#
# RE-ARMED, 67,500 → 68,200, closing the choice the paragraph above left open — and
# closing it the way this comment block predicted it would have to be closed. The
# 5.3.0 pre-release audit found rule 92's `spec/**` clause reading as a ban on the
# `spec/glossary.md` cross-link that `templates/spec/app-docs.md` itself ships, and
# the carve-out that fixes it cost 17 B against a 7 B margin. The content-preserving
# wording did not fit; the wording that fit dropped "for the user", the rule's whole
# contrast. That is verbatim the failure mode line 203 names — a tight ceiling
# dictating the wording of a correctness fix instead of bounding its cost — so the
# ceiling moved and the fix kept its words. Sized at measured+1% per line 201, which
# restores a ~690 B margin. NOT a licence to spend it: the reclaim half of the
# choice is still owed, and the 62,500 target is what it is owed against. Target
# stays 62,500.
# ----- history ends -----
# The last value the retired ratchet held. Reported for continuity with the
# release notes that cite it; NOT enforced. The live ceilings are per-profile in
# INJECTED_PROFILES.
RULES_ONDISK_LAST_CEILING = 68_200
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
# HELD at 12,400 by #443, which reclaimed 232 chars (`reference` stopped
# parenthesising each topic its own `when_to_use` already explains; `work`, `spec`
# and `intake` dropped restatement) and took headroom from 190 back to ~422. Seven
# literal subtopic tokens did go with it — `commit style`, `spec routing`,
# `audit evidence`, `subagents`, `durable state`, `Mermaid`, `LikeC4` — and they
# survive nowhere else in the measured surface; the topics remain reachable via
# `reference`'s eight doc-name arguments, but do not claim "no trigger phrase
# lost". Not ratcheted down, on this block's own stated basis: 12,400 was chosen
# to buy ~521 chars — "one whole additional skill" — and any lowering from the
# current 11,978 leaves less than that. Reclaim more first, then the ceiling can
# move.
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
#
# The rules target is now carried per-profile as `target_tokens` in
# INJECTED_PROFILES; the on-disk figure below is kept only so the report can keep
# showing the authoring surface next to the payload that is actually gated.
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

    injected: dict[str, dict] = {}
    for name, spec in INJECTED_PROFILES.items():
        payload_bytes = measure_injected(root, name)
        injected[name] = {
            "bytes": payload_bytes,
            "tokens": tokens(payload_bytes),
            "max_tokens": spec["max_tokens"],
            "target_tokens": spec["target_tokens"],
            "gated": spec["gated"],
            "blurb": spec["blurb"],
        }

    return {
        "rules_files": len(rules),
        "rules_bytes": rules_bytes,
        "injected": injected,
        "skills": skills,
        "listing_chars": listing_chars,
        "bodies": bodies,
    }


def run_checks(root: Path) -> list[str]:
    errors: list[str] = []
    if not root.is_dir():
        return [f"{root}: plugin root directory not found"]
    try:
        stats = measure(root)
    except RuntimeError as exc:
        # Fail loudly. A budget gate that cannot measure must never pass.
        return [f"could not measure the injected payload: {exc}"]

    for name, got in stats["injected"].items():
        ceiling = got["max_tokens"]
        if ceiling is None or got["tokens"] <= ceiling:
            continue
        hint = (
            "an always-on rule (one with no `inject-when` marker) is the usual cause — "
            "scope it to the repos that need it, or trade prose out"
            if name == "knowledge"
            else "move prose to templates/reference/* (surfaced via /steer:reference) "
            "and keep rules imperative"
        )
        errors.append(
            f"{root / 'rules'}: the '{name}' profile ({got['blurb']}) receives "
            f"~{got['tokens']:,} tokens ({got['bytes']:,} B), over its "
            f"{ceiling:,}-token ceiling. This is the payload a session actually gets "
            f"from inject-standards.sh, not the on-disk total — {hint}. Run "
            f"`mise run rules:preview` to see which rules inject and why. Do not "
            f"raise the ceiling to fit new prose; if a raise is genuinely right, "
            f"record the reason beside the constant (see the retired-ratchet history "
            f"in this file for what happens when that discipline slips)."
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
    ]
    for name, got in stats["injected"].items():
        ceiling = f"{got['max_tokens']:,} tok" if got["max_tokens"] is not None else "— (not gated)"
        lines.append(
            f"| injected payload — {name} ({got['blurb']}) "
            f"| {got['tokens']:,} tok / {got['bytes']:,} B | {ceiling} "
            f"| {got['target_tokens']:,} tok |"
        )
    lines += [
        (
            f"| rules/*.md on disk ({stats['rules_files']} files, authoring surface) "
            f"| {stats['rules_bytes']:,} B | not gated "
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

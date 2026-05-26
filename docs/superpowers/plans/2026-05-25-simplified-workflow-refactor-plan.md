# Simplified Workflow Refactor — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the `e22-plugins` marketplace from the v0.3 two-lane model to the v0.4 three-zone model — POs get one always-on org plugin and natural-language affordances; engineering keeps full governance, applied only in governed-production zones.

**Architecture:** A new top-level `e22-org` plugin provides always-loaded `CLAUDE.md`, sandbox guardrails, the natural-language handoff trigger, and a shared `lib/zone.sh` zone-detector. Hook plugins (`always-test`, `spine-writer`, `house-style`) source `zone.sh` and self-gate to governed zones. `handoff-packager` is rewritten to a single-file `HANDOFF.md` per spec v0.4 §7.3. `production-lane`'s `/validate` decision matrix changes to Harden / Extract / Rewrite / Reject / Continue exploring. `prototype-lane` and `spec-driven-dev` are deleted. Marketplace shrinks 8 → 7.

**Tech Stack:** Claude Code plugin marketplace; bash hooks; markdown skills and commands; JSON manifests; `git`, `grep`, `find` for verification.

**Spec:** [`docs/superpowers/specs/2026-05-25-simplified-workflow-refactor-design.md`](../specs/2026-05-25-simplified-workflow-refactor-design.md) (commit `1208d4a`).

**Branch:** Continue on `feat/simplify-workflow` (already checked out). Do not branch further. One commit per task.

**Working directory:** All paths in this plan are relative to `/Users/alexis-valotaire/Documents/00_Work/TLM/01_Projects/Element_22/e22-plugins/` unless otherwise stated.

---

## Task 1: Create the `e22-org` plugin skeleton

**Files:**
- Create: `plugins/e22-org/.claude-plugin/plugin.json`
- Create: `plugins/e22-org/lib/zone.sh`
- Create: `plugins/e22-org/templates/HANDOFF.md.template`

This is the load-bearing task. Every later hook-gate task sources `zone.sh`, so this lands first.

- [ ] **Step 1: Make the directory layout**

```bash
mkdir -p plugins/e22-org/.claude-plugin \
         plugins/e22-org/hooks \
         plugins/e22-org/lib \
         plugins/e22-org/templates
```

- [ ] **Step 2: Write the plugin manifest**

File: `plugins/e22-org/.claude-plugin/plugin.json`

```json
{
  "name": "e22-org",
  "version": "0.1.0",
  "description": "Element 22 organization plugin — the PO's single required installation. Always-loaded CLAUDE.md with sandbox guardrails, natural-language handoff trigger, production-boundary reminders, tech-stack pointer. Ships hooks where the surface supports them (Claude Code) and instructions where it does not (Claude Chat, Cowork, Artifacts). Provides plugins/e22-org/lib/zone.sh, the shared zone-detection helper that other plugins source to gate their behavior.",
  "author": {
    "name": "Element 22 Platform",
    "email": "alexis.valotaire@element-22.com"
  },
  "homepage": "https://github.com/element22llc/e22-plugins/tree/main/plugins/e22-org",
  "license": "UNLICENSED",
  "keywords": ["element-22", "always-on", "claude-chat", "claude-cowork", "claude-code", "hooks-claude-code-only", "org-plugin", "sandbox", "handoff", "zone-detection"]
}
```

- [ ] **Step 3: Write the shared zone-detection helper**

File: `plugins/e22-org/lib/zone.sh`

```bash
#!/usr/bin/env bash
# e22-org: shared zone-detection helper. Sourced by every plugin that needs to
# behave differently in a local MVP sandbox vs a governed-production repo.
#
# Definitions:
#   - governed: the workspace is a git repo whose origin remote points at GitHub.
#   - sandbox:  anything else.
#
# Per spec v0.4 §11.3, governance applies where it earns its keep. The GitHub
# remote is the simplest robust signal that the work has entered the governed
# zone — Dev has imported into a repo with PR/CI/review available.

e22_zone() {
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
       && git remote get-url origin 2>/dev/null | grep -qi 'github\.com'; then
    echo governed
  else
    echo sandbox
  fi
}

# Convenience guard for hook scripts. Sources this file and exits early if not
# governed. Usage from a hook:
#
#   source "${CLAUDE_PLUGIN_ROOT}/../e22-org/lib/zone.sh"
#   e22_require_governed || exit 0
e22_require_governed() {
  [[ "$(e22_zone)" == "governed" ]]
}
```

- [ ] **Step 4: Write the HANDOFF.md template (v0.4 §7.3, verbatim)**

File: `plugins/e22-org/templates/HANDOFF.md.template`

```markdown
# MVP Handoff — <working title>

## 1. Product intent
<user problem, target users, desired outcome, success criteria>

## 2. Prototype behavior
<what the MVP currently does, including main flows and important screens>

## 3. UX decisions
<copy, layout, interaction, workflow, and variant decisions made during exploration>

## 4. Demo evidence
<links or references to screenshots, recordings, local preview notes, or artifacts>

## 5. Files and dependencies
<important files, libraries, tools, generated assets, and external packages>

## 6. Data model implications
<entities, fields, relationships, persistence assumptions, fake data used>

## 7. External service implications
<auth, payments, email, maps, AI APIs, storage, queues, or other integrations implied>

## 8. Security, privacy, and compliance risks
<PII, auth, permissions, billing, secrets, abuse vectors, retention, audit concerns>

## 9. Known shortcuts and hacks
<prototype shortcuts, hardcoded values, mock services, fake users, fragile paths>

## 10. What must not be reused
<anything that would be unsafe or irresponsible to carry into production>

## 11. Manual test notes
<what was tried manually, what worked, what failed, known bugs>

## 12. Suggested production tests
<unit, integration, E2E, accessibility, security, and regression tests Dev should add>

## 13. Open product questions
<decisions the PO or team still needs to make>

## 14. Suggested Dev decision
Harden / Extract / Rewrite / Reject / Continue exploring

## 15. Rationale
<why Claude recommends that decision>
```

- [ ] **Step 5: Verify file structure**

Run:

```bash
ls -la plugins/e22-org/.claude-plugin/ plugins/e22-org/lib/ plugins/e22-org/templates/
bash -n plugins/e22-org/lib/zone.sh
```

Expected: all four files exist; `bash -n` exits 0 with no output (syntax OK).

- [ ] **Step 6: Smoke-test the zone detector in both zones**

Run from the repo root (which IS a git repo with a GitHub remote → governed):

```bash
bash -c 'source plugins/e22-org/lib/zone.sh; e22_zone'
```

Expected: `governed`.

Then run from a tmp dir (no git):

```bash
( cd /tmp && bash -c 'source '"$(pwd -P)"'/plugins/e22-org/lib/zone.sh; e22_zone' )
```

Wait — that subshell won't work cleanly. Use this instead:

```bash
SCRIPT="$(pwd -P)/plugins/e22-org/lib/zone.sh"
( cd /tmp && bash -c "source '$SCRIPT'; e22_zone" )
```

Expected: `sandbox`.

- [ ] **Step 7: Commit**

```bash
git add plugins/e22-org/
git commit -m "$(cat <<'EOF'
e22-org: add plugin skeleton, zone detector, HANDOFF template

Creates the new always-on organization plugin with:
- plugin.json (v0.1.0)
- lib/zone.sh — shared zone detector (governed vs sandbox) sourced by
  every other plugin that needs to gate behavior on zone
- templates/HANDOFF.md.template — spec v0.4 §7.3 verbatim, 15 sections

CLAUDE.md and hooks come in follow-up tasks (see implementation plan).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Write `e22-org/CLAUDE.md` (always-loaded baseline)

**Files:**
- Create: `plugins/e22-org/CLAUDE.md`

- [ ] **Step 1: Write the file**

File: `plugins/e22-org/CLAUDE.md`

```markdown
# e22-org — always-loaded baseline

Element 22's organization plugin. Loaded into every Claude session for users on
any surface (Claude Code, Claude Chat, Claude Cowork, Claude Artifacts). Defines
the three-zone model, the natural-language affordances POs can use, the handoff
trigger, and the production-boundary reminders.

The repo-level baseline is [`CONSTITUTION.md`](../../CONSTITUTION.md). The full
spec is [`docs/collaborative-ai-workflow-spec.md`](../../docs/collaborative-ai-workflow-spec.md).
When this file and the spec disagree, the spec wins.

## The workflow in one line

> Let the PO explore locally. Let Claude extract the meaning. Let engineering
> decide what becomes production.

## The three zones

| Zone | Owner | Tooling | Control point |
|---|---|---|---|
| **Local MVP Sandbox** | PO | Claude, local folders, disposable previews | Always-on org plugin guardrails |
| **Handoff / Extraction** | Claude + Dev | `HANDOFF.md`, assets, optional source export | Dev reviews meaning before code |
| **Governed Production** | Dev | GitHub, PRs, branch protection, CI/CD, review rules | Checks, approvals, rollback |

Zone detection is implemented in `plugins/e22-org/lib/zone.sh`. A workspace is
**governed** when it's a git repo with an `origin` remote pointing at GitHub.
Everything else is **sandbox**. Other plugins source this helper and self-gate.

## Plain-language affordances

POs do not need to remember commands. They can say things like:

- "Build an MVP for this idea."
- "Try a different checkout flow."
- "Make this more useful for dispatchers."
- "Show me three variants of the landing page."
- "Use fake data — this is exploratory."
- "Handoff this to engineering." (see §Handoff trigger below)

## Handoff trigger

When the user's message expresses intent to hand off the prototype to
engineering, generate `HANDOFF.md` at the workspace root from the template at
`plugins/e22-org/templates/HANDOFF.md.template`. Trigger phrases include (but
are not limited to):

- "handoff this" / "hand this off"
- "package this for dev" / "package this up for engineering"
- "I'm done with the MVP"
- "turn this into a dev brief"
- "extract the spec"
- "ready for engineering review"

When triggered:

1. Copy `HANDOFF.md.template` to `HANDOFF.md` at the workspace root (NOT under
   `proposals/<slug>/`).
2. Fill all 15 sections from the conversation history and the workspace
   evidence (files, assets, notes).
3. Sections 8 (Security/privacy/compliance risks), 9 (Known shortcuts and hacks),
   10 (What must not be reused), 12 (Suggested production tests), and 13 (Open
   product questions) are **MANDATORY**. They must not be left blank.
4. If you have no evidence for a section's contents, write `No evidence
   collected during this session.` rather than fabricating content.
5. Section 14 must contain a single suggested Dev decision (Harden / Extract /
   Rewrite / Reject / Continue exploring). Section 15 must give the rationale
   in 2-5 sentences.
6. Once written, report to the user with the absolute path to `HANDOFF.md` and
   a one-line summary of what Dev will see.

If `handoff-packager` is also installed, its `CLAUDE.md` carries detailed
guidance for how to populate each section from chat + workspace evidence.

## Sandbox guardrails (instructions)

The Local MVP Sandbox is for exploration with fake inputs. In any zone:

- **Use fake data by default.** Synthetic users, synthetic transactions,
  synthetic events. Never copy real production records into the workspace.
- **Refuse real secrets, credentials, or production database connection
  strings.** If the user pastes any, replace with a placeholder and explain.
- **Refuse real PII patterns** — SSN-shaped strings, real credit-card numbers,
  real IBANs. Treat these as production data even in conversation.
- **Refuse live auth, payment, billing, or permissions integrations.** Stub
  them out. The sandbox is for shape; production is for integration.
- **Label shortcuts as they appear.** "Mock auth — replace before production."
  "Hardcoded admin user for the demo." This is what populates section 9 of
  the handoff packet.

## Production-boundary reminders

Once the work is imported into a governed repo (zone flips to `governed`):

- **No direct pushes to `main`.** Every change goes through a PR.
- **CI must pass before merge.** Tests, lint, security scans, secret scanning.
- **Sensitive areas** (auth, payments, billing, PII, permissions, data model,
  production data handling, security boundaries, infrastructure, environment
  configuration, secrets) **require explicit engineering review.**
- **Infrastructure changes** (cloud, IAM, networking, Kubernetes, production
  DB migrations, cost-impacting resources) require explicit human approval.
- **Deployments need a rollback path.** Risky changes ship behind a feature
  flag or equivalent rollout control.

## Tech stack pointer

Before generating code in any zone, read [`TECH-STACK.md`](../../TECH-STACK.md)
for the team's preferred languages and tooling. When adding a dependency:

- Prefer the latest stable version.
- If `context7` is installed, defer to it for current API and version docs.
- Read the nearest manifest (`package.json`, `pyproject.toml`, `Cargo.toml`,
  `go.mod`, `mise.toml`) for authoritative version pins.
- If a manifest is missing or the stack is unclear, ask — do not guess.

Detailed conventions are in `house-style`'s own `CLAUDE.md` (loaded when that
plugin is installed).

## Non-negotiable boundaries

These rules hold in every zone, on every surface:

1. Local MVP sandboxes do not deploy directly to production.
2. Local MVP sandboxes do not use production credentials or production databases.
3. Local MVP sandboxes do not use real customer data or real PII.
4. Live auth, payment, billing, and permission integrations are forbidden in
   sandbox exploration.
5. Prototype code is disposable unless Dev explicitly accepts ownership.
6. Handoff artifacts (`HANDOFF.md`) are durable memory for the transition; chat
   history is not canonical.
7. Prototype shortcuts must be explicitly labeled in `HANDOFF.md` section 9.
8. Production work uses GitHub PR governance.
9. No direct pushes to `main`.
10. Secrets must never be committed or pasted into specs, chats, PRs, or
    handoff files. Reference them via the product's secret-store variable
    names only.
11. Sensitive production changes require explicit engineering review.
12. Infrastructure and environment-configuration changes require explicit
    human approval before modification.

## Surface notes

Hooks are hard controls only where the Claude surface supports them (Claude
Code today). In Claude Chat, Cowork, and Artifacts, the same rules apply as
instructions and reminders in this file. That asymmetry is acceptable because
the sandbox cannot deploy to production, use real customer data, or access
production credentials.
```

- [ ] **Step 2: Verify the file is well-formed markdown**

Run:

```bash
wc -l plugins/e22-org/CLAUDE.md
grep -c '^##' plugins/e22-org/CLAUDE.md
```

Expected: line count between 120 and 180; at least 8 section headers (`##`).

- [ ] **Step 3: Verify the handoff trigger phrases appear**

```bash
grep -ciE '"handoff this"|"package this for dev"|"extract the spec"' plugins/e22-org/CLAUDE.md
```

Expected: at least 3 matches.

- [ ] **Step 4: Commit**

```bash
git add plugins/e22-org/CLAUDE.md
git commit -m "$(cat <<'EOF'
e22-org: add always-loaded CLAUDE.md with handoff trigger

Plain-language affordances, the three-zone model, the natural-language
handoff trigger and its mandatory sections (8/9/10/12/13), sandbox
guardrails as instructions, production-boundary reminders, and the
tech-stack pointer.

Per spec v0.4 §5.1, the handoff trigger fires on natural language and
generates HANDOFF.md at the workspace root — no slash command required.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Implement `e22-org` hooks

**Files:**
- Create: `plugins/e22-org/hooks/hooks.json`
- Create: `plugins/e22-org/hooks/sandbox-guardrails.sh`
- Create: `plugins/e22-org/hooks/handoff-cue.sh`

- [ ] **Step 1: Write `hooks.json`**

File: `plugins/e22-org/hooks/hooks.json`

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/sandbox-guardrails.sh"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/handoff-cue.sh"
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Write `sandbox-guardrails.sh`**

File: `plugins/e22-org/hooks/sandbox-guardrails.sh`

```bash
#!/usr/bin/env bash
# e22-org: PreToolUse hook. Complements security-rails (which already blocks
# secrets, AWS keys, Stripe live keys, raw-SQL interpolation). This hook covers
# what security-rails does not: real PII patterns and explicit production-DB
# connection strings. Hard-blocks in BOTH zones — spec v0.4 §12 boundary #3
# (no real PII in sandbox) is non-negotiable.

set -uo pipefail

payload="$(cat || true)"
file_path="$(printf '%s' "$payload" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("file_path",""))' 2>/dev/null || true)"
content="$(printf '%s' "$payload" | python3 -c 'import sys,json; d=json.load(sys.stdin); ti=d.get("tool_input",{}); print(ti.get("content") or ti.get("new_string") or "")' 2>/dev/null || true)"

[ -z "$content" ] && exit 0

block() {
  echo "e22-org BLOCKED: $1" >&2
  echo "  File: $file_path" >&2
  [ -n "${2:-}" ] && echo "  Match: $2" >&2
  echo "  See plugins/e22-org/CLAUDE.md → 'Sandbox guardrails'." >&2
  exit 2
}

# 1. US SSN shape: NNN-NN-NNNN with realistic ranges (not all-zeros, not 666-).
if printf '%s' "$content" | grep -qE '(^|[^0-9])(?!000|666|9)[0-9]{3}-(?!00)[0-9]{2}-(?!0000)[0-9]{4}([^0-9]|$)' 2>/dev/null \
   || printf '%s' "$content" | grep -qE '\b[1-8][0-9]{2}-[0-9]{2}-[0-9]{4}\b'; then
  block "looks like a real US Social Security Number. Use a synthetic placeholder (e.g. 000-00-0000)."
fi

# 2. Credit-card-shaped digit runs (13-19 digits in common groupings). Heuristic:
#    require Visa/MC/Amex prefixes to reduce false positives on long numeric IDs.
if printf '%s' "$content" | grep -qE '\b(4[0-9]{3}([- ]?[0-9]{4}){3}|5[1-5][0-9]{2}([- ]?[0-9]{4}){3}|3[47][0-9]{2}([- ]?[0-9]{6})([- ]?[0-9]{5}))\b'; then
  block "looks like a real credit-card number. Use a synthetic placeholder (e.g. 4242 4242 4242 4242)."
fi

# 3. IBAN shape: 2-letter country code + 2 check digits + up to 30 alphanumerics.
if printf '%s' "$content" | grep -qE '\b[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}\b'; then
  block "looks like a real IBAN. Use a synthetic placeholder."
fi

# 4. Production-DB connection strings: scheme://user:pass@host... where host
#    contains 'prod' or 'production' as a word segment.
if printf '%s' "$content" | grep -qiE '(postgres|postgresql|mysql|mongodb|redis)://[^/[:space:]]+@[^/[:space:]]*\b(prod|production)\b'; then
  block "production database connection string detected. The sandbox cannot use production DBs (spec v0.4 §12 boundary #2)."
fi

exit 0
```

- [ ] **Step 3: Write `handoff-cue.sh`**

File: `plugins/e22-org/hooks/handoff-cue.sh`

```bash
#!/usr/bin/env bash
# e22-org: UserPromptSubmit hook. Scans the user's prompt for handoff-intent
# phrases. On match, emits a system reminder pointing Claude at the
# HANDOFF.md-generation instructions in plugins/e22-org/CLAUDE.md.
#
# This is belt-and-suspenders to the always-loaded instruction — on Claude Code
# the hook is hard to miss; on other surfaces the instruction in CLAUDE.md
# carries the same rule.

set -uo pipefail

payload="$(cat || true)"
prompt="$(printf '%s' "$payload" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("prompt",""))' 2>/dev/null || true)"

[ -z "$prompt" ] && exit 0

# Lowercased copy for matching.
lc="$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')"

trigger=0
case "$lc" in
  *"handoff this"*|*"hand this off"*|*"hand-off this"*) trigger=1 ;;
  *"package this for dev"*|*"package this up for engineering"*) trigger=1 ;;
  *"package for dev"*|*"package up for engineering"*) trigger=1 ;;
  *"i'm done with the mvp"*|*"i am done with the mvp"*|*"done with the mvp"*) trigger=1 ;;
  *"turn this into a dev brief"*) trigger=1 ;;
  *"extract the spec"*) trigger=1 ;;
  *"ready for engineering review"*|*"ready for engineering"*) trigger=1 ;;
esac

if [ "$trigger" -eq 1 ]; then
  cat <<'EOF'
e22-org: detected a handoff trigger in the user's prompt.

Follow the handoff procedure in plugins/e22-org/CLAUDE.md → "Handoff trigger":

1. Copy plugins/e22-org/templates/HANDOFF.md.template to HANDOFF.md at the
   workspace root.
2. Fill all 15 sections from this conversation + the workspace.
3. Sections 8, 9, 10, 12, 13 are MANDATORY — write "No evidence collected
   during this session." if you have nothing, never fabricate.
4. Section 14: pick one of Harden / Extract / Rewrite / Reject / Continue
   exploring. Section 15: 2-5 sentence rationale.
5. Report the absolute path of HANDOFF.md and a one-line summary to the user.

If the handoff-packager plugin is installed, defer to its CLAUDE.md for
detailed per-section guidance.
EOF
fi

exit 0
```

- [ ] **Step 4: Make the hooks executable**

```bash
chmod +x plugins/e22-org/hooks/sandbox-guardrails.sh plugins/e22-org/hooks/handoff-cue.sh plugins/e22-org/lib/zone.sh
```

- [ ] **Step 5: Syntax-check both hooks**

```bash
bash -n plugins/e22-org/hooks/sandbox-guardrails.sh
bash -n plugins/e22-org/hooks/handoff-cue.sh
```

Expected: both exit 0 with no output.

- [ ] **Step 6: Smoke-test handoff-cue**

```bash
printf '%s' '{"prompt":"handoff this to engineering please"}' \
  | bash plugins/e22-org/hooks/handoff-cue.sh
```

Expected: output starts with `e22-org: detected a handoff trigger`.

Then a negative case:

```bash
printf '%s' '{"prompt":"build me an MVP for a checkout flow"}' \
  | bash plugins/e22-org/hooks/handoff-cue.sh
```

Expected: no output, exit 0.

- [ ] **Step 7: Smoke-test sandbox-guardrails**

Negative (no real PII):

```bash
printf '%s' '{"tool_input":{"file_path":"foo.py","content":"x = 1"}}' \
  | bash plugins/e22-org/hooks/sandbox-guardrails.sh
echo "exit=$?"
```

Expected: `exit=0`.

Positive (fake-but-shaped CC number):

```bash
printf '%s' '{"tool_input":{"file_path":"f.py","content":"cc = \"4111-1111-1111-1111\""}}' \
  | bash plugins/e22-org/hooks/sandbox-guardrails.sh
echo "exit=$?"
```

Expected: stderr contains `BLOCKED`, `exit=2`.

- [ ] **Step 8: Commit**

```bash
git add plugins/e22-org/hooks/
git commit -m "$(cat <<'EOF'
e22-org: add sandbox-guardrails and handoff-cue hooks

PreToolUse hook (sandbox-guardrails) hard-blocks real PII (SSN/CC/IBAN
shapes) and production-DB connection strings in BOTH zones — spec v0.4
§12 boundary #3 is non-negotiable. Complements security-rails rather
than duplicating; security-rails already covers secrets, AWS keys,
Stripe keys, raw-SQL interpolation.

UserPromptSubmit hook (handoff-cue) scans for natural-language handoff
phrases and injects a system reminder pointing at the procedure in
plugins/e22-org/CLAUDE.md. Belt-and-suspenders to the always-loaded
instruction.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Zone-gate `always-test` hooks; drop lane logic

**Files:**
- Modify: `plugins/always-test/hooks/check-test-coverage.sh`
- Modify: `plugins/always-test/hooks/remind-smoke-test.sh`
- Modify: `plugins/always-test/.claude-plugin/plugin.json`

- [ ] **Step 1: Rewrite `check-test-coverage.sh`**

Replace the entire contents of `plugins/always-test/hooks/check-test-coverage.sh` with:

```bash
#!/usr/bin/env bash
# always-test: PostToolUse hook. When a route handler, page component, or job
# definition is added or modified in a GOVERNED repo, block with exit 2 if no
# adjacent test file exists.
#
# Zone-gated (spec v0.4 §11.3): silent in the local MVP sandbox; full
# enforcement in governed-production repos. The sandbox does not need a minimum
# test floor (spec v0.4 §10.3).

set -uo pipefail

# Zone gate: silent in sandbox.
source "${CLAUDE_PLUGIN_ROOT}/../e22-org/lib/zone.sh"
e22_require_governed || exit 0

payload="$(cat || true)"
file_path="$(printf '%s' "$payload" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("file_path",""))' 2>/dev/null || true)"

[ -z "$file_path" ] && exit 0

endpoint_patterns='(api|route|handler|page|screen|view|job|worker|task|endpoint)'

if printf '%s' "$file_path" | grep -qiE "$endpoint_patterns"; then
  case "$file_path" in
    *test*|*spec*|*__tests__*|*.test.*|*.spec.*) exit 0 ;;
  esac

  dir="$(dirname "$file_path")"
  base="$(basename "$file_path" | sed -E 's/\.[a-zA-Z]+$//')"
  found=0
  for candidate in \
    "${dir}/${base}.test.ts" \
    "${dir}/${base}.test.tsx" \
    "${dir}/${base}.spec.ts" \
    "${dir}/${base}.test.py" \
    "${dir}/${base}_test.py" \
    "${dir}/__tests__/${base}.test.ts" \
    "${dir}/__tests__/${base}.test.tsx" \
    "${dir}/tests/test_${base}.py"
  do
    if [ -f "$candidate" ]; then
      found=1
      break
    fi
  done

  if [ "$found" -eq 0 ]; then
    echo "always-test (governed, BLOCK): '$file_path' is a new endpoint/screen/job and has no adjacent test." >&2
    echo "  Governed-production repos require at least one smoke test per artifact." >&2
    echo "  Write the test, then re-attempt the edit." >&2
    exit 2
  fi
fi

exit 0
```

- [ ] **Step 2: Rewrite `remind-smoke-test.sh`**

Replace the entire contents of `plugins/always-test/hooks/remind-smoke-test.sh` with:

```bash
#!/usr/bin/env bash
# always-test: Stop hook. When Claude is about to end a turn in a GOVERNED
# repo, scan the diff for newly-added endpoint/screen/job files that still
# have no test file, and ask Claude to keep going (exit 2).
#
# Zone-gated: silent in the local MVP sandbox.

set -uo pipefail

source "${CLAUDE_PLUGIN_ROOT}/../e22-org/lib/zone.sh"
e22_require_governed || exit 0

changed="$(git diff --name-only --diff-filter=AM 2>/dev/null; git diff --cached --name-only --diff-filter=AM 2>/dev/null)"
[ -z "$changed" ] && exit 0

missing=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  case "$f" in
    *test*|*spec*|*__tests__*|*.test.*|*.spec.*|*.md|*.json|*.yaml|*.yml|*.toml) continue ;;
  esac
  if printf '%s' "$f" | grep -qiE '(api|route|handler|page|screen|view|job|worker|task|endpoint)'; then
    dir="$(dirname "$f")"
    base="$(basename "$f" | sed -E 's/\.[a-zA-Z]+$//')"
    found=0
    for c in "${dir}/${base}.test.ts" "${dir}/${base}.test.tsx" "${dir}/${base}.spec.ts" "${dir}/${base}.test.py" "${dir}/${base}_test.py" "${dir}/__tests__/${base}.test.ts" "${dir}/__tests__/${base}.test.tsx" "${dir}/tests/test_${base}.py"; do
      [ -f "$c" ] && { found=1; break; }
    done
    [ "$found" -eq 0 ] && missing="${missing}${f}\n"
  fi
done <<< "$changed"

if [ -n "$missing" ]; then
  cat >&2 <<EOF
always-test (governed): the following new/changed files look like endpoints/screens/jobs and have no adjacent test:
$(printf '%b' "$missing" | sed 's/^/  - /')

Scaffold tests before ending the turn per the product's testing strategy — typically unit + integration + smoke. Production CI will fail on coverage delta if these land untested.
EOF
  exit 2
fi

exit 0
```

- [ ] **Step 3: Bump version and rewrite manifest description**

Modify `plugins/always-test/.claude-plugin/plugin.json` — replace the entire file with:

```json
{
  "name": "always-test",
  "version": "0.3.0",
  "description": "House rule: every new endpoint, screen, or background job in a governed-production repo ships with at least one smoke test. Zone-gated — sources plugins/e22-org/lib/zone.sh and is silent in the local MVP sandbox, full enforcement (exit 2 / Stop-continue) when the workspace has a GitHub remote.",
  "author": {
    "name": "Element 22 Platform",
    "email": "alexis.valotaire@element-22.com"
  },
  "homepage": "https://github.com/element22llc/e22-plugins/tree/main/plugins/always-test",
  "license": "UNLICENSED",
  "keywords": ["element-22", "house-rule", "claude-chat", "claude-cowork", "claude-code", "hooks-claude-code-only", "tests", "smoke-tests", "ci", "zone-gated"]
}
```

- [ ] **Step 4: Syntax-check both hooks**

```bash
bash -n plugins/always-test/hooks/check-test-coverage.sh
bash -n plugins/always-test/hooks/remind-smoke-test.sh
```

Expected: both exit 0 with no output.

- [ ] **Step 5: Verify no lingering lane references**

```bash
grep -nE 'branch\.yaml|prototype/|lane' plugins/always-test/hooks/*.sh
```

Expected: no output (no matches).

- [ ] **Step 6: Commit**

```bash
git add plugins/always-test/
git commit -m "$(cat <<'EOF'
always-test: zone-gate hooks; drop lane logic (v0.2.0 → v0.3.0)

Both hooks now source e22-org/lib/zone.sh and exit 0 in the sandbox.
Removes the branch.yaml-based lane detection per spec v0.4. Sandbox
gets no test-floor enforcement (spec v0.4 §10.3 defers minimum test
floor during exploration); governed repos get the previous strict
behavior (exit 2 on PostToolUse miss, Stop-continue on session end).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Zone-gate `spine-writer` hook + add sandbox refusal to `/spine-refresh`

**Files:**
- Modify: `plugins/spine-writer/hooks/maybe-refresh.sh`
- Modify: `plugins/spine-writer/commands/spine-refresh.md`
- Modify: `plugins/spine-writer/.claude-plugin/plugin.json`

- [ ] **Step 1: Rewrite `maybe-refresh.sh`**

Replace the entire contents of `plugins/spine-writer/hooks/maybe-refresh.sh` with:

```bash
#!/usr/bin/env bash
# spine-writer: PostToolUse hook. After a "meaningful" edit (new endpoint,
# schema migration, new screen, dependency change) in a GOVERNED repo, surface
# a reminder to refresh the Spine. We don't auto-invoke the agent here — that
# would be costly and noisy; we let Claude decide whether the change is
# meaningful enough to warrant /spine-refresh.
#
# Zone-gated (spec v0.4 §10.3): no continuous Spine writing during exploration.
# Silent in the local MVP sandbox; nudges only in governed-production repos.
# This hook never blocks.

set -uo pipefail

source "${CLAUDE_PLUGIN_ROOT}/../e22-org/lib/zone.sh"
e22_require_governed || exit 0

payload="$(cat || true)"
file_path="$(printf '%s' "$payload" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("file_path",""))' 2>/dev/null || true)"

[ -z "$file_path" ] && exit 0

meaningful=0
case "$file_path" in
  */routes/*|*/api/*|*/handlers/*) meaningful=1 ;;
  */migrations/*|*schema*) meaningful=1 ;;
  */pages/*|*/screens/*|*/components/*) meaningful=1 ;;
  package.json|pyproject.toml|Cargo.toml|go.mod) meaningful=1 ;;
esac

[ "$meaningful" -eq 0 ] && exit 0

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
slug="$(echo "$branch" | sed -E 's|^(proposal|feat|fix)/||')"

if [ -f "proposals/${slug}/product-spine.md" ]; then
  spine_age_minutes=$(( ( $(date +%s) - $(stat -f %m "proposals/${slug}/product-spine.md" 2>/dev/null || stat -c %Y "proposals/${slug}/product-spine.md" 2>/dev/null || echo 0) ) / 60 ))
  if [ "$spine_age_minutes" -gt 60 ]; then
    echo "spine-writer: meaningful change to '$file_path' but proposals/${slug}/product-spine.md is ${spine_age_minutes} minutes stale. Consider running /spine-refresh." >&2
  fi
else
  echo "spine-writer: meaningful change to '$file_path' on branch '${branch}' but no Product Spine exists at proposals/${slug}/product-spine.md. Run /spine-refresh to create one." >&2
fi

exit 0
```

- [ ] **Step 2: Add sandbox refusal to `/spine-refresh`**

Modify `plugins/spine-writer/commands/spine-refresh.md`. Find the `## Workflow` heading and insert a new step 0 immediately above the current step 1.

Old text:

```markdown
## Workflow

1. **Locate the Spine.** If `$ARGUMENTS` is provided, use that path. Otherwise:
```

New text:

```markdown
## Workflow

0. **Zone check.** Source `${CLAUDE_PLUGIN_ROOT}/../e22-org/lib/zone.sh` and
   run `e22_zone`. If the workspace is `sandbox`, refuse cleanly:
   *"Product Spines are a governed-production artifact. Generate `HANDOFF.md`
   instead (handoff-packager) — or run this command after the work is imported
   into a governed repo (one with a GitHub remote)."* Exit without writing.

1. **Locate the Spine.** If `$ARGUMENTS` is provided, use that path. Otherwise:
```

- [ ] **Step 3: Scrub stale references in `spine-refresh.md`**

In the same file, find and replace any remaining references to `/package-handoff` (which is being deleted in Task 10). Run:

```bash
grep -n '/package-handoff\|prototype lane' plugins/spine-writer/commands/spine-refresh.md
```

If matches appear, edit them out manually. Replace `/package-handoff` references with `the handoff flow in plugins/e22-org/CLAUDE.md`. Replace `prototype lane` with `local MVP sandbox`.

After editing, verify clean:

```bash
grep -n '/package-handoff\|prototype lane\|prototype-lane' plugins/spine-writer/commands/spine-refresh.md
```

Expected: no output.

- [ ] **Step 4: Bump version and rewrite manifest description**

Replace the entire contents of `plugins/spine-writer/.claude-plugin/plugin.json` with:

```json
{
  "name": "spine-writer",
  "version": "0.2.0",
  "description": "House rule: the Product Spine stays in sync with the code in governed-production repos. Provides /spine-refresh (manual) and a PostToolUse hook (automatic, when a meaningful file changes). The spine-extractor agent distills Intent/UX/Surface/Architecture/Open Questions from a branch's commits, code, and chat context. Zone-gated — silent in the local MVP sandbox (spec v0.4 §10.3), nudges and runs only when the workspace has a GitHub remote.",
  "author": {
    "name": "Element 22 Platform",
    "email": "alexis.valotaire@element-22.com"
  },
  "homepage": "https://github.com/element22llc/e22-plugins/tree/main/plugins/spine-writer",
  "license": "UNLICENSED",
  "keywords": ["element-22", "house-rule", "claude-chat", "claude-cowork", "claude-code", "github-connector", "spine", "spec", "handoff", "drift", "zone-gated"]
}
```

- [ ] **Step 5: Syntax-check the hook and verify cleanup**

```bash
bash -n plugins/spine-writer/hooks/maybe-refresh.sh
grep -n 'prototype/\*\|prototype lane' plugins/spine-writer/hooks/maybe-refresh.sh
```

Expected: hook syntax OK; no lane-prefix references remaining in the hook.

- [ ] **Step 6: Commit**

```bash
git add plugins/spine-writer/
git commit -m "$(cat <<'EOF'
spine-writer: zone-gate hook + sandbox refusal (v0.1.1 → v0.2.0)

PostToolUse hook now sources e22-org/lib/zone.sh and exits silently in
the local MVP sandbox per spec v0.4 §10.3 (no continuous Spine writing
during exploration). Drops the prototype/* branch-prefix carve-out
since the sandbox is now zone-determined, not branch-determined.

/spine-refresh gains a zone check that refuses to write in the sandbox,
pointing at the handoff flow instead.

Scrubs residual references to /package-handoff and "prototype lane."

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Zone-gate `house-style` hook + add `CLAUDE.md` with tech-stack guidance

**Files:**
- Modify: `plugins/house-style/hooks/run-house-style.sh`
- Create: `plugins/house-style/CLAUDE.md`
- Modify: `plugins/house-style/.claude-plugin/plugin.json`

- [ ] **Step 1: Add zone gate to `run-house-style.sh`**

Replace the entire contents of `plugins/house-style/hooks/run-house-style.sh` with:

```bash
#!/usr/bin/env bash
# house-style: PostToolUse hook. Run the product's configured linter/formatter
# on the edited file. Zone-gated (spec v0.4 §11.3): silent in the local MVP
# sandbox — lint nags during exploration are exactly the friction v0.4 removes
# — full enforcement (exit 2 on failure) in governed-production repos.
#
# Tech-stack and latest-stable-version guidance is delivered separately as
# always-loaded instructions in plugins/house-style/CLAUDE.md (loaded in both
# zones so the PO benefits from the team's tech-stack choices during MVP work).
#
# We do not encode the lint tool here — the product's CLAUDE.md should declare
# it. This hook dispatches on common extensions to common tools, falling back
# to silently passing if no tool is installed.

set -uo pipefail

source "${CLAUDE_PLUGIN_ROOT}/../e22-org/lib/zone.sh"
e22_require_governed || exit 0

payload="$(cat || true)"
file_path="$(printf '%s' "$payload" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("tool_input",{}).get("file_path",""))' 2>/dev/null || true)"

[ -z "$file_path" ] && exit 0
[ ! -f "$file_path" ] && exit 0

output=""
rc=0

case "$file_path" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs)
    if command -v biome >/dev/null 2>&1; then
      output="$(biome check --no-errors-on-unmatched "$file_path" 2>&1)" || rc=$?
    elif command -v eslint >/dev/null 2>&1; then
      output="$(eslint "$file_path" 2>&1)" || rc=$?
    fi
    ;;
  *.py)
    if command -v ruff >/dev/null 2>&1; then
      output="$(ruff check "$file_path" 2>&1)" || rc=$?
    elif command -v flake8 >/dev/null 2>&1; then
      output="$(flake8 "$file_path" 2>&1)" || rc=$?
    fi
    ;;
  *.tf|*.tofu)
    if command -v tofu >/dev/null 2>&1; then
      output="$(tofu fmt -check=true -diff=true "$file_path" 2>&1)" || rc=$?
    elif command -v terraform >/dev/null 2>&1; then
      output="$(terraform fmt -check=true -diff=true "$file_path" 2>&1)" || rc=$?
    fi
    ;;
  *.hcl)
    if command -v terragrunt >/dev/null 2>&1; then
      output="$(terragrunt hclfmt --terragrunt-check --terragrunt-diff "$file_path" 2>&1)" || rc=$?
    fi
    ;;
  *.go)
    if command -v gofmt >/dev/null 2>&1; then
      output="$(gofmt -l "$file_path" 2>&1)" || rc=$?
      [ -n "$output" ] && rc=1
    fi
    ;;
  *)
    exit 0 ;;
esac

if [ "$rc" -ne 0 ]; then
  echo "house-style (governed, BLOCK): lint failed for $file_path" >&2
  [ -n "$output" ] && echo "$output" >&2
  exit 2
fi

exit 0
```

- [ ] **Step 2: Write `house-style/CLAUDE.md`**

File: `plugins/house-style/CLAUDE.md`

```markdown
# house-style — always-loaded conventions

Loaded into every Claude session when `house-style` is installed. Applies in
**both** zones (sandbox and governed) — the team's tech-stack choices matter
for MVP work too, so the prototype isn't built on a stack that will be
discarded at handoff.

The PostToolUse lint/format hook is zone-gated and runs only in
governed-production repos. These instructions are not.

## Read the stack before generating code

Before generating code in any zone:

1. Read [`TECH-STACK.md`](../../TECH-STACK.md) for the team's preferred
   languages, frameworks, ORM, tests, observability, feature-flag tooling,
   and infrastructure.
2. Read the nearest product `CLAUDE.md` (`apps/<product>/CLAUDE.md`) for any
   per-product stack divergence or convention.
3. Read the nearest manifest file (`mise.toml`, `package.json`,
   `pyproject.toml`, `Cargo.toml`, `go.mod`) for the authoritative pinned
   versions. **Never claim a version from memory.**

If a manifest is missing or the stack is unclear, ask — do not guess.

## Prefer the latest stable version

When adding a dependency that the product does not already pin:

- Pick the latest stable release (not pre-release, not RC).
- If `context7` is installed, defer to it for current API and version docs
  rather than relying on training-data recall.
- Mention the version you picked in the PR description or HANDOFF.md so Dev
  can see it at review time.

This rule applies in both zones. POs building MVPs benefit from the same
stack choices as production — it makes the Dev decision (Harden / Extract /
Rewrite) simpler.

## Naming and folder conventions

Advisory in the sandbox; enforced by the PostToolUse hook in governed repos.

- Follow the patterns already present in the product. If the codebase uses
  `kebab-case` for files, do not introduce `camelCase`.
- New endpoints/handlers/jobs live where existing ones live — do not create
  parallel layouts.
- Shared utilities go in the product's existing shared directory (`packages/`,
  `shared/`, `lib/`); do not duplicate within a feature directory.

## Tool version manager

Every project that can express its toolchain in [mise](https://mise.jdx.dev/)
must do so. Do not introduce parallel installs via `nvm`, `pyenv`, `asdf`,
Homebrew, or global `npm i -g` unless explicitly documented in the product's
`CLAUDE.md`.
```

- [ ] **Step 3: Bump version and rewrite manifest description**

Replace the entire contents of `plugins/house-style/.claude-plugin/plugin.json` with:

```json
{
  "name": "house-style",
  "version": "0.2.0",
  "description": "House rule: naming, folder layout, lint rules, tech-stack adherence, and latest-stable-version guidance are consistent in every Claude session. Provides always-loaded CLAUDE.md (both zones — POs benefit from team tech-stack choices during MVP work) and a PostToolUse lint/format hook that is zone-gated to governed-production repos via plugins/e22-org/lib/zone.sh.",
  "author": {
    "name": "Element 22 Platform",
    "email": "alexis.valotaire@element-22.com"
  },
  "homepage": "https://github.com/element22llc/e22-plugins/tree/main/plugins/house-style",
  "license": "UNLICENSED",
  "keywords": ["element-22", "always-on", "house-rule", "claude-chat", "claude-cowork", "claude-code", "hooks-claude-code-only", "lint", "format", "conventions", "tech-stack", "zone-gated"]
}
```

- [ ] **Step 4: Syntax-check and verify no lane refs**

```bash
bash -n plugins/house-style/hooks/run-house-style.sh
grep -nE 'prototype/\*|prototype lane|lane' plugins/house-style/hooks/run-house-style.sh
```

Expected: syntax OK; only the word "lane" appearing in comments referencing the gate's history is acceptable — but the rewrite above has none. The grep should return no output.

- [ ] **Step 5: Commit**

```bash
git add plugins/house-style/
git commit -m "$(cat <<'EOF'
house-style: zone-gate hook + always-loaded CLAUDE.md (v0.1.0 → v0.2.0)

Splits the plugin's behavior by zone:
- Lint/format PostToolUse hook now sources e22-org/lib/zone.sh and is
  silent in the local MVP sandbox; full enforcement (exit 2 on failure)
  in governed repos.
- New CLAUDE.md carries tech-stack adherence and latest-stable-version
  guidance in BOTH zones, so PO MVPs are built on the team's chosen
  stack from day one. Per the design doc — POs benefit from the same
  tech-stack choices as production.

Drops the branch-prefix "lane" logic in favor of zone detection via
e22-org/lib/zone.sh.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Patch `security-rails` description (no behavior change)

**Files:**
- Modify: `plugins/security-rails/.claude-plugin/plugin.json`

`security-rails` already behaves correctly in both zones — its `scan-content.sh`
and `scan-bash.sh` apply universal blocks (secrets, AWS keys, Stripe live keys,
SQL injection, force-push, push-to-main). Only the description needs to clarify
the dual-zone role.

- [ ] **Step 1: Bump patch version and revise description**

Replace the entire contents of `plugins/security-rails/.claude-plugin/plugin.json` with:

```json
{
  "name": "security-rails",
  "version": "0.2.1",
  "description": "House rule: blocks universal risky patterns in BOTH zones (sandbox and governed-production). PreToolUse hooks scan Write/Edit content (plaintext secrets, AWS access keys, Stripe live keys, raw-SQL f-string interpolation) and Bash commands (force-push, push-to-main, prod database clients). Pairs with Anthropic's security-guidance plugin (required complement) for code-injection patterns. Complemented by e22-org's sandbox-guardrails hook which adds real-PII pattern blocks.",
  "author": {
    "name": "Element 22 Platform",
    "email": "alexis.valotaire@element-22.com"
  },
  "homepage": "https://github.com/element22llc/e22-plugins/tree/main/plugins/security-rails",
  "license": "UNLICENSED",
  "keywords": ["element-22", "always-on", "house-rule", "claude-chat", "claude-cowork", "claude-code", "hooks-claude-code-only", "security", "guardrails"]
}
```

- [ ] **Step 2: Commit**

```bash
git add plugins/security-rails/.claude-plugin/plugin.json
git commit -m "$(cat <<'EOF'
security-rails: clarify dual-zone role in description (v0.2.0 → v0.2.1)

Patch — no behavior change. Description now explicitly states the
plugin applies in both sandbox and governed zones, and notes the
complementary relationship with e22-org's sandbox-guardrails hook
(which handles real-PII patterns this plugin does not).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Rewrite `handoff-packager` — single-file `HANDOFF.md`

**Files:**
- Delete: `plugins/handoff-packager/commands/package.md`
- Delete: `plugins/handoff-packager/commands/` (empty after delete)
- Create: `plugins/handoff-packager/CLAUDE.md`
- Modify: `plugins/handoff-packager/.claude-plugin/plugin.json`

- [ ] **Step 1: Delete the old `/package` command**

```bash
rm plugins/handoff-packager/commands/package.md
rmdir plugins/handoff-packager/commands
```

- [ ] **Step 2: Write the new `CLAUDE.md`**

File: `plugins/handoff-packager/CLAUDE.md`

```markdown
# handoff-packager — per-section guidance

Loaded into every Claude session when `handoff-packager` is installed.
Provides detailed guidance for filling each section of `HANDOFF.md` when the
natural-language handoff trigger fires (see `plugins/e22-org/CLAUDE.md` →
"Handoff trigger").

The template lives at `plugins/e22-org/templates/HANDOFF.md.template`. This
plugin does not own a slash command — generation is triggered by natural
language and always lands at the workspace root, never under `proposals/`.

## Output location

Always: `<workspace-root>/HANDOFF.md`.

Never: `proposals/<slug>/handoff/*` (that scheme was removed in v0.2.0 with
the v0.4 spec revision — spec v0.4 §7.2 mandates a single file by default).

## Section-by-section guidance

### 1. Product intent

User problem, target users, desired outcome, success criteria. Pull from the
PO's earliest messages — the framing they used before iteration changed the
shape. One paragraph each is enough.

### 2. Prototype behavior

What the MVP currently does, including main flows and important screens.
Concrete, observable behavior — not implementation detail. Each main flow
gets a sub-bullet.

### 3. UX decisions

Copy, layout, interaction, workflow, and variant decisions the PO made during
exploration. Include rejected alternatives where the user explicitly chose
between options ("we tried X but went with Y because…").

### 4. Demo evidence

Links or references to screenshots, recordings, local preview notes, or
artifacts collected during the session. If `assets/` exists at the workspace
root, list the relevant files. If a Claude Artifact URL is in the chat,
include it.

### 5. Files and dependencies

Important files in the workspace, libraries added, tools used, generated
assets, external packages. For each dependency: name and pinned version.

### 6. Data model implications

Entities, fields, relationships, persistence assumptions, fake data used.
Include the shape of any in-memory or temporary database schema. Note where
real production data would replace fake.

### 7. External service implications

Auth, payments, email, maps, AI APIs, storage, queues, or other integrations
the prototype implies but does not actually call. List what production would
need to provision.

### 8. Security, privacy, and compliance risks (MANDATORY)

PII, auth, permissions, billing, secrets, abuse vectors, retention, audit
concerns. Do not leave blank. If no risks were identified, write `No
evidence collected during this session.` — but think carefully first: most
real systems have at least an auth and PII surface.

### 9. Known shortcuts and hacks (MANDATORY)

Prototype shortcuts, hardcoded values, mock services, fake users, fragile
paths. **Every shortcut Claude knowingly took during the session belongs
here.** Examples: hardcoded admin user, mock auth bypass, no rate limiting,
inline secrets for the demo, fragile parsing of a vendor format.

### 10. What must not be reused (MANDATORY)

Anything that would be unsafe or irresponsible to carry into production.
Often overlaps with §9 but framed as a forward-looking prohibition. If §9
contains "hardcoded admin user 'alice'", §10 contains "the mock auth flow
must be replaced before production — do not copy."

### 11. Manual test notes

What was tried manually, what worked, what failed, known bugs. Include any
test data used.

### 12. Suggested production tests (MANDATORY)

Unit, integration, E2E, accessibility, security, and regression tests Dev
should add. Be specific: "POST /checkout with an empty cart should 400" beats
"add tests for the checkout flow."

### 13. Open product questions (MANDATORY)

Decisions the PO or team still needs to make. Each entry is a question, not a
statement. If the PO said "we'll figure out pricing later," that's an open
question: "What pricing tiers, and what's free vs paid?"

### 14. Suggested Dev decision

Exactly one of: **Harden / Extract / Rewrite / Reject / Continue exploring**
(spec v0.4 §7.4). For brand-new MVPs the default is Extract or Rewrite;
Harden is allowed only when Dev has reviewed the implementation and accepts
ownership of the technical choices.

### 15. Rationale

2-5 sentences explaining the §14 decision. Anchor to evidence from earlier
sections, especially §8/§9/§10 — the risks and shortcuts drive most
Refactor/Rewrite decisions.

## Mandatory sections — fill them, don't fabricate

Sections 8, 9, 10, 12, 13 must not be left blank. Spec v0.4 §7.3 lists them
as mandatory because they prevent prototype shortcuts from migrating into
production by inertia.

If you genuinely have no evidence for a section, write `No evidence
collected during this session.` — that is honest and gives Dev a clear
signal. Fabricating content that "looks like" a real risk or a real test
suggestion is worse than admitting the session didn't surface one.

## Don't drift into `proposals/`

The v0.3 multi-file bundle (`proposals/<slug>/handoff/{dependency-delta,
novel-patterns, plugin-violations}.md`) was removed. Spec v0.4 §7.2: *"use
one file by default: `HANDOFF.md`. Do not create multiple required markdown
files until the single-file packet has proven insufficient."*

If the team later decides a multi-file bundle is needed (e.g., a Dev-side
post-import audit), that's a separate feature — do not add it implicitly
during handoff generation.
```

- [ ] **Step 3: Rewrite the manifest**

Replace the entire contents of `plugins/handoff-packager/.claude-plugin/plugin.json` with:

```json
{
  "name": "handoff-packager",
  "version": "0.2.0",
  "description": "Always-on guidance: how to populate the 15 sections of HANDOFF.md when e22-org's natural-language handoff trigger fires. Loads always-on CLAUDE.md with per-section guidance, mandatory-section rules (8/9/10/12/13), and the 'No evidence collected' fallback. The HANDOFF.md template lives in plugins/e22-org/templates/HANDOFF.md.template. No slash command — generation is triggered by natural language; output always lands at the workspace root, never under proposals/. Replaces the v0.1.0 multi-file bundle scheme.",
  "author": {
    "name": "Element 22 Platform",
    "email": "alexis.valotaire@element-22.com"
  },
  "homepage": "https://github.com/element22llc/e22-plugins/tree/main/plugins/handoff-packager",
  "license": "UNLICENSED",
  "keywords": ["element-22", "always-on", "claude-chat", "claude-cowork", "claude-code", "handoff", "mvp", "single-file"]
}
```

- [ ] **Step 4: Verify deletion and the new file structure**

```bash
ls plugins/handoff-packager/
test ! -d plugins/handoff-packager/commands && echo "commands removed OK"
```

Expected: directory listing shows `.claude-plugin/`, `CLAUDE.md`; the second line prints `commands removed OK`.

- [ ] **Step 5: Verify mandatory-section guidance is in the new file**

```bash
grep -c 'MANDATORY' plugins/handoff-packager/CLAUDE.md
```

Expected: 5 or more matches (one per mandatory section + the dedicated subsection at the bottom).

- [ ] **Step 6: Commit**

```bash
git add plugins/handoff-packager/
git commit -m "$(cat <<'EOF'
handoff-packager: rewrite for single-file HANDOFF.md (v0.1.0 → v0.2.0)

Per spec v0.4 §7.2 — single HANDOFF.md by default, not the v0.3
multi-file bundle.

Removes:
- /package slash command (commands/package.md). Generation is now
  triggered by natural language in e22-org, not a command.
- The proposals/<slug>/handoff/* output path scheme.
- The GitHub-connector requirement.

Adds:
- CLAUDE.md with per-section guidance for all 15 sections, explicit
  marking of mandatory sections 8/9/10/12/13, and the "No evidence
  collected during this session" fallback per spec v0.4 §7.3.

The HANDOFF.md template itself lives in plugins/e22-org/templates/
(added in Task 1 of this plan).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Update `production-lane` `/validate` decision matrix + scrub vocab

**Files:**
- Modify: `plugins/production-lane/commands/validate.md`
- Modify: `plugins/production-lane/skills/validation-decision/SKILL.md`
- Modify: `plugins/production-lane/.claude-plugin/plugin.json`
- Possibly modify: `plugins/production-lane/commands/{propose,from-design,promote}.md`
- Possibly modify: `plugins/production-lane/skills/{proposal-intake,feature-flag-promotion}/SKILL.md`
- Possibly modify: `plugins/production-lane/agents/{spec-refiner,drift-monitor}.md`

The breaking decision-label change is the headline. The vocabulary scrub is
mechanical but needs care because some files reference deleted plugins
(`prototype-lane`, `spec-driven-dev`, `/vibe`, `/package-handoff`).

- [ ] **Step 1: Replace the decision matrix in `validate.md`**

Open `plugins/production-lane/commands/validate.md` and:

(a) Rewrite the frontmatter `description` line. Find:

```markdown
description: Engineer validation gate for a packaged prototype. Read the Spine, make one of four decisions — Keep, Refactor, Redesign, Reject.
```

Replace with:

```markdown
description: Engineer validation gate for a packaged prototype. Read HANDOFF.md and any Spine, make one of five decisions — Harden, Extract, Rewrite, Reject, Continue exploring.
```

(b) Rewrite the decision-matrix table. Find the table that begins with `| Decision     | What it means` and ends after the `**Reject**` row. Replace the entire table block with:

```markdown
The five decisions are mutually exclusive:

| Decision               | What it means                                                              | What happens next                                                                            |
| ---------------------- | -------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| **Harden**             | Prototype is production-shaped and Dev accepts ownership of the technical choices. | Import the prototype source into the governed repo, open a draft PR, run the `/propose` workflow from step 5 (self-review) onward. |
| **Extract**            | Keep selected flows, components, copy, data-shape ideas, or UX decisions; build the rest fresh. | Open a new draft PR; carry only the named pieces forward, drop the rest. Use HANDOFF.md §3 (UX decisions) and §6 (data model) as the source of truth for what to extract. |
| **Rewrite**            | Intent is right; the implementation is disposable.                         | Open a new draft PR off `main`. Reimplement using HANDOFF.md as the spec. Do not pull from the prototype source. |
| **Reject**             | Wrong problem or wrong direction.                                          | Close the handoff with a respectful comment quoting HANDOFF.md §15 (rationale) and §13 (open questions). PO can re-vibe with feedback. |
| **Continue exploring** | PO should iterate more before engineering engages.                         | No PR. Reply to the PO with what specifically is unclear or unfinished — typically tied to HANDOFF.md §13 (open questions) and §8 (risks). |

For brand-new MVPs the default is **Extract** or **Rewrite** (spec v0.4 §7.4).
**Harden** is allowed only when Dev has reviewed the implementation and accepts
ownership of the technical choices.
```

(c) Find every remaining occurrence of `Keep`, `Refactor`, `Redesign` in the file and update them. Run:

```bash
grep -n 'Keep\|Refactor\|Redesign' plugins/production-lane/commands/validate.md
```

For each match, decide which new label applies:
- `Keep` → `Harden` (when it refers to the decision)
- `Refactor` → `Rewrite` (almost always — Refactor in v0.3 meant "intent right, impl wrong" which is now Rewrite)
- `Redesign` → `Rewrite` (Redesign in v0.3 was distinct only in tone; the v0.4 model collapses it into Rewrite)

In particular, replace the §6 "Apply the decision" sub-sections:
- Section heading `#### If Keep:` → `#### If Harden:`
- Section heading `#### If Refactor or Redesign:` → `#### If Extract or Rewrite:`
- All body references to the old labels in those sections.

Also rewrite step 5's "Pick one of Keep / Refactor / Redesign / Reject" → "Pick one of Harden / Extract / Rewrite / Reject / Continue exploring".

After editing, verify clean:

```bash
grep -nE '\b(Keep|Refactor|Redesign)\b' plugins/production-lane/commands/validate.md
```

Expected: no output. (If any matches remain, they are likely legitimate uses of those English words — re-read and confirm. None are expected after this rewrite.)

(d) Scrub references to deleted plugins. The file currently mentions `prototype/<slug>`, `proposal/<slug>`, `/.workflow/branch.yaml`, `/.workflow/handoff.md`, `spec-driven-dev`, `prototype-lane`. The simplest treatment:

Replace `prototype/<slug>` with `the handoff source branch`.
Replace `/.workflow/branch.yaml` references with `HANDOFF.md`.
Replace `/.workflow/handoff.md` with `HANDOFF.md` (at the workspace root or imported into the governed repo).
Replace `prototype lane` with `local MVP sandbox`.
Replace `production lane` with `governed production`.
Replace `spec-driven-dev` with — remove the reference; that plugin is deleted.

In the "Plugin violations from `house-style`, `security-rails`, `spec-driven-dev`, and `always-test`" sentence, drop `spec-driven-dev,`.

After editing:

```bash
grep -nE 'prototype/<slug>|spec-driven-dev|prototype-lane|/\.workflow/' plugins/production-lane/commands/validate.md
```

Expected: no output.

(e) The SOC2 exception currently says `for products marked soc2: true, Keep is unavailable. The minimum is Refactor`. Update to: `for products marked soc2: true, Harden is unavailable. The minimum is Rewrite`. (Rewrite is the most conservative non-rejection option.)

- [ ] **Step 2: Update `validation-decision/SKILL.md`**

Open `plugins/production-lane/skills/validation-decision/SKILL.md` and:

(a) Rewrite the `description:` frontmatter line. Find:

```markdown
description: Auto-triggered when an engineer signals they're about to review a packaged prototype awaiting validation without typing /validate — "let's review PR #N", "I'll look at the handoff for X", "what's in the awaiting-validation queue", "is this a Keep or Refactor", "evaluate this prototype", "go through the bundle for Y", "the PO handed this off — let me look". Routes to the /validate gate so the engineer makes a Keep / Refactor / Redesign / Reject decision in minutes against the Spine, not a line-by-line read of throwaway prototype code.
```

Replace with:

```markdown
description: Auto-triggered when an engineer signals they're about to review a HANDOFF.md from a PO MVP without typing /validate — "let's review the handoff for X", "I'll evaluate the MVP", "is this Harden or Extract", "evaluate this prototype", "go through the HANDOFF for Y", "the PO handed this off — let me look". Routes to the /validate gate so the engineer makes a Harden / Extract / Rewrite / Reject / Continue exploring decision in minutes against the handoff packet, not a line-by-line read of disposable prototype code.
```

(b) Update the "When to trigger" bullets — replace `Keep / Refactor / Redesign / Reject` with `Harden / Extract / Rewrite / Reject / Continue exploring`.

(c) Update the "When NOT to trigger" bullets — remove references to:
- `change-idea-intake` (prototype-lane, deleted) → replace the line "The user is still iterating on a prototype — route to `change-idea-intake` (prototype-lane) or stay in `/vibe`." with "The user is still iterating on the MVP locally — the PO should keep exploring; respond conversationally without invoking /validate."
- `branch.yaml` and `handoff_status: ready` → replace with HANDOFF.md presence and §14 having a suggested decision filled in.

(d) Update the "What happens next" numbered list — Step 5 ends with "On Refactor or Redesign, hand off to `proposal-intake` → `/propose`…". Rewrite as "On Extract or Rewrite, hand off to `proposal-intake` → `/propose` with HANDOFF.md as the spec and the prototype source kept aside (the source may be discarded entirely on Rewrite)."

(e) Verify clean:

```bash
grep -nE '\b(Keep|Refactor|Redesign)\b|change-idea-intake|branch\.yaml|/\.workflow|spec-driven-dev|prototype-lane' plugins/production-lane/skills/validation-decision/SKILL.md
```

Expected: no output.

- [ ] **Step 3: Scrub the remaining production-lane files**

For each of: `commands/propose.md`, `commands/from-design.md`, `commands/promote.md`, `skills/proposal-intake/SKILL.md`, `skills/feature-flag-promotion/SKILL.md`, `agents/spec-refiner.md`, `agents/drift-monitor.md` — run:

```bash
for f in \
  plugins/production-lane/commands/propose.md \
  plugins/production-lane/commands/from-design.md \
  plugins/production-lane/commands/promote.md \
  plugins/production-lane/skills/proposal-intake/SKILL.md \
  plugins/production-lane/skills/feature-flag-promotion/SKILL.md \
  plugins/production-lane/agents/spec-refiner.md \
  plugins/production-lane/agents/drift-monitor.md
do
  echo "=== $f ==="
  grep -nE '\b(Keep|Refactor|Redesign)\b|change-idea-intake|/vibe\b|/package-handoff|branch\.yaml|/\.workflow|spec-driven-dev|prototype-lane|prototype lane|production lane' "$f" 2>/dev/null
done
```

For each match: apply the same substitution rules as Step 1(d) and Step 1(c) (Keep→Harden / Refactor→Rewrite / Redesign→Rewrite for decision-label uses; remove references to deleted plugins/commands; replace lane vocabulary with zone vocabulary). After editing, re-run the loop and confirm no matches.

- [ ] **Step 4: Bump version and rewrite manifest description**

Replace the entire contents of `plugins/production-lane/.claude-plugin/plugin.json` with:

```json
{
  "name": "production-lane",
  "version": "0.3.0",
  "description": "Element 22's governed-production plugin for engineers. /validate is the Harden / Extract / Rewrite / Reject / Continue-exploring gate that turns a HANDOFF.md from a PO MVP into a production proposal (spec v0.4 §7.4). /propose starts a production proposal directly. /from-design starts from a Claude Design handoff bundle. /promote governs feature-flag rollouts. spec-refiner and drift-monitor agents keep specs honest. SOC2 governance overlay applies on top. Auto-triggered skills (proposal-intake, validation-decision, feature-flag-promotion) route Dev intent to the right command.",
  "author": {
    "name": "Element 22 Platform",
    "email": "alexis.valotaire@element-22.com"
  },
  "homepage": "https://github.com/element22llc/e22-plugins/tree/main/plugins/production-lane",
  "license": "UNLICENSED",
  "keywords": ["element-22", "production", "claude-chat", "claude-cowork", "claude-code", "github-connector", "proposals", "validation", "governance", "soc2", "feature-flags"]
}
```

- [ ] **Step 5: Final verify**

```bash
grep -rnE '\b(Keep|Refactor|Redesign)\b' plugins/production-lane/ | grep -v plugin.json
grep -rnE 'change-idea-intake|/vibe\b|/package-handoff|prototype-lane|spec-driven-dev' plugins/production-lane/
```

Expected for both: no output.

- [ ] **Step 6: Commit**

```bash
git add plugins/production-lane/
git commit -m "$(cat <<'EOF'
production-lane: /validate matrix → Harden/Extract/Rewrite/Reject/Continue (v0.2.1 → v0.3.0)

Breaking change per spec v0.4 §7.4. The /validate decision matrix moves
from Keep/Refactor/Redesign/Reject to Harden/Extract/Rewrite/Reject/
Continue exploring. Defaults for brand-new MVPs are Extract or Rewrite;
Harden requires Dev acceptance of technical ownership. SOC2 minimum
moves from Refactor to Rewrite.

Vocabulary scrub:
- Drops references to deleted plugins (prototype-lane, spec-driven-dev,
  /vibe, /package-handoff).
- Replaces "lane" with "zone" / "governed production" / "local MVP
  sandbox" throughout.
- Replaces /.workflow/branch.yaml + /.workflow/handoff.md references
  with HANDOFF.md at the workspace root.

Affects: commands/validate.md, skills/validation-decision/SKILL.md, and
any cross-references in propose/from-design/promote commands, the
proposal-intake and feature-flag-promotion skills, and the spec-refiner
and drift-monitor agents.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: Delete `prototype-lane` and `spec-driven-dev`

**Files:**
- Delete: `plugins/prototype-lane/` (entire directory)
- Delete: `plugins/spec-driven-dev/` (entire directory)

Cross-reference cleanup is intentionally split into Tasks 11–13 (the root docs)
since most lingering refs are in `CLAUDE.md`, `README.md`, `MARKETPLACE_VALIDATION.md`.

- [ ] **Step 1: Sanity-check what's about to be deleted**

```bash
ls plugins/prototype-lane/
ls plugins/spec-driven-dev/
```

Expected: each directory listing matches what was explored during plan
authoring (prototype-lane has `.claude-plugin/`, `agents/`, `commands/`,
`skills/`; spec-driven-dev has `.claude-plugin/`, `hooks/`).

- [ ] **Step 2: Grep the surviving codebase one more time for inbound refs**

```bash
grep -rnE 'prototype-lane|spec-driven-dev|/vibe\b|/package-handoff' \
  --include='*.md' --include='*.json' --include='*.sh' \
  plugins/ .claude-plugin/ \
  CLAUDE.md README.md MARKETPLACE_VALIDATION.md CONSTITUTION.md CONNECTORS.md PRODUCT_SPINE_TEMPLATE.md TECH-STACK.md 2>/dev/null
```

Note the matches. After this task, the only acceptable remaining matches are
in `CLAUDE.md`, `README.md`, `MARKETPLACE_VALIDATION.md`, and `marketplace.json`
— Tasks 11–13 clean those up. Any matches in `plugins/production-lane/`,
`plugins/spine-writer/`, `plugins/handoff-packager/`, or in other plugins
mean a prior task missed a scrub — go back and fix before deleting.

- [ ] **Step 3: Delete the directories**

```bash
rm -rf plugins/prototype-lane plugins/spec-driven-dev
ls plugins/
```

Expected: listing shows exactly: `always-test`, `e22-org`, `handoff-packager`,
`house-style`, `production-lane`, `security-rails`, `spine-writer` — seven
plugins.

- [ ] **Step 4: Commit**

```bash
git add -A plugins/
git commit -m "$(cat <<'EOF'
plugins: delete prototype-lane and spec-driven-dev

Per spec v0.4 §5.1, §13 (prototype-lane skills removed) and the
v0.4 §11.3 reuse list (spec-driven-dev not included).

prototype-lane is replaced by e22-org's natural-language handoff
affordances. /vibe, /package-handoff, /proposal-status, the
change-idea-intake and proposal-glossary skills, and the
intake-clarifier / project-type-detector agents are all gone.

spec-driven-dev's lane-aware spec-pre-gate is obsoleted by v0.4 §10.3
("no minimum test floor during exploration"). always-test still covers
the production test gate.

Cross-reference cleanup in CLAUDE.md, README.md, MARKETPLACE_VALIDATION.md,
and marketplace.json follows in later tasks.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Rewrite root `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md` (repo root)

- [ ] **Step 1: Replace the entire file**

Replace the entire contents of `/Users/alexis-valotaire/Documents/00_Work/TLM/01_Projects/Element_22/e22-plugins/CLAUDE.md` with:

```markdown
# CLAUDE.md — e22-plugins

This repo is the **Element 22 plugin marketplace** for Claude Code, Claude
Chat, and Claude Cowork. It is not a product; it is the substrate every
product Claude session loads.

The always-loaded operating rules live in [`CONSTITUTION.md`](./CONSTITUTION.md).
The full operational spec lives in
[`docs/collaborative-ai-workflow-spec.md`](./docs/collaborative-ai-workflow-spec.md).
When the constitution and the spec disagree, the spec wins.

---

## The workflow in one line

> Let the PO explore locally. Let Claude extract the meaning. Let engineering
> decide what becomes production.

POs install the always-on org plugin and start a brand-new MVP by talking
naturally — no commands, no skills to remember, no GitHub repository, no
branch metadata, no Product Spine maintenance. Engineering keeps full
governance, applied only when the work has been imported into a governed repo.

---

## The three zones

| Zone | Owner | Tooling | Control point |
|---|---|---|---|
| **Local MVP Sandbox** | PO | Claude, local folders, disposable previews | Always-on org plugin guardrails |
| **Handoff / Extraction** | Claude + Dev | `HANDOFF.md` at workspace root, optional assets, optional source export | Dev reviews the handoff packet before code |
| **Governed Production** | Dev | GitHub, PRs, branch protection, CI/CD, review rules | Checks, approvals, rollback |

Zone detection is implemented once in `plugins/e22-org/lib/zone.sh`. A
workspace is **governed** when it's a git repo whose `origin` remote points
at GitHub. Otherwise it's **sandbox**. Hook plugins source this helper and
self-gate; in the sandbox they go silent.

---

## The seven plugins

| Plugin | Profile | What it does |
|---|---|---|
| `e22-org` | always-on (PO + Dev) | Always-loaded `CLAUDE.md` baseline, sandbox guardrails (real PII / prod-DB connection strings), natural-language handoff trigger, shared `lib/zone.sh`. The PO's only required installation. |
| `security-rails` | always-on (PO + Dev) | Universal hard guardrails in both zones — secrets, AWS keys, Stripe live keys, raw-SQL interpolation, force-push, push-to-main. |
| `handoff-packager` | always-on (PO + Dev) | Per-section guidance for filling `HANDOFF.md`. Template lives in `e22-org/templates/`. Triggered by natural language, not a command. |
| `house-style` | always-on (PO + Dev) | Always-loaded tech-stack and latest-stable-version guidance in both zones; lint/format PostToolUse hook gated to governed zone only. |
| `always-test` | production (Dev) | Test-floor enforcement. Zone-gated — silent in sandbox, full enforcement (exit 2 / Stop-continue) in governed repos. |
| `spine-writer` | production (Dev) | Product Spine generation. Zone-gated. `/spine-refresh` refuses in sandbox. |
| `production-lane` | production (Dev) | `/validate` (Harden / Extract / Rewrite / Reject / Continue exploring), `/propose`, `/from-design`, `/promote`. Auto-trigger skills route Dev intent to the right command. |

**Install profiles** (documented; not enforced by the marketplace):

- **PO bundle:** `e22-org`, `security-rails`, `handoff-packager`, `house-style`.
- **Dev bundle:** all seven.

The four "always-on" plugins are safe in both zones; the three "production"
plugins are no-ops in the sandbox so installing the full Dev bundle is also
fine for a PO who wants one install.

---

## Auto-trigger skills

Three skills auto-fire on plain-language intent — all Dev-facing, all in
`production-lane`. POs do not need to know they exist; Devs benefit from
not having to type slash commands when intent is clear.

| Skill | Plugin | Intent it auto-detects | Routes to |
|---|---|---|---|
| `proposal-intake` | production-lane | "let's add X", "implement Y", "ship a change to do Z", "fix bug W", "create a PR for V" | `/propose` |
| `validation-decision` | production-lane | "let's review the handoff for X", "I'll evaluate the MVP", "is this Harden or Extract", "evaluate this prototype" | `/validate` |
| `feature-flag-promotion` | production-lane | "promote X to 50%", "graduate from experimental", "ramp the flag" | `/promote` |
| `spine-staleness-cue` | spine-writer | "the spec is stale", "spine drift", "regenerate the spec for this branch" | `/spine-refresh` |

Routing rules:

- *Exploratory* phrasing in the sandbox ("can we try", "what if we", "show me
  three variants") — Claude responds conversationally; no skill auto-fires.
- *Committed* production phrasing ("we need to ship", "this has to land in
  main") in a governed repo → `proposal-intake` → `/propose`.
- *Reviewing a HANDOFF.md* → `validation-decision`, never `proposal-intake`.
- *Sensitive domains* (auth, payments, PII, permissions, billing, data model):
  every skill refuses to generate production-bound code without explicit
  engineering review.
- *Just venting / asking a question*: do not auto-invoke any skill.

The natural-language handoff trigger ("handoff this", "package this for
dev", "I'm done with the MVP", etc.) is handled by `e22-org`'s
always-loaded `CLAUDE.md` plus its `handoff-cue.sh` UserPromptSubmit hook —
not by an auto-trigger skill. POs never need to know the mechanism.

---

## Hook-based plugins

Four plugins fire on **harness events**, not user wording.

| Plugin | Substrate | Zone gate | Fires on |
|---|---|---|---|
| `e22-org` | PreToolUse (Write/Edit) + UserPromptSubmit | none — both zones | Every edit and prompt |
| `security-rails` | PreToolUse (Write/Edit, Bash) | none — both zones | Every edit and Bash command |
| `always-test` | PostToolUse + Stop | governed only | Every edit and session end |
| `house-style` | PostToolUse | governed only | Every edit |
| `spine-writer` | PostToolUse | governed only | Meaningful edits |

Hooks are hard controls only where the Claude surface supports them — Claude
Code today. On Chat / Cowork / Artifacts the same rules apply as
instructions and reminders in always-loaded `CLAUDE.md` files. That
asymmetry is acceptable because the sandbox cannot deploy to production,
use real customer data, or access production credentials.

Per spec v0.4 §11.2, AI instructions are soft — bypassable. Safety-bearing
rules in the governed zone live in hooks or in the repo contract (branch
protection, CODEOWNERS, CI policies, review rules), never in instructions
alone.

---

## The non-negotiables

Spec v0.4 §12 boundaries that always hold:

1. Local MVP sandboxes do not deploy directly to production.
2. Local MVP sandboxes do not use production credentials or databases.
3. Local MVP sandboxes do not use real customer data or real PII.
4. Live auth, payment, billing, and permission integrations are forbidden
   in sandbox exploration.
5. Prototype code is disposable unless Dev explicitly accepts ownership.
6. `HANDOFF.md` is durable memory for the transition; chat history is not
   canonical.
7. Prototype shortcuts must be labeled in `HANDOFF.md` §9.
8. Production work uses GitHub PR governance.
9. No direct pushes to `main`.
10. Secrets never appear in code, PRs, comments, commit messages,
    `HANDOFF.md`, specs, or chat. Reference them via secret-store variable
    names only.
11. Sensitive production changes require explicit engineering review.
12. Infrastructure and environment-configuration changes require explicit
    human approval before modification.
13. Production safety rules need hard enforcement where possible: CI,
    branch protection, CODEOWNERS, secret scanning, review rules.

---

## When working *in this repo* (the marketplace itself)

This repo's own changes go through normal `feat/*` / `fix/*` branches off
`main`. Changes to a plugin's behavior need a version bump in that
plugin's `plugin.json` and a note in the relevant README or commit
message.

New auto-trigger skills go under `plugins/<plugin>/skills/<skill-name>/SKILL.md`,
follow the existing `validation-decision` shape (trigger phrases in the
`description` frontmatter, *When NOT to trigger* section, *What happens
next* section), and must be listed in the routing table above.

Hook scripts under `plugins/*/hooks/*.sh` must be executable. The
marketplace install does not chmod for you. Hooks parse the hook payload
from stdin with `python3`; if a target environment cannot rely on Python,
swap for `jq` or inline parsing.
```

- [ ] **Step 2: Verify no references to deleted things**

```bash
grep -nE '/vibe\b|/package-handoff|prototype-lane|spec-driven-dev|change-idea-intake|proposal-glossary|\.workflow/branch\.yaml|Keep / Refactor / Redesign' CLAUDE.md
```

Expected: no output.

- [ ] **Step 3: Verify the seven plugins appear**

```bash
for p in e22-org security-rails handoff-packager house-style always-test spine-writer production-lane; do
  grep -q "\`$p\`" CLAUDE.md && echo "found $p" || echo "MISSING $p"
done
```

Expected: seven `found <name>` lines.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
docs: rewrite root CLAUDE.md for the three-zone workflow

Drops the v0.3 two-lane narrative and the auto-trigger skills table
that referenced now-deleted prototype-lane skills. New shape:

- The workflow in one line + the three zones (sandbox / handoff /
  governed production) + zone detection
- The seven plugins, with install profiles (PO bundle / Dev bundle)
- The four surviving auto-trigger skills (all Dev-facing, all in
  production-lane + spine-writer)
- The five hook-based plugins and their zone gates
- The thirteen non-negotiable boundaries from spec v0.4 §12
- Repo conventions for working in this marketplace

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Rewrite `README.md` and tidy the supporting docs

**Files:**
- Modify: `README.md`
- Modify: `MARKETPLACE_VALIDATION.md`
- Modify: `CONNECTORS.md` (small clarification)
- Modify: `PRODUCT_SPINE_TEMPLATE.md` (top-of-file note only)

The README is 696 lines and almost entirely v0.3 narrative. A full inline
rewrite in this plan would be unwieldy. The agent should rewrite the file in
place following the structure below.

- [ ] **Step 1: Rewrite `README.md`**

Replace the entire contents of `README.md` with the following structure
(target: ~250-350 lines; do not aim for parity with the v0.3 README's 696
lines):

```markdown
# e22-plugins

Element 22's plugin marketplace for Claude Code, Claude Chat, and Claude
Cowork — the AI-native collaborative workflow **from local MVP to governed
production**.

> Let the PO explore locally. Let Claude extract the meaning. Let
> engineering decide what becomes production.

This repository is a [Claude Code plugin
marketplace](https://code.claude.com/docs/en/plugin-marketplaces). Installing
it on a workspace gives the team:

- **Three zones**, one workflow: a **Local MVP Sandbox** for Product Owners
  to explore brand-new MVPs without commands or governance overhead; a
  **Handoff / Extraction** zone built around a single `HANDOFF.md`; a
  **Governed Production** zone where the normal engineering controls apply.
- **An always-on organization plugin** (`e22-org`) — the PO's only required
  installation. Provides plain-language affordances, the natural-language
  handoff trigger, sandbox guardrails, and a shared zone detector.
- **Seven plugins** covering both zones. Update a plugin once, every Claude
  session picks it up tomorrow.

The marketplace works on all three Claude surfaces:

- **Claude Chat** — web/mobile, where most POs will start their MVPs.
- **Claude Cowork** — the desktop tool for file and task automation.
- **Claude Code** — the terminal coding agent, where hooks are hard
  controls.

Plugins behave identically across surfaces with one caveat: hooks fire only
where the surface supports them (Claude Code today). On Chat / Cowork the
same rules apply as instructions in always-loaded `CLAUDE.md` files. The
sandbox is safe for instruction-only enforcement because it cannot deploy
to production, use real customer data, or access production credentials.

## The arc of a change

```text
Local MVP Sandbox   →    Handoff / Extraction   →    Governed Production
PO explores              HANDOFF.md generated          PR / CI / review / approval
naturally, fake          from chat + workspace         Dev decides Harden /
data, no commands        evidence; 15 sections;        Extract / Rewrite /
                         5 mandatory                    Reject / Continue
```

Speed lives on the left. Safety lives on the right. The handoff packet is
the bridge.

## Zones and ownership

| Zone | Owner | Tooling | Control point |
|---|---|---|---|
| **Local MVP Sandbox** | PO | Claude, local folders, disposable previews | Always-on org plugin guardrails |
| **Handoff / Extraction** | Claude + Dev | `HANDOFF.md` at workspace root | Dev reviews the packet before code |
| **Governed Production** | Dev | GitHub, PRs, branch protection, CI/CD, review rules | Checks, approvals, rollback |

Zone detection is shared logic in `plugins/e22-org/lib/zone.sh`. A workspace
is **governed** when it is a git repo with an `origin` remote pointing at
GitHub. Otherwise it is **sandbox**.

## The seven plugins

### Always-on (install for PO bundle and Dev bundle)

| Plugin | What it does |
|---|---|
| [`e22-org`](./plugins/e22-org) | The always-on org plugin. Always-loaded `CLAUDE.md` baseline, sandbox guardrails (PII / prod-DB connection strings), natural-language handoff trigger, the shared zone-detection helper. The PO's only required installation. |
| [`security-rails`](./plugins/security-rails) | Universal hard guardrails in both zones — secrets, AWS keys, Stripe live keys, raw-SQL interpolation, force-push, push-to-main. |
| [`handoff-packager`](./plugins/handoff-packager) | Per-section guidance for filling `HANDOFF.md` when the handoff trigger fires. Single-file output (spec v0.4 §7.2). No slash command. |
| [`house-style`](./plugins/house-style) | Always-loaded tech-stack and latest-stable-version guidance in both zones; lint/format PostToolUse hook gated to the governed zone. |

### Production (install for Dev bundle only)

| Plugin | What it does |
|---|---|
| [`always-test`](./plugins/always-test) | Test-floor enforcement in governed repos. Zone-gated — silent in sandbox; exit-2 on PostToolUse miss and Stop-continue on session end when governed. |
| [`spine-writer`](./plugins/spine-writer) | Product Spine generation. Zone-gated PostToolUse nudge. `/spine-refresh` refuses in sandbox. |
| [`production-lane`](./plugins/production-lane) | `/validate` (Harden / Extract / Rewrite / Reject / Continue exploring), `/propose`, `/from-design`, `/promote`. Auto-trigger skills route Dev intent to the right command. SOC2 governance overlay applies. |

## Install

### PO bundle (sandbox-safe four)

```bash
claude plugin marketplace add element22llc/e22-plugins
claude plugin install e22-org@e22-plugins
claude plugin install security-rails@e22-plugins
claude plugin install handoff-packager@e22-plugins
claude plugin install house-style@e22-plugins
```

### Dev bundle (all seven)

```bash
claude plugin marketplace add element22llc/e22-plugins
claude plugin install e22-org@e22-plugins
claude plugin install security-rails@e22-plugins
claude plugin install handoff-packager@e22-plugins
claude plugin install house-style@e22-plugins
claude plugin install always-test@e22-plugins
claude plugin install spine-writer@e22-plugins
claude plugin install production-lane@e22-plugins
```

POs may also install the full Dev bundle without issue — the three
production plugins are silent in the sandbox.

## The PO experience

1. Install the PO bundle.
2. Open Claude on any supported surface. Say: *"Build me an MVP for a
   restaurant reservations app."*
3. Iterate naturally: *"add a waitlist feature"*, *"try a different
   checkout"*, *"show me three variants of the homepage."*
4. When you're done, say: *"handoff this to dev"* or *"package this for
   engineering"* or *"I'm done with the MVP."*
5. Claude writes `HANDOFF.md` at your workspace root. Send the file (and
   any screenshots in `assets/`) to your engineering counterpart.

There are no commands to remember. There is no GitHub setup. There is no
Product Spine to maintain. The handoff is what Dev reads first.

## The Dev experience

When you receive `HANDOFF.md`:

1. Open `/validate` (or just say *"let's review the handoff for X"* — the
   `validation-decision` skill auto-fires).
2. Make one of five decisions: **Harden / Extract / Rewrite / Reject /
   Continue exploring** (spec v0.4 §7.4). For brand-new MVPs the default is
   Extract or Rewrite; Harden requires you to accept ownership of the
   prototype's technical choices.
3. If Harden or Extract: import the relevant source into a governed repo
   and run `/propose`.
4. If Rewrite: open a fresh PR off `main`; use `HANDOFF.md` as the spec.
5. If Reject: respond with reasoning grounded in `HANDOFF.md §15` so the
   PO knows what would change the decision.
6. If Continue exploring: reply with what specifically is unclear or
   unfinished — usually tied to `HANDOFF.md §13` (open questions) and §8
   (risks).

Once you accept the work, normal engineering rules apply: PR, CI, review,
approval, rollback path, secret scanning, branch protection, CODEOWNERS,
sensitive-area review.

## Where to learn more

- [`CONSTITUTION.md`](./CONSTITUTION.md) — always-loaded baseline for every
  Claude session in this org.
- [`docs/collaborative-ai-workflow-spec.md`](./docs/collaborative-ai-workflow-spec.md)
  — the full operational spec (v0.4).
- [`TECH-STACK.md`](./TECH-STACK.md) — preferred languages and tooling.
- [`CONNECTORS.md`](./CONNECTORS.md) — connector requirements per zone.
- [`PRODUCT_SPINE_TEMPLATE.md`](./PRODUCT_SPINE_TEMPLATE.md) — the
  durable-spec template, used after the work is imported into a governed
  repo.
- [`MARKETPLACE_VALIDATION.md`](./MARKETPLACE_VALIDATION.md) — marketplace
  conformance and version baselines.

## Versions

| Plugin | Version |
|---|---|
| `e22-org` | 0.1.0 |
| `security-rails` | 0.2.1 |
| `handoff-packager` | 0.2.0 |
| `house-style` | 0.2.0 |
| `always-test` | 0.3.0 |
| `spine-writer` | 0.2.0 |
| `production-lane` | 0.3.0 |
```

- [ ] **Step 2: Verify the README**

```bash
grep -nE '/vibe\b|/package-handoff|prototype-lane|spec-driven-dev|Keep / Refactor / Redesign|two lanes' README.md
```

Expected: no output.

```bash
for p in e22-org security-rails handoff-packager house-style always-test spine-writer production-lane; do
  grep -q "\`$p\`" README.md && echo "found $p" || echo "MISSING $p"
done
```

Expected: seven `found <name>` lines.

- [ ] **Step 3: Rewrite `MARKETPLACE_VALIDATION.md`**

Replace the entire contents of `MARKETPLACE_VALIDATION.md` with:

```markdown
# Marketplace conformance — `e22-plugins`

Validated against: <https://code.claude.com/docs/en/plugin-marketplaces> (fetched 2026-05-19).
Last verified locally: `claude plugin validate .` should be re-run after the
2026-05-25 simplified-workflow refactor (this commit).

## Status

Conformant in design. Shipping seven plugins reflecting the v0.4 spec
(simplified, three-zone workflow):

- Always-on (sandbox + governed): `e22-org`, `security-rails`,
  `handoff-packager`, `house-style`
- Production (governed only): `always-test`, `spine-writer`, `production-lane`

The v0.3 lane plugins (`prototype-lane`, `spec-driven-dev`) were removed in
the same change set.

## Naming

| Surface              | Value                                                | Where it's set                                              |
| -------------------- | ---------------------------------------------------- | ----------------------------------------------------------- |
| Marketplace name     | `e22-plugins`                                        | `.claude-plugin/marketplace.json` → `name`                  |
| Plugin names         | `e22-org`, `security-rails`, `handoff-packager`, `house-style`, `always-test`, `spine-writer`, `production-lane` | each `plugins/<name>/.claude-plugin/plugin.json` and the marketplace entry |
| Install handles      | `<name>@e22-plugins`                                 | derived                                                     |
| Suggested GitHub repo| `element22llc/e22-plugins`                           | external — directory on disk is `e22-plugins/`              |

Reserved-name check: none of the plugin names collide with the Anthropic
reserved list, and none include the word `claude`.

## Layout

```
e22-plugins/
├── .claude-plugin/
│   └── marketplace.json
├── plugins/
│   ├── e22-org/
│   │   ├── .claude-plugin/plugin.json
│   │   ├── CLAUDE.md
│   │   ├── hooks/{hooks.json,sandbox-guardrails.sh,handoff-cue.sh}
│   │   ├── lib/zone.sh
│   │   └── templates/HANDOFF.md.template
│   ├── security-rails/
│   │   ├── .claude-plugin/plugin.json
│   │   └── hooks/{hooks.json,scan-content.sh,scan-bash.sh}
│   ├── handoff-packager/
│   │   ├── .claude-plugin/plugin.json
│   │   └── CLAUDE.md
│   ├── house-style/
│   │   ├── .claude-plugin/plugin.json
│   │   ├── CLAUDE.md
│   │   └── hooks/{hooks.json,run-house-style.sh}
│   ├── always-test/
│   │   ├── .claude-plugin/plugin.json
│   │   └── hooks/{hooks.json,check-test-coverage.sh,remind-smoke-test.sh}
│   ├── spine-writer/
│   │   ├── .claude-plugin/plugin.json
│   │   ├── agents/spine-extractor.md
│   │   ├── commands/spine-refresh.md
│   │   ├── hooks/{hooks.json,maybe-refresh.sh}
│   │   └── skills/spine-staleness-cue/SKILL.md
│   └── production-lane/
│       ├── .claude-plugin/plugin.json
│       ├── agents/{spec-refiner,drift-monitor}.md
│       ├── commands/{validate,propose,from-design,promote}.md
│       └── skills/{validation-decision,proposal-intake,feature-flag-promotion}/SKILL.md
├── templates/
│   ├── claude-settings.json
│   └── README.md
├── CONSTITUTION.md
├── PRODUCT_SPINE_TEMPLATE.md
├── MARKETPLACE_VALIDATION.md
└── README.md
```

## Install and test

From the repo root:

```bash
claude plugin validate .
claude plugin marketplace add ./
# PO bundle:
claude plugin install e22-org@e22-plugins
claude plugin install security-rails@e22-plugins
claude plugin install handoff-packager@e22-plugins
claude plugin install house-style@e22-plugins
# Dev bundle adds:
claude plugin install always-test@e22-plugins
claude plugin install spine-writer@e22-plugins
claude plugin install production-lane@e22-plugins
```

Once on GitHub at `element22llc/e22-plugins`:

```bash
claude plugin marketplace add element22llc/e22-plugins
# install handles above with the @e22-plugins suffix
```

## Hooks notes

- Every hook script under `plugins/*/hooks/*.sh` must be executable
  (`chmod +x`). The marketplace install does not chmod for you.
- Hook scripts use `${CLAUDE_PLUGIN_ROOT}` for portable referencing.
- Zone-gated hooks source `${CLAUDE_PLUGIN_ROOT}/../e22-org/lib/zone.sh`.
  This means `e22-org` must be installed for the other plugins' hooks to
  work — install it first, or always (it's part of both bundles).
- Hooks parse the hook payload from stdin with `python3` (assumed present).

## Outstanding manual steps

1. **Re-run `claude plugin validate .`** locally after this commit to
   re-establish a clean validation timestamp.
2. **Push to GitHub** when the branch is ready.

## Things to know for later

- **Adding an eighth plugin.** Create
  `plugins/<new-plugin>/.claude-plugin/plugin.json` and a new entry in
  `marketplace.json#plugins` with `"source": "./plugins/<new-plugin>"`.
  Use explicit repo-rooted paths (we tried `metadata.pluginRoot` and the
  Claude.ai org sync did not honor it).
- **Versioning.** Bump on every functional change or users won't see
  updates. Current versions: see README.md "Versions" table.
- **Zone detection.** All zone-gated hooks source
  `plugins/e22-org/lib/zone.sh`. The discriminator is the `origin` remote
  pointing at GitHub. Don't change this casually — every zone-gated plugin
  depends on it.
- **Release channels.** When ready, create two marketplaces pointing at the
  same repo on different refs (`stable`, `latest`) and assign them via
  managed settings.
- **Private repo auto-updates.** Background updates need `GITHUB_TOKEN` or
  `GH_TOKEN` in the user's env.
```

- [ ] **Step 4: Clarify `CONNECTORS.md` (small edit)**

Open `CONNECTORS.md` and find the introduction section near the top. The
current intro likely refers to GitHub-only requirements without zone
language. Make this clarification once, near the top of the file (insert
after the document title, before the first major section):

```markdown
## Zone applicability

The connector requirements below apply in the **governed-production zone**
only. The **local MVP sandbox** (the PO's exploration zone) is
connector-free — no GitHub connector required, no real-data integrations.
Zone detection lives in `plugins/e22-org/lib/zone.sh`. See `CLAUDE.md` and
the spec for the full zone model.
```

Then scan the rest of the file:

```bash
grep -nE '/vibe\b|/package-handoff|prototype-lane|spec-driven-dev|Keep / Refactor / Redesign' CONNECTORS.md
```

If any matches appear, scrub them: replace decision-label references with
the new five labels; replace deleted plugin/command names with `e22-org` +
`HANDOFF.md` flow.

- [ ] **Step 5: Add a sandbox note at the top of `PRODUCT_SPINE_TEMPLATE.md`**

Open `PRODUCT_SPINE_TEMPLATE.md` and insert immediately after the document
title (before any other content):

```markdown
> **Scope:** This template is for **governed-production** work after Dev
> has imported the MVP into a repo. It is not required, and not
> recommended, during the local MVP sandbox (PO exploration) phase. The
> sandbox uses `HANDOFF.md` as its single durable artifact (spec v0.4
> §7.2). The Product Spine becomes useful once production-bound code lives
> in a versioned repo and needs durable spec memory.
```

- [ ] **Step 6: Final cross-check**

```bash
grep -rnE 'two lanes|prototype lane|production lane|/vibe\b|/package-handoff|prototype-lane|spec-driven-dev|Keep / Refactor / Redesign' \
  README.md CLAUDE.md MARKETPLACE_VALIDATION.md CONNECTORS.md PRODUCT_SPINE_TEMPLATE.md CONSTITUTION.md TECH-STACK.md 2>/dev/null
```

Expected: no output. If matches remain, edit them out.

- [ ] **Step 7: Commit**

```bash
git add README.md MARKETPLACE_VALIDATION.md CONNECTORS.md PRODUCT_SPINE_TEMPLATE.md
git commit -m "$(cat <<'EOF'
docs: rewrite README + MARKETPLACE_VALIDATION; scrub CONNECTORS + spine template

README.md — full rewrite. New three-zone narrative, install profiles
(PO bundle vs Dev bundle), PO and Dev experience walkthroughs, versions
table. Drops the v0.3 two-lane diagram and the prototype-lane / spec-
driven-dev references.

MARKETPLACE_VALIDATION.md — full rewrite for the 7-plugin shape,
updated layout tree, updated install commands, updated hooks-notes
section calling out the zone.sh dependency.

CONNECTORS.md — single small clarification: governed-zone scope. No
behavior change.

PRODUCT_SPINE_TEMPLATE.md — adds a scope note clarifying it is for
governed-production use, not for PO sandbox exploration.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: Update `marketplace.json` to the 7-plugin shape

**Files:**
- Modify: `.claude-plugin/marketplace.json`

This is last because validation depends on every plugin's manifest being
correct (Tasks 4–9 bump those manifests).

- [ ] **Step 1: Replace the manifest**

Replace the entire contents of `.claude-plugin/marketplace.json` with:

```json
{
  "name": "e22-plugins",
  "description": "Element 22 plugin catalog — three zones (Local MVP Sandbox, Handoff, Governed Production), one always-on org plugin, governance only where it earns its keep. Seven plugins for Claude Code, Claude Chat, and Claude Cowork.",
  "owner": {
    "name": "Element 22 Platform",
    "email": "alexis.valotaire@element-22.com"
  },
  "plugins": [
    {
      "name": "e22-org",
      "source": "./plugins/e22-org",
      "description": "Always-on organization plugin. The PO's single required installation. Always-loaded CLAUDE.md, sandbox guardrails (real PII, prod-DB connection strings), natural-language handoff trigger, shared lib/zone.sh zone detector. Installed for both PO and Dev bundles.",
      "category": "always-on",
      "keywords": ["element-22", "org-plugin", "sandbox", "handoff", "zone-detection", "always-loaded"]
    },
    {
      "name": "security-rails",
      "source": "./plugins/security-rails",
      "description": "Universal hard guardrails in both zones — secrets, AWS access keys, Stripe live keys, raw-SQL interpolation, force-push, push-to-main, prod database clients. Pairs with Anthropic's security-guidance plugin for code-injection patterns. Installed for both bundles.",
      "category": "always-on",
      "keywords": ["element-22", "house-rule", "security", "guardrails"]
    },
    {
      "name": "handoff-packager",
      "source": "./plugins/handoff-packager",
      "description": "Per-section guidance for filling HANDOFF.md when e22-org's natural-language handoff trigger fires. Single-file output per spec v0.4 §7.2. No slash command. Installed for both bundles.",
      "category": "always-on",
      "keywords": ["element-22", "handoff", "mvp", "single-file"]
    },
    {
      "name": "house-style",
      "source": "./plugins/house-style",
      "description": "Tech-stack adherence and latest-stable-version guidance as always-loaded CLAUDE.md (both zones); lint/format PostToolUse hook gated to the governed-production zone. Installed for both bundles.",
      "category": "always-on",
      "keywords": ["element-22", "house-rule", "lint", "format", "tech-stack", "conventions"]
    },
    {
      "name": "always-test",
      "source": "./plugins/always-test",
      "description": "Test-floor enforcement in governed-production repos: every new endpoint, screen, or background job needs at least one smoke test. Zone-gated — silent in sandbox, exit-2 / Stop-continue when governed. Dev bundle only.",
      "category": "production",
      "keywords": ["element-22", "house-rule", "tests", "smoke-tests", "ci", "zone-gated"]
    },
    {
      "name": "spine-writer",
      "source": "./plugins/spine-writer",
      "description": "Product Spine generation for governed-production work. /spine-refresh (manual) and a PostToolUse hook (automatic, on meaningful file changes). Zone-gated — silent and refuses in sandbox per spec v0.4 §10.3. Dev bundle only.",
      "category": "production",
      "keywords": ["element-22", "house-rule", "spine", "spec", "drift", "zone-gated"]
    },
    {
      "name": "production-lane",
      "source": "./plugins/production-lane",
      "description": "Governed-production plugin for engineers. /validate is the Harden / Extract / Rewrite / Reject / Continue-exploring gate (spec v0.4 §7.4) that turns a HANDOFF.md into a production proposal. /propose, /from-design, /promote drive the production lifecycle. Auto-trigger skills route Dev intent. SOC2 overlay applies. Dev bundle only.",
      "category": "production",
      "keywords": ["element-22", "proposals", "validation", "governance", "soc2", "feature-flags", "production"]
    }
  ]
}
```

- [ ] **Step 2: Validate as JSON**

```bash
python3 -c 'import json; print(len(json.load(open(".claude-plugin/marketplace.json"))["plugins"]))'
```

Expected output: `7`.

- [ ] **Step 3: Verify every named plugin source path exists**

```bash
for src in $(python3 -c 'import json; print("\n".join(p["source"] for p in json.load(open(".claude-plugin/marketplace.json"))["plugins"]))'); do
  test -d "$src" && echo "OK $src" || echo "MISSING $src"
done
```

Expected: seven `OK ./plugins/<name>` lines.

- [ ] **Step 4: Verify the `category` field is consistent with the install profiles**

```bash
python3 -c '
import json
m = json.load(open(".claude-plugin/marketplace.json"))
always_on = [p["name"] for p in m["plugins"] if p["category"] == "always-on"]
prod = [p["name"] for p in m["plugins"] if p["category"] == "production"]
print("always-on:", always_on)
print("production:", prod)
assert set(always_on) == {"e22-org", "security-rails", "handoff-packager", "house-style"}, always_on
assert set(prod) == {"always-test", "spine-writer", "production-lane"}, prod
print("OK")
'
```

Expected output ends with `OK`.

- [ ] **Step 5: If `claude` CLI is available, run the marketplace validator**

```bash
which claude && claude plugin validate . || echo "claude CLI not on PATH — skip"
```

If `claude plugin validate .` reports any error, fix the manifest field it
points at; if `claude` is not on PATH, the JSON-level checks in steps 2–4 are
sufficient for this plan's purposes.

- [ ] **Step 6: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "$(cat <<'EOF'
marketplace: shrink to seven plugins; add category field

Per the simplified-workflow refactor (v0.4 spec). Drops the v0.3
prototype-lane and spec-driven-dev entries. Adds e22-org as the new
always-on organization plugin.

The category field documents the intended install profile (always-on =
PO + Dev bundle; production = Dev bundle only) but is not enforced —
POs may install everything; production plugins are silent in the
sandbox.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: Final sweep + smoke-test

**Files:** none modified; verification only.

- [ ] **Step 1: Repo-wide grep for residual v0.3 vocabulary**

```bash
grep -rnE '/vibe\b|/package-handoff|prototype-lane|spec-driven-dev|change-idea-intake|proposal-glossary|intake-clarifier|project-type-detector|Keep / Refactor / Redesign|\.workflow/branch\.yaml' \
  --include='*.md' --include='*.json' --include='*.sh' \
  . 2>/dev/null \
  | grep -v 'docs/superpowers/'
```

Expected: no output. (Plan and design docs in `docs/superpowers/` legitimately
mention these names in the context of the refactor itself; they're excluded.)

If any output appears, scrub the matched files and amend (or follow-on commit).

- [ ] **Step 2: Verify every hook script is executable**

```bash
find plugins -name '*.sh' -type f ! -perm -u+x
```

Expected: no output. If any file appears, `chmod +x` it and commit.

- [ ] **Step 3: Smoke-test zone.sh from a hook script's perspective**

Pretend we're a hook in `always-test`. From the repo root:

```bash
( cd plugins/always-test && \
  CLAUDE_PLUGIN_ROOT="$(pwd)" \
  bash -c 'source "${CLAUDE_PLUGIN_ROOT}/../e22-org/lib/zone.sh"; e22_zone' )
```

Expected: `governed` (this repo has a GitHub remote — verify with
`git remote get-url origin`).

- [ ] **Step 4: Verify the new plugin count matches everywhere**

```bash
echo -n "marketplace.json: "; python3 -c 'import json; print(len(json.load(open(".claude-plugin/marketplace.json"))["plugins"]))'
echo -n "plugins/ dir count: "; ls -d plugins/*/ | wc -l | tr -d ' '
echo -n "README.md versions table: "; grep -cE '^\| `[a-z][a-z0-9-]+` *\|' README.md
echo -n "MARKETPLACE_VALIDATION.md plugin-names row: "; grep -E '^\| Plugin names' MARKETPLACE_VALIDATION.md | tr ',' '\n' | wc -l | tr -d ' '
```

Expected:
- marketplace.json plugins: `7`
- plugins/ dir count: `7`
- README.md versions table: `7`
- MARKETPLACE_VALIDATION.md plugin-names row: `7` (seven comma-separated names)

If any number is wrong, fix and amend.

- [ ] **Step 5: Verify `git status` is clean**

```bash
git status --short
```

Expected: empty output.

- [ ] **Step 6: Inspect the resulting commit history for the refactor**

```bash
git log --oneline ae4bdb5..HEAD
```

Expected: a clean sequence of ~13 commits, one per task in this plan, all
authored against `feat/simplify-workflow`. (Task 14 produces no commit if
all checks pass — it's verification only.)

- [ ] **Step 7: Final note for the operator**

If `claude plugin validate .` is available locally, run it now and capture
any warnings. If everything is clean, the branch is ready for PR review
against `main` per the constitution's repo conventions.

---

## Self-review

Run through this checklist after writing every task above.

**1. Spec coverage.** Walk each section of `docs/superpowers/specs/2026-05-25-simplified-workflow-refactor-design.md` and point to a task:

- §3 New `e22-org` plugin → Tasks 1, 2, 3 ✓
- §4.1 `handoff-packager` rewrite → Task 8 ✓
- §4.2 `house-style` rewrite → Task 6 ✓
- §5.1 `always-test` self-gate → Task 4 ✓
- §5.2 `spine-writer` self-gate → Task 5 ✓
- §5.3 `production-lane` decision-matrix + vocab scrub → Task 9 ✓
- §5.4 `security-rails` patch → Task 7 ✓
- §6 Deletions (`prototype-lane`, `spec-driven-dev`) → Task 10 ✓
- §7.1 `marketplace.json` rewrite → Task 13 ✓
- §7.2 Repo-level docs → Tasks 11 (CLAUDE.md), 12 (README + MARKETPLACE_VALIDATION + CONNECTORS + spine template) ✓
- §8 Version-bump summary → Tasks 4–9 each bump in-task ✓
- §9 Implementation order → matches Task 1 → 14 numbering ✓

No gaps.

**2. Placeholder scan.** No `TBD`, no `TODO`, no "implement later", no "similar to Task N". Every code block contains the actual content. Every command shows expected output.

**3. Type consistency.** Function/symbol names match across tasks:
- `e22_zone` (defined Task 1; sourced in Tasks 4, 5, 6, 14) ✓
- `e22_require_governed` (defined Task 1; sourced in Tasks 4, 5, 6) ✓
- `HANDOFF.md.template` (created Task 1; referenced in Tasks 2, 3, 8) ✓
- Decision labels Harden / Extract / Rewrite / Reject / Continue exploring (introduced Task 9 §1(b); referenced Tasks 11, 12) ✓
- Version numbers in commit messages match the manifest edits in the same task ✓

**4. Ordering.** Task 1 (zone.sh) must land before Tasks 4–6 (which source it). Task 10 (deletions) must land after Task 9 (which still references prototype source branches in some old text being scrubbed). Task 13 (marketplace.json) lands last because the JSON references every other plugin's `source` path. Order verified.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-25-simplified-workflow-refactor-plan.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?

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

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

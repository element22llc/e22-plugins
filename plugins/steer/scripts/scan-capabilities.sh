#!/usr/bin/env sh
# scan-capabilities.sh — read-only capability-prerequisite detector for
# /steer:sync's capability-repair step (templates/reference/CAPABILITIES.md).
#
# WHAT IT READS
#   $1  repo-root        — a managed repo to inspect (default: ".")
#   $2  plugin-root      — the plugin source for byte-identical comparisons
#                          (default: $CLAUDE_PLUGIN_ROOT, else this script's
#                          parent dir). Needed only for `verbatim` capabilities.
#
# WHAT IT COMPARES
#   For each capability in CAPABILITIES.md it checks WHOLE-FILE presence and a
#   literal WIRED-WHEN marker (a `grep` token that proves the capability is
#   actually enabled, not just that the file exists). Verbatim files
#   (the version-pin scripts) are compared byte-for-byte (`cmp`) against their
#   plugin source. Stack/tracker conditionality that the helper can resolve
#   deterministically (Node vs Python stack; GitHub-Issues tracker) is folded in
#   as `n/a`; anything needing judgment (does this product need backing
#   services?) is reported raw and left to the skill — the same over-report →
#   skill-prunes division as template-reconcile.sh.
#
# WHETHER IT MODIFIES ANYTHING
#   No. It only reads the repo + plugin source and writes status lines to stdout.
#   Nothing is written outside stdout/stderr; the repo is never touched.
#
# OUTPUT (stdout)
#   One TAB-separated line per capability:  <id>\t<status>\t<files>
#   plus one fingerprint line:              stack\t<node|python|polyglot|none>\t-
#   status ∈ present-wired | absent | mis-wired | disabled | n/a
#     present-wired  file(s) present AND the wired-when marker holds
#     absent         a required file is missing
#     mis-wired      file present but the capability is not actually enabled
#                    (no marker, or a verbatim copy drifted from the plugin)
#     disabled       deliberately turned off in-repo (respected, never repaired)
#     n/a            the capability's conditional predicate does not apply here
#   A gap (absent / mis-wired) is reported on STDOUT, NEVER via a nonzero exit,
#   so a skill running this through a tool's Bash wrapper does not see a normal
#   "gaps found" run reported as a failure.
#
# EXIT CODES
#   0  ran OK — read stdout for the per-capability verdicts.
#   2  usage error — too many arguments.
#   3  repo-root is missing or unreadable.
#
# SECURITY: read-only; never executes repo content; no network; no jq.
#   Diagnostics name the path + capability id, never file contents.
#
# Usage:
#   sh scan-capabilities.sh [repo-root] [plugin-root]
#
# NOTE: this helper is plugin-internal (a /steer:sync tool). It is deliberately
# NOT shipped into consumer repos, so it carries no byte-identical-copy
# obligation. Keep the capability set here in lockstep with CAPABILITIES.md.

set -u

usage() {
	echo "usage: scan-capabilities.sh [repo-root] [plugin-root]" >&2
	exit 2
}

[ "$#" -le 2 ] || usage

ROOT="${1:-.}"
HERE="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
PLUGIN="${2:-${CLAUDE_PLUGIN_ROOT:-${HERE%/scripts}}}"

[ -d "$ROOT" ] && [ -r "$ROOT" ] || {
	echo "scan-capabilities: cannot read repo-root: $ROOT" >&2
	exit 3
}

emit() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }

# Literal marker present in a file? (read-only; missing file -> false)
has() { [ -f "$ROOT/$1" ] && grep -q "$2" "$ROOT/$1" 2>/dev/null; }
exists() { [ -e "$ROOT/$1" ]; }

# --- stack fingerprint (drives Node/Python conditionality) ---
_node=false
_py=false
{ [ -f "$ROOT/package.json" ] || [ -f "$ROOT/pnpm-workspace.yaml" ]; } && _node=true
{ [ -f "$ROOT/pyproject.toml" ] || ls "$ROOT"/*/pyproject.toml >/dev/null 2>&1; } && _py=true
if $_node && $_py; then
	stack=polyglot
elif $_node; then
	stack=node
elif $_py; then
	stack=python
else
	stack=none
fi
emit "stack" "$stack" "-"

# --- plugin-enabled-local — local sessions load steer ---
# A `false` value is a deliberate opt-off and is respected, never repaired.
F=".claude/settings.json"
if ! exists "$F"; then
	emit "plugin-enabled-local" "absent" "$F"
elif grep -Eq '"steer@e22-plugins"[[:space:]]*:[[:space:]]*false' "$ROOT/$F" 2>/dev/null; then
	emit "plugin-enabled-local" "disabled" "$F"
elif grep -Eq '"steer@e22-plugins"[[:space:]]*:[[:space:]]*true' "$ROOT/$F" 2>/dev/null; then
	emit "plugin-enabled-local" "present-wired" "$F"
else
	emit "plugin-enabled-local" "mis-wired" "$F"
fi

# --- delivery-mode-declared — explicit delivery mode in CLAUDE.md ---
# The commit-autonomy + issue-first hooks read a `steer:delivery-mode=` marker on
# the product CLAUDE.md and FAIL OPEN to pr-flow when it is absent — so a repo
# bootstrapped before the marker existed runs implicit pr-flow and the solo-trunk
# choice is never surfaced. Wired only when the marker is explicitly present; an
# absent CLAUDE.md is a deeper problem and reported as such. Always applies (every
# managed repo has a CLAUDE.md and runs in some delivery mode). The repair is a
# human decision (which mode) — the skill proposes, never picks one.
F="CLAUDE.md"
if ! exists "$F"; then
	emit "delivery-mode-declared" "absent" "$F"
elif has "$F" "steer:delivery-mode="; then
	emit "delivery-mode-declared" "present-wired" "$F"
else
	emit "delivery-mode-declared" "mis-wired" "$F"
fi

# --- in-ci-plugin-loading — @claude CI runs under steer standards ---
# Wired only via the action's plugin_marketplaces input; an enabledPlugins block
# does NOT count (trust-dialog gated, no-ops in headless CI).
F=".github/workflows/claude.yml"
if ! exists "$F"; then
	emit "in-ci-plugin-loading" "absent" "$F"
elif has "$F" "plugin_marketplaces"; then
	emit "in-ci-plugin-loading" "present-wired" "$F"
else
	emit "in-ci-plugin-loading" "mis-wired" "$F"
fi

# --- version-pin-enforcement — policy + verbatim scanner scripts ---
# scripts are contractually byte-identical to the plugin source.
P_POLICY="policy/versions.yml"
P_SCAN="scripts/scan-version-pins.sh"
P_LIB="scripts/version-policy.sh"
vp_files="$P_POLICY,$P_SCAN,$P_LIB"
if ! exists "$P_POLICY"; then
	emit "version-pin-enforcement" "absent" "$vp_files"
elif ! exists "$P_SCAN" || ! exists "$P_LIB"; then
	emit "version-pin-enforcement" "mis-wired" "$vp_files"
elif ! cmp -s "$ROOT/$P_SCAN" "$PLUGIN/scripts/scan-version-pins.sh" 2>/dev/null ||
	! cmp -s "$ROOT/$P_LIB" "$PLUGIN/hooks/lib/version-policy.sh" 2>/dev/null; then
	# A drifted verbatim copy: present but no longer enforces the current policy.
	emit "version-pin-enforcement" "mis-wired" "$vp_files"
else
	emit "version-pin-enforcement" "present-wired" "$vp_files"
fi

# --- drift-gate — CI hygiene job + PR-template checklists ---
F=".github/workflows/ci.yml"
PRT=".github/pull_request_template.md"
dg_files="$F,$PRT"
if ! exists "$F"; then
	emit "drift-gate" "absent" "$dg_files"
elif has "$F" "scan-version-pins.sh" && exists "$PRT"; then
	emit "drift-gate" "present-wired" "$dg_files"
else
	emit "drift-gate" "mis-wired" "$dg_files"
fi

# --- branch-protection-policy — machine-readable gate description ---
F="policy/branch-protection.yml"
if exists "$F"; then
	emit "branch-protection-policy" "present-wired" "$F"
else
	emit "branch-protection-policy" "absent" "$F"
fi

# --- toolchain-pin — mise toolchain + lock (lock contents NOT compared) ---
mt="mise.toml"
ml="mise.lock"
if ! exists "$mt"; then
	emit "toolchain-pin" "absent" "$mt,$ml"
elif ! exists "$ml"; then
	emit "toolchain-pin" "mis-wired" "$mt,$ml"
else
	emit "toolchain-pin" "present-wired" "$mt,$ml"
fi

# --- node-tooling — lint/format baseline (Node stack only) ---
nt_files="biome.json,configs/tsconfig.base.json"
if [ "$stack" = "python" ] || [ "$stack" = "none" ]; then
	emit "node-tooling" "n/a" "$nt_files"
elif exists "biome.json"; then
	emit "node-tooling" "present-wired" "$nt_files"
else
	emit "node-tooling" "absent" "$nt_files"
fi

# --- github-issue-forms — PO-friendly Issue Forms (GitHub-Issues tracker) ---
F=".github/ISSUE_TEMPLATE"
if grep -Eq '^[[:space:]]*system:[[:space:]]*github\b' "$ROOT/spec/tracker.md" 2>/dev/null; then
	if exists "$F/config.yml"; then
		emit "github-issue-forms" "present-wired" "$F"
	else
		emit "github-issue-forms" "absent" "$F"
	fi
else
	emit "github-issue-forms" "n/a" "$F"
fi

# --- backing-services-compose — local services (judgment: skill asks) ---
# Whether a product NEEDS backing services is not deterministically knowable, so
# absence is reported raw and the skill proposes only after confirming.
F="compose.yaml"
if exists "$F"; then
	emit "backing-services-compose" "present-wired" "$F"
else
	emit "backing-services-compose" "absent" "$F"
fi

# --- worktree-port-isolation — collision-free parallel worktrees ---
# Applicable only where a local runtime binds host ports: a compose.yaml is
# present OR the stack is Node/Python. Wired when the deriver script exists AND
# mise.toml sources it (per-worktree COMPOSE_PROJECT_NAME + host-port offset).
WTE="scripts/worktree-env.sh"
WT_MT="mise.toml"
wt_files="$WTE,$WT_MT"
if ! exists "compose.yaml" && [ "$stack" = "none" ]; then
	emit "worktree-port-isolation" "n/a" "$wt_files"
elif ! exists "$WTE"; then
	emit "worktree-port-isolation" "absent" "$wt_files"
elif has "$WT_MT" "worktree-env.sh"; then
	emit "worktree-port-isolation" "present-wired" "$wt_files"
else
	emit "worktree-port-isolation" "mis-wired" "$wt_files"
fi

exit 0

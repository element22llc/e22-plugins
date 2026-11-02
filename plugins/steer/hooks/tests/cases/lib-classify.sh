#!/usr/bin/env sh
# shellcheck disable=SC2015,SC2034,SC2153,SC2154 # lib.sh idioms, and names it assigns
. "$(dirname -- "$0")/../lib.sh"

# --- classifier ---
assert_eq "classify ts" "$(steer_classify_path src/app.ts)" "implementation"
assert_eq "classify tf" "$(steer_classify_path infra/main.tf)" "operations"
assert_eq "classify compose" "$(steer_classify_path compose.yaml)" "operations"
assert_eq "classify .env" "$(steer_classify_path .env)" "operations"
assert_eq "classify Makefile" "$(steer_classify_path Makefile)" "operations"
assert_eq "classify toml" "$(steer_classify_path mise.toml)" "operations"
assert_eq "classify Dockerfile" "$(steer_classify_path Dockerfile)" "operations"
assert_eq "classify md" "$(steer_classify_path README.md)" "documentation"
assert_eq "classify lock" "$(steer_classify_path uv.lock)" "lockfile"
assert_eq "classify generated" "$(steer_classify_path dist/app.js)" "generated"
assert_eq "classify spec" "$(steer_classify_path spec/features/x/intent.md)" "spec"
assert_eq "classify unknown" "$(steer_classify_path data.bin)" "unknown"

finish

# shellcheck shell=sh
# shellcheck disable=SC2221,SC2222
# (sourced, not executed — no shebang. SC2221/SC2222: several broad globs (*.lock,
# *.yaml, *.toml, *.env) shadow the explicit names listed beside them; the explicit
# names are kept deliberately as documentation of intent and are harmless because
# each maps to the SAME class as the glob that shadows it.)
#
# e22-standards hook helper — one file classifier, sourced by the point-of-action
# nudges so they share a single notion of what a path *is*. Each hook maps the
# class to its own policy (exempt / nudge); the classification itself lives here.
#
# Classes:
#   spec           — the /spec spine or .claude/ config (bootstrapping the spine)
#   documentation  — prose: md/mdx/txt/rst, LICENSE, docs/
#   implementation — application source code
#   operations     — config / infra: toml, yaml/yml, .env, Makefile, Dockerfile,
#                    compose, *.tf, *.sql, *.sh, CI workflows, k8s/helm, *.conf,
#                    *.properties, *.ini, *.cfg, mise config, manifests
#   generated      — build output / vendored / minified
#   lockfile       — dependency lockfiles
#   unknown        — anything else (callers nudge conservatively)
#
# POSIX sh, pure string matching on the path. Order matters: more specific
# classes are tested first.
e22_classify_path() {
  _p="$1"
  case "${_p}" in
    */spec/*|spec/*|*/.claude/*|.claude/*) printf 'spec' ; return ;;
  esac
  case "${_p}" in
    package-lock.json|*/package-lock.json|pnpm-lock.yaml|*/pnpm-lock.yaml|\
    yarn.lock|*/yarn.lock|*.lock|*.lockb|Cargo.lock|*/Cargo.lock|\
    poetry.lock|*/poetry.lock|uv.lock|*/uv.lock|go.sum|*/go.sum|\
    composer.lock|*/composer.lock|Gemfile.lock|*/Gemfile.lock)
      printf 'lockfile' ; return ;;
  esac
  case "${_p}" in
    */dist/*|dist/*|*/build/*|build/*|*/node_modules/*|node_modules/*|\
    */.next/*|*/target/*|target/*|*/__pycache__/*|*.min.js|*.min.css|*.map)
      printf 'generated' ; return ;;
  esac
  case "${_p}" in
    *.md|*.mdx|*.markdown|*.txt|*.rst|*.adoc|LICENSE|LICENSE.*|*/docs/*|docs/*)
      printf 'documentation' ; return ;;
  esac
  case "${_p}" in
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.py|*.go|*.rs|*.java|*.rb|*.php|*.cs|\
    *.cpp|*.cc|*.c|*.h|*.hpp|*.swift|*.kt|*.scala|*.ex|*.exs|*.vue|*.svelte)
      printf 'implementation' ; return ;;
  esac
  case "${_p}" in
    *.toml|*.yaml|*.yml|*.tf|*.tfvars|*.sql|*.sh|*.bash|*.zsh|\
    *.json|*.properties|*.conf|*.cfg|*.ini|*.env|.env|.env.*|*/.env|*/.env.*|\
    Dockerfile|Dockerfile.*|*/Dockerfile|*/Dockerfile.*|Containerfile|\
    compose.yaml|compose.yml|docker-compose.yml|docker-compose.yaml|\
    */compose.yaml|*/compose.yml|Makefile|makefile|GNUmakefile|*/Makefile|*.mk|\
    Chart.yaml|values.yaml|*/k8s/*|*/helm/*|*/.github/workflows/*|.github/workflows/*|\
    mise.toml|*/mise.toml|.mise.toml|mise.lock|*/mise.lock)
      printf 'operations' ; return ;;
  esac
  printf 'unknown'
}

# e22_class_nudges <class> — the shared exempt/nudge decision used by BOTH
# point-of-action nudges: exempt spec/documentation/generated/lockfile; nudge on
# implementation/operations; nudge conservatively on unknown. Prints "nudge" or
# "exempt".
e22_class_nudges() {
  case "$1" in
    implementation|operations|unknown) printf 'nudge' ;;
    *) printf 'exempt' ;;
  esac
}

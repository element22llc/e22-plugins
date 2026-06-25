# configs

Shared tooling configuration referenced by [apps](../apps/README.md) and
[packages](../packages/README.md): lint rules, base `tsconfig`, formatter
config, test presets, and similar.

- Put config here when two or more apps/packages should share it, so the rule
  lives in one place and is extended rather than copied.
- This is configuration only — no deployable code (that's an app) and no shared
  runtime library code (that's a package).

# Contributing

`e22-plugins` is **published read-only**. It is the source of truth for Element
22's engineering standards (the `steer` plugin) and the bundled repo scaffold,
mirrored here publicly so teams and partners can adopt the same SDLC. We do
**not** accept external pull requests, and active development happens internally.

You are welcome to **use** it under the [Apache-2.0 license](LICENSE):

```bash
/plugin marketplace add element22llc/e22-plugins
```

See the [documentation site](https://ai.element-22.com) and the repository
[`README.md`](README.md) for install and adoption guidance.

## Found a problem?

- **A security vulnerability** — follow [`SECURITY.md`](SECURITY.md); report it
  privately, not in a public issue.
- **A defect in the `steer` plugin** (a broken hook, a contradictory rule or
  skill, a missing or broken template/script) — open an issue using the
  **steer self-report** template on the
  [Issues tab](https://github.com/element22llc/e22-plugins/issues). From a Claude
  Code session that has the plugin installed, `/steer:report` will gather the
  defect, scrub it of secrets and local paths, and file it for you.

Bug reports and reproductions are appreciated; code contributions from outside
the organization are not merged.

## Internal contributors

If you have write access, the authoring workflow, verification gates, and release
process are documented in [`AUTHORING.md`](AUTHORING.md) and
[`CLAUDE.md`](CLAUDE.md). In short: work on a `feat/*` / `fix/*` branch, add a
`CHANGELOG.md` entry under `## steer` → `### [Unreleased]` for any plugin-behavior
change, run `mise run ci` before pushing, and open a PR.

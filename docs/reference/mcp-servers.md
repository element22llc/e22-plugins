# MCP servers

The **steer plugin** ships an `.mcp.json` (source: `plugins/steer/.mcp.json`)
that wires **local Claude Code sessions** to a small set of
[Model Context Protocol](https://modelcontextprotocol.io) servers. Because they
ship with the plugin rather than the scaffold, every repo that enables steer
picks them up centrally and they refresh on `/plugin update` — there is no
per-repo `.mcp.json` to scaffold, drift, or reconcile. Each server still goes
through Claude Code's per-server approval the first time it connects, and a repo
may add its own project `.mcp.json` for product-specific servers (it merges
additively with the plugin's). This page is kept in sync with the plugin's
`.mcp.json` and the scaffold `README.md` by `/plugin-docs`; the nav/orphan check
in `scripts/validate_docs.py` guards that it stays linked, but its
server-by-server content is reconciled by hand against the source of truth.

!!! info "Local sessions only — not CI"
    The plugin's `.mcp.json` configures the Claude Code **you run on your
    machine**. GitHub Actions does *not* read it — the in-CI agent loads steer
    and its tools through the action's inputs instead (see
    [GitHub Actions integration](github-integration.md)). Interactively
    authenticated MCP servers may also be absent in headless/cron runs (see
    [Known limitations](known-limitations.md)).

!!! warning "Claude Cowork doesn't use this file — MCP config isn't shared across surfaces"
    This `.mcp.json` is read by the Claude Code **CLI / Code tab**, not by the
    **Cowork** or **Chat** tabs, which wire MCP through their own **Connectors**.
    On Cowork the `${GITHUB_PAT}` `github` server can't authenticate (no shell to
    export the PAT into) and the local-process `markitdown` server can't run (no
    installs in the sandbox) — so for GitHub work in Cowork, enable the **built-in
    GitHub connector** instead. See
    [Known limitations → Claude Cowork's sandbox](known-limitations.md#claude-coworks-sandbox-no-installs-connector-only-github).

## Servers

| Server | Transport | Auth | Purpose |
| --- | --- | --- | --- |
| `github` | HTTP (`api.githubcopilot.com/mcp/`) | `${GITHUB_PAT}` (your shell) | Read issues, comment on PRs, inspect workflow runs. |
| `markitdown` | local process (`uvx markitdown-mcp`) | none | Convert provided Office documents to Markdown. |
| `context7` | HTTP (`mcp.context7.com/mcp`) | none (optional `CONTEXT7_API_KEY`) | Pull up-to-date, version-accurate library/API documentation on demand. |

## `github`

Wires the session to GitHub's hosted MCP server so tracker reads/writes can go
through MCP rather than shelling out. It is the **preferred** path for
[`/steer:tracker-sync`](skills.md), which falls back to the `gh` CLI and then a
manual floor when no MCP tracker tool is present.

The config references `${GITHUB_PAT}`; the token **never lives in the repo** —
you export a fine-grained PAT from your shell. Full setup (required scopes, shell
export, secret-manager option) is in the scaffold `README.md` → "GitHub MCP
server", reachable from any bootstrapped repo.

!!! warning "Never commit the token"
    Don't put the PAT in a repo file (even a gitignored one) or paste it into a
    Claude message.

## `markitdown`

Wires the session to Microsoft's
[markitdown](https://github.com/microsoft/markitdown) MCP server
(`packages/markitdown-mcp`), which converts binary Office documents — `.docx`,
`.xlsx`, `.pptx`, plus HTML/EPUB/CSV and more — into clean Markdown. Reach for it
when a stakeholder hands over source material in those formats, so Claude reads it
cheaply instead of choking on raw zip+XML.

!!! tip "PDFs and images don't need it"
    Claude's native `Read` tool already handles PDFs (it renders pages visually)
    and images. Use `markitdown` for the Office binaries specifically.

[`/steer:intake`](../workflows/intake.md) is the main consumer: it converts each
version of a PO-supplied document to the normalized `extracted.md` it commits and
diffs. The same converter is available off-MCP as the `mise run convert:doc`
scaffold task, the deterministic on-disk path.

It runs via `uvx markitdown-mcp`, so it needs `uv` (and a Python for `uv` to
manage) on `PATH` — **no token**. The scaffold `mise.toml` pins `node`, `python`,
and `uv` as an always-installed agent-runtime baseline (AI tooling and MCP
servers run packages on demand via `npx`/`uvx`), so
`mise install` makes this work out of the box regardless of product stack. First
use auto-fetches the package from PyPI.

!!! warning "Local, trusted use only"
    markitdown-mcp is meant for local use — don't expose it over HTTP/SSE.

## `context7`

Wires the session to [Context7](https://context7.com)'s hosted MCP server, which
returns **up-to-date, version-accurate documentation** for thousands of libraries
and frameworks on demand. Reach for it when you're working against a fast-moving
dependency and want the *current* API surface rather than what training data
remembers — it pulls the docs for the exact version in play instead of guessing.

Like `github`, it's an **HTTP** server (`https://mcp.context7.com/mcp`), so there
is **no local process, package fetch, or runtime dependency** — nothing to install
and nothing on `PATH` to break. It connects **with no token**: the anonymous free
tier works out of the box.

!!! tip "Optional API key for higher rate limits"
    A `CONTEXT7_API_KEY` is **optional** — it only raises rate limits. If you hit
    them, get a key from [context7.com](https://context7.com), export it from your
    shell, and add it via your own project `.mcp.json` (which merges additively
    with the plugin's) as an `Authorization` header — don't edit the
    plugin-managed `.mcp.json`, which refreshes on `/plugin update`.

!!! warning "Hosted service — queries leave your machine"
    Like the `github` server, context7 is a third-party hosted service: the
    library names and queries you send go to context7's API. Don't send anything
    sensitive through it.

## Verifying

Restart Claude Code in the repo and run `/mcp`. Each configured server should
report **connected**. A server that shows disconnected means its prerequisite is
missing — a `GITHUB_PAT` not exported (for `github`), or `uv`/`python` removed
from `mise.toml` (for `markitdown`). Nothing breaks when a server is
disconnected; only that server's tools are unavailable.

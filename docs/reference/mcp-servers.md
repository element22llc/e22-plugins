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

## Servers

| Server | Transport | Auth | Purpose |
| --- | --- | --- | --- |
| `github` | HTTP (`api.githubcopilot.com/mcp/`) | `${GITHUB_PAT}` (your shell) | Read issues, comment on PRs, inspect workflow runs. |
| `markitdown` | local process (`uvx markitdown-mcp`) | none | Convert provided Office documents to Markdown. |

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

It runs via `uvx markitdown-mcp`, so it needs `uv` (and a Python for `uv` to
manage) on `PATH` — **no token**. The scaffold `mise.toml` pins `node`, `python`,
and `uv` as an always-installed agent-runtime baseline (AI tooling and MCP
servers run packages on demand via `npx`/`uvx`), so
`mise install` makes this work out of the box regardless of product stack. First
use auto-fetches the package from PyPI.

!!! warning "Local, trusted use only"
    markitdown-mcp is meant for local use — don't expose it over HTTP/SSE.

## Verifying

Restart Claude Code in the repo and run `/mcp`. Each configured server should
report **connected**. A server that shows disconnected means its prerequisite is
missing — a `GITHUB_PAT` not exported (for `github`), or `uv`/`python` removed
from `mise.toml` (for `markitdown`). Nothing breaks when a server is
disconnected; only that server's tools are unavailable.

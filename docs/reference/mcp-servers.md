# MCP servers

The **steer plugin** ships an MCP config (source: `plugins/steer/.claude-plugin/mcp.json`)
that wires **local Claude Code sessions** to a small set of
[Model Context Protocol](https://modelcontextprotocol.io) servers. Because they
ship with the plugin rather than the scaffold, every repo that enables steer
picks them up centrally and they refresh on `/plugin update` - there is no
per-repo `.mcp.json` to scaffold, drift, or reconcile. Each server still goes
through Claude Code's per-server approval the first time it connects, and a repo
may add its own project `.mcp.json` for product-specific servers (it merges
additively with the plugin's). This page is kept in sync with the plugin's
MCP config and the scaffold `README.md` by `/plugin-docs`; the nav/orphan check
in `scripts/validate_docs.py` guards that it stays linked, but its
server-by-server content is reconciled by hand against the source of truth.

!!! info "Local sessions only - not CI"
    The plugin's MCP config configures the Claude Code **you run on your
    machine**. GitHub Actions does *not* read it - the in-CI agent loads steer
    and its tools through the action's inputs instead (see
    [GitHub Actions integration](github-integration.md)). Interactively
    authenticated MCP servers may also be absent in headless/cron runs (see
    [Known limitations](known-limitations.md)).

!!! warning "Claude Cowork doesn't use this file - MCP config isn't shared across surfaces"
    This config is read by the Claude Code **CLI / Code tab**, not by the
    **Cowork** or **Chat** tabs, which wire MCP through their own **Connectors**.
    Cowork reads neither this file nor the plugin's `userConfig`, so the `github`
    server can't authenticate there - for GitHub work in Cowork, enable the
    **built-in GitHub connector** instead. See
    [Known limitations -> Claude Cowork's sandbox](known-limitations.md#claude-coworks-sandbox-no-installs-connector-only-github).

## Servers

| Server | Transport | Auth | Purpose |
| --- | --- | --- | --- |
| `github` | HTTP (`api.githubcopilot.com/mcp/`) | `${user_config.github_pat}` (keychain / `~/.claude/.credentials.json`) | Read and write issues (the `context` and `issues` toolsets), plus three PR tools as the delivery fallback. |
| `context7` | HTTP (`mcp.context7.com/mcp`) | none (optional `CONTEXT7_API_KEY`) | Pull up-to-date, version-accurate library/API documentation on demand. |

## `github`

Wires the session to GitHub's hosted MCP server so tracker reads/writes can go
through MCP rather than shelling out. It is the **preferred** path for
[`/steer:tracker-sync`](skills.md), which falls back to the `gh` CLI and then a
manual floor when no MCP tracker tool is present.

The server is limited to two toolsets with the `X-MCP-Toolsets: context,issues`
header: `issues` carries every tool steer calls (`issue_read`, `issue_write`,
`list_issues`, `search_issues`, `sub_issue_write`, `add_issue_comment`), and
`context` carries `get_me`. The `X-MCP-Tools` header adds three single tools
from the `pull_requests` toolset: `create_pull_request`, `update_pull_request`
and `list_pull_requests`. That is 17 tools instead of about 50, so tool
selection stays sharp.

Pull requests go through the `gh` CLI first; the three PR tools are
`/steer:work finish`'s fallback when `gh` is not authenticated. The rest of the
`pull_requests` toolset, `merge_pull_request` and the review tools included, is
deliberately not exposed: the merge stays the human's step. The CI watch,
repositories and workflow runs stay on `gh`. To get more GitHub tools for ad-hoc
use, add your own GitHub server in a project or user `.mcp.json` (a merge tool
there is still denied by the `check-bash-actions.sh` merge gate).

!!! warning "Tool names must exist"
    The hosted server rejects `initialize` with HTTP 400 when `X-MCP-Tools`
    names a tool it does not have, so a typo there disconnects `github` for
    every install. Check a change against the live server's `tools/list`.

The config references `${user_config.github_pat}`, a **plugin user-config**
value declared in the plugin manifest's `userConfig` block and marked
`sensitive`. Claude Code prompts for it once when the plugin is installed and
holds it outside the repo - in the **macOS Keychain**, or
`~/.claude/.credentials.json` where no supported keychain is available (WSL2
included). There is no shell rc to edit and nothing to
re-export per machine or per terminal. The token **never lives in the repo**.

!!! warning "Upgrading from a `GITHUB_PAT` shell export"
    Before this changed, the server read `Bearer ${GITHUB_PAT}` from whatever
    shell launched Claude Code, and the scaffold README told every teammate to
    export it from `~/.zshrc` / `~/.bashrc`. **That export stops being read on
    update.** If `github` was working for you and now reports disconnected after
    a `/plugin update`, this is why - the token has to be supplied to the *plugin*
    once per machine:

    ```sh
    claude plugin install steer@e22-plugins --config github_pat=...
    ```

    No file edit restores access; a repo's `/steer:setup sync` rewrites the stale README
    instruction, but the token itself is yours to re-supply. Removing the old
    `export GITHUB_PAT` line is optional - nothing reads it any more, though a
    same-named GitHub Actions secret is unrelated and must be left alone.

The field is **optional**: skip the prompt and the `github` server simply reports
disconnected, which every consumer of it already handles -
[`/steer:tracker-sync`](skills.md) falls back to the `gh` CLI and then to a
manual floor. To set or change it later, use `claude plugin install
steer@e22-plugins --config github_pat=...`, or re-run the install prompt.

Full setup (the required fine-grained scopes) is in the scaffold `README.md` ->
"GitHub MCP server", reachable from any bootstrapped repo.

!!! warning "Never commit the token"
    Don't put the PAT in a repo file (even a gitignored one) or paste it into a
    Claude message.

## Office-document conversion is *not* a server

Earlier versions wired Microsoft's
[markitdown](https://github.com/microsoft/markitdown) as a third MCP server.
It was removed: a plugin MCP server starts automatically whenever the plugin is
enabled, so every session paid a `uvx markitdown-mcp` subprocess to serve the
one skill that needs it ([`/steer:spec intake`](../workflows/intake.md)).

The same tool now runs **on demand** as the scaffold's mise task, which
`/steer:spec intake` already used as its deterministic committable path:

```sh
mise run convert:doc path/to/document.docx     # Markdown on stdout
```

It runs `uvx --from "markitdown[all]" markitdown` - the `[all]` extras are
load-bearing, since the bare package ships no format handlers - so it needs `uv`
(and a Python for `uv` to manage) on
`PATH` - no token. The scaffold `mise.toml` pins `node`, `python`, and `uv` as
an always-installed agent-runtime baseline, so `mise install` makes this work
out of the box regardless of product stack. First use auto-fetches the package
from PyPI.

!!! tip "PDFs and images don't need it"
    Claude's native `Read` tool already handles PDFs (it renders pages visually)
    and images. Use `convert:doc` for the Office binaries specifically.

!!! note "Stale entries are harmless"
    A repo bootstrapped before the removal may still list a `markitdown` server
    in `.mcp.json` or `.vscode/mcp.json`. Nothing breaks - it just starts a
    server nothing calls. [`/steer:setup sync`](skills.md) clears it.

## `context7`

Wires the session to [Context7](https://context7.com)'s hosted MCP server, which
returns **up-to-date, version-accurate documentation** for thousands of libraries
and frameworks on demand. It pulls the docs for the exact version in play instead
of guessing.

This is **not** discretionary: rule `10-stack` names this server as how to satisfy
its own instruction - *"when you pick or change a piece, verify the current stable
version in-session via the bundled `context7` MCP server - never from
training-data memory."* Reach for it whenever a version, API surface, or
configuration question would otherwise be answered from training data. (For
release-support windows and EOL dates, `CONVENTIONS.md` (via
`/steer:reference conventions`) points at the registry,
[endoflife.date](https://endoflife.date), or the vendor's own site - those are not
library docs and context7 does not carry them.)

Like `github`, it's an **HTTP** server (`https://mcp.context7.com/mcp`), so there
is **no local process, package fetch, or runtime dependency** - nothing to install
and nothing on `PATH` to break. It connects **with no token**: the anonymous free
tier works out of the box.

!!! tip "Optional API key for higher rate limits"
    A `CONTEXT7_API_KEY` is **optional** - it only raises rate limits. If you hit
    them, get a key from [context7.com](https://context7.com), export it from your
    shell, and add it via your own project `.mcp.json` (which merges additively
    with the plugin's) as an `Authorization` header - don't edit the
    plugin-managed MCP config, which refreshes on `/plugin update`.

!!! warning "Hosted service - queries leave your machine"
    Like the `github` server, context7 is a third-party hosted service: the
    library names and queries you send go to context7's API. Don't send anything
    sensitive through it.

## Verifying

Restart Claude Code in the repo and run `/mcp`. Each configured server should
report **connected**. A server that shows disconnected means its prerequisite is
missing - typically the `github_pat` plugin config left blank (for `github`).
Nothing breaks when a server is disconnected; only that server's tools are
unavailable.

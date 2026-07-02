# Installation

`steer` is distributed through the `e22-plugins` marketplace. Install it once in
Claude Code, then bootstrap or adopt repos with its skills.

## Add the marketplace and install the plugin

```text
/plugin marketplace add element22llc/e22-plugins
/plugin install steer@e22-plugins
```

Once installed, the `SessionStart` hook injects the always-on
[rules](../reference/configuration.md) into every session where the plugin is
enabled — a lean subset in non-code folders, since the scoped rules self-gate (see
[Known limitations](../reference/known-limitations.md)) — and the
`/steer:<skill>` commands become available.

!!! note "Invocation is always namespaced"
    Skills are invoked as `/steer:<skill>` (e.g. `/steer:spec`), never bare
    `/<skill>` — Claude Code namespaces plugin skills to avoid collisions.

### Verify it worked

Run `/plugin` and confirm **Steer — Engineering Standards** is listed and enabled.
Opening a new session in a managed repo then shows the injected version banner at
the top of the standards block — that banner is your confirmation the rules loaded.

!!! note "Prerequisites for the full workflow"
    `/steer:setup` invokes **`/steer:doctor`** to install the local toolchain
    (git, mise, Docker) when it's missing. The issue and PR steps additionally need
    an authenticated GitHub path: check `gh auth status` (run `gh auth login` if
    it fails), or export a `GITHUB_PAT` for the GitHub MCP server.

## Where hooks fire (surfaces)

!!! warning "Hooks don't fire everywhere — rules may not load automatically"
    `steer` relies on Claude Code's hook lifecycle: the `SessionStart` hook is
    what injects the always-on rules. **Claude Code** (the CLI, the IDE
    extensions, and the Desktop **Code** tab) runs hooks fully. **Cowork** runs
    them too, but it's a no-install sandbox and **best-effort, for PO/knowledge-work
    only** — do engineering work in Claude Code (reconfirm hooks on your build;
    `SessionStart` had bugs earlier in 2026, since closed). But on the **Desktop
    *Chat* tab and claude.ai web
    chat** hooks do **not** run, so the rules are **not** auto-injected and the
    `PreToolUse` hooks (the spec-first/issue-first nudges and the version-pin
    block) do not run. On those surfaces — and as a fallback anywhere the rules
    didn't load — run this manually at the start of the session before doing
    anything else:

    ```text
    /steer:standards
    ```

    See [Known limitations](../reference/known-limitations.md) for the full list
    of where this matters.

!!! note "Windows: give the hooks a shell"
    steer's hooks are invoked via `sh`, which native Windows lacks. On the
    **Claude Desktop Code tab**, install
    [Git for Windows](https://gitforwindows.org/) and that's the whole setup —
    hooks fire and `/steer:build` builds locally (add Docker Desktop if the repo
    runs services); **no WSL2 needed**. If you work through the **CLI or an IDE**,
    use **WSL2** instead. Full matrix: [Windows setup](windows-setup.md).

## Bootstrapping a repo

Run **[`/steer:setup`](../workflows/index.md)** — it detects the repo state and
routes to the right path, so you don't have to choose:

- **New repo:** installs the bundled scaffold and `/spec` spine (`/steer:init`).
- **Existing app:** reverse-engineers a `/spec` spine from the code and adds the
  scaffold ([`/steer:adopt`](../workflows/adopt.md)).

Both replace the old static `repository-template` as the bootstrap source.

!!! tip "Desktop Code-tab preview (app repos)"
    For the **`app`** profile, bootstrap also drops a `.claude/launch.json`
    preview-server config so the **Desktop Code tab**'s preview pane and
    auto-verify screenshots run the repo's real dev command (`pnpm dev` on port
    3000) instead of relying on auto-detection. Bring services/DB up first with
    `mise run dev:setup`; repoint the config at `mise run dev` once the repo goes
    polyglot. It never overwrites an existing `launch.json`, and other profiles
    (`service` can copy it; `library`/`cli`/`infra` skip it) don't get one.

## Keeping a repo in sync

After a new plugin release, run **[`/steer:setup`](../workflows/index.md)** in a
managed repo — it detects the drift and applies pending migrations, reconciling
the scaffold and spec spine against the current templates (via `/steer:sync`).

## Next step

Walk through the [first workflow](first-workflow.md) end to end.

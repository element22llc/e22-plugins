# Installation

`steer` is distributed through the `e22-plugins` marketplace. Install it once in
Claude Code, then bootstrap or adopt repos with its skills.

## Add the marketplace and install the plugin

```text
/plugin marketplace add element22llc/e22-plugins
/plugin install steer@e22-plugins
```

Once installed, the `SessionStart` hook injects the always-on
[rules](../reference/configuration.md) into every session in repos that have been
set up with the plugin, and the `/steer:<skill>` commands become available.

!!! note "Invocation is always namespaced"
    Skills are invoked as `/steer:<skill>` (e.g. `/steer:spec`), never bare
    `/<skill>` — Claude Code namespaces plugin skills to avoid collisions.

## Where hooks fire (surfaces)

!!! warning "Hooks don't fire everywhere — rules may not load automatically"
    `steer` relies on Claude Code's hook lifecycle: the `SessionStart` hook is
    what injects the always-on rules. **Claude Code** (the CLI, the IDE
    extensions, and the Desktop **Code** tab) runs hooks fully, and **Cowork**
    runs them too (reconfirm on your build — `SessionStart` hooks had bugs earlier
    in 2026, since closed). But on the **Desktop *Chat* tab and claude.ai web
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

## Bootstrapping a repo

Run **[`/steer:setup`](../workflows/index.md)** — it detects the repo state and
routes to the right path, so you don't have to choose:

- **New repo:** installs the bundled scaffold and `/spec` spine (`/steer:init`).
- **Existing app:** reverse-engineers a `/spec` spine from the code and adds the
  scaffold ([`/steer:adopt`](../workflows/adopt.md)).

Both replace the old static `repository-template` as the bootstrap source.

## Keeping a repo in sync

After a new plugin release, run **[`/steer:setup`](../workflows/index.md)** in a
managed repo — it detects the drift and applies pending migrations, reconciling
the scaffold and spec spine against the current templates (via `/steer:sync`).

## Next step

Walk through the [first workflow](first-workflow.md) end to end.

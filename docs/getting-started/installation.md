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

## Surfaces where hooks do not fire

On Claude Cowork and the Claude desktop app, plugin `SessionStart` hooks do not
currently fire, so the always-on rules are not auto-injected. On those surfaces,
load them on demand at the start of a session:

```text
/steer:standards
```

## Bootstrapping a repo

- **New repo:** [`/steer:init`](../workflows/index.md) installs the bundled
  scaffold and `/spec` spine.
- **Existing app:** [`/steer:adopt`](../workflows/adopt.md) reverse-engineers a
  `/spec` spine from the code and adds the scaffold.

Both replace the old static `repository-template` as the bootstrap source.

## Keeping a repo in sync

After a new plugin release, run [`/steer:sync`](../workflows/index.md) in a
managed repo to apply pending migrations and reconcile the scaffold and spec
spine against the current templates.

## Next step

Walk through the [first workflow](first-workflow.md) end to end.

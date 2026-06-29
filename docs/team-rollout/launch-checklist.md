# Launch checklist

One pass to run **before** opening `steer` to the wider team. Work top to bottom;
each item is something you've actually exercised, not just read about. Do this in
a real (or throwaway) repo, not against production work.

## Pre-rollout checks

- [ ] **Plugin install tested.** `/plugin marketplace add element22llc/e22-plugins`
      then `/plugin install steer@e22-plugins` succeeds in a clean Claude Code.
- [ ] **`/steer:init` tested.** Runs in a fresh repo and installs the scaffold +
      `/spec` spine. (See [Adopt](../workflows/adopt.md) for the existing-repo path.)
- [ ] **`/steer:standards` tested.** Loads the always-on rules on demand —
      confirm it works on a hookless surface (Cowork/desktop) where `SessionStart`
      doesn't fire. See [Known limitations](../reference/known-limitations.md).
- [ ] **Issue creation tested.** Capturing an idea creates a tracked issue through
      `/steer:tracker-sync` (MCP-first → `gh` fallback). Confirm `gh auth status`
      is green so the path doesn't drop to the manual floor.
- [ ] **PR workflow tested.** `/steer:work` produces a branch + commit and opens a
      PR, and the **push/PR gate** correctly pauses for a human.
- [ ] **In-CI `@claude` provisioned.** The shipped `claude.yml` loads the `steer`
      plugin in CI, so it needs the `ANTHROPIC_API_KEY` secret. The marketplace
      repo is public, so the plugin clone is anonymous — no marketplace credential
      needed. Add the key, then `@claude` on a test PR and confirm the reply
      reflects steer standards (proves the plugin loaded). See
      [GitHub Actions integration](../reference/github-integration.md).
- [ ] **Docs drift CI tested.** `mise run docs:check` passes, and a deliberate
      drift (e.g. add a skill without updating the reference) is caught by CI.
- [ ] **One PO dry run completed.** A non-developer walks
      [the PO happy path](../workflows/build.md#the-po-happy-path) end to end:
      idea → preview → PR for dev review.
- [ ] **Rollback / uninstall documented.** The team knows how to back out (below).

## Rollback / uninstall

To remove the plugin from a Claude Code install, use the `/plugin` manager
(symmetric with the install steps in [Installation](../getting-started/installation.md)):

```text
/plugin uninstall steer@e22-plugins
/plugin marketplace remove element22llc/e22-plugins
```

This stops the hooks from firing and the rules from being injected in new
sessions; it does **not** touch artifacts already written into a managed repo
(the `/spec` spine, scaffold files, branches, or issues). To fully back a repo
out, revert those changes through normal git history.

## Next

Point new teammates at [Team onboarding](../getting-started/team-onboarding.md)
once these boxes are checked.

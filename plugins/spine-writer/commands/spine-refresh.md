---
description: Refresh the Product Spine for the current branch by re-extracting intent, surface, and architecture from the code.
argument-hint: [optional path to spine file; defaults to proposals/<branch-slug>/product-spine.md]
---

# /spine-refresh

Re-runs the `spine-extractor` agent against the current branch and updates the
Product Spine file. Use this:

- After a long working session, before packaging the handoff.
- Post-merge on a production-lane proposal, when the `drift-monitor` agent flags
  that the Spine has diverged from code.
- Any time the Spine feels stale relative to what's actually been built.

This command does **not** open or modify any PR. It only updates the Spine file
and appends a changelog entry.

## Surface and connector requirements

Works on **Claude.ai (Chat), Claude Cowork, and Claude Code**.

- In Claude Code: reads commits, diffs, and writes the Spine via the local
  filesystem (plus `git`).
- In Chat/Cowork: reads commits, diffs, manifests, and writes the Spine via the
  **GitHub connector**'s repo-contents API. The Spine update lands as a commit
  on the current branch.

Refuse cleanly in Chat/Cowork if the connector is missing.

## Workflow

0. **Zone check.** Source `${CLAUDE_PLUGIN_ROOT}/../e22-org/lib/zone.sh` and
   run `e22_zone`. If the workspace is `sandbox`, refuse cleanly:
   *"Product Spines are a governed-production artifact. Generate `HANDOFF.md`
   instead (handoff-packager) — or run this command after the work is imported
   into a governed repo (one with a GitHub remote)."* Exit without writing.

1. **Locate the Spine.** If `$ARGUMENTS` is provided, use that path. Otherwise:
   - Derive the branch slug from the current branch name.
   - Look for `proposals/<branch-slug>/product-spine.md`.
   - If none exists, look for a canonical per-product Spine pointed to by the
     product's `apps/<product>/CLAUDE.md`.
   - If still none, create a new file from `PRODUCT_SPINE_TEMPLATE.md`.

2. **Invoke `spine-extractor` agent.** Pass the Spine's current contents (for
   diffing) and the branch metadata (commits since `main`, file diffs, the
   product's CLAUDE.md, any open Claude chat context).

3. **Write the updated Spine.** Preserve human-edited content; merge in code-derived
   updates. Specifically:
   - **Intent** section: never auto-overwrite — humans own this.
   - **UX** section: auto-update from screens/components touched in the diff; flag
     for human review if the change is substantial.
   - **Surface** section: auto-update from new/changed endpoints, events, schemas.
   - **Architecture** section: auto-update from new components, dependencies, data
     flow inferable from the code.
   - **Open Questions**: append new ones discovered in TODO/XXX comments; do not
     remove existing entries.

4. **Append a changelog entry.** A single line at the bottom of the Spine:
   `- <YYYY-MM-DD> — Spine refreshed by spine-writer. <one-line summary of changes>.`

5. **Report to chat.** Single message:
   - Path to the updated Spine
   - What sections changed and why (1 sentence each)
   - Any **new** Open Questions that were just added
   - If Intent diverged from what was implemented, flag this — a human must
     resolve it.

## Things to avoid

- **Do not modify code.** This command is read-only on the code.
- **Do not auto-overwrite the Intent section.** Humans own intent.
- **Do not remove Open Questions.** They are closed by humans confirming the
  answer in chat (which the next refresh will see).
- **Do not run on a `main` checkout.** Spine refreshes are per-branch artefacts.

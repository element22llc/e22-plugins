---
description: Check the status of proposals you've filed or are championing.
argument-hint: [optional search term, proposal title, or "mine"]
---

# /proposal-status

Helps a non-engineering contributor see where their proposals stand without learning the proposal lifecycle's internal label vocabulary.

## Workflow

1. **Determine scope from $ARGUMENTS.**
   - Empty or "mine" → show proposals where this user is the champion.
   - A search term → search PR titles and bodies for that term.
   - A PR number → look up that specific proposal.

2. **Query GitHub via the GitHub MCP.** Search PRs with the `proposal` label in the relevant org. Filter by champion (look for `**Champion:** @<github-handle>` in the PR description) when scope is "mine".

3. **Translate the lifecycle labels into plain language** when you report status:

   | Internal label | What to say to the contributor |
   |---|---|
   | `drafting` | "Engineer is working on it. Preview coming." |
   | `preview-ready` | "Ready for you to review the preview." |
   | `review-requested` | "You confirmed it works — engineering review in progress." |
   | `experimental` | "Merged. Not visible to customers yet." |
   | `production-graded` | "Live for customers." |

4. **Format the response** as a short, scannable list:

   ```
   Your proposals (3):

   • Faster checkout — Preview coming (drafting, 2 days)
     → engineer: @alex   PR #142   preview not ready yet
   • Dark mode toggle — Ready for you to review (preview-ready, 4 hours)
     → engineer: @sam    PR #145   https://preview-145.tier1.dev
   • Receipt download bug — Live for customers (production-graded, 11 days)
     → engineer: @jordan PR #138   no action needed
   ```

5. **Surface action items.** If any proposal is `preview-ready`, mention that the contributor should review and tick off acceptance criteria when they're satisfied. If GitHub MCP isn't connected, say so plainly and suggest the contributor look directly in the repo's PR list.

6. **Offer a follow-up.** "Want me to set up a live status page you can come back to?" If they say yes, create an artifact via `mcp__cowork__create_artifact` that fetches the same data fresh on each open.

## Things to avoid

- Don't expose internal label strings or jargon in the default output. They can ask for the technical view if they want.
- Don't editorialize on whether progress is fast or slow — just report the state and age.
- Don't ping engineers automatically. The contributor decides when to nudge.

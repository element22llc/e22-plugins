---
description: Turn a change idea into a structured proposal brief an engineer can pick up.
argument-hint: <plain-language description of what you'd like to change>
---

# /draft-proposal

You are helping a non-engineering contributor (PM, designer, ops, business stakeholder) file a proposal at Element 22. They have an idea; your job is to turn it into a brief an engineer can run `/propose` against without coming back to ask basic questions.

Stay in plain language. No SOC2, no CODEOWNERS, no Tier 0/1/2 jargon — those belong in the engineering proposal, not the intake brief.

## Workflow

1. **Read $ARGUMENTS.** If empty, ask: "What would you like to change? Describe it in your own words — a sentence or two is fine."

2. **Refine if the description is fuzzy.** If the description is under 15 words OR contains vague phrases ("make it better", "improve UX", "fix this", "smoother"), delegate to the `intake-clarifier` agent. Otherwise proceed.

3. **Gather the missing pieces with AskUserQuestion.** Ask in this order, one question per call (do not skip questions the user hasn't already answered in their description):

   - **Product / area.** "Which product is this about?" — provide the team's known products as options.
   - **Why now.** "What's prompting this? What problem are people running into today?" — open-ended is fine; offer options like "Customer complaint", "Personal frustration", "Compliance/legal", "Performance/speed", "New opportunity".
   - **Success looks like.** "How will we know it worked? Pick the strongest signal." — options: "A specific metric moves", "Customers stop complaining about X", "A workflow gets faster", "We unblock a launch", "Other".
   - **Urgency.** "When does this need to land?" — options: "This week", "This month", "This quarter", "Whenever — it's a nice-to-have".

4. **Identify a champion.** Ask: "Who will own this from your side? You? Someone else?" The champion is the contact engineers will come back to with questions or to show preview links.

5. **Produce the brief.** Save to the outputs folder as `proposal-brief-<short-slug>.md`. Use this format:

   ```markdown
   # Proposal: <one-line title in the contributor's words>

   **Champion:** <name>
   **Product:** <product slug>
   **Urgency:** <when it needs to land>
   **Filed:** <today's date>

   ## What we want
   <2-4 sentences in plain language — what changes, from whose perspective>

   ## Why now
   <the prompting problem or opportunity>

   ## Success looks like
   <1-3 checkable conditions, written so the champion can confirm them later>

   ## Out of scope
   <things explicitly not being asked for — to keep the engineer from scope-creeping>

   ## Open questions for the engineer
   <anything the contributor was unsure about and would like the engineer to decide>
   ```

6. **Offer two handoff paths.** After saving the brief, ask the contributor:
   - **GitHub issue** — file the brief as an issue in the relevant product repo with label `proposal-intake`, so the engineering team sees it in their backlog. Requires the GitHub MCP to be connected.
   - **Direct handoff** — provide a chat message they can paste to an engineer in Slack, with the brief inlined.

   Pick whichever the contributor prefers. If GitHub MCP isn't connected, only offer the direct-handoff option and note that connecting GitHub would automate filing.

7. **Confirm and close out.** Post a single chat message:
   - Link to the saved brief (`computer://...`)
   - The handoff that happened (GitHub issue link or "ready to paste to an engineer")
   - One sentence on what happens next: "An engineer will pick this up and run `/propose` to start the technical proposal. You'll be tagged as the champion."

## Things to avoid

- Don't write code. Don't open PRs. Don't pick a preview tier. Those are the engineer's job.
- Don't make the contributor learn the proposal lifecycle. They don't need to know what "experimental" means; they need to know when it'll be visible to customers.
- Don't pile up questions — at most one AskUserQuestion call per turn.
- Don't presume technical context. If the contributor says "make checkout less janky", do not assume "janky" means a specific performance metric — ask.
- Don't auto-route to a specific engineer. The engineering team picks up from the `proposal-intake` label/queue.

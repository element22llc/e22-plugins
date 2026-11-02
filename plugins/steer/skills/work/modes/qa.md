# `/steer:work qa` - drive what the diff changed, before review

Read this file before running `qa [#N]`. The guardrails, preconditions and
authorization in `SKILL.md` apply unchanged.

Unit and integration tests cover the code; nobody clicks through the changed
flows until the reviewer does. `qa` does that first: it maps the user flows the
branch touches, drives them in a real browser, fixes what it can prove broken,
and leaves the rest written down for the reviewer. It **hunts for breakage**,
where `walkthrough` films a happy path for a PO.

## When it runs

**Opt-in, never automatic.** It costs a running stack and a browser session, so
it runs only when asked. `finish` names it in the closing block when the diff
touches UI paths (`NEXT-ACTION.md`); it never starts it.

It runs on the work not yet in `origin/<default>` - the work branch in pr-flow,
the unpushed trunk commits in solo-trunk - inside that work's issue: a fix it
makes is a localized supporting change of that issue, recorded in its managed
block. The run itself opens no issue. With nothing ahead of `origin/<default>`,
or no UI in the diff, say there is nothing to drive and stop.

## Preconditions

1. **The app runs on a fresh stack**: `mise run dev:setup`, then the repo's dev
   task, both through `mise run` so the worktree's ports apply. Stop whatever
   you started before you finish.
2. **A browser driver**, chosen by the tool table in
   `${CLAUDE_PLUGIN_ROOT}/templates/demo/README.md` -> Choosing the tool: the
   Playwright CLI where there is a shell, the Playwright MCP where there is none.
   Neither available -> say so and stop; a guessed result is not QA.
3. **Local and seeded only.** Never a deployed environment, a real account or a
   real third-party call. Saved sign-in state holds tokens: keep it in the
   scratchpad or the anchored, ignored `demo/.auth/`, never a committed path.

## Steps

1. **Map the flows.** From `git diff origin/<default>...HEAD`, list the pages,
   routes, components, server actions and API handlers that changed, then the
   user flows that reach them: entry URL, persona, steps. Add the touched
   feature's acceptance criteria from its `intent.md` when one exists. Keep to
   what the diff reaches, plus a neighbouring flow that shares a changed
   component. Post the list and carry on; it is not a gate.
2. **Drive each flow.** The happy path first, then the edges this diff makes
   likely: empty and invalid input, a second role where access logic changed,
   back and reload mid-flow, a narrow viewport. Read the page through snapshots
   (role, label, text) and take a screenshot only when the layout is the
   question. Watch for console errors, failed requests, error pages and broken
   layout, not only the visible result.
3. **Judge.** Each criterion passes or fails on what the browser showed, never
   on what the code suggests. Each defect gets the exact steps that reproduce it.
4. **Fix or file.**
   - **Introduced by this diff and fixable here** -> fix it by
     [`debug.md`](debug.md): the cause first, a regression test that fails
     before the fix at the lowest seam that reproduces it, the fix at the
     source. Then drive the flow again.
   - **Independent acceptance criteria, a product decision, or already broken
     on the default branch** -> a separate linked issue (`SKILL.md` ->
     Discovered work). Never widen this branch to absorb it.
   - Three fix attempts that do not converge -> stop and report it as open.
5. **Record it for the reviewer.** Under the PR's *Notes for the reviewer* (in
   solo-trunk, the trunk commit body): the flows driven, the criteria that
   passed, each defect fixed with its test, each one filed with its issue ref,
   and anything that could not be exercised locally. A fix adds commits, so the
   next step is `finish` again, which re-runs the local gates and the code gate
   on them.

## Gotchas

- **Commit no QA script.** This is exploration. A check worth keeping becomes a
  regression test in the repo's own suite, not a browser script beside it.
- **The browser state is evidence only when the stack is clean.** Leftover local
  data hides or fakes a defect; drive after `dev:setup`, not on a long-lived
  database.
- **A green test suite is not a pass here.** A flow passes when the browser
  showed it working.
- **Close the browser** when done.

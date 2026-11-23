# `/steer-work qa` - drive what the diff changed, before review

Read this file before running `qa [#N]`. The guardrails, preconditions and
authorization in `SKILL.md` apply unchanged.

Unit and integration tests cover the code; nobody clicks through the changed
flows until the reviewer does. `qa` does that first: it maps the user flows the
branch touches, drives them in a real browser, fixes what it can prove broken,
and leaves the rest written down for the reviewer, with before/after
screenshots of each changed screen in the PR. It **hunts for breakage**,
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
   you started before you finish. Under Orca (`ORCA_WORKTREE_ID` set, `orca` on
   the PATH), take the app's URL from `orca ports --json` - the dev server row's
   `advertisedUrl`, else `http://<connectHost>:<port>` from that row - rather
   than deriving it from the worktree's port offset.
2. **A browser driver**, chosen by the tool table in
   `https://raw.githubusercontent.com/element22llc/e22-plugins/main/plugins/steer/templates/demo/README.md` -> Choosing the tool: the
   Playwright CLI where there is a shell, the Playwright MCP where there is none.
   **Under Orca, drive Orca's built-in browser instead**, so the dev can watch
   the run in the IDE: read `orca skills get orca-cli --reference
   references/browser.md` once, then `orca tab create --url <app-url> --json`,
   and pass its `browserPageId` as `--page` to every later `snapshot`, `click`,
   `fill`, `console`, `network` and `screenshot`. Close only that tab (`orca tab
   close --page <id>`) when done. If the tab cannot open, fall back to the
   table's driver.
   No driver available -> say so and stop; a guessed result is not QA.
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
5. **Capture before/after**, once the fixes are in - pr-flow only: solo-trunk
   has no PR body to render images, so skip this step and say so in the record.
   - **After:** re-run `mise run dev:setup` on this stack first, so both sides
     start from the same seed data.
   - **Before:** `git fetch origin <default>`, then `git worktree add --detach
     <scratchpad>/qa-before origin/<default>`. Copy the files
     `.worktreeinclude` lists from the primary checkout, since a hand-made
     worktree gets none. If the primary checkout is trusted, run `mise trust`
     in the worktree; otherwise ask - never create trust. Boot it as in
     Precondition 1; a linked worktree gets its own ports. When it cannot
     boot, capture "after" only and say why.
   - Each changed screen of each flow, in the same state on both sides, at
     desktop (1280 wide) and narrow (390 wide). Name each file
     `<flow>-<before|after>-<desktop|narrow>.png` and keep it in its own
     `<scratchpad>/qa-shots/` directory, apart from sign-in state, never in
     the repo.
   - Host them: `sh "${STEER_PLUGIN_ROOT}/scripts/pr-assets.sh"
     <repo-url> <branch> <scratchpad>/qa-shots/*.png`. `<repo-url>` is the
     repo `origin` points at, from `gh repo view --json url -q .url`; with no
     `gh`, it is the PR URL cut to `https://<host>/<owner>/<repo>`. The helper
     pushes the images to `refs/steer-assets/<branch>`, which is not a branch
     and which a default clone never fetches, then prints one URL per file.
     Only these `github.com` blob URLs render for reviewers of a private repo;
     a repo-relative path or a `raw.githubusercontent.com` link shows a broken
     image.
   - A non-zero exit (a push ruleset, no push rights, no git identity) means
     no images: record `screenshots not hosted: <reason>`. Never commit them
     instead.
6. **Record it for the reviewer.** Under the PR's *Notes for the reviewer* (in
   solo-trunk, the trunk commit body): the flows driven, the criteria that
   passed, each defect fixed with its test, each one filed with its issue ref,
   and anything that could not be exercised locally. Under *Visual changes*,
   replace the table with one `| Flow | Viewport | Before | After |` row per
   capture, each image an inline Markdown image of its printed URL. A fix adds
   commits, so the next step is `finish` again, which re-runs the local gates
   and the code gate on them.

**Every exit tears down what `qa` started**, the stop paths included (no driver,
fixes that do not converge): the dev server, and the before stack - `mise run
docker:clean` inside it, then `git worktree remove`.

## Gotchas

- **Commit no QA script or screenshot.** This is exploration. A check worth keeping becomes a
  regression test in the repo's own suite, not a browser script beside it.
- **The browser state is evidence only when the stack is clean.** Leftover local
  data hides or fakes a defect; drive after `dev:setup`, not on a long-lived
  database.
- **A green test suite is not a pass here.** A flow passes when the browser
  showed it working.
- **The images outlive the branch.** The ref is kept as review evidence; prune
  one with `git push origin --delete refs/steer-assets/<branch>`, which breaks
  that PR's images once GitHub garbage-collects the commit.
- **`<repo-url>` names the repo the helper pushes to.** From a fork that is the
  fork, not the PR's base repo; a mismatch links a SHA the URL's repo lacks.
- **Close the browser** when done.

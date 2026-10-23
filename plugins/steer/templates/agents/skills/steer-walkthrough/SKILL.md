---
name: steer-walkthrough
description: 'Internal recorder - a captioned walkthrough video of the running app that proves an approved feature intent: scenes planned from the intent, a committed re-recordable script plus a `mise run demo:record` task, and the frames verified before the MP4 is handed over.'
user-invocable: false
---

<!-- Generated from the steer plugin's skills/walkthrough/SKILL.md - do not edit by hand.
     Refresh with /steer:setup sync from Claude Code in a managed repo, or
     `mise run gen:copilot` in the plugin repo. Authored for Claude Code and
     rendered here in the cross-tool Agent Skills format (agentskills.io) that
     Copilot, Cursor, Gemini CLI and Codex read from .agents/skills/. -->

**When to use.** Reached via /steer-work walkthrough <feature> - not a direct entry point.

# Walkthrough video (`/steer-work walkthrough <feature>`)

For the PO or client who asks "show me" rather than "send me the spec". The
deliverable is a **committed script** that re-records the video with one
command, plus the **verified MP4**. The video itself is never committed: it goes
stale whenever the data or UI changes, and the script is what makes it cheap to
re-record.

Templates, per-stack wiring and the tool-choice table:
`https://raw.githubusercontent.com/element22llc/e22-plugins/main/plugins/steer/templates/demo/README.md`. Read it before step 3.

## Preconditions

1. **Resolve the feature** to `spec/features/<id>/intent.md`. In a polyrepo
   member that is the workspace's copy (`/steer-reference polyrepo`). No id
   given: ask which feature.
2. **The intent is `approved` or `live`.** A `draft` intent stops here: a
   walkthrough proves an approved intent, it does not stand in for one. Point
   at `/steer-spec approve <id>`.
3. **`ffmpeg` is on PATH.** If it is missing, say so and stop; installing it is
   the dev's call.
4. **The app runs on a fresh stack**: `mise run dev:setup`, then the repo's dev
   task, both through `mise run` so the worktree's ports apply. Stop whatever you
   started before you finish.
5. **A script already exists** at `scripts/demo/<id>_walkthrough.*`: update it
   rather than writing a second one. A plain re-record goes straight to step 4.

## Procedure

1. **Plan the scenes from the intent.** A title card (feature name, one line on
   what it does), one scene per `## User experience` step with the acceptance
   criteria it demonstrates folded into its caption, then a closing "What's
   next" card. Captions use the product's domain language: no ADR ids, `Q-NNN`,
   issue refs, feature slugs or spec paths. Note which persona each scene needs.
   A criterion the UI cannot show (retention, a background job) is left out and
   listed in the report. Post the scene list and carry on; it is not a gate.
2. **Explore the running app with the Playwright CLI** (`npx -y @playwright/cli`,
   or an installed `playwright-cli`): `open`, `goto`, `snapshot`, one command per call, to find each scene's page and a stable
   locator (role, label or text before CSS). Sign in once and `state-save`, so
   you know where the app keeps its session. With no shell, use the Playwright
   MCP instead. Close the browser when done.
3. **Write the script** from the template for the repo's stack (Node by default,
   Python for a Python app), replacing every placeholder and the sample scenes.
   Wire the dependency, the `demo:record` task and the anchored `/demo/` ignore
   rule as the templates README shows. The script passes the repo's lint,
   format and typecheck gates like any other code.
4. **Record**: `mise run demo:record`.
5. **Verify from the frames, not the logs.** Build the contact sheets (templates
   README) and read every one back. Each scene shows what its caption claims,
   rings sit on the intended element, and nothing on screen is an error, a
   leftover from older data, a secret or real personal data. Fix and re-record;
   after three rounds that do not converge, stop and report what is wrong.
6. **Deliver the script.** It changes tooling, not product behavior, so the PR
   is its record (rule 45, Commit autonomy): commit the script, task, ignore
   rule and lockfile, push, open the PR. The MP4 stays in the ignored `demo/`.
7. **Report**: the video path and duration, which criteria it shows and which it
   leaves out, and what a viewer should know - seeded or synthetic data, the
   product version or commit recorded, any real names on screen. Sharing the
   file is the human's act; never upload it anywhere.

## Gotchas

- **Sign in off camera.** Record from saved storage state, and save it with
  IndexedDB included: some apps keep the session there, so clearing cookies and
  localStorage does not sign out. Saved state holds tokens: it lives in
  `demo/.auth/`, never in a committed path.
- **Headless video has no cursor.** Everything the viewer follows is drawn:
  captions and rings. The template's `ring` scrolls the target to the centre and
  rings only a visible match; clear rings before every tab switch or navigation.
- **A different persona is a different browser context.** Record one clip per
  persona and join them; the template's `join` emits H.264 MP4 (`yuv420p`,
  `+faststart`) so it plays anywhere.
- **Controls are rarely what they look like.** A "fit view" button may open a
  menu; a node may need expanding before its detail shows. The contact sheet is
  the check, not a clean exit code.
- **Hold captions long enough to read**: about one second per five words, never
  under three. Aim for a video under three minutes.
- **The video is only as clean as the environment.** Leftover local state shows
  up on camera, so record after `dev:setup` on a fresh stack, never on a
  long-lived dev database.

## Recommended next actions

End with `## Recommended next actions - /steer-work walkthrough` per
`https://raw.githubusercontent.com/element22llc/e22-plugins/main/plugins/steer/templates/reference/NEXT-ACTIONS.md`:

| State | Category | Action / suggested command |
|---|---|---|
| Intent still `draft` | Blocking now | `/steer-spec approve <id>` |
| Frames show a defect in the app itself | Blocking now | File it - `/steer-work issues capture` |
| PR open with the script | Human decision required | A reviewer reviews the PR |
| Video verified and handed over | Complete | Re-record after data or UI changes - `mise run demo:record` |

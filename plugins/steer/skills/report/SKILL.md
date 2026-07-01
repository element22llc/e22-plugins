---
name: report
description: "File a bug report about the steer plugin ITSELF upstream in element22llc/e22-plugins — gather the defect, scrub secrets/absolute-paths/product-code, dedupe against existing upstream issues, and file via gh only on your confirmation (detect-and-offer, never auto-file). For steer's own defects, not product-code bugs (those go to the product tracker via /steer:issues)."
when_to_use: 'Use when steer itself misbehaves — a SessionStart self-fault notice appears, a skill/rule gives contradictory or impossible instructions, or a referenced template/script/helper is missing or crashes — and you want it fixed upstream. Also when the user says "report this steer bug" / "file this against the plugin".'
argument-hint: "[describe the defect | run with no args to use recorded faults]"
allowed-tools:
  - Bash(gh auth status *)
  - Bash(gh repo view *)
  - Bash(gh issue list *)
  - Bash(gh issue view *)
  - Bash(gh search issues *)
  - Bash(gh label list *)
  - Bash(git remote *)
  - Bash(git rev-parse *)
---

# Report a steer plugin defect upstream

`/steer:report` is steer's **phone-home channel**: when the plugin's own
machinery misbehaves in a product repo, this files a bug **upstream** in
`element22llc/e22-plugins` (the plugin's home), so it gets fixed for everyone.

Two invariants, always:

- **This is for steer's OWN defects** — a contradictory skill/rule, a missing or
  broken template/script/helper, or a recorded hook fault. Ordinary product-code
  bugs, failing tests, or user mistakes are **not** plugin faults; those go to the
  product tracker via `/steer:issues`. If the problem isn't steer's fault, say so
  and stop.
- **Detect-and-offer, never auto-file.** You render the scrubbed body and the
  user confirms before anything is written. The upstream `gh` write is
  intentionally **not** pre-approved (allowed-tools above are read-only) — the
  permission prompt on the create call is the final human gate. Honour it.

## 1. Establish the report source

Pick where the defect comes from:

- **Recorded faults (no args).** Read `<repo-root>/.claude/steer-faults.log` (one
  pipe-delimited record per line: `version|source|signature`). These were
  recorded by steer's hooks via `lib/report-fault.sh` and surfaced by
  `surface-faults.sh`. Each line is one candidate report.
- **A defect described now (args, or one you just hit).** The user describes it,
  or you observed a skill/rule contradiction or a crashed template/script this
  session. Capture the surface (skill/rule/hook/template) and what triggered it.

If there is no fault log and nothing concrete to report, say there's nothing to
file and stop — never invent a defect.

Read the **steer version** from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`
(or the SessionStart banner). Read the consumer repo **slug** from
`git remote get-url origin` → keep only `owner/repo`; never the local path.

## 2. Build the report from the template

Use `${CLAUDE_PLUGIN_ROOT}/templates/github/issue-bodies/steer-bug.md`. Fill
every section. Set the two markers at the top:

- `<!-- steer:self-report=1 -->` — keep verbatim.
- `<!-- steer:fault-fingerprint=SOURCE:SIGNATURE -->` — the **dedup key**. Build
  it as `<source>:<signature>` from the fault record (e.g.
  `inject-standards.sh:rules directory missing`), or for a described defect, a
  short stable slug of the surface + symptom. It must be path-free and stable so
  the same defect maps to the same fingerprint across repos and sessions.

## 3. Scrub before anything leaves the repo

The report goes to a **shared** repo. Before rendering or filing:

- Rewrite absolute paths to `<repo>/…`; drop machine/user directory prefixes.
- Redact anything secret-shaped (tokens, keys, URLs with credentials, `.env`
  values) — replace with `[redacted]`.
- Do **not** include product source code. A short steer-side artifact (the hook
  output, the contradictory instruction) is fine; a product file is not.
- Keep the consumer identity to the `owner/repo` slug at most. If even that is
  sensitive, omit it.

## 4. Deduplicate upstream

Detect capability, then search before creating:

1. `gh auth status` — confirm authentication. If a **GitHub MCP** server is
   available, prefer it for the search/create; otherwise use `gh`.
2. Search open + closed issues for the fingerprint:
   `gh issue list --repo element22llc/e22-plugins --state all --search "<signature>" --json number,title,url,state`
   and/or `gh search issues "<signature>" --repo element22llc/e22-plugins`.
3. **Match found** → don't open a duplicate. Show the user the existing issue and
   offer to add a short "also seen in `<slug>` on v`<version>`" comment (with the
   fingerprint) instead. One issue per fingerprint.

## 5. Confirm, then file

Render the **full body** to the user and the target (`element22llc/e22-plugins`,
labels `bug` + `steer:self-report`). Ask for explicit confirmation.

On confirmation, write the body to a temp file and create the issue (you'll see a
permission prompt — that's the gate):

```sh
gh issue create --repo element22llc/e22-plugins \
  --title "[steer] <one-line summary>" \
  --label bug --body-file <tmpfile>
```

- If the `steer:self-report` label doesn't exist upstream and you can't create
  it, file with `bug` alone — never fail the report over a missing label.
- **No upstream write access / `gh` unauthenticated / offline** → fall back:
  print the rendered body and a paste-ready
  `https://github.com/element22llc/e22-plugins/issues/new?template=steer-self-report.yml`
  link (or the full `gh issue create` command), so the user files it manually.
  Say plainly that nothing was filed automatically.

## 6. Aftercare

- Report the created issue URL (or that you posted a +1 comment).
- For faults that came from the log: once filed (or the user dismisses them),
  remove `<repo-root>/.claude/steer-faults.log` and
  `<repo-root>/.claude/steer-faults.surfaced` so resolved faults don't linger or
  re-surface. If only some were filed, leave the rest.
- Never commit these files or the report to the product repo — this channel
  touches the plugin's repo only, and `.claude/steer-faults.*` is git-ignored.

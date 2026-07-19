---
name: report
description: "File a bug about the steer plugin itself upstream in element22llc/e22-plugins — gather the defect, scrub secrets/paths/product code, dedupe against existing issues, and auto-file via gh. For steer's own defects, not product bugs (those go to /steer:issues)."
when_to_use: >-
  Use when steer misbehaves — a SessionStart self-fault notice, contradictory or
  impossible skill/rule instructions, a missing or crashing bundled helper — or
  on "report this steer bug".
argument-hint: "[describe the defect | run with no args to use recorded faults]"
allowed-tools:
  - Bash(gh auth status *)
  - Bash(gh repo view *)
  - Bash(gh issue list *)
  - Bash(gh issue view *)
  - Bash(gh search issues *)
  - Bash(gh label list *)
  - Bash(gh issue create --repo element22llc/e22-plugins *)
  - Bash(gh issue comment --repo element22llc/e22-plugins *)
  - mcp__github__issue_write
  - mcp__github__search_issues
  - mcp__github__list_issues
  - mcp__github__add_issue_comment
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
- **Scrub and dedupe, then auto-file.** You render the scrubbed body and file it
  without a confirmation step — the upstream `gh`/MCP create is **pre-approved**
  in allowed-tools above. The safety floor is the scrub (§3) and the fingerprint
  dedupe (§4), not a human prompt: if the scrub finds something it cannot safely
  redact, it **omits** it (or drops the whole field) rather than asking.

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
- **Fail closed by omission, never by asking.** The report is auto-filed, so when
  something can't be confidently redacted (an unclassifiable secret-shaped value,
  an unavoidable absolute path, product code), **drop it** — omit the line or
  field entirely. Never pause to ask the user how to redact.

## 4. Deduplicate upstream

Detect capability, then search before creating:

1. `gh auth status` — confirm authentication. If a **GitHub MCP** server is
   available, prefer it for the search/create; otherwise use `gh`.
2. Search open + closed issues for the fingerprint:
   `gh issue list --repo element22llc/e22-plugins --state all --search "<signature>" --json number,title,url,state`
   and/or `gh search issues "<signature>" --repo element22llc/e22-plugins`.
3. **Match found** → don't open a duplicate. Add a short "also seen in `<slug>` on
   v`<version>`" comment (with the fingerprint) to the existing issue instead of
   filing a new one — no need to ask first. Prefer the GitHub MCP comment tool;
   the `gh issue comment --repo element22llc/e22-plugins <n>` fallback is
   pre-approved only with `--repo element22llc/e22-plugins` as its first flag.
   One issue per fingerprint.

## 5. File it

Write the scrubbed body to a temp file and create the issue against
`element22llc/e22-plugins` with labels `bug` + `steer:self-report`. This is
pre-approved in allowed-tools — no confirmation, no permission prompt. Keep
`--repo element22llc/e22-plugins` as the **first** flag: the pre-approval is
scoped to that exact prefix, so a reordered create would fall back to a prompt.

```sh
gh issue create --repo element22llc/e22-plugins \
  --title "[steer] <one-line summary>" \
  --label bug --label steer:self-report --body-file <tmpfile>
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

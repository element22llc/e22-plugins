# `/steer-protect apply` — the write path

Read this file when the dev has confirmed an `apply`, and not before. The
guardrails, the authorization boundary, the preconditions, `Resolve desired
state`, and `Verify` stay in `SKILL.md` and still bind every step here — this
file is only the write procedure and its failure paths.

## Steps — only after explicit confirmation

When rules are drifted or absent:

0. **Profile selection** (`apply --solo` / `apply --team` only). Set `profile:` in
   the repo's **own** `policy/branch-protection.yml` to the requested value — the
   scaffold seeds that copy, so edit the existing line; if the repo has no copy,
   create it from `https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/policy/branch-protection.yml` first
   (verbatim, then set the line), because the plugin default is read-only and
   consumer-first resolution needs the choice to live in the repo. Then
   re-resolve the desired state with the profile overlaid (`SKILL.md` →
   "Resolve desired state") before continuing. Never write `solo` when the
   collaborator count is known to be > 1 — say so and keep `team`.
1. Show the **exact** request you will run — the full classic-protection body that
   closes the gap. Pipe the JSON from `echo` into `--input -` rather than using a
   heredoc: a heredoc's closing delimiter must sit at column 0, but these examples
   are indented inside a list, so a copy-pasted heredoc hangs at the `heredoc>`
   prompt. The piped form below has no terminator and pastes safely at any
   indentation (single-quote the JSON so the shell does not expand `$`):
   ```sh
   echo '{"required_status_checks":{"strict":false,"contexts":["<resolved-ci-context>"]},"enforce_admins":true,"required_pull_request_reviews":{"required_approving_review_count":1,"dismiss_stale_reviews":true},"required_linear_history":true,"restrictions":null}' \
     | gh api -X PUT "repos/${OWNER}/${REPO}/branches/${BRANCH}/protection" --input -
   ```
   **Every *policy* value in that body comes from the policy file, not from this
   example** (`restrictions: null` is the one exception — the API requires the field
   and the policy does not carry it) —
   `policy/branch-protection.yml` is the source of truth, and the body above shows
   its *current* values only as an illustration. Read each field from the policy for
   the branch in scope (`strict`, `contexts`, the review counts, `enforce_admins`,
   `required_linear_history`) exactly as you already resolve the `ci` context name
   from the workflow — with the selected **profile** overlaid (under `solo` the
   review count is `0`, on `prod` too). Emitting a value this example hardcodes while the policy says
   otherwise makes the step-4 re-verify report permanent drift on a branch you just
   "fixed". When you emit the concrete command for a dev, substitute the resolved
   `OWNER`/`REPO`/`BRANCH` and the real CI context inline — do not leave `${...}`
   placeholders or a heredoc in the command you hand them to run. Run this PUT
   **once per branch in scope** (default branch, then each declared branch that
   exists), substituting that branch's `BRANCH` and resolved fields each time.
2. **Wait for the dev's explicit confirmation.** Do not apply without it.
3. Apply the repo-level settings as **separate** calls — once for the repo, not
   per branch — surfaced and confirmed
   the same way as the protection PUT:
   - secret scanning + push protection **and** Dependabot security updates in one
     `gh api -X PATCH "repos/${OWNER}/${REPO}"` with the `security_and_analysis`
     block;
   - Dependabot **alerts** via `gh api -X PUT
     "repos/${OWNER}/${REPO}/vulnerability-alerts"` (no body; its own endpoint).
4. After applying, re-run the verify diff and report the new state.
5. **Graduating a solo-trunk repo** (the marker flip + `/spec/history/` entry
   `SKILL.md` describes): if the `## Delivery mode` section also carries a
   graduation waiver — `<!-- steer:graduation=waived -->` — **delete that line**
   and its waiver prose in the same edit, and let the graduation entry say the
   waiver ended here. A waiver left behind is inert in pr-flow but reads as a
   contradiction. The graduation entry also names the **profile** applied
   (`solo` or `team`) — for `solo`, that entry is the record of the choice the
   policy's "tighten, don't loosen" note asks for; no separate ADR is needed.

**Insufficient permissions (`403`/admin required):** you cannot set protection
without admin on the repo. Do not retry blindly — print the equivalent manual
steps (**Settings → Branches → Add branch ruleset**, or **Settings → Rules**)
mapped to each policy field, and let the dev (or an org admin) apply them.

**Protection unavailable (plan limit):** on some GitHub plans branch protection
cannot be enabled on private repos at all (the API returns `403` with an
upgrade message). The two-state model still applies — the repo runs pr-flow on
the honor system: same branch + PR + never-merge flow (rule 45), just without
the server wall. Recommend recording that exception as an ADR (run
`/steer-adr`) so the gap is a documented decision `verify` and `/steer-audit`
keep visible, not an oversight.

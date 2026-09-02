---
name: sync
description: "Bring a bootstrapped repo up to date with the current plugin — apply ledger migrations, reconcile spine + scaffold against current templates, repair capability wiring and stale invocations, re-stamp /spec/.version, and land a PR. Read-then-propose, never clobbers."
when_to_use: >-
  Use on a steady-state repo after a plugin release, when an upstream rename or
  missing capability wiring needs repair, or with --check for a read-only
  capability + drift report with no branch or PR.
argument-hint: "[--check]"
allowed-tools:
  - Bash(git status *)
  - Bash(git branch *)
  - Bash(git switch *)
  - Bash(git checkout -b *)
  - Bash(git diff *)
  - Bash(git log *)
  - Bash(git rev-parse *)
  - Bash(git add *)
  - Bash(git mv *)
  - Bash(git commit *)
  - Bash(git push)
  - Bash(git push -u origin *)
  - Bash(git push origin *)
  - Bash(gh pr create *)
  - Bash(sh *scripts/scan-spine-state.sh*)
  - Bash(sh *scripts/scan-capabilities.sh*)
  - Bash(sh *scripts/scan-invocations.sh*)
  - Bash(sh *scripts/template-reconcile.sh*)
  - Bash(python3 *scripts/scaffold_reconcile.py*)
---

# Sync a repo to the current plugin

A repo materializes part of the plugin into itself at bootstrap time — the
`/spec` spine, the bundled scaffold (CI, `mise.toml`, PR template, …). Those
copies are **frozen at the plugin version that wrote them**. `/plugin update`
refreshes the *plugin* (rules, skills, reference prose read in place), but it
does **not** touch the files already on disk. `/steer:sync` closes that gap: it
carries an already-bootstrapped repo forward to the current plugin's
conventions.

This is the steady-state counterpart to the one-time bootstraps. Use it when:

- a plugin release renamed/moved a spec artifact or changed the scaffold, and
  this repo still has the old shape;
- you want a repo's spine + scaffold reconciled against the current templates
  without re-running a full adoption;
- someone asks to "sync to the latest standards / plugin version".

It is **not** a bootstrap (no `/spec` → `/steer:init` or `/steer:adopt`), **not** a
spec-vs-tracker drift check (`/steer:audit spec`), and **not** a code-health audit
(`/steer:audit`). Those operate on different axes; this one is
**repo-structure-vs-plugin-conventions**.

## Guardrails

- **Structure only, never behavior.** Sync moves/renames artifacts and splices
  in template additions; it does not refactor app code, resolve open questions,
  or re-triage productionization. Code health is `/steer:audit`; drift is
  `/steer:audit spec`.
- **The ledger is the source of truth for non-additive changes.** Apply
  renames, deletions, in-file token rewrites, and whole-file/whole-section re-takes
  only from `MIGRATIONS.md` entries — never
  improvise a transform from memory of "what changed."
- **Capability repair is presence + wiring only.** `CAPABILITIES.md` is the
  source of truth for which files unlock which capability and how to repair a gap.
  Create a capability-critical file only when its conditional predicate applies
  and it isn't `disabled`; re-copy a `verbatim` script only because it's
  contractually identical (after showing the diff); otherwise splice the named
  marker / propose, never clobber. Don't broaden into app code (`/steer:audit`)
  or spec↔tracker drift (`/steer:audit spec`).
- **Read-then-propose, never clobber.** Diff and ask before touching any file
  that exists; reconcile scaffold into it rather than replacing it; preserve
  every filled-in value. Never touch working app code.
- **Invocation hygiene is a token rewrite on live prose only.** Apply only the
  detector's deterministic classes (`legacy-e22`, `reference-mode`) as exact-token
  rewrites; propose (never auto-apply) `noncallable-gateway` front-door swaps and
  surface `unknown` tokens for the dev. Scan only the live instruction surfaces the
  detector targets — never rewrite append-only/provenance prose (`spec/history/*`, `spec/HISTORY.md`,
  reports, ADRs), and never the marketplace id `e22-plugins`.
- **Verify versions from disk.** `TARGET` comes from `plugin.json`, `FROM` from
  `/spec/.version` — never from training-data memory.
- **Branch + PR; never commit to `main` — in *both* delivery modes.** Plugin
  maintenance is structural, not feature work (rule `36-issue-first`), so a sync
  lands on its own `feat/sync` branch even in a declared **solo-trunk** repo,
  where feature work goes straight to trunk (rule `45-commit-autonomy`). This is
  the deliberate exception to that rule, not an application of it. The dev's PR
  **merge review** is the hard gate; push the branch and open the PR yourself,
  announced — never merge it.
- **The PR targets `BASE`, never `main` by default.** `BASE` is the branch the
  dev invoked the sync from (captured in step 1), so the sync lands back onto the
  work it continues. Only when `BASE` is itself `main` does the PR target `main`.
  Never silently default `gh pr create` to the repo's default branch, and never
  ask the dev to pick the base — `BASE` already answers that.

## Axis at a glance

| Skill | Compares | Edits |
|---|---|---|
| **sync** | materialized spine + scaffold ↔ current plugin conventions, capability prerequisites, **and live-prose invocation hygiene** | yes (structural; read-then-propose) |
| `/steer:audit spec` | as-built `/spec` ↔ tracker spec export | no |
| `/steer:audit code` | code ↔ standards (leverage-ranked) | no |

Pass **`--check`** to run read-only: steps 1–6.5 detect and report (the migration
preview, the capability status table, and the invocation-hygiene findings) but
nothing is branched, written, or PR'd. Use it to see what a full sync would do.

## Steps

1. **Confirm it's a sync case, and capture the base branch.** Sync only operates on
   a spine steer itself wrote — check the *state*, don't merely test that `spec/`
   exists:

   ```sh
   sh "${CLAUDE_PLUGIN_ROOT}/scripts/scan-spine-state.sh"
   ```

   One read-only call; it prints the repo root, the spine state, the polyrepo
   role step 6 needs, and the declared tracker repository. Run it **once** here
   and carry the values forward.

   Only **`damaged`** and **`managed`** are sync cases. **`unmanaged`** or
   **`foreign`** is not: stop and redirect per `/steer:setup`'s routing table
   (the canonical state→skill map) — never "reconcile" a directory steer never
   wrote. **Before creating any branch, record the currently checked-out
   branch — call it `BASE`:**

   ```sh
   BASE=$(git rev-parse --abbrev-ref HEAD)
   ```

   `BASE` is the branch the dev invoked the sync from; the sync's PR targets it
   (step 8), so the sync lands back onto the work it continues, not `main`.

   **If invoked as `/steer:sync --check`**, do **not** branch or write anything:
   run steps 2–6.5 read-only (the migration preview, the capability status table,
   and the invocation-hygiene findings), report, and **stop here — nothing below
   this paragraph runs under `--check`.**

   **Otherwise (the full, writing flow):**
   branch a `feat/sync` off `BASE` and work there — never commit to `main` or
   to `BASE` directly, solo-trunk included (see Guardrails). If `BASE` *is* `main` (the dev ran
   sync from a clean trunk), that's the one case the PR targets `main`. Commit,
   push, and open the PR autonomously as step 8 says — only the **merge** waits
   for the dev (commit-autonomy rule; never pause to ask whether to commit).

2. **Update the plugin first.** The ledger and templates this skill reads are
   only current if the plugin is. Tell the dev to run
   `/plugin update steer@e22-plugins` if they haven't this session, then
   resolve the **current plugin version** from
   `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` — never from memory. Call
   this `TARGET`.

3. **Read the repo's stamp.** Read `/spec/.version` for the version the spine was
   last materialized or synced at — call it `FROM`:

   ```sh
   grep -m1 -oE '[0-9]+\.[0-9]+\.[0-9]+' spec/.version 2>/dev/null || echo "unstamped"
   ```

   `unstamped` means the repo predates stamping (bootstrapped before this
   feature) — treat `FROM` as `0.0.0` and rely on each migration's precondition
   to decide what actually applies. If `FROM` already equals `TARGET`, no
   **version-keyed** entry can be pending — but do **not** skip step 4: an entry
   headed `### [Unreleased]` carries no version to compare, and skipping it here
   would strand it on exactly the repos already stamped at that version, which is
   the failure the `[Unreleased]` convention exists to prevent. Walk the ledger for
   those entries, then continue to step 5 (additive reconciliation can still find
   template drift) — say so rather than going silent. The stamp is an
   **optimization, not the safety mechanism**; the precondition is.

   **Establish the repo profile and the polyrepo role** before anything is
   reconciled — the `CLAUDE.md` `## Profile` marker (`<!-- steer:profile=… -->`;
   absent → `app`) and step 1's `- polyrepo role:`. Together they select which
   scaffold overlay steps 5–6 compare against and which `/spec` paths are
   off-limits, so resolve them here and carry them forward. **Open
   [`RECONCILE.md`](${CLAUDE_PLUGIN_ROOT}/skills/sync/RECONCILE.md) now** — its
   §"What steps 4–6 may touch" carries the per-profile and per-role rules, and
   steps 5–6 are in the same file.

4. **Apply pending structural migrations.** Open the ledger at
   `${CLAUDE_PLUGIN_ROOT}/templates/reference/MIGRATIONS.md`. Walk its entries
   oldest→newest. For each entry whose introducing version is **greater than
   `FROM`**, check its **precondition** against the repo; apply the **action**
   only if the precondition holds (entries are idempotent and self-detecting, so
   an entry already applied — or never relevant — is a safe no-op). An entry
   headed **`### [Unreleased]`** carries no version to compare, so it is **always
   walked** by its precondition, never skipped — that is the property that makes a
   forgotten release-time rename safe. Because the
   precondition is the real gate, when `FROM` is `unstamped` walk the **whole**
   ledger by precondition. Apply each as the ledger directs — `git mv` for
   renames so history follows, `git rm` for deletions, an **in-file token
   rewrite** (replace only the exact old→new string pairs the entry enumerates,
   never a broader match), or a **whole-file or whole-section re-take** (the entry
   names a file — or one bounded region inside it — whose content moved past any
   enumerable pair set, so the current template replaces that whole file or region;
   carry the consumer's own edits forward) — all **read-then-propose, never clobber**
   filled-in content. For a token-rewrite entry, run its precondition grep first and
   show the diff of proposed substitutions before applying; for a re-take, show the
   diff against the consumer's copy — never a blind overwrite — and for a section
   re-take confirm the entry's stated region boundaries before replacing anything. List each migration
   you're applying (and each skipped, with why) before touching files.

5. **Reconcile the materialized templates (additive)**,
   6. **repair capability gaps (missing / mis-wired scaffold wiring)**, and
   6.5. **repair invocation hygiene (stale / invalid slash invocations in live
   prose).** These steps carry the bulk of the procedure — the
   template-reconciliation convention, the `scaffold_reconcile.py` structured
   merge, the `.mcp.json` exemption, the capability scan/repair table, and the
   `scan-invocations.sh` findings. All three live in
   [`RECONCILE.md`](${CLAUDE_PLUGIN_ROOT}/skills/sync/RECONCILE.md) — read it
   before executing. All are additive and never clobber; under `--check` they
   report only.

7. **Re-stamp.** Write `TARGET` into `/spec/.version` (overwrite the old value):

   ```
   # Spec-spine version — managed by /steer:init, /steer:adopt, /steer:build,
   # /steer:sync. Do not edit by hand.
   <TARGET>
   ```

8. **Record and hand off.** Write a `/spec/history/` entry (what synced —
   `FROM → TARGET`, which migrations applied, which templates reconciled, which
   capability gaps repaired — why, who asked, refs) — in a member, to the
   workspace's ledger per rule `32-living-docs`; the member's own durable record
   is its `/spec/.version` stamp. Commit on `feat/sync`, then
   push and open the PR
   **against `BASE`** (the branch captured in step 1) without asking, announcing
   it (Commit autonomy) — the dev's merge review of that PR is the gate. The PR base
   is **always `BASE`**, not `main` — the sync rejoins the work it continues. Do
   not ask the dev which base to use; state that the PR targets `BASE` and let
   them correct it if wrong. When you create it:

   ```sh
   gh pr create --base "$BASE" --head feat/sync ...
   ```

   Run the end-of-session checklist.

9. **Recommend the next action.** Emit a `## Recommended next actions` block per
   `${CLAUDE_PLUGIN_ROOT}/templates/reference/NEXT-ACTIONS.md`, derived from the
   sync's state.

   | Observed state | Category | Action / suggested command |
   |---|---|---|
   | Failed migration or merge conflict | Blocking now | Resolve it before continuing |
   | Pending migrations in the ledger | Blocking now (next transition) | Apply them |
   | Reconcile or capability-repair batch proposed, not approved | Human decision required | Dev reviews the proposed batch (no command) |
   | Invalid invocation flagged `noncallable-gateway`/`unknown` (needs a front-door/semantic decision) | Human decision required | Dev picks the correct invocation (no command) |
   | Capability needs an external secret/config (`claude.yml` API key; branch protection) | Human decision required | Dev adds `ANTHROPIC_API_KEY`, or applies the gate via `/steer:protect` |
   | Capability follow-up after a created file (Issue Forms added) | Recommended | `/steer:issues bootstrap-labels` |
   | Sync PR open, awaiting review | Human decision required | A dev reviews/merges the PR (no command) — execution is done, integration is not |
   | Nothing pending; `/spec/.version` current; all capabilities present-and-wired | Complete | `No action is currently required.` |

   Pick one `Current recommended action` by precedence (a failed migration
   outranks a capability gap). An opened-but-unmerged sync PR is **not**
   `Complete`. Never clobbers, never commits to `main`.

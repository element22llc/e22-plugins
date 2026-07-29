# One-time convention mandate — granted 2026-07-29

`/audit-loop` L3d ends with the repo's frozen-scope rule: fixing an incoherence in
`CLAUDE.md`, `AUTHORING.md`, `CONTRIBUTING.md`, or a gate script is in scope when
the audit found it; *redefining a convention* while you are there is not.

This file **suspends that second half, for the three items enumerated below only,
for one run.** It exists because the five-round convergence in
[#423](https://github.com/element22llc/e22-plugins/pull/423) proved these three are
findings the loop is structurally incapable of clearing: each one *is* a convention
change, so every round re-finds it, reports it, and defers it. Three findings of
pure churn per round is not convergence evidence, it is noise in the ledger.

## Scope — exactly these three, nothing adjacent

### 1. `scripts/check_changelog.py` — `BEHAVIOUR_PREFIXES` misses both Copilot manifests

`BEHAVIOUR_PREFIXES` covers six `plugins/steer/*` prefixes plus the exact path
`plugins/steer/.claude-plugin/plugin.json`. It does **not** cover
`plugins/steer/.github/plugin/plugin.json` or `.github/plugin/marketplace.json`,
so a future non-version edit to either ships with no CHANGELOG entry.

**Authorized:** extend the behaviour set to cover both. This is a gate-coverage
gap, not present drift — no existing entry is missing.

### 2. `CLAUDE.md` + `CONTRIBUTING.md` — "root `.github/` ships nothing" is false

`CLAUDE.md:94` and `CONTRIBUTING.md:121` both classify the whole root `.github/`
as shipping nothing. `.github/plugin/marketplace.json` sits under it, is the
consumer-facing Copilot marketplace, and carries steer's released version. This is
the prose that makes gap 1 read as intentional, which is why the two are granted
together — fixing either alone leaves the repo self-contradictory.

**Authorized:** correct both statements to except `.github/plugin/`.

### 3. `MIGRATIONS.md` + `skills/sync/SKILL.md` — the fourth action class

Both files authorize exactly three migration shapes: `git mv`, `git rm`, and an
in-file token rewrite enumerating old→new pairs. Step 3 of the `### v3.24.0` entry
is a whole-file script refresh with dev-edit carry-forward, which is none of them,
and `ws.sh` has no `CAPABILITIES.md` entry, so the verbatim-re-copy path is closed
too. The step is *needed* — nothing else refreshes `ws.sh` content.

**Authorized: option 1 only** — add "re-take a whole file (read-then-propose diff,
carry dev edits forward)" as a named action class to `MIGRATIONS.md` §"How a
migration is applied" **and** `plugins/steer/skills/sync/SKILL.md`, in both places,
with the same vocabulary.

**Not authorized: option 2** — giving `ws.sh` a `CAPABILITIES.md` entry. That
forecloses local extension of a shipped script, which is a real trade against a
consumer's ability to adapt it, and it is not the loop's call to make. If the
evidence in-round argues option 2 is materially better, **defer it to the human**
rather than taking it.

## Standing constraints — unchanged by this grant

- **Not a general licence.** Any *other* convention question the round surfaces is
  still `deferred-for-human`. If a fix here appears to require touching a fourth
  convention, that fourth one is deferred — do not follow the thread.
- **`plugins/steer/` fixes still need a `CHANGELOG.md` bullet** under the existing
  `## steer` → `### [Unreleased]` heading. Items 1 and 2 touch repo tooling and
  root docs, which ship nothing and need no bullet; item 3 touches
  `templates/reference/MIGRATIONS.md` and `skills/sync/SKILL.md`, which do.
- **No version bump, no heading rename, no release.** `/release` still owns the
  semver call. The `### v3.24.0` key in `MIGRATIONS.md` is confirmed correct by
  the human — leave it alone.
- **Never fix by weakening a check.** Item 1 *widens* gate coverage; nothing here
  authorizes loosening a validator or deleting an assertion.

## Expiry — this file is consumed, not kept

The round that acts on this mandate **deletes this file in the same commit**, and
names it in the round's ledger line. A one-time grant that survives its round is a
permanent convention change made by omission, which is the exact failure this repo's
frozen-scope rule exists to prevent. If a later run needs a mandate, a human writes
a new one.

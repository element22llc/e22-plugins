# `/steer:issues reconcile` — issue ↔ spec consistency

Read this file when running `reconcile`. The guardrails, coupling rules, the
question-reconciliation floor, and the `## Recommended next actions` contract
stay in `SKILL.md` — they apply to every mode and are not repeated here.

## `reconcile #N | feature-id | --all`

Verify issue ↔ spec pointers agree and the lifecycle is internally consistent;
update only the managed block of any issue it touches; **never auto-resolve
behavioural drift or a product decision** — route those to a human.

Two scopes:

### bounded (`#N` / `feature-id`)

One issue or feature. Enforce the question-reconciliation floor in `SKILL.md`.

### repo-wide (`--all`)

Sweep the spine + tracker and report every disagreement:

- referenced issues that no longer exist;
- a `live` intent whose feature issue is not terminal — released, never closed;
- approved specs missing a tracker ref (`require_tracker_ref_for_features`);
- open `spec-drift` issues that no longer reproduce;
- sub-issues with no parent link;
- **epic↔feature inconsistency** (a closed epic with open child features or vice
  versa, or a `validate`/`done` epic with no linked features);
- promoted questions whose issue is closed but whose `Q-NNN` is still `open`;
- and **contract-less issues** (below).

**Delivery state is never reconciled — there is nothing to reconcile.** A feature's
progress lives only in its issue `steer:state`; the spec's `Status:` holds product
state (`draft`/`approved`/`live`) and no longer mirrors it, so a merged PR, a close,
or a reopen cannot leave a stale `Status`. Do not compare `Status:` against
`in-progress`/`validate`/`done` and do not "fix" a spec that reads `approved` while
its issue reads `done` — that pairing is correct (see the crosswalk in
`ISSUE-WORKFLOW.md`). The only spec-side state worth checking is the pair above:
`live` without a terminal issue, and an `approved` feature with no tracker ref.

**Contract-less issues — the after-the-fact recovery path for a raw create that
bypassed `/steer:tracker-sync`** (the point-of-action issue-create contract
nudge in `check-bash-actions.sh` is best-effort, not a gate). Flag any open
issue missing the machine-readable contract: **no `steer:` markers AND no
`steer:managed` block** (so neither `steer:kind` nor `steer:source` is set, the
issue carries no `source:*` label, and its Type is the unset default). Such an
issue is invisible to marker-based dedup (`triage`/`board`) and to every
lifecycle check above, so surface it here with the retrofit action — infer kind
+ labels + Type via `/steer:issues triage` and apply the contract through
`/steer:tracker-sync` (markers + derived `source:*` label + Issue Type).

**Never invent intent:** retrofit only the machine-readable contract onto the
existing human body; do not rewrite or guess the issue's content, and leave a
genuinely human-authored issue (one a human typed directly) for `triage` to
label rather than treating it as drift.

Output is a reconciliation report + proposed actions, confirmed once before any
write. `--all` is read-heavy — route all fetches through `/steer:tracker-sync`
and say so.

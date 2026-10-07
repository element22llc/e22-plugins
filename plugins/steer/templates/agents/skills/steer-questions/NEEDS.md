# `/steer-spec questions needs` - sweep what the client still owes before a wave

Read this file only when running `needs`. The default resolve flow, the
open-question locations, the done-when contract and the coupling rules stay in
`SKILL.md`; rendering stays in [`BUNDLE.md`](BUNDLE.md).

## What it is for

Before a new wave of work, a dev needs **one list of everything still owed by
the client**: access to grant, accounts or tools to provision, decisions to
make, and clarifications. The signals are already in the repo, scattered across
the spine, `policy/*.yml`, ADRs and the tracker. This mode reads them, proposes
**one `### Q-NNN` per real gap** with the matching `kind:` (`ENUMS.md` ->
`question_kind`), and writes them **only after the dev confirms the list**.
It renders nothing itself: the questions it writes are what
`/steer-spec questions bundle` then hands the client, and the answers come back
through `/steer-spec intake clarify` like any other. **No new return path.**

The spine stays the source of truth. A gap inferred from a heuristic (an empty
`observability:`, an unconfirmed deploy target) is a guess until a dev confirms
it, so nothing reaches the client unconfirmed - and once written, each ask is a
durable question, aged, tracked and closed like any other.

## Flow

1. **Require a spine.** No `spec/.version` -> route to **`/steer-setup`** and
   stop (`SKILL.md` step 0, for the same reason).

2. **Scope.** No argument = the whole spine. `needs --milestone <m>` narrows
   to the wave: the features whose issues sit in milestone `<m>` (the issue's
   `<!-- steer:feature-id=... -->` marker, `ISSUE-SCHEMA.md`), plus the
   product level. An unknown milestone -> list the open milestones and ask;
   never guess one.

3. **Read the signals.** Read-only. Tracker reads go **only** through
   `/steer-tracker-sync` (export, filtered by label / milestone / state) - this
   mode never calls the tracker directly. An unreachable tracker skips the
   tracker rows and says so; it is not "no gaps".

   | `kind` | Signal | Concrete evidence that proposes it |
   |---|---|---|
   | `clarification` | spec `Q-NNN`, `status: open` / `investigating` | already a question - **listed, never duplicated** |
   | `decision` | issue labelled `needs:product-decision` with no `steer:question-id` | the issue ref |
   | `decision` | ADR `Status: Proposed` whose `Deciders:` names someone outside the dev team | the ADR path |
   | `access` | `policy/delivery.yml` names a non-`none` `deploy_on_merge` / `production_gate` but nothing records the deploy target (no ADR, no `infra/` target) | the field |
   | `access` | rule `60-high-risk` "the declared store" has no declared store yet (`policy/org.yml` not `e22` and no ADR naming one) while code or `.env.example` reads secrets | the env names + the missing declaration |
   | `access` | `spec/tracker.md` `owners:` has a blank role, or the tracker is unreachable for lack of access | the field / the failed read |
   | `tooling` | `policy/delivery.yml` `observability: []` (an explicit "not wired yet") | the field |
   | `tooling` | a third-party service a `contract.md` or `.env.example` names, with no account recorded for it (no ADR, no `spec/design/` source, no answered question) | the file + the service name |

   **Never fabricate.** A gap with no concrete signal - a file, a field, an
   issue - is not proposed. "They probably need monitoring" is not a signal;
   `observability: []` is.

4. **Dedupe.** A gap already covered by an `open` / `investigating` /
   `deferred` question (same feature, same ask) is not proposed again - list
   it as already tracked. A `resolved` question whose answer still holds closes
   the gap; one the repo now contradicts is a new question citing the old id.

5. **Propose - and stop for the dev.** Print the proposed list grouped by
   `kind`, each line: the target file, the question in plain language a client
   can answer, its `kind` / `owner` / `impact` / `required_before`, and the
   evidence. Defaults: `impact: blocking` when the wave cannot start without
   it, else `non-blocking`; `owner: product` for a client ask, `owner:
   security` for an access grant on production data; `required_before` the
   earliest gate the wave hits. **Write nothing until the dev confirms**; they
   may drop, merge or reword lines. Nothing confirmed -> stop.

6. **Write the confirmed questions.** Each becomes a `### Q-NNN` block in the
   canonical format (`SPEC-FRAMEWORK.md` -> "Open-question format"), with
   `kind:` set and `created: <today>`:
   - **Home.** The owning feature's `spec/features/<id>/intent.md` when the gap
     belongs to one feature; `spec/vision.md` for product-level and
     cross-feature gaps (access, tooling and environment asks usually land
     here).
   - **Id.** The next free `Q-NNN` in that file - after the highest number any
     heading there uses, placeholders included.
   - **Provenance.** A gap raised from an issue sets `tracker:` to that ref;
     other gaps cite their evidence (the file / field) in the question body.
   - **Never a secret.** An `access` question asks the client to **grant or
     confirm** - a role, an account invite, a store path - never to send a
     key, token or password. Word it that way: "Who should be invited to the
     AWS account as deployer?", never "What is the deploy key?".
   - **Not a design.** `/infra` and IAM stay high-risk (rule `60-high-risk`):
     ask for the access, never draft the IAM policy here.

   The writes land in the working tree for the PR to review - the PR is the
   gate, as in the default flow.

7. **Hand off.** Recommend **`/steer-spec questions bundle`** to render the
   client questionnaire (grouped by kind). Answers come back with
   **`/steer-spec intake clarify <filled-doc>`** and fold through the default
   `/steer-spec questions` flow.

## Guardrails

- **Never solicit a secret value.** The filled questionnaire is committed
  under `spec/sources/`; `bundle` puts the no-secrets line on every `access`
  field, and `intake clarify` stops before committing a pasted credential.
- **Never fabricate.** Every proposed question names its evidence.
- **Read-only until confirmed.** Steps 1-5 write nothing; only step 6 writes,
  and only the confirmed list.
- **No tracker writes.** This mode reads the tracker; promoting a question to
  an issue stays the default flow's step 6.

## Recommended next action

Close with a `## Recommended next actions - /steer-spec questions needs` block
per `https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/templates/reference/NEXT-ACTIONS.md`: after a write,
**render the questionnaire with `/steer-spec questions bundle`** (Recommended);
when nothing was proposed or confirmed, `No action is currently required.`
(Complete).

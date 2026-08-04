# `/steer:build` — steps 5 & 6: scaffold the real app, then build feature by feature

Read this file when you reach step 5. Steps 1–4 (bootstrap, interview, draft
intents, PO validation gate) and step 7 (guardrails) stay in `SKILL.md`, as do
the PO-mode guardrails — which apply throughout everything below. Steps 8–10
(demo, the PO demo-validation gate, handoff) are in `HANDOFF.md`.

5. **Scaffold the real app.** `apps/` starts **empty** — the bundled scaffold
   deliberately ships no starter app (`templates/scaffold/MANIFEST.md` →
   "Deliberately not bundled"), and step 1 bootstrapped this repo through
   `/steer:init` **Path B**. So this step *creates* the first app on the default
   stack (Next.js + TypeScript + Tailwind; PostgreSQL via `compose.yaml`); there is
   no placeholder to replace. (A repo that *is* a legacy template fork does carry
   one — swapping it is `LEGACY-TEMPLATE-FORK.md`'s job, on `/steer:init` Path A,
   not this step's.) Then generate and commit `pnpm-lock.yaml` and resolve the root
   `packageManager` placeholder to the mise-pinned pnpm version, per `/steer:init`
   step 5 ("Pin the toolchain and lock the workspace"), which is written for exactly
   this moment — "once the first real app/workspace exists". Add the app's
   `apps/<app>/Dockerfile` from the plugin's
   `templates/docker/` reference (`Dockerfile.node`, or `Dockerfile.python` for a
   Python service) plus the repo-root `.dockerignore`, adapting the base image to
   the pinned runtime — CI builds it once present. Draft the initial stack ADR
   yourself via `/steer:adr` — the PO
   approves intent, not ADR prose. **This is the change that establishes the
   stack and layout, so fill the root living docs in it** (Living-docs rule):
   populate `ARCHITECTURE.md` — the tech-stack table from `mise.toml` /
   `package.json` / `compose.yaml`, and the apps/packages map from the real
   layout (every `apps/*` and `packages/*` you just created) — and edit
   `apps/README.md` so it no longer claims the folder "starts empty" once a real
   app exists. These are doc upkeep applying a decision already made, not new
   decisions — no PO sign-off, and the PO never sees them (they're for the dev
   reviewer).
6. **Build feature by feature.** Who *owns implementation* depends on whether this
   repo is GitHub-adopted (`/spec/tracker.md` declares `system: github`):

   - **Prototype/local mode — the default (greenfield, no GitHub tracker yet).**
     Issue-first (rule 36) is scoped to `system: github`, so it does not apply
     here. Build the v0 yourself: for each approved intent write `contract.md`,
     implement under `/apps` + `/packages`, and write tests in the same unit of
     work (Definition of Done). Commit coherent units without asking
     (Commit-autonomy rule). **In PR flow** that's a single `feat/*` build
     branch, and the work stays local and provisional until the one v0 handoff
     PR (step 10); **in solo trunk** (chosen in step 1) commit directly to `main`
     with no branch and no v0 PR — the work is provisional on the trunk until
     graduation (step 10). Either way this keeps the PO's inner loop fast — no
     per-feature issue/branch/PR ceremony.
     **"Prototype mode" relaxes only this ceremony** (issues, per-feature
     branches/PRs, approval-gate formality) — it does **not** skip the bundled
     scaffold (step 1) or the spec spine (steps 2–4) or the real-stack app
     scaffold (step 5). A prototype that hand-rolls `package.json` / build config
     / CI instead of installing the scaffold, or that ships no `/spec`, has
     skipped bootstrap, not run it in prototype mode.

   - **Governed mode — repo already GitHub-adopted (`system: github`).**
     Issue-first applies, so implementation runs through
     **`/steer:work`**, the sole owner of
     claim → branch → implement → test → PR → transition — and of adapting that
     flow to the repo's delivery mode (in solo-trunk it commits straight to `main`
     and closes the issue from the trunk commit, no branch/PR). For each approved intent
     (or coherent delivery slice), materialize or reuse a GitHub issue via
     **`/steer:issues`** (which routes tracker I/O through
     `/steer:tracker-sync`), then hand that issue to
     `/steer:work` — **invisibly**: the PO never types a technical
     command and never needs to see an issue number. You keep the PO conversation,
     intent approval (step 4), the app scaffold (step 5), the demo (step 8), and
     the handoff framing (step 10); `work` owns execution. Do **not** branch,
     implement, or open PRs yourself in this mode, and `work` must **not**
     re-enter `/steer:build` (no recursion) — drive one slice at a time.

   In **either** mode, as you build UI seed and grow the root `DESIGN.md` from
   the visual identity you actually implement — swap the placeholder product
   name and `#000000` colors for the product's real name and tokens, and
   promote a token or component once the same choice recurs in 3+ places
   (`Design sources` rule). Don't leave the stub for the dev reviewer.

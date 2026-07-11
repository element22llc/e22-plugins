# Audit dimensions — the standards catalogue behind `/steer:audit code`

The standards dimensions `/steer:audit` `code` mode sweeps, anchored to the
baseline (`rules/85-practices.md`, Definition of Done, the high-risk rule) and
the productionization brief — **not** a generic checklist. Skip any dimension
that doesn't apply to the repo (e.g. design on a backend-only service) and say
so in the report.

1. **Spec conformance & coverage** *(needs `/spec`)* — user-facing features with
   no `intent.md`/`contract.md`; `contract.md` sections stale vs the real code;
   hard-to-reverse choices baked into the code with no ADR under
   `/spec/decisions/`.
2. **Architecture & boundaries** — fat route handlers; domain logic living in UI
   components or handlers instead of shared testable modules; server-first
   violations (secrets/DB access leaking client-side); broken package boundaries.
3. **Data layer** — raw or string-interpolated SQL instead of a parameterized
   query layer; schema changed outside committed, reviewed migrations.
4. **Input validation & config** — external inputs (requests, external API
   responses, env vars) used without boundary validation; scattered raw env reads
   instead of one validated config module.
5. **Error handling & escape hatches** — swallowed errors / empty `catch`;
   unexpected errors not reported with context (Sentry gaps); escape hatches
   without a why-comment (`any`, `@ts-ignore`/`@ts-expect-error`, wholesale
   lint-rule disabling).
6. **Testing** — untested domain logic; bug-fix commits with no regression test;
   high-risk areas without coverage.
7. **Toolchain & dependency health** — outdated dependencies; missing or drifted
   lockfiles (`mise.lock`, `pnpm-lock.yaml`, `uv.lock`, `.terraform.lock.hcl`);
   unpinned toolchain versions. On a GitHub-tracked repo, also note if `main`
   lacks branch protection (the real PR gate) — route to `/steer:protect` to
   verify/apply against `policy/branch-protection.yml`; do not query or change
   settings here (audit is read-only code-health). **Exception:** if `CLAUDE.md`
   declares `Delivery mode: solo trunk (pre-MVP)`, an unprotected `main` is
   intentional — *not* drift. But check whether the repo has **outgrown**
   solo-trunk: a second collaborator (`gh api repos/{owner}/{repo}/collaborators
   --jq 'length'` > 1), a `prod`/`production` branch, or a deploy target (a deploy
   workflow / `infra/` tree). If any holds, **escalate** from "recommend later" to
   "graduation conditions met — run `/steer:protect apply` now to raise the PR
   wall"; if none, report solo-trunk as expected and note graduation is optional
   until the MVP works. (The SessionStart `check-graduation.sh` hook nudges on the
   local signals; this is the networked, on-demand confirmation.)
8. **Design consistency** *(UI repos only)* — `DESIGN.md` drift vs the code;
   styling that recurs in **3+ places** but isn't promoted to a token/component
   (the `DESIGN.md` 3+ rule).
9. **DX & docs** — README quickstart that no longer matches reality;
   `ARCHITECTURE.md` stale vs the code — stack table diverged from
   `package.json` / `mise.toml`, or the apps/packages map missing/naming a
   directory that doesn't match `apps/*`+`packages/*`; `mise.toml` missing the
   tasks a contributor needs (`setup`, `dev`, `test`, `lint`).

**Out of scope of every dimension** — correctness bugs, security
vulnerabilities, and mechanical cleanup are delegated, never re-run by the
audit; the operative routing lives in `/steer:audit`'s Boundaries note
(`/code-review`, `/security-review`, `/simplify`).

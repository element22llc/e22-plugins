---
name: setup
description: "One front door for getting a repo onto the standards — detect the /spec spine state and route to greenfield init, brownfield adopt, or steady-state sync, installing prerequisites first when the toolchain is missing."
when_to_use: >-
  Use when asked to set up, onboard, bootstrap, or adopt a repo, or to sync to
  the latest plugin — the single entry point whenever you would otherwise guess
  between /steer:init, /steer:adopt, and /steer:sync.
argument-hint: "[init | adopt | sync]"
allowed-tools:
  - Bash(git status *)
  - Bash(git rev-parse *)
  - Bash(gh auth status *)
---
<!-- steer:modes init,adopt,sync -->

# Set up a repo on the standards

This is the **one door** for onboarding a repo. The init / adopt / sync split is a
real distinction, but it's one the tool can decide from repo state — so the user
should never have to. Detect the state, announce the path you're taking, then hand
off to the owning skill. Do **not** re-implement their steps here.

## Detect, then route

Compute the spine state with the existing helper rather than inventing detection:

```sh
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/repo-root.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/spine.sh"
. "${CLAUDE_PLUGIN_ROOT}/hooks/lib/scope.sh"
root="$(steer_repo_root "$PWD")" && steer_spine_state "$root"
steer_polyrepo_role "$root" || echo "(single-repo product)"
```

`steer_polyrepo_role` prints `workspace`, `member`, or nothing. It changes what
the state above *means* — see "Polyrepo" below — so read both before routing.

| Detected state | Meaning | Route to |
| --- | --- | --- |
| `unmanaged` + little/no app code | brand-new repo, building from scratch | **`/steer:init`** (greenfield, Path B) |
| `foreign` / `unmanaged` + substantial existing code | a "vibe-coded" app to reverse-engineer | **`/steer:adopt`** |
| unresolved template placeholders present (`@github-handle`, bracketed fill-in markers) | legacy template fork | **`/steer:init`** (Path A) |
| `damaged` | spine stamped but files missing | **`/steer:sync`** (repair) |
| `managed` + template drift flagged | bootstrapped but behind a plugin release | **`/steer:sync`** (update) |
| `managed`, no drift | already current | nothing to do — say so, suggest `/steer:next` |

The `unmanaged`-with-code vs `unmanaged`-greenfield call is the one judgment the
state helper can't make alone: check for app code (a populated `apps/`/`src/`,
`package.json` with real deps, etc.). If genuinely ambiguous, ask **one** question
("Is there existing code to reverse-engineer, or are we starting fresh?") then route.

## Polyrepo

A product may span several repos: a **workspace** repo (`workspace.yml`) holding
THE `/spec` spine and no code, and **member** repos (`spec/PRODUCT.md`) holding the
code. Detect the role before routing — the same spine state means different things:

| Role | Routing change |
| --- | --- |
| `workspace` | Route as normal. The spine is complete here; there is simply no app code to look for, so never read "no `apps/`" as greenfield-with-no-code. |
| `member` | Its spine is **partial by design** — product-level artifacts live in the workspace. `steer_spine_state` already accounts for this and reports `managed`. Never route a member to `/steer:sync` to "repair" missing `vision.md`/`tracker.md`/`spec/features/`; reinstalling them recreates the split-brain spine this topology exists to prevent. |
| none | Single-repo product — the default; everything above is inert. |

**Adopting a polyrepo is not this skill's call.** If the user describes a product
already split across repos, recommend a monorepo first unless the split is
externally mandated (deployment, ownership, or compliance boundaries), then route
to `/steer:init` for the workspace repo. Load `/steer:reference polyrepo` before
advising — do not improvise the topology.

**Prerequisites first.** If the toolchain is missing (`git`, `mise`, Docker — "command
not found", mise/docker errors), the bootstrap paths can't run. `/steer:init` and
`/steer:build` already invoke `/steer:doctor` when prerequisites are absent; surface
that here too rather than failing partway.

## Bootstrap precedence

This skill is the developer/ambiguous entry point for a repo with no `/spec` spine — the
always-on router sends feature or build intent here as the **first move**, not as a closing
offer after a long scoping pass. Honor that:

- **Bootstrap first, announced up front.** Lead with the path you detected and start it; the
  scoping the user expects folds into `init`'s own interview. Don't run a long free-form
  scoping conversation and *then* offer to set up.
- **Durable decisions wait for the spine.** Design decisions surfaced during onboarding are
  captured into `/spec` once it exists (`31-decision-capture`), never a memory- or chat-only
  record.
- **"Prototype" / "quick" / "throwaway" never waives bootstrap.** A prototype is greenfield: it
  still gets the bundled scaffold and a `/spec` spine. Those words change spec *depth* and
  *ceremony* (lighter interview; declaring solo-trunk mode drops per-feature branch/PR — a
  GitHub-adopted repo still keeps the issue per change, see Issue-first), never *whether* scaffold
  and spine exist. The greenfield-vs-prototype ceremony mechanics are canonical in Spec workflow
  (`30-spec-workflow`) — don't restate them; route and let that skill own depth.

(A non-technical owner's idea routes to `/steer:build` instead — bootstrap-inclusive, with its own
prototype-ceremony handling. This section governs the developer path that lands here.)

## Explicit override

Power users can skip detection by naming the path: `setup init`, `setup adopt`, or
`setup sync`. Honor the explicit mode, but if it clearly contradicts the detected
state (e.g. `setup init` on a repo that's already `managed`), say what you detected
and confirm before proceeding.

## Why this exists

`init`, `adopt`, and `sync` remain the skills that do the work — they're just no
longer something a user has to choose between. They stay directly invocable — this
front door just auto-routes to them, so users never have to choose which one fits.

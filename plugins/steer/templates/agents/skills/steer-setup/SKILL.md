---
name: steer-setup
description: One front door for getting a repo onto the standards - detect the /spec spine state and route to `init` (greenfield bootstrap of the spec spine + scaffold, or a template fork's leftover placeholders), `adopt` (reverse-engineer the spec from an existing vibe-coded repo), or `sync` (apply migrations and reconcile drift after a plugin release), flagging missing prerequisites before routing.
argument-hint: '[init | adopt | sync] [--check]'
---

<!-- Generated from the steer plugin's skills/setup/SKILL.md - do not edit by hand.
     Refresh with /steer:sync from Claude Code in a managed repo, or
     `mise run gen:copilot` in the plugin repo. Authored for Claude Code and
     rendered here in the cross-tool Agent Skills format (agentskills.io) that
     Copilot, Cursor, Gemini CLI and Codex read from .agents/skills/. -->

**When to use.** Use when asked to set up, onboard, bootstrap, or adopt a repo, or to sync to the latest plugin - the single entry point whenever you would otherwise guess which path fits. `init` covers a brand-new repo and a template fork with bracketed fill-in placeholders left; `adopt` covers an existing repo whose code has no spec spine; `sync` brings a managed or openspec repo up to date after a plugin release, with `sync --check` the read-only drift report.

<!-- steer:modes init,adopt,sync -->

# Set up a repo on the standards

This is the **one door** for onboarding a repo. The init / adopt / sync split is a
real distinction, but it's one the tool can decide from repo state - so the user
should never have to. Detect the state, announce the path you're taking, then hand
off to the owning skill. Do **not** re-implement their steps here.

## Modes

Each mode **delegates** to the internal skill that owns the work - load it on
entry and follow it; never restate its steps here.

| Mode | What it does | Owning skill |
|---|---|---|
| `default` | Detect the spine state and route to one of the three below | - |
| `init` | Greenfield bootstrap: spine + scaffold + pinned toolchain, or a legacy template fork's placeholders | `/steer-init` |
| `adopt` | Brownfield: reverse-engineer the spine from working code, triage productionization | `/steer-adopt` |
| `sync` | Steady state: ledger migrations, spine/scaffold reconcile, capability + invocation repair, lands a PR. `sync --check` reports and writes nothing | `/steer-sync` |

The three are `user-invocable: false` - a user reaches them **only** through this
door, so a recommendation you hand back names `/steer-setup <mode>`, never the
owning skill.

## Detect, then route

Compute the spine state with the bundled helper rather than inventing detection:

```sh
sh "https://github.com/element22llc/e22-plugins/blob/main/plugins/steer/scripts/scan-spine-state.sh"
```

One read-only call; it prints the repo root, the spine state, the polyrepo role,
and the tracker repository the spine declares. The **polyrepo role** changes what
the spine state *means* - see "Polyrepo" below - so read both lines before routing.

| Detected state | Meaning | Route to |
| --- | --- | --- |
| `unmanaged` + little/no app code | brand-new repo, building from scratch | **`/steer-init`** (greenfield, Path B) |
| `foreign` / `unmanaged` + substantial existing code | a "vibe-coded" app to reverse-engineer | **`/steer-adopt`** |
| unresolved template placeholders present (`@github-handle`, bracketed fill-in markers) | legacy template fork | **`/steer-init`** (Path A) |
| `damaged` | spine stamped but files missing | **`/steer-sync`** (repair) |
| `managed` + template drift flagged | bootstrapped but behind a plugin release | **`/steer-sync`** (update) |
| `managed`, no drift | already current | nothing to do - say so, suggest `/steer-next` |
| `openspec-setup` | OpenSpec spine; steer's tracker declaration missing | **do not init/adopt** - create `openspec/steer/tracker.md` from `templates/spec/tracker.md`, then scaffold only (below) |
| `openspec` | OpenSpec spine, steer's side present | scaffold/drift only - **`/steer-sync`**, which admits this state and reconciles steer's surface (scaffold + `openspec/steer/**`) without touching `spec/`; otherwise nothing to do |

**An OpenSpec repo (`openspec/`) never routes to `/steer-init` or
`/steer-adopt`.** Both write a `spec/` spine from `templates/spec/` and stamp
`spec/.version` - a second, competing spine beside the one the repo actually
uses (rule `33-spec-workflow-openspec`). What such a repo can still need from
this door is the **bundled scaffold** (mise, compose, CI, PR template) and
steer's two artifacts, which live under `openspec/steer/`. Lay those down
directly; they are single files, not a bootstrap.

The `unmanaged`-with-code vs `unmanaged`-greenfield call is the one judgment the
state helper can't make alone: check for app code (a populated `apps/`/`src/`,
`package.json` with real deps, etc.). If genuinely ambiguous, ask **one** question
("Is there existing code to reverse-engineer, or are we starting fresh?") then route.

## Polyrepo

A product may span several repos: a **workspace** repo (`spec/workspace.yml`) holding
THE `/spec` spine and no code, and **member** repos (`spec/PRODUCT.md`) holding the
code. Detect the role before routing - the same spine state means different things:

| Role | Routing change |
| --- | --- |
| `workspace` | Route as normal. The spine is complete here; there is simply no app code to look for, so never read "no `apps/`" as greenfield-with-no-code. |
| `member` | Its spine is **partial by design** - product-level artifacts live in the workspace. `steer_spine_state` already accounts for this and reports `managed`. Never route a member to `/steer-sync` to "repair" missing `vision.md`/`tracker.md`/`spec/features/`; reinstalling them recreates the split-brain spine this topology exists to prevent. |
| none | Single-repo product - the default; everything above is inert. |

**Adopting a polyrepo is not this skill's call.** If the user describes a product
already split across repos, recommend a monorepo first unless the split is
externally mandated (deployment, ownership, or compliance boundaries), then route
to `/steer-init` for the workspace repo - and to `/steer-adopt`, once per member,
when those repos already carry working code (`/steer-adopt` -> "Several repos, one
product?"). Load `/steer-reference polyrepo` before advising - do not improvise
the topology.

**Prerequisites first.** If the toolchain is missing (`git`, `mise`, Docker - "command
not found", mise/docker errors), the bootstrap paths can't run. `/steer-init` and
`/steer-build` already invoke `/steer-doctor` when prerequisites are absent; surface
that here too rather than failing partway.

## Bootstrap precedence

This skill is the developer/ambiguous entry point for a repo with no `/spec` spine - the
always-on router sends feature or build intent here as the **first move**, not as a closing
offer after a long scoping pass. Honor that:

- **Bootstrap first, announced up front.** Lead with the path you detected and start it; the
  scoping the user expects folds into `init`'s own interview. Don't run a long free-form
  scoping conversation and *then* offer to set up.
- **Durable decisions wait for the spine.** Design decisions surfaced during onboarding are
  captured into `/spec` once it exists (`30-spec` § Durable decisions), never a memory- or chat-only
  record.
- **"Prototype" / "quick" / "throwaway" never waives bootstrap.** A prototype is greenfield: it
  still gets the bundled scaffold and a `/spec` spine. Those words change spec *depth* and
  *ceremony* (lighter interview; declaring solo-trunk mode drops per-feature branch/PR - a
  GitHub-adopted repo still keeps the issue where Issue-first requires one), never *whether* scaffold
  and spine exist. The greenfield-vs-prototype ceremony mechanics are canonical in Spec workflow
  (`30-spec`) - don't restate them; route and let that skill own depth.

(A non-technical owner's idea routes to `/steer-build` instead - bootstrap-inclusive, with its own
prototype-ceremony handling. This section governs the developer path that lands here.)

## Explicit override

Power users can skip detection by naming the mode: `setup init`, `setup adopt`, or
`setup sync` (`setup sync --check` for the read-only report). Honor the explicit
mode, but if it clearly contradicts the detected state (e.g. `setup init` on a repo
that's already `managed`), say what you detected and confirm before proceeding.

## Why this exists

`init`, `adopt`, and `sync` remain the skills that do the work - they are just no
longer a choice the user has to get right. Picking the wrong one is expensive:
`init` on a repo with code lays a spine over work it never read, and `adopt` on an
empty repo has nothing to reverse-engineer. The state that decides it is
detectable, so detection belongs here and the three stay behind this door.

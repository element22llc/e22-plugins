# Workflows overview

A **workflow** is a multi-step skill that drives a phase of the product
lifecycle. This section documents the ones a developer or PO invokes directly.
For the full per-command catalog (including internal helpers), see the
[Skills reference](../reference/skills.md).

!!! tip "You don't have to remember these commands"
    The always-on router rule makes Claude the dispatcher: **describe what you
    want in plain language** ("I have an app idea", "fix #123", "what should I do
    next?") and Claude routes to the matching skill itself, announcing the choice
    in one line. The `/steer:*` forms below are the explicit way to invoke a
    workflow — handy when you already know the one you want — not something you
    must memorize. Decision gates (creating issues, approving a spec, pushing a
    PR, deploying) still pause for a human regardless of how the skill was
    reached.

```mermaid
flowchart LR
    subgraph Setup
      setup["/steer:setup<br/>detect & route"]
      init["/steer:init<br/>new repo"]
      adopt["/steer:adopt<br/>existing app"]
      setup --> init & adopt
    end
    subgraph Build loop
      issues["/steer:issues"]
      spec["/steer:spec"]
      work["/steer:work"]
    end
    subgraph Steady state
      sync["/steer:sync"]
      drift["/steer:audit spec"]
      audit["/steer:audit"]
    end
    Setup --> issues --> spec --> work --> drift
    work --> sync
```

## I want to … → run …

A one-screen cheat sheet, keyed by intent rather than phase. You don't have to
memorize it — describe the goal in plain language and Claude routes for you — but
when you'd rather invoke the skill yourself, this is the index. The phase tables
below give the detail.

| I want to … | Run |
| --- | --- |
| Get set up — I'm not sure what state the repo is in | `/steer:setup` (detects & routes) |
| Start a brand-new repo from scratch | `/steer:init` |
| Bring an existing app under steer | [`/steer:adopt`](adopt.md) |
| Absorb a product owner's spec / roadmap document | [`/steer:intake`](intake.md) |
| Capture, triage, or decompose ideas into issues | [`/steer:issues`](issues.md) |
| Shape or approve a feature spec | [`/steer:spec`](spec.md) |
| Start, resume, or finish an issue | [`/steer:work`](work.md) |
| Implement with a review-gated loop (vetted, not first-draft) | [`/steer:work --reviewed`](work.md) |
| Build or prototype an app as a non-developer | [`/steer:build`](build.md) |
| Find out what to do next | `/steer:next` |
| Browse everything steer can do — not sure what to ask for | `/steer:help` |
| Check standards conformance, or that the app matches its spec | `/steer:audit code` · `/steer:audit spec` |
| Apply a new plugin release (migrations, scaffold, spine) | `/steer:sync` |
| Generate a release-milestone timeline | `/steer:roadmap` |
| Lock branch protection or flip the delivery mode | `/steer:protect` |
| A tool is missing, or set up the local toolchain | `/steer:doctor` |
| steer itself is misbehaving — file a plugin bug upstream | `/steer:report` |
| Answer accumulated open questions | `/steer:questions` |
| Load the rules manually (Desktop *Chat* tab / web chat, where the hook can't fire) | `/steer:standards` |

## Setup (one-time)

| Skill | Use when |
| --- | --- |
| `/steer:setup` | **The front door** — detects the repo state and routes to the right path below. Start here. |
| `/steer:init` | (via setup) A new repo with no `/spec` spine — installs the bundled scaffold + spine. |
| [`/steer:adopt`](adopt.md) | (via setup) An existing app with working code but no spine. |

## Build loop

| Skill | Use when |
| --- | --- |
| [`/steer:issues`](issues.md) | Drive an idea from capture → draft spec → decomposed work. |
| [`/steer:spec`](spec.md) | Think a feature through and shape/approve acceptance criteria. |
| [`/steer:work`](work.md) | Start, resume, or finish a specific issue. Add `--reviewed` to run it through a review-gated loop (plan → plan-gate review → implement → `/code-review` → bounded fix) — vetted, not first-draft. |
| [`/steer:build`](build.md) | A non-developer wants to build or prototype an idea. |

## Steady state

| Skill | Use when |
| --- | --- |
| `/steer:sync` | (via `/steer:setup`) After a plugin release — apply migrations, reconcile spine + scaffold. |
| `/steer:audit` | Periodic read-only pass: `code` for whole-repo standards-conformance health, `spec` to audit the built app against its tracker specs, `all` for both. |
| `/steer:next` | "What should I do next?" across the whole workspace (read-only). |
| `/steer:roadmap` | Generate a release-milestone timeline from the `/spec` spine (viewable as a GitHub Projects v2 roadmap). |

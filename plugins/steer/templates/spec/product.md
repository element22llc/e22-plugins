---
# Polyrepo member pointer. Read by every skill that needs product-level spec.
# Its PRESENCE is what marks this repo a member (lib/scope.sh → has-product-pointer),
# so do not add this file to a single-repo product.
# /steer:init and /steer:adopt resolve the placeholders — never ship fabricated values.
workspace:
  repository:               # "[owner/repository]" — the repo hosting the product /spec spine
  branch: main              # the branch to read the spine from
  path:                     # OPTIONAL relative path to a local workspace checkout,
                            # e.g. ".." when this repo is cloned inside the workspace.
                            # Omit when there is no local checkout; reads fall back to GitHub.
member:
  name:                     # this repo's member id in the workspace manifest
  profile:                  # app | service | infra | library | cli
---

# Product spine — not in this repo

This repo is **one member** of a product whose `/spec` spine lives in the
workspace repo named above. It is not the whole product, and nothing here
describes the whole product.

## What lives where

| Artifact | Home |
| --- | --- |
| `vision.md`, `users.md`, `glossary.md`, `HISTORY.md`, `spec/app/` | **workspace** |
| `spec/features/**` — every feature's `intent.md` + `contract.md` | **workspace** |
| `spec/tracker.md` | **workspace** |
| `spec/sources/`, `spec/reference/` — PO source docs + research | **workspace** |
| `spec/decisions/` — ADRs about *this repo's* internals | **here** |
| `spec/design/`, `DESIGN.md` — *this repo's* design sources | **here** |
| `ARCHITECTURE.md` — how *this repo* is built | **here** |
| application code, tests, `mise.toml`, CI | **here** |

A feature that spans repos has exactly **one** `intent.md`, in the workspace. If
you cannot find a feature's intent locally, that is expected — read it from the
workspace rather than writing a second copy here.

## Resolving the spine

1. `workspace.path` set and `spec/workspace.yml` present at that path → read the
   spine from there. Require the **manifest**, not just a directory: a relative
   `path` is relative to the repo's **primary checkout**, so from a linked
   worktree (`.claude/worktrees/<name>`) the recommended `..` lands on a real but
   empty directory. Resolve against the primary checkout, and treat a resolved
   path with no manifest as no local checkout.
2. Otherwise → read it from `workspace.repository` at `workspace.branch` over the
   GitHub tracker gateway (`/steer:tracker-sync`).
3. Neither available → say the spine is unreachable and stop. Do **not** proceed
   on a guess, and do **not** create local product-level spec files to fill the
   gap; that is exactly the split-brain this file exists to prevent.

## Working here

- `/steer:work` loads the linked feature's intent from the workspace before it
  touches code.
- The tracker is the workspace's, so a PR here cannot auto-close its issue with
  `Closes #N`. Use `Refs owner/repo#N` and close explicitly after merge.
- A contract change here can invalidate a sibling member's assumption. Flag the
  drift class and name the sibling — no gate catches it across the repo edge.

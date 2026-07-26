# [Product Name] — workspace

This repo is the **spine host** for a product that spans several repos. It holds
the product `/spec`, including the `spec/workspace.yml` member manifest. It holds
no application code.

Prefer a monorepo whenever the split is not externally mandated. This topology
buys a single product spine across repos; it does **not** buy atomic cross-repo
commits, and it never will — a contract change across two members is still two
PRs that can merge out of order.

## Layout

```text
spec/                THE product spine — vision, users, glossary, HISTORY,
                     app docs, and every feature's intent.md + contract.md
spec/workspace.yml   the member manifest (repos, branches, profiles)
spec/tracker.md      the tracker for the whole product
```

Member repos carry `spec/PRODUCT.md` pointing back here, their own
`spec/decisions/` and `ARCHITECTURE.md`, and their code. They never grow a second
copy of a product-level artifact.

## Working across the members

- `/steer:next`, `/steer:status`, `/steer:audit` run from here and cover the
  members they can reach — each report names which those are. A member with
  neither a local checkout nor gateway access is reported **uncovered**, never
  silently dropped.
- `/steer:issues` decomposition works across repos: GitHub sub-issues may span
  repositories within an org (100 sub-issues per parent, 8 levels of nesting).
- A PR in a member repo **cannot** auto-close an issue here — GitHub honours
  closing keywords only within one repo. Use `Refs owner/repo#N` and close the
  issue explicitly after merge.

## What is not here yet

Running the whole product locally — one `mise run dev` booting every member via
Compose `include:` and mise's monorepo task addressing — is deliberately not part
of this scaffold. Clone the members wherever you like and run them as they stand.

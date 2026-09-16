<!-- steer:inject-when=has-openspec -->
## Spec workflow — OpenSpec backend

This repo carries an `openspec/` spine, so **OpenSpec owns the spec artifacts**.
This rule overrides the *paths and commands* in Spec workflow. Every other rule
— stack, testing, coverage, Definition of Done, issue-first, drift gates,
secrets, compliance, change size — applies unchanged.

**`openspec/` IS this repo's spine**, so the router's bootstrap precedence and
Durable decisions' "no `/spec` spine yet?" check are already satisfied: do not
announce `/steer:setup`, `/steer:init` or `/steer:adopt` as the first move here,
and do not read the absent `spec/features/**` as an unbootstrapped repo. Those
bootstrap routes would lay a second, competing spine.

- **New or changed behavior** → an OpenSpec change, not `spec/features/<id>/`:
  **`/opsx:propose`** writes `openspec/changes/<id>/` with `proposal.md`,
  `specs/`, `design.md`, `tasks.md`. Shape it with **`/opsx:explore`** first
  when the approach is still open.
- **Intent** is `proposal.md`; the **behavior contract** is that change's
  `specs/` (requirement + scenario), promoted into `openspec/specs/` on archive.
  Never create `spec/features/<id>/intent.md` here — prefer the `/opsx:*`
  commands over `/steer:spec` for authoring on this repo.
- **Implement** from `tasks.md` (**`/opsx:apply`**), then **`/opsx:archive`** at
  merge — that archive is this repo's action history.
- **Behavior changed** → update the owning requirement in the same PR, exactly
  as the contract rule demands. Where the expanded profile is enabled,
  **`/opsx:verify`** (implementation vs. the change's artifacts) is a pre-merge
  check here, alongside the drift gates.
- **Open questions** go in the change's `proposal.md`, not a side channel.

**Two artifacts are steer's, because OpenSpec has no equivalent — and on this
repo they live under `openspec/steer/`, NOT in `spec/`:**

- **ADRs** → `openspec/steer/decisions/000N-<slug>.md` (**`/steer:adr`**). A
  change's `design.md` is per-change and is archived with it; a hard-to-reverse
  choice has to outlive the change that made it.
- **Tracker declaration** → `openspec/steer/tracker.md`. It declares the issue
  tracker and is what issue-first enforcement reads. OpenSpec models no tracker.
- **App guide** → `openspec/steer/app/`. Living documentation (how to use and
  operate the product), not a spec artifact — Living docs applies unchanged,
  only the path moves.

**This overrides every skill and rule that names a `spec/` path for these
three.** A skill body still says `spec/decisions/`, `spec/tracker.md` or
`spec/app/` — read it as `openspec/steer/…` here. The `steer/` segment keeps steer's durable artifacts
out of the namespace the `openspec` CLI regenerates. If you find them at the old
`spec/` paths, the repo predates the move: run **`/steer:sync`**.

Toolchain and CI scaffolding are still steer's — the bundled scaffold (mise,
compose, CI, PR template) applies here unchanged. Reach it via **`/steer:setup`**
*only when that scaffold is missing*, and do not let it route into
`/steer:init` / `/steer:adopt`: those write a `spec/` spine from the templates
and stamp `spec/.version`, which is the competing spine this rule exists to
prevent. Missing `openspec/steer/tracker.md`? Instantiate
`templates/spec/tracker.md` there directly — it is one file, not a bootstrap.

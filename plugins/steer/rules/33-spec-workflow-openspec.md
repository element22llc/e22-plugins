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

**Two artifacts stay steer's, because OpenSpec has no equivalent:**

- **ADRs** remain at `spec/decisions/000N-<slug>.md` (**`/steer:adr`**). A
  change's `design.md` is per-change and is archived with it; a hard-to-reverse
  choice has to outlive the change that made it.
- **`spec/tracker.md`** remains — it declares the issue tracker and is what
  issue-first enforcement reads. OpenSpec models no tracker.

Toolchain and CI scaffolding are still steer's: run **`/steer:setup`** for the
bundled scaffold. It will not fight the `openspec/` spine.

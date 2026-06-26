# Claude Operating Manual — [Product Name]

The org-wide engineering standards (stack defaults, monorepo layout,
spec workflow, testing rules, Definition of Done, high-risk areas, secrets
handling, change-size model, baseline patterns/anti-patterns, design sources)
are **injected automatically every session** by the **`steer`** plugin
from the `e22-plugins` marketplace — see `.claude/settings.json`. They are maintained
centrally in [`element22llc/e22-plugins`](https://github.com/element22llc/e22-plugins)
and update via `/plugin update`, so they are **not** duplicated here. This file
holds only product-specific context.

> **New repo?** Run **`/steer:init`** once to fill the placeholders, pin the
> toolchain, and finish the bootstrap. Remove this line when setup is done.
> Non-technical PO? Type **`/steer:build`** to go from idea to a working local
> app — it runs the first-run setup for you.
>
> On-demand helpers from the plugin: `/steer:spec` (new feature
> spec), `/steer:adr <slug>` (architecture decision), and
> `/steer:reference [conventions|traceability|design-sources|context-hygiene]`
> (full reference prose). If the plugin isn't installed, your teammate will be prompted to install
> it when they trust this folder.

## Product

[Replace with one paragraph: what this product does, who uses it, and what
success looks like. Pull from `/spec/vision.md` once it exists.]

## Delivery mode

<!-- steer:delivery-mode=pr-flow -->
<!-- ^ machine-readable marker (steer hooks read this line; values: pr-flow | solo-trunk).
     /steer:init sets it; /steer:protect flips it to pr-flow at graduation. Keep it in sync
     with the prose below. -->

**`PR flow`** — work on `feat/*` branches, one PR per change, merged after a dev
reviews it (Commit autonomy). This is the default.

Solo greenfield can instead run in **`solo trunk (pre-MVP)`** mode (offered by
`/steer:init` when one person is both PO and dev with no MVP yet): commit directly
to `main`, no per-feature branch or PR, until graduation. Issue-first still holds
(every change keeps a GitHub issue, closed from the trunk commit); only the branch
and PR ceremony relaxes. CI still runs on every push, and the spine, tests, and
Definition of Done are unchanged. **Graduate** to `PR flow` — run
**`/steer:protect`**, which raises the server-side PR wall — the moment the MVP
works, you first deploy, or a second contributor joins, whichever comes first; then
set this marker and the prose to `PR flow`.

## Profile

<!-- steer:profile=app -->

**`app`** — this repo is an internal app monorepo. The profile decides which
stack-specific scaffold the bootstrap lays down on top of the universal core
(mise pinning, the `/spec` spine, CI hygiene); `/steer:init` sets the marker
above to the detected profile (`app` / `infra` / `service` / `library` / `cli`).
Keep the marker and this line in sync — `/steer:sync` reads the marker. An
**infra** repo (Terraform/OpenTofu/Ansible/Pulumi) gets a tofu/terragrunt/ansible
root `mise.toml` and infra CI instead of the Node project files
(`package.json` / `biome.json`); `node` + `compose.yaml` stay from the core scaffold.

## Stack overrides

The default stack (injected by the plugin) applies unless overridden. Record
any deviation as an ADR under `/spec/decisions/` (run `/steer:adr`) and note it here.
The current as-built stack and how the pieces fit together live in
[`ARCHITECTURE.md`](./ARCHITECTURE.md) — this section holds only the *deviations*.

- [none yet — defaults apply]

## Patterns we follow

The baseline (Drizzle/parameterized SQL, schema-validated boundaries,
server-first, static typing, …) is injected by the plugin. Add only
product-specific patterns the team learns here.

## Things to avoid

The baseline anti-patterns are injected by the plugin. Add only
product-specific ones discovered here.

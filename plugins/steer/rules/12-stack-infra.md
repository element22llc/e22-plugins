<!-- steer:inject-when=has-iac -->
## Stack — infrastructure / IaC

This repo does infrastructure-as-code. The universal core still applies (mise
pinning, the `/spec` spine, CI hygiene); the stack below replaces the app
defaults. Deviations are ADRs, same as any stack choice.

- **IaC engine:** OpenTofu (or Terraform) for cloud resources; Ansible for host
  configuration/provisioning; Pulumi only with an ADR. **Orchestration/DRY:**
  Terragrunt for OpenTofu/Terraform.
- **Toolchain:** pinned in the **root** `mise.toml` for a root-level infra repo
  (`opentofu`/`terragrunt`/`ansible`/`node`/`uv`), or in `infra/mise.toml` for a
  nested `/infra` dir of an app monorepo. Commit `mise.lock`. The `node` runtime
  is still pinned (agent tooling needs it), but there is **no Node project layer**
  — no `package.json`/`biome.json`. `compose.yaml` ships from the core scaffold;
  keep it only if the repo runs local backing services.
- **Layout:** `live/` (deployable units, per-env `terragrunt.hcl`) + `modules/`
  for OpenTofu/Terraform; `roles/` + `playbooks/` (or `site.yml`) + `inventory/`
  for Ansible. Detail in `/infra/README.md` (monorepo) or the repo README.
- **Validate locally before CI:** `tofu fmt -check` + `tofu validate` /
  `terragrunt run-all validate`; `ansible-lint` + `yamllint` for Ansible. These
  run in CI too.
- **State & secrets:** remote state with locking (S3 `use_lockfile`); secrets in
  the cloud secret store (SSM Parameter Store `SecureString` / Secrets Manager),
  Ansible Vault for Ansible — never committed (see Secrets handling). Commit
  provider lockfiles (`.terraform.lock.hcl`).
- **Pin image/provider/role majors** the same way app stacks pin them; a
  deliberately older pin needs an ADR plus `# pin-ok: <reason>`.

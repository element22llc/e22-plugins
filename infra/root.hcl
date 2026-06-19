# Root Terragrunt config for Element 22 infrastructure (AWS account 053932564353).
#
# Units under live/: dns (Route 53 CNAME, aws provider) and access (Cloudflare
# Access, cloudflare provider). Providers are generated PER UNIT — not here —
# because Terragrunt rejects two generate blocks with the same name across the
# include hierarchy, and the two units need different providers. Root owns only
# the shared remote state + locals.
#
# Remote state lives in S3 with native S3 state locking (use_lockfile, requires
# OpenTofu >= 1.10) — no DynamoDB lock table.

locals {
  aws_account_id = "053932564353"
  aws_region     = "us-east-1"
  state_bucket   = "element22-tofu-state" # confirm/create before first apply (see README)
  aws_profile    = "e22-main-admin"
}

# Inherited by every unit via `include "root"`. Each unit gets its own state key
# derived from its path under infra/.
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket       = local.state_bucket
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.aws_region
    encrypt      = true
    use_lockfile = true
    profile      = local.aws_profile
  }
}

# Root Terragrunt config for Element 22 infrastructure (AWS account 053932564353).
#
# DNS-only today: the single managed resource is the Route 53 CNAME that points
# ai.element-22.com at the Cloudflare Pages project serving the docs site. The
# Cloudflare Pages project and the Cloudflare Access app that gates it are set up
# in the Cloudflare dashboard — see README.md.
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

# Pin the provider to the intended account so a mis-scoped credential fails fast
# instead of touching the wrong AWS account.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region              = "${local.aws_region}"
      allowed_account_ids = ["${local.aws_account_id}"]
      profile = "${local.aws_profile}"
      default_tags {
        tags = {
          ManagedBy = "opentofu"
          IacRepo   = "e22-plugins"
        }
      }
    }
  EOF
}

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# AWS provider for this unit. Generated here (not in root.hcl) so the access unit
# can use the Cloudflare provider without a same-name generate-block collision.
# Pins the account so a mis-scoped credential fails fast.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region              = "${include.root.locals.aws_region}"
      allowed_account_ids = ["${include.root.locals.aws_account_id}"]
      profile             = "${include.root.locals.aws_profile}"
      default_tags {
        tags = {
          ManagedBy = "opentofu"
          IacRepo   = "e22-plugins"
        }
      }
    }
  EOF
}

inputs = {
  # CNAME target from the Cloudflare Pages custom-domain setup:
  # Pages → the e22-ai-docs project → Custom domains → add ai.element-22.com →
  # copy the <project>.pages.dev target Cloudflare shows, and set it here.
  pages_hostname = "e22-ai-docs.pages.dev"
  ttl            = 300
}

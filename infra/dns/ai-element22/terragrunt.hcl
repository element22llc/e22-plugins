include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}

inputs = {
  # CNAME target from the Cloudflare Pages custom-domain setup:
  # Pages → the e22-docs project → Custom domains → add ai.element22.com →
  # copy the <project>.pages.dev target Cloudflare shows, and set it here.
  pages_hostname = "e22-docs.pages.dev"
  ttl            = 300
}

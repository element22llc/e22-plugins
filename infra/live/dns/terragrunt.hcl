include "root" {
  path = find_in_parent_folders("root.hcl")
}

inputs = {
  # CNAME target from the Cloudflare Pages custom-domain setup:
  # Pages → the e22-ai-docs project → Custom domains → add ai.element-22.com →
  # copy the <project>.pages.dev target Cloudflare shows, and set it here.
  pages_hostname = "e22-ai-docs.pages.dev"
  ttl            = 300
}

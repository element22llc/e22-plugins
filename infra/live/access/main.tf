terraform {
  required_version = ">= 1.10"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID (from CLOUDFLARE_ACCOUNT_ID)."
  type        = string
}

variable "github_client_id" {
  description = "GitHub OAuth app client ID for the Access identity provider."
  type        = string
}

variable "github_client_secret" {
  description = "GitHub OAuth app client secret. Sensitive — it is stored in tofu state."
  type        = string
  sensitive   = true
}

variable "access_domain" {
  description = "Hostname Access protects (the Pages custom domain)."
  type        = string
}

variable "email_domain" {
  description = "Email domain allowed in via the Include rule."
  type        = string
}

variable "session_duration" {
  description = "Access session token lifetime."
  type        = string
  default     = "24h"
}

# GitHub login for the docs site. The GitHub OAuth app's Authorization callback
# URL must be https://<team>.cloudflareaccess.com/cdn-cgi/access/callback.
resource "cloudflare_zero_trust_access_identity_provider" "github" {
  account_id = var.cloudflare_account_id
  name       = "GitHub"
  type       = "github"
  config = {
    client_id     = var.github_client_id
    client_secret = var.github_client_secret
  }
}

# Allow anyone with an @<email_domain> address (matched on the email GitHub returns).
resource "cloudflare_zero_trust_access_policy" "staff" {
  account_id = var.cloudflare_account_id
  name       = "Element 22 staff"
  decision   = "allow"
  include = [{
    email_domain = {
      domain = var.email_domain
    }
  }]
}

# Self-hosted Access app guarding the docs site, pinned to GitHub login.
# Note: the v5 provider has some known cosmetic drift on this resource
# (allowed_idps / session_duration re-appearing in plans); harmless if it does.
resource "cloudflare_zero_trust_access_application" "docs" {
  account_id                = var.cloudflare_account_id
  name                      = "E22 docs"
  domain                    = var.access_domain
  type                      = "self_hosted"
  session_duration          = var.session_duration
  allowed_idps              = [cloudflare_zero_trust_access_identity_provider.github.id]
  auto_redirect_to_identity = true # single IdP → skip the chooser, go straight to GitHub

  policies = [{
    id         = cloudflare_zero_trust_access_policy.staff.id
    precedence = 1
  }]
}

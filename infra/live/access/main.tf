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

# Login uses Cloudflare's built-in One-time PIN (OTP): no identity provider /
# OAuth app to register. Cloudflare emails a code to the address the user types;
# the policy below gates on that verified email. With no SSO IdP configured, the
# Access app falls back to OTP automatically, so there is no IdP resource here.

# Allow anyone with an @<email_domain> address (the address OTP verifies).
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

# Self-hosted Access app guarding the docs site. No allowed_idps: leaving it
# unset permits all login methods, which with no SSO IdP configured means the
# built-in One-time PIN flow. Note: the v5 provider has some known cosmetic drift
# on this resource (session_duration re-appearing in plans); harmless if it does.
resource "cloudflare_zero_trust_access_application" "docs" {
  account_id       = var.cloudflare_account_id
  name             = "E22 docs"
  domain           = var.access_domain
  type             = "self_hosted"
  session_duration = var.session_duration

  policies = [{
    id         = cloudflare_zero_trust_access_policy.staff.id
    precedence = 1
  }]
}

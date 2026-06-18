terraform {
  # >= 1.10 for native S3 state locking (use_lockfile), set in the root config.
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

variable "pages_hostname" {
  description = "Cloudflare Pages custom-domain CNAME target (e.g. e22-ai-docs.pages.dev)."
  type        = string
}

variable "ttl" {
  description = "DNS record TTL in seconds."
  type        = number
  default     = 300
}

# The element-22.com hosted zone is managed elsewhere; we only add a record to it.
data "aws_route53_zone" "root" {
  name = "element-22.com"
}

# ai.element-22.com → Cloudflare Pages. Traffic is served through Cloudflare's
# edge, which is what lets Cloudflare Access gate the site even though the zone
# itself stays in Route 53.
resource "aws_route53_record" "ai" {
  zone_id = data.aws_route53_zone.root.zone_id
  name    = "ai.element-22.com"
  type    = "CNAME"
  ttl     = var.ttl
  records = [var.pages_hostname]
}

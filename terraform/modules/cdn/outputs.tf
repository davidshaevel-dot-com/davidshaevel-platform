# ------------------------------------------------------------------------------
# CDN Module Outputs
# CloudFront and ACM certificate information
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# CloudFront Distribution Outputs
# ------------------------------------------------------------------------------

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution (use for cache invalidation)"
  value       = aws_cloudfront_distribution.main.id
}

output "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.arn
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution (e.g., d123abc.cloudfront.net)"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_hosted_zone_id" {
  description = "Route53 hosted zone ID for the CloudFront distribution (for potential future use)"
  value       = aws_cloudfront_distribution.main.hosted_zone_id
}

output "cloudfront_status" {
  description = "Current status of the CloudFront distribution"
  value       = aws_cloudfront_distribution.main.status
}

# ------------------------------------------------------------------------------
# ACM Certificate Outputs
# ------------------------------------------------------------------------------

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate used by CloudFront"
  value       = aws_acm_certificate.main.arn
}

output "acm_certificate_domain_name" {
  description = "Domain name of the ACM certificate"
  value       = aws_acm_certificate.main.domain_name
}

output "acm_certificate_status" {
  description = "Status of the ACM certificate (PENDING_VALIDATION, ISSUED, etc.)"
  value       = aws_acm_certificate.main.status
}

# ------------------------------------------------------------------------------
# ACM Certificate Validation Records for Cloudflare
# IMPORTANT: Add these records to Cloudflare DNS for certificate validation
# ------------------------------------------------------------------------------

output "acm_certificate_validation_records" {
  description = <<-EOT
    DNS validation records for ACM certificate.
    Add these CNAME records to Cloudflare DNS (gray cloud) to validate the certificate.
    
    Format: [
      {
        name  = "_xxx.davidshaevel.com"
        type  = "CNAME"
        value = "_yyy.acm-validations.aws."
      }
    ]
  EOT
  value = [
    for dvo in aws_acm_certificate.main.domain_validation_options : {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  ]
}

# ------------------------------------------------------------------------------
# CloudFront CNAME Records for Cloudflare
# IMPORTANT: Add these records to Cloudflare DNS after distribution is deployed
# ------------------------------------------------------------------------------

output "cloudflare_cname_records" {
  description = <<-EOT
    CNAME records to add to Cloudflare DNS (gray cloud) to point custom domains to CloudFront.
    
    Add these records in Cloudflare:
    1. Type: CNAME, Name: @ (apex), Target: <cloudfront_domain_name>, Proxy: DNS only (gray cloud)
    2. Type: CNAME, Name: www, Target: <cloudfront_domain_name>, Proxy: DNS only (gray cloud)
    
    IMPORTANT: Use DNS only mode (gray cloud) to avoid double CDN (Cloudflare + CloudFront).
  EOT
  value = {
    cloudfront_domain = aws_cloudfront_distribution.main.domain_name
    records = [
      {
        type  = "CNAME"
        name  = "@" # apex domain (e.g., davidshaevel.com)
        value = aws_cloudfront_distribution.main.domain_name
        note  = "Use DNS only mode (gray cloud) in Cloudflare"
      },
      {
        type  = "CNAME"
        name  = "www"
        value = aws_cloudfront_distribution.main.domain_name
        note  = "Use DNS only mode (gray cloud) in Cloudflare"
      }
    ]
  }
}

# ------------------------------------------------------------------------------
# Custom Domain URLs
# ------------------------------------------------------------------------------

output "custom_domain_urls" {
  description = "URLs for custom domains (after DNS is configured in Cloudflare)"
  value = {
    primary   = "https://${var.domain_name}"
    alternate = [for domain in var.alternate_domain_names : "https://${domain}"]
  }
}

# ------------------------------------------------------------------------------
# Cache Invalidation Command
# ------------------------------------------------------------------------------

output "cache_invalidation_command" {
  description = "AWS CLI command to invalidate CloudFront cache"
  value       = "aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.main.id} --paths '/*'"
}

# ------------------------------------------------------------------------------
# Cache Policy Outputs
# ------------------------------------------------------------------------------

output "nextjs_cache_policy_id" {
  description = "ID of the custom Next.js cache policy (includes RSC headers in cache key)"
  value       = aws_cloudfront_cache_policy.nextjs.id
}


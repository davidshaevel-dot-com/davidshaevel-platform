# ------------------------------------------------------------------------------
# CDN Module Variables
# Configuration for CloudFront distribution and ACM certificate
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Required Variables
# ------------------------------------------------------------------------------

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "domain_name" {
  description = "Primary domain name for the CDN (e.g., davidshaevel.com)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,61}[a-z0-9]\\.[a-z]{2,}$", var.domain_name))
    error_message = "Domain name must be a valid domain format."
  }
}

variable "alb_dns_name" {
  description = "DNS name of the Application Load Balancer (CloudFront origin)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+\\.[a-z]{2}(-[a-z]+)+-[0-9]{1}\\.elb\\.amazonaws\\.com$", var.alb_dns_name))
    error_message = "ALB DNS name must be a valid ELB DNS format (e.g., my-alb.us-east-1.elb.amazonaws.com)."
  }
}

# ------------------------------------------------------------------------------
# Optional Variables
# ------------------------------------------------------------------------------

variable "alternate_domain_names" {
  description = "List of alternate domain names (CNAMEs) for the distribution (e.g., www.davidshaevel.com)"
  type        = list(string)
  default     = []
}

variable "enable_ipv6" {
  description = "Enable IPv6 support for CloudFront distribution"
  type        = bool
  default     = true
}

variable "default_root_object" {
  description = "Object that CloudFront returns when requesting the root URL (empty for Next.js dynamic routing)"
  type        = string
  default     = ""
}

variable "price_class" {
  description = "CloudFront distribution price class (PriceClass_All, PriceClass_200, PriceClass_100)"
  type        = string
  default     = "PriceClass_100" # US, Canada, Europe

  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.price_class)
    error_message = "Price class must be PriceClass_All, PriceClass_200, or PriceClass_100."
  }
}

variable "web_acl_id" {
  description = "AWS WAF Web ACL ID to associate with CloudFront (optional)"
  type        = string
  default     = ""
}

# ------------------------------------------------------------------------------
# Cache Policy Variables
# ------------------------------------------------------------------------------

variable "cache_policy_id_default" {
  description = "CloudFront cache policy ID for default behavior (frontend). Defaults to AWS managed CachingOptimized."
  type        = string
  default     = ""
}

variable "cache_policy_id_api" {
  description = "CloudFront cache policy ID for API behavior. Defaults to AWS managed CachingDisabled."
  type        = string
  default     = ""
}

variable "origin_request_policy_id_default" {
  description = "CloudFront origin request policy ID for default behavior. Leave empty for no origin request policy (recommended for static content)."
  type        = string
  default     = ""
}

variable "origin_request_policy_id_api" {
  description = "CloudFront origin request policy ID for API behavior. Defaults to AWS managed AllViewer."
  type        = string
  default     = ""
}

variable "origin_protocol_policy" {
  description = "Protocol policy for CloudFront to origin. Use 'https-only' when ALB has HTTPS listener, 'http-only' when ALB only has HTTP."
  type        = string
  default     = "https-only"

  validation {
    condition     = contains(["http-only", "https-only", "match-viewer"], var.origin_protocol_policy)
    error_message = "Origin protocol policy must be http-only, https-only, or match-viewer."
  }
}

# ------------------------------------------------------------------------------
# Logging Variables
# ------------------------------------------------------------------------------

variable "logging_bucket" {
  description = "S3 bucket for CloudFront access logs (e.g., bucket-name.s3.amazonaws.com). Leave empty to disable logging."
  type        = string
  default     = ""
}

variable "logging_prefix" {
  description = "Prefix for CloudFront access log files in S3 bucket"
  type        = string
  default     = "cloudfront/"
}


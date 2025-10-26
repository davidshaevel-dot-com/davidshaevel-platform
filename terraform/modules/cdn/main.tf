# ------------------------------------------------------------------------------
# CDN Module - CloudFront Distribution with ACM Certificate
# Provides content delivery network with custom domain support
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# ACM Certificate for CloudFront
# MUST be in us-east-1 region for CloudFront, regardless of other resources
# ------------------------------------------------------------------------------

resource "aws_acm_certificate" "main" {
  # CloudFront requires certificates in us-east-1
  provider = aws.us_east_1

  domain_name               = var.domain_name
  subject_alternative_names = var.alternate_domain_names
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-cloudfront-cert"
  }
}

# ------------------------------------------------------------------------------
# CloudFront Distribution
# Global content delivery network with ALB origin
# ------------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = var.enable_ipv6
  comment             = "${var.environment} ${var.project_name} CDN"
  default_root_object = var.default_root_object
  price_class         = var.price_class
  aliases             = concat([var.domain_name], var.alternate_domain_names)
  web_acl_id          = var.web_acl_id

  # ALB Origin
  origin {
    domain_name = var.alb_dns_name
    origin_id   = "alb-origin"

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "http-only" # ALB doesn't have HTTPS yet (no certificate)
      origin_ssl_protocols     = ["TLSv1.2"]
      origin_read_timeout      = 60
      origin_keepalive_timeout = 5
    }

    custom_header {
      name  = "X-Custom-Header"
      value = var.project_name
    }
  }

  # Default cache behavior - Frontend
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "alb-origin"
    compress         = true

    # Use AWS managed caching policy for optimized static content
    cache_policy_id = var.cache_policy_id_default != "" ? var.cache_policy_id_default : data.aws_cloudfront_cache_policy.caching_optimized.id

    # Origin request policy: null by default for better cache hit ratio on static content
    # Override with var.origin_request_policy_id_default if headers/cookies needed
    origin_request_policy_id = var.origin_request_policy_id_default != "" ? var.origin_request_policy_id_default : null

    viewer_protocol_policy = "redirect-to-https"
  }

  # Ordered cache behavior - Backend API (no caching)
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "alb-origin"
    compress         = true

    # Use AWS managed policy for no caching (API endpoints)
    cache_policy_id = var.cache_policy_id_api != "" ? var.cache_policy_id_api : data.aws_cloudfront_cache_policy.caching_disabled.id

    # Forward all viewer headers/cookies/query strings for API
    origin_request_policy_id = var.origin_request_policy_id_api != "" ? var.origin_request_policy_id_api : data.aws_cloudfront_origin_request_policy.all_viewer.id

    viewer_protocol_policy = "redirect-to-https"
  }

  # SSL/TLS Configuration
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.main.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  # Restrictions (none for this project)
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Access Logging (optional, disabled by default)
  dynamic "logging_config" {
    for_each = var.logging_bucket != "" ? [1] : []
    content {
      bucket          = var.logging_bucket
      prefix          = var.logging_prefix
      include_cookies = false
    }
  }

  # Custom error responses
  custom_error_response {
    error_code            = 502
    response_code         = 502
    response_page_path    = "/error.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 503
    response_code         = 503
    response_page_path    = "/error.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 504
    response_code         = 504
    response_page_path    = "/error.html"
    error_caching_min_ttl = 10
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-cloudfront"
  }
}

# ------------------------------------------------------------------------------
# AWS Managed Cache Policies (Data Sources)
# ------------------------------------------------------------------------------

# Caching Optimized - For static content (frontend)
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

# Caching Disabled - For dynamic content (API)
data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

# ------------------------------------------------------------------------------
# AWS Managed Origin Request Policies (Data Sources)
# ------------------------------------------------------------------------------

# All Viewer - Forward all viewer headers, cookies, and query strings
data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewer"
}


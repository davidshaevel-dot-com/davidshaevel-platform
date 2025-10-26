# Development Environment Outputs
# These outputs provide information about the deployed dev infrastructure

# -----------------------------------------------------------------------------
# Environment Information
# -----------------------------------------------------------------------------

output "environment" {
  description = "The environment name"
  value       = var.environment
}

output "aws_region" {
  description = "The AWS region where resources are deployed"
  value       = var.aws_region
}

output "project_name" {
  description = "The name of the project"
  value       = var.project_name
}

output "resource_prefix" {
  description = "Standard prefix for resource names"
  value       = "${var.environment}-${var.project_name}"
}

# -----------------------------------------------------------------------------
# Module Outputs
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Networking Outputs
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.networking.vpc_id
}

# -----------------------------------------------------------------------------
# Database Outputs
# -----------------------------------------------------------------------------

output "database_endpoint" {
  description = "RDS instance endpoint"
  value       = module.database.db_instance_endpoint
}

output "database_port" {
  description = "Database port"
  value       = module.database.db_instance_port
}

output "database_name" {
  description = "Database name"
  value       = module.database.db_name
}

output "database_connection_string" {
  description = "Database connection string (without credentials)"
  value       = module.database.connection_string
}

output "database_secret_arn" {
  description = "ARN of the database credentials secret in Secrets Manager"
  value       = module.database.secret_arn
}

# -----------------------------------------------------------------------------
# Compute Outputs (ECS + ALB)
# -----------------------------------------------------------------------------

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.compute.ecs_cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.compute.ecs_cluster_arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer (use this to access the application)"
  value       = module.compute.alb_dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.compute.alb_arn
}

output "frontend_service_name" {
  description = "Name of the frontend ECS service"
  value       = module.compute.frontend_service_name
}

output "backend_service_name" {
  description = "Name of the backend ECS service"
  value       = module.compute.backend_service_name
}

output "application_url" {
  description = "URL to access the application"
  value       = module.compute.application_url
}

output "frontend_url" {
  description = "URL to access the frontend"
  value       = module.compute.frontend_url
}

output "backend_url" {
  description = "URL to access the backend API"
  value       = module.compute.backend_url
}

# -----------------------------------------------------------------------------
# CDN Outputs (CloudFront)
# -----------------------------------------------------------------------------

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution (use for cache invalidation)"
  value       = module.cdn.cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name (e.g., d123abc.cloudfront.net)"
  value       = module.cdn.cloudfront_domain_name
}

output "cloudfront_status" {
  description = "Current status of the CloudFront distribution"
  value       = module.cdn.cloudfront_status
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate used by CloudFront"
  value       = module.cdn.acm_certificate_arn
}

output "acm_certificate_status" {
  description = "Status of the ACM certificate (PENDING_VALIDATION, ISSUED, etc.)"
  value       = module.cdn.acm_certificate_status
}

output "acm_certificate_validation_records" {
  description = "DNS validation records for ACM certificate - ADD THESE TO CLOUDFLARE DNS"
  value       = module.cdn.acm_certificate_validation_records
}

output "cloudflare_cname_records" {
  description = "CNAME records to add to Cloudflare DNS - ADD THESE AFTER CERTIFICATE VALIDATION"
  value       = module.cdn.cloudflare_cname_records
}

output "custom_domain_urls" {
  description = "URLs for custom domains (after DNS is configured in Cloudflare)"
  value       = module.cdn.custom_domain_urls
}

output "cache_invalidation_command" {
  description = "AWS CLI command to invalidate CloudFront cache"
  value       = module.cdn.cache_invalidation_command
}

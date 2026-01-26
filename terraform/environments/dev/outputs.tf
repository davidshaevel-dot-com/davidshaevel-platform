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
  value       = var.dev_activated ? module.compute[0].ecs_cluster_name : null
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = var.dev_activated ? module.compute[0].ecs_cluster_arn : null
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer (use this to access the application)"
  value       = var.dev_activated ? module.compute[0].alb_dns_name : null
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = var.dev_activated ? module.compute[0].alb_arn : null
}

output "frontend_service_name" {
  description = "Name of the frontend ECS service"
  value       = var.dev_activated ? module.compute[0].frontend_service_name : null
}

output "backend_service_name" {
  description = "Name of the backend ECS service"
  value       = var.dev_activated ? module.compute[0].backend_service_name : null
}

output "application_url" {
  description = "URL to access the application"
  value       = var.dev_activated ? module.compute[0].application_url : null
}

output "frontend_url" {
  description = "URL to access the frontend"
  value       = var.dev_activated ? module.compute[0].frontend_url : null
}

output "backend_url" {
  description = "URL to access the backend API"
  value       = var.dev_activated ? module.compute[0].backend_url : null
}

# -----------------------------------------------------------------------------
# ECR Repository Outputs (Always-on resources)
# -----------------------------------------------------------------------------

output "backend_ecr_repository_url" {
  description = "URL of the backend ECR repository (use for docker push)"
  value       = aws_ecr_repository.backend.repository_url
}

output "backend_ecr_repository_name" {
  description = "Name of the backend ECR repository"
  value       = aws_ecr_repository.backend.name
}

output "frontend_ecr_repository_url" {
  description = "URL of the frontend ECR repository (use for docker push)"
  value       = aws_ecr_repository.frontend.repository_url
}

output "frontend_ecr_repository_name" {
  description = "Name of the frontend ECR repository"
  value       = aws_ecr_repository.frontend.name
}

output "grafana_ecr_repository_url" {
  description = "URL of the Grafana ECR repository (use for docker push)"
  value       = aws_ecr_repository.grafana.repository_url
}

output "grafana_ecr_repository_name" {
  description = "Name of the Grafana ECR repository"
  value       = aws_ecr_repository.grafana.name
}

# -----------------------------------------------------------------------------
# Observability Outputs (Grafana)
# -----------------------------------------------------------------------------

output "grafana_service_name" {
  description = "Name of the Grafana ECS service"
  value       = var.dev_activated ? module.observability[0].grafana_service_name : null
}

# -----------------------------------------------------------------------------
# CDN Outputs (CloudFront)
# -----------------------------------------------------------------------------

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution (use for cache invalidation)"
  value       = var.dev_activated ? module.cdn[0].cloudfront_distribution_id : null
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name (e.g., d123abc.cloudfront.net)"
  value       = var.dev_activated ? module.cdn[0].cloudfront_domain_name : null
}

output "cloudfront_status" {
  description = "Current status of the CloudFront distribution"
  value       = var.dev_activated ? module.cdn[0].cloudfront_status : null
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate used by CloudFront"
  value       = var.dev_activated ? module.cdn[0].acm_certificate_arn : null
}

output "acm_certificate_status" {
  description = "Status of the ACM certificate (PENDING_VALIDATION, ISSUED, etc.)"
  value       = var.dev_activated ? module.cdn[0].acm_certificate_status : null
}

output "acm_certificate_validation_records" {
  description = "DNS validation records for ACM certificate - ADD THESE TO CLOUDFLARE DNS"
  value       = var.dev_activated ? module.cdn[0].acm_certificate_validation_records : null
}

output "cloudflare_cname_records" {
  description = "CNAME records to add to Cloudflare DNS - ADD THESE AFTER CERTIFICATE VALIDATION"
  value       = var.dev_activated ? module.cdn[0].cloudflare_cname_records : null
}

output "custom_domain_urls" {
  description = "URLs for custom domains (after DNS is configured in Cloudflare)"
  value       = var.dev_activated ? module.cdn[0].custom_domain_urls : null
}

output "cache_invalidation_command" {
  description = "AWS CLI command to invalidate CloudFront cache"
  value       = var.dev_activated ? module.cdn[0].cache_invalidation_command : null
}

# -----------------------------------------------------------------------------
# CI/CD IAM Outputs
# -----------------------------------------------------------------------------

output "cicd_iam_user_name" {
  description = "Name of the GitHub Actions IAM user"
  value       = var.dev_activated ? module.cicd_iam[0].user_name : null
}

output "cicd_iam_user_arn" {
  description = "ARN of the GitHub Actions IAM user"
  value       = var.dev_activated ? module.cicd_iam[0].user_arn : null
}

output "cicd_iam_policy_arn" {
  description = "ARN of the GitHub Actions deployment policy"
  value       = var.dev_activated ? module.cicd_iam[0].policy_arn : null
}

output "cicd_iam_policy_name" {
  description = "Name of the GitHub Actions deployment policy"
  value       = var.dev_activated ? module.cicd_iam[0].policy_name : null
}

# -----------------------------------------------------------------------------
# Profiling Artifacts Outputs
# -----------------------------------------------------------------------------

output "profiling_artifacts_bucket_name" {
  description = "Name of the S3 bucket for profiling artifacts (empty if not enabled)"
  value       = var.dev_activated ? module.compute[0].profiling_artifacts_bucket_name : null
}

# -----------------------------------------------------------------------------
# Pilot Light Mode Outputs
# -----------------------------------------------------------------------------

output "dev_activated" {
  description = "Whether the dev environment compute resources are active"
  value       = var.dev_activated
}

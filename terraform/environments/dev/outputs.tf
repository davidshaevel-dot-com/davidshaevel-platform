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

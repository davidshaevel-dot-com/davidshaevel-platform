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

output "database_secret_name" {
  description = "Name of the database credentials secret"
  value       = module.database.secret_name
}

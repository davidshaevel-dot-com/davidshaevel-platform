# Production Environment Outputs
# These outputs provide information about the deployed prod infrastructure

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
# As modules are added, their outputs will be exposed here
# Example:
# output "vpc_id" {
#   description = "The ID of the VPC"
#   value       = module.networking.vpc_id
# }

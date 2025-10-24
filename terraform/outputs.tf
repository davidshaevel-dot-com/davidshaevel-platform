# Root-Level Terraform Outputs
# These outputs provide information about the deployed infrastructure
#
# Outputs can be used by:
# 1. Other Terraform configurations (via terraform_remote_state)
# 2. CI/CD pipelines
# 3. Documentation and verification
#
# View outputs with: terraform output

# -----------------------------------------------------------------------------
# Project Information
# -----------------------------------------------------------------------------

output "project_name" {
  description = "The name of the project"
  value       = var.project_name
}

output "environment" {
  description = "The environment name"
  value       = var.environment
}

output "aws_region" {
  description = "The AWS region where resources are deployed"
  value       = var.aws_region
}

output "aws_account_id" {
  description = "The AWS account ID"
  value       = var.aws_account_id
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Resource Naming Convention
# -----------------------------------------------------------------------------

output "resource_prefix" {
  description = "Standard prefix for resource names"
  value       = "${var.environment}-${var.project_name}"
}

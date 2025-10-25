# Development Environment Configuration
# This file serves as the entry point for the dev environment
#
# Usage:
#   cd terraform/environments/dev
#   terraform init
#   terraform plan
#   terraform apply

terraform {
  # Backend configuration for remote state
  #
  # IMPORTANT: This backend block is intentionally empty.
  # All configuration values are provided via backend-config.tfvars
  # during 'terraform init -backend-config=backend-config.tfvars'
  #
  # This pattern keeps main.tf environment-agnostic while allowing
  # environment-specific backend configuration in separate files.
  # Each environment (dev, prod) has its own backend-config.tfvars.
  backend "s3" {
    # Values loaded from backend-config.tfvars:
    # - bucket: S3 bucket name for state storage
    # - key: State file path (e.g., dev/terraform.tfstate)
    # - region: AWS region for S3 bucket
    # - dynamodb_table: DynamoDB table for state locking
    # - encrypt: Enable encryption at rest (should be true)
  }

  required_version = "~> 1.13.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.18"
    }
  }
}

# AWS Provider Configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        Project     = var.project_name
        Environment = var.environment
        ManagedBy   = "Terraform"
        Repository  = var.repository_name
      },
      var.tags
    )
  }
}

# ==============================================================================
# Networking Module
# ==============================================================================

module "networking" {
  source = "../../modules/networking"

  environment  = var.environment
  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr

  aws_region         = var.aws_region
  availability_zones = var.availability_zones

  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Owner       = "David Shaevel"
    CostCenter  = "Platform Engineering"
  }
}

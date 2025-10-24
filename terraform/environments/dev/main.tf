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
  # Uncomment and configure when ready to use remote state
  #
  # backend "s3" {
  #   # Configuration will be provided via backend-config.tfvars
  #   # or via command-line flags during terraform init
  # }

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
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = var.repository_name
    }
  }
}

# Module imports will be added here as we build out infrastructure
# Examples:
# module "networking" {
#   source = "../../modules/networking"
#   ...
# }

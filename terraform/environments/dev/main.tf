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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
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

  # Enable NAT Gateway with full HA (2 NAT Gateways)
  enable_nat_gateway = true
  single_nat_gateway = false

  # Enable VPC Flow Logs for network monitoring
  enable_flow_logs         = true
  flow_logs_retention_days = 7

  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Owner       = "David Shaevel"
    CostCenter  = "Platform Engineering"
  }
}

# ==============================================================================
# Database Module
# ==============================================================================

module "database" {
  source = "../../modules/database"

  # Environment configuration
  environment  = var.environment
  project_name = var.project_name

  # Networking inputs (from networking module)
  vpc_id                     = module.networking.vpc_id
  private_db_subnet_ids      = module.networking.private_db_subnet_ids
  database_security_group_id = module.networking.database_security_group_id

  # Database configuration (from variables)
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  db_name               = var.db_name
  db_master_username    = var.db_master_username

  # High availability (from variables)
  multi_az            = var.db_multi_az
  deletion_protection = var.db_deletion_protection

  # Tags
  tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Owner       = "David Shaevel"
    CostCenter  = "Platform Engineering"
  }
}

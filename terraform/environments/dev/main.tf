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
}

# ==============================================================================
# Compute Module
# ==============================================================================

module "compute" {
  source = "../../modules/compute"

  # Environment configuration
  environment  = var.environment
  project_name = var.project_name

  # Networking inputs (from networking module)
  vpc_id                     = module.networking.vpc_id
  public_subnet_ids          = module.networking.public_subnet_ids
  private_app_subnet_ids     = module.networking.private_app_subnet_ids
  alb_security_group_id      = module.networking.alb_security_group_id
  frontend_security_group_id = module.networking.app_frontend_security_group_id
  backend_security_group_id  = module.networking.app_backend_security_group_id

  # Database inputs (from database module)
  database_endpoint   = module.database.db_instance_endpoint
  database_port       = module.database.db_instance_port
  database_name       = module.database.db_name
  database_secret_arn = module.database.secret_arn

  # Container images (placeholder for now, will be replaced with ECR images)
  frontend_image = var.frontend_container_image
  backend_image  = var.backend_container_image

  # Task sizing
  frontend_task_cpu    = var.frontend_task_cpu
  frontend_task_memory = var.frontend_task_memory
  backend_task_cpu     = var.backend_task_cpu
  backend_task_memory  = var.backend_task_memory

  # Service configuration
  desired_count_frontend = var.desired_count_frontend
  desired_count_backend  = var.desired_count_backend

  # Health checks
  frontend_health_check_path = var.frontend_health_check_path
  backend_health_check_path  = var.backend_health_check_path
  health_check_grace_period  = var.health_check_grace_period

  # ALB configuration
  enable_deletion_protection = var.alb_enable_deletion_protection

  # CloudWatch Logs
  log_retention_days        = var.ecs_log_retention_days
  enable_container_insights = var.enable_container_insights

  # Tags
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Owner       = "David Shaevel"
    CostCenter  = "Platform Engineering"
  }
}

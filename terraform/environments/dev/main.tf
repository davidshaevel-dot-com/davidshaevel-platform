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

locals {
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = var.repository_name
    },
    var.tags
  )
}

# ==============================================================================
# State Migration - Moved Blocks
# These blocks tell Terraform that modules have been made conditional (with count)
# and resources have moved from module.X to module.X[0]
#
# Note: networking module is NOT conditional because database depends on VPC/subnets.
# NAT Gateway cost optimization would require refactoring the networking module.
# ==============================================================================

moved {
  from = module.compute
  to   = module.compute[0]
}

moved {
  from = module.cdn
  to   = module.cdn[0]
}

moved {
  from = module.cicd_iam
  to   = module.cicd_iam[0]
}

moved {
  from = module.observability
  to   = module.observability[0]
}

moved {
  from = module.service_discovery
  to   = module.service_discovery[0]
}

# AWS Provider Configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# AWS Provider for us-east-1 (CloudFront ACM certificates)
# CloudFront requires ACM certificates to be in us-east-1 region
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = local.common_tags
  }
}

# ==============================================================================
# Networking Module
# ==============================================================================

# NOTE: Networking module is always-on because database depends on VPC/subnets.
# NAT Gateways (~$65/month) are inside this module - for full cost optimization,
# the networking module would need refactoring to make NAT conditional.
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

  # Container ports (from compute module)
  backend_metrics_port  = module.compute[0].backend_port
  frontend_metrics_port = module.compute[0].frontend_port

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
  count  = var.dev_activated ? 1 : 0

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
  alb_certificate_arn        = var.dev_activated ? module.cdn[0].acm_certificate_arn : null

  # CloudWatch Logs
  log_retention_days        = var.ecs_log_retention_days
  enable_container_insights = var.enable_container_insights

  # ECS Exec configuration
  enable_backend_ecs_exec  = var.enable_backend_ecs_exec
  enable_frontend_ecs_exec = var.enable_frontend_ecs_exec

  # Node.js Inspector for remote debugging (TT-63 Part 3)
  enable_backend_inspector = var.enable_backend_inspector

  # Profiling artifacts S3 bucket
  enable_profiling_artifacts_bucket = var.enable_profiling_artifacts_bucket

  # Lab endpoints configuration (TT-63 Node.js Profiling Lab)
  lab_enable = var.lab_enable
  lab_token  = var.lab_token

  # Contact Form Configuration (TT-78)
  resend_api_key    = var.resend_api_key
  contact_form_to   = var.contact_form_to
  contact_form_from = var.contact_form_from

  # Service Discovery (AWS Cloud Map) - from service_discovery module
  backend_service_registry_arn  = module.service_discovery[0].backend_service_arn
  frontend_service_registry_arn = module.service_discovery[0].frontend_service_arn

  # Tags
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Owner       = "David Shaevel"
    CostCenter  = "Platform Engineering"
  }
}

# ==============================================================================
# CDN Module
# ==============================================================================

module "cdn" {
  source = "../../modules/cdn"
  count  = var.dev_activated ? 1 : 0

  # Required provider configuration for us-east-1 ACM certificate
  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  # Environment configuration
  environment  = var.environment
  project_name = var.project_name

  # Domain configuration
  domain_name            = var.domain_name
  alternate_domain_names = var.cdn_alternate_domain_names

  # ALB origin (from compute module)
  alb_dns_name = module.compute[0].alb_dns_name

  # CloudFront configuration
  enable_ipv6         = var.cdn_enable_ipv6
  price_class         = var.cdn_price_class
  default_root_object = var.cdn_default_root_object

  # Logging (optional)
  logging_bucket = var.cdn_logging_bucket
  logging_prefix = var.cdn_logging_prefix

  # Note: cache_policy_id_default and origin_request_policy_id_default
  # now default to Next.js-optimized settings (custom Next.js cache policy
  # with RSC headers in cache key, and AllViewer origin request policy)
}

# ==============================================================================
# CI/CD IAM Module
# ==============================================================================

module "cicd_iam" {
  source = "../../modules/cicd-iam"
  count  = var.dev_activated ? 1 : 0

  environment    = var.environment
  project_name   = var.project_name
  aws_account_id = var.aws_account_id
  aws_region     = var.aws_region

  # CloudFront distribution ID for cache invalidation permissions
  cloudfront_distribution_id = module.cdn[0].cloudfront_distribution_id
}

# ==============================================================================
# Observability Module
# ==============================================================================

module "observability" {
  source = "../../modules/observability"
  count  = var.dev_activated ? 1 : 0

  # Environment configuration
  environment  = var.environment
  project_name = var.project_name

  # Networking inputs (from networking module)
  vpc_id                       = module.networking.vpc_id
  private_app_subnet_ids       = module.networking.private_app_subnet_ids
  prometheus_security_group_id = module.networking.prometheus_security_group_id
  backend_security_group_id    = module.networking.app_backend_security_group_id
  frontend_security_group_id   = module.networking.app_frontend_security_group_id

  # Container ports (from compute module)
  backend_metrics_port  = module.compute[0].backend_port
  frontend_metrics_port = module.compute[0].frontend_port

  # EFS configuration
  enable_prometheus_efs           = true
  prometheus_efs_performance_mode = "generalPurpose"
  prometheus_efs_throughput_mode  = "bursting"
  efs_transition_to_ia_days       = 14 # Changed from 15 to comply with AWS EFS constraints
  enable_efs_encryption           = true

  # S3 configuration
  enable_config_bucket_versioning = true
  config_bucket_lifecycle_days    = 90

  # Prometheus ECS Service configuration (Phase 5 - TT-25)
  aws_region                      = var.aws_region
  ecs_cluster_id                  = module.compute[0].ecs_cluster_id
  prometheus_service_registry_arn = module.service_discovery[0].prometheus_service_arn
  prometheus_image                = var.prometheus_image
  prometheus_task_cpu             = var.prometheus_task_cpu
  prometheus_task_memory          = var.prometheus_task_memory
  prometheus_desired_count        = var.prometheus_desired_count
  prometheus_retention_time       = var.prometheus_retention_time
  prometheus_config_s3_key        = var.prometheus_config_s3_key
  log_retention_days              = var.prometheus_log_retention_days
  enable_ecs_exec                 = var.enable_prometheus_ecs_exec

  # Grafana ECS Service configuration (Phase 10 - TT-25)
  enable_grafana               = true
  grafana_image                = var.grafana_image
  grafana_task_cpu             = var.grafana_task_cpu
  grafana_task_memory          = var.grafana_task_memory
  grafana_desired_count        = var.grafana_desired_count
  grafana_service_registry_arn = module.service_discovery[0].grafana_service_arn
  grafana_admin_password       = var.grafana_admin_password

  # ALB Integration for Public Access (prefers HTTPS listener if available)
  alb_listener_arn      = module.compute[0].alb_https_listener_arn != null ? module.compute[0].alb_https_listener_arn : module.compute[0].alb_http_listener_arn
  alb_security_group_id = module.networking.alb_security_group_id
  grafana_domain_name   = "grafana.${var.domain_name}"

  tags = {
    CostCenter = "Platform Engineering"
    Owner      = "David Shaevel"
  }
}

# ==============================================================================
# Prometheus Configuration Upload to S3
# ==============================================================================

# Render Prometheus configuration from template
# Template variables are substituted with actual values from service discovery
locals {
  prometheus_config_rendered = var.dev_activated ? templatefile("../../../observability/prometheus/prometheus.yml.tpl", {
    environment           = var.environment
    service_prefix        = "${var.environment}-${var.project_name}"
    platform_name         = var.project_name
    private_dns_zone      = var.private_dns_namespace
    backend_service_name  = module.service_discovery[0].backend_service_name
    frontend_service_name = module.service_discovery[0].frontend_service_name
  }) : ""
}

# Upload rendered Prometheus config to S3
# Init container will sync this to EFS on task startup
resource "aws_s3_object" "prometheus_config" {
  count = var.dev_activated ? 1 : 0

  bucket  = module.observability[0].prometheus_config_bucket_id
  key     = var.prometheus_config_s3_key
  content = local.prometheus_config_rendered

  # Content type for YAML files
  content_type = "application/x-yaml"

  # ETag forces update when content changes
  etag = md5(local.prometheus_config_rendered)

  tags = merge(
    local.common_tags,
    {
      Name        = "prometheus-config"
      Application = "prometheus"
      Purpose     = "Prometheus scrape configuration"
    }
  )
}

# ==============================================================================
# Service Discovery Module (AWS Cloud Map)
# ==============================================================================

module "service_discovery" {
  source = "../../modules/service-discovery"
  count  = var.dev_activated ? 1 : 0

  # Environment configuration
  environment  = var.environment
  project_name = var.project_name

  # Networking inputs (from networking module)
  vpc_id = module.networking.vpc_id

  # DNS namespace configuration
  private_dns_namespace = var.private_dns_namespace

  # Note: backend_service_name and frontend_service_name use module defaults
  # ("backend" and "frontend" respectively)

  tags = {
    CostCenter = "Platform Engineering"
    Owner      = "David Shaevel"
  }
}

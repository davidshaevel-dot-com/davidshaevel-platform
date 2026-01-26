# Development Environment Variables
# These variables configure the dev environment
#
# Values can be set via:
# 1. terraform.tfvars file (not committed)
# 2. TF_VAR_* environment variables
# 3. Command-line flags: -var="key=value"

# -----------------------------------------------------------------------------
# Project Configuration
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Dev Environment Activation Control (Pilot Light Mode)
# -----------------------------------------------------------------------------

variable "dev_activated" {
  description = "Whether to deploy compute resources (ECS, NAT, ALB). Set to false for pilot light mode to minimize costs."
  type        = bool
  default     = true  # Default to active for backward compatibility
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "davidshaevel"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# -----------------------------------------------------------------------------
# AWS Configuration
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]{1}$", var.aws_region))
    error_message = "AWS region must be a valid region identifier (e.g., us-east-1, us-gov-west-1, cn-north-1)."
  }
}

variable "aws_account_id" {
  description = "AWS account ID (12-digit number)"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "AWS account ID must be a 12-digit number."
  }
}

# -----------------------------------------------------------------------------
# Domain Configuration
# -----------------------------------------------------------------------------

variable "domain_name" {
  description = "Primary domain name for the application"
  type        = string
  default     = "davidshaevel.com"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]\\.[a-z]{2,}$", var.domain_name))
    error_message = "Domain name must be a valid domain (e.g., example.com)."
  }
}

# -----------------------------------------------------------------------------
# Repository Configuration
# -----------------------------------------------------------------------------

variable "repository_name" {
  description = "Name of the repository (used in resource tags)"
  type        = string
  default     = "davidshaevel-platform"
}

# -----------------------------------------------------------------------------
# Networking Configuration
# -----------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "List of availability zones for multi-AZ deployment"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones are required for high availability."
  }
}

variable "private_dns_namespace" {
  description = "Private DNS namespace for AWS Cloud Map service discovery (e.g., davidshaevel.local)"
  type        = string
  default     = "davidshaevel.local"

  validation {
    condition     = can(regex("^[a-z0-9-]+\\.(local|internal)$", var.private_dns_namespace))
    error_message = "Private DNS namespace must end with .local or .internal and contain only lowercase letters, numbers, and hyphens."
  }
}

# -----------------------------------------------------------------------------
# Database Configuration
# -----------------------------------------------------------------------------

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum allocated storage in GB (for autoscaling)"
  type        = number
  default     = 100
}

variable "db_name" {
  description = "Name of the database to create"
  type        = string
  default     = "davidshaevel"
}

variable "db_master_username" {
  description = "Master username for the database"
  type        = string
  default     = "dbadmin"
  sensitive   = true
}

variable "db_multi_az" {
  description = "Enable Multi-AZ deployment for high availability"
  type        = bool
  default     = false
}

variable "db_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Compute Configuration (ECS + ALB)
# -----------------------------------------------------------------------------

variable "frontend_container_image" {
  description = "Docker image for frontend container"
  type        = string
  default     = "nginx:latest"
}

variable "backend_container_image" {
  description = "Docker image for backend container (must specify explicit tag, e.g., :abc123)"
  type        = string
  # No default - explicit image tag required for safe, predictable deployments
  # Example: terraform apply -var 'backend_container_image=108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/backend:abc123'
}

variable "frontend_task_cpu" {
  description = "CPU units for frontend task (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "frontend_task_memory" {
  description = "Memory (MiB) for frontend task"
  type        = number
  default     = 512
}

variable "backend_task_cpu" {
  description = "CPU units for backend task (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "backend_task_memory" {
  description = "Memory (MiB) for backend task"
  type        = number
  default     = 512
}

variable "desired_count_frontend" {
  description = "Desired number of frontend tasks"
  type        = number
  default     = 2
}

variable "desired_count_backend" {
  description = "Desired number of backend tasks"
  type        = number
  default     = 2
}

variable "frontend_health_check_path" {
  description = "Health check path for frontend service"
  type        = string
  default     = "/"
}

variable "backend_health_check_path" {
  description = "Health check path for backend service"
  type        = string
  default     = "/api/health"
}

variable "health_check_grace_period" {
  description = "Seconds to wait before starting health checks on newly started tasks"
  type        = number
  default     = 60
}

variable "alb_enable_deletion_protection" {
  description = "Enable deletion protection for ALB (recommended for production)"
  type        = bool
  default     = false
}

variable "ecs_log_retention_days" {
  description = "CloudWatch Logs retention period in days for ECS containers"
  type        = number
  default     = 7
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for ECS cluster"
  type        = bool
  default     = true
}

variable "enable_backend_ecs_exec" {
  description = "Enable ECS Exec for debugging backend tasks (allows shell access via AWS CLI)"
  type        = bool
  default     = false
}

variable "enable_frontend_ecs_exec" {
  description = "Enable ECS Exec for debugging frontend tasks (allows shell access via AWS CLI)"
  type        = bool
  default     = false
}

variable "enable_backend_inspector" {
  description = "Enable Node.js Inspector for remote debugging (--inspect=0.0.0.0:9229). WARNING: Only enable temporarily for debugging sessions."
  type        = bool
  default     = false
}

variable "enable_profiling_artifacts_bucket" {
  description = "Create S3 bucket for exporting profiling artifacts (CPU profiles, heap snapshots). When enabled, adds S3 permissions to the backend task role."
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Lab Endpoints Configuration (TT-63 Node.js Profiling Lab)
# -----------------------------------------------------------------------------

variable "lab_enable" {
  description = "Enable lab endpoints for profiling/debugging (should be false in production)"
  type        = bool
  default     = false
}

variable "lab_token" {
  description = "Authentication token for lab endpoints (required if lab_enable is true)"
  type        = string
  default     = ""
  sensitive   = true
}

# -----------------------------------------------------------------------------
# CDN Configuration (CloudFront)
# -----------------------------------------------------------------------------

variable "cdn_alternate_domain_names" {
  description = "List of alternate domain names (CNAMEs) for CloudFront distribution"
  type        = list(string)
  default     = ["www.davidshaevel.com"]
}

variable "cdn_enable_ipv6" {
  description = "Enable IPv6 support for CloudFront distribution"
  type        = bool
  default     = true
}

variable "cdn_price_class" {
  description = "CloudFront distribution price class (PriceClass_All, PriceClass_200, PriceClass_100)"
  type        = string
  default     = "PriceClass_100" # US, Canada, Europe - most cost effective
}

variable "cdn_default_root_object" {
  description = "Object that CloudFront returns when requesting the root URL (empty for Next.js dynamic routing)"
  type        = string
  default     = ""
}

variable "cdn_logging_bucket" {
  description = "S3 bucket for CloudFront access logs (e.g., bucket-name.s3.amazonaws.com). Leave empty to disable."
  type        = string
  default     = ""
}

variable "cdn_logging_prefix" {
  description = "Prefix for CloudFront access log files in S3 bucket"
  type        = string
  default     = "cloudfront/"
}

# -----------------------------------------------------------------------------
# Common Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Prometheus Configuration (TT-25 Phase 5)
# -----------------------------------------------------------------------------

variable "prometheus_image" {
  description = "Docker image for Prometheus (e.g., prom/prometheus:v2.45.0)"
  type        = string
  default     = "prom/prometheus:v2.45.0"
}

variable "prometheus_task_cpu" {
  description = "CPU units for Prometheus task (256 = 0.25 vCPU, 512 = 0.5 vCPU, 1024 = 1 vCPU)"
  type        = number
  default     = 512
}

variable "prometheus_task_memory" {
  description = "Memory (MB) for Prometheus task"
  type        = number
  default     = 1024
}

variable "prometheus_desired_count" {
  description = "Desired number of Prometheus tasks to run"
  type        = number
  default     = 1
}

variable "prometheus_retention_time" {
  description = "How long to retain metrics in Prometheus TSDB (e.g., 15d, 30d, 90d)"
  type        = string
  default     = "15d"
}

variable "prometheus_config_s3_key" {
  description = "S3 key path for Prometheus configuration file"
  type        = string
  default     = "observability/prometheus/prometheus.yml"
}

variable "prometheus_log_retention_days" {
  description = "CloudWatch Logs retention period in days for Prometheus"
  type        = number
  default     = 7
}

variable "enable_prometheus_ecs_exec" {
  description = "Enable ECS Exec for debugging Prometheus tasks"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Grafana Configuration (TT-25 Phase 10)
# -----------------------------------------------------------------------------

variable "grafana_image" {
  description = "Docker image for Grafana"
  type        = string
  default     = "grafana/grafana:10.4.2"
}

variable "grafana_task_cpu" {
  description = "CPU units for Grafana task"
  type        = number
  default     = 512
}

variable "grafana_task_memory" {
  description = "Memory (MB) for Grafana task"
  type        = number
  default     = 1024
}

variable "grafana_desired_count" {
  description = "Desired number of Grafana tasks to run"
  type        = number
  default     = 1
}

variable "grafana_admin_password" {
  description = "Initial admin password for Grafana (stored in Secrets Manager)"
  type        = string
  default     = "" # If empty, a random password will be generated
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Contact Form Configuration (TT-78)
# -----------------------------------------------------------------------------

variable "resend_api_key" {
  description = "Resend API key for sending contact form emails (plain text, not Secrets Manager)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "contact_form_to" {
  description = "Email address to receive contact form submissions"
  type        = string
  default     = "david+contact@davidshaevel.com"
}

variable "contact_form_from" {
  description = "Email address shown as sender for contact form emails"
  type        = string
  default     = "david+noreply@davidshaevel.com"
}

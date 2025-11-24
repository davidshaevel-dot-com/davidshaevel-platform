# ==============================================================================
# Observability Module Variables
# ==============================================================================
#
# This module provisions infrastructure for the observability stack:
# - S3 bucket for Prometheus configuration storage
# - EFS file system for Prometheus data persistence
# - Security groups for EFS access
# - IAM policies for S3 and EFS access
#
# Phase 3 of TT-25: EFS file systems and supporting infrastructure

# ------------------------------------------------------------------------------
# Required Variables
# ------------------------------------------------------------------------------

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = can(regex("^(dev|staging|prod)$", var.environment))
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "vpc_id" {
  description = "ID of the VPC where observability resources will be deployed"
  type        = string
}

variable "private_app_subnet_ids" {
  description = "List of private application subnet IDs for EFS mount targets"
  type        = list(string)

  validation {
    condition     = length(var.private_app_subnet_ids) >= 2
    error_message = "At least 2 private app subnets required for high availability."
  }
}

variable "prometheus_security_group_id" {
  description = "Security group ID for Prometheus ECS tasks (will be allowed to access EFS)"
  type        = string
}

# ------------------------------------------------------------------------------
# Optional Variables with Defaults
# ------------------------------------------------------------------------------

variable "enable_prometheus_efs" {
  description = "Enable EFS file system for Prometheus data persistence"
  type        = bool
  default     = true
}

variable "prometheus_efs_performance_mode" {
  description = "EFS performance mode for Prometheus data (generalPurpose or maxIO)"
  type        = string
  default     = "generalPurpose"

  validation {
    condition     = can(regex("^(generalPurpose|maxIO)$", var.prometheus_efs_performance_mode))
    error_message = "Performance mode must be generalPurpose or maxIO."
  }
}

variable "prometheus_efs_throughput_mode" {
  description = "EFS throughput mode for Prometheus (bursting or provisioned)"
  type        = string
  default     = "bursting"

  validation {
    condition     = can(regex("^(bursting|provisioned)$", var.prometheus_efs_throughput_mode))
    error_message = "Throughput mode must be bursting or provisioned."
  }
}

variable "efs_transition_to_ia_days" {
  description = <<-EOT
    Number of days before transitioning EFS data to Infrequent Access storage class.
    This controls EFS lifecycle management, not Prometheus data retention.
    Prometheus retention is configured separately in the Dockerfile CMD flags.
    Valid values: 1, 7, 14, 30, 60, 90 days (AWS EFS constraints).
  EOT
  type        = number
  default     = 14

  validation {
    condition     = contains([1, 7, 14, 30, 60, 90], var.efs_transition_to_ia_days)
    error_message = "EFS IA transition must be one of: 1, 7, 14, 30, 60, 90 days."
  }
}

variable "enable_efs_encryption" {
  description = "Enable encryption at rest for EFS file system"
  type        = bool
  default     = true
}

variable "enable_config_bucket_versioning" {
  description = "Enable versioning for Prometheus config S3 bucket"
  type        = bool
  default     = true
}

variable "config_bucket_lifecycle_days" {
  description = "Number of days before old config versions expire (0 to disable)"
  type        = number
  default     = 90

  validation {
    condition     = var.config_bucket_lifecycle_days >= 0
    error_message = "Lifecycle days must be >= 0."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------------------------
# Prometheus ECS Service Variables (Phase 5 - TT-25)
# ------------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for CloudWatch Logs configuration"
  type        = string
}

variable "ecs_cluster_id" {
  description = "ID of the ECS cluster where Prometheus will run"
  type        = string
}

variable "prometheus_service_registry_arn" {
  description = "ARN of the service discovery registry for Prometheus"
  type        = string
}

variable "prometheus_image" {
  description = "Docker image for Prometheus (e.g., prom/prometheus:v2.45.0)"
  type        = string
  default     = "prom/prometheus:v2.45.0"

  validation {
    condition     = can(regex("^[a-z0-9/_-]+:[a-z0-9._-]+$", var.prometheus_image))
    error_message = "Prometheus image must be a valid Docker image reference (repository:tag)."
  }
}

variable "prometheus_task_cpu" {
  description = "CPU units for Prometheus task (256 = 0.25 vCPU, 512 = 0.5 vCPU, 1024 = 1 vCPU)"
  type        = number
  default     = 512

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.prometheus_task_cpu)
    error_message = "Prometheus task CPU must be one of: 256, 512, 1024, 2048, 4096."
  }
}

variable "prometheus_task_memory" {
  description = "Memory (MB) for Prometheus task (must be valid for selected CPU)"
  type        = number
  default     = 1024

  validation {
    condition     = var.prometheus_task_memory >= 512 && var.prometheus_task_memory <= 30720
    error_message = "Prometheus task memory must be between 512 and 30720 MB."
  }
}

variable "prometheus_desired_count" {
  description = "Desired number of Prometheus tasks to run"
  type        = number
  default     = 1

  validation {
    condition     = var.prometheus_desired_count >= 0 && var.prometheus_desired_count <= 10
    error_message = "Prometheus desired count must be between 0 and 10."
  }
}

variable "prometheus_retention_time" {
  description = "How long to retain metrics in Prometheus TSDB (e.g., 15d, 30d, 90d)"
  type        = string
  default     = "15d"

  validation {
    condition     = can(regex("^[0-9]+[smhdwy]$", var.prometheus_retention_time))
    error_message = "Retention time must be a valid duration (e.g., 15d, 30d, 90d)."
  }
}

variable "prometheus_config_s3_key" {
  description = "S3 key path for Prometheus configuration file"
  type        = string
  default     = "observability/prometheus/prometheus.yml"
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days"
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention days must be a valid CloudWatch Logs retention period."
  }
}

variable "enable_ecs_exec" {
  description = "Enable ECS Exec for debugging Prometheus tasks"
  type        = bool
  default     = false
}

# ------------------------------------------------------------------------------
# Grafana ECS Service Variables (Phase 10 - TT-25)
# ------------------------------------------------------------------------------

variable "enable_grafana" {
  description = "Enable Grafana resources"
  type        = bool
  default     = true
}

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

variable "grafana_service_registry_arn" {
  description = "ARN of the service discovery registry for Grafana"
  type        = string
}

variable "grafana_admin_password" {
  description = "Initial admin password for Grafana (stored in Secrets Manager)"
  type        = string
  default     = "" # If empty, a random password will be generated
  sensitive   = true
}

variable "grafana_security_group_id" {
  description = "Security group ID for Grafana ECS tasks"
  type        = string
  default     = "" # If empty, a new security group will be created
}

variable "alb_listener_arn" {
  description = "ARN of the ALB listener to attach the Grafana listener rule to (HTTPS preferred)"
  type        = string
  default     = null
}

variable "grafana_domain_name" {
  description = "Domain name for public Grafana access (e.g. grafana.davidshaevel.com)"
  type        = string
  default     = ""
}

variable "alb_security_group_id" {
  description = "Security group ID for the Application Load Balancer (for Grafana ingress)"
  type        = string
  default     = null
}

# ------------------------------------------------------------------------------
# Application Security Groups for Metrics Scraping
# ------------------------------------------------------------------------------

variable "backend_security_group_id" {
  description = "Security group ID for backend containers (for Prometheus to scrape /api/metrics)"
  type        = string
}

variable "frontend_security_group_id" {
  description = "Security group ID for frontend containers (for Prometheus to scrape /api/metrics)"
  type        = string
}

variable "backend_metrics_port" {
  description = "Port number for backend metrics endpoint (passed from compute module)"
  type        = number
}

variable "frontend_metrics_port" {
  description = "Port number for frontend metrics endpoint (passed from compute module)"
  type        = number
}

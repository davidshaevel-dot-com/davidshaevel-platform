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

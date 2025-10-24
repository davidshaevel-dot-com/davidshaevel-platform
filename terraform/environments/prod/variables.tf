# Production Environment Variables
# These variables configure the prod environment
#
# Values can be set via:
# 1. terraform.tfvars file (not committed)
# 2. TF_VAR_* environment variables
# 3. Command-line flags: -var="key=value"

# -----------------------------------------------------------------------------
# Project Configuration
# -----------------------------------------------------------------------------

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
  default     = "prod"

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
# Common Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

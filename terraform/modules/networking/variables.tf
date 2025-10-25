# ==============================================================================
# Networking Module Variables
# ==============================================================================

# ------------------------------------------------------------------------------
# Required Variables
# ------------------------------------------------------------------------------

variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be 'dev' or 'prod'."
  }
}

variable "project_name" {
  description = "Project name for resource naming (e.g., 'davidshaevel')"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------------------------
# Regional Configuration
# ------------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
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

# ------------------------------------------------------------------------------
# Subnet Configuration (for Step 5 implementation)
# ------------------------------------------------------------------------------
# These variables are defined but not yet used in Step 4
# They will be utilized when implementing subnets in Step 5

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == length(var.availability_zones)
    error_message = "Number of public subnet CIDRs must match the number of availability zones."
  }
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for private application subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]

  validation {
    condition     = length(var.private_app_subnet_cidrs) == length(var.availability_zones)
    error_message = "Number of private app subnet CIDRs must match the number of availability zones."
  }
}

variable "private_db_subnet_cidrs" {
  description = "CIDR blocks for private database subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24"]

  validation {
    condition     = length(var.private_db_subnet_cidrs) == length(var.availability_zones)
    error_message = "Number of private DB subnet CIDRs must match the number of availability zones."
  }
}

# ------------------------------------------------------------------------------
# NAT Gateway Configuration (for Step 5 implementation)
# ------------------------------------------------------------------------------

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnet internet access"
  type        = bool
  default     = false
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway for all AZs (cost optimization)"
  type        = bool
  default     = false
}

# ------------------------------------------------------------------------------
# VPC Flow Logs Configuration (for Step 5 implementation)
# ------------------------------------------------------------------------------

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs for network monitoring"
  type        = bool
  default     = false
}

variable "flow_logs_retention_days" {
  description = "Number of days to retain VPC Flow Logs"
  type        = number
  default     = 7

  validation {
    # Valid retention periods per AWS CloudWatch Logs documentation:
    # https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/Working-with-log-groups-and-streams.html
    # AWS only supports specific retention periods (not arbitrary values)
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180,
      365, 400, 545, 731, 1827, 3653
    ], var.flow_logs_retention_days)
    error_message = "Flow logs retention must be a valid CloudWatch Logs retention period."
  }
}


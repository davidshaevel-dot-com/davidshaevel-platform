# Disaster Recovery Environment Variables
# Region: us-west-2 (Oregon)
#
# These variables configure the DR environment for Pilot Light strategy

# -----------------------------------------------------------------------------
# DR Activation Control
# -----------------------------------------------------------------------------

variable "dr_activated" {
  description = "Whether to deploy the full DR infrastructure. Set to true during DR activation."
  type        = bool
  default     = false
}

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
  default     = "dr"

  validation {
    condition     = contains(["dr", "disaster-recovery"], var.environment)
    error_message = "Environment must be dr or disaster-recovery."
  }
}

# -----------------------------------------------------------------------------
# AWS Configuration
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for DR environment"
  type        = string
  default     = "us-west-2"

  validation {
    condition     = var.aws_region == "us-west-2"
    error_message = "DR region must be us-west-2 (Oregon)."
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
# Primary Region Configuration (us-east-1)
# These variables reference resources in the primary region for DR replication
# -----------------------------------------------------------------------------

variable "primary_db_instance_identifier" {
  description = "RDS instance identifier of the primary database in us-east-1 (e.g., 'dev-davidshaevel-db')"
  type        = string
  default     = "dev-davidshaevel-db"
}

variable "primary_db_kms_key_arn" {
  description = "ARN of the KMS key used to encrypt the primary database in us-east-1"
  type        = string
  default     = null # Will be set via tfvars or at apply time
}

# -----------------------------------------------------------------------------
# Domain Configuration
# -----------------------------------------------------------------------------

variable "domain_name" {
  description = "Primary domain name for the application"
  type        = string
  default     = "davidshaevel.com"
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
  description = "CIDR block for the DR VPC (same as primary for consistency)"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "List of availability zones for DR region"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b"]

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones are required."
  }
}

variable "private_dns_namespace" {
  description = "Private DNS namespace for AWS Cloud Map service discovery"
  type        = string
  default     = "davidshaevel.local"
}

# -----------------------------------------------------------------------------
# Database Configuration
# -----------------------------------------------------------------------------

variable "db_instance_class" {
  description = "RDS instance class for DR"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum allocated storage in GB"
  type        = number
  default     = 100
}

variable "db_name" {
  description = "Name of the database"
  type        = string
  default     = "davidshaevel"
}

variable "db_master_username" {
  description = "Master username for the database"
  type        = string
  default     = "dbadmin"
  sensitive   = true
}

variable "db_snapshot_identifier" {
  description = "Snapshot identifier to restore from (for DR activation)"
  type        = string
  default     = null
}

variable "dr_database_secret_arn" {
  description = "ARN of the Secrets Manager secret containing DR database credentials. Required when restoring from snapshot since RDS doesn't auto-create a managed secret."
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Compute Configuration
# -----------------------------------------------------------------------------

variable "frontend_container_image" {
  description = "Docker image for frontend container (us-west-2 ECR URL)"
  type        = string
  default     = null
}

variable "backend_container_image" {
  description = "Docker image for backend container (us-west-2 ECR URL)"
  type        = string
  default     = null
}

variable "frontend_task_cpu" {
  description = "CPU units for frontend task"
  type        = number
  default     = 256
}

variable "frontend_task_memory" {
  description = "Memory (MiB) for frontend task"
  type        = number
  default     = 512
}

variable "backend_task_cpu" {
  description = "CPU units for backend task"
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
  description = "Seconds to wait before starting health checks"
  type        = number
  default     = 60
}

variable "ecs_log_retention_days" {
  description = "CloudWatch Logs retention period in days"
  type        = number
  default     = 7
}

# -----------------------------------------------------------------------------
# DR-Specific Configuration
# -----------------------------------------------------------------------------

variable "dr_acm_certificate_arn" {
  description = "ARN of ACM certificate in us-west-2 for ALB HTTPS"
  type        = string
  default     = null
}

# -----------------------------------------------------------------------------
# Common Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

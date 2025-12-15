# ------------------------------------------------------------------------------
# Compute Module Variables
# ECS Fargate cluster, Application Load Balancer, and containerized services
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Required Variables
# ------------------------------------------------------------------------------

variable "project_name" {
  description = "Name of the project (used in resource naming)"
  type        = string

  validation {
    condition     = length(var.project_name) > 0 && length(var.project_name) <= 32
    error_message = "Project name must be between 1 and 32 characters."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# ------------------------------------------------------------------------------
# Networking Variables (from networking module)
# ------------------------------------------------------------------------------

variable "vpc_id" {
  description = "ID of the VPC where resources will be deployed"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB deployment"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "At least 2 public subnets required for ALB high availability."
  }
}

variable "private_app_subnet_ids" {
  description = "List of private app subnet IDs for ECS tasks"
  type        = list(string)

  validation {
    condition     = length(var.private_app_subnet_ids) >= 2
    error_message = "At least 2 private subnets required for ECS task high availability."
  }
}

variable "alb_security_group_id" {
  description = "Security group ID for Application Load Balancer"
  type        = string
}

variable "frontend_security_group_id" {
  description = "Security group ID for frontend containers"
  type        = string
}

variable "backend_security_group_id" {
  description = "Security group ID for backend containers"
  type        = string
}

# ------------------------------------------------------------------------------
# Database Variables (from database module)
# ------------------------------------------------------------------------------

variable "database_endpoint" {
  description = "Database endpoint (host:port) for backend connection"
  type        = string
}

variable "database_port" {
  description = "Database port number"
  type        = number
  default     = 5432
}

variable "database_name" {
  description = "Database name"
  type        = string
}

variable "database_secret_arn" {
  description = "ARN of the AWS Secrets Manager secret containing database credentials"
  type        = string
}

# ------------------------------------------------------------------------------
# Container Image Variables
# ------------------------------------------------------------------------------

variable "frontend_image" {
  description = "Docker image for frontend container (e.g., nginx:latest or ECR URI)"
  type        = string
  default     = "nginx:latest"
}

variable "backend_image" {
  description = "Docker image for backend container (e.g., nginx:latest or ECR URI)"
  type        = string
  default     = "nginx:latest"
}

# ------------------------------------------------------------------------------
# ECS Task Configuration
# ------------------------------------------------------------------------------

variable "frontend_task_cpu" {
  description = "CPU units for frontend task (256 = 0.25 vCPU)"
  type        = number
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.frontend_task_cpu)
    error_message = "CPU must be one of: 256, 512, 1024, 2048, 4096."
  }
}

variable "frontend_task_memory" {
  description = "Memory (MiB) for frontend task"
  type        = number
  default     = 512

  validation {
    condition     = contains([512, 1024, 2048, 3072, 4096, 5120, 6144, 7168, 8192], var.frontend_task_memory)
    error_message = "Memory must be valid for the selected CPU size."
  }
}

variable "backend_task_cpu" {
  description = "CPU units for backend task (256 = 0.25 vCPU)"
  type        = number
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.backend_task_cpu)
    error_message = "CPU must be one of: 256, 512, 1024, 2048, 4096."
  }
}

variable "backend_task_memory" {
  description = "Memory (MiB) for backend task"
  type        = number
  default     = 512

  validation {
    condition     = contains([512, 1024, 2048, 3072, 4096, 5120, 6144, 7168, 8192], var.backend_task_memory)
    error_message = "Memory must be valid for the selected CPU size."
  }
}

# ------------------------------------------------------------------------------
# ECS Service Configuration
# ------------------------------------------------------------------------------

variable "desired_count_frontend" {
  description = "Desired number of frontend tasks"
  type        = number
  default     = 2

  validation {
    condition     = var.desired_count_frontend >= 0 && var.desired_count_frontend <= 10
    error_message = "Desired count must be between 0 and 10."
  }
}

variable "desired_count_backend" {
  description = "Desired number of backend tasks"
  type        = number
  default     = 2

  validation {
    condition     = var.desired_count_backend >= 0 && var.desired_count_backend <= 10
    error_message = "Desired count must be between 0 and 10."
  }
}

variable "health_check_grace_period" {
  description = "Seconds to wait before starting health checks on newly started tasks"
  type        = number
  default     = 60

  validation {
    condition     = var.health_check_grace_period >= 0 && var.health_check_grace_period <= 300
    error_message = "Health check grace period must be between 0 and 300 seconds."
  }
}

# ------------------------------------------------------------------------------
# ALB Configuration
# ------------------------------------------------------------------------------

variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALB (recommended for production)"
  type        = bool
  default     = false
}

variable "alb_idle_timeout" {
  description = "Time in seconds that the connection is allowed to be idle"
  type        = number
  default     = 60

  validation {
    condition     = var.alb_idle_timeout >= 1 && var.alb_idle_timeout <= 4000
    error_message = "ALB idle timeout must be between 1 and 4000 seconds."
  }
}

variable "enable_alb_access_logs" {
  description = "Enable ALB access logs to S3 bucket"
  type        = bool
  default     = false
}

variable "alb_access_logs_bucket" {
  description = "S3 bucket name for ALB access logs (required if enable_alb_access_logs is true)"
  type        = string
  default     = ""

  validation {
    condition     = !var.enable_alb_access_logs || (var.enable_alb_access_logs && var.alb_access_logs_bucket != "")
    error_message = "alb_access_logs_bucket must be provided when enable_alb_access_logs is true."
  }
}

variable "alb_certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS listener (optional, enables HTTPS if provided)"
  type        = string
  default     = null
}

variable "alb_ssl_policy" {
  description = "SSL policy for HTTPS listener (only used if alb_certificate_arn is provided)"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  validation {
    condition = contains([
      "ELBSecurityPolicy-TLS13-1-2-2021-06",
      "ELBSecurityPolicy-TLS13-1-3-2021-06",
      "ELBSecurityPolicy-2016-08",
      "ELBSecurityPolicy-TLS-1-2-2017-01",
      "ELBSecurityPolicy-FS-1-2-Res-2020-10"
    ], var.alb_ssl_policy)
    error_message = "Invalid SSL policy. Must be a valid ELB security policy."
  }
}

# ------------------------------------------------------------------------------
# Health Check Configuration
# ------------------------------------------------------------------------------

variable "frontend_health_check_path" {
  description = "Health check path for frontend service"
  type        = string
  default     = "/health"
}

variable "backend_health_check_path" {
  description = "Health check path for backend service"
  type        = string
  default     = "/api/health"
}

variable "health_check_interval" {
  description = "Seconds between health checks"
  type        = number
  default     = 30

  validation {
    condition     = var.health_check_interval >= 5 && var.health_check_interval <= 300
    error_message = "Health check interval must be between 5 and 300 seconds."
  }
}

variable "health_check_timeout" {
  description = "Seconds to wait for health check response"
  type        = number
  default     = 5

  validation {
    condition     = var.health_check_timeout >= 2 && var.health_check_timeout <= 120
    error_message = "Health check timeout must be between 2 and 120 seconds."
  }
}

variable "healthy_threshold" {
  description = "Number of consecutive successful health checks required"
  type        = number
  default     = 2

  validation {
    condition     = var.healthy_threshold >= 2 && var.healthy_threshold <= 10
    error_message = "Healthy threshold must be between 2 and 10."
  }
}

variable "unhealthy_threshold" {
  description = "Number of consecutive failed health checks required"
  type        = number
  default     = 3

  validation {
    condition     = var.unhealthy_threshold >= 2 && var.unhealthy_threshold <= 10
    error_message = "Unhealthy threshold must be between 2 and 10."
  }
}

# ------------------------------------------------------------------------------
# CloudWatch Logs Configuration
# ------------------------------------------------------------------------------

variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days"
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention must be a valid CloudWatch Logs retention period."
  }
}

variable "enable_container_insights" {
  description = "Enable CloudWatch Container Insights for ECS cluster"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# ECS Exec Configuration
# ------------------------------------------------------------------------------

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

# ------------------------------------------------------------------------------
# Service Discovery Configuration (AWS Cloud Map)
# ------------------------------------------------------------------------------

variable "backend_service_registry_arn" {
  description = "ARN of the Cloud Map service registry for backend service discovery"
  type        = string
  default     = ""
}

variable "frontend_service_registry_arn" {
  description = "ARN of the Cloud Map service registry for frontend service discovery"
  type        = string
  default     = ""
}

# ------------------------------------------------------------------------------
# Lab Endpoints Configuration (Node.js Profiling Lab - TT-63)
# ------------------------------------------------------------------------------

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

# ------------------------------------------------------------------------------
# Tags
# ------------------------------------------------------------------------------

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ==============================================================================
# Database Module Variables
# ==============================================================================

# ------------------------------------------------------------------------------
# Required Variables - From Environment
# ------------------------------------------------------------------------------

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ------------------------------------------------------------------------------
# Networking Inputs
# ------------------------------------------------------------------------------

variable "vpc_id" {
  description = "VPC ID where the database will be deployed"
  type        = string
}

variable "private_db_subnet_ids" {
  description = "List of private database subnet IDs"
  type        = list(string)
}

variable "database_security_group_id" {
  description = "Security group ID for database access (from networking module)"
  type        = string
}

# ------------------------------------------------------------------------------
# Database Configuration
# ------------------------------------------------------------------------------

variable "engine" {
  description = "Database engine (postgres, mysql, etc.)"
  type        = string
  default     = "postgres"
}

variable "engine_version" {
  description = "Database engine version"
  type        = string
  default     = "15.12" # Latest stable PostgreSQL 15
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
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

# ------------------------------------------------------------------------------
# Storage Configuration
# ------------------------------------------------------------------------------

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Maximum allocated storage in GB (for autoscaling)"
  type        = number
  default     = 100
}

variable "storage_type" {
  description = "Storage type (gp3, gp2, io1)"
  type        = string
  default     = "gp3"
}

# ------------------------------------------------------------------------------
# Backup Configuration
# ------------------------------------------------------------------------------

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Daily time range for backups (UTC)"
  type        = string
  default     = "03:00-04:00"
}

# ------------------------------------------------------------------------------
# Maintenance Configuration
# ------------------------------------------------------------------------------

variable "maintenance_window" {
  description = "Weekly maintenance window (day:hh24:mi-day:hh24:mi)"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "auto_minor_version_upgrade" {
  description = "Enable automatic minor version upgrades"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------------------
# Monitoring Configuration
# ------------------------------------------------------------------------------

variable "cloudwatch_logs_exports" {
  description = "List of log types to export to CloudWatch"
  type        = list(string)
  default     = ["postgresql", "upgrade"]
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

variable "performance_insights_retention_period" {
  description = "Performance Insights retention period in days"
  type        = number
  default     = 7 # Free tier is 7 days
}

# ------------------------------------------------------------------------------
# High Availability Configuration
# ------------------------------------------------------------------------------

variable "multi_az" {
  description = "Enable Multi-AZ deployment for high availability"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false # Set to true for production
}

# ------------------------------------------------------------------------------
# Parameter Group Configuration
# ------------------------------------------------------------------------------

variable "create_parameter_group" {
  description = "Whether to create a custom parameter group"
  type        = bool
  default     = false
}

variable "parameter_group_family" {
  description = "Parameter group family"
  type        = string
  default     = "postgres15"
}

# ------------------------------------------------------------------------------
# CloudWatch Alarms Configuration
# ------------------------------------------------------------------------------

variable "alarm_actions" {
  description = "List of ARNs to notify when alarm triggers"
  type        = list(string)
  default     = [] # No SNS topics configured yet
}

variable "max_connections_threshold" {
  description = "Threshold for max connections alarm"
  type        = number
  default     = 80 # 80% of default for db.t3.micro (87 connections)
}

variable "low_free_storage_threshold_bytes" {
  description = "Threshold for low free storage alarm (in bytes)"
  type        = number
  default     = 10737418240 # 10 GB in bytes
}

variable "low_freeable_memory_threshold_bytes" {
  description = "Threshold for low freeable memory alarm (in bytes)"
  type        = number
  default     = 536870912 # 512 MB in bytes
}

# ==============================================================================
# Service Discovery Module Variables
# ==============================================================================
#
# This module provisions AWS Cloud Map service discovery infrastructure:
# - Private DNS namespace for internal service communication
# - Service discovery services for ECS applications
# - SRV records for Prometheus service discovery
#
# Phase 4 of TT-25: AWS Cloud Map service discovery

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
  description = "ID of the VPC where the private DNS namespace will be created"
  type        = string

  validation {
    condition     = substr(var.vpc_id, 0, 4) == "vpc-"
    error_message = "The vpc_id must be a valid VPC ID, starting with 'vpc-'."
  }
}

variable "private_dns_namespace" {
  description = "Private DNS namespace for service discovery (e.g., davidshaevel.local)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+\\.(local|internal)$", var.private_dns_namespace))
    error_message = "Private DNS namespace must end with .local or .internal and contain only lowercase letters, numbers, and hyphens."
  }
}

# ------------------------------------------------------------------------------
# Optional Variables with Defaults
# ------------------------------------------------------------------------------

variable "backend_service_name" {
  description = "Name for the backend service in Cloud Map"
  type        = string
  default     = "backend"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.backend_service_name))
    error_message = "Backend service name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "frontend_service_name" {
  description = "Name for the frontend service in Cloud Map"
  type        = string
  default     = "frontend"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.frontend_service_name))
    error_message = "Frontend service name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "backend_port" {
  description = "Port number for the backend service"
  type        = number
  default     = 3001

  validation {
    condition     = var.backend_port > 0 && var.backend_port <= 65535
    error_message = "Backend port must be between 1 and 65535."
  }
}

variable "frontend_port" {
  description = "Port number for the frontend service"
  type        = number
  default     = 3000

  validation {
    condition     = var.frontend_port > 0 && var.frontend_port <= 65535
    error_message = "Frontend port must be between 1 and 65535."
  }
}

variable "prometheus_service_name" {
  description = "Name for the prometheus service in Cloud Map"
  type        = string
  default     = "prometheus"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.prometheus_service_name))
    error_message = "Prometheus service name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "prometheus_port" {
  description = "Port number for the prometheus service"
  type        = number
  default     = 9090

  validation {
    condition     = var.prometheus_port > 0 && var.prometheus_port <= 65535
    error_message = "Prometheus port must be between 1 and 65535."
  }
}

variable "grafana_service_name" {
  description = "Name for the grafana service in Cloud Map"
  type        = string
  default     = "grafana"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.grafana_service_name))
    error_message = "Grafana service name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "grafana_port" {
  description = "Port number for the grafana service"
  type        = number
  default     = 3000

  validation {
    condition     = var.grafana_port > 0 && var.grafana_port <= 65535
    error_message = "Grafana port must be between 1 and 65535."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ==============================================================================
# Service Discovery Module - AWS Cloud Map Configuration
# ==============================================================================
#
# This module provisions AWS Cloud Map service discovery infrastructure:
# - Private DNS namespace for internal service communication
# - Service discovery services for backend and frontend applications
# - SRV records for Prometheus service discovery and scraping
#
# Phase 4 of TT-25: AWS Cloud Map service discovery for observability
#
# Architecture:
# 1. Private DNS namespace (davidshaevel.local) for internal service resolution
# 2. Service registry for each ECS service (backend, frontend)
# 3. Automatic DNS registration when ECS tasks start/stop
# 4. SRV records enable Prometheus to discover and scrape metrics endpoints
#

locals {
  name_prefix = "${var.environment}-${var.project_name}"

  common_tags = merge(
    var.tags,
    {
      Module      = "service-discovery"
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
    }
  )
}

# ==============================================================================
# Private DNS Namespace
# ==============================================================================

# Create private DNS namespace for service discovery
# This namespace is only resolvable within the VPC
# Format: {service-name}.{namespace} (e.g., backend.davidshaevel.local)
resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = var.private_dns_namespace
  description = "Private DNS namespace for ${var.environment} environment service discovery"
  vpc         = var.vpc_id

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-private-dns-namespace"
    }
  )
}

# ==============================================================================
# Backend Service Discovery
# ==============================================================================

# Service discovery for backend API
# Enables automatic DNS registration and health checking
# Prometheus will discover backend instances via SRV records
resource "aws_service_discovery_service" "backend" {
  name = var.backend_service_name

  description = "Service discovery for backend API in ${var.environment}"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    # Create both A and SRV records for comprehensive service discovery
    dns_records {
      ttl  = 10
      type = "A"
    }

    dns_records {
      ttl  = 10
      type = "SRV"
    }

    routing_policy = "MULTIVALUE"
  }

  # Health check configuration - ECS will manage health checks
  # failure_threshold is deprecated and always set to 1 by AWS
  health_check_custom_config {}

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.name_prefix}-backend-service-discovery"
      Application = "backend"
    }
  )
}

# ==============================================================================
# Frontend Service Discovery
# ==============================================================================

# Service discovery for frontend application
# Enables automatic DNS registration and health checking
# Prometheus will discover frontend instances via SRV records
resource "aws_service_discovery_service" "frontend" {
  name = var.frontend_service_name

  description = "Service discovery for frontend application in ${var.environment}"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    # Create both A and SRV records for comprehensive service discovery
    dns_records {
      ttl  = 10
      type = "A"
    }

    dns_records {
      ttl  = 10
      type = "SRV"
    }

    routing_policy = "MULTIVALUE"
  }

  # Health check configuration - ECS will manage health checks
  # failure_threshold is deprecated and always set to 1 by AWS
  health_check_custom_config {}

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.name_prefix}-frontend-service-discovery"
      Application = "frontend"
    }
  )
}

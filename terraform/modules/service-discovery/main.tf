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

  # Map of service ports for Prometheus configuration
  service_ports = {
    backend    = var.backend_port
    frontend   = var.frontend_port
    prometheus = var.prometheus_port
  }

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
# Service Discovery for Applications
# ==============================================================================

# Service discovery for backend, frontend, and prometheus applications
# Enables automatic DNS registration and health checking
# Prometheus will discover instances via SRV records
resource "aws_service_discovery_service" "app_service" {
  for_each = {
    backend    = var.backend_service_name
    frontend   = var.frontend_service_name
    prometheus = var.prometheus_service_name
  }

  name = each.value

  description = "Service discovery for ${each.key} application in ${var.environment}"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    # Create both A and SRV records for comprehensive service discovery
    # Using dynamic block to reduce duplication and improve maintainability
    dynamic "dns_records" {
      for_each = toset(["A", "SRV"])
      content {
        ttl  = 10
        type = dns_records.value
      }
    }

    routing_policy = "MULTIVALUE"
  }

  # Note: health_check_custom_config block removed as AWS does not support
  # empty configuration blocks. ECS manages health checks automatically
  # without requiring explicit service discovery health check configuration.

  tags = merge(
    local.common_tags,
    {
      Name        = "${local.name_prefix}-${each.key}-service-discovery"
      Application = each.key
    }
  )
}

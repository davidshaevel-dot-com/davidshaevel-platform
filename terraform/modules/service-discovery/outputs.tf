# ==============================================================================
# Service Discovery Module Outputs
# ==============================================================================
#
# Outputs provide information needed by other modules:
# - Namespace and service IDs for ECS service integration
# - DNS names for Prometheus configuration
# - ARNs for IAM policies and monitoring
#

# ------------------------------------------------------------------------------
# Private DNS Namespace Outputs
# ------------------------------------------------------------------------------

output "private_dns_namespace_id" {
  description = "ID of the private DNS namespace"
  value       = aws_service_discovery_private_dns_namespace.main.id
}

output "private_dns_namespace_arn" {
  description = "ARN of the private DNS namespace"
  value       = aws_service_discovery_private_dns_namespace.main.arn
}

output "private_dns_namespace_name" {
  description = "Name of the private DNS namespace"
  value       = aws_service_discovery_private_dns_namespace.main.name
}

output "private_dns_namespace_hosted_zone_id" {
  description = "Route 53 hosted zone ID for the private DNS namespace"
  value       = aws_service_discovery_private_dns_namespace.main.hosted_zone
}

# ------------------------------------------------------------------------------
# Backend Service Discovery Outputs
# ------------------------------------------------------------------------------

output "backend_service_id" {
  description = "ID of the backend service discovery service"
  value       = aws_service_discovery_service.app_service["backend"].id
}

output "backend_service_arn" {
  description = "ARN of the backend service discovery service"
  value       = aws_service_discovery_service.app_service["backend"].arn
}

output "backend_service_name" {
  description = "Name of the backend service in Cloud Map"
  value       = aws_service_discovery_service.app_service["backend"].name
}

output "backend_dns_name" {
  description = "Fully qualified DNS name for backend service (for Prometheus config)"
  value       = "${aws_service_discovery_service.app_service["backend"].name}.${aws_service_discovery_private_dns_namespace.main.name}"
}

# ------------------------------------------------------------------------------
# Frontend Service Discovery Outputs
# ------------------------------------------------------------------------------

output "frontend_service_id" {
  description = "ID of the frontend service discovery service"
  value       = aws_service_discovery_service.app_service["frontend"].id
}

output "frontend_service_arn" {
  description = "ARN of the frontend service discovery service"
  value       = aws_service_discovery_service.app_service["frontend"].arn
}

output "frontend_service_name" {
  description = "Name of the frontend service in Cloud Map"
  value       = aws_service_discovery_service.app_service["frontend"].name
}

output "frontend_dns_name" {
  description = "Fully qualified DNS name for frontend service (for Prometheus config)"
  value       = "${aws_service_discovery_service.app_service["frontend"].name}.${aws_service_discovery_private_dns_namespace.main.name}"
}

# ------------------------------------------------------------------------------
# Consolidated Service Map Output
# ------------------------------------------------------------------------------

output "services" {
  description = "Map of all created service discovery services with their attributes"
  value = {
    for k, v in aws_service_discovery_service.app_service : k => {
      id       = v.id
      arn      = v.arn
      name     = v.name
      dns_name = "${v.name}.${aws_service_discovery_private_dns_namespace.main.name}"
    }
  }
}

# ------------------------------------------------------------------------------
# Prometheus Configuration Helpers
# ------------------------------------------------------------------------------

output "prometheus_dns_sd_configs" {
  description = "DNS service discovery configuration for Prometheus (use in prometheus.yml.tpl)"
  value = {
    for k, v in aws_service_discovery_service.app_service : k => {
      dns_name = "${v.name}.${aws_service_discovery_private_dns_namespace.main.name}"
      port     = local.service_ports[k]
      type     = "SRV"
    }
  }
}

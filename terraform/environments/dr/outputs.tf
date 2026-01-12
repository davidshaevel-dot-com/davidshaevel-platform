# Disaster Recovery Environment Outputs
# These outputs provide information about the DR infrastructure

# -----------------------------------------------------------------------------
# Environment Information
# -----------------------------------------------------------------------------

output "environment" {
  description = "The environment name"
  value       = var.environment
}

output "aws_region" {
  description = "The AWS region where DR resources are deployed"
  value       = var.aws_region
}

output "dr_activated" {
  description = "Whether full DR infrastructure is deployed"
  value       = var.dr_activated
}

# -----------------------------------------------------------------------------
# Pilot Light (Always-On) Outputs
# -----------------------------------------------------------------------------

output "dr_kms_key_arn" {
  description = "ARN of the KMS key for DR encryption"
  value       = aws_kms_key.dr_encryption.arn
}

output "dr_kms_key_alias" {
  description = "Alias of the KMS key for DR encryption"
  value       = aws_kms_alias.dr_encryption.name
}

output "ecr_replication_status" {
  description = "ECR replication configuration status"
  value       = "Replicating davidshaevel/* images from us-east-1 to us-west-2"
}

output "snapshot_copy_lambda_arn" {
  description = "ARN of the Lambda function for snapshot copying"
  value       = aws_lambda_function.snapshot_copy.arn
}

# -----------------------------------------------------------------------------
# Deploy-On-Demand Outputs (only when dr_activated = true)
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "The ID of the DR VPC"
  value       = var.dr_activated ? module.networking[0].vpc_id : null
}

output "alb_dns_name" {
  description = "DNS name of the DR Application Load Balancer"
  value       = var.dr_activated ? module.compute[0].alb_dns_name : null
}

output "database_endpoint" {
  description = "DR RDS instance endpoint"
  value       = var.dr_activated ? module.database[0].db_instance_endpoint : null
}

output "ecs_cluster_name" {
  description = "Name of the DR ECS cluster"
  value       = var.dr_activated ? module.compute[0].ecs_cluster_name : null
}

output "frontend_service_name" {
  description = "Name of the frontend ECS service"
  value       = var.dr_activated ? module.compute[0].frontend_service_name : null
}

output "backend_service_name" {
  description = "Name of the backend ECS service"
  value       = var.dr_activated ? module.compute[0].backend_service_name : null
}

# -----------------------------------------------------------------------------
# DR Activation Instructions
# -----------------------------------------------------------------------------

output "dr_activation_instructions" {
  description = "Instructions for activating DR"
  value       = <<-EOF

    ========================================
    DISASTER RECOVERY ACTIVATION
    ========================================

    Current Status: ${var.dr_activated ? "ACTIVATED" : "PILOT LIGHT (standby)"}

    Always-On Components:
    ✓ ECR cross-region replication
    ✓ RDS snapshot copy Lambda
    ✓ KMS encryption key

    To activate full DR infrastructure:

    1. Find latest DR snapshot (copied from primary):
       aws rds describe-db-snapshots \
         --region ${var.aws_region} \
         --snapshot-type manual \
         --query 'DBSnapshots[?starts_with(DBSnapshotIdentifier, `${var.primary_db_instance_identifier}-dr-`)] | sort_by(@, &SnapshotCreateTime) | [-1].DBSnapshotIdentifier' \
         --output text

    2. Activate DR:
       terraform apply \
         -var="dr_activated=true" \
         -var="db_snapshot_identifier=<snapshot-id>" \
         -var="frontend_container_image=<ecr-image>" \
         -var="backend_container_image=<ecr-image>"

    3. Update DNS to point to DR ALB

    Estimated activation time: 30-45 minutes

    ========================================
  EOF
}

# -----------------------------------------------------------------------------
# Observability Outputs (only when dr_activated = true)
# -----------------------------------------------------------------------------

output "prometheus_service_name" {
  description = "Name of the Prometheus ECS service"
  value       = var.dr_activated ? module.observability[0].prometheus_service_name : null
}

output "grafana_service_name" {
  description = "Name of the Grafana ECS service"
  value       = var.dr_activated ? module.observability[0].grafana_service_name : null
}

output "prometheus_endpoint" {
  description = "Prometheus endpoint (internal)"
  value       = var.dr_activated ? "http://prometheus.${var.private_dns_namespace}:9090" : null
}

output "grafana_endpoint" {
  description = "Grafana endpoint (internal)"
  value       = var.dr_activated ? "http://grafana.${var.private_dns_namespace}:3000" : null
}

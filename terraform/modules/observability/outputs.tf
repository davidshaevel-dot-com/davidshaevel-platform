# ==============================================================================
# Observability Module Outputs
# ==============================================================================
#
# These outputs are used by other modules (primarily compute module)
# to configure Prometheus ECS tasks with access to S3 config and EFS storage

# ------------------------------------------------------------------------------
# S3 Bucket Outputs
# ------------------------------------------------------------------------------

output "prometheus_config_bucket_id" {
  description = "ID of the S3 bucket storing Prometheus configuration"
  value       = aws_s3_bucket.prometheus_config.id
}

output "prometheus_config_bucket_arn" {
  description = "ARN of the S3 bucket storing Prometheus configuration"
  value       = aws_s3_bucket.prometheus_config.arn
}

output "prometheus_config_bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.prometheus_config.bucket_domain_name
}

# ------------------------------------------------------------------------------
# EFS File System Outputs
# ------------------------------------------------------------------------------

output "prometheus_efs_id" {
  description = "ID of the Prometheus EFS file system"
  value       = var.enable_prometheus_efs ? aws_efs_file_system.prometheus[0].id : null
}

output "prometheus_efs_arn" {
  description = "ARN of the Prometheus EFS file system"
  value       = var.enable_prometheus_efs ? aws_efs_file_system.prometheus[0].arn : null
}

output "prometheus_efs_dns_name" {
  description = "DNS name of the Prometheus EFS file system"
  value       = var.enable_prometheus_efs ? aws_efs_file_system.prometheus[0].dns_name : null
}

# ------------------------------------------------------------------------------
# EFS Mount Target Outputs
# ------------------------------------------------------------------------------

output "prometheus_efs_mount_target_ids" {
  description = "List of EFS mount target IDs"
  value       = var.enable_prometheus_efs ? aws_efs_mount_target.prometheus[*].id : []
}

output "prometheus_efs_mount_target_ips" {
  description = "List of EFS mount target IP addresses"
  value       = var.enable_prometheus_efs ? aws_efs_mount_target.prometheus[*].ip_address : []
}

output "prometheus_efs_mount_target_availability_zones" {
  description = "List of availability zones where EFS mount targets are deployed"
  value       = var.enable_prometheus_efs ? aws_efs_mount_target.prometheus[*].availability_zone_name : []
}

# ------------------------------------------------------------------------------
# Security Group Outputs
# ------------------------------------------------------------------------------

output "efs_security_group_id" {
  description = "ID of the EFS security group"
  value       = var.enable_prometheus_efs ? aws_security_group.efs[0].id : null
}

output "efs_security_group_arn" {
  description = "ARN of the EFS security group"
  value       = var.enable_prometheus_efs ? aws_security_group.efs[0].arn : null
}

# ------------------------------------------------------------------------------
# IAM Policy Outputs
# ------------------------------------------------------------------------------

output "prometheus_s3_config_policy_arn" {
  description = "ARN of the IAM policy for Prometheus S3 config access"
  value       = aws_iam_policy.prometheus_s3_config_access.arn
}

output "prometheus_s3_config_policy_name" {
  description = "Name of the IAM policy for Prometheus S3 config access"
  value       = aws_iam_policy.prometheus_s3_config_access.name
}

# ------------------------------------------------------------------------------
# Configuration Helpers
# ------------------------------------------------------------------------------

output "prometheus_config_s3_key" {
  description = "Suggested S3 key path for Prometheus configuration file"
  value       = "${var.project_name}/${var.environment}/observability/prometheus/prometheus.yml"
}

output "prometheus_efs_mount_path" {
  description = "Suggested container mount path for Prometheus EFS volume"
  value       = "/prometheus"
}

# ------------------------------------------------------------------------------
# Prometheus ECS Service Outputs (Phase 5 - TT-25)
# ------------------------------------------------------------------------------

output "prometheus_task_execution_role_arn" {
  description = "ARN of the Prometheus task execution role"
  value       = aws_iam_role.prometheus_task_execution.arn
}

output "prometheus_task_role_arn" {
  description = "ARN of the Prometheus task role"
  value       = aws_iam_role.prometheus_task.arn
}

output "prometheus_task_definition_arn" {
  description = "ARN of the Prometheus ECS task definition"
  value       = var.enable_prometheus_efs ? aws_ecs_task_definition.prometheus[0].arn : null
}

output "prometheus_service_name" {
  description = "Name of the Prometheus ECS service"
  value       = var.enable_prometheus_efs ? aws_ecs_service.prometheus[0].name : null
}

output "prometheus_service_id" {
  description = "ID of the Prometheus ECS service"
  value       = var.enable_prometheus_efs ? aws_ecs_service.prometheus[0].id : null
}

output "prometheus_log_group_name" {
  description = "Name of the CloudWatch log group for Prometheus"
  value       = aws_cloudwatch_log_group.prometheus.name
}

output "prometheus_log_group_arn" {
  description = "ARN of the CloudWatch log group for Prometheus"
  value       = aws_cloudwatch_log_group.prometheus.arn
}

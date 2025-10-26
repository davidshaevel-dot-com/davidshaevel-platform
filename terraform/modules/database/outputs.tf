# ==============================================================================
# Database Module Outputs
# ==============================================================================

# ------------------------------------------------------------------------------
# RDS Instance Outputs
# ------------------------------------------------------------------------------

output "db_instance_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.main.id
}

output "db_instance_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.main.arn
}

output "db_instance_endpoint" {
  description = "RDS instance endpoint (hostname)"
  value       = aws_db_instance.main.endpoint
}

output "db_instance_address" {
  description = "RDS instance hostname (DNS name)"
  value       = aws_db_instance.main.address
}

output "db_instance_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

output "db_username" {
  description = "Master username"
  value       = aws_db_instance.main.username
  sensitive   = true
}

# ------------------------------------------------------------------------------
# Subnet Group Outputs
# ------------------------------------------------------------------------------

output "db_subnet_group_id" {
  description = "RDS DB subnet group ID"
  value       = aws_db_subnet_group.main.id
}

output "db_subnet_group_arn" {
  description = "RDS DB subnet group ARN"
  value       = aws_db_subnet_group.main.arn
}

# ------------------------------------------------------------------------------
# Secrets Manager Outputs
# ------------------------------------------------------------------------------

output "secret_arn" {
  description = "ARN of the database credentials secret managed by RDS"
  value       = length(aws_db_instance.main.master_user_secret) > 0 ? aws_db_instance.main.master_user_secret[0].secret_arn : null
}

output "secret_name" {
  description = "Name of the database credentials secret managed by RDS"
  value       = null
}

# ------------------------------------------------------------------------------
# Connection String Outputs
# ------------------------------------------------------------------------------

output "connection_string" {
  description = "Database connection string (without credentials)"
  value       = "postgresql://${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
  sensitive   = false
}

output "jdbc_connection_string" {
  description = "JDBC connection string (without credentials)"
  value       = "jdbc:postgresql://${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
  sensitive   = false
}

# ------------------------------------------------------------------------------
# CloudWatch Alarms Outputs
# ------------------------------------------------------------------------------

output "alarm_high_cpu_arn" {
  description = "ARN of the high CPU alarm"
  value       = aws_cloudwatch_metric_alarm.high_cpu.arn
}

output "alarm_high_connections_arn" {
  description = "ARN of the high connections alarm"
  value       = aws_cloudwatch_metric_alarm.high_connections.arn
}

output "alarm_low_free_storage_arn" {
  description = "ARN of the low free storage alarm"
  value       = aws_cloudwatch_metric_alarm.low_free_storage.arn
}

output "alarm_low_freeable_memory_arn" {
  description = "ARN of the low freeable memory alarm"
  value       = aws_cloudwatch_metric_alarm.low_freeable_memory.arn
}

# ------------------------------------------------------------------------------
# Resource Tags
# ------------------------------------------------------------------------------

output "tags" {
  description = "Tags applied to the database resources"
  value       = var.tags
}

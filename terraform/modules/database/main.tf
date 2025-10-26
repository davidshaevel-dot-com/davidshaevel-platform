# ==============================================================================
# Database Module - RDS PostgreSQL
# ==============================================================================
# This module provisions an RDS PostgreSQL database with:
# - High availability configuration
# - Security best practices
# - Automated backups
# - Monitoring and alerting
# - Secrets management
# ==============================================================================

terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# ------------------------------------------------------------------------------
# Random Password Generation
# ------------------------------------------------------------------------------

resource "random_password" "db_master_password" {
  length  = 32
  special = true

  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ------------------------------------------------------------------------------
# IAM Role for Enhanced Monitoring
# ------------------------------------------------------------------------------

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "${var.project_name}-${var.environment}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-rds-monitoring-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ------------------------------------------------------------------------------
# AWS Secrets Manager - Database Credentials
# ------------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}-${var.environment}-db-credentials"
  description             = "Database credentials for ${var.project_name} ${var.environment}"
  recovery_window_in_days = 7

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-db-credentials"
    }
  )
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_master_username
    password = random_password.db_master_password.result
    engine   = "postgres"
    host     = aws_db_instance.main.endpoint
    port     = 5432
    dbname   = var.db_name
  })
}

# ------------------------------------------------------------------------------
# RDS Subnet Group
# ------------------------------------------------------------------------------

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = var.private_db_subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-db-subnet-group"
    }
  )
}

# ------------------------------------------------------------------------------
# RDS Parameter Group (Optional - for future customization)
# ------------------------------------------------------------------------------

resource "aws_db_parameter_group" "main" {
  count  = var.create_parameter_group ? 1 : 0
  name   = "${var.project_name}-${var.environment}-db-parameters"
  family = var.parameter_group_family

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-db-parameters"
    }
  )
}

# ------------------------------------------------------------------------------
# Security Group (Using existing from networking module)
# ------------------------------------------------------------------------------

# Note: We use the database security group passed from the networking module
# No additional security group rules needed here

# ------------------------------------------------------------------------------
# RDS Instance
# ------------------------------------------------------------------------------

resource "aws_db_instance" "main" {
  # Basic Configuration
  identifier     = "${var.project_name}-${var.environment}-db"
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  # Database Configuration
  db_name  = var.db_name
  username = var.db_master_username
  password = random_password.db_master_password.result

  # Storage Configuration
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = true # Always encrypt at rest

  # Network Configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.database_security_group_id]
  publicly_accessible    = false # Always private

  # Backup Configuration
  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  copy_tags_to_snapshot   = true

  # Maintenance Configuration
  maintenance_window         = var.maintenance_window
  auto_minor_version_upgrade = var.auto_minor_version_upgrade

  # Monitoring Configuration
  monitoring_interval                   = 60 # Enhanced monitoring every 60 seconds
  monitoring_role_arn                   = aws_iam_role.rds_enhanced_monitoring.arn
  enabled_cloudwatch_logs_exports       = var.cloudwatch_logs_exports
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_retention_period

  # High Availability
  multi_az                  = var.multi_az
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = !var.deletion_protection
  final_snapshot_identifier = var.deletion_protection ? "${var.project_name}-${var.environment}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null

  # Parameter Group
  parameter_group_name = var.create_parameter_group ? aws_db_parameter_group.main[0].name : null

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-db"
    }
  )

  # Lifecycle to prevent accidental recreation
  lifecycle {
    ignore_changes = [
      password,
      final_snapshot_identifier,
    ]
  }
}

# ------------------------------------------------------------------------------
# CloudWatch Alarms - Database Monitoring
# ------------------------------------------------------------------------------

# CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-db-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors RDS CPU utilization"
  treat_missing_data  = "breaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  alarm_actions = var.alarm_actions

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-db-high-cpu"
    }
  )
}

# Database Connections Alarm
resource "aws_cloudwatch_metric_alarm" "high_connections" {
  alarm_name          = "${var.project_name}-${var.environment}-db-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.max_connections_threshold
  alarm_description   = "This metric monitors RDS database connections"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  alarm_actions = var.alarm_actions

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-db-high-connections"
    }
  )
}

# Free Storage Space Alarm
resource "aws_cloudwatch_metric_alarm" "low_free_storage" {
  alarm_name          = "${var.project_name}-${var.environment}-db-low-free-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 10737418240 # 10 GB in bytes
  alarm_description   = "This metric monitors RDS free storage space"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  alarm_actions = var.alarm_actions

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-db-low-free-storage"
    }
  )
}

# Freeable Memory Alarm
resource "aws_cloudwatch_metric_alarm" "low_freeable_memory" {
  alarm_name          = "${var.project_name}-${var.environment}-db-low-freeable-memory"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 536870912 # 512 MB in bytes
  alarm_description   = "This metric monitors RDS freeable memory"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  alarm_actions = var.alarm_actions

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-db-low-freeable-memory"
    }
  )
}

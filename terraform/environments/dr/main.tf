# Disaster Recovery Environment Configuration (Pilot Light)
# Region: us-west-2 (Oregon)
#
# This environment implements a Pilot Light DR strategy:
# - Always-on: ECR replication, RDS snapshots, KMS key
# - Deploy-on-demand: VPC, ECS, ALB, RDS restore
#
# Usage:
#   cd terraform/environments/dr
#   terraform init -backend-config=backend-config.tfvars
#   terraform plan
#   terraform apply
#
# For DR activation:
#   terraform apply -var="dr_activated=true"

terraform {
  # Backend configuration for remote state
  # State is stored separately from dev/prod for isolation
  backend "s3" {
    # Values loaded from backend-config.tfvars:
    # - bucket: S3 bucket name for state storage
    # - key: dr/terraform.tfstate (separate from dev/prod)
    # - region: us-east-1 (same as state bucket)
    # - dynamodb_table: DynamoDB table for state locking
    # - encrypt: true
  }

  required_version = "~> 1.13.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.18"
    }
  }
}

locals {
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = var.repository_name
      Owner       = "David Shaevel"
      DRRegion    = "true"
    },
    var.tags
  )
}

# AWS Provider Configuration for DR region (us-west-2)
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# AWS Provider for us-east-1 (for cross-region resources)
# Used for: ECR replication config, accessing primary region resources
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = local.common_tags
  }
}

# ==============================================================================
# Pilot Light - Always-On Resources
# These resources are always deployed, even when DR is not activated
# ==============================================================================

# KMS Key for encrypting RDS snapshots and other resources in DR region
resource "aws_kms_key" "dr_encryption" {
  description             = "${var.environment}-${var.project_name} DR encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name    = "${var.environment}-${var.project_name}-dr-key"
    Purpose = "DR encryption"
  }
}

resource "aws_kms_alias" "dr_encryption" {
  name          = "alias/${var.environment}-${var.project_name}-dr"
  target_key_id = aws_kms_key.dr_encryption.key_id
}

# ==============================================================================
# ECR Cross-Region Replication (configured from primary region)
# This resource is created in us-east-1 to replicate TO us-west-2
# ==============================================================================

resource "aws_ecr_replication_configuration" "cross_region" {
  provider = aws.us_east_1

  replication_configuration {
    rule {
      destination {
        region      = var.aws_region # us-west-2
        registry_id = var.aws_account_id
      }

      repository_filter {
        filter      = "davidshaevel"
        filter_type = "PREFIX_MATCH"
      }
    }
  }
}

# ==============================================================================
# RDS Automated Snapshot Copy (Event-Driven)
# Copies snapshots from us-east-1 to us-west-2
# ==============================================================================

# IAM Role for Lambda to copy snapshots
resource "aws_iam_role" "snapshot_copy_lambda" {
  name = "${var.environment}-${var.project_name}-dr-snapshot-copy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = {
    Name    = "${var.environment}-${var.project_name}-dr-snapshot-copy"
    Purpose = "Cross-region RDS snapshot copy"
  }
}

resource "aws_iam_role_policy" "snapshot_copy_lambda" {
  name = "snapshot-copy-policy"
  role = aws_iam_role.snapshot_copy_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DescribeSnapshots"
        Effect   = "Allow"
        Action   = ["rds:DescribeDBSnapshots"]
        Resource = "*" # DescribeDBSnapshots does not support resource-level permissions
      },
      {
        Sid    = "CopySourceSnapshots"
        Effect = "Allow"
        Action = [
          "rds:CopyDBSnapshot",
          "rds:AddTagsToResource",
          "rds:ListTagsForResource"
        ]
        Resource = [
          # Source snapshots from primary DB (automated backups)
          "arn:aws:rds:us-east-1:${var.aws_account_id}:snapshot:rds:${var.primary_db_instance_identifier}-*",
          # Destination snapshots in DR region (named: {db_identifier}-dr-{timestamp})
          "arn:aws:rds:${var.aws_region}:${var.aws_account_id}:snapshot:${var.primary_db_instance_identifier}-dr-*"
        ]
      },
      {
        Sid      = "DeleteOldDRSnapshots"
        Effect   = "Allow"
        Action   = ["rds:DeleteDBSnapshot"]
        Resource = "arn:aws:rds:${var.aws_region}:${var.aws_account_id}:snapshot:${var.primary_db_instance_identifier}-dr-*"
      },
      {
        Sid    = "KMSAccess"
        Effect = "Allow"
        Action = [
          "kms:CreateGrant",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*"
        ]
        Resource = compact([
          aws_kms_key.dr_encryption.arn,
          var.primary_db_kms_key_arn # Primary DB encryption key (null if not set)
        ])
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:us-east-1:${var.aws_account_id}:log-group:/aws/lambda/${var.environment}-${var.project_name}-dr-snapshot-copy:*"
      }
    ]
  })
}

# Lambda function for snapshot copy
resource "aws_lambda_function" "snapshot_copy" {
  provider = aws.us_east_1

  function_name = "${var.environment}-${var.project_name}-dr-snapshot-copy"
  description   = "Copies RDS snapshots to DR region (us-west-2)"
  role          = aws_iam_role.snapshot_copy_lambda.arn

  runtime     = "python3.12"
  handler     = "index.handler"
  timeout     = 300
  memory_size = 128

  filename         = data.archive_file.snapshot_copy_lambda.output_path
  source_code_hash = data.archive_file.snapshot_copy_lambda.output_base64sha256

  environment {
    variables = {
      TARGET_REGION  = var.aws_region
      TARGET_KMS_KEY = aws_kms_key.dr_encryption.arn
      DB_IDENTIFIER  = var.primary_db_instance_identifier
      MAX_SNAPSHOTS  = "3" # Keep last 3 snapshots in DR region
    }
  }

  tags = {
    Name    = "${var.environment}-${var.project_name}-dr-snapshot-copy"
    Purpose = "Cross-region DR snapshot copy"
  }
}

# Lambda source code
data "archive_file" "snapshot_copy_lambda" {
  type        = "zip"
  output_path = "${path.root}/.terraform/tmp/snapshot_copy.zip"

  source {
    content  = <<-EOF
      import boto3
      import os
      import json
      from datetime import datetime

      def handler(event, context):
          """
          Copies RDS automated snapshots to DR region.
          Triggered by EventBridge when new automated snapshot is created.
          """
          target_region = os.environ['TARGET_REGION']
          target_kms_key = os.environ['TARGET_KMS_KEY']
          db_identifier = os.environ['DB_IDENTIFIER']
          max_snapshots = int(os.environ.get('MAX_SNAPSHOTS', '3'))

          # Parse EventBridge event
          detail = event.get('detail', {})
          source_snapshot_arn = detail.get('SourceArn', '')

          if not source_snapshot_arn:
              print("No source snapshot ARN in event")
              return {'statusCode': 400, 'body': 'No source snapshot ARN'}

          source_snapshot_id = source_snapshot_arn.split(':')[-1]

          # Create target snapshot identifier
          timestamp = datetime.now().strftime('%Y%m%d-%H%M%S')
          target_snapshot_id = f"{db_identifier}-dr-{timestamp}"

          print(f"Copying snapshot {source_snapshot_id} to {target_region} as {target_snapshot_id}")

          # Copy snapshot to DR region
          target_rds = boto3.client('rds', region_name=target_region)

          try:
              response = target_rds.copy_db_snapshot(
                  SourceDBSnapshotIdentifier=source_snapshot_arn,
                  TargetDBSnapshotIdentifier=target_snapshot_id,
                  KmsKeyId=target_kms_key,
                  CopyTags=True,
                  SourceRegion='us-east-1',
                  Tags=[
                      {'Key': 'DRCopy', 'Value': 'true'},
                      {'Key': 'SourceSnapshot', 'Value': source_snapshot_id},
                      {'Key': 'CopiedAt', 'Value': timestamp}
                  ]
              )
              print(f"Snapshot copy initiated: {response['DBSnapshot']['DBSnapshotIdentifier']}")

              # Cleanup old DR snapshots (keep only max_snapshots)
              cleanup_old_snapshots(target_rds, db_identifier, max_snapshots)

              return {'statusCode': 200, 'body': f'Copied to {target_snapshot_id}'}

          except Exception as e:
              print(f"Error copying snapshot: {str(e)}")
              raise

      def cleanup_old_snapshots(rds_client, db_identifier, max_snapshots):
          """Delete old DR snapshots, keeping only the most recent ones."""
          try:
              # List DR snapshots
              response = rds_client.describe_db_snapshots(
                  SnapshotType='manual',
                  DBInstanceIdentifier=db_identifier
              )

              # Filter to DR copies and sort by creation time
              dr_snapshots = [
                  s for s in response['DBSnapshots']
                  if s['DBSnapshotIdentifier'].startswith(f"{db_identifier}-dr-")
              ]
              dr_snapshots.sort(key=lambda x: x['SnapshotCreateTime'], reverse=True)

              # Delete old snapshots
              for snapshot in dr_snapshots[max_snapshots:]:
                  snapshot_id = snapshot['DBSnapshotIdentifier']
                  print(f"Deleting old DR snapshot: {snapshot_id}")
                  rds_client.delete_db_snapshot(DBSnapshotIdentifier=snapshot_id)

          except Exception as e:
              print(f"Error during cleanup: {str(e)}")
    EOF
    filename = "index.py"
  }
}

# EventBridge rule to trigger on RDS snapshot completion (in us-east-1)
resource "aws_cloudwatch_event_rule" "rds_snapshot" {
  provider = aws.us_east_1

  name        = "${var.environment}-${var.project_name}-dr-snapshot-trigger"
  description = "Trigger DR snapshot copy when automated RDS snapshot completes"

  event_pattern = jsonencode({
    source      = ["aws.rds"]
    detail-type = ["RDS DB Snapshot Event"]
    detail = {
      SourceType = ["SNAPSHOT"]
      EventID    = ["RDS-EVENT-0091"] # Automated snapshot created
      SourceIdentifier = [{
        prefix = "rds:${var.primary_db_instance_identifier}"
      }]
    }
  })

  tags = {
    Name    = "${var.environment}-${var.project_name}-dr-snapshot-trigger"
    Purpose = "DR snapshot copy trigger"
  }
}

resource "aws_cloudwatch_event_target" "rds_snapshot" {
  provider = aws.us_east_1

  rule      = aws_cloudwatch_event_rule.rds_snapshot.name
  target_id = "dr-snapshot-copy"
  arn       = aws_lambda_function.snapshot_copy.arn
}

resource "aws_lambda_permission" "eventbridge" {
  provider = aws.us_east_1

  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.snapshot_copy.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.rds_snapshot.arn
}

# ==============================================================================
# Deploy-On-Demand Resources (DR Activation)
# These resources are only created when dr_activated = true
# ==============================================================================

# Networking Module (deploy-on-demand)
module "networking" {
  source = "../../modules/networking"
  count  = var.dr_activated ? 1 : 0

  environment  = var.environment
  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr

  aws_region         = var.aws_region
  availability_zones = var.availability_zones

  # Cost optimization: Single NAT Gateway for DR
  enable_nat_gateway = true
  single_nat_gateway = true

  # Enable VPC Flow Logs
  enable_flow_logs         = true
  flow_logs_retention_days = 7

  # Placeholder ports (will be updated when compute is deployed)
  backend_metrics_port  = 3001
  frontend_metrics_port = 3000

  common_tags = local.common_tags
}

# Database Module (restore from snapshot)
module "database" {
  source = "../../modules/database"
  count  = var.dr_activated ? 1 : 0

  environment  = var.environment
  project_name = var.project_name

  vpc_id                     = module.networking[0].vpc_id
  private_db_subnet_ids      = module.networking[0].private_db_subnet_ids
  database_security_group_id = module.networking[0].database_security_group_id

  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  db_name               = var.db_name
  db_master_username    = var.db_master_username

  # DR-specific: Restore from snapshot
  snapshot_identifier = var.db_snapshot_identifier

  # Single-AZ for DR (cost optimization)
  multi_az            = false
  deletion_protection = false
}

# Service Discovery Module (deploy-on-demand)
module "service_discovery" {
  source = "../../modules/service-discovery"
  count  = var.dr_activated ? 1 : 0

  environment  = var.environment
  project_name = var.project_name

  vpc_id                = module.networking[0].vpc_id
  private_dns_namespace = var.private_dns_namespace

  tags = {
    DRRegion = "true"
  }
}

# Compute Module (deploy-on-demand)
module "compute" {
  source = "../../modules/compute"
  count  = var.dr_activated ? 1 : 0

  environment  = var.environment
  project_name = var.project_name

  vpc_id                     = module.networking[0].vpc_id
  public_subnet_ids          = module.networking[0].public_subnet_ids
  private_app_subnet_ids     = module.networking[0].private_app_subnet_ids
  alb_security_group_id      = module.networking[0].alb_security_group_id
  frontend_security_group_id = module.networking[0].app_frontend_security_group_id
  backend_security_group_id  = module.networking[0].app_backend_security_group_id

  database_endpoint   = module.database[0].db_instance_endpoint
  database_port       = module.database[0].db_instance_port
  database_name       = module.database[0].db_name
  # When restoring from snapshot, use the DR secret ARN (RDS doesn't auto-create a managed secret)
  database_secret_arn = coalesce(module.database[0].secret_arn, var.dr_database_secret_arn)

  # Use DR region ECR images (replicated automatically)
  frontend_image = var.frontend_container_image
  backend_image  = var.backend_container_image

  # Task sizing (same as primary)
  frontend_task_cpu    = var.frontend_task_cpu
  frontend_task_memory = var.frontend_task_memory
  backend_task_cpu     = var.backend_task_cpu
  backend_task_memory  = var.backend_task_memory

  # Service configuration
  desired_count_frontend = var.desired_count_frontend
  desired_count_backend  = var.desired_count_backend

  # Health checks
  frontend_health_check_path = var.frontend_health_check_path
  backend_health_check_path  = var.backend_health_check_path
  health_check_grace_period  = var.health_check_grace_period

  # ALB configuration
  enable_deletion_protection = false
  alb_certificate_arn        = var.dr_acm_certificate_arn

  # CloudWatch Logs
  log_retention_days        = var.ecs_log_retention_days
  enable_container_insights = true

  # ECS Exec (for debugging)
  enable_backend_ecs_exec  = true
  enable_frontend_ecs_exec = true

  # Lab endpoints disabled in DR
  lab_enable = false
  lab_token  = ""

  # No profiling bucket in DR
  enable_profiling_artifacts_bucket = false
  enable_backend_inspector          = false

  # Service Discovery
  backend_service_registry_arn  = module.service_discovery[0].backend_service_arn
  frontend_service_registry_arn = module.service_discovery[0].frontend_service_arn

  common_tags = local.common_tags
}

# Observability Module (deploy-on-demand) - Prometheus & Grafana
module "observability" {
  source = "../../modules/observability"
  count  = var.dr_activated ? 1 : 0

  environment  = var.environment
  project_name = var.project_name

  # Networking inputs
  vpc_id                       = module.networking[0].vpc_id
  private_app_subnet_ids       = module.networking[0].private_app_subnet_ids
  prometheus_security_group_id = module.networking[0].prometheus_security_group_id
  backend_security_group_id    = module.networking[0].app_backend_security_group_id
  frontend_security_group_id   = module.networking[0].app_frontend_security_group_id

  # Container ports
  backend_metrics_port  = 3001
  frontend_metrics_port = 3000

  # EFS configuration (cost-optimized for DR)
  enable_prometheus_efs           = true
  prometheus_efs_performance_mode = "generalPurpose"
  prometheus_efs_throughput_mode  = "bursting"
  efs_transition_to_ia_days       = 7 # Faster transition for DR
  enable_efs_encryption           = true

  # S3 configuration
  enable_config_bucket_versioning = true
  config_bucket_lifecycle_days    = 30 # Shorter lifecycle for DR

  # Prometheus ECS Service
  aws_region                      = var.aws_region
  ecs_cluster_id                  = module.compute[0].ecs_cluster_id
  prometheus_service_registry_arn = module.service_discovery[0].prometheus_service_arn
  prometheus_image                = var.prometheus_image
  prometheus_task_cpu             = var.prometheus_task_cpu
  prometheus_task_memory          = var.prometheus_task_memory
  prometheus_desired_count        = var.prometheus_desired_count
  prometheus_retention_time       = var.prometheus_retention_time
  prometheus_config_s3_key        = "observability/prometheus/prometheus.yml"
  log_retention_days              = var.ecs_log_retention_days
  enable_ecs_exec                 = true

  # Grafana ECS Service
  enable_grafana               = true
  grafana_image                = var.grafana_image
  grafana_task_cpu             = var.grafana_task_cpu
  grafana_task_memory          = var.grafana_task_memory
  grafana_desired_count        = var.grafana_desired_count
  grafana_service_registry_arn = module.service_discovery[0].grafana_service_arn
  grafana_admin_password       = var.grafana_admin_password

  # ALB Integration - disabled for DR (Grafana accessible only via internal service discovery)
  # To enable public access, set grafana_domain_name and enable_grafana_alb_integration = true
  enable_grafana_alb_integration = var.grafana_domain_name != ""
  alb_listener_arn               = var.grafana_domain_name != "" ? (module.compute[0].alb_https_listener_arn != null ? module.compute[0].alb_https_listener_arn : module.compute[0].alb_http_listener_arn) : null
  alb_security_group_id          = var.grafana_domain_name != "" ? module.networking[0].alb_security_group_id : null
  grafana_domain_name            = var.grafana_domain_name

  tags = {
    DRRegion   = "true"
    CostCenter = "Platform Engineering"
  }
}

# ==============================================================================
# Prometheus Configuration for DR
# ==============================================================================

# Render Prometheus configuration from template for DR environment
locals {
  prometheus_config_rendered = var.dr_activated ? templatefile("../../../observability/prometheus/prometheus.yml.tpl", {
    environment           = var.environment
    service_prefix        = "${var.environment}-${var.project_name}"
    platform_name         = var.project_name
    private_dns_zone      = var.private_dns_namespace
    backend_service_name  = module.service_discovery[0].backend_service_name
    frontend_service_name = module.service_discovery[0].frontend_service_name
  }) : ""
}

# Upload rendered Prometheus config to S3 for DR
resource "aws_s3_object" "prometheus_config" {
  count = var.dr_activated ? 1 : 0

  bucket       = module.observability[0].prometheus_config_bucket_id
  key          = "observability/prometheus/prometheus.yml"
  content      = local.prometheus_config_rendered
  content_type = "text/yaml"
  etag         = md5(local.prometheus_config_rendered)

  tags = {
    Name        = "${var.environment}-${var.project_name}-prometheus-config"
    Environment = var.environment
    DRRegion    = "true"
  }
}

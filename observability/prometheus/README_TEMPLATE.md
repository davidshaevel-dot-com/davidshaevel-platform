# Prometheus Configuration Templating

## Overview

The Prometheus configuration supports multi-environment deployments using Terraform's `templatefile()` function.

## Files

- **prometheus.yml.tpl** - Template configuration with variables
- **prometheus.yml** - Pre-rendered configuration for DEV environment (used by Dockerfile for local testing)

## Template Variables

The template (`prometheus.yml.tpl`) uses the following variables:

| Variable | Description | Example Values |
|----------|-------------|----------------|
| `environment` | Target environment name | `dev`, `staging`, `prod` |
| `service_prefix` | Cloud Map service name prefix | `dev-davidshaevel`, `prod-davidshaevel` |

## Usage in Terraform

During ECS task definition creation, Terraform will:

1. Read `prometheus.yml.tpl` as a template
2. Substitute variables based on environment
3. Mount the generated config into the Prometheus container

### Example Terraform Code

The recommended approach is to store the rendered configuration in S3 and make it available to the Prometheus container via an EFS volume mount.

```hcl
# Generate Prometheus config from template
locals {
  prometheus_config = templatefile(
    "${path.module}/../../observability/prometheus/prometheus.yml.tpl",
    {
      environment    = var.environment
      service_prefix = "${var.environment}-davidshaevel"
    }
  )
}

# Store rendered config in S3
resource "aws_s3_object" "prometheus_config" {
  bucket  = var.config_bucket_name
  key     = "${var.environment}/observability/prometheus/prometheus.yml"
  content = local.prometheus_config
  etag    = md5(local.prometheus_config)
}

# ECS task definition with EFS volume mount
resource "aws_ecs_task_definition" "prometheus" {
  family                   = "${var.environment}-prometheus"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  # EFS volume for config and data
  volume {
    name = "prometheus-config"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.prometheus.id
      root_directory = "/config"  # Config files stored here
    }
  }

  volume {
    name = "prometheus-data"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.prometheus.id
      root_directory = "/data"    # TSDB data stored here
    }
  }

  container_definitions = jsonencode([{
    name  = "prometheus"
    image = "${var.ecr_repository_url}:${var.image_tag}"

    # Mount EFS volumes
    mountPoints = [
      {
        sourceVolume  = "prometheus-config"
        containerPath = "/etc/prometheus"
        readOnly      = true
      },
      {
        sourceVolume  = "prometheus-data"
        containerPath = "/prometheus"
        readOnly      = false
      }
    ]

    # ... rest of container config ...
  }])
}
```

**Note:** The configuration file must be synced from S3 to the EFS `/config` directory before the Prometheus task starts. This can be done using:
- **Lambda function** triggered on S3 object creation
- **ECS task** (one-time or scheduled) that runs `aws s3 cp`
- **Init container** in the task definition that syncs before Prometheus starts

See the main Terraform infrastructure code (Phase 3-6) for the complete implementation.

## Environment-Specific Configs

### Development (`dev`)
```yaml
external_labels:
  environment: 'dev'

dns_sd_configs:
  - names: ['dev-davidshaevel-backend.davidshaevel.local']
```

### Production (`prod`)
```yaml
external_labels:
  environment: 'prod'

dns_sd_configs:
  - names: ['prod-davidshaevel-backend.davidshaevel.local']
```

## Local Development

For local testing without Terraform:
1. Use `prometheus.yml` (pre-rendered for DEV)
2. Docker build will copy this file into the image
3. Works out-of-the-box for local development

## Benefits

✅ **Single source of truth** - One template for all environments
✅ **No manual edits** - Terraform generates configs automatically
✅ **Type safety** - Terraform validates template variables
✅ **DRY principle** - Don't repeat configuration across environments
✅ **Easy rollback** - Config changes tracked in Terraform state

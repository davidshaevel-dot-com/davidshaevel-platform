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

# Store config in SSM Parameter Store or S3
resource "aws_ssm_parameter" "prometheus_config" {
  name  = "/${var.environment}/observability/prometheus/config"
  type  = "String"
  value = local.prometheus_config
}

# ECS task definition will mount this config
resource "aws_ecs_task_definition" "prometheus" {
  # ... task definition ...

  container_definitions = jsonencode([{
    # ... container config ...

    # Option 1: Mount from SSM Parameter Store
    secrets = [{
      name      = "PROMETHEUS_CONFIG"
      valueFrom = aws_ssm_parameter.prometheus_config.arn
    }]

    # Option 2: Use S3 + EFS
    # - Store in S3
    # - Sync to EFS on startup
    # - Mount EFS to /etc/prometheus
  }])
}
```

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

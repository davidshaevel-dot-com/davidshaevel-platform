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
| `platform_name` | Platform identifier for external_labels | `davidshaevel`, `myapp` |
| `private_dns_zone` | Private hosted zone name for service discovery | `davidshaevel.local`, `dev.internal`, `prod.internal` |

**Multi-Account Architecture Note:**

In multi-account AWS architectures (where dev, staging, and prod environments run in separate AWS accounts), each account typically has its own private hosted zone for service discovery. The `private_dns_zone` variable provides flexibility to support different organizational patterns:

- **Pattern A:** Same zone name across all accounts (e.g., `davidshaevel.local` in dev, staging, and prod accounts)
- **Pattern B:** Account-specific zone names (e.g., `davidshaevel-dev.local`, `davidshaevel-prod.local`)
- **Pattern C:** Environment-specific zone names (e.g., `dev.internal`, `staging.internal`, `prod.internal`)

All patterns work because Route 53 private hosted zones are scoped to their AWS account and associated VPCs. Services in different accounts cannot conflict even with identical zone names.

## Usage in Terraform

During ECS task definition creation, Terraform will:

1. Read `prometheus.yml.tpl` as a template
2. Substitute variables based on environment
3. Mount the generated config into the Prometheus container

### Required IAM Roles

The ECS task requires two IAM roles:

1. **Execution Role** (`prometheus_execution_role`):
   - Used by the ECS agent to set up the task
   - Permissions: Pull container images from ECR, write logs to CloudWatch
   - Required for all ECS tasks

2. **Task Role** (`prometheus_task_role`):
   - Used by containers running inside the task
   - Permissions: S3 access for config-init container (see IAM Requirements section below)
   - Used at runtime by application code

**Note:** Complete IAM role definitions will be provided in the Phase 3-6 Terraform infrastructure modules. For AWS documentation on ECS IAM roles, see: [ECS Task IAM Roles](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html)

### Example Terraform Code

The recommended approach is to store the rendered configuration in S3 and make it available to the Prometheus container via an EFS volume mount.

**Prerequisites:**
- AWS region data source: `data "aws_region" "current" {}` (provides current region name)

**Security Note:** For production deployments, consider pinning the AWS CLI image to a digest (`@sha256:...`) instead of a tag for true immutability. Get the digest via: `docker manifest inspect public.ecr.aws/aws-cli/aws-cli:2.17.8`

```hcl
# Get current AWS region
data "aws_region" "current" {}

# Generate Prometheus config from template
locals {
  prometheus_config = templatefile(
    "${path.module}/../../observability/prometheus/prometheus.yml.tpl",
    {
      environment      = var.environment
      service_prefix   = "${var.environment}-${var.project_name}"
      platform_name    = var.project_name
      private_dns_zone = var.private_dns_zone  # e.g., "davidshaevel.local" or "dev.internal"
    }
  )

  # Define S3 key path once for DRY principle
  prometheus_config_s3_key = "${var.project_name}/${var.environment}/observability/prometheus/prometheus.yml"
}

# Store rendered config in S3
resource "aws_s3_object" "prometheus_config" {
  bucket  = var.config_bucket_name
  key     = local.prometheus_config_s3_key
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
  execution_role_arn       = aws_iam_role.prometheus_execution_role.arn  # For pulling images, writing logs
  task_role_arn            = aws_iam_role.prometheus_task_role.arn       # For S3 access in init container

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

  container_definitions = jsonencode([
    {
      # Init container: Fetches config from S3 to EFS before Prometheus starts
      name      = "config-init"
      image     = "public.ecr.aws/aws-cli/aws-cli:2.17.8"  # Pin to specific version for stability
      essential = true   # Task should fail and restart if config sync fails
      command = [
        "s3", "cp",
        "--region", "${data.aws_region.current.name}",  # Explicit region for reliability
        "s3://${var.config_bucket_name}/${local.prometheus_config_s3_key}",
        "/etc/prometheus/prometheus.yml"
      ]
      mountPoints = [
        {
          sourceVolume  = "prometheus-config"
          containerPath = "/etc/prometheus"
          readOnly      = false  # Writable for init container
        }
      ]
    },
    {
      name      = "prometheus"
      image     = "${var.ecr_repository_url}:${var.image_tag}"
      essential = true
      dependsOn = [
        {
          containerName = "config-init"
          condition     = "SUCCESS"  # Wait for config sync
        }
      ]

      # Mount EFS volumes
      mountPoints = [
        {
          sourceVolume  = "prometheus-config"
          containerPath = "/etc/prometheus"
          readOnly      = true  # Read-only for main container
        },
        {
          sourceVolume  = "prometheus-data"
          containerPath = "/prometheus"
          readOnly      = false
        }
      ]

      # ... rest of container config ...
    }
  ])
}
```

**Configuration Sync Pattern:**

The example above uses an **init container** to sync the configuration from S3 to EFS before Prometheus starts. This is the recommended approach because:

- ✅ **Self-contained:** No external processes (Lambda, cron) required
- ✅ **Automatic:** Config refreshed on every task restart
- ✅ **Simple:** No custom entrypoint scripts in Prometheus image
- ✅ **Reliable:** Task won't start until config is in place
- ✅ **Fail-fast:** Init container is `essential = true`, so task fails and retries if config sync fails (clear failure signal vs confusing "running but non-functional" state)

**IAM Requirements:**

The ECS task role needs `s3:GetObject` permission:

```hcl
resource "aws_iam_role_policy" "prometheus_s3_config" {
  role   = aws_iam_role.prometheus_task_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject"]
      Resource = "${aws_s3_object.prometheus_config.arn}"
    }]
  })
}
```

**Alternative Approaches:**

- **Lambda function:** Triggered on S3 object changes, syncs to EFS (more complex)
- **ECS task:** One-time or scheduled task runs `aws s3 cp` (requires scheduling)

See the main Terraform infrastructure code (Phase 3-6) for the complete implementation.

## Environment-Specific Configs

### Development (`dev`)
```yaml
external_labels:
  environment: 'dev'
  platform: 'davidshaevel'

# In scrape_configs:
- job_name: 'backend'
  dns_sd_configs:
    - names: ['dev-davidshaevel-backend.davidshaevel.local']
      type: 'SRV'

- job_name: 'frontend'
  dns_sd_configs:
    - names: ['dev-davidshaevel-frontend.davidshaevel.local']
      type: 'SRV'
```

### Production (`prod`)
```yaml
external_labels:
  environment: 'prod'
  platform: 'davidshaevel'

# In scrape_configs:
- job_name: 'backend'
  dns_sd_configs:
    - names: ['prod-davidshaevel-backend.davidshaevel.local']
      type: 'SRV'

- job_name: 'frontend'
  dns_sd_configs:
    - names: ['prod-davidshaevel-frontend.davidshaevel.local']
      type: 'SRV'
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

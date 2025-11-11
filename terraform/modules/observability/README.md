# Observability Module

Terraform module for provisioning observability infrastructure including Prometheus metrics collection and Grafana visualization.

## Overview

This module provisions the infrastructure foundation for a production-ready observability stack:

- **S3 Bucket:** Stores rendered Prometheus configuration files
- **EFS File System:** Provides persistent storage for Prometheus TSDB data
- **EFS Mount Targets:** Multi-AZ availability for high reliability
- **Security Groups:** Controlled NFS access from ECS tasks
- **IAM Policies:** S3 read access for configuration sync

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Observability Stack                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Terraform Render                S3 Bucket                     │
│  (prometheus.yml.tpl)  ───────►  (prometheus-config)           │
│                                        │                        │
│                                        │ S3 CP (init)           │
│                                        ▼                        │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              ECS Task (Prometheus)                       │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │  Init Container:         Main Container:                 │  │
│  │  - Sync S3 → EFS         - Read config from EFS         │  │
│  │  - essential=true        - Write data to EFS            │  │
│  │                          - Scrape metrics               │  │
│  └──────────────────────────────────────────────────────────┘  │
│                         │              │                        │
│                         │              ▼                        │
│                         │     EFS File System                   │
│                         │     - /config (ro)                    │
│                         │     - /data   (rw)                    │
│                         │              │                        │
│                         │              ▼                        │
│                         │     Mount Targets (Multi-AZ)          │
│                         │     - us-east-1a                      │
│                         │     - us-east-1b                      │
│                         │                                       │
│                         ▼                                       │
│                    Service Discovery                            │
│                    (AWS Cloud Map)                              │
│                         │                                       │
│                         ▼                                       │
│                Backend + Frontend Services                      │
│                (Prometheus metrics endpoints)                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Resources Created

### S3 Resources
- **S3 Bucket:** Stores Prometheus configuration files
- **Bucket Versioning:** Tracks config changes (optional)
- **Encryption:** AES256 encryption at rest
- **Public Access Block:** Prevents public access
- **Lifecycle Policy:** Expires old versions after 90 days

### EFS Resources
- **EFS File System:** Persistent storage for Prometheus TSDB data
- **EFS Mount Targets:** One per availability zone (2 for HA)
- **Security Group:** Controls NFS access (port 2049)
- **Lifecycle Policies:** Transition to IA after 30 days

### IAM Resources
- **IAM Policy:** Grants S3 read access for config sync

## Usage

### Basic Example

```hcl
module "observability" {
  source = "../../modules/observability"

  # Environment configuration
  environment  = "dev"
  project_name = "davidshaevel"

  # Networking inputs (from networking module)
  vpc_id                        = module.networking.vpc_id
  private_app_subnet_ids        = module.networking.private_app_subnet_ids
  prometheus_security_group_id  = module.networking.prometheus_security_group_id

  # Optional: Customize EFS configuration
  prometheus_efs_performance_mode = "generalPurpose"
  prometheus_efs_throughput_mode  = "bursting"
  prometheus_data_retention_days  = 15
  enable_efs_encryption          = true

  # Optional: Customize S3 configuration
  enable_config_bucket_versioning = true
  config_bucket_lifecycle_days    = 90

  tags = {
    CostCenter = "Platform Engineering"
    Owner      = "DevOps Team"
  }
}
```

### Integration with Compute Module

The observability module outputs are used by the compute module to configure Prometheus ECS tasks:

```hcl
module "compute" {
  source = "../../modules/compute"

  # ... other inputs ...

  # Observability integration
  prometheus_config_bucket_id        = module.observability.prometheus_config_bucket_id
  prometheus_efs_id                  = module.observability.prometheus_efs_id
  prometheus_s3_config_policy_arn    = module.observability.prometheus_s3_config_policy_arn
}
```

## Configuration Sync Pattern

The module supports an **init container pattern** for configuration management:

1. **Terraform** renders `prometheus.yml.tpl` → uploads to S3
2. **Init container** syncs S3 → EFS on task startup (essential=true)
3. **Prometheus container** reads config from EFS, writes data to EFS

**Benefits:**
- ✅ Self-contained (no Lambda/cron required)
- ✅ Automatic refresh on task restart
- ✅ Fail-fast behavior (task won't start without config)
- ✅ Simple (no custom entrypoint scripts)

## EFS Configuration

### Performance Modes

- **generalPurpose** (default): Up to 7,000 IOPS, ideal for Prometheus
- **maxIO**: Higher aggregate throughput, higher latency per operation

### Throughput Modes

- **bursting** (default): Throughput scales with storage size (50 MB/s per TB)
- **provisioned**: Fixed throughput regardless of storage size

### Cost Optimization

- **Lifecycle Management:** Automatically transitions infrequently accessed data to IA storage class after 30 days
- **Data Retention:** Prometheus configured for 15-day retention (configurable)
- **No EFS Backups:** Metrics data is ephemeral, backups not required

## Security

### S3 Bucket Security
- All public access blocked
- Encryption at rest with AES256
- Versioning enabled for audit trail
- IAM policy restricts access to Prometheus task role only

### EFS Security
- Encryption at rest with AWS-managed KMS key
- Security group limits access to Prometheus ECS tasks
- NFS (port 2049) only from authorized security groups
- Multi-AZ for high availability

### IAM Least Privilege
- Task role has read-only access to config bucket
- No write permissions granted
- Policy scoped to specific S3 bucket only

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| environment | Environment name (dev, staging, prod) | string | - | yes |
| project_name | Project name for resource naming | string | - | yes |
| vpc_id | VPC ID for EFS mount targets | string | - | yes |
| private_app_subnet_ids | Private subnet IDs for EFS mount targets | list(string) | - | yes |
| prometheus_security_group_id | Security group ID for Prometheus ECS tasks | string | - | yes |
| enable_prometheus_efs | Enable EFS file system | bool | true | no |
| prometheus_efs_performance_mode | EFS performance mode | string | "generalPurpose" | no |
| prometheus_efs_throughput_mode | EFS throughput mode | string | "bursting" | no |
| prometheus_data_retention_days | Data retention in days | number | 15 | no |
| enable_efs_encryption | Enable EFS encryption | bool | true | no |
| enable_config_bucket_versioning | Enable S3 versioning | bool | true | no |
| config_bucket_lifecycle_days | Days before old versions expire | number | 90 | no |
| tags | Additional resource tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| prometheus_config_bucket_id | S3 bucket ID for Prometheus config |
| prometheus_config_bucket_arn | S3 bucket ARN |
| prometheus_efs_id | EFS file system ID |
| prometheus_efs_arn | EFS file system ARN |
| prometheus_efs_dns_name | EFS DNS name for mounting |
| prometheus_efs_mount_target_ids | List of EFS mount target IDs |
| efs_security_group_id | EFS security group ID |
| prometheus_s3_config_policy_arn | IAM policy ARN for S3 access |
| prometheus_config_s3_key | Suggested S3 key path for config |
| prometheus_efs_mount_path | Suggested container mount path |

## Cost Estimates

**Development Environment (Monthly):**
- S3 Storage (1 MB config): < $0.01
- EFS Storage (5 GB metrics): ~$1.50
- EFS Requests (moderate): ~$0.50
- Data Transfer (minimal): ~$0.25
- **Total:** ~$2.25/month

**Production Environment (Monthly):**
- S3 Storage (1 MB config): < $0.01
- EFS Storage (20 GB metrics): ~$6.00
- EFS Requests (high): ~$2.00
- Data Transfer (moderate): ~$1.00
- **Total:** ~$9.00/month

## Related Resources

- [Prometheus Docker Configuration](../../../observability/prometheus/)
- [Prometheus Templating Documentation](../../../observability/prometheus/README_TEMPLATE.md)
- [TT-25 Phase 1-2 Documentation](../../../docs/2025-11-08_tt25_issue_update.md)
- [AWS EFS Best Practices](https://docs.aws.amazon.com/efs/latest/ug/best-practices.html)
- [AWS EFS Performance](https://docs.aws.amazon.com/efs/latest/ug/performance.html)

## Next Steps (TT-25 Phase 4-6)

After deploying this module:

1. **Phase 4:** Configure AWS Cloud Map service discovery
2. **Phase 5:** Deploy Prometheus ECS service with init container
3. **Phase 6:** Deploy Grafana ECS service with ALB integration
4. **Phase 7-8:** Enhance metrics endpoints in backend/frontend
5. **Phase 9:** Create Grafana dashboards
6. **Phase 10:** Verify end-to-end observability

## Authors

David Shaevel - Platform Engineering Portfolio Project

## License

Private project - Not licensed for public use

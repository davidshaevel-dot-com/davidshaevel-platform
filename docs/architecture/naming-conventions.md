# Resource Naming Conventions

**Project:** DavidShaevel.com Platform  
**Date:** October 23, 2025  
**Author:** David Shaevel  
**Version:** 1.0

## Overview

This document defines the naming conventions for all AWS resources in the DavidShaevel.com platform. Consistent naming improves resource identification, management, and cost tracking.

## General Naming Pattern

**Format:** `{environment}-{project}-{resource-type}-{purpose}-{identifier}`

**Components:**
- **environment:** `dev` or `prod`
- **project:** `davidshaevel` (short form)
- **resource-type:** AWS service abbreviation
- **purpose:** Functional description
- **identifier:** Sequential number, AZ letter, or unique identifier

## Environment Prefixes

| Environment | Prefix | Description |
|-------------|--------|-------------|
| Development | `dev` | Development and testing environment |
| Production | `prod` | Production environment |

## Resource Type Abbreviations

### Networking

| Resource | Abbreviation | Example |
|----------|-------------|---------|
| VPC | `vpc` | `dev-davidshaevel-vpc` |
| Subnet | `subnet` | `dev-davidshaevel-subnet-public-1a` |
| Internet Gateway | `igw` | `dev-davidshaevel-igw` |
| NAT Gateway | `nat` | `dev-davidshaevel-nat-1a` |
| Route Table | `rt` | `dev-davidshaevel-rt-public` |
| Network ACL | `nacl` | `dev-davidshaevel-nacl-public` |
| Security Group | `sg` | `dev-davidshaevel-sg-alb` |
| VPC Endpoint | `vpce` | `dev-davidshaevel-vpce-s3` |
| Elastic IP | `eip` | `dev-davidshaevel-eip-nat-1a` |

### Compute

| Resource | Abbreviation | Example |
|----------|-------------|---------|
| ECS Cluster | `ecs-cluster` | `dev-davidshaevel-ecs-cluster` |
| ECS Service | `ecs-service` | `dev-davidshaevel-ecs-service-frontend` |
| ECS Task Definition | `ecs-task` | `dev-davidshaevel-ecs-task-backend` |
| EC2 Instance | `ec2` | `dev-davidshaevel-ec2-bastion` |
| Launch Template | `lt` | `dev-davidshaevel-lt-ecs` |
| Auto Scaling Group | `asg` | `dev-davidshaevel-asg-ecs` |

### Load Balancing

| Resource | Abbreviation | Example |
|----------|-------------|---------|
| Application Load Balancer | `alb` | `dev-davidshaevel-alb` |
| Target Group | `tg` | `dev-davidshaevel-tg-frontend` |
| Listener | `listener` | `dev-davidshaevel-listener-https` |

### Database

| Resource | Abbreviation | Example |
|----------|-------------|---------|
| RDS Instance | `rds` | `dev-davidshaevel-rds-postgres` |
| DB Subnet Group | `db-subnet-group` | `dev-davidshaevel-db-subnet-group` |
| DB Parameter Group | `db-param-group` | `dev-davidshaevel-db-param-group` |
| DB Option Group | `db-option-group` | `dev-davidshaevel-db-option-group` |

### Storage

| Resource | Abbreviation | Example |
|----------|-------------|---------|
| S3 Bucket | `s3` | `dev-davidshaevel-s3-static-assets` |
| ECR Repository | `ecr` | `davidshaevel-ecr-frontend` |

### CDN & DNS

| Resource | Abbreviation | Example |
|----------|-------------|---------|
| CloudFront Distribution | `cf` | `dev-davidshaevel-cf` |
| Route53 Hosted Zone | `r53-zone` | `davidshaevel-r53-zone` |
| Route53 Record | `r53-record` | `davidshaevel-r53-record-www` |

### Security & Secrets

| Resource | Abbreviation | Example |
|----------|-------------|---------|
| IAM Role | `iam-role` | `dev-davidshaevel-iam-role-ecs-task` |
| IAM Policy | `iam-policy` | `dev-davidshaevel-iam-policy-s3-read` |
| Secrets Manager Secret | `secret` | `dev-davidshaevel-secret-db-password` |
| KMS Key | `kms` | `dev-davidshaevel-kms-rds` |
| ACM Certificate | `acm` | `davidshaevel-acm-wildcard` |

### Monitoring & Logging

| Resource | Abbreviation | Example |
|----------|-------------|---------|
| CloudWatch Log Group | `cw-logs` | `dev-davidshaevel-cw-logs-ecs-frontend` |
| CloudWatch Alarm | `cw-alarm` | `dev-davidshaevel-cw-alarm-cpu-high` |
| CloudWatch Dashboard | `cw-dashboard` | `dev-davidshaevel-cw-dashboard-main` |
| SNS Topic | `sns` | `dev-davidshaevel-sns-alerts` |

## Detailed Naming Examples

### VPC Resources

```
dev-davidshaevel-vpc
dev-davidshaevel-igw
dev-davidshaevel-subnet-public-1a
dev-davidshaevel-subnet-public-1b
dev-davidshaevel-subnet-private-app-1a
dev-davidshaevel-subnet-private-app-1b
dev-davidshaevel-subnet-private-db-1a
dev-davidshaevel-subnet-private-db-1b
dev-davidshaevel-nat-1a
dev-davidshaevel-nat-1b
dev-davidshaevel-eip-nat-1a
dev-davidshaevel-eip-nat-1b
dev-davidshaevel-rt-public
dev-davidshaevel-rt-private-app-1a
dev-davidshaevel-rt-private-app-1b
dev-davidshaevel-rt-private-db
```

### Security Groups

```
dev-davidshaevel-sg-alb
dev-davidshaevel-sg-frontend
dev-davidshaevel-sg-backend
dev-davidshaevel-sg-db
dev-davidshaevel-sg-ecs-instance
```

### ECS Resources

```
dev-davidshaevel-ecs-cluster
dev-davidshaevel-ecs-service-frontend
dev-davidshaevel-ecs-service-backend
dev-davidshaevel-ecs-task-frontend
dev-davidshaevel-ecs-task-backend
dev-davidshaevel-asg-ecs
dev-davidshaevel-lt-ecs
```

### Load Balancer Resources

```
dev-davidshaevel-alb
dev-davidshaevel-tg-frontend
dev-davidshaevel-tg-backend
dev-davidshaevel-listener-http
dev-davidshaevel-listener-https
```

### Database Resources

```
dev-davidshaevel-rds-postgres
dev-davidshaevel-db-subnet-group
dev-davidshaevel-db-param-group-postgres14
dev-davidshaevel-sg-db
dev-davidshaevel-secret-db-credentials
```

### Storage Resources

```
dev-davidshaevel-s3-static-assets
dev-davidshaevel-s3-terraform-state
dev-davidshaevel-s3-logs
davidshaevel-ecr-frontend
davidshaevel-ecr-backend
```

### CloudFront & DNS

```
dev-davidshaevel-cf-main
prod-davidshaevel-cf-main
davidshaevel-r53-zone-main
davidshaevel-acm-wildcard
```

### IAM Resources

```
dev-davidshaevel-iam-role-ecs-task-execution
dev-davidshaevel-iam-role-ecs-task-frontend
dev-davidshaevel-iam-role-ecs-task-backend
dev-davidshaevel-iam-role-ecs-instance
dev-davidshaevel-iam-policy-s3-static-read
dev-davidshaevel-iam-policy-ecr-pull
```

### Monitoring Resources

```
dev-davidshaevel-cw-logs-vpc-flow
dev-davidshaevel-cw-logs-ecs-frontend
dev-davidshaevel-cw-logs-ecs-backend
dev-davidshaevel-cw-logs-alb
dev-davidshaevel-cw-alarm-alb-5xx
dev-davidshaevel-cw-alarm-rds-cpu
dev-davidshaevel-cw-alarm-ecs-memory
dev-davidshaevel-cw-dashboard-platform
dev-davidshaevel-sns-alerts
```

## Docker Image Naming

**Format:** `{account-id}.dkr.ecr.{region}.amazonaws.com/{repository}:{tag}`

**Examples:**
```
123456789012.dkr.ecr.us-east-1.amazonaws.com/davidshaevel-ecr-frontend:latest
123456789012.dkr.ecr.us-east-1.amazonaws.com/davidshaevel-ecr-frontend:v1.0.0
123456789012.dkr.ecr.us-east-1.amazonaws.com/davidshaevel-ecr-frontend:dev-abc123
123456789012.dkr.ecr.us-east-1.amazonaws.com/davidshaevel-ecr-backend:latest
123456789012.dkr.ecr.us-east-1.amazonaws.com/davidshaevel-ecr-backend:prod-v1.2.3
```

**Tagging Strategy:**
- `latest` - Most recent build (dev environment)
- `v{major}.{minor}.{patch}` - Semantic version (prod releases)
- `{env}-{git-sha}` - Environment-specific Git commit
- `{env}-{branch}-{timestamp}` - Feature branch builds

## Tag Standards

All AWS resources should include the following tags:

### Required Tags

| Tag Key | Description | Example |
|---------|-------------|---------|
| `Environment` | Environment name | `development`, `production` |
| `Project` | Project name | `DavidShaevel.com Platform` |
| `ManagedBy` | Management method | `Terraform` |
| `Owner` | Technical owner | `David Shaevel` |
| `CostCenter` | Cost tracking | `Platform Engineering` |

### Optional Tags

| Tag Key | Description | Example |
|---------|-------------|---------|
| `Application` | Application component | `Frontend`, `Backend`, `Database` |
| `Version` | Resource version | `v1.0.0` |
| `BackupPolicy` | Backup requirements | `Daily`, `Weekly`, `None` |
| `Compliance` | Compliance requirements | `HIPAA`, `PCI`, `None` |

### Terraform Tag Example

```hcl
locals {
  common_tags = {
    Environment  = var.environment
    Project      = "DavidShaevel.com Platform"
    ManagedBy    = "Terraform"
    Owner        = "David Shaevel"
    CostCenter   = "Platform Engineering"
  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  tags = merge(local.common_tags, {
    Name        = "${var.environment}-davidshaevel-vpc"
    Application = "Infrastructure"
  })
}
```

## S3 Bucket Naming

S3 buckets must be globally unique and follow additional constraints.

**Format:** `{account-id}-{environment}-davidshaevel-{purpose}`

**Examples:**
```
123456789012-dev-davidshaevel-static-assets
123456789012-dev-davidshaevel-terraform-state
123456789012-dev-davidshaevel-logs
123456789012-prod-davidshaevel-static-assets
123456789012-prod-davidshaevel-backups
```

**Rules:**
- Lowercase only
- No underscores
- Use hyphens for separation
- 3-63 characters
- Prefix with account ID for global uniqueness

## CloudWatch Log Group Naming

**Format:** `/aws/{service}/{environment}-davidshaevel-{component}`

**Examples:**
```
/aws/vpc/dev-davidshaevel-flow-logs
/aws/ecs/dev-davidshaevel-frontend
/aws/ecs/dev-davidshaevel-backend
/aws/rds/dev-davidshaevel-postgres
/aws/lambda/dev-davidshaevel-migration
/aws/elasticloadbalancing/dev-davidshaevel-alb
```

## Secrets Manager Naming

**Format:** `{environment}/davidshaevel/{component}/{secret-name}`

**Examples:**
```
dev/davidshaevel/database/master-password
dev/davidshaevel/database/connection-string
dev/davidshaevel/api/jwt-secret
dev/davidshaevel/github/deploy-token
prod/davidshaevel/database/master-password
```

## GitHub Actions Secrets

**Format:** `{ENVIRONMENT}_{SERVICE}_{PURPOSE}`

**Examples:**
```
DEV_AWS_ACCESS_KEY_ID
DEV_AWS_SECRET_ACCESS_KEY
DEV_ECR_REPOSITORY_FRONTEND
DEV_ECR_REPOSITORY_BACKEND
PROD_AWS_ACCESS_KEY_ID
PROD_DATABASE_URL
```

## Naming Conventions Summary Table

| Category | Pattern | Example |
|----------|---------|---------|
| VPC Resources | `{env}-davidshaevel-{type}-{purpose}` | `dev-davidshaevel-subnet-public-1a` |
| Compute | `{env}-davidshaevel-{type}-{component}` | `dev-davidshaevel-ecs-service-frontend` |
| Security Groups | `{env}-davidshaevel-sg-{tier}` | `dev-davidshaevel-sg-backend` |
| S3 Buckets | `{account}-{env}-davidshaevel-{purpose}` | `123456789012-dev-davidshaevel-static` |
| ECR Repos | `davidshaevel-ecr-{component}` | `davidshaevel-ecr-frontend` |
| Secrets | `{env}/davidshaevel/{component}/{name}` | `dev/davidshaevel/database/password` |
| Log Groups | `/aws/{service}/{env}-davidshaevel-{component}` | `/aws/ecs/dev-davidshaevel-frontend` |

## Best Practices

1. **Be Consistent:** Always follow the established pattern
2. **Be Descriptive:** Names should clearly indicate purpose
3. **Use Lowercase:** Avoid uppercase in resource names (except tags)
4. **Use Hyphens:** Prefer hyphens over underscores for AWS resources
5. **Include Environment:** Always prefix with environment for clarity
6. **Tag Everything:** Apply consistent tags to all resources
7. **Document Changes:** Update this document when adding new patterns
8. **Automate Validation:** Use Terraform validation to enforce naming

## Terraform Variable Example

```hcl
variable "environment" {
  description = "Environment name"
  type        = string
  
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be dev or prod."
  }
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "davidshaevel"
}

locals {
  name_prefix = "${var.environment}-${var.project}"
}
```

---

**Last Updated:** October 23, 2025  
**Next Review:** After initial deployment


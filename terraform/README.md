# Terraform Infrastructure

Infrastructure as Code for the DavidShaevel.com Platform using Terraform.

## Overview

This directory contains the Terraform configuration for deploying and managing the AWS infrastructure for the project. The infrastructure is organized using a modular approach with separate environments for development and production.

## Prerequisites

Before using these Terraform configurations, ensure you have:

- ✅ **Terraform** >= 1.13.4 installed (latest stable as of Oct 2025)
- ✅ **AWS CLI** v2.x configured
- ✅ **AWS credentials** configured (via SSO or access keys)
- ✅ **Environment variables** set in `.envrc` (see `.envrc.example`)
- ✅ **Backend resources** created (S3 bucket and DynamoDB table)

See `docs/terraform-local-setup.md` for complete setup instructions.

## Directory Structure

```
terraform/
├── versions.tf          # Terraform and provider version constraints
├── provider.tf          # AWS provider configuration
├── backend.tf           # Remote state backend configuration
├── variables.tf         # Root-level variable definitions
├── outputs.tf           # Root-level outputs
├── README.md            # This file
│
├── modules/             # Reusable Terraform modules (to be created)
│   ├── networking/      # VPC, subnets, security groups
│   ├── database/        # RDS PostgreSQL
│   ├── compute/         # ECS Fargate
│   └── cdn/             # CloudFront, Route53
│
├── environments/        # Environment-specific configurations (to be created)
│   ├── dev/            # Development environment
│   └── prod/           # Production environment
│
└── scripts/            # Helper scripts
    └── setup-backend.sh # Backend setup automation
```

## Current Status

**Phase:** Networking Complete (Steps 1-6 of 10)

**Completed:**
- ✅ **Step 1-3:** Terraform foundation and environment structure (TT-16)
- ✅ **Step 4:** VPC and Internet Gateway (TT-17)
- ✅ **Step 5:** Subnets, NAT Gateways, and routing (TT-17)
- ✅ **Step 6:** Security groups for three-tier architecture (TT-17)
- ✅ Remote state backend activated (S3 + DynamoDB)
- ✅ Development environment fully operational
- ✅ ~45 AWS resources deployed

**Next Steps:**
- 📋 **Step 7:** Implement database module (RDS PostgreSQL) - TT-21
- 📋 **Step 8-9:** Implement compute module (ECS Fargate) - TT-22
- 📋 **Step 10:** Implement CDN module (CloudFront + Route53) - TT-24

## Quick Start

### Initialize Terraform

```bash
# Source environment variables
source .envrc

# Initialize Terraform (downloads providers)
cd terraform
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt -recursive
```

### Working with Variables

Variables are defined in `variables.tf` and can be set via:

1. **Environment Variables** (recommended):
   ```bash
   export TF_VAR_project_name="myproject"
   export TF_VAR_aws_account_id="123456789012"
   ```

2. **terraform.tfvars file** (not committed):
   ```hcl
   project_name   = "myproject"
   environment    = "dev"
   aws_region     = "us-east-1"
   aws_account_id = "123456789012"
   domain_name    = "example.com"
   ```

3. **Command-line flags**:
   ```bash
   terraform plan -var="environment=dev"
   ```

## Backend Configuration

Terraform state is stored remotely in AWS S3 with DynamoDB locking.

**Note:** Backend configuration in `backend.tf` is currently commented out for initial testing. Uncomment when ready to use remote state.

**Backend Resources:**
- **S3 Bucket:** `<account-id>-terraform-state-<project-name>`
- **DynamoDB Table:** `terraform-state-lock-<project-name>`

Backend values are provided during initialization:
```bash
terraform init \
  -backend-config="bucket=123456789012-terraform-state-myproject" \
  -backend-config="key=dev/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=terraform-state-lock-myproject" \
  -backend-config="encrypt=true"
```

## Helper Scripts

The `terraform/scripts/` directory contains automation scripts for common tasks:

### Validate All Environments

Validates Terraform configurations across all environments:

```bash
./terraform/scripts/validate-all.sh
```

Features:
- Validates dev and prod environments
- Auto-initializes if needed
- Color-coded output
- Exit code 0 on success, 1 on failure

### Cost Estimation

Runs terraform plan and provides cost estimation guidance:

```bash
# Estimate all environments
./terraform/scripts/cost-estimate.sh

# Estimate specific environment
./terraform/scripts/cost-estimate.sh dev
./terraform/scripts/cost-estimate.sh prod
```

Features:
- Generates plan for specified environment(s)
- Shows resource changes
- Provides links to cost estimation tools
- Handles missing environment variables

### Backend Setup

Creates S3 bucket and DynamoDB table for Terraform state:

```bash
./terraform/scripts/setup-backend.sh
```

**Note:** This script was already run during initial setup. Only run again if setting up a new backend.

## Common Commands

```bash
# Format all Terraform files
terraform fmt -recursive

# Validate configuration
terraform validate

# Initialize and configure backend
terraform init

# Plan changes (dry run)
terraform plan

# Apply changes
terraform apply

# Show current state
terraform show

# List resources in state
terraform state list

# View outputs
terraform output

# Destroy resources (careful!)
terraform destroy
```

## Resource Naming Convention

All resources follow this naming pattern:
```
{environment}-{project_name}-{resource_type}-{descriptor}
```

Examples:
- `dev-myproject-vpc`
- `dev-myproject-subnet-public-1a`
- `prod-myproject-rds-postgres`

This is enforced through the `resource_prefix` output: `${var.environment}-${var.project_name}`

## Tags

All resources are automatically tagged with:
- `Project`: Project name from `var.project_name`
- `Environment`: Environment from `var.environment`
- `ManagedBy`: `Terraform`
- `Repository`: `davidshaevel-platform`

Additional tags can be added via the `tags` variable.

## Security Best Practices

1. **Never commit sensitive values:**
   - AWS account IDs
   - Secrets or passwords
   - terraform.tfvars files

2. **Use environment variables:**
   - Store sensitive values in `.envrc` (gitignored)
   - Reference via `TF_VAR_*` prefix

3. **State file security:**
   - State is encrypted at rest in S3
   - State locking prevents concurrent modifications
   - Backend access is controlled via IAM

4. **Least privilege:**
   - Use IAM roles with minimal permissions
   - Avoid long-lived access keys
   - Prefer AWS SSO for authentication

## Troubleshooting

### Backend initialization failed

```bash
# Remove cached backend config
rm -rf .terraform

# Re-initialize
terraform init -reconfigure
```

### State is locked

```bash
# View lock information
aws dynamodb scan --table-name terraform-state-lock-myproject

# Force unlock (use carefully!)
terraform force-unlock <lock-id>
```

### Provider version conflicts

```bash
# Upgrade providers to match version constraints
terraform init -upgrade
```

## Documentation

For more detailed information, see:
- **Local Setup Guide:** `docs/terraform-local-setup.md`
- **Implementation Plan:** `docs/terraform-implementation-plan.md`
- **Backend Setup Log:** `docs/backend-setup-log.md`
- **Architecture Docs:** `docs/architecture/`

## Support

For issues or questions:
- Check documentation in `docs/`
- Review Linear issue TT-16
- See GitHub pull requests for changes

---

**Last Updated:** 2025-10-25
**Terraform Version:** >= 1.13.4 (latest stable)
**AWS Provider Version:** ~> 6.18 (v6.18.0, released Oct 23, 2025)
**Implementation Status:** Steps 1-6 Complete (Foundation + Networking)

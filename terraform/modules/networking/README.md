# Networking Module

**Version:** 2.0 (Steps 4-5 - Complete VPC Infrastructure)
**Status:** Full VPC networking with subnets, NAT Gateways, and routing implemented
**Next:** Step 6 will add Security Groups

## Overview

This module creates the complete networking infrastructure for the DavidShaevel.com platform. It implements a production-ready, highly available VPC with multi-AZ architecture.

### Current Implementation (Steps 4-5)

**Step 4 - VPC Foundation:**
- ✅ VPC with DNS support (10.0.0.0/16)
- ✅ Internet Gateway for public internet access
- ✅ Resource naming following conventions
- ✅ Comprehensive tagging

**Step 5 - Subnets and Routing:**
- ✅ Public subnets (2 AZs: us-east-1a, us-east-1b)
- ✅ Private application subnets (2 AZs)
- ✅ Private database subnets (2 AZs)
- ✅ NAT Gateways with full HA configuration (2 NAT GWs)
- ✅ Route tables and associations
- ✅ VPC Flow Logs to CloudWatch

### Future Enhancements

- ⏳ Security Groups (Step 6)
- ⏳ VPC Endpoints for S3 and ECR
- ⏳ Network ACLs (NACLs)

## Architecture

```
┌────────────────────────────────────────┐
│            Internet                    │
└──────────────┬─────────────────────────┘
               │
      ┌────────▼────────┐
      │ Internet Gateway│
      └────────┬────────┘
               │
    ┌──────────▼──────────┐
    │  VPC: 10.0.0.0/16   │
    │                     │
    │  (Step 5: Subnets)  │
    │  (Step 5: NAT GWs)  │
    │  (Step 5: Routes)   │
    └─────────────────────┘
```

## Usage

### Basic Usage (Step 4)

```hcl
module "networking" {
  source = "../../modules/networking"

  environment  = "dev"
  project_name = "davidshaevel"
  vpc_cidr     = "10.0.0.0/16"

  common_tags = {
    Environment = "dev"
    Project     = "DavidShaevel.com Platform"
    ManagedBy   = "Terraform"
    Owner       = "David Shaevel"
    CostCenter  = "Platform Engineering"
  }
}
```

### Full Configuration (Ready for Step 5)

```hcl
module "networking" {
  source = "../../modules/networking"

  # Required
  environment  = "dev"
  project_name = "davidshaevel"
  vpc_cidr     = "10.0.0.0/16"

  # Regional
  aws_region         = "us-east-1"
  availability_zones = ["us-east-1a", "us-east-1b"]

  # Subnets (Step 5)
  public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24"]
  private_app_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
  private_db_subnet_cidrs  = ["10.0.21.0/24", "10.0.22.0/24"]

  # NAT Gateway (Step 5)
  enable_nat_gateway  = true
  single_nat_gateway  = false  # Use 2 NAT Gateways for HA

  # VPC Flow Logs (Step 5)
  enable_flow_logs          = true
  flow_logs_retention_days  = 7

  # Tags
  common_tags = {
    Environment = "dev"
    Project     = "DavidShaevel.com Platform"
    ManagedBy   = "Terraform"
    Owner       = "David Shaevel"
    CostCenter  = "Platform Engineering"
  }
}
```

## Inputs

### Required Variables

| Name | Description | Type | Example |
|------|-------------|------|---------|
| `environment` | Environment name (dev or prod) | `string` | `"dev"` |
| `project_name` | Project name for resource naming | `string` | `"davidshaevel"` |
| `vpc_cidr` | CIDR block for the VPC | `string` | `"10.0.0.0/16"` |

### Optional Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `common_tags` | Common tags to apply to all resources | `map(string)` | `{}` |
| `aws_region` | AWS region for resources | `string` | `"us-east-1"` |
| `availability_zones` | List of AZs for multi-AZ deployment | `list(string)` | `["us-east-1a", "us-east-1b"]` |
| `public_subnet_cidrs` | CIDR blocks for public subnets | `list(string)` | `["10.0.1.0/24", "10.0.2.0/24"]` |
| `private_app_subnet_cidrs` | CIDR blocks for private app subnets | `list(string)` | `["10.0.11.0/24", "10.0.12.0/24"]` |
| `private_db_subnet_cidrs` | CIDR blocks for private DB subnets | `list(string)` | `["10.0.21.0/24", "10.0.22.0/24"]` |
| `enable_nat_gateway` | Enable NAT Gateway | `bool` | `false` |
| `single_nat_gateway` | Use single NAT Gateway (cost optimization) | `bool` | `false` |
| `enable_flow_logs` | Enable VPC Flow Logs | `bool` | `false` |
| `flow_logs_retention_days` | Flow logs retention period | `number` | `7` |

## Outputs

### VPC Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | ID of the VPC |
| `vpc_cidr` | CIDR block of the VPC |
| `vpc_arn` | ARN of the VPC |

### Internet Gateway Outputs

| Name | Description |
|------|-------------|
| `internet_gateway_id` | ID of the Internet Gateway |
| `internet_gateway_arn` | ARN of the Internet Gateway |

### Subnet Outputs

| Name | Description |
|------|-------------|
| `public_subnet_ids` | List of public subnet IDs |
| `public_subnet_cidrs` | List of public subnet CIDR blocks |
| `private_app_subnet_ids` | List of private application subnet IDs |
| `private_app_subnet_cidrs` | List of private application subnet CIDR blocks |
| `private_db_subnet_ids` | List of private database subnet IDs |
| `private_db_subnet_cidrs` | List of private database subnet CIDR blocks |

### NAT Gateway Outputs

| Name | Description |
|------|-------------|
| `nat_gateway_ids` | List of NAT Gateway IDs |
| `nat_gateway_public_ips` | List of NAT Gateway public IP addresses |

### Route Table Outputs

| Name | Description |
|------|-------------|
| `public_route_table_id` | ID of the public route table |
| `private_route_table_ids` | List of private route table IDs |

### VPC Flow Logs Outputs

| Name | Description |
|------|-------------|
| `flow_logs_log_group_name` | CloudWatch Log Group name for VPC Flow Logs |
| `flow_logs_log_group_arn` | CloudWatch Log Group ARN for VPC Flow Logs |

## Resources Created

### Complete Implementation (Steps 4-5)

**Core Networking:**
- 1 x VPC
- 1 x Internet Gateway
- 6 x Subnets (2 public, 2 private app, 2 private DB)
- 2 x Elastic IPs (for NAT Gateways)
- 2 x NAT Gateways (HA configuration)

**Routing:**
- 1 x Public Route Table
- 2 x Private Route Tables (one per AZ)
- 1 x Public Internet Route
- 2 x Private NAT Gateway Routes
- 2 x Public Subnet Associations
- 2 x Private App Subnet Associations
- 2 x Private DB Subnet Associations

**Monitoring:**
- 1 x CloudWatch Log Group (VPC Flow Logs)
- 1 x IAM Role (VPC Flow Logs)
- 1 x IAM Role Policy (VPC Flow Logs)
- 1 x VPC Flow Log

**Total:** ~26 resources
**Monthly Cost:** ~$68.50 (primarily NAT Gateways)

## Cost Considerations

### Development Environment

| Resource | Quantity | Monthly Cost |
|----------|----------|--------------|
| VPC | 1 | $0 |
| Internet Gateway | 1 | $0 |
| NAT Gateways | 2 | ~$64 |
| NAT Data Transfer | ~100GB | ~$4.50 |

**Step 4 Total:** $0/month  
**Step 5 Total:** ~$68.50/month

### Cost Optimization Options

1. **Single NAT Gateway:** Set `single_nat_gateway = true` to save ~$32/month
   - Trade-off: Reduced availability, cross-AZ data transfer costs
   - Recommendation: Not recommended; defeats multi-AZ purpose

2. **VPC Endpoints:** Add S3, ECR endpoints to save ~$5-10/month on data transfer
   - Will be implemented in future enhancement

## Naming Conventions

Resources follow the pattern: `{environment}-{project}-{resource-type}-{purpose}-{identifier}`

**Examples:**
```
dev-davidshaevel-vpc
dev-davidshaevel-igw
dev-davidshaevel-subnet-public-1a
dev-davidshaevel-subnet-private-app-1a
dev-davidshaevel-nat-1a
dev-davidshaevel-rt-public
```

See `docs/architecture/naming-conventions.md` for complete details.

## High Availability

This module implements multi-AZ high availability:

- ✅ VPC spans multiple availability zones
- ✅ Subnets distributed across 2 AZs (us-east-1a, us-east-1b)
- ✅ NAT Gateway in each AZ for redundancy
- ✅ Independent routing per AZ (AZ-specific route tables)

## Security

- ✅ DNS resolution enabled for internal service discovery
- ✅ DNS hostnames enabled for EC2/ECS instances
- ✅ Network isolation with public/private subnet segregation
- ✅ VPC Flow Logs to CloudWatch for network monitoring
- ✅ IAM role with least privilege for Flow Logs

## Validation

Variables include validation rules to ensure:

- Environment is 'dev' or 'prod'
- Project name uses valid characters (lowercase, numbers, hyphens)
- VPC CIDR is a valid IPv4 CIDR block
- At least 2 availability zones for HA
- Flow logs retention is a valid CloudWatch period

## Example Output

```bash
$ terraform apply

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

Outputs:

internet_gateway_arn = "arn:aws:ec2:us-east-1:123456789012:internet-gateway/igw-abc123"
internet_gateway_id = "igw-abc123"
vpc_arn = "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-def456"
vpc_cidr = "10.0.0.0/16"
vpc_id = "vpc-def456"
```

## Testing

### Validation

```bash
terraform validate
```

### Planning

```bash
terraform plan
```

### Verification

After applying, verify resources in AWS Console:
- VPC exists with correct CIDR (10.0.0.0/16)
- DNS hostnames and DNS resolution are enabled
- Internet Gateway is attached to VPC
- Tags are applied correctly

## Next Steps

**Step 6 - Security Groups:**
1. Create security group for load balancers
2. Create security group for application tier
3. Create security group for database tier
4. Implement least-privilege ingress/egress rules

## References

- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Project Architecture](../../../docs/architecture/network.md)
- [Naming Conventions](../../../docs/architecture/naming-conventions.md)

---

**Last Updated:** October 25, 2025
**Implementation Status:** Steps 4-5 Complete
**Next Phase:** Step 6 - Security Groups


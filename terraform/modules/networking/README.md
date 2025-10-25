# Networking Module

**Version:** 1.0 (Step 4 - VPC Foundation)  
**Status:** Foundational VPC and Internet Gateway implemented  
**Next:** Step 5 will add subnets, NAT Gateways, and routing

## Overview

This module creates the networking infrastructure for the DavidShaevel.com platform. It follows an incremental development approach, starting with foundational components and expanding over time.

### Current Implementation (Step 4)

- ✅ VPC with DNS support (10.0.0.0/16)
- ✅ Internet Gateway for public internet access
- ✅ Resource naming following conventions
- ✅ Comprehensive tagging

### Planned Implementation (Step 5)

- ⏳ Public subnets (2 AZs)
- ⏳ Private application subnets (2 AZs)
- ⏳ Private database subnets (2 AZs)
- ⏳ NAT Gateways (HA configuration)
- ⏳ Route tables and associations
- ⏳ VPC Flow Logs

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

### Subnet Outputs (Step 5)

| Name | Description |
|------|-------------|
| `public_subnet_ids` | List of public subnet IDs |
| `private_app_subnet_ids` | List of private application subnet IDs |
| `private_db_subnet_ids` | List of private database subnet IDs |

### NAT Gateway Outputs (Step 5)

| Name | Description |
|------|-------------|
| `nat_gateway_ids` | List of NAT Gateway IDs |
| `nat_gateway_public_ips` | List of NAT Gateway public IP addresses |

### Route Table Outputs (Step 5)

| Name | Description |
|------|-------------|
| `public_route_table_id` | ID of the public route table |
| `private_route_table_ids` | List of private route table IDs |

## Resources Created

### Step 4 (Current)

- 1 x VPC
- 1 x Internet Gateway

**Total:** 2 resources  
**Monthly Cost:** $0 (VPC and IGW are free)

### Step 5 (Planned)

- 6 x Subnets (2 public, 2 private app, 2 private DB)
- 2 x NAT Gateways (HA configuration)
- 2 x Elastic IPs (for NAT Gateways)
- 4 x Route Tables
- 6 x Route Table Associations
- 1 x CloudWatch Log Group (Flow Logs)
- 1 x IAM Role (Flow Logs)

**Total:** ~25-30 resources  
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
- ⏳ Subnets distributed across 2 AZs (Step 5)
- ⏳ NAT Gateway in each AZ (Step 5)
- ⏳ Independent routing per AZ (Step 5)

## Security

- ✅ DNS resolution enabled for internal service discovery
- ✅ DNS hostnames enabled for EC2/ECS instances
- ⏳ Network isolation with public/private subnet segregation (Step 5)
- ⏳ VPC Flow Logs for network monitoring (Step 5)

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

**Step 5 Implementation:**
1. Add subnet resources (public, private app, private DB)
2. Add NAT Gateway resources with Elastic IPs
3. Configure route tables and associations
4. Add VPC Flow Logs with CloudWatch
5. Update outputs to export new resource IDs

## References

- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Project Architecture](../../../docs/architecture/network.md)
- [Naming Conventions](../../../docs/architecture/naming-conventions.md)

---

**Last Updated:** October 25, 2025  
**Implementation Status:** Step 4 Complete  
**Next Phase:** Step 5 - Subnets and Routing


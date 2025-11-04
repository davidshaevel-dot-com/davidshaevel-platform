# Terraform Incremental Implementation Plan

**Project:** DavidShaevel.com Platform
**Issue:** TT-16 - Initialize Terraform project structure
**Strategy:** Build incrementally with working infrastructure at each step
**Date:** October 24, 2025

---

## Philosophy: Progressive Infrastructure Development

Instead of creating all modules at once, we'll build infrastructure incrementally:

1. ✅ **Each step produces working infrastructure**
2. ✅ **Each step is testable independently**
3. ✅ **Each step is committed to Git**
4. ✅ **Each step is reviewable via PR**
5. ✅ **Rollback is easy at any point**

---

## Project Structure Organization

```
terraform/
├── backend.tf                 # S3 backend configuration
├── provider.tf                # AWS provider setup
├── variables.tf               # Root-level variables
├── outputs.tf                 # Root-level outputs
├── versions.tf                # Terraform and provider version constraints
├── main.tf                    # Root module (references environment modules)
│
├── environments/              # Environment-specific configurations
│   ├── dev/
│   │   ├── main.tf           # Dev environment entry point
│   │   ├── variables.tf      # Dev-specific variables
│   │   ├── outputs.tf        # Dev outputs
│   │   ├── terraform.tfvars.example  # Example variables
│   │   └── backend-config.tfvars.example  # Example backend config
│   └── prod/
│       ├── main.tf           # Prod environment entry point
│       ├── variables.tf      # Prod-specific variables
│       ├── outputs.tf        # Prod outputs
│       ├── terraform.tfvars.example
│       └── backend-config.tfvars.example
│
├── modules/                   # Reusable infrastructure modules
│   ├── networking/           # VPC, subnets, routing
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── security/             # Security groups
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── database/             # RDS PostgreSQL
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── compute/              # ECS Fargate
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   └── cdn/                  # CloudFront + Route53
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── README.md
│
├── scripts/                   # Helper scripts
│   ├── setup-backend.sh      # Initialize S3 and DynamoDB
│   ├── validate-all.sh       # Validate all environments
│   └── cost-estimate.sh      # Estimate infrastructure costs
│
└── README.md                  # Comprehensive documentation
```

---

## Implementation Phases

### Phase 1: Foundation (Steps 1-3)
Basic Terraform setup with no AWS resources

### Phase 2: Networking (Steps 4-5)
VPC, subnets, and security groups

### Phase 3: Database (Step 6)
RDS PostgreSQL instance

### Phase 4: Compute (Steps 7-8)
ECS cluster and services

### Phase 5: Distribution (Step 9)
CloudFront and Route53

---

## Detailed Implementation Steps

### ✅ Step 1: Initialize Basic Terraform Structure

**Goal:** Create minimal Terraform files with no resources

**Files to create:**
- `terraform/versions.tf`
- `terraform/provider.tf`
- `terraform/backend.tf`
- `terraform/variables.tf`
- `terraform/outputs.tf`
- `terraform/README.md`

**What this includes:**
- Terraform version constraints (>= 1.5.0)
- AWS provider configuration
- S3 backend configuration (commented out initially)
- Basic project variables (region, project_name, environment)

**Test:**
```bash
cd terraform
terraform init
terraform validate
```

**Commit:**
```
feat(terraform): initialize basic terraform structure

- Add version constraints for Terraform and AWS provider
- Configure S3 backend for remote state management
- Define root-level variables and outputs
- Add comprehensive README documentation

related-issues: TT-16
```

---

### ✅ Step 2: Create Environment Structure

**Goal:** Set up dev and prod environment directories

**Files to create:**
- `terraform/environments/dev/main.tf`
- `terraform/environments/dev/variables.tf`
- `terraform/environments/dev/outputs.tf`
- `terraform/environments/dev/terraform.tfvars.example`
- `terraform/environments/dev/backend-config.tfvars.example`
- `terraform/environments/prod/` (same structure)

**What this includes:**
- Environment-specific entry points
- Variable declarations for each environment
- Example configuration files
- Backend configuration templates

**Test:**
```bash
cd terraform/environments/dev
terraform init
terraform validate
terraform plan  # Should show no changes
```

**Commit:**
```
feat(terraform): add dev and prod environment structure

- Create environment-specific directories
- Add main, variables, and outputs files
- Include example configuration files
- Document environment-specific settings

related-issues: TT-16
```

---

### ✅ Step 3: Add Helper Scripts and Documentation

**Goal:** Create automation scripts for common tasks

**Files to create:**
- `terraform/scripts/setup-backend.sh`
- `terraform/scripts/validate-all.sh`
- `terraform/scripts/cost-estimate.sh`

**What this includes:**
- Script to create S3 bucket and DynamoDB table
- Script to validate all environments
- Script to estimate costs (using terraform plan)

**Test:**
```bash
chmod +x terraform/scripts/*.sh
./terraform/scripts/validate-all.sh
```

**Commit:**
```
feat(terraform): add helper scripts and documentation

- Add backend setup automation script
- Add validation script for all environments
- Add cost estimation helper
- Update README with usage instructions

related-issues: TT-16
```

**PR #1:** Create pull request for basic structure
- Title: "feat(terraform): initialize terraform project structure"
- Description: Basic Terraform setup with no AWS resources

---

### ✅ Step 4: Implement Networking Module (VPC only)

**Goal:** Create VPC with basic configuration

**Files to create:**
- `terraform/modules/networking/main.tf` (VPC + IGW only)
- `terraform/modules/networking/variables.tf`
- `terraform/modules/networking/outputs.tf`
- `terraform/modules/networking/README.md`

**What this includes:**
- VPC with DNS support
- Internet Gateway
- Tags for organization

**Resources created:** ~2 resources

**Update:**
- `terraform/environments/dev/main.tf` to use networking module

**Test:**
```bash
cd terraform/environments/dev
terraform plan  # Should show 2 resources to create
terraform apply  # Deploy VPC only
```

**Cost:** $0/month (VPC and IGW are free)

**Commit:**
```
feat(terraform): add networking module with VPC

- Create networking module with VPC and Internet Gateway
- Add comprehensive variable definitions
- Include outputs for VPC ID and CIDR
- Update dev environment to use networking module

related-issues: TT-16, TT-17
```

---

### ✅ Step 5: Expand Networking Module (Subnets + NAT)

**Goal:** Add subnets and NAT gateways

**Update:**
- `terraform/modules/networking/main.tf` (add subnets, NAT, routes)

**What this includes:**
- Public subnets (2 AZs)
- Private subnets (2 AZs)
- Database subnets (2 AZs)
- NAT Gateways (configurable: 1 or 2)
- Route tables and associations
- VPC Flow Logs (optional)

**Resources created:** ~25-30 resources

**Test:**
```bash
terraform plan  # Review all networking resources
terraform apply
```

**Cost:** ~$2.40/day (2 NAT Gateways)

**Commit:**
```
feat(terraform): expand networking with subnets and NAT gateways

- Add public, private, and database subnets across 2 AZs
- Configure NAT gateways for private subnet internet access
- Set up route tables and associations
- Add VPC Flow Logs for network monitoring
- Make NAT gateway count configurable for cost optimization

related-issues: TT-16, TT-17
```

**PR #2:** Create pull request for networking
- Title: "feat(terraform): implement complete networking infrastructure"
- Description: VPC, subnets, NAT gateways, and routing

---

### ✅ Step 6: Add Security Groups Module

**Goal:** Create security groups for all tiers

**Files to create:**
- `terraform/modules/security/main.tf`
- `terraform/modules/security/variables.tf`
- `terraform/modules/security/outputs.tf`
- `terraform/modules/security/README.md`

**What this includes:**
- ALB security group (ingress: 80, 443)
- ECS security group (ingress: from ALB)
- RDS security group (ingress: from ECS)
- Egress rules for each

**Resources created:** ~4 security groups

**Update:**
- `terraform/environments/dev/main.tf` to use security module

**Test:**
```bash
terraform plan
terraform apply
```

**Cost:** $0/month (security groups are free)

**Commit:**
```
feat(terraform): add security groups module

- Create security groups for ALB, ECS, and RDS
- Implement least-privilege access rules
- Add ingress/egress rules following architecture design
- Document security group purposes and rules

related-issues: TT-16, TT-17
```

---

### ✅ Step 7: Implement Database Module

**Goal:** Create RDS PostgreSQL instance

**Files to create:**
- `terraform/modules/database/main.tf`
- `terraform/modules/database/variables.tf`
- `terraform/modules/database/outputs.tf`
- `terraform/modules/database/README.md`

**What this includes:**
- RDS PostgreSQL 15 instance
- DB subnet group (uses database subnets)
- Automated backups (7 days retention)
- Encryption at rest
- Secrets Manager for credentials
- CloudWatch alarms

**Resources created:** ~8-10 resources

**Update:**
- `terraform/environments/dev/main.tf` to use database module

**Test:**
```bash
terraform plan
terraform apply
# Test connection (from private subnet)
```

**Cost:** ~$15/month (db.t3.micro)

**Commit:**
```
feat(terraform): add RDS PostgreSQL database module

- Create RDS PostgreSQL 15 instance
- Configure DB subnet group in database tier
- Enable automated backups and encryption
- Store credentials in AWS Secrets Manager
- Add CloudWatch monitoring and alarms
- Configure for single-AZ (dev) and Multi-AZ (prod)

related-issues: TT-16, TT-21
```

**PR #3:** Create pull request for database
- Title: "feat(terraform): implement RDS PostgreSQL database infrastructure"
- Description: Secure, encrypted database with backups and monitoring

---

### ✅ Step 8: Implement Compute Module (Part 1: ECS Cluster + ALB)

**Goal:** Create ECS cluster and Application Load Balancer

**Files to create:**
- `terraform/modules/compute/main.tf` (cluster + ALB only)
- `terraform/modules/compute/variables.tf`
- `terraform/modules/compute/outputs.tf`
- `terraform/modules/compute/README.md`

**What this includes:**
- ECS Fargate cluster
- Application Load Balancer (in public subnets)
- Target groups (frontend and backend)
- ALB listeners (HTTP → HTTPS redirect, HTTPS)
- ACM certificate for HTTPS

**Resources created:** ~10-12 resources

**Test:**
```bash
terraform plan
terraform apply
# Verify ALB is created and healthy
```

**Cost:** ~$20/month (ALB)

**Commit:**
```
feat(terraform): add ECS cluster and ALB

- Create ECS Fargate cluster
- Configure Application Load Balancer
- Set up target groups for frontend and backend
- Configure HTTPS with ACM certificate
- Add health checks

related-issues: TT-16, TT-22
```

---

### ✅ Step 9: Expand Compute Module (Part 2: Task Definitions + Services)

**Goal:** Add ECS task definitions and services

**Update:**
- `terraform/modules/compute/main.tf` (add tasks and services)

**What this includes:**
- ECS task definitions (frontend and backend)
- ECS services with auto-scaling
- IAM roles for task execution
- Service discovery (optional)
- CloudWatch log groups

**Resources created:** ~15-20 resources

**Test:**
```bash
terraform plan
terraform apply
# Deploy placeholder container images
# Verify services are running
```

**Cost:** ~$15-30/month (Fargate tasks)

**Commit:**
```
feat(terraform): add ECS task definitions and services

- Create task definitions for frontend and backend
- Configure ECS services with auto-scaling
- Set up IAM roles for task execution and task role
- Configure CloudWatch log groups for container logs
- Add service discovery for internal communication
- Configure health checks and deployment settings

related-issues: TT-16, TT-22
```

**PR #4:** Create pull request for compute infrastructure
- Title: "feat(terraform): implement ECS Fargate infrastructure"
- Description: Complete container orchestration with ALB and auto-scaling

---

### ✅ Step 10: Implement CDN Module

**Goal:** Add CloudFront and Route53

**Files to create:**
- `terraform/modules/cdn/main.tf`
- `terraform/modules/cdn/variables.tf`
- `terraform/modules/cdn/outputs.tf`
- `terraform/modules/cdn/README.md`

**What this includes:**
- S3 bucket for static assets
- CloudFront distribution
- Route53 hosted zone
- DNS records (A, AAAA for apex and www)
- SSL certificate (ACM)
- WAF rules (optional)

**Resources created:** ~10-15 resources

**Update:**
- `terraform/environments/dev/main.tf` to use cdn module

**Test:**
```bash
terraform plan
terraform apply
# Verify CloudFront distribution
# Test DNS resolution
```

**Cost:** ~$1/month (CloudFront) + $0.50/month (Route53)

**Commit:**
```
feat(terraform): add CloudFront and Route53 module

- Create S3 bucket for static assets
- Configure CloudFront distribution with caching
- Set up Route53 hosted zone
- Add DNS records for apex and www subdomain
- Configure SSL certificate with ACM
- Add WAF rules for security

related-issues: TT-16, TT-24
```

**PR #5:** Create pull request for CDN
- Title: "feat(terraform): implement CloudFront CDN and Route53 DNS"
- Description: Global content delivery and DNS management

---

## Testing Strategy

### Per-Step Testing

After each step:
1. `terraform fmt -recursive` - Format code
2. `terraform validate` - Validate syntax
3. `terraform plan` - Review changes
4. `terraform apply` - Deploy infrastructure
5. Manual testing in AWS Console
6. Cost verification
7. Git commit with conventional format

### Integration Testing

After each PR:
1. Destroy and recreate from scratch
2. Verify all resources are created correctly
3. Test resource connectivity
4. Verify tags and naming conventions
5. Review costs in Cost Explorer

---

## Cost Management

### Development Environment (Estimated)

| Phase | Resources | Daily Cost | Monthly Cost |
|-------|-----------|------------|--------------|
| Phase 1-2 | Foundation | $0.00 | $0.00 |
| Phase 3 | + Networking | $2.40 | $72.00 |
| Phase 4 | + Database | $2.90 | $87.00 |
| Phase 5 | + Compute | $3.90 | $117.00 |
| Phase 6 | + CDN | $4.10 | $123.00 |

### Cost Optimization Strategies

1. **Single NAT Gateway in Dev** - Reduce from $1.08/day to $0.54/day
2. **Shutdown During Off-Hours** - Save ~70% on ECS costs
3. **Use db.t4g.micro** - ARM-based instances are cheaper
4. **CloudFront Caching** - Reduce origin requests

---

## Git Workflow

### Branch Naming
- Main branch: `claude/tt-16-terraform-project-structure`
- Feature branches: Create sub-branches if needed

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

related-issues: <issue-ids>
```

**Types:** feat, fix, docs, chore, refactor, test

**Example:**
```
feat(terraform): add networking module with VPC

- Create VPC with DNS support enabled
- Add Internet Gateway for public access
- Include comprehensive outputs
- Add module documentation

related-issues: TT-16, TT-17
```

### Pull Request Strategy

**PR Frequency:** After every 2-3 steps or major milestone

**PR Template:**
```markdown
## Description
Brief description of changes

## Changes
- List of key changes
- Infrastructure components added
- Configuration updates

## Testing
- [ ] `terraform fmt` passed
- [ ] `terraform validate` passed
- [ ] `terraform plan` reviewed
- [ ] Resources tested in AWS
- [ ] Costs verified

## Resources Created
- Resource type 1: X resources
- Resource type 2: Y resources

## Estimated Cost
- Daily: $X.XX
- Monthly: $X.XX

## Screenshots
[Optional: AWS Console screenshots]

## Related Issues
- TT-16
- TT-17

## Checklist
- [ ] Code follows project conventions
- [ ] Documentation updated
- [ ] No secrets in code
- [ ] Tags applied consistently
```

---

## Linear Issue Updates

Update TT-16 after each milestone:

**After Phase 1:**
```
Progress Update:
✅ Created basic Terraform structure
✅ Set up environment directories
✅ Added helper scripts
🔄 Next: Implementing networking module
```

**After Phase 2:**
```
Progress Update:
✅ Implemented complete networking infrastructure
✅ VPC, subnets, NAT gateways deployed
✅ Security groups configured
🔄 Next: Implementing database module
```

Continue pattern for all phases...

---

## Rollback Strategy

If issues arise:

### Step-Level Rollback
```bash
# Destroy specific module
terraform destroy -target=module.networking

# Or revert Git commit
git revert HEAD
terraform apply
```

### Complete Rollback
```bash
# Destroy all resources
terraform destroy

# Reset to main branch
git reset --hard origin/main
```

---

## Success Criteria

TT-16 is complete when:

- ✅ All infrastructure modules implemented
- ✅ Dev environment fully functional
- ✅ All tests passing
- ✅ Documentation complete
- ✅ PRs reviewed and merged
- ✅ Costs within budget ($130/month)
- ✅ Linear issue updated and closed

---

## Next Steps After TT-16

1. **TT-18:** Build Next.js frontend
2. **TT-19:** Build Nest.js backend
3. **TT-20:** Docker Compose setup
4. **TT-23:** CI/CD pipeline
5. **TT-25:** Observability setup

---

**Ready to start implementation!**

Follow the steps sequentially, test thoroughly, and commit frequently.

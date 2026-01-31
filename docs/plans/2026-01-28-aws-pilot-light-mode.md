# AWS Pilot Light Mode Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add `dev_activated` variable to Terraform and create shell scripts that allow toggling the dev environment between active (running ECS/NAT) and pilot light (minimal cost) modes.

**Architecture:** Follow the existing `dr_activated` pattern from the DR environment. Add a boolean variable that controls whether expensive compute resources (NAT Gateways, ECS services, ALB) are deployed. Always-on resources (ECR repos, IAM roles, RDS, S3) remain unchanged.

**Tech Stack:** Terraform, Bash, AWS CLI

---

## Background

With the Vercel migration complete, the AWS dev environment is no longer serving production traffic. We want to keep it available for testing/rollback but minimize costs (~$118/month) when not actively needed.

**Cost breakdown of resources to make conditional:**
- NAT Gateways (2x): ~$65/month
- ECS Fargate tasks: ~$30/month
- ALB: ~$18/month

**Always-on resources (minimal cost, needed for DR/rollback):**
- RDS PostgreSQL (db.t3.micro): ~$15/month - Keep for data persistence
- ECR repositories: ~$0 (storage only)
- IAM roles/policies: $0
- S3 buckets: ~$1/month

---

## Task 1: Add dev_activated variable to variables.tf

**Files:**
- Modify: [terraform/environments/dev/variables.tf](terraform/environments/dev/variables.tf#L1-L10)

**Step 1: Add dev_activated variable**

Add the following block after the `# Project Configuration` section header (around line 9):

```hcl
# -----------------------------------------------------------------------------
# Dev Environment Activation Control (Pilot Light Mode)
# -----------------------------------------------------------------------------

variable "dev_activated" {
  description = "Whether to deploy compute resources (ECS, NAT, ALB). Set to false for pilot light mode to minimize costs."
  type        = bool
  default     = true  # Default to active for backward compatibility
}
```

**Step 2: Verify syntax**

Run: `cd /Users/dshaevel/workspace-ds/davidshaevel-platform/main/terraform/environments/dev && terraform validate`
Expected: Success

**Step 3: Commit**

```bash
git add terraform/environments/dev/variables.tf
git commit -m "feat(TT-95): Add dev_activated variable for pilot light mode

Adds a boolean variable to control whether compute resources are deployed.
When false, only always-on resources (RDS, ECR, IAM, S3) remain."
```

---

## Task 2: Make networking module conditional on dev_activated

**Files:**
- Modify: [terraform/environments/dev/main.tf](terraform/environments/dev/main.tf#L75-L104)

**Step 1: Add count to networking module**

Change the networking module block from:
```hcl
module "networking" {
  source = "../../modules/networking"
```

To:
```hcl
module "networking" {
  source = "../../modules/networking"
  count  = var.dev_activated ? 1 : 0
```

**Step 2: Update all references to module.networking**

Find and replace all `module.networking.` references to use `module.networking[0].`:
- Line 118-121 (database module): `module.networking.vpc_id`, etc.
- Line 148-151 (compute module): `module.networking.vpc_id`, etc.
- Line 284-288 (observability module): `module.networking.vpc_id`, etc.
- Line 390 (service_discovery module): `module.networking.vpc_id`

**Step 3: Verify syntax**

Run: `cd /Users/dshaevel/workspace-ds/davidshaevel-platform/main/terraform/environments/dev && terraform validate`
Expected: Success

**Step 4: Commit**

```bash
git add terraform/environments/dev/main.tf
git commit -m "feat(TT-95): Make networking module conditional on dev_activated"
```

---

## Task 3: Make database module conditional with always-on option

**Important:** For Phase 2, we want to keep RDS always-on to preserve data. The database module should NOT be conditional. Skip this task.

---

## Task 4: Make compute module conditional on dev_activated

**Files:**
- Modify: [terraform/environments/dev/main.tf](terraform/environments/dev/main.tf#L138-L217)

**Step 1: Add count to compute module**

Add `count = var.dev_activated ? 1 : 0` after the source line.

**Step 2: Update networking references to use [0] index**

Update the compute module's networking inputs to reference `module.networking[0]`:
```hcl
  vpc_id                     = module.networking[0].vpc_id
  public_subnet_ids          = module.networking[0].public_subnet_ids
  private_app_subnet_ids     = module.networking[0].private_app_subnet_ids
  alb_security_group_id      = module.networking[0].alb_security_group_id
  frontend_security_group_id = module.networking[0].app_frontend_security_group_id
  backend_security_group_id  = module.networking[0].app_backend_security_group_id
```

**Step 3: Verify syntax**

Run: `terraform validate`
Expected: Success

**Step 4: Commit**

```bash
git add terraform/environments/dev/main.tf
git commit -m "feat(TT-95): Make compute module conditional on dev_activated"
```

---

## Task 5: Make CDN module conditional on dev_activated

**Files:**
- Modify: [terraform/environments/dev/main.tf](terraform/environments/dev/main.tf#L223-L254)

**Step 1: Add count to CDN module**

Add `count = var.dev_activated ? 1 : 0` after the source line.

**Step 2: Update ALB reference**

Update `alb_dns_name = module.compute.alb_dns_name` to `alb_dns_name = module.compute[0].alb_dns_name`

**Step 3: Verify syntax**

Run: `terraform validate`
Expected: Success

**Step 4: Commit**

```bash
git add terraform/environments/dev/main.tf
git commit -m "feat(TT-95): Make CDN module conditional on dev_activated"
```

---

## Task 6: Keep cicd_iam module always-on

> **UPDATE (TT-134):** The cicd_iam module is now **always-on** instead of conditional.
> This avoids needing to recreate IAM access keys and update GitHub secrets when
> switching between pilot light modes. IAM resources are free ($0 cost impact).

**Files:**
- Modify: [terraform/environments/dev/main.tf](terraform/environments/dev/main.tf#L260-L270)

**Step 1: Ensure cicd_iam module has NO count**

The module should NOT have a `count` conditional - it remains always-on:
```hcl
module "cicd_iam" {
  source = "../../modules/cicd-iam"
  # Always-on: IAM resources are free and keeping them avoids
  # needing to recreate access keys when switching pilot light modes

  environment    = var.environment
  ...
}
```

**Step 2: Update CDN reference**

Update `cloudfront_distribution_id` to handle when CDN doesn't exist:
```hcl
  cloudfront_distribution_id = var.dev_activated ? module.cdn[0].cloudfront_distribution_id : ""
```

**Step 3: Verify syntax**

Run: `terraform validate`
Expected: Success

**Step 4: Commit**

```bash
git add terraform/environments/dev/main.tf
git commit -m "feat(pilot-light): keep CI/CD IAM resources always-on"
```

---

## Task 7: Make observability module conditional on dev_activated

**Files:**
- Modify: [terraform/environments/dev/main.tf](terraform/environments/dev/main.tf#L276-L336)

**Step 1: Add count to observability module**

Add `count = var.dev_activated ? 1 : 0` after the source line.

**Step 2: Update all networking and compute references to use [0] index**

Update references like:
- `module.networking.vpc_id` → `module.networking[0].vpc_id`
- `module.compute.backend_port` → `module.compute[0].backend_port`
- etc.

**Step 3: Verify syntax**

Run: `terraform validate`
Expected: Success

**Step 4: Commit**

```bash
git add terraform/environments/dev/main.tf
git commit -m "feat(TT-95): Make observability module conditional on dev_activated"
```

---

## Task 8: Make service_discovery module conditional on dev_activated

**Files:**
- Modify: [terraform/environments/dev/main.tf](terraform/environments/dev/main.tf#L382-L402)

**Step 1: Add count to service_discovery module**

Add `count = var.dev_activated ? 1 : 0` after the source line.

**Step 2: Update networking reference**

Update `vpc_id = module.networking.vpc_id` to `vpc_id = module.networking[0].vpc_id`

**Step 3: Verify syntax**

Run: `terraform validate`
Expected: Success

**Step 4: Commit**

```bash
git add terraform/environments/dev/main.tf
git commit -m "feat(TT-95): Make service_discovery module conditional on dev_activated"
```

---

## Task 9: Make prometheus config resources conditional on dev_activated

**Files:**
- Modify: [terraform/environments/dev/main.tf](terraform/environments/dev/main.tf#L344-L376)

**Step 1: Update locals for prometheus config**

Update the `prometheus_config_rendered` local to be conditional:
```hcl
locals {
  prometheus_config_rendered = var.dev_activated ? templatefile("../../../observability/prometheus/prometheus.yml.tpl", {
    environment           = var.environment
    service_prefix        = "${var.environment}-${var.project_name}"
    platform_name         = var.project_name
    private_dns_zone      = var.private_dns_namespace
    backend_service_name  = module.service_discovery[0].backend_service_name
    frontend_service_name = module.service_discovery[0].frontend_service_name
  }) : ""
}
```

**Step 2: Add count to aws_s3_object resource**

Add `count = var.dev_activated ? 1 : 0` to the `aws_s3_object.prometheus_config` resource.

Update `bucket = module.observability.prometheus_config_bucket_id` to `bucket = module.observability[0].prometheus_config_bucket_id`

**Step 3: Verify syntax**

Run: `terraform validate`
Expected: Success

**Step 4: Commit**

```bash
git add terraform/environments/dev/main.tf
git commit -m "feat(TT-95): Make prometheus config conditional on dev_activated"
```

---

## Task 10: Update outputs to handle conditional modules

**Files:**
- Modify: [terraform/environments/dev/outputs.tf](terraform/environments/dev/outputs.tf)

**Step 1: Update networking outputs**

```hcl
output "vpc_id" {
  description = "The ID of the VPC"
  value       = var.dev_activated ? module.networking[0].vpc_id : null
}
```

**Step 2: Update compute outputs**

All compute outputs need conditional logic:
```hcl
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = var.dev_activated ? module.compute[0].ecs_cluster_name : null
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = var.dev_activated ? module.compute[0].alb_dns_name : null
}
# ... etc for all compute outputs
```

**Step 3: Update ECR outputs to use always-on resources**

Since ECR repos are now always-on, update outputs to reference the local resources:
```hcl
output "backend_ecr_repository_url" {
  description = "URL of the backend ECR repository"
  value       = aws_ecr_repository.backend.repository_url
}

output "backend_ecr_repository_name" {
  description = "Name of the backend ECR repository"
  value       = aws_ecr_repository.backend.name
}

output "frontend_ecr_repository_url" {
  description = "URL of the frontend ECR repository"
  value       = aws_ecr_repository.frontend.repository_url
}

output "frontend_ecr_repository_name" {
  description = "Name of the frontend ECR repository"
  value       = aws_ecr_repository.frontend.name
}

output "grafana_ecr_repository_url" {
  description = "URL of the Grafana ECR repository"
  value       = aws_ecr_repository.grafana.repository_url
}

output "grafana_ecr_repository_name" {
  description = "Name of the Grafana ECR repository"
  value       = aws_ecr_repository.grafana.name
}
```

**Step 4: Update CDN, CICD, Observability outputs**

All outputs from conditional modules need the pattern:
```hcl
output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = var.dev_activated ? module.cdn[0].cloudfront_distribution_id : null
}
```

**Step 5: Add dev_activated output**

```hcl
output "dev_activated" {
  description = "Whether the dev environment compute resources are active"
  value       = var.dev_activated
}
```

**Step 6: Verify syntax**

Run: `terraform validate`
Expected: Success

**Step 7: Commit**

```bash
git add terraform/environments/dev/outputs.tf
git commit -m "feat(TT-95): Update outputs to handle pilot light mode"
```

---

## Task 11: Run terraform plan to verify changes

**Step 1: Generate terraform plan**

Run:
```bash
cd /Users/dshaevel/workspace-ds/davidshaevel-platform/main/terraform/environments/dev
terraform plan -var="dev_activated=true"
```
Expected: No changes (infrastructure should match current state)

**Step 2: Generate plan for pilot light mode**

Run:
```bash
terraform plan -var="dev_activated=false"
```
Expected: Plan should show destruction of ECS, NAT, ALB resources while keeping RDS, ECR, IAM

**Step 3: Review plan output**

Verify that the following are marked for destruction:
- NAT Gateways
- ECS cluster and services
- ALB
- CloudFront distribution
- Observability resources (Prometheus, Grafana)

Verify these remain unchanged:
- RDS instance
- ECR repositories (in compute module)

**NOTE:** We need to verify that ECR repos are NOT destroyed. If they are in the compute module with count, we may need to extract them like the DR environment does.

---

## Task 12: Create dev-deactivate.sh script (TT-97)

**Files:**
- Create: [scripts/dev-deactivate.sh](scripts/dev-deactivate.sh)

**Step 1: Create the script**

```bash
#!/bin/bash
#
# Dev Environment Deactivation Script (Pilot Light Mode)
# Tears down expensive compute resources while preserving data
#
# Usage: ./dev-deactivate.sh [--dry-run] [--yes]
#
# Options:
#   --dry-run  Show what would be done without making changes
#   --yes      Skip confirmation prompts (use with caution)
#
# Prerequisites:
#   - AWS CLI configured with appropriate credentials
#   - Terraform installed
#   - terraform.tfvars configured in terraform/environments/dev/

set -euo pipefail

# Find repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Configuration
DEV_REGION="us-east-1"
DEV_TERRAFORM_DIR="${REPO_ROOT}/terraform/environments/dev"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
DRY_RUN=false
AUTO_APPROVE=false
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            ;;
        --yes)
            AUTO_APPROVE=true
            ;;
    esac
done

if [[ "${DRY_RUN}" == "true" ]]; then
    echo -e "${YELLOW}=== DRY RUN MODE - No changes will be made ===${NC}"
fi

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo "========================================"
echo "  DEV ENVIRONMENT DEACTIVATION"
echo "  Entering Pilot Light Mode"
echo "========================================"
echo ""

# Step 1: Verify AWS credentials
log_info "Verifying AWS credentials..."
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
log_info "Using AWS Account: ${ACCOUNT_ID}"

# Step 2: Verify we're not serving production traffic
log_info "Checking current production traffic routing..."
log_warn "Ensure Vercel is serving davidshaevel.com before deactivating AWS"
log_warn "Verify: curl -sI https://davidshaevel.com | grep -i server"

# Step 3: Show what will be destroyed
echo ""
echo "========================================"
echo "  DEACTIVATION PLAN"
echo "========================================"
echo ""
echo "  Resources to be DESTROYED:"
echo "    - NAT Gateways (2x)"
echo "    - ECS Cluster and Services"
echo "    - Application Load Balancer"
echo "    - CloudFront Distribution"
echo "    - Observability (Prometheus, Grafana)"
echo "    - Service Discovery (Cloud Map)"
echo ""
echo "  Resources to be PRESERVED:"
echo "    - RDS PostgreSQL instance"
echo "    - ECR repositories"
echo "    - IAM roles and policies"
echo "    - S3 buckets"
echo ""
echo "  Estimated monthly savings: ~\$113"
echo ""
echo "========================================"

if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "Generating Terraform plan..."
    cd "${DEV_TERRAFORM_DIR}"
    terraform plan -var="dev_activated=false"
    echo ""
    log_info "Dry run complete. Run without --dry-run to deactivate."
    exit 0
fi

# Confirm deactivation
if [[ "${AUTO_APPROVE}" != "true" ]]; then
    echo ""
    read -p "Proceed with dev environment deactivation? (yes/no): " CONFIRM
    if [[ "${CONFIRM}" != "yes" ]]; then
        log_warn "Deactivation cancelled"
        exit 0
    fi
fi

# Step 4: Run Terraform apply
log_info "Deactivating dev environment..."
cd "${DEV_TERRAFORM_DIR}"

TF_VARS=(
    -var="dev_activated=false"
)

if [[ "${AUTO_APPROVE}" == "true" ]]; then
    TF_VARS+=(-auto-approve)
fi

terraform apply "${TF_VARS[@]}"

echo ""
echo "========================================"
echo "  DEACTIVATION COMPLETE"
echo "========================================"
echo ""
echo "  Dev environment is now in Pilot Light mode."
echo ""
echo "  Preserved resources:"
echo "    - RDS: davidshaevel-dev-db"
echo "    - ECR: davidshaevel/backend, davidshaevel/frontend"
echo ""
echo "  To reactivate, run:"
echo "    ./scripts/dev-activate.sh"
echo ""
echo "========================================"
```

**Step 2: Make executable**

Run: `chmod +x scripts/dev-deactivate.sh`

**Step 3: Commit**

```bash
git add scripts/dev-deactivate.sh
git commit -m "feat(TT-97): Add dev-deactivate.sh for pilot light mode

Adds script to safely tear down expensive compute resources while
preserving RDS, ECR, and IAM for future reactivation."
```

---

## Task 13: Create dev-activate.sh script (TT-96)

**Files:**
- Create: [scripts/dev-activate.sh](scripts/dev-activate.sh)

**Step 1: Create the script**

```bash
#!/bin/bash
#
# Dev Environment Activation Script
# Brings up compute resources from Pilot Light mode
#
# Usage: ./dev-activate.sh [--dry-run] [--yes]
#
# Options:
#   --dry-run  Show what would be done without making changes
#   --yes      Skip confirmation prompts (use with caution)
#
# Prerequisites:
#   - AWS CLI configured with appropriate credentials
#   - Terraform installed
#   - terraform.tfvars configured in terraform/environments/dev/
#   - backend_container_image must be specified

set -euo pipefail

# Find repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Configuration
DEV_REGION="us-east-1"
DEV_TERRAFORM_DIR="${REPO_ROOT}/terraform/environments/dev"
ECR_REGISTRY="108581769167.dkr.ecr.${DEV_REGION}.amazonaws.com"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
DRY_RUN=false
AUTO_APPROVE=false
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            ;;
        --yes)
            AUTO_APPROVE=true
            ;;
    esac
done

if [[ "${DRY_RUN}" == "true" ]]; then
    echo -e "${YELLOW}=== DRY RUN MODE - No changes will be made ===${NC}"
fi

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo "========================================"
echo "  DEV ENVIRONMENT ACTIVATION"
echo "  Exiting Pilot Light Mode"
echo "========================================"
echo ""

# Step 1: Verify AWS credentials
log_info "Verifying AWS credentials..."
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
log_info "Using AWS Account: ${ACCOUNT_ID}"

# Step 2: Find latest backend image
log_info "Finding latest backend container image..."
BACKEND_IMAGE=$(aws ecr describe-images \
    --repository-name davidshaevel/backend \
    --region ${DEV_REGION} \
    --query 'imageDetails | sort_by(@, &imagePushedAt) | [-1].imageTags[0]' \
    --output text 2>/dev/null || echo "")

if [[ -z "${BACKEND_IMAGE}" || "${BACKEND_IMAGE}" == "None" ]]; then
    log_error "No backend images found in ECR"
    log_error "Push an image before activating: npm run deploy:backend"
    exit 1
fi

FULL_BACKEND_IMAGE="${ECR_REGISTRY}/davidshaevel/backend:${BACKEND_IMAGE}"
log_info "Backend image: ${FULL_BACKEND_IMAGE}"

# Step 3: Check RDS status
log_info "Checking RDS status..."
RDS_STATUS=$(aws rds describe-db-instances \
    --db-instance-identifier dev-davidshaevel-db \
    --region ${DEV_REGION} \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text 2>/dev/null || echo "not-found")

if [[ "${RDS_STATUS}" != "available" ]]; then
    log_error "RDS instance is not available (status: ${RDS_STATUS})"
    exit 1
fi
log_info "RDS status: ${RDS_STATUS}"

# Step 4: Show activation plan
echo ""
echo "========================================"
echo "  ACTIVATION PLAN"
echo "========================================"
echo ""
echo "  Resources to be CREATED:"
echo "    - VPC and Networking (NAT Gateways)"
echo "    - ECS Cluster and Services"
echo "    - Application Load Balancer"
echo "    - CloudFront Distribution"
echo "    - Observability (Prometheus, Grafana)"
echo "    - Service Discovery (Cloud Map)"
echo ""
echo "  Using backend image: ${BACKEND_IMAGE}"
echo ""
echo "  Estimated deployment time: 15-20 minutes"
echo ""
echo "========================================"

if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "Generating Terraform plan..."
    cd "${DEV_TERRAFORM_DIR}"
    terraform plan -var="dev_activated=true" -var="backend_container_image=${FULL_BACKEND_IMAGE}"
    echo ""
    log_info "Dry run complete. Run without --dry-run to activate."
    exit 0
fi

# Confirm activation
if [[ "${AUTO_APPROVE}" != "true" ]]; then
    echo ""
    read -p "Proceed with dev environment activation? (yes/no): " CONFIRM
    if [[ "${CONFIRM}" != "yes" ]]; then
        log_warn "Activation cancelled"
        exit 0
    fi
fi

# Step 5: Run Terraform apply
log_info "Activating dev environment..."
cd "${DEV_TERRAFORM_DIR}"

TF_VARS=(
    -var="dev_activated=true"
    -var="backend_container_image=${FULL_BACKEND_IMAGE}"
)

if [[ "${AUTO_APPROVE}" == "true" ]]; then
    TF_VARS+=(-auto-approve)
fi

terraform apply "${TF_VARS[@]}"

# Step 6: Get outputs
log_info "Retrieving endpoints..."
ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "N/A")

echo ""
echo "========================================"
echo "  ACTIVATION COMPLETE"
echo "========================================"
echo ""
echo "  ALB DNS: ${ALB_DNS}"
echo ""
echo "  Verify services:"
echo "    curl -k https://${ALB_DNS}/api/health"
echo ""
echo "  To deactivate and return to Pilot Light mode:"
echo "    ./scripts/dev-deactivate.sh"
echo ""
echo "========================================"
```

**Step 2: Make executable**

Run: `chmod +x scripts/dev-activate.sh`

**Step 3: Commit**

```bash
git add scripts/dev-activate.sh
git commit -m "feat(TT-96): Add dev-activate.sh to bring up compute resources

Adds script to bring dev environment out of Pilot Light mode,
deploying ECS, NAT, ALB, and observability stack."
```

---

## Task 14: Extract ECR repos to always-on section

**Important:** The compute module creates ECR repos with `count = var.create_ecr_repos ? 1 : 0`. When the compute module has `count = 0`, ECR repos would be destroyed. We must extract them as always-on resources.

**Files:**
- Modify: [terraform/environments/dev/main.tf](terraform/environments/dev/main.tf)

**Step 1: Add always-on ECR repos section**

Add the following section BEFORE the networking module (after the `locals` block, around line 49):

```hcl
# ==============================================================================
# Always-On Resources (Pilot Light Mode)
# These resources persist even when dev_activated=false
# ==============================================================================

# Backend ECR Repository - Always on for image storage
resource "aws_ecr_repository" "backend" {
  name                 = "${var.project_name}/backend"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(local.common_tags, {
    Name        = "${var.project_name}-backend-ecr"
    Application = "backend"
  })
}

resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Frontend ECR Repository - Always on for image storage
resource "aws_ecr_repository" "frontend" {
  name                 = "${var.project_name}/frontend"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(local.common_tags, {
    Name        = "${var.project_name}-frontend-ecr"
    Application = "frontend"
  })
}

resource "aws_ecr_lifecycle_policy" "frontend" {
  repository = aws_ecr_repository.frontend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Grafana ECR Repository - Always on for image storage
resource "aws_ecr_repository" "grafana" {
  name                 = "${var.project_name}/grafana"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(local.common_tags, {
    Name        = "${var.project_name}-grafana-ecr"
    Application = "grafana"
  })
}

resource "aws_ecr_lifecycle_policy" "grafana" {
  repository = aws_ecr_repository.grafana.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
```

**Step 2: Add create_ecr_repos = false to compute module**

In the compute module block, add:
```hcl
  # Don't create ECR repos - they're managed as always-on resources above
  create_ecr_repos = false
```

**Step 3: Verify syntax**

Run: `terraform validate`
Expected: Success

**Step 4: Commit**

```bash
git add terraform/environments/dev/main.tf
git commit -m "feat(TT-95): Extract ECR repos to always-on section

Prevents ECR repos from being destroyed when dev_activated=false.
Follows the same pattern as the DR environment (TT-75)."
```

---

## Task 15: End-to-end test with terraform plan

**Step 1: Run full validation**

```bash
cd /Users/dshaevel/workspace-ds/davidshaevel-platform/main/terraform/environments/dev
terraform init
terraform validate
terraform plan -var="dev_activated=true"
terraform plan -var="dev_activated=false"
```

**Step 2: Verify ECR repos preserved**

In the `dev_activated=false` plan, verify ECR repos are NOT in the destruction list.

**Step 3: Document any issues**

If ECR repos are destroyed, implement Task 14 extraction.

---

## Task 16: Update Linear issues and create PR

**Step 1: Update TT-95, TT-96, TT-97 to Done**

**Step 2: Create PR**

```bash
gh pr create --title "feat: Add AWS Pilot Light mode for dev environment" --body "$(cat <<'EOF'
## Summary
- Adds `dev_activated` variable to toggle compute resources
- Creates `dev-activate.sh` and `dev-deactivate.sh` scripts
- Follows existing DR environment pattern for conditional resources

## Test plan
- [ ] `terraform plan -var="dev_activated=true"` shows no changes
- [ ] `terraform plan -var="dev_activated=false"` shows compute destruction
- [ ] ECR repos preserved in pilot light mode
- [ ] Scripts have correct permissions and run --dry-run successfully

## Related issues
- TT-95: Add dev_activated variable to Terraform
- TT-96: Create dev-activate.sh script
- TT-97: Create dev-deactivate.sh script
EOF
)"
```

---

## Notes

- **Do NOT run `terraform apply -var="dev_activated=false"` yet** - this is for when we're ready to actually reduce costs
- The database module intentionally remains always-on to preserve data
- ECR repos must remain always-on to preserve container images for reactivation
- Follow the DR environment pattern closely for consistency

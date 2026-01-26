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
#   - Container images must exist in ECR

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

# Step 2: Check current activation status
log_info "Checking current dev_activated status..."
cd "${DEV_TERRAFORM_DIR}"
CURRENT_STATUS=$(terraform output -raw dev_activated 2>/dev/null || echo "unknown")
log_info "Current dev_activated: ${CURRENT_STATUS}"

if [[ "${CURRENT_STATUS}" == "true" ]]; then
    log_warn "Dev environment is already active"
    exit 0
fi

# Step 3: Find latest backend image
log_info "Finding latest backend container image..."
BACKEND_IMAGE=$(aws ecr describe-images \
    --repository-name davidshaevel/backend \
    --region ${DEV_REGION} \
    --query 'imageDetails | sort_by(@, &imagePushedAt) | [-1].imageTags[0]' \
    --output text 2>/dev/null || echo "")

if [[ -z "${BACKEND_IMAGE}" || "${BACKEND_IMAGE}" == "None" ]]; then
    log_error "No backend images found in ECR"
    log_error "Push an image before activating"
    exit 1
fi

FULL_BACKEND_IMAGE="${ECR_REGISTRY}/davidshaevel/backend:${BACKEND_IMAGE}"
log_info "Backend image: ${FULL_BACKEND_IMAGE}"

# Step 4: Find latest frontend image
log_info "Finding latest frontend container image..."
FRONTEND_IMAGE=$(aws ecr describe-images \
    --repository-name davidshaevel/frontend \
    --region ${DEV_REGION} \
    --query 'imageDetails | sort_by(@, &imagePushedAt) | [-1].imageTags[0]' \
    --output text 2>/dev/null || echo "")

if [[ -z "${FRONTEND_IMAGE}" || "${FRONTEND_IMAGE}" == "None" ]]; then
    log_error "No frontend images found in ECR"
    log_error "Push an image before activating"
    exit 1
fi

FULL_FRONTEND_IMAGE="${ECR_REGISTRY}/davidshaevel/frontend:${FRONTEND_IMAGE}"
log_info "Frontend image: ${FULL_FRONTEND_IMAGE}"

# Step 5: Check RDS status
log_info "Checking RDS status..."
RDS_STATUS=$(aws rds describe-db-instances \
    --db-instance-identifier davidshaevel-dev-db \
    --region ${DEV_REGION} \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text 2>/dev/null || echo "not-found")

if [[ "${RDS_STATUS}" != "available" ]]; then
    log_error "RDS instance is not available (status: ${RDS_STATUS})"
    exit 1
fi
log_info "RDS status: ${RDS_STATUS}"

# Step 6: Show activation plan
echo ""
echo "========================================"
echo "  ACTIVATION PLAN"
echo "========================================"
echo ""
echo "  Resources to be CREATED:"
echo "    - ECS Cluster and Services (4 services)"
echo "    - Application Load Balancer"
echo "    - CloudFront Distribution"
echo "    - Observability (Prometheus, Grafana, EFS)"
echo "    - Service Discovery (Cloud Map)"
echo "    - CI/CD IAM resources"
echo ""
echo "  Using images:"
echo "    - Backend:  ${BACKEND_IMAGE}"
echo "    - Frontend: ${FRONTEND_IMAGE}"
echo ""
echo "  Estimated deployment time: 15-20 minutes"
echo ""
echo "========================================"

if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "Generating Terraform plan..."
    terraform plan \
        -var="dev_activated=true" \
        -var="backend_container_image=${FULL_BACKEND_IMAGE}" \
        -var="frontend_container_image=${FULL_FRONTEND_IMAGE}"
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

# Step 7: Run Terraform apply
log_info "Activating dev environment..."

TF_VARS=(
    -var="dev_activated=true"
    -var="backend_container_image=${FULL_BACKEND_IMAGE}"
    -var="frontend_container_image=${FULL_FRONTEND_IMAGE}"
)

if [[ "${AUTO_APPROVE}" == "true" ]]; then
    TF_VARS+=(-auto-approve)
fi

terraform apply "${TF_VARS[@]}"

# Step 8: Get outputs
log_info "Retrieving endpoints..."
ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "N/A")
CLOUDFRONT_DOMAIN=$(terraform output -raw cloudfront_domain_name 2>/dev/null || echo "N/A")

echo ""
echo "========================================"
echo "  ACTIVATION COMPLETE"
echo "========================================"
echo ""
echo "  ALB DNS: ${ALB_DNS}"
echo "  CloudFront: ${CLOUDFRONT_DOMAIN}"
echo ""
echo "  Verify services:"
echo "    curl -k https://${ALB_DNS}/api/health"
echo ""
echo "  To switch DNS to AWS (if needed):"
echo "    ./scripts/vercel-dns-switch.sh --to-aws"
echo ""
echo "  To deactivate and return to Pilot Light mode:"
echo "    ./scripts/dev-deactivate.sh"
echo ""
echo "========================================"

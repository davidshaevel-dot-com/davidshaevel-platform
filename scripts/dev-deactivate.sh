#!/bin/bash
#
# Dev Environment Deactivation Script (Pilot Light Mode)
# Tears down expensive compute resources while preserving data and networking
#
# Usage: ./dev-deactivate.sh [--dry-run] [--yes] [--sync-data]
#
# Options:
#   --dry-run    Show what would be done without making changes
#   --yes        Skip confirmation prompts (use with caution)
#   --sync-data  Sync RDS database to Neon before deactivation
#
# Prerequisites:
#   - AWS CLI configured with appropriate credentials
#   - Terraform installed
#   - terraform.tfvars configured in terraform/environments/dev/

set -euo pipefail

# Find repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Configuration (can be overridden via environment variables)
DEV_REGION="${AWS_REGION:-us-east-1}"
DEV_TERRAFORM_DIR="${REPO_ROOT}/terraform/environments/dev"
PROJECT_NAME="${PROJECT_NAME:-davidshaevel}"

# ECR configuration - derived from project name
BACKEND_ECR_REPO="${PROJECT_NAME}/backend"
FRONTEND_ECR_REPO="${PROJECT_NAME}/frontend"
GRAFANA_ECR_REPO="${PROJECT_NAME}/grafana"

# RDS configuration - follows naming convention: ${project_name}-${environment}-db
RDS_INSTANCE_ID="${PROJECT_NAME}-dev-db"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
DRY_RUN=false
AUTO_APPROVE=false
SYNC_DATA=false
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            ;;
        --yes)
            AUTO_APPROVE=true
            ;;
        --sync-data)
            SYNC_DATA=true
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

# Step 2: Check current activation status
log_info "Checking current dev_activated status..."
cd "${DEV_TERRAFORM_DIR}"
CURRENT_STATUS=$(terraform output -raw dev_activated 2>/dev/null || echo "unknown")
log_info "Current dev_activated: ${CURRENT_STATUS}"

if [[ "${CURRENT_STATUS}" == "false" ]]; then
    log_warn "Dev environment is already in Pilot Light mode"
    exit 0
fi

# Step 3: Verify we're not serving production traffic
log_info "Checking current production traffic routing..."

# Automated check for Vercel serving production
PROD_SERVER=$(curl -sI https://davidshaevel.com 2>/dev/null | grep -i "^server:" | awk '{print tolower($2)}' || echo "unknown")

if [[ "${PROD_SERVER}" == *"vercel"* ]]; then
    log_info "Production is served by Vercel - safe to deactivate AWS"
else
    log_warn "Production server: ${PROD_SERVER}"
    log_warn "Expected: Vercel"
    echo ""
    echo "  Manual verification: curl -sI https://davidshaevel.com | grep -i server"
    echo ""
    if [[ "${AUTO_APPROVE}" != "true" ]]; then
        read -p "Production may not be on Vercel. Continue anyway? (yes/no): " PROD_CONFIRM
        if [[ "${PROD_CONFIRM}" != "yes" ]]; then
            log_error "Deactivation cancelled - verify Vercel is serving production first"
            exit 1
        fi
    fi
fi

# Step 4: Show what will be destroyed
echo ""
echo "========================================"
echo "  DEACTIVATION PLAN"
echo "========================================"
echo ""
echo "  Resources to be DESTROYED:"
echo "    - ECS Cluster and Services (4 services)"
echo "    - Application Load Balancer"
echo "    - CloudFront Distribution"
echo "    - Observability (Prometheus, Grafana, EFS)"
echo "    - Service Discovery (Cloud Map)"
echo "    - NAT Gateways"
echo "    - RDS PostgreSQL instance (snapshot created first)"
echo ""
echo "  Resources to be PRESERVED:"
echo "    - VPC and Networking (subnets, security groups)"
echo "    - ECR repositories"
echo "    - S3 buckets"
echo "    - CI/CD IAM resources (GitHub Actions user and policy)"
echo ""
echo "  Estimated monthly savings: ~\$115"
echo ""
if [[ "${SYNC_DATA}" == "true" ]]; then
    echo "  Data Sync: RDS → Neon (before Terraform destroy)"
    echo ""
fi
echo "========================================"

if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "Generating Terraform plan..."
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

# Step 5: Sync data from RDS to Neon (optional)
if [[ "${SYNC_DATA}" == "true" ]]; then
    echo ""
    log_info "Syncing data from RDS to Neon..."
    SYNC_FLAGS=()
    if [[ "${DRY_RUN}" == "true" ]]; then
        SYNC_FLAGS+=(--dry-run)
    fi
    "${SCRIPT_DIR}/sync-rds-to-neon.sh" "${SYNC_FLAGS[@]}"

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "Sync dry-run complete"
    else
        log_info "Data sync complete"
    fi
    echo ""
fi

# Step 6: Create manual RDS snapshot before destroying
log_info "Creating RDS snapshot before deactivation..."
SNAPSHOT_ID="${RDS_INSTANCE_ID}-pre-deactivation-$(date -u +%Y%m%d-%H%M%S)"

RDS_STATUS=$(aws rds describe-db-instances \
    --db-instance-identifier "${RDS_INSTANCE_ID}" \
    --region "${DEV_REGION}" \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text 2>/dev/null || echo "not-found")

if [[ "${RDS_STATUS}" == "available" ]]; then
    log_info "Creating snapshot: ${SNAPSHOT_ID}"
    aws rds create-db-snapshot \
        --db-instance-identifier "${RDS_INSTANCE_ID}" \
        --db-snapshot-identifier "${SNAPSHOT_ID}" \
        --region "${DEV_REGION}" \
        --output text > /dev/null

    log_info "Waiting for snapshot to complete (this may take a few minutes)..."
    aws rds wait db-snapshot-available \
        --db-snapshot-identifier "${SNAPSHOT_ID}" \
        --region "${DEV_REGION}"

    log_info "Snapshot complete: ${SNAPSHOT_ID}"
else
    log_warn "RDS instance not found or not available (status: ${RDS_STATUS})"
    log_warn "Skipping snapshot creation"
    SNAPSHOT_ID="N/A"
fi
echo ""

# Step 7: Run Terraform apply
log_info "Deactivating dev environment..."

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
echo "  RDS snapshot: ${SNAPSHOT_ID}"
echo ""
echo "  Preserved resources:"
echo "    - VPC (subnets, security groups)"
echo "    - ECR: ${BACKEND_ECR_REPO}, ${FRONTEND_ECR_REPO}, ${GRAFANA_ECR_REPO}"
echo "    - S3: Database backups bucket"
echo ""
echo "  To reactivate (creates fresh RDS + syncs from Neon):"
echo "    ./scripts/dev-activate.sh"
echo ""
echo "========================================"

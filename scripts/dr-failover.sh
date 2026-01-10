#!/bin/bash
#
# DR Failover Script
# Activates the Disaster Recovery environment in us-west-2
#
# Usage: ./dr-failover.sh [--dry-run]
#
# Prerequisites:
#   - AWS CLI configured with appropriate credentials
#   - Terraform installed
#   - Backend and tfvars files configured in terraform/environments/dr/

set -euo pipefail

# Find repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Configuration
DR_REGION="us-west-2"
PRIMARY_REGION="us-east-1"
DR_TERRAFORM_DIR="${REPO_ROOT}/terraform/environments/dr"
PRIMARY_DB_IDENTIFIER="davidshaevel-dev-db"
ECR_REGISTRY="108581769167.dkr.ecr.${DR_REGION}.amazonaws.com"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo -e "${YELLOW}=== DRY RUN MODE - No changes will be made ===${NC}"
fi

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo "========================================"
echo "  DISASTER RECOVERY FAILOVER"
echo "  Target Region: ${DR_REGION}"
echo "========================================"
echo ""

# Step 1: Verify AWS credentials
log_info "Verifying AWS credentials..."
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
log_info "Using AWS Account: ${ACCOUNT_ID}"

# Step 2: Check primary region health (optional - may be unavailable)
log_info "Checking primary region health..."
if aws ec2 describe-availability-zones --region ${PRIMARY_REGION} &>/dev/null; then
    log_warn "Primary region ${PRIMARY_REGION} appears to be available"
    log_warn "Confirm this is an intentional DR activation"
else
    log_info "Primary region ${PRIMARY_REGION} is not responding - proceeding with DR"
fi

# Step 3: Find latest DR snapshot
log_info "Finding latest DR snapshot in ${DR_REGION}..."
LATEST_SNAPSHOT=$(aws rds describe-db-snapshots \
    --region ${DR_REGION} \
    --snapshot-type manual \
    --query "DBSnapshots[?starts_with(DBSnapshotIdentifier, \`${PRIMARY_DB_IDENTIFIER}-dr-\`)] | sort_by(@, &SnapshotCreateTime) | [-1].DBSnapshotIdentifier" \
    --output text 2>/dev/null || echo "None")

if [[ "${LATEST_SNAPSHOT}" == "None" || -z "${LATEST_SNAPSHOT}" ]]; then
    log_error "No DR snapshots found in ${DR_REGION}"
    log_error "Ensure snapshot replication is working before activating DR"
    exit 1
fi

log_info "Latest DR snapshot: ${LATEST_SNAPSHOT}"

# Step 4: Get snapshot status
SNAPSHOT_STATUS=$(aws rds describe-db-snapshots \
    --region ${DR_REGION} \
    --db-snapshot-identifier "${LATEST_SNAPSHOT}" \
    --query 'DBSnapshots[0].Status' \
    --output text)

if [[ "${SNAPSHOT_STATUS}" != "available" ]]; then
    log_error "Snapshot ${LATEST_SNAPSHOT} is not available (status: ${SNAPSHOT_STATUS})"
    exit 1
fi

log_info "Snapshot status: ${SNAPSHOT_STATUS}"

# Step 5: Get latest ECR images
log_info "Finding latest container images in ${DR_REGION}..."
BACKEND_IMAGE=$(aws ecr describe-images \
    --repository-name davidshaevel/backend \
    --region ${DR_REGION} \
    --query 'imageDetails | sort_by(@, &imagePushedAt) | [-1].imageTags[0]' \
    --output text 2>/dev/null || echo "")

FRONTEND_IMAGE=$(aws ecr describe-images \
    --repository-name davidshaevel/frontend \
    --region ${DR_REGION} \
    --query 'imageDetails | sort_by(@, &imagePushedAt) | [-1].imageTags[0]' \
    --output text 2>/dev/null || echo "")

GRAFANA_IMAGE=$(aws ecr describe-images \
    --repository-name davidshaevel/grafana \
    --region ${DR_REGION} \
    --query 'imageDetails | sort_by(@, &imagePushedAt) | [-1].imageTags[0]' \
    --output text 2>/dev/null || echo "")

if [[ -z "${BACKEND_IMAGE}" || -z "${FRONTEND_IMAGE}" ]]; then
    log_error "Container images not found in DR region ECR"
    exit 1
fi

if [[ -z "${GRAFANA_IMAGE}" ]]; then
    log_warn "Grafana image not found in DR ECR - using default stock image"
    GRAFANA_IMAGE=""
fi

log_info "Backend image: ${ECR_REGISTRY}/davidshaevel/backend:${BACKEND_IMAGE}"
log_info "Frontend image: ${ECR_REGISTRY}/davidshaevel/frontend:${FRONTEND_IMAGE}"
if [[ -n "${GRAFANA_IMAGE}" ]]; then
    log_info "Grafana image: ${ECR_REGISTRY}/davidshaevel/grafana:${GRAFANA_IMAGE}"
fi

# Step 6: Display activation plan
echo ""
echo "========================================"
echo "  DR ACTIVATION PLAN"
echo "========================================"
echo ""
echo "  Snapshot:  ${LATEST_SNAPSHOT}"
echo "  Backend:   ${BACKEND_IMAGE}"
echo "  Frontend:  ${FRONTEND_IMAGE}"
if [[ -n "${GRAFANA_IMAGE}" ]]; then
    echo "  Grafana:   ${GRAFANA_IMAGE}"
fi
echo ""
echo "  Terraform will deploy:"
echo "    - VPC and networking in ${DR_REGION}"
echo "    - RDS PostgreSQL (restored from snapshot)"
echo "    - ECS Fargate cluster and services"
echo "    - Application Load Balancer"
echo "    - Service Discovery (Cloud Map)"
echo ""
echo "  Estimated time: 30-45 minutes"
echo ""
echo "========================================"

if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "Dry run complete. Run without --dry-run to activate DR."
    exit 0
fi

# Confirm activation
read -p "Proceed with DR activation? (yes/no): " CONFIRM
if [[ "${CONFIRM}" != "yes" ]]; then
    log_warn "DR activation cancelled"
    exit 0
fi

# Step 7: Run Terraform apply
log_info "Activating DR infrastructure..."
cd "${DR_TERRAFORM_DIR}"

# Build terraform apply command with required and optional vars
TF_VARS=(
    -var="dr_activated=true"
    -var="db_snapshot_identifier=${LATEST_SNAPSHOT}"
    -var="frontend_container_image=${ECR_REGISTRY}/davidshaevel/frontend:${FRONTEND_IMAGE}"
    -var="backend_container_image=${ECR_REGISTRY}/davidshaevel/backend:${BACKEND_IMAGE}"
)

# Add Grafana image if available in DR ECR
if [[ -n "${GRAFANA_IMAGE}" ]]; then
    TF_VARS+=(-var="grafana_image=${ECR_REGISTRY}/davidshaevel/grafana:${GRAFANA_IMAGE}")
fi

terraform apply "${TF_VARS[@]}"

# Step 8: Get outputs
log_info "Retrieving DR endpoints..."
ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "N/A")

# Step 9: Update CloudFront origin to DR ALB
log_info "Updating CloudFront distribution origin to DR ALB..."
CLOUDFRONT_DIST_ID="EJVDEMX0X00IG"

# Get current distribution config
aws cloudfront get-distribution-config --id "${CLOUDFRONT_DIST_ID}" > /tmp/cf-dist-config.json

# Extract ETag for update
ETAG=$(jq -r '.ETag' /tmp/cf-dist-config.json)

# Update origin domain name to DR ALB
jq --arg dr_alb "${ALB_DNS}" '.DistributionConfig.Origins.Items[0].DomainName = $dr_alb' /tmp/cf-dist-config.json | jq '.DistributionConfig' > /tmp/cf-dist-config-updated.json

# Update the distribution
if aws cloudfront update-distribution --id "${CLOUDFRONT_DIST_ID}" --if-match "${ETAG}" --distribution-config file:///tmp/cf-dist-config-updated.json > /dev/null 2>&1; then
    log_info "CloudFront origin updated to: ${ALB_DNS}"

    # Invalidate cache
    log_info "Creating CloudFront cache invalidation..."
    aws cloudfront create-invalidation --distribution-id "${CLOUDFRONT_DIST_ID}" --paths "/*" > /dev/null 2>&1
    log_info "Cache invalidation created for all paths"
else
    log_warn "Failed to update CloudFront origin automatically"
    log_warn "Please update manually: CloudFront > ${CLOUDFRONT_DIST_ID} > Origins > alb-origin"
fi

# Cleanup temp files
rm -f /tmp/cf-dist-config.json /tmp/cf-dist-config-updated.json

echo ""
echo "========================================"
echo "  DR ACTIVATION COMPLETE"
echo "========================================"
echo ""
echo "  DR ALB DNS: ${ALB_DNS}"
echo "  CloudFront: https://davidshaevel.com (origin updated to DR)"
echo ""
echo "  Next steps:"
echo "    1. Verify services: ./scripts/dr-validation.sh"
echo "    2. Wait for CloudFront deployment (~5-10 min)"
echo "    3. Test https://davidshaevel.com"
echo ""
echo "========================================"

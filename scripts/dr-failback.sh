#!/bin/bash
#
# DR Failback Script
# Returns traffic to the primary region (us-east-1) after DR activation
#
# Usage: ./dr-failback.sh [--dry-run] [--deactivate-dr]
#
# Options:
#   --dry-run       Show what would be done without making changes
#   --deactivate-dr Also deactivate DR infrastructure (terraform destroy)
#
# Prerequisites:
#   - AWS CLI configured with appropriate credentials
#   - Terraform installed
#   - Primary region must be healthy and operational

set -euo pipefail

# Find repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Configuration
PRIMARY_REGION="us-east-1"
DR_REGION="us-west-2"
DR_TERRAFORM_DIR="${REPO_ROOT}/terraform/environments/dr"
PRIMARY_ALB_DNS="dev-davidshaevel-alb-1965037461.us-east-1.elb.amazonaws.com"
CLOUDFRONT_DIST_ID="EJVDEMX0X00IG"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
DRY_RUN=false
DEACTIVATE_DR=false
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            ;;
        --deactivate-dr)
            DEACTIVATE_DR=true
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
echo "  DISASTER RECOVERY FAILBACK"
echo "  Returning to Primary Region: ${PRIMARY_REGION}"
echo "========================================"
echo ""

# Step 1: Verify AWS credentials
log_info "Verifying AWS credentials..."
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
log_info "Using AWS Account: ${ACCOUNT_ID}"

# Step 2: Check primary region health
log_info "Checking primary region health..."
if ! aws ec2 describe-availability-zones --region ${PRIMARY_REGION} &>/dev/null; then
    log_error "Primary region ${PRIMARY_REGION} is not responding"
    log_error "Cannot failback - primary region must be operational"
    exit 1
fi
log_info "Primary region ${PRIMARY_REGION} is available"

# Step 3: Check primary application health
log_info "Checking primary application health..."

# Check ECS cluster
PRIMARY_CLUSTER_STATUS=$(aws ecs describe-clusters \
    --clusters dev-davidshaevel-cluster \
    --region ${PRIMARY_REGION} \
    --query 'clusters[0].status' \
    --output text 2>/dev/null || echo "INACTIVE")

if [[ "${PRIMARY_CLUSTER_STATUS}" != "ACTIVE" ]]; then
    log_error "Primary ECS cluster is not active (status: ${PRIMARY_CLUSTER_STATUS})"
    exit 1
fi
log_info "Primary ECS cluster is active"

# Check backend service
BACKEND_RUNNING=$(aws ecs describe-services \
    --cluster dev-davidshaevel-cluster \
    --services dev-davidshaevel-backend \
    --region ${PRIMARY_REGION} \
    --query 'services[0].runningCount' \
    --output text 2>/dev/null || echo "0")

if [[ "${BACKEND_RUNNING}" -lt 1 ]]; then
    log_error "Primary backend service has no running tasks"
    exit 1
fi
log_info "Primary backend service: ${BACKEND_RUNNING} running task(s)"

# Check frontend service
FRONTEND_RUNNING=$(aws ecs describe-services \
    --cluster dev-davidshaevel-cluster \
    --services dev-davidshaevel-frontend \
    --region ${PRIMARY_REGION} \
    --query 'services[0].runningCount' \
    --output text 2>/dev/null || echo "0")

if [[ "${FRONTEND_RUNNING}" -lt 1 ]]; then
    log_error "Primary frontend service has no running tasks"
    exit 1
fi
log_info "Primary frontend service: ${FRONTEND_RUNNING} running task(s)"

# Step 4: Check primary ALB health
log_info "Checking primary ALB health..."
PRIMARY_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "http://${PRIMARY_ALB_DNS}/api/health" --connect-timeout 10 2>/dev/null || echo "000")
if [[ "${PRIMARY_HEALTH}" != "200" ]]; then
    log_warn "Primary ALB health check returned: HTTP ${PRIMARY_HEALTH}"
    log_warn "Proceeding with caution - verify primary is truly healthy"
else
    log_info "Primary ALB health check: HTTP ${PRIMARY_HEALTH}"
fi

# Step 5: Get current CloudFront origin
log_info "Checking current CloudFront configuration..."
CURRENT_ORIGIN=$(aws cloudfront get-distribution \
    --id "${CLOUDFRONT_DIST_ID}" \
    --query 'Distribution.DistributionConfig.Origins.Items[0].DomainName' \
    --output text 2>/dev/null || echo "unknown")
log_info "Current CloudFront origin: ${CURRENT_ORIGIN}"

if [[ "${CURRENT_ORIGIN}" == *"us-east-1"* ]]; then
    log_warn "CloudFront is already pointing to us-east-1"
    log_warn "Failback may not be necessary"
fi

# Step 6: Display failback plan
echo ""
echo "========================================"
echo "  FAILBACK PLAN"
echo "========================================"
echo ""
echo "  Current CloudFront origin: ${CURRENT_ORIGIN}"
echo "  Target CloudFront origin:  ${PRIMARY_ALB_DNS}"
echo ""
echo "  Actions:"
echo "    1. Update CloudFront origin to primary ALB"
echo "    2. Invalidate CloudFront cache"
if [[ "${DEACTIVATE_DR}" == "true" ]]; then
    echo "    3. Deactivate DR infrastructure (terraform apply dr_activated=false)"
fi
echo ""
echo "  Manual steps required after script completes:"
echo "    1. Update Cloudflare DNS for grafana.davidshaevel.com"
echo "       Target: ${PRIMARY_ALB_DNS}"
echo ""
echo "========================================"

if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "Dry run complete. Run without --dry-run to proceed."
    exit 0
fi

# Confirm failback
read -p "Proceed with failback to primary? (yes/no): " CONFIRM
if [[ "${CONFIRM}" != "yes" ]]; then
    log_warn "Failback cancelled"
    exit 0
fi

# Step 7: Update CloudFront origin to primary ALB
log_info "Updating CloudFront distribution origin to primary ALB..."

# Get current distribution config
aws cloudfront get-distribution-config --id "${CLOUDFRONT_DIST_ID}" > /tmp/cf-dist-config.json

# Extract ETag for update
ETAG=$(jq -r '.ETag' /tmp/cf-dist-config.json)

# Update origin domain name to primary ALB
jq --arg primary_alb "${PRIMARY_ALB_DNS}" '.DistributionConfig.Origins.Items[0].DomainName = $primary_alb' /tmp/cf-dist-config.json | jq '.DistributionConfig' > /tmp/cf-dist-config-updated.json

# Update the distribution
if aws cloudfront update-distribution --id "${CLOUDFRONT_DIST_ID}" --if-match "${ETAG}" --distribution-config file:///tmp/cf-dist-config-updated.json > /dev/null 2>&1; then
    log_info "CloudFront origin updated to: ${PRIMARY_ALB_DNS}"

    # Invalidate cache
    log_info "Creating CloudFront cache invalidation..."
    aws cloudfront create-invalidation --distribution-id "${CLOUDFRONT_DIST_ID}" --paths "/*" > /dev/null 2>&1
    log_info "Cache invalidation created for all paths"
else
    log_error "Failed to update CloudFront origin"
    log_error "Please update manually: CloudFront > ${CLOUDFRONT_DIST_ID} > Origins"
    exit 1
fi

# Cleanup temp files
rm -f /tmp/cf-dist-config.json /tmp/cf-dist-config-updated.json

# Step 8: Deactivate DR infrastructure (optional)
if [[ "${DEACTIVATE_DR}" == "true" ]]; then
    log_info "Deactivating DR infrastructure..."
    cd "${DR_TERRAFORM_DIR}"

    terraform apply \
        -var="dr_activated=false" \
        -auto-approve

    log_info "DR infrastructure deactivated (Pilot Light mode)"
fi

echo ""
echo "========================================"
echo "  FAILBACK COMPLETE"
echo "========================================"
echo ""
echo "  CloudFront origin: ${PRIMARY_ALB_DNS}"
echo "  CloudFront status: Deploying (~5-10 min)"
echo ""
echo "  MANUAL STEPS REQUIRED:"
echo ""
echo "  1. Update Cloudflare DNS for grafana.davidshaevel.com"
echo "     Log into Cloudflare Dashboard"
echo "     Update CNAME target to: ${PRIMARY_ALB_DNS}"
echo ""
echo "  2. Verify primary application:"
echo "     curl https://davidshaevel.com/api/health"
echo "     curl https://grafana.davidshaevel.com/api/health"
echo ""
if [[ "${DEACTIVATE_DR}" != "true" ]]; then
    echo "  3. (Optional) Deactivate DR infrastructure:"
echo "     cd terraform/environments/dr"
    echo "     terraform apply -var=\"dr_activated=false\""
    echo ""
fi
echo "========================================"

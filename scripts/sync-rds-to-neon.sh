#!/bin/bash
#
# sync-rds-to-neon.sh - Sync AWS RDS database to Neon
#
# Usage: ./scripts/sync-rds-to-neon.sh [--dry-run]
#
# Prerequisites:
#   - NEON_DATABASE_URL environment variable set
#   - AWS CLI configured with appropriate credentials
#   - psql, pg_dump installed
#   - RDS instance must be running
#
# This script:
#   1. Dumps RDS database to S3
#   2. Restores dump to Neon (full replace)
#   3. Verifies row counts match

set -euo pipefail

# Find repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Configuration
DEV_REGION="${AWS_REGION:-us-east-1}"
DEV_TERRAFORM_DIR="${REPO_ROOT}/terraform/environments/dev"
PROJECT_NAME="${PROJECT_NAME:-davidshaevel}"
S3_BUCKET="${PROJECT_NAME}-dev-db-backups"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H-%M-%S")
S3_KEY="rds-dumps/${TIMESTAMP}.dump"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parse arguments
DRY_RUN=false
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            ;;
        -h|--help)
            echo "Usage: $0 [--dry-run]"
            echo ""
            echo "Sync AWS RDS database to Neon (full replace)"
            echo ""
            echo "Options:"
            echo "  --dry-run  Show what would be done without making changes"
            echo "  -h, --help Show this help message"
            exit 0
            ;;
    esac
done

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

mask_url() {
    echo "$1" | sed 's/:\/\/[^:]*:[^@]*@/:\/\/****:****@/'
}

echo ""
echo "========================================"
echo "  SYNC: RDS -> Neon"
echo "  ${TIMESTAMP}"
echo "========================================"
echo ""

if [[ "${DRY_RUN}" == "true" ]]; then
    echo -e "${YELLOW}=== DRY RUN MODE - No changes will be made ===${NC}"
    echo ""
fi

# Step 1: Check prerequisites
log_info "Checking prerequisites..."

if ! command -v psql &> /dev/null; then
    log_error "psql is not installed"
    exit 1
fi

if ! command -v pg_dump &> /dev/null; then
    log_error "pg_dump is not installed"
    exit 1
fi

if [[ -z "${NEON_DATABASE_URL:-}" ]]; then
    log_error "NEON_DATABASE_URL environment variable is not set"
    exit 1
fi

log_info "Prerequisites OK"

# Step 2: Verify AWS credentials
log_info "Verifying AWS credentials..."
ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
log_info "Using AWS Account: ${ACCOUNT_ID}"

# Step 3: Get RDS connection details from Terraform outputs
log_info "Getting RDS connection details..."
cd "${DEV_TERRAFORM_DIR}"

RDS_ENDPOINT=$(terraform output -raw database_endpoint 2>/dev/null)
RDS_PORT=$(terraform output -raw database_port 2>/dev/null)
RDS_DBNAME=$(terraform output -raw database_name 2>/dev/null)
RDS_SECRET_ARN=$(terraform output -raw database_secret_arn 2>/dev/null)

if [[ -z "${RDS_ENDPOINT}" ]]; then
    log_error "Could not get RDS endpoint from Terraform outputs"
    exit 1
fi

# Extract host from endpoint (format: host:port)
RDS_HOST=$(echo "${RDS_ENDPOINT}" | cut -d: -f1)

log_info "RDS Host: ${RDS_HOST}"
log_info "RDS Database: ${RDS_DBNAME}"

# Step 4: Get RDS credentials from Secrets Manager
log_info "Getting RDS credentials from Secrets Manager..."
RDS_SECRET=$(aws secretsmanager get-secret-value \
    --secret-id "${RDS_SECRET_ARN}" \
    --region "${DEV_REGION}" \
    --query 'SecretString' \
    --output text)

RDS_USERNAME=$(echo "${RDS_SECRET}" | jq -r '.username')
RDS_PASSWORD=$(echo "${RDS_SECRET}" | jq -r '.password')

if [[ -z "${RDS_USERNAME}" || "${RDS_USERNAME}" == "null" ]]; then
    log_error "Could not extract username from Secrets Manager"
    exit 1
fi

log_info "RDS Username: ${RDS_USERNAME}"

# Step 5: Get row counts for comparison
log_info "Getting current row counts..."

export PGPASSWORD="${RDS_PASSWORD}"
RDS_COUNT=$(psql -h "${RDS_HOST}" -p "${RDS_PORT}" -U "${RDS_USERNAME}" -d "${RDS_DBNAME}" -t -c "SELECT COUNT(*) FROM projects;" 2>/dev/null | xargs || echo "0")
unset PGPASSWORD
log_info "RDS projects count: ${RDS_COUNT}"

NEON_COUNT=$(psql "${NEON_DATABASE_URL}" -t -c "SELECT COUNT(*) FROM projects;" 2>/dev/null | xargs || echo "0")
log_info "Neon projects count: ${NEON_COUNT}"

# Step 6: Show sync plan
echo ""
echo "========================================"
echo "  SYNC PLAN"
echo "========================================"
echo ""
echo "  Source: RDS (${RDS_HOST})"
echo "  Target: Neon ($(mask_url "${NEON_DATABASE_URL}"))"
echo "  S3 Dump: s3://${S3_BUCKET}/${S3_KEY}"
echo ""
echo "  RDS rows:  ${RDS_COUNT}"
echo "  Neon rows: ${NEON_COUNT} (will be replaced)"
echo ""
echo "========================================"

if [[ "${DRY_RUN}" == "true" ]]; then
    echo ""
    log_info "Dry run complete. Run without --dry-run to sync."
    exit 0
fi

# Step 7: Dump RDS to local temp file
log_info "Dumping RDS database..."
TEMP_DUMP=$(mktemp)
trap 'rm -f "${TEMP_DUMP}"' EXIT

export PGPASSWORD="${RDS_PASSWORD}"
pg_dump \
    --host="${RDS_HOST}" \
    --port="${RDS_PORT}" \
    --username="${RDS_USERNAME}" \
    --dbname="${RDS_DBNAME}" \
    --format=custom \
    --no-owner \
    --no-acl \
    --file="${TEMP_DUMP}"
unset PGPASSWORD

DUMP_SIZE=$(ls -lh "${TEMP_DUMP}" | awk '{print $5}')
log_info "Dump created: ${DUMP_SIZE}"

# Step 8: Upload to S3
log_info "Uploading to S3..."
aws s3 cp "${TEMP_DUMP}" "s3://${S3_BUCKET}/${S3_KEY}" --region "${DEV_REGION}"
log_info "Uploaded to s3://${S3_BUCKET}/${S3_KEY}"

# Step 9: Restore to Neon
log_info "Restoring to Neon..."

# Neon requires special handling - drop and recreate tables
# pg_restore with --clean works but may need retries
pg_restore \
    "${NEON_DATABASE_URL}" \
    --clean \
    --if-exists \
    --no-owner \
    --no-acl \
    "${TEMP_DUMP}" 2>&1 || true  # pg_restore returns non-zero on warnings

# Step 10: Verify sync
log_info "Verifying sync..."
NEON_COUNT_AFTER=$(psql "${NEON_DATABASE_URL}" -t -c "SELECT COUNT(*) FROM projects;" | xargs)

echo ""
echo "========================================"
echo "  SYNC COMPLETE"
echo "========================================"
echo ""
echo "  RDS rows:        ${RDS_COUNT}"
echo "  Neon rows after: ${NEON_COUNT_AFTER}"
echo "  S3 backup:       s3://${S3_BUCKET}/${S3_KEY}"
echo ""

if [[ "${RDS_COUNT}" == "${NEON_COUNT_AFTER}" ]]; then
    log_info "Row counts match - sync successful!"
else
    log_warn "Row counts differ - verify data manually"
fi

echo "========================================"

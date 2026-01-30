# Data Sync & Dev Validation Implementation Plan

**Goal:** Implement bidirectional database sync between Neon and RDS, plus a dev environment validation script.

**Architecture:** Full replace sync using pg_dump/pg_restore with S3 as intermediate storage. Scripts integrate with existing dev-activate.sh and dev-deactivate.sh via optional `--sync-data` flag.

**Tech Stack:** Bash, AWS CLI, PostgreSQL (psql, pg_dump, pg_restore), Terraform

---

## Task 1: Add S3 Bucket for Database Backups (Terraform)

**Files:**
- Modify: `terraform/environments/dev/main.tf` (after ECR repos, ~line 130)
- Modify: `terraform/environments/dev/outputs.tf` (add new outputs)

**Step 1: Add S3 bucket resources to main.tf**

Add after the ECR lifecycle policies (search for `aws_ecr_lifecycle_policy.grafana`):

```hcl
# Database Backups S3 Bucket - Always on for data sync
resource "aws_s3_bucket" "db_backups" {
  bucket = "${var.project_name}-dev-db-backups"

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-dev-db-backups"
    Purpose = "Database sync dumps between Neon and RDS"
  })
}

resource "aws_s3_bucket_lifecycle_configuration" "db_backups" {
  bucket = aws_s3_bucket.db_backups.id

  rule {
    id     = "expire-old-dumps"
    status = "Enabled"

    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_public_access_block" "db_backups" {
  bucket = aws_s3_bucket.db_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "db_backups" {
  bucket = aws_s3_bucket.db_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

**Step 2: Add outputs to outputs.tf**

Add at the end of the file:

```hcl
# -----------------------------------------------------------------------------
# Database Backup Outputs (Always-on)
# -----------------------------------------------------------------------------

output "db_backups_bucket_name" {
  description = "Name of the S3 bucket for database backup dumps"
  value       = aws_s3_bucket.db_backups.id
}

output "db_backups_bucket_arn" {
  description = "ARN of the S3 bucket for database backup dumps"
  value       = aws_s3_bucket.db_backups.arn
}
```

**Step 3: Validate Terraform**

Run: `cd terraform/environments/dev && terraform validate`
Expected: Success

**Step 4: Apply Terraform to create bucket**

Run: `terraform apply -target=aws_s3_bucket.db_backups -target=aws_s3_bucket_lifecycle_configuration.db_backups -target=aws_s3_bucket_public_access_block.db_backups -target=aws_s3_bucket_server_side_encryption_configuration.db_backups`
Expected: 4 resources created

**Step 5: Commit**

```bash
git add terraform/environments/dev/main.tf terraform/environments/dev/outputs.tf
git commit -m "feat(TT-98): Add S3 bucket for database sync backups

Always-on bucket with 30-day lifecycle, encryption, and public access blocked."
```

---

## Task 2: Create sync-neon-to-rds.sh Script (TT-98)

**Files:**
- Create: `scripts/sync-neon-to-rds.sh`

**Step 1: Create the script**

```bash
#!/bin/bash
#
# sync-neon-to-rds.sh - Sync Neon database to AWS RDS
#
# Usage: ./scripts/sync-neon-to-rds.sh [--dry-run]
#
# Prerequisites:
#   - NEON_DATABASE_URL environment variable set
#   - AWS CLI configured with appropriate credentials
#   - psql, pg_dump installed
#   - RDS instance must be running
#
# This script:
#   1. Dumps Neon database to S3
#   2. Restores dump to RDS (full replace)
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
S3_KEY="neon-dumps/${TIMESTAMP}.dump"

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
            echo "Sync Neon database to AWS RDS (full replace)"
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
echo "  SYNC: Neon → RDS"
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

NEON_COUNT=$(psql "${NEON_DATABASE_URL}" -t -c "SELECT COUNT(*) FROM projects;" 2>/dev/null | xargs || echo "0")
log_info "Neon projects count: ${NEON_COUNT}"

# Build RDS connection string for psql
export PGPASSWORD="${RDS_PASSWORD}"
RDS_COUNT=$(psql -h "${RDS_HOST}" -p "${RDS_PORT}" -U "${RDS_USERNAME}" -d "${RDS_DBNAME}" -t -c "SELECT COUNT(*) FROM projects;" 2>/dev/null | xargs || echo "0")
log_info "RDS projects count: ${RDS_COUNT}"

# Step 6: Show sync plan
echo ""
echo "========================================"
echo "  SYNC PLAN"
echo "========================================"
echo ""
echo "  Source: Neon ($(mask_url "${NEON_DATABASE_URL}"))"
echo "  Target: RDS (${RDS_HOST})"
echo "  S3 Dump: s3://${S3_BUCKET}/${S3_KEY}"
echo ""
echo "  Neon rows: ${NEON_COUNT}"
echo "  RDS rows:  ${RDS_COUNT} (will be replaced)"
echo ""
echo "========================================"

if [[ "${DRY_RUN}" == "true" ]]; then
    echo ""
    log_info "Dry run complete. Run without --dry-run to sync."
    exit 0
fi

# Step 7: Dump Neon to local temp file
log_info "Dumping Neon database..."
TEMP_DUMP=$(mktemp)
trap "rm -f ${TEMP_DUMP}" EXIT

pg_dump "${NEON_DATABASE_URL}" \
    --format=custom \
    --no-owner \
    --no-acl \
    --file="${TEMP_DUMP}"

DUMP_SIZE=$(ls -lh "${TEMP_DUMP}" | awk '{print $5}')
log_info "Dump created: ${DUMP_SIZE}"

# Step 8: Upload to S3
log_info "Uploading to S3..."
aws s3 cp "${TEMP_DUMP}" "s3://${S3_BUCKET}/${S3_KEY}" --region "${DEV_REGION}"
log_info "Uploaded to s3://${S3_BUCKET}/${S3_KEY}"

# Step 9: Restore to RDS
log_info "Restoring to RDS..."
pg_restore \
    --host="${RDS_HOST}" \
    --port="${RDS_PORT}" \
    --username="${RDS_USERNAME}" \
    --dbname="${RDS_DBNAME}" \
    --clean \
    --if-exists \
    --no-owner \
    --no-acl \
    "${TEMP_DUMP}" 2>&1 || true  # pg_restore returns non-zero on warnings

# Step 10: Verify sync
log_info "Verifying sync..."
RDS_COUNT_AFTER=$(psql -h "${RDS_HOST}" -p "${RDS_PORT}" -U "${RDS_USERNAME}" -d "${RDS_DBNAME}" -t -c "SELECT COUNT(*) FROM projects;" | xargs)

echo ""
echo "========================================"
echo "  SYNC COMPLETE"
echo "========================================"
echo ""
echo "  Neon rows:      ${NEON_COUNT}"
echo "  RDS rows after: ${RDS_COUNT_AFTER}"
echo "  S3 backup:      s3://${S3_BUCKET}/${S3_KEY}"
echo ""

if [[ "${NEON_COUNT}" == "${RDS_COUNT_AFTER}" ]]; then
    log_info "Row counts match - sync successful!"
else
    log_warn "Row counts differ - verify data manually"
fi

echo "========================================"
```

**Step 2: Make executable**

Run: `chmod +x scripts/sync-neon-to-rds.sh`

**Step 3: Test dry-run**

Run: `./scripts/sync-neon-to-rds.sh --dry-run`
Expected: Shows sync plan without making changes

**Step 4: Commit**

```bash
git add scripts/sync-neon-to-rds.sh
git commit -m "feat(TT-98): Add sync-neon-to-rds.sh script

Syncs Neon database to RDS using pg_dump/pg_restore.
- Dumps to S3 for backup/audit trail
- Full replace strategy
- Supports --dry-run mode
- Verifies row counts after sync"
```

---

## Task 3: Create sync-rds-to-neon.sh Script (TT-99)

**Files:**
- Create: `scripts/sync-rds-to-neon.sh`

**Step 1: Create the script**

```bash
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
echo "  SYNC: RDS → Neon"
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
trap "rm -f ${TEMP_DUMP}" EXIT

pg_dump \
    --host="${RDS_HOST}" \
    --port="${RDS_PORT}" \
    --username="${RDS_USERNAME}" \
    --dbname="${RDS_DBNAME}" \
    --format=custom \
    --no-owner \
    --no-acl \
    --file="${TEMP_DUMP}"

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
echo "  RDS rows:       ${RDS_COUNT}"
echo "  Neon rows after: ${NEON_COUNT_AFTER}"
echo "  S3 backup:       s3://${S3_BUCKET}/${S3_KEY}"
echo ""

if [[ "${RDS_COUNT}" == "${NEON_COUNT_AFTER}" ]]; then
    log_info "Row counts match - sync successful!"
else
    log_warn "Row counts differ - verify data manually"
fi

echo "========================================"
```

**Step 2: Make executable**

Run: `chmod +x scripts/sync-rds-to-neon.sh`

**Step 3: Test dry-run**

Run: `./scripts/sync-rds-to-neon.sh --dry-run`
Expected: Shows sync plan without making changes

**Step 4: Commit**

```bash
git add scripts/sync-rds-to-neon.sh
git commit -m "feat(TT-99): Add sync-rds-to-neon.sh script

Syncs RDS database to Neon using pg_dump/pg_restore.
- Dumps to S3 for backup/audit trail
- Full replace strategy
- Supports --dry-run mode
- Verifies row counts after sync"
```

---

## Task 4: Create dev-validation.sh Script (TT-132)

**Files:**
- Create: `scripts/dev-validation.sh`

**Step 1: Create the script**

```bash
#!/bin/bash
#
# Dev Validation Script
# Validates that the dev environment is healthy and operational
#
# Usage: ./dev-validation.sh [--verbose]
#

set -euo pipefail

# Find repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Configuration
DEV_REGION="${AWS_REGION:-us-east-1}"
DEV_TERRAFORM_DIR="${REPO_ROOT}/terraform/environments/dev"
PROJECT_NAME="${PROJECT_NAME:-davidshaevel}"

# ECR repositories to validate
ECR_REPOS=("backend" "frontend" "grafana")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VERBOSE=false
if [[ "${1:-}" == "--verbose" ]]; then
    VERBOSE=true
fi

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; WARN_COUNT=$((WARN_COUNT + 1)); }
log_info() { echo -e "[INFO] $1"; }

echo ""
echo "========================================"
echo "  DEV ENVIRONMENT VALIDATION"
echo "  Region: ${DEV_REGION}"
echo "========================================"
echo ""

# Check 1: AWS Credentials
log_info "Checking AWS credentials..."
if aws sts get-caller-identity &>/dev/null; then
    log_pass "AWS credentials valid"
else
    log_fail "AWS credentials invalid"
    exit 1
fi

# Check 2: Terraform state
log_info "Checking Terraform state..."
cd "${DEV_TERRAFORM_DIR}"
if terraform show &>/dev/null; then
    DEV_ACTIVATED=$(terraform output -raw dev_activated 2>/dev/null || echo "false")
    if [[ "${DEV_ACTIVATED}" == "true" ]]; then
        log_pass "Dev infrastructure is activated (full mode)"
    else
        log_pass "Dev infrastructure is in Pilot Light mode"
    fi
else
    log_fail "Cannot read Terraform state"
fi

# Check 3: ECR Repositories
log_info "Checking ECR repositories..."
for repo in "${ECR_REPOS[@]}"; do
    if aws ecr describe-repositories --repository-names "${PROJECT_NAME}/${repo}" --region ${DEV_REGION} &>/dev/null; then
        IMAGE_COUNT=$(aws ecr describe-images --repository-name "${PROJECT_NAME}/${repo}" --region ${DEV_REGION} --query 'length(imageDetails)' --output text 2>/dev/null || echo "0")
        log_pass "ECR repo ${PROJECT_NAME}/${repo} exists (${IMAGE_COUNT} images)"
    else
        log_fail "ECR repo ${PROJECT_NAME}/${repo} not found"
    fi
done

# Check 4: S3 Buckets
log_info "Checking S3 buckets..."
DB_BACKUPS_BUCKET="${PROJECT_NAME}-dev-db-backups"
if aws s3api head-bucket --bucket "${DB_BACKUPS_BUCKET}" --region ${DEV_REGION} &>/dev/null; then
    log_pass "S3 bucket ${DB_BACKUPS_BUCKET} exists"
else
    log_warn "S3 bucket ${DB_BACKUPS_BUCKET} not found (run terraform apply)"
fi

# Check 5: RDS Instance
log_info "Checking RDS instance..."
RDS_INSTANCE_ID="${PROJECT_NAME}-dev-db"
RDS_STATUS=$(aws rds describe-db-instances \
    --db-instance-identifier "${RDS_INSTANCE_ID}" \
    --region ${DEV_REGION} \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text 2>/dev/null || echo "not-found")

if [[ "${RDS_STATUS}" == "available" ]]; then
    log_pass "RDS instance ${RDS_INSTANCE_ID} is available"
else
    log_fail "RDS instance status: ${RDS_STATUS}"
fi

# Check 6: VPC
log_info "Checking VPC..."
VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
if [[ -n "${VPC_ID}" ]]; then
    VPC_STATE=$(aws ec2 describe-vpcs --vpc-ids "${VPC_ID}" --region ${DEV_REGION} --query 'Vpcs[0].State' --output text 2>/dev/null || echo "")
    if [[ "${VPC_STATE}" == "available" ]]; then
        log_pass "VPC ${VPC_ID} is available"
    else
        log_fail "VPC ${VPC_ID} state: ${VPC_STATE}"
    fi
else
    log_fail "VPC not found in Terraform outputs"
fi

# Checks 7-12: Only run if dev is activated
if [[ "${DEV_ACTIVATED:-false}" == "true" ]]; then
    # Check 7: ECS Cluster
    log_info "Checking ECS cluster..."
    CLUSTER_NAME=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "")
    if [[ -n "${CLUSTER_NAME}" ]]; then
        CLUSTER_STATUS=$(aws ecs describe-clusters \
            --clusters "${CLUSTER_NAME}" \
            --region ${DEV_REGION} \
            --query 'clusters[0].status' \
            --output text 2>/dev/null || echo "")
        if [[ "${CLUSTER_STATUS}" == "ACTIVE" ]]; then
            log_pass "ECS cluster ${CLUSTER_NAME} is active"
        else
            log_fail "ECS cluster status: ${CLUSTER_STATUS:-unknown}"
        fi
    fi

    # Check 8: ECS Services
    log_info "Checking ECS services..."
    FRONTEND_SVC=$(terraform output -raw frontend_service_name 2>/dev/null || echo "")
    BACKEND_SVC=$(terraform output -raw backend_service_name 2>/dev/null || echo "")
    GRAFANA_SVC=$(terraform output -raw grafana_service_name 2>/dev/null || echo "")

    for svc in "${FRONTEND_SVC}" "${BACKEND_SVC}" "${GRAFANA_SVC}"; do
        [[ -z "${svc}" ]] && continue
        SVC_STATUS=$(aws ecs describe-services \
            --cluster "${CLUSTER_NAME}" \
            --services "${svc}" \
            --region ${DEV_REGION} \
            --query 'services[0].status' \
            --output text 2>/dev/null || echo "")
        if [[ "${SVC_STATUS}" == "ACTIVE" ]]; then
            RUNNING=$(aws ecs describe-services \
                --cluster "${CLUSTER_NAME}" \
                --services "${svc}" \
                --region ${DEV_REGION} \
                --query 'services[0].runningCount' \
                --output text 2>/dev/null || echo "0")
            if [[ "${RUNNING}" -ge 1 ]]; then
                log_pass "ECS ${svc}: ${RUNNING} running task(s)"
            else
                log_warn "ECS ${svc}: 0 running tasks"
            fi
        else
            log_fail "ECS ${svc} status: ${SVC_STATUS:-unknown}"
        fi
    done

    # Check 9: ALB Health
    log_info "Checking ALB health..."
    ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
    if [[ -n "${ALB_DNS}" ]]; then
        HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" "https://${ALB_DNS}/api/health" --connect-timeout 5 2>/dev/null || echo "000")
        if [[ "${HTTP_CODE}" == "200" ]]; then
            log_pass "ALB health check: HTTPS ${HTTP_CODE}"
        else
            log_warn "ALB health check: HTTPS ${HTTP_CODE}"
        fi
    fi

    # Check 10: CloudFront
    log_info "Checking CloudFront distribution..."
    CF_DIST_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")
    if [[ -n "${CF_DIST_ID}" ]]; then
        CF_STATUS=$(aws cloudfront get-distribution \
            --id "${CF_DIST_ID}" \
            --query 'Distribution.Status' \
            --output text 2>/dev/null || echo "unknown")
        if [[ "${CF_STATUS}" == "Deployed" ]]; then
            log_pass "CloudFront ${CF_DIST_ID}: ${CF_STATUS}"
        else
            log_warn "CloudFront ${CF_DIST_ID}: ${CF_STATUS}"
        fi
    fi

    # Check 11: Service Discovery
    log_info "Checking service discovery..."
    SD_NAMESPACE=$(aws servicediscovery list-namespaces \
        --region ${DEV_REGION} \
        --query "Namespaces[?Name=='${PROJECT_NAME}.local'].Id" \
        --output text 2>/dev/null || echo "")
    if [[ -n "${SD_NAMESPACE}" ]]; then
        log_pass "Service discovery namespace: ${PROJECT_NAME}.local"
    else
        log_warn "Service discovery namespace not found"
    fi
fi

# Summary
echo ""
echo "========================================"
echo "  VALIDATION SUMMARY"
echo "========================================"
echo ""
if [[ "${DEV_ACTIVATED:-false}" == "true" ]]; then
    echo -e "  Mode:      ${GREEN}Full (activated)${NC}"
else
    echo -e "  Mode:      ${YELLOW}Pilot Light${NC}"
fi
echo -e "  ${GREEN}Passed:${NC}   ${PASS_COUNT}"
echo -e "  ${YELLOW}Warnings:${NC} ${WARN_COUNT}"
echo -e "  ${RED}Failed:${NC}   ${FAIL_COUNT}"
echo ""

if [[ ${FAIL_COUNT} -gt 0 ]]; then
    echo -e "${RED}Dev environment has failures - investigate before using${NC}"
    exit 1
elif [[ ${WARN_COUNT} -gt 0 ]]; then
    echo -e "${YELLOW}Dev environment has warnings - review before activation${NC}"
    exit 0
else
    if [[ "${DEV_ACTIVATED:-false}" == "true" ]]; then
        echo -e "${GREEN}Dev environment is healthy and fully activated${NC}"
    else
        echo -e "${GREEN}Dev Pilot Light components are healthy${NC}"
    fi
    exit 0
fi
```

**Step 2: Make executable**

Run: `chmod +x scripts/dev-validation.sh`

**Step 3: Test the script**

Run: `./scripts/dev-validation.sh`
Expected: Shows validation results for current state

**Step 4: Commit**

```bash
git add scripts/dev-validation.sh
git commit -m "feat(TT-132): Add dev-validation.sh script

Validates dev environment health for both pilot light and active modes.
- Checks AWS credentials, Terraform state
- Validates ECR repos, S3 buckets, RDS, VPC
- When activated: checks ECS services, ALB, CloudFront, service discovery
- Outputs summary with pass/warn/fail counts"
```

---

## Task 5: Add --sync-data Flag to dev-activate.sh (TT-128)

**Files:**
- Modify: `scripts/dev-activate.sh`

**Step 1: Add --sync-data flag parsing**

Find the argument parsing section (around line 43-54) and add `--sync-data`:

```bash
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
```

**Step 2: Add sync step after RDS check**

Find the "Step 5: Check RDS status" section (around line 126-138) and add after it:

```bash
# Step 6: Sync data from Neon to RDS (optional)
if [[ "${SYNC_DATA}" == "true" ]]; then
    echo ""
    log_info "Syncing data from Neon to RDS..."
    SYNC_FLAGS=()
    if [[ "${DRY_RUN}" == "true" ]]; then
        SYNC_FLAGS+=(--dry-run)
    fi
    "${SCRIPT_DIR}/sync-neon-to-rds.sh" "${SYNC_FLAGS[@]}"

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "Sync dry-run complete"
    else
        log_info "Data sync complete"
    fi
    echo ""
fi
```

**Step 3: Update usage comment at top of file**

Update the header comment:

```bash
# Usage: ./dev-activate.sh [--dry-run] [--yes] [--sync-data]
#
# Options:
#   --dry-run    Show what would be done without making changes
#   --yes        Skip confirmation prompts (use with caution)
#   --sync-data  Sync Neon database to RDS before activation
```

**Step 4: Update activation plan display**

Find the "ACTIVATION PLAN" section and add sync info:

```bash
echo "  Resources to be CREATED:"
echo "    - ECS Cluster and Services (4 services)"
# ... existing lines ...

if [[ "${SYNC_DATA}" == "true" ]]; then
    echo ""
    echo "  Data Sync: Neon → RDS (before Terraform)"
fi
```

**Step 5: Test**

Run: `./scripts/dev-activate.sh --sync-data --dry-run`
Expected: Shows sync dry-run output followed by Terraform plan

**Step 6: Commit**

```bash
git add scripts/dev-activate.sh
git commit -m "feat(TT-128): Add --sync-data flag to dev-activate.sh

Optionally syncs Neon database to RDS before activation.
- --sync-data: runs sync-neon-to-rds.sh before Terraform
- --sync-data --dry-run: runs sync in dry-run mode"
```

---

## Task 6: Add --sync-data Flag to dev-deactivate.sh (TT-128)

**Files:**
- Modify: `scripts/dev-deactivate.sh`

**Step 1: Add --sync-data flag parsing**

Find the argument parsing section (around line 43-54) and add `--sync-data`:

```bash
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
```

**Step 2: Add sync step after confirmation, before Terraform**

Find the confirmation section (around line 144-151) and add after it, before "Step 5: Run Terraform apply":

```bash
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

# Step 6: Run Terraform apply (renumber from Step 5)
```

**Step 3: Update usage comment at top of file**

Update the header comment:

```bash
# Usage: ./dev-deactivate.sh [--dry-run] [--yes] [--sync-data]
#
# Options:
#   --dry-run    Show what would be done without making changes
#   --yes        Skip confirmation prompts (use with caution)
#   --sync-data  Sync RDS database to Neon before deactivation
```

**Step 4: Update deactivation plan display**

Find the "DEACTIVATION PLAN" section and add sync info:

```bash
echo "  Resources to be DESTROYED:"
# ... existing lines ...

if [[ "${SYNC_DATA}" == "true" ]]; then
    echo ""
    echo "  Data Sync: RDS → Neon (before Terraform)"
fi
```

**Step 5: Test**

Run: `./scripts/dev-deactivate.sh --sync-data --dry-run`
Expected: Shows sync dry-run output followed by Terraform plan

**Step 6: Commit**

```bash
git add scripts/dev-deactivate.sh
git commit -m "feat(TT-128): Add --sync-data flag to dev-deactivate.sh

Optionally syncs RDS database to Neon before deactivation.
- --sync-data: runs sync-rds-to-neon.sh before Terraform
- --sync-data --dry-run: runs sync in dry-run mode"
```

---

## Task 7: End-to-End Testing

**Step 1: Run dev-validation.sh**

Run: `./scripts/dev-validation.sh`
Expected: All checks pass or warn (no failures)

**Step 2: Test sync-neon-to-rds.sh dry-run**

Run: `./scripts/sync-neon-to-rds.sh --dry-run`
Expected: Shows sync plan with row counts

**Step 3: Test sync-rds-to-neon.sh dry-run**

Run: `./scripts/sync-rds-to-neon.sh --dry-run`
Expected: Shows sync plan with row counts

**Step 4: Test dev-activate.sh with sync dry-run**

Run: `./scripts/dev-activate.sh --sync-data --dry-run`
Expected: Shows sync dry-run, then Terraform plan

**Step 5: Test dev-deactivate.sh with sync dry-run**

Run: `./scripts/dev-deactivate.sh --sync-data --dry-run`
Expected: Shows sync dry-run, then Terraform plan

**Step 6: Document results**

Note any issues or adjustments needed.

---

## Task 8: Create Pull Request

**Step 1: Push branch**

```bash
git push -u origin claude/tt-98-data-sync-validation
```

**Step 2: Create PR**

```bash
gh pr create --title "feat: Add database sync and dev validation scripts" --body "$(cat <<'EOF'
## Summary
- Adds bidirectional database sync between Neon and RDS
- Adds dev environment validation script
- Integrates sync into activate/deactivate scripts

## Changes
- **TT-98**: `sync-neon-to-rds.sh` - Syncs Neon → RDS
- **TT-99**: `sync-rds-to-neon.sh` - Syncs RDS → Neon
- **TT-132**: `dev-validation.sh` - Validates dev environment health
- **TT-128**: `--sync-data` flag for dev-activate.sh and dev-deactivate.sh
- **Terraform**: S3 bucket for database backups (always-on)

## Test plan
- [ ] `./scripts/dev-validation.sh` passes
- [ ] `./scripts/sync-neon-to-rds.sh --dry-run` shows correct plan
- [ ] `./scripts/sync-rds-to-neon.sh --dry-run` shows correct plan
- [ ] `./scripts/dev-activate.sh --sync-data --dry-run` works
- [ ] `./scripts/dev-deactivate.sh --sync-data --dry-run` works
- [ ] S3 bucket created via Terraform

## Related issues
- TT-98: Create sync-neon-to-rds.sh script
- TT-99: Create sync-rds-to-neon.sh script
- TT-128: Add Neon/RDS data sync integration
- TT-132: Create dev-validation.sh script

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Notes

- All scripts support `--dry-run` for safe testing
- S3 bucket has 30-day lifecycle for automatic cleanup
- Sync scripts use pg_dump custom format for efficiency
- dev-validation.sh adapts checks based on dev_activated state
- Row count verification ensures sync integrity

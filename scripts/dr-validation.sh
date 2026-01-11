#!/bin/bash
#
# DR Validation Script
# Validates that the DR environment is healthy and operational
#
# Usage: ./dr-validation.sh [--verbose]
#

set -euo pipefail

# Find repo root (directory containing .git or terraform/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Configuration
DR_REGION="us-west-2"
DR_TERRAFORM_DIR="${REPO_ROOT}/terraform/environments/dr"

# ECR repositories to validate (add new repos here when services are added)
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
echo "  DR ENVIRONMENT VALIDATION"
echo "  Region: ${DR_REGION}"
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
cd "${DR_TERRAFORM_DIR}"
if terraform show &>/dev/null; then
    DR_ACTIVATED=$(terraform output -raw dr_activated 2>/dev/null || echo "false")
    if [[ "${DR_ACTIVATED}" == "true" ]]; then
        log_pass "DR infrastructure is activated"
    else
        log_warn "DR is in Pilot Light mode (not fully activated)"
    fi
else
    log_fail "Cannot read Terraform state"
fi

# Check 3: KMS Key
log_info "Checking DR KMS key..."
KMS_ALIAS="alias/dr-davidshaevel-dr"
if aws kms describe-key --key-id "${KMS_ALIAS}" --region ${DR_REGION} &>/dev/null; then
    log_pass "KMS key exists: ${KMS_ALIAS}"
else
    log_fail "KMS key not found: ${KMS_ALIAS}"
fi

# Check 4: ECR Repositories
log_info "Checking ECR repositories in ${DR_REGION}..."
for repo in "${ECR_REPOS[@]}"; do
    if aws ecr describe-repositories --repository-names "davidshaevel/${repo}" --region ${DR_REGION} &>/dev/null; then
        IMAGE_COUNT=$(aws ecr describe-images --repository-name "davidshaevel/${repo}" --region ${DR_REGION} --query 'length(imageDetails)' --output text 2>/dev/null || echo "0")
        log_pass "ECR repo davidshaevel/${repo} exists (${IMAGE_COUNT} images)"
    else
        log_fail "ECR repo davidshaevel/${repo} not found"
    fi
done

# Check 5: DR Snapshots
log_info "Checking DR snapshots..."
SNAPSHOT_COUNT=$(aws rds describe-db-snapshots \
    --region ${DR_REGION} \
    --snapshot-type manual \
    --query "length(DBSnapshots[?starts_with(DBSnapshotIdentifier, \`davidshaevel-dev-db-dr-\`)])" \
    --output text 2>/dev/null || echo "0")

if [[ "${SNAPSHOT_COUNT}" -gt 0 ]]; then
    LATEST_SNAPSHOT=$(aws rds describe-db-snapshots \
        --region ${DR_REGION} \
        --snapshot-type manual \
        --query "DBSnapshots[?starts_with(DBSnapshotIdentifier, \`davidshaevel-dev-db-dr-\`)] | sort_by(@, &SnapshotCreateTime) | [-1].{ID:DBSnapshotIdentifier,Status:Status}" \
        --output json 2>/dev/null)
    log_pass "DR snapshots available: ${SNAPSHOT_COUNT}"
    if [[ "${VERBOSE}" == "true" ]]; then
        echo "      Latest: $(echo ${LATEST_SNAPSHOT} | jq -r '.ID')"
        echo "      Status: $(echo ${LATEST_SNAPSHOT} | jq -r '.Status')"
    fi
else
    log_warn "No DR snapshots found - Lambda may not have triggered yet"
fi

# Check 6: Lambda Function
log_info "Checking snapshot copy Lambda..."
LAMBDA_STATE=$(aws lambda get-function \
    --function-name dr-davidshaevel-dr-snapshot-copy \
    --region us-east-1 \
    --query 'Configuration.State' \
    --output text 2>/dev/null || echo "NotFound")

if [[ "${LAMBDA_STATE}" == "Active" ]]; then
    log_pass "Snapshot copy Lambda is active"
else
    log_fail "Snapshot copy Lambda state: ${LAMBDA_STATE}"
fi

# Check 7: EventBridge Rule
log_info "Checking EventBridge rule..."
RULE_STATE=$(aws events describe-rule \
    --name dr-davidshaevel-dr-snapshot-trigger \
    --region us-east-1 \
    --query 'State' \
    --output text 2>/dev/null || echo "NotFound")

if [[ "${RULE_STATE}" == "ENABLED" ]]; then
    log_pass "EventBridge rule is enabled"
else
    log_fail "EventBridge rule state: ${RULE_STATE}"
fi

# Check 8: VPC (only if DR activated)
if [[ "${DR_ACTIVATED:-false}" == "true" ]]; then
    log_info "Checking DR VPC..."
    VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
    if [[ -n "${VPC_ID}" ]]; then
        VPC_STATE=$(aws ec2 describe-vpcs --vpc-ids "${VPC_ID}" --region ${DR_REGION} --query 'Vpcs[0].State' --output text 2>/dev/null || echo "")
        if [[ "${VPC_STATE}" == "available" ]]; then
            log_pass "VPC ${VPC_ID} is available"
        else
            log_fail "VPC ${VPC_ID} state: ${VPC_STATE}"
        fi
    fi

    # Check 9: RDS
    log_info "Checking DR RDS instance..."
    DB_ENDPOINT=$(terraform output -raw database_endpoint 2>/dev/null || echo "")
    if [[ -n "${DB_ENDPOINT}" ]]; then
        # Extract DB identifier from endpoint (format: <identifier>.<random>.region.rds.amazonaws.com:port)
        DB_HOST=$(echo "${DB_ENDPOINT}" | cut -d: -f1)
        DB_IDENTIFIER=$(echo "${DB_HOST}" | cut -d. -f1)
        DB_STATUS=$(aws rds describe-db-instances \
            --db-instance-identifier "${DB_IDENTIFIER}" \
            --region ${DR_REGION} \
            --query 'DBInstances[0].DBInstanceStatus' \
            --output text 2>/dev/null || echo "unknown")
        if [[ "${DB_STATUS}" == "available" ]]; then
            log_pass "RDS instance ${DB_IDENTIFIER} is available"
        else
            log_warn "RDS instance status: ${DB_STATUS}"
        fi
    else
        log_warn "RDS instance not configured"
    fi

    # Check 10: ECS Services
    log_info "Checking ECS services..."
    CLUSTER_NAME=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "")
    FRONTEND_SVC=$(terraform output -raw frontend_service_name 2>/dev/null || echo "")
    BACKEND_SVC=$(terraform output -raw backend_service_name 2>/dev/null || echo "")
    if [[ -n "${CLUSTER_NAME}" ]]; then
        for svc in "${FRONTEND_SVC}" "${BACKEND_SVC}"; do
            [[ -z "${svc}" ]] && continue
            SVC_STATUS=$(aws ecs describe-services \
                --cluster "${CLUSTER_NAME}" \
                --services "${svc}" \
                --region ${DR_REGION} \
                --query 'services[0].status' \
                --output text 2>/dev/null || echo "")
            if [[ "${SVC_STATUS}" == "ACTIVE" ]]; then
                RUNNING=$(aws ecs describe-services \
                    --cluster "${CLUSTER_NAME}" \
                    --services "${svc}" \
                    --region ${DR_REGION} \
                    --query 'services[0].runningCount' \
                    --output text 2>/dev/null || echo "0")
                log_pass "ECS ${svc}: ${RUNNING} running tasks"
            else
                log_fail "ECS ${svc} status: ${SVC_STATUS:-unknown}"
            fi
        done
    fi

    # Check 11: ALB Health (via HTTPS, skipping cert validation for raw ALB DNS)
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

    # Check 12: Prometheus Service
    log_info "Checking Prometheus service..."
    PROMETHEUS_SVC=$(terraform output -raw prometheus_service_name 2>/dev/null || echo "")
    if [[ -n "${PROMETHEUS_SVC}" && -n "${CLUSTER_NAME}" ]]; then
        PROM_STATUS=$(aws ecs describe-services \
            --cluster "${CLUSTER_NAME}" \
            --services "${PROMETHEUS_SVC}" \
            --region ${DR_REGION} \
            --query 'services[0].status' \
            --output text 2>/dev/null || echo "")
        if [[ "${PROM_STATUS}" == "ACTIVE" ]]; then
            RUNNING=$(aws ecs describe-services \
                --cluster "${CLUSTER_NAME}" \
                --services "${PROMETHEUS_SVC}" \
                --region ${DR_REGION} \
                --query 'services[0].runningCount' \
                --output text 2>/dev/null || echo "0")
            if [[ "${RUNNING}" -ge 1 ]]; then
                log_pass "Prometheus: ${RUNNING} running task(s)"
            else
                log_warn "Prometheus: 0 running tasks"
            fi
        else
            log_fail "Prometheus service status: ${PROM_STATUS:-unknown}"
        fi
    else
        log_warn "Prometheus service not configured"
    fi

    # Check 13: Grafana Service
    log_info "Checking Grafana service..."
    GRAFANA_SVC=$(terraform output -raw grafana_service_name 2>/dev/null || echo "")
    if [[ -n "${GRAFANA_SVC}" && -n "${CLUSTER_NAME}" ]]; then
        GRAF_STATUS=$(aws ecs describe-services \
            --cluster "${CLUSTER_NAME}" \
            --services "${GRAFANA_SVC}" \
            --region ${DR_REGION} \
            --query 'services[0].status' \
            --output text 2>/dev/null || echo "")
        if [[ "${GRAF_STATUS}" == "ACTIVE" ]]; then
            RUNNING=$(aws ecs describe-services \
                --cluster "${CLUSTER_NAME}" \
                --services "${GRAFANA_SVC}" \
                --region ${DR_REGION} \
                --query 'services[0].runningCount' \
                --output text 2>/dev/null || echo "0")
            if [[ "${RUNNING}" -ge 1 ]]; then
                log_pass "Grafana: ${RUNNING} running task(s)"
            else
                log_warn "Grafana: 0 running tasks"
            fi
        else
            log_fail "Grafana service status: ${GRAF_STATUS:-unknown}"
        fi
    else
        log_warn "Grafana service not configured"
    fi

    # Check 14: Service Discovery - Prometheus
    log_info "Checking service discovery registrations..."
    PROMETHEUS_ENDPOINT=$(terraform output -raw prometheus_endpoint 2>/dev/null || echo "")
    if [[ -n "${PROMETHEUS_ENDPOINT}" ]]; then
        # Check if Prometheus is registered in Cloud Map
        PROM_SD_NAMESPACE=$(aws servicediscovery list-namespaces \
            --region ${DR_REGION} \
            --query "Namespaces[?Name=='davidshaevel.local'].Id" \
            --output text 2>/dev/null || echo "")
        if [[ -n "${PROM_SD_NAMESPACE}" ]]; then
            PROM_INSTANCES=$(aws servicediscovery list-instances \
                --service-id "$(aws servicediscovery list-services \
                    --region ${DR_REGION} \
                    --query "Services[?Name=='prometheus'].Id" \
                    --output text 2>/dev/null)" \
                --region ${DR_REGION} \
                --query 'length(Instances)' \
                --output text 2>/dev/null || echo "0")
            if [[ "${PROM_INSTANCES}" -ge 1 ]]; then
                log_pass "Prometheus service discovery: ${PROM_INSTANCES} instance(s)"
            else
                log_warn "Prometheus not registered in service discovery"
            fi
        fi
    fi
fi

# Summary
echo ""
echo "========================================"
echo "  VALIDATION SUMMARY"
echo "========================================"
echo ""
echo -e "  ${GREEN}Passed:${NC}  ${PASS_COUNT}"
echo -e "  ${YELLOW}Warnings:${NC} ${WARN_COUNT}"
echo -e "  ${RED}Failed:${NC}  ${FAIL_COUNT}"
echo ""

if [[ ${FAIL_COUNT} -gt 0 ]]; then
    echo -e "${RED}DR environment has failures - investigate before relying on it${NC}"
    exit 1
elif [[ ${WARN_COUNT} -gt 0 ]]; then
    echo -e "${YELLOW}DR environment has warnings - review before activation${NC}"
    exit 0
else
    echo -e "${GREEN}DR environment is healthy${NC}"
    exit 0
fi

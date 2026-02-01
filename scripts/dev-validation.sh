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
if aws sts get-caller-identity >/dev/null; then
    log_pass "AWS credentials valid"
else
    log_fail "AWS credentials invalid"
    exit 1
fi

# Check 2: Terraform state
log_info "Checking Terraform state..."
if terraform -chdir="${DEV_TERRAFORM_DIR}" show >/dev/null; then
    DEV_ACTIVATED=$(terraform -chdir="${DEV_TERRAFORM_DIR}" output -raw dev_activated 2>/dev/null || echo "false")
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
    if aws ecr describe-repositories --repository-names "${PROJECT_NAME}/${repo}" --region "${DEV_REGION}" >/dev/null; then
        IMAGE_COUNT=$(aws ecr describe-images --repository-name "${PROJECT_NAME}/${repo}" --region "${DEV_REGION}" --query 'length(imageDetails)' --output text 2>/dev/null || echo "0")
        log_pass "ECR repo ${PROJECT_NAME}/${repo} exists (${IMAGE_COUNT} images)"
    else
        log_fail "ECR repo ${PROJECT_NAME}/${repo} not found"
    fi
done

# Check 4: S3 Buckets
log_info "Checking S3 buckets..."
DB_BACKUPS_BUCKET="${PROJECT_NAME}-dev-db-backups"
if aws s3api head-bucket --bucket "${DB_BACKUPS_BUCKET}" --region "${DEV_REGION}" >/dev/null; then
    log_pass "S3 bucket ${DB_BACKUPS_BUCKET} exists"
else
    log_warn "S3 bucket ${DB_BACKUPS_BUCKET} not found (run terraform apply)"
fi

# Check 5: RDS Instance
log_info "Checking RDS instance..."
RDS_INSTANCE_ID="${PROJECT_NAME}-dev-db"
RDS_STATUS=$(aws rds describe-db-instances \
    --db-instance-identifier "${RDS_INSTANCE_ID}" \
    --region "${DEV_REGION}" \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text 2>/dev/null || echo "not-found")

if [[ "${RDS_STATUS}" == "available" ]]; then
    log_pass "RDS instance ${RDS_INSTANCE_ID} is available"
else
    log_fail "RDS instance status: ${RDS_STATUS}"
fi

# Check 6: VPC
log_info "Checking VPC..."
VPC_ID=$(terraform -chdir="${DEV_TERRAFORM_DIR}" output -raw vpc_id 2>/dev/null || echo "")
if [[ -n "${VPC_ID}" ]]; then
    VPC_STATE=$(aws ec2 describe-vpcs --vpc-ids "${VPC_ID}" --region "${DEV_REGION}" --query 'Vpcs[0].State' --output text 2>/dev/null || echo "")
    if [[ "${VPC_STATE}" == "available" ]]; then
        log_pass "VPC ${VPC_ID} is available"
    else
        log_fail "VPC ${VPC_ID} state: ${VPC_STATE}"
    fi
else
    log_fail "VPC not found in Terraform outputs"
fi

# Checks 7-13: Only run if dev is activated
if [[ "${DEV_ACTIVATED:-false}" == "true" ]]; then
    # Check 7: ECS Cluster
    log_info "Checking ECS cluster..."
    CLUSTER_NAME=$(terraform -chdir="${DEV_TERRAFORM_DIR}" output -raw ecs_cluster_name 2>/dev/null || echo "")
    if [[ -n "${CLUSTER_NAME}" ]]; then
        CLUSTER_STATUS=$(aws ecs describe-clusters \
            --clusters "${CLUSTER_NAME}" \
            --region "${DEV_REGION}" \
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
    FRONTEND_SVC=$(terraform -chdir="${DEV_TERRAFORM_DIR}" output -raw frontend_service_name 2>/dev/null || echo "")
    BACKEND_SVC=$(terraform -chdir="${DEV_TERRAFORM_DIR}" output -raw backend_service_name 2>/dev/null || echo "")
    GRAFANA_SVC=$(terraform -chdir="${DEV_TERRAFORM_DIR}" output -raw grafana_service_name 2>/dev/null || echo "")

    for svc in "${FRONTEND_SVC}" "${BACKEND_SVC}" "${GRAFANA_SVC}"; do
        [[ -z "${svc}" ]] && continue
        SVC_STATUS=$(aws ecs describe-services \
            --cluster "${CLUSTER_NAME}" \
            --services "${svc}" \
            --region "${DEV_REGION}" \
            --query 'services[0].status' \
            --output text 2>/dev/null || echo "")
        if [[ "${SVC_STATUS}" == "ACTIVE" ]]; then
            RUNNING=$(aws ecs describe-services \
                --cluster "${CLUSTER_NAME}" \
                --services "${svc}" \
                --region "${DEV_REGION}" \
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
    ALB_DNS=$(terraform -chdir="${DEV_TERRAFORM_DIR}" output -raw alb_dns_name 2>/dev/null || echo "")
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
    CF_DIST_ID=$(terraform -chdir="${DEV_TERRAFORM_DIR}" output -raw cloudfront_distribution_id 2>/dev/null || echo "")
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

    # Check 11: ACM Certificate
    log_info "Checking ACM certificate..."
    CERT_ARN=$(terraform -chdir="${DEV_TERRAFORM_DIR}" output -raw acm_certificate_arn 2>/dev/null || echo "")
    if [[ -n "${CERT_ARN}" ]]; then
        CERT_STATUS=$(aws acm describe-certificate \
            --certificate-arn "${CERT_ARN}" \
            --region us-east-1 \
            --query 'Certificate.Status' \
            --output text 2>/dev/null || echo "unknown")
        if [[ "${CERT_STATUS}" == "ISSUED" ]]; then
            log_pass "ACM certificate: ${CERT_STATUS}"
            # Check that certificate covers expected domains
            CERT_DOMAINS=$(aws acm describe-certificate \
                --certificate-arn "${CERT_ARN}" \
                --region us-east-1 \
                --query 'Certificate.SubjectAlternativeNames' \
                --output text 2>/dev/null || echo "")
            if echo "${CERT_DOMAINS}" | grep -q "grafana.davidshaevel.com"; then
                log_pass "ACM certificate covers grafana.davidshaevel.com"
            else
                log_warn "ACM certificate missing grafana.davidshaevel.com SAN"
            fi
        elif [[ "${CERT_STATUS}" == "PENDING_VALIDATION" ]]; then
            log_warn "ACM certificate pending DNS validation"
        else
            log_fail "ACM certificate status: ${CERT_STATUS}"
        fi
    else
        log_warn "ACM certificate ARN not found in Terraform outputs"
    fi

    # Check 13: Service Discovery
    log_info "Checking service discovery..."
    SD_NAMESPACE=$(aws servicediscovery list-namespaces \
        --region "${DEV_REGION}" \
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

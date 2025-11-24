#!/bin/bash
# ==============================================================================
# Grafana ECS Deployment Test Script
# ==============================================================================
#
# This script validates that the Grafana ECS task is running correctly and
# is accessible via internal and external endpoints.
#
# Prerequisites:
# - AWS CLI configured with credentials
# - AWS_PROFILE environment variable set
# - AWS Session Manager plugin installed
#
# Usage:
#   ./scripts/test-grafana-deployment.sh
#

set -e  # Exit on error
set -u  # Exit on undefined variable
set -o pipefail # Return exit status of the last command in the pipe that failed

# ==============================================================================
# Configuration
# ==============================================================================

CLUSTER_NAME="${CLUSTER_NAME:-dev-davidshaevel-cluster}"
GRAFANA_SERVICE="${GRAFANA_SERVICE:-dev-davidshaevel-grafana}"
AWS_REGION="${AWS_REGION:-us-east-1}"
GRAFANA_DNS="grafana.davidshaevel.local"
PUBLIC_DNS="grafana.davidshaevel.com"

# Dynamically fetch ALB DNS name
ALB_NAME="dev-davidshaevel-alb"
ALB_DNS=$(aws elbv2 describe-load-balancers --names "${ALB_NAME}" --region "${AWS_REGION}" --query 'LoadBalancers[0].DNSName' --output text)

GRAFANA_PORT="3000"

# Test result tracking
TEST_LOGS_RESULT="?"
TEST_INTERNAL_RESULT="?"
TEST_PUBLIC_RESULT="?"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==============================================================================
# Helper Functions
# ==============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

section_header() {
    echo ""
    echo "=============================================================================="
    echo "$1"
    echo "=============================================================================="
    echo ""
}

# ==============================================================================
# Pre-flight Checks
# ==============================================================================

preflight_checks() {
    section_header "Pre-flight Checks"

    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi
    
    if ! command -v session-manager-plugin &> /dev/null; then
        log_error "AWS Session Manager plugin not installed"
        exit 1
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity --region "$AWS_REGION" &> /dev/null; then
        log_error "AWS credentials not configured or invalid"
        exit 1
    fi
    
    log_success "Pre-flight checks passed"
}

# ==============================================================================
# Test 1: ECS Service Status
# ==============================================================================

test_ecs_service_status() {
    section_header "Test 1: Grafana ECS Service Status"

    log_info "Checking ECS service: $GRAFANA_SERVICE"

    SERVICE_JSON=$(aws ecs describe-services \
        --cluster "$CLUSTER_NAME" \
        --services "$GRAFANA_SERVICE" \
        --region "$AWS_REGION" \
        --query 'services[0]' \
        --output json)

    if [ "$(echo "$SERVICE_JSON" | jq -r '.serviceName')" == "null" ]; then
        log_error "Service not found: $GRAFANA_SERVICE"
        return 1
    fi

    SERVICE_STATUS=$(echo "$SERVICE_JSON" | jq -r '.status')
    RUNNING_COUNT=$(echo "$SERVICE_JSON" | jq -r '.runningCount')
    DESIRED_COUNT=$(echo "$SERVICE_JSON" | jq -r '.desiredCount')

    log_info "Service Status: $SERVICE_STATUS"
    log_info "Running Tasks: $RUNNING_COUNT / $DESIRED_COUNT"

    if [ "$SERVICE_STATUS" == "ACTIVE" ] && [ "$RUNNING_COUNT" -eq "$DESIRED_COUNT" ]; then
        log_success "ECS service is healthy"
    else
        log_error "ECS service is not healthy"
        return 1
    fi
}

# ==============================================================================
# Test 2: Task Health & Logs
# ==============================================================================

test_task_health_and_logs() {
    section_header "Test 2: Task Health & Logs"

    # Get task ARN
    TASK_ARN=$(aws ecs list-tasks \
        --cluster "$CLUSTER_NAME" \
        --service-name "$GRAFANA_SERVICE" \
        --region "$AWS_REGION" \
        --query 'taskArns[0]' \
        --output text)

    if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" == "None" ]; then
        log_error "No running tasks found"
        return 1
    fi

    log_info "Task ARN: $TASK_ARN"
    export TASK_ARN

    # Check logs for startup success
    LOG_GROUP="/ecs/dev-davidshaevel/grafana"
    log_info "Checking CloudWatch logs: $LOG_GROUP"

    # Get recent log streams
    LOG_STREAM=$(aws logs describe-log-streams \
        --log-group-name "$LOG_GROUP" \
        --order-by LastEventTime \
        --descending \
        --limit 1 \
        --region "$AWS_REGION" \
        --query 'logStreams[0].logStreamName' \
        --output text)

    if [ "$LOG_STREAM" == "None" ]; then
        log_warning "No log streams found yet"
    else
        log_info "Log Stream: $LOG_STREAM"
        
        # Look for any info level logs to confirm the application is running
        # "HTTP Server Listen" might be missed if it scrolled off
        LOG_COUNT=$(aws logs get-log-events \
            --log-group-name "$LOG_GROUP" \
            --log-stream-name "$LOG_STREAM" \
            --region "$AWS_REGION" \
            --limit 20 \
            --query 'events[*].message' \
            --output text 2>/dev/null | grep -c "level=info" || true)

        # Clean up newlines
        LOG_COUNT=$(echo "$LOG_COUNT" | tr -d '\n' | tr -d '\r')

        if [ "${LOG_COUNT:-0}" -gt 0 ]; then
            log_success "Grafana logs found ($LOG_COUNT events)"
            TEST_LOGS_RESULT="✓"
        else
            log_warning "Grafana logs empty or not found"
            TEST_LOGS_RESULT="?"
        fi
    fi
}

# ==============================================================================
# Test 3: Internal Health Check (ECS Exec)
# ==============================================================================

test_internal_health() {
    section_header "Test 3: Internal Health Check"

    log_info "Testing http://localhost:3000/api/health via ECS Exec..."

    HEALTH_RESPONSE=$(aws ecs execute-command \
        --cluster "$CLUSTER_NAME" \
        --task "$TASK_ARN" \
        --container grafana \
        --command "wget -qO- http://localhost:3000/api/health" \
        --region "$AWS_REGION" 2>&1 || echo "FAILED")

    if echo "$HEALTH_RESPONSE" | grep -q '"database": "ok"'; then
        log_success "Internal health check passed"
        TEST_INTERNAL_RESULT="✓"
    else
        log_error "Internal health check failed: $HEALTH_RESPONSE"
        TEST_INTERNAL_RESULT="✗"
    fi
}

# ==============================================================================
# Test 4: Public Access
# ==============================================================================

test_public_access() {
    section_header "Test 4: Public Access (via ALB)"

    log_info "Testing public endpoint: https://$PUBLIC_DNS/login"
    
    # Test 1: Direct DNS (HTTP -> HTTPS redirect expected)
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$PUBLIC_DNS/login" || echo "000")
    log_info "DNS HTTP Code (Expect 301): $HTTP_CODE"

    # Test 2: Direct DNS HTTPS (Expect 200)
    HTTPS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://$PUBLIC_DNS/login" || echo "000")
    log_info "DNS HTTPS Code (Expect 200): $HTTPS_CODE"

    # Test 3: Direct ALB HTTPS with Host Header (bypasses DNS)
    log_info "Testing via ALB ($ALB_DNS) with Host header..."
    ALB_HTTPS_CODE=$(curl -s -k -o /dev/null -w "%{http_code}" -H "Host: $PUBLIC_DNS" "https://$ALB_DNS/login" || echo "000")
    log_info "ALB HTTPS Code: $ALB_HTTPS_CODE"

    if [[ "$HTTPS_CODE" =~ ^2 ]]; then
        log_success "Public HTTPS endpoint accessible via DNS"
        TEST_PUBLIC_RESULT="✓"
    elif [[ "$ALB_HTTPS_CODE" =~ ^2 ]]; then
        log_success "Public HTTPS endpoint accessible via ALB (DNS propagation pending)"
        TEST_PUBLIC_RESULT="✓ (ALB)"
    else
        log_warning "Public HTTPS endpoint not accessible. Check Security Groups and Listener."
        TEST_PUBLIC_RESULT="✗"
    fi
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    echo "=============================================================================="
    echo "Grafana Deployment Test Suite"
    echo "=============================================================================="
    
    preflight_checks
    test_ecs_service_status || true
    test_task_health_and_logs || true
    test_internal_health || true
    test_public_access || true

    echo ""
    echo "Summary:"
    
    if [ "$TEST_LOGS_RESULT" == "✓" ]; then
        echo -e "  ${GREEN}[✓]${NC} Logs (Startup Confirmed)"
    else
        echo -e "  ${YELLOW}[?]${NC} Logs (Startup Not Found)"
    fi

    if [ "$TEST_INTERNAL_RESULT" == "✓" ]; then
        echo -e "  ${GREEN}[✓]${NC} Internal Health"
    else
        echo -e "  ${RED}[✗]${NC} Internal Health"
    fi

    if [[ "$TEST_PUBLIC_RESULT" == *"✓"* ]]; then
        echo -e "  ${GREEN}[✓]${NC} Public Access"
    else
        echo -e "  ${RED}[✗]${NC} Public Access"
    fi
    echo ""
}

main "$@"


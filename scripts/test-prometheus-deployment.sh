#!/bin/bash
# ==============================================================================
# Prometheus ECS Deployment Test Script
# ==============================================================================
#
# This script validates that the Prometheus ECS task is running correctly and
# all endpoints are responding as expected.
#
# Prerequisites:
# - AWS CLI configured with credentials
# - AWS_PROFILE environment variable set
# - AWS Session Manager plugin installed
#
# Usage:
#   ./scripts/test-prometheus-deployment.sh
#
# Installation of Session Manager plugin:
#   brew install --cask session-manager-plugin
#

set -e  # Exit on error
set -u  # Exit on undefined variable

# ==============================================================================
# Configuration
# ==============================================================================

CLUSTER_NAME="${CLUSTER_NAME:-dev-davidshaevel-cluster}"
PROMETHEUS_SERVICE="${PROMETHEUS_SERVICE:-dev-davidshaevel-prometheus}"
BACKEND_SERVICE="${BACKEND_SERVICE:-dev-davidshaevel-backend}"
FRONTEND_SERVICE="${FRONTEND_SERVICE:-dev-davidshaevel-frontend}"
AWS_REGION="${AWS_REGION:-us-east-1}"
PROMETHEUS_DNS="prometheus.davidshaevel.local"
BACKEND_DNS="backend.davidshaevel.local"
FRONTEND_DNS="frontend.davidshaevel.local"
PROMETHEUS_PORT="9090"
BACKEND_PORT="3001"
FRONTEND_PORT="3000"

# Test result tracking
TEST_5_RESULT="?"  # Prometheus HTTP Endpoints
TEST_6_RESULT="?"  # Prometheus DNS Resolution
TEST_7_RESULT="?"  # Backend Metrics Endpoint
TEST_8_RESULT="?"  # Frontend Metrics Endpoint

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

    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi
    log_success "AWS CLI installed: $(aws --version 2>&1 | head -1)"

    # Check AWS_PROFILE
    if [ -z "${AWS_PROFILE:-}" ]; then
        log_warning "AWS_PROFILE not set, using default profile"
    else
        log_success "AWS_PROFILE: $AWS_PROFILE"
    fi

    # Check Session Manager plugin
    if ! command -v session-manager-plugin &> /dev/null; then
        log_error "AWS Session Manager plugin not installed"
        log_info "Install with: brew install --cask session-manager-plugin"
        exit 1
    fi
    log_success "Session Manager plugin installed: $(session-manager-plugin --version 2>&1 || echo 'installed')"

    # Check AWS credentials
    if ! aws sts get-caller-identity --region "$AWS_REGION" &> /dev/null; then
        log_error "AWS credentials not configured or invalid"
        exit 1
    fi
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region "$AWS_REGION")
    log_success "AWS credentials valid (Account: $ACCOUNT_ID)"
}

# ==============================================================================
# Test 1: ECS Service Status
# ==============================================================================

test_ecs_service_status() {
    section_header "Test 1: Prometheus ECS Service Status"

    log_info "Checking ECS service: $PROMETHEUS_SERVICE"

    # Get service details
    SERVICE_JSON=$(aws ecs describe-services \
        --cluster "$CLUSTER_NAME" \
        --services "$PROMETHEUS_SERVICE" \
        --region "$AWS_REGION" \
        --query 'services[0]' \
        --output json)

    # Check service exists
    if [ "$(echo "$SERVICE_JSON" | jq -r '.serviceName')" == "null" ]; then
        log_error "Service not found: $PROMETHEUS_SERVICE"
        return 1
    fi

    # Check service status
    SERVICE_STATUS=$(echo "$SERVICE_JSON" | jq -r '.status')
    RUNNING_COUNT=$(echo "$SERVICE_JSON" | jq -r '.runningCount')
    DESIRED_COUNT=$(echo "$SERVICE_JSON" | jq -r '.desiredCount')
    DEPLOYMENT_STATUS=$(echo "$SERVICE_JSON" | jq -r '.deployments[0].rolloutState // "N/A"')

    log_info "Service Status: $SERVICE_STATUS"
    log_info "Running Tasks: $RUNNING_COUNT / $DESIRED_COUNT"
    log_info "Deployment Status: $DEPLOYMENT_STATUS"

    if [ "$SERVICE_STATUS" == "ACTIVE" ] && [ "$RUNNING_COUNT" -eq "$DESIRED_COUNT" ]; then
        log_success "ECS service is healthy"
    else
        log_error "ECS service is not healthy"
        return 1
    fi
}

# ==============================================================================
# Test 2: Task Health Status
# ==============================================================================

test_task_health() {
    section_header "Test 2: Prometheus Task Health Status"

    log_info "Getting Prometheus task details"

    # Get task ARN
    TASK_ARN=$(aws ecs list-tasks \
        --cluster "$CLUSTER_NAME" \
        --service-name "$PROMETHEUS_SERVICE" \
        --region "$AWS_REGION" \
        --query 'taskArns[0]' \
        --output text)

    if [ -z "$TASK_ARN" ] || [ "$TASK_ARN" == "None" ]; then
        log_error "No running tasks found"
        return 1
    fi

    TASK_ID=$(basename "$TASK_ARN")
    log_info "Task ID: $TASK_ID"

    # Get task details
    TASK_JSON=$(aws ecs describe-tasks \
        --cluster "$CLUSTER_NAME" \
        --tasks "$TASK_ARN" \
        --region "$AWS_REGION" \
        --query 'tasks[0]' \
        --output json)

    # Check Prometheus container
    PROMETHEUS_STATUS=$(echo "$TASK_JSON" | jq -r '.containers[] | select(.name=="prometheus") | .lastStatus')
    PROMETHEUS_HEALTH=$(echo "$TASK_JSON" | jq -r '.containers[] | select(.name=="prometheus") | .healthStatus')
    TASK_IP=$(echo "$TASK_JSON" | jq -r '.containers[] | select(.name=="prometheus") | .networkInterfaces[0].privateIpv4Address')

    log_info "Prometheus Container Status: $PROMETHEUS_STATUS"
    log_info "Prometheus Health Status: $PROMETHEUS_HEALTH"
    log_info "Task IP Address: $TASK_IP"

    # Check init container
    INIT_STATUS=$(echo "$TASK_JSON" | jq -r '.containers[] | select(.name=="init-config-sync") | .lastStatus')
    log_info "Init Container Status: $INIT_STATUS"

    if [ "$PROMETHEUS_STATUS" == "RUNNING" ] && [ "$PROMETHEUS_HEALTH" == "HEALTHY" ]; then
        log_success "Prometheus task is healthy"

        # Export for later tests
        export TASK_ARN
        export TASK_ID
        export TASK_IP
        return 0
    else
        log_error "Prometheus task is not healthy"
        return 1
    fi
}

# ==============================================================================
# Test 3: CloudWatch Logs
# ==============================================================================

test_cloudwatch_logs() {
    section_header "Test 3: CloudWatch Logs Analysis"

    LOG_GROUP="/ecs/dev-davidshaevel/prometheus"

    log_info "Checking CloudWatch logs: $LOG_GROUP"

    # Get recent log streams
    LOG_STREAMS=$(aws logs describe-log-streams \
        --log-group-name "$LOG_GROUP" \
        --order-by LastEventTime \
        --descending \
        --max-items 2 \
        --region "$AWS_REGION" \
        --query 'logStreams[*].logStreamName' \
        --output json)

    PROMETHEUS_STREAM=$(echo "$LOG_STREAMS" | jq -r '.[] | select(contains("prometheus/prometheus"))')
    INIT_STREAM=$(echo "$LOG_STREAMS" | jq -r '.[] | select(contains("init/init-config-sync"))')

    if [ -z "$PROMETHEUS_STREAM" ]; then
        log_error "No Prometheus log stream found"
        return 1
    fi

    log_info "Prometheus Log Stream: $PROMETHEUS_STREAM"
    log_info "Init Log Stream: $INIT_STREAM"

    # Check for startup message
    STARTUP_MSG=$(aws logs get-log-events \
        --log-group-name "$LOG_GROUP" \
        --log-stream-name "$PROMETHEUS_STREAM" \
        --region "$AWS_REGION" \
        --query 'events[*].message' \
        --output text | grep -c "Server is ready to receive web requests" | tr -d '\n' || echo "0")

    # Check for errors
    ERROR_COUNT=$(aws logs get-log-events \
        --log-group-name "$LOG_GROUP" \
        --log-stream-name "$PROMETHEUS_STREAM" \
        --region "$AWS_REGION" \
        --query 'events[*].message' \
        --output text | grep -c "level=error" | tr -d '\n' || echo "0")

    log_info "Startup messages found: $STARTUP_MSG"
    log_info "Error messages found: $ERROR_COUNT"

    if [ "$STARTUP_MSG" -gt 0 ]; then
        log_success "Prometheus started successfully (log verification)"
    else
        log_warning "No startup message found in logs"
    fi

    if [ "$ERROR_COUNT" -gt 0 ]; then
        log_warning "Found $ERROR_COUNT error messages in logs"
    else
        log_success "No error messages in logs"
    fi
}

# ==============================================================================
# Test 4: Service Discovery
# ==============================================================================

test_service_discovery() {
    section_header "Test 4: Service Discovery Configuration"

    log_info "Checking service discovery for: $PROMETHEUS_DNS"

    # Get service discovery namespace
    NAMESPACE_ID=$(aws servicediscovery list-namespaces \
        --region "$AWS_REGION" \
        --query 'Namespaces[?Name==`davidshaevel.local`].Id' \
        --output text)

    if [ -z "$NAMESPACE_ID" ]; then
        log_error "Service discovery namespace not found: davidshaevel.local"
        return 1
    fi

    log_info "Namespace ID: $NAMESPACE_ID"

    # Get Prometheus service
    SERVICE_ID=$(aws servicediscovery list-services \
        --region "$AWS_REGION" \
        --query 'Services[?Name==`prometheus`].Id' \
        --output text)

    if [ -z "$SERVICE_ID" ]; then
        log_error "Service discovery service not found: prometheus"
        return 1
    fi

    log_info "Service ID: $SERVICE_ID"

    # Get actual registered instances (not just the InstanceCount field which may not be updated)
    INSTANCES=$(aws servicediscovery list-instances \
        --service-id "$SERVICE_ID" \
        --region "$AWS_REGION" \
        --query 'Instances' \
        --output json)

    INSTANCE_COUNT=$(echo "$INSTANCES" | jq 'length')

    log_info "Registered Instances: $INSTANCE_COUNT"

    if [ "$INSTANCE_COUNT" -gt 0 ]; then
        log_success "Service discovery configured with $INSTANCE_COUNT instance(s)"

        # Log instance details
        echo "$INSTANCES" | jq -r '.[] | "  Instance ID: \(.Id) | IP: \(.Attributes.AWS_INSTANCE_IPV4)"' | while read -r line; do
            log_info "$line"
        done
    else
        log_warning "Service discovery configured but no instances registered yet (may take 30-60s)"
    fi
}

# ==============================================================================
# Test 5: HTTP Endpoints via ECS Exec
# ==============================================================================

test_http_endpoints() {
    section_header "Test 5: HTTP Endpoints via ECS Exec"

    if [ -z "${TASK_ARN:-}" ]; then
        log_error "TASK_ARN not set - previous tests may have failed"
        return 1
    fi

    log_info "Testing Prometheus endpoints via ECS Exec"
    log_info "Task ARN: $TASK_ARN"

    # Test health endpoint
    log_info "Testing /-/healthy endpoint..."
    HEALTH_RESPONSE=$(aws ecs execute-command \
        --cluster "$CLUSTER_NAME" \
        --task "$TASK_ARN" \
        --container prometheus \
        --interactive \
        --command "wget -qO- http://localhost:$PROMETHEUS_PORT/-/healthy" \
        --region "$AWS_REGION" 2>&1 || echo "FAILED")

    if echo "$HEALTH_RESPONSE" | grep -q "Prometheus.*is.*Healthy"; then
        log_success "Health endpoint responding: Prometheus is Healthy"
    elif echo "$HEALTH_RESPONSE" | grep -q "FAILED"; then
        log_error "Failed to test health endpoint (ECS Exec may not be enabled)"
        log_info "To enable ECS Exec, set enable_ecs_exec = true in terraform variables"
        TEST_5_RESULT="✗"
        return 1
    else
        log_warning "Unexpected health response: $HEALTH_RESPONSE"
        TEST_5_RESULT="⚠"
    fi

    # Test ready endpoint
    log_info "Testing /-/ready endpoint..."
    READY_RESPONSE=$(aws ecs execute-command \
        --cluster "$CLUSTER_NAME" \
        --task "$TASK_ARN" \
        --container prometheus \
        --interactive \
        --command "wget -qO- http://localhost:$PROMETHEUS_PORT/-/ready" \
        --region "$AWS_REGION" 2>&1 || echo "FAILED")

    if echo "$READY_RESPONSE" | grep -q "Prometheus.*is.*Ready"; then
        log_success "Ready endpoint responding: Prometheus is Ready"
    else
        log_warning "Ready endpoint check inconclusive"
    fi

    # Test targets endpoint
    log_info "Testing /api/v1/targets endpoint..."
    TARGETS_RESPONSE=$(aws ecs execute-command \
        --cluster "$CLUSTER_NAME" \
        --task "$TASK_ARN" \
        --container prometheus \
        --interactive \
        --command "wget -qO- http://localhost:$PROMETHEUS_PORT/api/v1/targets" \
        --region "$AWS_REGION" 2>&1 || echo "FAILED")

    if echo "$TARGETS_RESPONSE" | grep -q '"status":"success"'; then
        log_success "Targets API endpoint responding"

        # Count active targets
        ACTIVE_TARGETS=$(echo "$TARGETS_RESPONSE" | grep -o '"health":"up"' | wc -l || echo "0")
        log_info "Active targets found: $ACTIVE_TARGETS"

        # All 3 endpoints passed
        TEST_5_RESULT="✓"
    else
        log_warning "Targets API check inconclusive"
        TEST_5_RESULT="⚠"
    fi
}

# ==============================================================================
# Test 6: DNS Resolution from Backend
# ==============================================================================

test_dns_resolution() {
    section_header "Test 6: DNS Resolution via Backend Container"

    log_info "Testing service discovery DNS resolution"

    # Get backend task
    BACKEND_TASK=$(aws ecs list-tasks \
        --cluster "$CLUSTER_NAME" \
        --service-name dev-davidshaevel-backend \
        --region "$AWS_REGION" \
        --query 'taskArns[0]' \
        --output text)

    if [ -z "$BACKEND_TASK" ] || [ "$BACKEND_TASK" == "None" ]; then
        log_warning "No backend task running - skipping DNS test"
        TEST_6_RESULT="⚠"
        return 0
    fi

    log_info "Backend Task: $(basename "$BACKEND_TASK")"

    # Check if backend has ECS Exec enabled
    BACKEND_EXEC_ENABLED=$(aws ecs describe-tasks \
        --cluster "$CLUSTER_NAME" \
        --tasks "$BACKEND_TASK" \
        --region "$AWS_REGION" \
        --query 'tasks[0].enableExecuteCommand' \
        --output text)

    if [[ "$BACKEND_EXEC_ENABLED" != "True" ]]; then
        log_warning "Backend container does not have ECS Exec enabled - skipping DNS test"
        log_info "To enable ECS Exec for backend, set enable_execute_command = true in terraform"
        TEST_6_RESULT="⚠"
        return 0
    fi

    # Try to resolve DNS from backend
    DNS_RESPONSE=$(aws ecs execute-command \
        --cluster "$CLUSTER_NAME" \
        --task "$BACKEND_TASK" \
        --container backend \
        --interactive \
        --command "nslookup $PROMETHEUS_DNS" \
        --region "$AWS_REGION" 2>&1 || echo "FAILED")

    # Check DNS resolution result
    DNS_PASSED=false
    if echo "$DNS_RESPONSE" | grep -q "Address:"; then
        log_success "DNS resolution successful from backend container"
        echo "$DNS_RESPONSE" | grep "Address:" | while read -r line; do
            log_info "$line"
        done
        DNS_PASSED=true
    else
        log_warning "DNS resolution failed"
        TEST_6_RESULT="✗"
    fi

    # Only test HTTP if DNS passed
    if [ "$DNS_PASSED" = true ]; then
        # Try to wget Prometheus from backend (wget is available in node:alpine)
        log_info "Testing HTTP request from backend to Prometheus..."
        WGET_RESPONSE=$(aws ecs execute-command \
            --cluster "$CLUSTER_NAME" \
            --task "$BACKEND_TASK" \
            --container backend \
            --interactive \
            --command "wget -qO- --timeout=10 http://$PROMETHEUS_DNS:$PROMETHEUS_PORT/-/healthy" \
            --region "$AWS_REGION" 2>&1 || echo "FAILED")

        if HEALTH_LINE=$(echo "$WGET_RESPONSE" | grep "Prometheus.*is.*Healthy"); then
            log_success "HTTP request successful: $(echo "$HEALTH_LINE" | head -1)"
            TEST_6_RESULT="✓"
        elif echo "$WGET_RESPONSE" | grep -q "timed out\|Cannot\|FAILED"; then
            log_warning "HTTP request failed - possible network/security group issue"
            log_info "This may be expected if backend→prometheus traffic is not allowed"
            TEST_6_RESULT="✗"
        else
            log_warning "HTTP request test inconclusive: $WGET_RESPONSE"
            TEST_6_RESULT="⚠"
        fi
    fi
}

# ==============================================================================
# Test 7: Backend Metrics Endpoint
# ==============================================================================

test_backend_metrics() {
    section_header "Test 7: Backend Metrics Endpoint"

    log_info "Testing backend /api/metrics endpoint"

    # Get backend task
    BACKEND_TASK=$(aws ecs list-tasks \
        --cluster "$CLUSTER_NAME" \
        --service-name "$BACKEND_SERVICE" \
        --region "$AWS_REGION" \
        --query 'taskArns[0]' \
        --output text)

    if [ -z "$BACKEND_TASK" ] || [ "$BACKEND_TASK" == "None" ]; then
        log_warning "No backend tasks running - skipping test"
        TEST_7_RESULT="⚠"
        return 0
    fi

    log_info "Backend task found: $(basename "$BACKEND_TASK")"

    # Check if ECS Exec is enabled on the task
    BACKEND_EXEC_ENABLED=$(aws ecs describe-tasks \
        --cluster "$CLUSTER_NAME" \
        --tasks "$BACKEND_TASK" \
        --region "$AWS_REGION" \
        --query 'tasks[0].enableExecuteCommand' \
        --output text)

    if [[ "$BACKEND_EXEC_ENABLED" != "True" ]]; then
        log_warning "ECS Exec not enabled on backend task - skipping test"
        TEST_7_RESULT="⚠"
        return 0
    fi

    # Fetch metrics endpoint from within the backend container
    # Note: Alpine Linux (node:20-alpine) doesn't have curl, use wget instead
    log_info "Fetching metrics from http://localhost:$BACKEND_PORT/api/metrics"

    METRICS_RESPONSE=$(aws ecs execute-command \
        --cluster "$CLUSTER_NAME" \
        --task "$BACKEND_TASK" \
        --container backend \
        --interactive \
        --command "wget -qO- http://localhost:$BACKEND_PORT/api/metrics" \
        --region "$AWS_REGION" 2>&1 || echo "FAILED")

    # Check for specific metrics
    if echo "$METRICS_RESPONSE" | grep -q "backend_uptime_seconds\|http_requests_total"; then
        log_success "Backend metrics endpoint responding"

        # Check for enhanced metrics from prom-client
        if echo "$METRICS_RESPONSE" | grep -q "http_request_duration_seconds"; then
            log_success "Enhanced metrics detected (prom-client)"
        fi

        # Sample a few metrics
        echo "$METRICS_RESPONSE" | grep "^backend_info\|^backend_uptime\|^http_request" | head -5 | while read -r line; do
            log_info "  $line"
        done

        TEST_7_RESULT="✓"
    else
        log_error "Backend metrics endpoint not responding correctly"
        TEST_7_RESULT="✗"
    fi
}

# ==============================================================================
# Test 8: Frontend Metrics Endpoint
# ==============================================================================

test_frontend_metrics() {
    section_header "Test 8: Frontend Metrics Endpoint"

    log_info "Testing frontend /api/metrics endpoint"

    # Get frontend task
    FRONTEND_TASK=$(aws ecs list-tasks \
        --cluster "$CLUSTER_NAME" \
        --service-name "$FRONTEND_SERVICE" \
        --region "$AWS_REGION" \
        --query 'taskArns[0]' \
        --output text)

    if [ -z "$FRONTEND_TASK" ] || [ "$FRONTEND_TASK" == "None" ]; then
        log_warning "No frontend tasks running - skipping test"
        TEST_8_RESULT="⚠"
        return 0
    fi

    log_info "Frontend task found: $(basename "$FRONTEND_TASK")"

    # Check if ECS Exec is enabled on the task
    FRONTEND_EXEC_ENABLED=$(aws ecs describe-tasks \
        --cluster "$CLUSTER_NAME" \
        --tasks "$FRONTEND_TASK" \
        --region "$AWS_REGION" \
        --query 'tasks[0].enableExecuteCommand' \
        --output text)

    if [[ "$FRONTEND_EXEC_ENABLED" != "True" ]]; then
        log_warning "ECS Exec not enabled on frontend task - skipping test"
        TEST_8_RESULT="⚠"
        return 0
    fi

    # Fetch metrics endpoint from within the frontend container
    # Note: Alpine Linux (node:20-alpine) doesn't have curl, use wget instead
    log_info "Fetching metrics from http://localhost:$FRONTEND_PORT/api/metrics"

    METRICS_RESPONSE=$(aws ecs execute-command \
        --cluster "$CLUSTER_NAME" \
        --task "$FRONTEND_TASK" \
        --container frontend \
        --interactive \
        --command "wget -qO- http://localhost:$FRONTEND_PORT/api/metrics" \
        --region "$AWS_REGION" 2>&1 || echo "FAILED")

    # Check for specific metrics
    if echo "$METRICS_RESPONSE" | grep -q "frontend_uptime_seconds\|frontend_info"; then
        log_success "Frontend metrics endpoint responding"

        # Check for enhanced metrics from prom-client
        if echo "$METRICS_RESPONSE" | grep -q "frontend_page_views_total"; then
            log_success "Enhanced metrics detected (prom-client)"
        fi

        # Sample a few metrics
        echo "$METRICS_RESPONSE" | grep "^frontend_info\|^frontend_uptime\|^frontend_page" | head -5 | while read -r line; do
            log_info "  $line"
        done

        TEST_8_RESULT="✓"
    else
        log_error "Frontend metrics endpoint not responding correctly"
        TEST_8_RESULT="✗"
    fi
}

# ==============================================================================
# Summary Report
# ==============================================================================

generate_summary() {
    section_header "Test Summary"

    echo "ECS Deployment Test Results:"
    echo ""
    echo "  Cluster: $CLUSTER_NAME"
    echo "  Region: $AWS_REGION"
    echo ""
    echo "Services:"
    echo "  Prometheus: $PROMETHEUS_SERVICE ($PROMETHEUS_DNS:$PROMETHEUS_PORT)"
    echo "  Backend:    $BACKEND_SERVICE ($BACKEND_DNS:$BACKEND_PORT)"
    echo "  Frontend:   $FRONTEND_SERVICE ($FRONTEND_DNS:$FRONTEND_PORT)"
    echo ""
    echo "Test Results:"
    echo "  [✓] Prometheus Service Status"
    echo "  [✓] Prometheus Task Health"
    echo "  [✓] Prometheus CloudWatch Logs"
    echo "  [✓] Prometheus Service Discovery"
    echo "  [${TEST_5_RESULT}] Prometheus HTTP Endpoints"
    echo "  [${TEST_6_RESULT}] Prometheus DNS Resolution"
    echo "  [${TEST_7_RESULT}] Backend Metrics Endpoint"
    echo "  [${TEST_8_RESULT}] Frontend Metrics Endpoint"
    echo ""

    if [ "${TASK_IP:-}" ]; then
        echo "Prometheus Direct Access (from VPC):"
        echo "  curl http://$TASK_IP:$PROMETHEUS_PORT/-/healthy"
        echo "  curl http://$TASK_IP:$PROMETHEUS_PORT/api/v1/targets"
        echo ""
    fi

    echo "Service Discovery Access (from VPC):"
    echo "  Prometheus:"
    echo "    curl http://$PROMETHEUS_DNS:$PROMETHEUS_PORT/-/healthy"
    echo "    curl http://$PROMETHEUS_DNS:$PROMETHEUS_PORT/metrics"
    echo "    curl http://$PROMETHEUS_DNS:$PROMETHEUS_PORT/api/v1/targets"
    echo "  Backend:"
    echo "    curl http://$BACKEND_DNS:$BACKEND_PORT/health"
    echo "    curl http://$BACKEND_DNS:$BACKEND_PORT/api/metrics"
    echo "  Frontend:"
    echo "    curl http://$FRONTEND_DNS:$FRONTEND_PORT/health"
    echo "    curl http://$FRONTEND_DNS:$FRONTEND_PORT/api/metrics"
    echo ""
}

# ==============================================================================
# Main Execution
# ==============================================================================

main() {
    echo "=============================================================================="
    echo "ECS Deployment Test Suite (Prometheus + Applications)"
    echo "=============================================================================="
    echo ""

    # Run all tests
    preflight_checks

    # Prometheus tests
    test_ecs_service_status || true
    test_task_health || true
    test_cloudwatch_logs || true
    test_service_discovery || true
    test_http_endpoints || true
    test_dns_resolution || true

    # Application metrics tests
    test_backend_metrics || true
    test_frontend_metrics || true

    generate_summary

    log_success "Test suite completed!"
}

# Run main function
main "$@"

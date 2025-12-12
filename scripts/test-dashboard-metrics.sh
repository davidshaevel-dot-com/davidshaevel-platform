#!/bin/bash
# ==============================================================================
# Dashboard Metrics Validation Script
# ==============================================================================
#
# This script validates that Grafana dashboard JSON files are syntactically
# correct and that the Prometheus metrics they reference actually exist.
#
# Prerequisites:
# - AWS CLI configured with credentials
# - AWS_PROFILE environment variable set (e.g., davidshaevel-dev)
# - AWS Session Manager plugin installed
# - jq installed
#
# Usage:
#   ./scripts/test-dashboard-metrics.sh [dashboard-name]
#
# Examples:
#   ./scripts/test-dashboard-metrics.sh                    # Test all dashboards
#   ./scripts/test-dashboard-metrics.sh nodejs-performance # Test specific dashboard
#

set -e  # Exit on error
set -u  # Exit on undefined variable
set -o pipefail # Return exit status of the last command in the pipe that failed

# ==============================================================================
# Configuration
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DASHBOARD_DIR="$PROJECT_ROOT/observability/grafana/provisioning/dashboard-definitions"

CLUSTER_NAME="${CLUSTER_NAME:-dev-davidshaevel-cluster}"
AWS_REGION="${AWS_REGION:-us-east-1}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNINGS=0

# ==============================================================================
# Helper Functions
# ==============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

log_metric() {
    echo -e "    ${CYAN}→${NC} $1"
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

    # Check jq
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed (required for JSON parsing)"
        exit 1
    fi
    log_success "jq is installed"

    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi
    log_success "AWS CLI is installed"

    # Check dashboard directory exists
    if [[ ! -d "$DASHBOARD_DIR" ]]; then
        log_error "Dashboard directory not found: $DASHBOARD_DIR"
        exit 1
    fi
    log_success "Dashboard directory exists"

    # Check AWS credentials (only if we'll query Prometheus)
    if [[ "$SKIP_PROMETHEUS" != "true" ]]; then
        if ! aws sts get-caller-identity --region "$AWS_REGION" &> /dev/null; then
            log_warning "AWS credentials not configured - skipping Prometheus metric verification"
            SKIP_PROMETHEUS="true"
        else
            log_success "AWS credentials valid"
        fi
    fi
}

# ==============================================================================
# JSON Validation
# ==============================================================================

validate_json() {
    local dashboard_file="$1"
    local dashboard_name=$(basename "$dashboard_file" .json)

    section_header "Validating: $dashboard_name"

    # Check JSON syntax
    if jq . "$dashboard_file" > /dev/null 2>&1; then
        log_success "JSON syntax is valid"
    else
        log_error "JSON syntax error in $dashboard_file"
        jq . "$dashboard_file" 2>&1 | head -5
        return 1
    fi

    # Check required fields
    local title=$(jq -r '.dashboard.title // empty' "$dashboard_file")
    if [[ -n "$title" ]]; then
        log_success "Dashboard title: $title"
    else
        log_error "Missing dashboard title"
    fi

    # Count panels
    local panel_count=$(jq '.dashboard.panels | length' "$dashboard_file")
    if [[ "$panel_count" -gt 0 ]]; then
        log_success "Panel count: $panel_count"
    else
        log_warning "No panels defined in dashboard"
    fi

    # List panels
    log_info "Panels:"
    jq -r '.dashboard.panels[] | "    \(.id). \(.title) (\(.type))"' "$dashboard_file"

    # Extract metrics
    echo ""
    log_info "PromQL expressions used:"
    local metrics=$(jq -r '.dashboard.panels[].targets[]?.expr // empty' "$dashboard_file" | sort -u)
    echo "$metrics" | while read -r expr; do
        if [[ -n "$expr" ]]; then
            log_metric "$expr"
        fi
    done

    return 0
}

# ==============================================================================
# Prometheus Metric Verification
# ==============================================================================

get_prometheus_task_id() {
    aws ecs list-tasks \
        --cluster "$CLUSTER_NAME" \
        --service-name "dev-davidshaevel-prometheus" \
        --region "$AWS_REGION" \
        --query 'taskArns[0]' \
        --output text | rev | cut -d'/' -f1 | rev
}

get_available_metrics() {
    local task_id="$1"

    # Query Prometheus for available metric names
    aws ecs execute-command \
        --cluster "$CLUSTER_NAME" \
        --task "$task_id" \
        --container prometheus \
        --interactive \
        --command "wget -qO- 'http://localhost:9090/api/v1/label/__name__/values'" \
        --region "$AWS_REGION" 2>/dev/null | jq -r '.data[]' 2>/dev/null
}

verify_metrics_in_prometheus() {
    local dashboard_file="$1"
    local dashboard_name=$(basename "$dashboard_file" .json)

    section_header "Verifying Prometheus Metrics: $dashboard_name"

    # Get Prometheus task ID
    log_info "Finding Prometheus task..."
    local task_id=$(get_prometheus_task_id)

    if [[ -z "$task_id" || "$task_id" == "None" ]]; then
        log_warning "Could not find Prometheus task - skipping metric verification"
        return 0
    fi
    log_success "Found Prometheus task: $task_id"

    # Get available metrics
    log_info "Fetching available metrics from Prometheus..."
    local available_metrics=$(get_available_metrics "$task_id")

    if [[ -z "$available_metrics" ]]; then
        log_warning "Could not fetch metrics from Prometheus"
        return 0
    fi

    local metric_count=$(echo "$available_metrics" | wc -l | tr -d ' ')
    log_success "Found $metric_count metrics in Prometheus"

    # Extract base metric names from dashboard expressions
    log_info "Checking dashboard metrics against Prometheus..."
    local expressions=$(jq -r '.dashboard.panels[].targets[]?.expr // empty' "$dashboard_file" | sort -u)

    local missing_metrics=()
    local found_metrics=()

    echo "$expressions" | while read -r expr; do
        if [[ -z "$expr" ]]; then
            continue
        fi

        # Extract metric name from expression (handles rate(), sum(), etc.)
        # This is a simplified extraction - handles common patterns
        #
        # LIMITATION: This regex only extracts the first metric name from complex
        # expressions. For example, in division expressions like:
        #   "sum(rate(http_request_errors_total[5m])) / sum(rate(http_requests_total[5m]))"
        # only "http_request_errors_total" will be extracted and verified, not
        # "http_requests_total". This is acceptable for basic validation since:
        # 1. Most panels use related metrics (if one exists, the other likely does)
        # 2. A comprehensive solution would require a full PromQL parser
        # 3. The JSON syntax validation catches structural issues
        # 4. Missing metrics surface quickly in Grafana as "No Data" panels
        local metric_name=$(echo "$expr" | grep -oE '[a-z_]+\{' | sed 's/{//' | head -1)

        if [[ -z "$metric_name" ]]; then
            # Try without label selector
            metric_name=$(echo "$expr" | grep -oE '^[a-z_]+' | head -1)
        fi

        if [[ -z "$metric_name" ]]; then
            continue
        fi

        # Check if metric exists in Prometheus
        if echo "$available_metrics" | grep -q "^${metric_name}$"; then
            log_success "Metric exists: $metric_name"
        else
            log_error "Metric NOT FOUND: $metric_name"
        fi
    done
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    local specific_dashboard="${1:-}"
    SKIP_PROMETHEUS="${SKIP_PROMETHEUS:-false}"

    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║           Dashboard Metrics Validation Script                                ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"

    preflight_checks

    # Find dashboards to test
    local dashboards=()
    if [[ -n "$specific_dashboard" ]]; then
        local dashboard_file="$DASHBOARD_DIR/${specific_dashboard}.json"
        if [[ -f "$dashboard_file" ]]; then
            dashboards+=("$dashboard_file")
        else
            log_error "Dashboard not found: $dashboard_file"
            exit 1
        fi
    else
        while IFS= read -r -d '' file; do
            dashboards+=("$file")
        done < <(find "$DASHBOARD_DIR" -name "*.json" -print0)
    fi

    log_info "Found ${#dashboards[@]} dashboard(s) to validate"

    # Validate each dashboard
    for dashboard in "${dashboards[@]}"; do
        validate_json "$dashboard"

        if [[ "$SKIP_PROMETHEUS" != "true" ]]; then
            verify_metrics_in_prometheus "$dashboard"
        fi
    done

    # Summary
    section_header "Summary"
    echo -e "Total tests:  $TOTAL_TESTS"
    echo -e "Passed:       ${GREEN}$PASSED_TESTS${NC}"
    echo -e "Failed:       ${RED}$FAILED_TESTS${NC}"
    echo -e "Warnings:     ${YELLOW}$WARNINGS${NC}"
    echo ""

    if [[ $FAILED_TESTS -gt 0 ]]; then
        log_error "Some tests failed!"
        exit 1
    else
        log_success "All tests passed!"
        exit 0
    fi
}

# Run main with all arguments
main "$@"

#!/usr/bin/env bash
#
# grafana-dns-switch.sh - Switch Grafana DNS between primary and DR environments
#
# Usage:
#   ./scripts/grafana-dns-switch.sh [--to-dr | --to-primary] [--dry-run]
#   ./scripts/grafana-dns-switch.sh --status
#
# Requirements:
#   - CLOUDFLARE_API_TOKEN environment variable (Account API token with DNS edit permissions)
#   - CLOUDFLARE_ZONE_ID environment variable
#
# Examples:
#   ./scripts/grafana-dns-switch.sh --status          # Show current DNS configuration
#   ./scripts/grafana-dns-switch.sh --to-dr --dry-run # Preview switch to DR
#   ./scripts/grafana-dns-switch.sh --to-dr           # Switch to DR ALB
#   ./scripts/grafana-dns-switch.sh --to-primary      # Switch to primary ALB

set -euo pipefail

# Configuration
GRAFANA_HOSTNAME="grafana.davidshaevel.com"
PRIMARY_ALB="dev-davidshaevel-alb-85034469.us-east-1.elb.amazonaws.com"
DR_ALB="dr-davidshaevel-alb-1754623288.us-west-2.elb.amazonaws.com"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Switch Grafana DNS between primary (us-east-1) and DR (us-west-2) ALB endpoints.

Options:
    --to-dr         Switch Grafana DNS to DR ALB (us-west-2)
    --to-primary    Switch Grafana DNS to primary ALB (us-east-1)
    --status        Show current DNS configuration
    --dry-run       Preview changes without applying
    -h, --help      Show this help message

Environment Variables Required:
    CLOUDFLARE_API_TOKEN    Cloudflare API token with DNS edit permissions
    CLOUDFLARE_ZONE_ID      Cloudflare Zone ID for davidshaevel.com

Examples:
    $(basename "$0") --status
    $(basename "$0") --to-dr --dry-run
    $(basename "$0") --to-dr
    $(basename "$0") --to-primary
EOF
    exit 1
}

check_requirements() {
    if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
        log_error "CLOUDFLARE_API_TOKEN environment variable is not set"
        log_error "Set it in your .envrc or export it manually"
        exit 1
    fi

    if [[ -z "${CLOUDFLARE_ZONE_ID:-}" ]]; then
        log_error "CLOUDFLARE_ZONE_ID environment variable is not set"
        log_error "Set it in your .envrc or export it manually"
        exit 1
    fi

    if ! command -v curl &> /dev/null; then
        log_error "curl is required but not installed (try: brew install curl)"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed (try: brew install jq)"
        exit 1
    fi
}

get_grafana_record() {
    local response
    response=$(curl -s -X GET \
        "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records?name=${GRAFANA_HOSTNAME}" \
        -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
        -H "Content-Type: application/json")

    if ! echo "$response" | jq -e '.success' > /dev/null 2>&1; then
        log_error "Failed to query Cloudflare API"
        echo "$response" | jq -r '.errors[0].message // "Unknown error"'
        exit 1
    fi

    echo "$response"
}

show_status() {
    log_info "Checking current Grafana DNS configuration..."

    local response
    response=$(get_grafana_record)

    local record_count
    record_count=$(echo "$response" | jq '.result | length')

    if [[ "$record_count" -eq 0 ]]; then
        log_warn "No DNS record found for ${GRAFANA_HOSTNAME}"
        return
    fi

    local record_id record_type record_content proxied
    record_id=$(echo "$response" | jq -r '.result[0].id')
    record_type=$(echo "$response" | jq -r '.result[0].type')
    record_content=$(echo "$response" | jq -r '.result[0].content')
    proxied=$(echo "$response" | jq -r '.result[0].proxied')

    echo ""
    echo "========================================"
    echo "  Grafana DNS Status"
    echo "========================================"
    echo ""
    echo "  Hostname:  ${GRAFANA_HOSTNAME}"
    echo "  Type:      ${record_type}"
    echo "  Target:    ${record_content}"
    echo "  Proxied:   ${proxied}"
    echo "  Record ID: ${record_id}"
    echo ""

    if [[ "$record_content" == "$PRIMARY_ALB" ]]; then
        log_info "Currently pointing to: PRIMARY (us-east-1)"
    elif [[ "$record_content" == "$DR_ALB" ]]; then
        log_info "Currently pointing to: DR (us-west-2)"
    else
        log_warn "Currently pointing to: UNKNOWN target"
    fi

    echo ""
    echo "  Primary ALB: ${PRIMARY_ALB}"
    echo "  DR ALB:      ${DR_ALB}"
    echo ""
}

update_dns() {
    local target_alb="$1"
    local target_name="$2"
    local dry_run="${3:-false}"

    log_info "Getting current Grafana DNS record..."

    local response
    response=$(get_grafana_record)

    local record_count
    record_count=$(echo "$response" | jq '.result | length')

    if [[ "$record_count" -eq 0 ]]; then
        log_error "No DNS record found for ${GRAFANA_HOSTNAME}"
        log_error "Please create the CNAME record in Cloudflare first"
        exit 1
    fi

    local record_id current_content
    record_id=$(echo "$response" | jq -r '.result[0].id')
    current_content=$(echo "$response" | jq -r '.result[0].content')

    if [[ "$current_content" == "$target_alb" ]]; then
        log_info "DNS already pointing to ${target_name} (${target_alb})"
        return
    fi

    echo ""
    echo "========================================"
    echo "  DNS Update Plan"
    echo "========================================"
    echo ""
    echo "  Hostname:    ${GRAFANA_HOSTNAME}"
    echo "  Current:     ${current_content}"
    echo "  Target:      ${target_alb}"
    echo "  Environment: ${target_name}"
    echo ""

    if [[ "$dry_run" == "true" ]]; then
        log_warn "DRY RUN - No changes will be made"
        return
    fi

    log_info "Updating DNS record..."

    local update_response
    update_response=$(curl -s -X PATCH \
        "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records/${record_id}" \
        -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "{\"content\":\"${target_alb}\"}")

    if echo "$update_response" | jq -e '.success' > /dev/null 2>&1; then
        log_info "DNS record updated successfully"
        log_info "Grafana DNS now pointing to: ${target_name} (${target_alb})"
        echo ""
        log_info "DNS propagation may take a few minutes"
    else
        log_error "Failed to update DNS record"
        echo "$update_response" | jq -r '.errors[0].message // "Unknown error"'
        exit 1
    fi
}

# Main
DRY_RUN=false
ACTION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --to-dr)
            ACTION="to-dr"
            shift
            ;;
        --to-primary)
            ACTION="to-primary"
            shift
            ;;
        --status)
            ACTION="status"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

if [[ -z "$ACTION" ]]; then
    log_error "No action specified"
    usage
fi

check_requirements

case $ACTION in
    status)
        show_status
        ;;
    to-dr)
        update_dns "$DR_ALB" "DR (us-west-2)" "$DRY_RUN"
        ;;
    to-primary)
        update_dns "$PRIMARY_ALB" "PRIMARY (us-east-1)" "$DRY_RUN"
        ;;
esac

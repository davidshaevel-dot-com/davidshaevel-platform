#!/usr/bin/env bash
#
# vercel-dns-switch.sh - Switch davidshaevel.com DNS between AWS CloudFront and Vercel
#
# Usage:
#   ./scripts/vercel-dns-switch.sh [--to-vercel | --to-aws] [--dry-run]
#   ./scripts/vercel-dns-switch.sh --status
#
# Requirements:
#   - CLOUDFLARE_API_TOKEN environment variable (Account API token with DNS edit permissions)
#   - CLOUDFLARE_ZONE_ID environment variable
#
# Examples:
#   ./scripts/vercel-dns-switch.sh --status              # Show current DNS configuration
#   ./scripts/vercel-dns-switch.sh --to-vercel --dry-run  # Preview switch to Vercel
#   ./scripts/vercel-dns-switch.sh --to-vercel            # Switch to Vercel
#   ./scripts/vercel-dns-switch.sh --to-aws               # Switch back to AWS CloudFront

set -euo pipefail

# Configuration
DOMAIN="davidshaevel.com"
CLOUDFRONT_DIST="dbaz91yl33r82.cloudfront.net"
VERCEL_A_RECORD="216.198.79.1"
VERCEL_WWW_CNAME="2d7df72c42ce62a7.vercel-dns-017.com."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
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

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Switch davidshaevel.com DNS between AWS CloudFront and Vercel.

Options:
    --to-vercel     Switch DNS to Vercel (A record for root, CNAME for www)
    --to-aws        Switch DNS back to AWS CloudFront (CNAME for both)
    --status        Show current DNS configuration
    --dry-run       Preview changes without applying
    -h, --help      Show this help message

Environment Variables Required:
    CLOUDFLARE_API_TOKEN    Cloudflare API token with DNS edit permissions
    CLOUDFLARE_ZONE_ID      Cloudflare Zone ID for davidshaevel.com

DNS Targets:
    Vercel:     ${DOMAIN} -> A ${VERCEL_A_RECORD}
                www.${DOMAIN} -> CNAME ${VERCEL_WWW_CNAME}
    AWS:        ${DOMAIN} -> CNAME ${CLOUDFRONT_DIST}
                www.${DOMAIN} -> CNAME ${CLOUDFRONT_DIST}

Examples:
    $(basename "$0") --status
    $(basename "$0") --to-vercel --dry-run
    $(basename "$0") --to-vercel
    $(basename "$0") --to-aws
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
        log_error "curl is required but not installed"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed (try: brew install jq)"
        exit 1
    fi
}

cf_api() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"

    local args=(-s -X "$method"
        "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/${endpoint}"
        -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}"
        -H "Content-Type: application/json")

    if [[ -n "$data" ]]; then
        args+=(--data "$data")
    fi

    curl "${args[@]}"
}

get_record() {
    local name="$1"
    cf_api GET "dns_records?name=${name}"
}

delete_record() {
    local record_id="$1"
    cf_api DELETE "dns_records/${record_id}"
}

create_record() {
    local type="$1"
    local name="$2"
    local content="$3"
    local proxied="${4:-false}"

    cf_api POST "dns_records" "{\"type\":\"${type}\",\"name\":\"${name}\",\"content\":\"${content}\",\"proxied\":${proxied},\"ttl\":1}"
}

update_record() {
    local record_id="$1"
    local type="$2"
    local name="$3"
    local content="$4"
    local proxied="${5:-false}"

    cf_api PATCH "dns_records/${record_id}" "{\"type\":\"${type}\",\"name\":\"${name}\",\"content\":\"${content}\",\"proxied\":${proxied},\"ttl\":1}"
}

show_status() {
    log_info "Checking current DNS configuration for ${DOMAIN}..."

    echo ""
    echo "========================================"
    echo "  DNS Status: ${DOMAIN}"
    echo "========================================"

    # Root domain
    local root_response
    root_response=$(get_record "${DOMAIN}")

    local root_records
    root_records=$(echo "$root_response" | jq '[.result[] | select(.type == "A" or .type == "CNAME")]')
    local root_count
    root_count=$(echo "$root_records" | jq 'length')

    echo ""
    echo "  Root domain (${DOMAIN}):"
    if [[ "$root_count" -eq 0 ]]; then
        echo "    No A/CNAME records found"
    else
        for i in $(seq 0 $((root_count - 1))); do
            local rtype rcontent rproxied
            rtype=$(echo "$root_records" | jq -r ".[$i].type")
            rcontent=$(echo "$root_records" | jq -r ".[$i].content")
            rproxied=$(echo "$root_records" | jq -r ".[$i].proxied")
            echo "    Type: ${rtype}  Content: ${rcontent}  Proxied: ${rproxied}"
        done
    fi

    # WWW domain
    local www_response
    www_response=$(get_record "www.${DOMAIN}")

    local www_records
    www_records=$(echo "$www_response" | jq '[.result[] | select(.type == "A" or .type == "CNAME")]')
    local www_count
    www_count=$(echo "$www_records" | jq 'length')

    echo ""
    echo "  WWW domain (www.${DOMAIN}):"
    if [[ "$www_count" -eq 0 ]]; then
        echo "    No A/CNAME records found"
    else
        for i in $(seq 0 $((www_count - 1))); do
            local wtype wcontent wproxied
            wtype=$(echo "$www_records" | jq -r ".[$i].type")
            wcontent=$(echo "$www_records" | jq -r ".[$i].content")
            wproxied=$(echo "$www_records" | jq -r ".[$i].proxied")
            echo "    Type: ${wtype}  Content: ${wcontent}  Proxied: ${wproxied}"
        done
    fi

    # Determine current target
    echo ""
    local root_content
    root_content=$(echo "$root_records" | jq -r '.[0].content // "none"')
    local root_type
    root_type=$(echo "$root_records" | jq -r '.[0].type // "none"')

    if [[ "$root_content" == "$CLOUDFRONT_DIST" ]]; then
        log_info "Currently pointing to: AWS CloudFront"
    elif [[ "$root_content" == "$VERCEL_A_RECORD" && "$root_type" == "A" ]]; then
        log_info "Currently pointing to: Vercel"
    else
        log_warn "Currently pointing to: UNKNOWN target (${root_type} ${root_content})"
    fi

    echo ""
    echo "  AWS target:    CNAME ${CLOUDFRONT_DIST}"
    echo "  Vercel target: A ${VERCEL_A_RECORD} / CNAME ${VERCEL_WWW_CNAME}"
    echo ""
}

switch_to_vercel() {
    local dry_run="${1:-false}"

    log_info "Switching DNS to Vercel..."

    echo ""
    echo "========================================"
    echo "  DNS Switch Plan: AWS → Vercel"
    echo "========================================"
    echo ""
    echo "  Root (${DOMAIN}):"
    echo "    Current:  CNAME ${CLOUDFRONT_DIST}"
    echo "    Target:   A ${VERCEL_A_RECORD}"
    echo "    Action:   Delete CNAME → Create A record"
    echo ""
    echo "  WWW (www.${DOMAIN}):"
    echo "    Current:  CNAME ${CLOUDFRONT_DIST}"
    echo "    Target:   CNAME ${VERCEL_WWW_CNAME}"
    echo "    Action:   Update CNAME content"
    echo ""

    if [[ "$dry_run" == "true" ]]; then
        log_warn "DRY RUN - No changes will be made"
        return
    fi

    # Step 1: Get current root record
    log_step "1/4 Getting current root domain record..."
    local root_response
    root_response=$(get_record "${DOMAIN}")
    local root_id
    root_id=$(echo "$root_response" | jq -r '[.result[] | select(.type == "CNAME")][0].id // empty')

    if [[ -z "$root_id" ]]; then
        # Check if already an A record (idempotent)
        local existing_a
        existing_a=$(echo "$root_response" | jq -r '[.result[] | select(.type == "A")][0].content // empty')
        if [[ "$existing_a" == "$VERCEL_A_RECORD" ]]; then
            log_info "Root already pointing to Vercel A record"
        else
            log_error "No CNAME record found for root domain and no matching A record"
            exit 1
        fi
    else
        # Step 2: Delete root CNAME
        log_step "2/4 Deleting root CNAME record..."
        local delete_response
        delete_response=$(delete_record "$root_id")
        if echo "$delete_response" | jq -e '.success' > /dev/null 2>&1; then
            log_info "Root CNAME deleted"
        else
            log_error "Failed to delete root CNAME"
            echo "$delete_response" | jq -r '.errors[0].message // "Unknown error"'
            exit 1
        fi

        # Step 3: Create root A record
        log_step "3/4 Creating root A record for Vercel..."
        local create_response
        create_response=$(create_record "A" "${DOMAIN}" "${VERCEL_A_RECORD}" "false")
        if echo "$create_response" | jq -e '.success' > /dev/null 2>&1; then
            log_info "Root A record created: ${VERCEL_A_RECORD}"
        else
            log_error "Failed to create root A record"
            echo "$create_response" | jq -r '.errors[0].message // "Unknown error"'
            log_error "CRITICAL: Root domain DNS may be broken. Restore manually!"
            exit 1
        fi
    fi

    # Step 4: Update www CNAME
    log_step "4/4 Updating www CNAME record..."
    local www_response
    www_response=$(get_record "www.${DOMAIN}")
    local www_id
    www_id=$(echo "$www_response" | jq -r '[.result[] | select(.type == "CNAME")][0].id // empty')

    if [[ -z "$www_id" ]]; then
        log_warn "No www CNAME found, creating new record..."
        local www_create
        www_create=$(create_record "CNAME" "www" "${VERCEL_WWW_CNAME}" "false")
        if echo "$www_create" | jq -e '.success' > /dev/null 2>&1; then
            log_info "WWW CNAME created"
        else
            log_error "Failed to create www CNAME"
            echo "$www_create" | jq -r '.errors[0].message // "Unknown error"'
            exit 1
        fi
    else
        local www_update
        www_update=$(update_record "$www_id" "CNAME" "www" "${VERCEL_WWW_CNAME}" "false")
        if echo "$www_update" | jq -e '.success' > /dev/null 2>&1; then
            log_info "WWW CNAME updated: ${VERCEL_WWW_CNAME}"
        else
            log_error "Failed to update www CNAME"
            echo "$www_update" | jq -r '.errors[0].message // "Unknown error"'
            exit 1
        fi
    fi

    echo ""
    log_info "DNS switch to Vercel complete!"
    log_info "Propagation may take a few minutes"
    echo ""
}

switch_to_aws() {
    local dry_run="${1:-false}"

    log_info "Switching DNS back to AWS CloudFront..."

    echo ""
    echo "========================================"
    echo "  DNS Switch Plan: Vercel → AWS"
    echo "========================================"
    echo ""
    echo "  Root (${DOMAIN}):"
    echo "    Current:  A ${VERCEL_A_RECORD}"
    echo "    Target:   CNAME ${CLOUDFRONT_DIST}"
    echo "    Action:   Delete A record → Create CNAME"
    echo ""
    echo "  WWW (www.${DOMAIN}):"
    echo "    Current:  CNAME ${VERCEL_WWW_CNAME}"
    echo "    Target:   CNAME ${CLOUDFRONT_DIST}"
    echo "    Action:   Update CNAME content"
    echo ""

    if [[ "$dry_run" == "true" ]]; then
        log_warn "DRY RUN - No changes will be made"
        return
    fi

    # Step 1: Get current root record
    log_step "1/4 Getting current root domain record..."
    local root_response
    root_response=$(get_record "${DOMAIN}")
    local root_a_id
    root_a_id=$(echo "$root_response" | jq -r '[.result[] | select(.type == "A")][0].id // empty')

    if [[ -z "$root_a_id" ]]; then
        # Check if already a CNAME (idempotent)
        local existing_cname
        existing_cname=$(echo "$root_response" | jq -r '[.result[] | select(.type == "CNAME")][0].content // empty')
        if [[ "$existing_cname" == "$CLOUDFRONT_DIST" ]]; then
            log_info "Root already pointing to CloudFront CNAME"
        else
            log_error "No A record found for root domain and no matching CNAME"
            exit 1
        fi
    else
        # Step 2: Delete root A record
        log_step "2/4 Deleting root A record..."
        local delete_response
        delete_response=$(delete_record "$root_a_id")
        if echo "$delete_response" | jq -e '.success' > /dev/null 2>&1; then
            log_info "Root A record deleted"
        else
            log_error "Failed to delete root A record"
            echo "$delete_response" | jq -r '.errors[0].message // "Unknown error"'
            exit 1
        fi

        # Step 3: Create root CNAME
        log_step "3/4 Creating root CNAME record for CloudFront..."
        local create_response
        create_response=$(create_record "CNAME" "${DOMAIN}" "${CLOUDFRONT_DIST}" "false")
        if echo "$create_response" | jq -e '.success' > /dev/null 2>&1; then
            log_info "Root CNAME created: ${CLOUDFRONT_DIST}"
        else
            log_error "Failed to create root CNAME"
            echo "$create_response" | jq -r '.errors[0].message // "Unknown error"'
            log_error "CRITICAL: Root domain DNS may be broken. Restore manually!"
            exit 1
        fi
    fi

    # Step 4: Update www CNAME
    log_step "4/4 Updating www CNAME record..."
    local www_response
    www_response=$(get_record "www.${DOMAIN}")
    local www_id
    www_id=$(echo "$www_response" | jq -r '[.result[] | select(.type == "CNAME")][0].id // empty')

    if [[ -z "$www_id" ]]; then
        log_warn "No www CNAME found, creating new record..."
        local www_create
        www_create=$(create_record "CNAME" "www" "${CLOUDFRONT_DIST}" "false")
        if echo "$www_create" | jq -e '.success' > /dev/null 2>&1; then
            log_info "WWW CNAME created"
        else
            log_error "Failed to create www CNAME"
            echo "$www_create" | jq -r '.errors[0].message // "Unknown error"'
            exit 1
        fi
    else
        local www_update
        www_update=$(update_record "$www_id" "CNAME" "www" "${CLOUDFRONT_DIST}" "false")
        if echo "$www_update" | jq -e '.success' > /dev/null 2>&1; then
            log_info "WWW CNAME updated: ${CLOUDFRONT_DIST}"
        else
            log_error "Failed to update www CNAME"
            echo "$www_update" | jq -r '.errors[0].message // "Unknown error"'
            exit 1
        fi
    fi

    echo ""
    log_info "DNS switch to AWS CloudFront complete!"
    log_info "Propagation may take a few minutes"
    echo ""
}

# Main
DRY_RUN=false
ACTION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --to-vercel)
            ACTION="to-vercel"
            shift
            ;;
        --to-aws)
            ACTION="to-aws"
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
    to-vercel)
        switch_to_vercel "$DRY_RUN"
        ;;
    to-aws)
        switch_to_aws "$DRY_RUN"
        ;;
esac

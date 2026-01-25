#!/usr/bin/env bash
#
# neon-validate.sh - Validate Neon database connectivity and schema
#
# Usage:
#   ./scripts/neon-validate.sh
#
# Requirements:
#   - NEON_DATABASE_URL environment variable
#   - psql (PostgreSQL client)
#
# Examples:
#   ./scripts/neon-validate.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CHECKS_PASSED=0
CHECKS_FAILED=0

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_check() {
    echo -e "${BLUE}[CHECK]${NC} $1"
}

check_pass() {
    echo -e "  ${GREEN}PASS${NC} $1"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
}

check_fail() {
    echo -e "  ${RED}FAIL${NC} $1"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
}

usage() {
    cat << EOF
Usage: $(basename "$0")

Validate Neon database connectivity and schema for davidshaevel-platform.

Environment Variables Required:
    NEON_DATABASE_URL    Neon PostgreSQL connection string

Example:
    export NEON_DATABASE_URL="postgresql://user:pass@host/db?sslmode=require"
    ./scripts/neon-validate.sh
EOF
}

check_prerequisites() {
    log_check "Checking prerequisites..."

    if command -v psql &> /dev/null; then
        check_pass "psql installed: $(psql --version | head -1)"
    else
        check_fail "psql not installed"
        exit 1
    fi

    if [[ -n "${NEON_DATABASE_URL:-}" ]]; then
        # Mask password in output
        local masked_url
        masked_url=$(echo "$NEON_DATABASE_URL" | sed 's/:\/\/[^:]*:[^@]*@/:\/\/****:****@/')
        check_pass "NEON_DATABASE_URL set: $masked_url"
    else
        check_fail "NEON_DATABASE_URL not set"
        exit 1
    fi
}

check_connection() {
    log_check "Testing database connection..."

    if psql "${NEON_DATABASE_URL}" -c "SELECT 1" &> /dev/null; then
        check_pass "Connection successful"
    else
        check_fail "Connection failed"
        return 1
    fi

    local version
    version=$(psql "${NEON_DATABASE_URL}" -t -c "SELECT version();" | head -1 | xargs)
    check_pass "PostgreSQL version: $(echo "$version" | cut -d' ' -f1-2)"

    local db_name
    db_name=$(psql "${NEON_DATABASE_URL}" -t -c "SELECT current_database();" | xargs)
    check_pass "Database name: $db_name"
}

check_extensions() {
    log_check "Checking extensions..."

    local has_uuid
    has_uuid=$(psql "${NEON_DATABASE_URL}" -t -c "SELECT COUNT(*) FROM pg_extension WHERE extname = 'uuid-ossp';" | xargs)

    if [[ "$has_uuid" -gt 0 ]]; then
        check_pass "uuid-ossp extension installed"
    else
        check_fail "uuid-ossp extension not installed"
    fi
}

check_tables() {
    log_check "Checking tables..."

    local tables
    tables=$(psql "${NEON_DATABASE_URL}" -t -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;")

    if echo "$tables" | grep -q "projects"; then
        check_pass "projects table exists"
    else
        check_fail "projects table missing"
        return 1
    fi
}

check_projects_schema() {
    log_check "Checking projects table schema..."

    local expected_columns=("id" "title" "description" "imageUrl" "projectUrl" "githubUrl" "technologies" "isActive" "sortOrder" "createdAt" "updatedAt")

    for col in "${expected_columns[@]}"; do
        local exists
        exists=$(psql "${NEON_DATABASE_URL}" -t -c "SELECT COUNT(*) FROM information_schema.columns WHERE table_name = 'projects' AND column_name = '$col';" | xargs)

        if [[ "$exists" -gt 0 ]]; then
            check_pass "Column: $col"
        else
            check_fail "Missing column: $col"
        fi
    done
}

check_data() {
    log_check "Checking data..."

    local count
    count=$(psql "${NEON_DATABASE_URL}" -t -c "SELECT COUNT(*) FROM projects;" | xargs)
    check_pass "Projects count: $count"
}

print_summary() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Validation Summary${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "  ${GREEN}Passed:${NC} $CHECKS_PASSED"
    echo -e "  ${RED}Failed:${NC} $CHECKS_FAILED"
    echo ""

    if [[ $CHECKS_FAILED -eq 0 ]]; then
        log_info "All checks passed! Neon database is ready."
        return 0
    else
        log_error "Some checks failed. Run ./scripts/neon-init.sh to initialize schema."
        return 1
    fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Neon Database Validation${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

check_prerequisites
check_connection
check_extensions
check_tables
check_projects_schema
check_data
print_summary

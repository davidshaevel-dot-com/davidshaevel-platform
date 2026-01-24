#!/usr/bin/env bash
#
# neon-init.sh - Initialize Neon database schema
#
# Usage:
#   ./scripts/neon-init.sh [--reset]
#
# Requirements:
#   - NEON_DATABASE_URL environment variable
#   - psql (PostgreSQL client)
#
# Examples:
#   ./scripts/neon-init.sh           # Create schema (fails if exists)
#   ./scripts/neon-init.sh --reset   # Drop and recreate schema

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
    echo -e "${BLUE}[STEP]${NC} $1"
}

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Initialize Neon database schema for davidshaevel-platform.

Options:
    --reset     Drop existing tables and recreate schema
    -h, --help  Show this help message

Environment Variables Required:
    NEON_DATABASE_URL    Neon PostgreSQL connection string

Example:
    export NEON_DATABASE_URL="postgresql://user:pass@host/db?sslmode=require"
    ./scripts/neon-init.sh
EOF
}

check_prerequisites() {
    log_step "Checking prerequisites..."

    if ! command -v psql &> /dev/null; then
        log_error "psql is required but not installed"
        log_error "Install via: brew install libpq && brew link --force libpq"
        log_error "Or download PostgreSQL.app from https://postgresapp.com"
        exit 1
    fi

    if [[ -z "${NEON_DATABASE_URL:-}" ]]; then
        log_error "NEON_DATABASE_URL environment variable is not set"
        log_error "Set it in your .envrc file or export it directly"
        exit 1
    fi

    log_info "Prerequisites OK"
}

test_connection() {
    log_step "Testing Neon connection..."

    if ! psql "${NEON_DATABASE_URL}" -c "SELECT 1" &> /dev/null; then
        log_error "Failed to connect to Neon database"
        log_error "Check your NEON_DATABASE_URL"
        exit 1
    fi

    local version
    version=$(psql "${NEON_DATABASE_URL}" -t -c "SELECT version();" | head -1 | xargs)
    log_info "Connected to: ${version}"
}

drop_schema() {
    log_step "Dropping existing schema..."

    psql "${NEON_DATABASE_URL}" << 'EOF'
-- Drop tables in reverse dependency order
DROP TABLE IF EXISTS projects CASCADE;

-- Drop extensions if needed
-- DROP EXTENSION IF EXISTS "uuid-ossp";
EOF

    log_info "Schema dropped"
}

create_schema() {
    log_step "Creating schema..."

    psql "${NEON_DATABASE_URL}" << 'EOF'
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Projects table
CREATE TABLE IF NOT EXISTS projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    "imageUrl" VARCHAR(500),
    "projectUrl" VARCHAR(500),
    "githubUrl" VARCHAR(500),
    technologies TEXT[],
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
    "updatedAt" TIMESTAMP NOT NULL DEFAULT now()
);

-- Create index for common queries
CREATE INDEX IF NOT EXISTS idx_projects_is_active ON projects ("isActive");
CREATE INDEX IF NOT EXISTS idx_projects_sort_order ON projects ("sortOrder");
EOF

    log_info "Schema created"
}

verify_schema() {
    log_step "Verifying schema..."

    local tables
    tables=$(psql "${NEON_DATABASE_URL}" -t -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;")

    echo -e "${GREEN}Tables created:${NC}"
    echo "$tables" | while read -r table; do
        if [[ -n "$table" ]]; then
            echo "  - $(echo "$table" | xargs)"
        fi
    done

    # Verify projects table structure
    local columns
    columns=$(psql "${NEON_DATABASE_URL}" -t -c "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'projects' ORDER BY ordinal_position;")

    echo -e "\n${GREEN}Projects table columns:${NC}"
    echo "$columns" | while read -r col; do
        if [[ -n "$col" ]]; then
            echo "  - $(echo "$col" | xargs)"
        fi
    done
}

# Parse arguments
RESET=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --reset)
            RESET=true
            shift
            ;;
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
echo -e "${BLUE}  Neon Database Schema Initialization${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

check_prerequisites
test_connection

if [[ "$RESET" == "true" ]]; then
    log_warn "Reset mode: existing schema will be dropped"
    read -p "Are you sure? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        drop_schema
    else
        log_info "Aborted"
        exit 0
    fi
fi

create_schema
verify_schema

echo ""
log_info "Neon database initialization complete!"
